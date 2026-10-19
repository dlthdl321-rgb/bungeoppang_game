import { createHash, createPublicKey, KeyObject, verify } from "node:crypto";
import { Store, Doc } from "./store";
import { requireDevelopmentProgress } from "./active_progress";
import { parseCompositeIntent, validateDevelopmentCompositeQuote, CompositeIntent } from "./development_contracts";
import { purchaseFingerprint } from "./composite_purchases";
import { evidencePath } from "./workshop_evidence";

export class ProtectedPurchaseError extends Error {}
type Action="checkpoint"|"reservation"|"debit"|"cancellation";
interface Snapshot { buns:string; lifetimeBuns:string; level:number }
export interface ProtectedEvent {
  schema:1; audience:"workshop-purchase-v1"; account:string; progress:string; epoch:number;
  eventId:string; sequence:number; previousDigest:string; issuedAtMs:number; expiresAtMs:number;
  action:Action; snapshot:Snapshot; intent?:CompositeIntent;
}
export interface SignedProtectedEvent { keyId:string; payload:string; signature:string }
export interface TrustedSnapshotKey { pem:string; notBeforeMs:number; notAfterMs:number }
function fail(message:string):never {throw new ProtectedPurchaseError(message);}
function object(value:unknown):Doc {
  if(!value || typeof value!=="object" || Array.isArray(value)) return fail("Invalid protected object");
  return value as Doc;
}
function integer(value:unknown):number {
  if(typeof value!=="number" || !Number.isSafeInteger(value) || value<0) return fail("Invalid protected integer");
  return value;
}
function decimal(value:unknown):string {
  if(typeof value!=="string" || !/^(0|[1-9][0-9]{0,4095})$/.test(value)) return fail("Invalid protected balance");
  return value;
}
function identifier(value:unknown):string {
  if(typeof value!=="string" || !/^[A-Za-z0-9_-]{8,64}$/.test(value)) return fail("Invalid protected identifier");
  return value;
}
function snapshot(value:unknown):Snapshot {
  const row=object(value),buns=decimal(row.buns),lifetimeBuns=decimal(row.lifetimeBuns),level=integer(row.level);
  if(BigInt(buns)>BigInt(lifetimeBuns) || level<1 || level>50) return fail("Invalid protected snapshot");
  return {buns,lifetimeBuns,level};
}
function same(a:Snapshot,b:Snapshot):boolean {return a.buns===b.buns && a.lifetimeBuns===b.lifetimeBuns && a.level===b.level;}
/** Trust keys are configured SERVER validator public keys, never app/device keys.
 * A signature proves provenance, not gameplay validity. The issuer must replay
 * and validate production/save events before signing. No signing API is exposed. */
export class ProtectedPurchasePipeline {
  private readonly keys=new Map<string,{key:KeyObject;start:number;end:number}>();
  constructor(private readonly store:Store,private readonly config:unknown,
      keys:Readonly<Record<string,TrustedSnapshotKey>>,private readonly clock:()=>number) {
    for(const [id,row] of Object.entries(keys)) {
      if(!/^[A-Za-z0-9_-]{1,64}$/.test(id) || integer(row.notBeforeMs)>=integer(row.notAfterMs)) fail("Invalid validator key lifetime");
      const key=createPublicKey(row.pem);
      if(key.asymmetricKeyType!=="ed25519") fail("Expected Ed25519 validator key");
      this.keys.set(id,{key,start:row.notBeforeMs,end:row.notAfterMs});
    }
    if(!this.keys.size) fail("No trusted snapshot validator configured");
  }
  private decode(account:string,input:unknown):{event:ProtectedEvent;digest:string} {
    const envelope=object(input),key=typeof envelope.keyId==="string" ? this.keys.get(envelope.keyId):undefined;
    if(!key || typeof envelope.payload!=="string" || Buffer.byteLength(envelope.payload)>65536 ||
        typeof envelope.signature!=="string" || !/^[A-Za-z0-9_-]{86}$/.test(envelope.signature)) fail("Invalid protected signature envelope");
    const bytes=Buffer.from(envelope.payload,"utf8");
    if(!verify(null,bytes,key.key,Buffer.from(envelope.signature,"base64url"))) fail("Invalid protected signature");
    let row:Doc;
    try {row=object(JSON.parse(envelope.payload));} catch {return fail("Invalid protected JSON");}
    if(row.schema!==1 || row.audience!=="workshop-purchase-v1" || row.account!==account || !account || account.includes("/") || account.length>128) fail("Protected account/audience mismatch");
    const progress=identifier(row.progress),eventId=identifier(row.eventId),sequence=integer(row.sequence),epoch=integer(row.epoch);
    const issuedAtMs=integer(row.issuedAtMs),expiresAtMs=integer(row.expiresAtMs);
    if(!epoch || issuedAtMs<key.start || expiresAtMs>key.end || expiresAtMs<=issuedAtMs || expiresAtMs-issuedAtMs>900000 ||
        typeof row.previousDigest!=="string" || !(row.previousDigest==="" || /^[a-f0-9]{64}$/.test(row.previousDigest)) ||
        !["checkpoint","reservation","debit","cancellation"].includes(String(row.action))) fail("Invalid protected event metadata");
    const action=row.action as Action,intent=action==="checkpoint" ? undefined:parseCompositeIntent(row.intent,account);
    if(action==="checkpoint" && row.intent!==undefined) fail("Checkpoint cannot approve a purchase");
    const event:ProtectedEvent={schema:1,audience:"workshop-purchase-v1",account,progress,epoch,eventId,sequence,
      previousDigest:row.previousDigest,issuedAtMs,expiresAtMs,action,snapshot:snapshot(row.snapshot),...(intent ? {intent}: {})};
    return {event,digest:createHash("sha256").update(bytes).digest("hex")};
  }
  async ingest(account:string,input:unknown):Promise<Doc> {
    const signed={...object(input)};
    const {event:e,digest}=this.decode(account,signed),base=`users/${account}`;
    const eventPath=`${base}/workshopProtectionEvents/${e.eventId}`,headPath=`${base}/workshopProtection/${e.progress}`;
    return this.store.run(async tx=>{
      const prior=await tx.get(eventPath);
      if(prior) {
        if(prior.digest!==digest) fail("Protected event ID reused");
        return {account,eventId:e.eventId,sequence:e.sequence,digest,status:"accepted"};
      }
      const now=integer(this.clock());
      if(e.issuedAtMs>now+30000 || e.expiresAtMs<=now) fail("Protected event expired or issued in future");
      await requireDevelopmentProgress(tx,account,e.progress,e.epoch);
      const head=await tx.get(headPath),pending=await tx.get(`${base}/compositeState/pending`);
      if(head ? head.epoch!==e.epoch || e.sequence!==integer(head.sequence)+1 || e.previousDigest!==head.digest :
          e.action!=="checkpoint" || e.sequence!==0 || e.previousDigest!=="") fail("Protected snapshot CAS conflict");
      const previous=head ? snapshot(head.snapshot):undefined;
      let reservationBuns: string|undefined;
      let reservationDigest:string|undefined;
      let canceledBeforeHold:Doc|undefined;
      let evidence:Doc|undefined;
      let path:string|undefined;
      if(e.action==="checkpoint") {
        if(pending?.transaction) fail("Unsettled purchase prevents checkpoint replacement");
        if(head && (head.action==="reservation" || head.action==="debit")) {
          const old=await tx.get(`${base}/compositePurchases/${identifier(head.transaction)}`);
          if(!old || !["committed","canceled"].includes(String(old.status))) fail("Unsettled protected purchase");
        }
      } else {
        const intent=e.intent!,transaction=intent.transaction;
        const purchase=await tx.get(`${base}/compositePurchases/${transaction}`);
        const cancellation=await tx.get(evidencePath(account,"cancellation",transaction));
        if(e.action==="reservation") {
          if(!previous || !same(previous,e.snapshot) || pending?.transaction || purchase || cancellation) fail("Reservation requires current idle snapshot");
          if(head && (head.action==="reservation" || head.action==="debit")) {
            const old=await tx.get(`${base}/compositePurchases/${identifier(head.transaction)}`);
            if(!old || !["committed","canceled"].includes(String(old.status))) fail("Protected purchase is pending");
          }
          const ownership=await tx.get(`${base}/compositeSkills/${intent.skill}`),wallet=await tx.get(base);
          validateDevelopmentCompositeQuote(this.config,intent,account,integer(ownership?.owned??0));
          if(BigInt(e.snapshot.buns)<BigInt(intent.buns) || BigInt(integer(wallet?.gold??0))<BigInt(intent.gold)) fail("Insufficient protected funds");
          reservationBuns=e.snapshot.buns;reservationDigest=digest;
        } else {
          if(!head || head.transaction!==transaction || head.fingerprint!==purchaseFingerprint(intent) || !previous ||
              purchase?.status==="committed" || purchase?.status==="canceled" ||
              (purchase && purchaseFingerprint(parseCompositeIntent(purchase,account))!==purchaseFingerprint(intent))) fail("Protected purchase context mismatch");
          reservationBuns=decimal(head.reservationBuns);
          if(typeof head.reservationDigest!=="string" || !/^[a-f0-9]{64}$/.test(head.reservationDigest)) fail("Corrupt protected reservation digest");
          reservationDigest=head.reservationDigest;
          if(e.snapshot.lifetimeBuns!==previous.lifetimeBuns || e.snapshot.level!==previous.level) fail("Purchase cannot change lifetime/level");
          if(e.action==="debit") {
            if(head.action!=="reservation" || cancellation || purchase?.status!=="reserved" || pending?.transaction!==transaction ||
                BigInt(e.snapshot.buns)!==BigInt(reservationBuns)-BigInt(intent.buns)) fail("Protected debit mismatch/fenced");
          } else {
            if(!["reservation","debit"].includes(String(head.action)) || cancellation || e.snapshot.buns!==reservationBuns ||
                (pending?.transaction && pending.transaction!==transaction)) fail("Protected cancellation restoration mismatch");
            if(!purchase) {
              if(pending?.transaction) fail("Missing purchase journal with a pending hold");
              // A signed restoration/fence plus atomic absence of BOTH hold and
              // journal permits an immutable no-charge cancellation tombstone.
              canceledBeforeHold={...intent,progress:e.progress,epoch:e.epoch,status:"canceled",
                receiptId:`canceled_${purchaseFingerprint(intent)}`,grantId:"",reservedDigest:reservationDigest,debitDigest:""};
            }
          }
        }
        path=evidencePath(account,e.action,transaction);
        if(await tx.get(path)) fail("Protected evidence is immutable");
        evidence={source:"trustedServerValidation",verifierVersion:1,account,progress:e.progress,epoch:e.epoch,transaction,
          fingerprint:purchaseFingerprint(intent),snapshotDigest:digest,availableBuns:e.snapshot.buns,lifetimeBuns:e.snapshot.lifetimeBuns,
          level:e.snapshot.level,phase:e.action,protectionSequence:e.sequence,protectionEvent:e.eventId,
          ...(e.action==="cancellation" ? {debitFenced:true,localDebitRestored:true}:{})};
      }
      // All reads precede all writes. Head, immutable event and proof share CAS.
      tx.create(eventPath,{digest,account,progress:e.progress,epoch:e.epoch,sequence:e.sequence,action:e.action,
        keyId:signed.keyId,payload:signed.payload,signature:signed.signature});
      tx.set(headPath,{account,progress:e.progress,epoch:e.epoch,sequence:e.sequence,digest,snapshot:e.snapshot,action:e.action,
        ...(e.intent ? {transaction:e.intent.transaction,fingerprint:purchaseFingerprint(e.intent),reservationBuns,reservationDigest}: {})});
      if(path && evidence) tx.create(path,evidence);
      if(canceledBeforeHold) tx.create(`${base}/compositePurchases/${e.intent!.transaction}`,canceledBeforeHold);
      return {account,eventId:e.eventId,sequence:e.sequence,digest,status:"accepted"};
    });
  }
}
