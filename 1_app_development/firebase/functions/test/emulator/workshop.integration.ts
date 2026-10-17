import { test, after, before } from "node:test";
import assert from "node:assert/strict";
import { generateKeyPairSync, sign } from "node:crypto";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import config from "../../src/generated/development_balance.json";
import { lazyFirestoreStore } from "../../src/firestore_store";
import { WorkshopService } from "../../src/workshop_service";
import { ProtectedEvent, ProtectedPurchasePipeline } from "../../src/protected_purchase_pipeline";
import { acceptWorkshopSsv, WorkshopSsvVerifier } from "../../src/workshop_ads";

// A production project or external host must never be reachable from this test.
const project="demo-workshop-step04",host=process.env.FIRESTORE_EMULATOR_HOST;
if(host!=="127.0.0.1:18084" || process.env.GCLOUD_PROJECT!==project) throw new Error("Require isolated demo Firestore emulator");
const app=initializeApp({projectId:project}),db=getFirestore(app),store=lazyFirestoreStore(()=>db);
before(async()=>{
  const response=await fetch(`http://${host}/emulator/v1/projects/${project}/databases/(default)/documents`,{method:"DELETE"});
  assert.equal(response.status,200);
});
after(async()=>{await db.terminate();await deleteApp(app);});
const at=Date.UTC(2026,9,18,14,59,59),progress="progress_0001",context={progress,epoch:1};
const pair=generateKeyPairSync("ed25519"),pem=pair.publicKey.export({format:"pem",type:"spki"}).toString();
const pipeline=new ProtectedPurchasePipeline(store,config,{validator:{pem,notBeforeMs:at-1,notAfterMs:at+900000}},()=>at);
const service=new WorkshopService(store,config,()=>at,new Uint8Array(32).fill(3));
function intent(account:string) {return {account,transaction:"transaction_0001",revision:config.metadata.revision,skill:"tap_1",owned:0,quantity:1,buns:"15",gold:"1"};}
function signed(account:string,action:ProtectedEvent["action"],sequence:number,previousDigest:string,buns="100",eventId=`event_000${sequence}`) {
  const event:ProtectedEvent={schema:1,audience:"workshop-purchase-v1",account,progress,epoch:1,eventId,sequence,previousDigest,issuedAtMs:at,expiresAtMs:at+60000,action,
    snapshot:{buns,lifetimeBuns:"100",level:1},...(action==="checkpoint" ? {}:{intent:intent(account)})};
  const payload=JSON.stringify(event);return {keyId:"validator",payload,signature:sign(null,Buffer.from(payload),pair.privateKey).toString("base64url")};
}
async function setup(account:string) {
  await service.claim(account,{progress});await db.doc(`users/${account}`).set({gold:5});
  return pipeline.ingest(account,signed(account,"checkpoint",0,""));
}
test("real Firestore retries serialize identical signed events and purchase requests",async()=>{
  const account="emu_purchase",head=await setup(account),quote=intent(account);
  const signedReservation=signed(account,"reservation",1,String(head.digest));
  const acknowledgements=await Promise.all(Array.from({length:4},()=>pipeline.ingest(account,signedReservation)));
  assert.ok(acknowledgements.every(x=>x.digest===acknowledgements[0].digest));
  const reserved=await Promise.all(Array.from({length:4},()=>service.purchase(account,"reserve",{...context,intent:quote})));
  assert.ok(reserved.every(x=>x.status==="reserved"));
  assert.equal((await db.doc(`users/${account}`).get()).data()!.gold,4);
  const proof=await pipeline.ingest(account,signed(account,"debit",2,String(acknowledgements[0].digest),"85"));
  const committed=await Promise.all(Array.from({length:4},()=>service.purchase(account,"commit",{...context,intent:quote})));
  assert.ok(committed.every(x=>x.status==="committed" && x.receiptId===committed[0].receiptId));
  assert.equal((await db.doc(`users/${account}/compositeSkills/tap_1`).get()).data()!.owned,1);
  assert.equal((await db.doc(`users/${account}`).get()).data()!.gold,4);
  assert.equal((await pipeline.ingest(account,signed(account,"debit",2,String(acknowledgements[0].digest),"85"))).digest,proof.digest);
});
test("real Firestore CAS allows only one fork of a protected snapshot",async()=>{
  const account="emu_cas",head=await setup(account);
  const outcomes=await Promise.allSettled([pipeline.ingest(account,signed(account,"reservation",1,String(head.digest),"100","fork_0001")),
    pipeline.ingest(account,signed(account,"reservation",1,String(head.digest),"100","fork_0002"))]);
  assert.equal(outcomes.filter(x=>x.status==="fulfilled").length,1);
  assert.equal((await db.doc(`users/${account}/workshopProtection/${progress}`).get()).data()!.sequence,1);
});
test("cancellation fence and commit race is atomic; no refund plus grant",async()=>{
  const account="emu_cancel",head=await setup(account),quote=intent(account);
  const reservation=await pipeline.ingest(account,signed(account,"reservation",1,String(head.digest)));
  await service.purchase(account,"reserve",{...context,intent:quote});
  const debit=await pipeline.ingest(account,signed(account,"debit",2,String(reservation.digest),"85"));
  await Promise.allSettled([pipeline.ingest(account,signed(account,"cancellation",3,String(debit.digest))),service.purchase(account,"commit",{...context,intent:quote})]);
  let result=await service.purchase(account,"query",{...context,transaction:quote.transaction});
  if(result.status==="reserved") result=await service.purchase(account,"cancel",{...context,transaction:quote.transaction});
  const gold=(await db.doc(`users/${account}`).get()).data()!.gold;
  const owned=(await db.doc(`users/${account}/compositeSkills/tap_1`).get()).data()?.owned??0;
  assert.ok((result.status==="committed" && gold===4 && owned===1)||(result.status==="canceled" && gold===5 && owned===0));
});
test("concurrent devices share two ad slots; duplicate SSV pays once across midnight",async()=>{
  const account="emu_ads";
  const attempts=await Promise.allSettled(["attempt_0001","attempt_0002","attempt_0003"].map(attempt=>service.adStart(account,{attempt})));
  const approved=attempts.filter((x):x is PromiseFulfilledResult<Awaited<ReturnType<WorkshopService["adStart"]>>>=>x.status==="fulfilled");
  assert.equal(approved.length,2);
  const first=approved[0].value,second=approved[1].value;
  const verifier=(customData:string):WorkshopSsvVerifier=>({verify:async()=>({provider:"admob",adUnit:"unit",transaction:"emulator-provider-tx",customData})});
  const paid=await Promise.all(Array.from({length:4},()=>acceptWorkshopSsv(store,verifier(first.customData),"signed-test-adapter",new Set(["unit"]),()=>at+2000)));
  assert.ok(paid.every(x=>x.paid===true && x.day==="2026-10-18"));
  await assert.rejects(acceptWorkshopSsv(store,verifier(second.customData),"signed-test-adapter",new Set(["unit"]),()=>at+2000));
  assert.equal((await db.doc(`users/${account}`).get()).data()!.gold,config.rewarded_ads.gold_per_verified_view);
  const next=new WorkshopService(store,config,()=>at+2000,new Uint8Array(32).fill(3));
  assert.equal((await next.adStart(account,{attempt:"attempt_next"})).day,"2026-10-19");
});
test("Firestore rules deny direct client evidence writes and protected reads",async()=>{
  const url=`http://${host}/v1/projects/${project}/databases/(default)/documents/users/client/workshopEvidence/reservation_fake`;
  const write=await fetch(url,{method:"PATCH",headers:{"Content-Type":"application/json"},body:JSON.stringify({fields:{verified:{booleanValue:true}}})});
  assert.equal(write.status,403);
  assert.equal((await fetch(`http://${host}/v1/projects/${project}/databases/(default)/documents/users/emu_purchase`)).status,403);
});
test("callable authentication and default OFF gates are preserved through HTTP",async()=>{
  if(process.env.FIREBASE_AUTH_EMULATOR_HOST!=="127.0.0.1:19099") throw new Error("Require demo auth emulator");
  const call=async(name:string,token?:string)=>fetch(`http://127.0.0.1:15004/${project}/asia-northeast3/${name}`,{method:"POST",
    headers:{"Content-Type":"application/json",...(token ? {Authorization:`Bearer ${token}`}:{})},body:JSON.stringify({data:{progress}})});
  const anonymous=await call("workshopProgressClaim");assert.equal(anonymous.status,401);
  const token=await getAuth(app).createCustomToken("kakao:emulator",{provider:"kakao"});
  const login=await fetch("http://127.0.0.1:19099/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=demo",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({token,returnSecureToken:true})});
  assert.equal(login.status,200);
  const data=await login.json() as {idToken:string};
  const disabled=await call("workshopProgressClaim",data.idToken);assert.equal(disabled.status,400);
  assert.equal(((await disabled.json()) as {error:{status:string}}).error.status,"FAILED_PRECONDITION");
  assert.equal((await fetch(`http://127.0.0.1:15004/${project}/asia-northeast3/workshopAdSsv`)).status,503);
});

test("unreserved approval cancellation creates a durable no-charge tombstone",async()=>{
  const account="emu_before_hold",head=await setup(account),quote=intent(account);
  const reservation=await pipeline.ingest(account,signed(account,"reservation",1,String(head.digest)));
  await pipeline.ingest(account,signed(account,"cancellation",2,String(reservation.digest)));
  const result=await service.purchase(account,"query",{...context,transaction:quote.transaction});
  assert.equal(result.status,"canceled");
  assert.deepEqual(await service.purchase(account,"reserve",{...context,intent:quote}),result);
  assert.equal((await db.doc(`users/${account}`).get()).data()!.gold,5);
});
