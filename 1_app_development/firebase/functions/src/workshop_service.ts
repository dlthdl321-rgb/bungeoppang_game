import { createHash, randomBytes } from "node:crypto";
import { Store } from "./store";
import { claimDevelopmentProgress, transferDevelopmentProgress } from "./active_progress";
import { PurchaseContext, reserveCompositePurchase, finishCompositePurchase, queryCompositePurchase, purchaseFingerprint } from "./composite_purchases";
import { StoredWorkshopEvidence } from "./workshop_evidence";
import { creditWorkshopMission } from "./workshop_missions";
import { reviewAndCreditSale, querySaleReward } from "./sale_rewards";
import { developmentAdPolicy, reserveDevelopmentAd, parseCompositeIntent } from "./development_contracts";

import { creditWorkshopAd } from "./workshop_ads";

type Row = Record<string,unknown>;
export class WorkshopServiceError extends Error {}
function object(value: unknown): Row {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new WorkshopServiceError("요청 형식 오류");
  return value as Row;
}
function id(value: unknown): string {
  if (typeof value !== "string" || !/^[A-Za-z0-9_:-]{1,160}$/.test(value)) throw new WorkshopServiceError("요청 식별자 오류");
  return value;
}
function canonical(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === "object") return Object.fromEntries(Object.keys(value).sort().map(k => [k,canonical((value as Row)[k])]));
  if (value === null || typeof value === "string" || typeof value === "boolean" ||
      (typeof value === "number" && Number.isSafeInteger(value))) return value;
  throw new WorkshopServiceError("증거는 정수 기반 JSON이어야 합니다.");
}
export function rewardFingerprint(account: string, progress: string, claim: string, kind: string, payload: Row): string {
  return JSON.stringify([account,progress,claim,kind,canonical(payload)]);
}
/** Source-wired authenticated handlers. No client endpoint writes trusted
 * evidence. Enabling requires the trusted validation pipeline and deployment. */
export class WorkshopService {
  private readonly evidence: StoredWorkshopEvidence;
  constructor(private readonly store: Store, private readonly config: unknown,
      private readonly clock: () => number, private readonly saleKey: Uint8Array) {
    this.evidence = new StoredWorkshopEvidence(store);
  }
  private account(account:string):void {
    if (!account || account.includes("/") || account.length>128) throw new WorkshopServiceError("계정 식별자 오류");
  }
  async claim(account: string, input: unknown) {
    this.account(account);
    const data = object(input);
    return this.storeProgress(account,id(data.progress));
  }
  async transfer(account:string,input:unknown) {
    this.account(account);
    const data=object(input),request=id(data.request),target=id(data.target);
    const proof=await this.store.run(tx=>tx.get(`users/${account}/workshopEvidence/transfer_${request}`));
    if (!proof || proof.verifierVersion!==1 || proof.source!=="trustedServerValidation" || proof.account!==account || proof.to!==target ||
        typeof proof.from!=="string" || typeof proof.sourceEpoch!=="number" || typeof proof.snapshotDigest!=="string" ||
        typeof proof.protectionDigest!=="string" || proof.pendingResolved!==true) throw new WorkshopServiceError("진행 이전 보호 증거 확인이 필요합니다.");
    return {account,...await transferDevelopmentProgress(this.store,account,request,{account,from:proof.from,to:target,
      sourceEpoch:proof.sourceEpoch,snapshotDigest:proof.snapshotDigest,protectionDigest:proof.protectionDigest,pendingResolved:true})};
  }
  private async storeProgress(account: string,progress: string) {
    return { account,...await claimDevelopmentProgress(this.store,account,progress) };
  }
  private context(account: string,input: unknown): PurchaseContext {
    const data = object(input), epoch = data.epoch;
    if (typeof epoch !== "number" || !Number.isSafeInteger(epoch) || epoch <= 0) throw new WorkshopServiceError("활성 진행 순번 오류");
    return { account,progress:id(data.progress),epoch };
  }
  async purchase(account: string,action: "reserve"|"query"|"commit"|"cancel",input: unknown) {
    this.account(account);
    const ctx = this.context(account,input),data = object(input);
    if (action === "reserve") return reserveCompositePurchase(this.store,this.config,this.evidence,ctx,data.intent);
    if (action === "commit") return finishCompositePurchase(this.store,this.evidence,ctx,data.intent,"commit");
    const old = await queryCompositePurchase(this.store,ctx,id(data.transaction));
    if (action === "query" || old.status === "unknown" || old.status === "committed" || old.status === "canceled") return old;
    // Validator must fence late commits and attest rollback/no debit.
    const cancellation=await this.store.run(tx=>tx.get(`users/${account}/workshopEvidence/cancellation_${id(data.transaction)}`));
    if (!cancellation || cancellation.source!=="trustedServerValidation" || cancellation.verifierVersion!==1 ||
        cancellation.account!==account || cancellation.progress!==ctx.progress || cancellation.epoch!==ctx.epoch ||
        cancellation.transaction!==data.transaction || cancellation.fingerprint!==purchaseFingerprint(parseCompositeIntent(old,account)) ||
        cancellation.debitFenced!==true || cancellation.localDebitRestored!==true) {
      throw new WorkshopServiceError("Cancellation evidence required");
    }
    return finishCompositePurchase(this.store,this.evidence,ctx,old,"cancel");
  }
  async reward(account: string,input: unknown,submit: boolean) {
    this.account(account);
    const data = object(input),progress=id(data.progress),claim=id(data.claim),kind=data.kind;
    if (kind !== "sale" && kind !== "mission") throw new WorkshopServiceError("보상 종류 오류");
    const payload = object(data.payload),fingerprint = rewardFingerprint(account,progress,claim,kind,payload);
    if (Buffer.byteLength(fingerprint,"utf8") > 262144) throw new WorkshopServiceError("보상 증거 크기 초과");
    const digest = createHash("sha256").update(JSON.stringify([progress,claim,kind])).digest("hex");
    const path = `users/${account}/workshopSubmissions/${digest}`;
    const submission = { account,progress,claim,kind,fingerprint,payload };
    await this.store.run(async tx => {
      const old=await tx.get(path);
      if (old) {
        if (old.fingerprint !== fingerprint) throw new WorkshopServiceError("동일 보상 ID의 증거 변경");
      } else if (submit) tx.create(path,submission);
      else throw new WorkshopServiceError("아직 제출하지 않은 보상입니다.");
    });
    const resultBase = { account,progress,claim,kind,fingerprint };
    const resultPath=`users/${account}/workshopRewardResults/${digest}`;
    const cached=await this.store.run(tx=>tx.get(resultPath));
    if(cached) {
      if(cached.account!==account || cached.progress!==progress || cached.claim!==claim || cached.kind!==kind || cached.fingerprint!==fingerprint ||
          !["eligible","noWin","unverifiable"].includes(String(cached.outcome)) || typeof cached.gold!=="number" || !Number.isSafeInteger(cached.gold) ||
          cached.gold<0 || typeof cached.receiptId!=="string" || !cached.receiptId || (cached.outcome==="eligible")!==(cached.gold>0)) throw new WorkshopServiceError("확정 보상 수신 원장 충돌");
      return cached;
    }
    const finish=async(result:Row)=>this.store.run(async tx=>{
      const old=await tx.get(resultPath);
      if(old) {
        if(JSON.stringify(canonical(old))!==JSON.stringify(canonical(result))) throw new WorkshopServiceError("최종 보상 결과 변경");
        return old;
      }
      tx.create(resultPath,result);return result;
    });
    // Recover already-paid/final outcomes before consulting a verifier that
    // may be delayed or temporarily unavailable after a successful credit.
    if (kind === "sale") {
      const prior=await querySaleReward(this.store,account,claim);
      if (prior) {
        if (prior.progress!==progress || prior.fingerprint!==fingerprint) throw new WorkshopServiceError("기존 판매 결과와 증거 불일치");
        return finish({...resultBase,outcome:prior.outcome,gold:prior.gold,receiptId:`sale_${digest}`});
      }
    } else {
      const earned=createHash("sha256").update(JSON.stringify(["mission",claim])).digest("hex");
      const previous=await this.store.run(tx => tx.get(`users/${account}/ledger/earned_${earned}`));
      if (previous) {
        if (previous.account!==account || previous.claimId!==claim || previous.kind!=="mission" || previous.fingerprint!==fingerprint ||
            typeof previous.gold!=="number" || !Number.isSafeInteger(previous.gold) || previous.gold<=0) throw new WorkshopServiceError("미션 지급 원장 재대조 필요");
        return finish({...resultBase,outcome:"eligible",gold:previous.gold,receiptId:`mission_${digest}`});
      }
    }
    if (kind === "sale") {
      const verified = await this.evidence.sale.verify(account,claim);
      if (verified.status === "pending") return { ...resultBase,outcome:"pending",gold:0,receiptId:"" };
      if (verified.progress !== progress || verified.fingerprint !== fingerprint) throw new WorkshopServiceError("판매 검증 대상 불일치");
      const result = await reviewAndCreditSale(this.store,this.evidence.sale,this.config,this.saleKey,account,claim,this.clock);
      if (result.outcome === "pending") return { ...resultBase,outcome:"pending",gold:0,receiptId:"" };
      return finish({ ...resultBase,outcome:result.outcome,gold:result.gold,receiptId:`sale_${digest}` });
    }
    const attestationPath = `users/${account}/workshopEvidence/mission_${claim}`;
    const attestation = await this.store.run(tx => tx.get(attestationPath));
    if (!attestation) return { ...resultBase,outcome:"pending",gold:0,receiptId:"" };
    if (attestation.progress !== progress || attestation.fingerprint !== fingerprint) throw new WorkshopServiceError("미션 검증 대상 불일치");
    const verified = await this.evidence.mission.verify(account,claim);
    const credited=await creditWorkshopMission(this.store,verified,payload,this.clock());
    return finish({ ...resultBase,...credited,receiptId:`mission_${digest}` });
  }
  async adStart(account: string,input: unknown) {
    this.account(account);
    const data=object(input),attempt=id(data.attempt);
    const approval = await reserveDevelopmentAd(this.store,account,attempt,this.clock(),developmentAdPolicy(this.config));
    const tokenPath=`users/${account}/workshopAdTokens/${attempt}`;
    const customData=await this.store.run(async tx => {
      const old=await tx.get(tokenPath);
      if (old) {
        if (typeof old.token !== "string" || !/^[a-f0-9]{64}$/.test(old.token)) throw new WorkshopServiceError("광고 검증 토큰 손상");
        return old.token;
      }
      const token=randomBytes(32).toString("hex");
      const digest=createHash("sha256").update(token).digest("hex");
      tx.create(tokenPath,{ account,attempt,token });
      tx.create(`workshopAdTokenIndex/${digest}`,{account,attempt,revision:approval.revision});
      return token;
    });
    return { ...approval,customData };
  }
  async adQuery(account:string,input:unknown) {
    this.account(account);
    const data=object(input),attempt=id(data.attempt);
    return creditWorkshopAd(this.store,account,attempt,this.clock);
  }
}
