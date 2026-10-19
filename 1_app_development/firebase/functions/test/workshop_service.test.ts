import assert from "node:assert/strict";
import { test } from "node:test";
import config from "../src/generated/development_balance.json";
import { MemoryStore } from "../src/store";
import { WorkshopService, rewardFingerprint } from "../src/workshop_service";
import { evidencePath } from "../src/workshop_evidence";
import { purchaseFingerprint } from "../src/composite_purchases";
import { acceptWorkshopSsv, WorkshopSsvVerifier } from "../src/workshop_ads";
const at=Date.UTC(2026,9,16,14,59,59),key=new Uint8Array(32).fill(8);
async function setup() {
  const store=new MemoryStore(),service=new WorkshopService(store,config,()=>at,key);
  await service.claim("a",{progress:"progress_0001"});return {store,service};
}
const intent={account:"a",transaction:"transaction_0001",revision:config.metadata.revision,
  skill:"tap_1",owned:0,quantity:1,buns:"15",gold:"1"};
const context={progress:"progress_0001",epoch:1};
test("클라이언트 차감 JSON만으로는 황금 홀드/상품 지급이 열리지 않는다",async()=>{
  const {store,service}=await setup();store.docs.set("users/a",{gold:5});
  await assert.rejects(service.purchase("a","reserve",{...context,intent,debited:true,verified:true}));
  assert.equal(store.docs.get("users/a")!.gold,5);
});
test("서버 승인 증거와 활성 진행이 맞을 때만 복합 결제가 연결된다",async()=>{
  const {store,service}=await setup();store.docs.set("users/a",{gold:5});
  const proof={source:"trustedServerValidation",verifierVersion:1,account:"a",progress:context.progress,epoch:1,
    transaction:intent.transaction,fingerprint:purchaseFingerprint(intent),snapshotDigest:"protected",availableBuns:"100",lifetimeBuns:"100"};
  store.docs.set(evidencePath("a","reservation",intent.transaction),{...proof,phase:"reservation"});
  await service.purchase("a","reserve",{...context,intent});
  store.docs.set(evidencePath("a","debit",intent.transaction),{...proof,phase:"debit"});
  const committed=await service.purchase("a","commit",{...context,intent});
  assert.equal(committed.status,"committed");
  assert.deepEqual(await service.purchase("a","query",{...context,transaction:intent.transaction}),committed);
  assert.equal(store.docs.get("users/a")!.gold,4);
});
test("검증 안 된 보상 제출은 저장만 하며 클라이언트 보상량을 지급하지 않는다",async()=>{
  const {store,service}=await setup();
  const data={...context,claim:"progress_0001:level:2",kind:"mission",payload:{level:2,gold:999999}};
  assert.equal((await service.reward("a",data,true)).outcome,"pending");
  assert.equal(store.docs.has("users/a"),false);
  await assert.rejects(service.reward("a",{...data,payload:{level:2,gold:1}},true));
});
test("지급 뒤 검증 기록이 없어져도 원 지급 원장에서 수신 복구한다",async()=>{
  const {store,service}=await setup(),claim="progress_0001:level:2",payload={level:2,gold:1};
  const fingerprint=rewardFingerprint("a",context.progress,claim,"mission",payload);
  const path=evidencePath("a","mission",claim);
  store.docs.set(path,{source:"trustedServerValidation",verifierVersion:1,account:"a",progress:context.progress,
    claimId:claim,kind:"mission",revision:config.metadata.revision,fingerprint,gold:1});
  const data={...context,claim,kind:"mission",payload};
  const first=await service.reward("a",data,true);assert.equal(first.outcome,"eligible");
  store.docs.delete(path);
  assert.deepEqual(await service.reward("a",data,false),first);
  assert.equal(store.docs.get("users/a")!.gold,1);
});
test("AdMob 서명 검증 adapter와 광고단위 allowlist가 없으면 지급하지 않는다",async()=>{
  const {store,service}=await setup(),attempt="attempt_0001";
  const start=await service.adStart("a",{attempt});
  assert.equal((await service.adQuery("a",{attempt})).paid,false);
  const verifier:WorkshopSsvVerifier={verify:async()=>({provider:"admob",transaction:"provider-1",adUnit:"unit-1",customData:start.customData})};
  await assert.rejects(acceptWorkshopSsv(store,verifier,"signed-query",new Set(),()=>at+2000));
  assert.equal(store.docs.has("users/a"),false);
  const paid=await acceptWorkshopSsv(store,verifier,"signed-query",new Set(["unit-1"]),()=>at+2000);
  assert.equal(paid.paid,true);assert.equal(paid.day,"2026-10-16");
  await acceptWorkshopSsv(store,verifier,"signed-query",new Set(["unit-1"]),()=>at+86400000);
  assert.equal(store.docs.get("users/a")!.gold,config.rewarded_ads.gold_per_verified_view);
});
test("3번째 광고 승인과 다른 시도에서의 provider 거래 재사용은 지급하지 않는다",async()=>{
  const {store,service}=await setup();
  const a=await service.adStart("a",{attempt:"attempt_0001"});
  const b=await service.adStart("a",{attempt:"attempt_0002"});
  await assert.rejects(service.adStart("a",{attempt:"attempt_0003"}));
  const verifier=(token:string):WorkshopSsvVerifier=>({verify:async()=>({provider:"admob",transaction:"same-provider-id",adUnit:"unit",customData:token})});
  await acceptWorkshopSsv(store,verifier(a.customData),"signed",new Set(["unit"]),()=>at);
  await assert.rejects(acceptWorkshopSsv(store,verifier(b.customData),"signed",new Set(["unit"]),()=>at));
  assert.equal(store.docs.get("users/a")!.gold,config.rewarded_ads.gold_per_verified_view);
});

test("진행 이전은 검증된 증거가 있어도 미정산 구매 잠금이 생기면 차단한다",async()=>{
  const {store,service}=await setup(),request="transfer_0001",target="progress_0002";
  store.docs.set(evidencePath("a","transfer",request),{source:"trustedServerValidation",verifierVersion:1,account:"a",
    from:context.progress,to:target,sourceEpoch:1,snapshotDigest:"protected-target",protectionDigest:"protected-journal",pendingResolved:true});
  store.docs.set("users/a/compositeState/pending",{transaction:"pending-purchase"});
  await assert.rejects(service.transfer("a",{request,target}));
  store.docs.set("users/a/compositeState/pending",{transaction:null});
  const result=await service.transfer("a",{request,target});
  assert.equal(result.progressId,target);assert.equal(result.epoch,2);
});

test("아바타 구매도 서버 가격·레벨·보유 회차와 승인 증거를 함께 검사한다",async()=>{
  const {store,service}=await setup();store.docs.set("users/a",{gold:10});
  const cosmetic={...intent,transaction:"cosmetic_0001",skill:"cosmetic:short",buns:config.cosmetic_purchase.short.buns,
    gold:String(config.cosmetic_purchase.short.gold)};
  const proof={source:"trustedServerValidation",verifierVersion:1,account:"a",progress:context.progress,epoch:1,
    transaction:cosmetic.transaction,fingerprint:purchaseFingerprint(cosmetic),snapshotDigest:"protected",
    availableBuns:"2000",lifetimeBuns:"2000",phase:"reservation",level:0};
  const path=evidencePath("a","reservation",cosmetic.transaction);
  store.docs.set(path,proof);
  await assert.rejects(service.purchase("a","reserve",{...context,intent:cosmetic}));
  store.docs.set(path,{...proof,level:50});
  await service.purchase("a","reserve",{...context,intent:cosmetic});
  store.docs.set(evidencePath("a","debit",cosmetic.transaction),{...proof,phase:"debit",level:50});
  await service.purchase("a","commit",{...context,intent:cosmetic});
  assert.equal(store.docs.get("users/a/compositeSkills/cosmetic:short")!.owned,1);
});

test("다른 진행 ID로 같은 일일 목표를 제출해도 계정별 지급을 복제하지 않는다",async()=>{
  const {store,service}=await setup(),payload={scope:"daily",period:"2026-10-16",goal:"taps",gold:1};
  for(const progress of ["progress_0001","progress_0002"]) {
    const claim=`${progress}:mission:daily:2026-10-16:taps`;
    store.docs.set(evidencePath("a","mission",claim),{source:"trustedServerValidation",verifierVersion:1,account:"a",progress,
      claimId:claim,kind:"mission",revision:config.metadata.revision,fingerprint:rewardFingerprint("a",progress,claim,"mission",payload),gold:1});
    const result=await service.reward("a",{progress,claim,kind:"mission",payload},true);
    assert.equal(result.outcome,progress==="progress_0001" ? "eligible":"unverifiable");
  }
  assert.equal(store.docs.get("users/a")!.gold,1);
});


test("purchase retries recover the journal without re-reading expired evidence",async()=>{
  const {store,service}=await setup();store.docs.set("users/a",{gold:5});
  const proof={source:"trustedServerValidation",verifierVersion:1,account:"a",progress:context.progress,epoch:1,
    transaction:intent.transaction,fingerprint:purchaseFingerprint(intent),snapshotDigest:"protected",availableBuns:"100",lifetimeBuns:"100"};
  const reservation=evidencePath("a","reservation",intent.transaction),debit=evidencePath("a","debit",intent.transaction);
  store.docs.set(reservation,{...proof,phase:"reservation"});
  const reserved=await service.purchase("a","reserve",{...context,intent});
  store.docs.delete(reservation);
  assert.deepEqual(await service.purchase("a","reserve",{...context,intent}),reserved);
  await assert.rejects(service.purchase("a","cancel",{...context,transaction:intent.transaction}));
  assert.equal(store.docs.get("users/a")!.gold,4);
  store.docs.set(debit,{...proof,phase:"debit"});
  const result=await service.purchase("a","commit",{...context,intent});store.docs.delete(debit);
  assert.deepEqual(await service.purchase("a","commit",{...context,intent}),result);
  await assert.rejects(service.purchase("a","reserve",{...context,intent:{...intent,gold:"2"}}));
  assert.equal(store.docs.get("users/a")!.gold,4);
});

test("trusted fenced cancellation refunds once and wins over late commit",async()=>{
  const {store,service}=await setup();store.docs.set("users/a",{gold:5});
  const proof={source:"trustedServerValidation",verifierVersion:1,account:"a",progress:context.progress,epoch:1,
    transaction:intent.transaction,fingerprint:purchaseFingerprint(intent),snapshotDigest:"protected",availableBuns:"100",lifetimeBuns:"100",phase:"reservation"};
  store.docs.set(evidencePath("a","reservation",intent.transaction),proof);
  await service.purchase("a","reserve",{...context,intent});
  store.docs.set(evidencePath("a","cancellation",intent.transaction),{...proof,debitFenced:true,localDebitRestored:true});
  const result=await service.purchase("a","cancel",{...context,transaction:intent.transaction});
  assert.equal(result.status,"canceled");
  assert.deepEqual(await service.purchase("a","cancel",{...context,transaction:intent.transaction}),result);
  assert.deepEqual(await service.purchase("a","commit",{...context,intent}),result);
  assert.equal(store.docs.get("users/a")!.gold,5);
});


test("SSV accepted before wallet failure is recoverable by query across KST midnight",async()=>{
  const {store,service}=await setup();
  const start=await service.adStart("a",{attempt:"recover_0001"});
  store.docs.set("users/a",{gold:Number.MAX_SAFE_INTEGER});
  const verifier:WorkshopSsvVerifier={verify:async()=>({provider:"admob",transaction:"recover-proof",adUnit:"unit",customData:start.customData})};
  await assert.rejects(acceptWorkshopSsv(store,verifier,"signed",new Set(["unit"]),()=>at+2000));
  store.docs.set("users/a",{gold:0});
  const later=new WorkshopService(store,config,()=>at+86400000,key);
  const paid=await later.adQuery("a",{attempt:"recover_0001"});
  assert.equal(paid.paid,true);assert.equal(paid.day,"2026-10-16");
  assert.equal((await later.adQuery("a",{attempt:"recover_0001"})).paid,true);
  assert.equal(store.docs.get("users/a")!.gold,config.rewarded_ads.gold_per_verified_view);
  const next=await later.adStart("a",{attempt:"recover_0002"});assert.equal(next.day,"2026-10-17");
  assert.equal((await later.adStart("a",{attempt:"recover_0001"})).day,"2026-10-16");
});
