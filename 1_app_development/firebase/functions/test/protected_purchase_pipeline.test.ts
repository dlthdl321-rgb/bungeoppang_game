import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash, generateKeyPairSync, sign } from "node:crypto";
import config from "../src/generated/development_balance.json";
import { ProtectedPurchasePipeline, ProtectedEvent } from "../src/protected_purchase_pipeline";
import { MemoryStore } from "../src/store";
import { WorkshopService } from "../src/workshop_service";
const at=Date.UTC(2026,9,18),account="protected_a",progress="progress_0001";
const intent={account,transaction:"transaction_0001",revision:config.metadata.revision,skill:"tap_1",owned:0,quantity:1,buns:"15",gold:"1"};
const pair=generateKeyPairSync("ed25519"),pem=pair.publicKey.export({format:"pem",type:"spki"}).toString();
function envelope(event:ProtectedEvent) {const payload=JSON.stringify(event);return {keyId:"validator",payload,signature:sign(null,Buffer.from(payload),pair.privateKey).toString("base64url")};}
function event(action:ProtectedEvent["action"],sequence:number,previousDigest:string,buns="100"):ProtectedEvent {
  return {schema:1,audience:"workshop-purchase-v1",account,progress,epoch:1,eventId:`event_000${sequence}`,sequence,previousDigest,
    issuedAtMs:at,expiresAtMs:at+60000,action,snapshot:{buns,lifetimeBuns:"100",level:1},...(action==="checkpoint" ? {}:{intent})};
}
async function fixture() {
  const store=new MemoryStore(),service=new WorkshopService(store,config,()=>at,new Uint8Array(32).fill(1));
  await service.claim(account,{progress});store.docs.set(`users/${account}`,{gold:5});
  const pipeline=new ProtectedPurchasePipeline(store,config,{validator:{pem,notBeforeMs:at-1,notAfterMs:at+900000}},()=>at);
  const head=await pipeline.ingest(account,envelope(event("checkpoint",0,"")));
  return {store,service,pipeline,head};
}
test("signed protected snapshots generate purchase evidence with CAS and recover a committed purchase",async()=>{
  const {store,service,pipeline,head}=await fixture();
  const reservation=await pipeline.ingest(account,envelope(event("reservation",1,String(head.digest))));
  await service.purchase(account,"reserve",{progress,epoch:1,intent});
  const signed=envelope(event("debit",2,String(reservation.digest),"85"));
  const proof=await pipeline.ingest(account,signed);
  assert.deepEqual(await pipeline.ingest(account,signed),proof);
  const committed=await service.purchase(account,"commit",{progress,epoch:1,intent});assert.equal(committed.status,"committed");
  assert.equal(store.docs.get(`users/${account}`)!.gold,4);
  assert.equal((store.docs.get(`users/${account}/workshopProtection/${progress}`)!.snapshot as {buns:string}).buns,"85");
  await assert.rejects(pipeline.ingest(account,envelope(event("cancellation",3,String(proof.digest)))));
});
test("a protected restored snapshot fences late debit/commit and refunds once",async()=>{
  const {store,service,pipeline,head}=await fixture();
  const reservation=await pipeline.ingest(account,envelope(event("reservation",1,String(head.digest))));
  await service.purchase(account,"reserve",{progress,epoch:1,intent});
  const debit=await pipeline.ingest(account,envelope(event("debit",2,String(reservation.digest),"85")));
  await pipeline.ingest(account,envelope(event("cancellation",3,String(debit.digest))));
  await assert.rejects(service.purchase(account,"commit",{progress,epoch:1,intent}));
  const canceled=await service.purchase(account,"cancel",{progress,epoch:1,transaction:intent.transaction});assert.equal(canceled.status,"canceled");
  assert.deepEqual(await service.purchase(account,"cancel",{progress,epoch:1,transaction:intent.transaction}),canceled);
  assert.equal(store.docs.get(`users/${account}`)!.gold,5);
});
test("forged/other-account/expired/rollback/forked snapshots never create approval evidence",async()=>{
  const {store,pipeline,head}=await fixture(),signed=envelope(event("reservation",1,String(head.digest)));
  const before=structuredClone([...store.docs]);
  await assert.rejects(pipeline.ingest(account,{...signed,payload:signed.payload.replace('"100"','"999"')}));
  await assert.rejects(pipeline.ingest("other",signed));
  await assert.rejects(pipeline.ingest(account,envelope({...event("reservation",1,String(head.digest)),expiresAtMs:at-1})));
  await assert.rejects(pipeline.ingest(account,envelope(event("reservation",1,"a".repeat(64)))));
  await assert.rejects(pipeline.ingest(account,envelope({...event("checkpoint",0,""),eventId:"rollback_0001"})));
  assert.deepEqual([...store.docs],before);
});
test("signed status alone cannot approve incorrect debit amount or replace a pending checkpoint",async()=>{
  const {pipeline,service,head}=await fixture();
  const reservation=await pipeline.ingest(account,envelope(event("reservation",1,String(head.digest))));
  await service.purchase(account,"reserve",{progress,epoch:1,intent});
  await assert.rejects(pipeline.ingest(account,envelope(event("debit",2,String(reservation.digest),"100"))));
  await assert.rejects(pipeline.ingest(account,envelope(event("checkpoint",2,String(reservation.digest)))));
});
test("issuer keys must be server Ed25519 keys; hash matching is never a signature",async()=>{
  const store=new MemoryStore();
  assert.throws(()=>new ProtectedPurchasePipeline(store,config,{},()=>at));
  const pipeline=new ProtectedPurchasePipeline(store,config,{validator:{pem,notBeforeMs:at-1,notAfterMs:at+900000}},()=>at);
  const signed=envelope(event("checkpoint",0,""));
  await assert.rejects(pipeline.ingest(account,{...signed,signature:createHash("sha512").update(signed.payload).digest("base64url")}));
});

test("audit evidence retains exactly the signed envelope accepted before async CAS",async()=>{
  const {pipeline,store,head}=await fixture();
  const signed=envelope(event("reservation",1,String(head.digest))),payload=signed.payload;
  const inflight=pipeline.ingest(account,signed);signed.payload="tampered after validation";
  await inflight;
  assert.equal(store.docs.get(`users/${account}/workshopProtectionEvents/event_0001`)!.payload,payload);
});

test("signed cancellation before a server hold settles unknown intent without creating a refund",async()=>{
  const {pipeline,store,service,head}=await fixture();
  const reservation=await pipeline.ingest(account,envelope(event("reservation",1,String(head.digest))));
  await pipeline.ingest(account,envelope(event("cancellation",2,String(reservation.digest))));
  const result=await service.purchase(account,"query",{progress,epoch:1,transaction:intent.transaction});
  assert.equal(result.status,"canceled");assert.equal(result.grantId,"");
  assert.deepEqual(await service.purchase(account,"reserve",{progress,epoch:1,intent}),result);
  assert.deepEqual(await service.purchase(account,"commit",{progress,epoch:1,intent}),result);
  assert.equal(store.docs.get(`users/${account}`)!.gold,5);
  assert.equal(store.docs.has(`users/${account}/compositeSkills/tap_1`),false);
});
