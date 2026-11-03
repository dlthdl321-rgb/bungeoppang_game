import assert from "node:assert/strict";
import { test } from "node:test";
import config from "../src/generated/development_balance.json";
import { MemoryStore } from "../src/store";
import { WorkshopService } from "../src/workshop_service";
import { PlausibilityValidator } from "../src/plausibility_validator";

const start=Date.UTC(2026,9,16,3,0,0); // KST 2026-10-16 12:00
const progress="progress_0001",context={progress,epoch:1};
function setup() {
  const store=new MemoryStore(),clock={now:start};
  const service=new WorkshopService(store,config,()=>clock.now,new Uint8Array(32).fill(8),{
    validator:new PlausibilityValidator(store,config,()=>clock.now),welcomeGold:config.welcome_reward.gold});
  return {store,service,clock};
}
const snapshot=(buns:string,lifetimeBuns:string,taps=0,sales=0,level=1)=>({buns,lifetimeBuns,level,taps,sales});
function intent(transaction="transaction_0001",owned=0) {
  return {account:"a",transaction,revision:config.metadata.revision,skill:"tap_1",owned,quantity:1,buns:owned ? "18":"15",gold:"1"};
}
function daily(goal:"taps"|"production",value:string,extra:Record<string,unknown>={}) {
  const row=config.mission_targets.daily[goal];
  return {requirements:{[goal]:{metric:row.metric,target:row.target}},scope:"daily",period:"2026-10-16",goal,
    revision:config.metadata.revision,gold:config.mission_gold_rewards[row.reward_key as keyof typeof config.mission_gold_rewards],
    progress:{[goal]:value},...extra};
}
const gold=(store:MemoryStore)=>Number(store.docs.get("users/a")!.gold);

test("첫 진행 등록에 환영 황금을 계정당 한 번만 서버 지갑에 지급한다",async()=>{
  const {store,service}=setup();
  await service.claim("a",{progress});await service.claim("a",{progress});
  assert.equal(gold(store),config.welcome_reward.gold);
  assert.equal(store.docs.get("users/a/ledger/welcome_v1")!.gold,config.welcome_reward.gold);
});
test("타당한 스냅샷이면 예약·차감·확정까지 서버 검증으로 스킬을 산다",async()=>{
  const {store,service,clock}=setup();await service.claim("a",{progress});
  const reserved=await service.purchase("a","reserve",{...context,intent:intent(),snapshot:snapshot("40","40",40)});
  assert.equal(reserved.status,"reserved");assert.equal(gold(store),config.welcome_reward.gold-1);
  clock.now+=2000;
  const committed=await service.purchase("a","commit",{...context,intent:intent(),snapshot:snapshot("25","40",40)});
  assert.equal(committed.status,"committed");
  assert.equal(store.docs.get("users/a/compositeSkills/tap_1")!.owned,1);
  // Retry replays the terminal receipt without new evidence.
  assert.deepEqual(await service.purchase("a","commit",{...context,intent:intent(),snapshot:snapshot("0","40",40)}),committed);
});
test("차감하지 않은 스냅샷으로는 구매를 확정하지 않는다",async()=>{
  const {service}=setup();await service.claim("a",{progress});
  await service.purchase("a","reserve",{...context,intent:intent(),snapshot:snapshot("40","40",40)});
  await assert.rejects(service.purchase("a","commit",{...context,intent:intent(),snapshot:snapshot("40","40",40)}));
});
test("서버 시간으로 설명할 수 없는 붕어빵력 증가는 거절하고, 시간이 지나면 허용한다",async()=>{
  const {service,clock}=setup();await service.claim("a",{progress});
  await service.purchase("a","reserve",{...context,intent:intent(),snapshot:snapshot("40","40",40)});
  await service.purchase("a","commit",{...context,intent:intent(),snapshot:snapshot("25","40",40)});
  const second={...context,intent:intent("transaction_0002",1)};
  await assert.rejects(service.purchase("a","reserve",{...second,snapshot:snapshot("900000","900000",40)}));
  // 2 taps/s for 10 minutes at tap rate 2 is plausible.
  clock.now+=600000;
  assert.equal((await service.purchase("a","reserve",{...second,snapshot:snapshot("2425","2440",1240)})).status,"reserved");
});
test("진행 기록이 줄어든 스냅샷은 거절한다",async()=>{
  const {service}=setup();await service.claim("a",{progress});
  await service.purchase("a","reserve",{...context,intent:intent(),snapshot:snapshot("40","40",40)});
  await assert.rejects(service.purchase("a","commit",{...context,intent:intent(),snapshot:snapshot("25","30",40)}));
});
test("붕어빵력이 부족해 거절된 예약은 무과금 취소 기록으로 정리된다",async()=>{
  const {store,service}=setup();await service.claim("a",{progress});
  await assert.rejects(service.purchase("a","reserve",{...context,intent:intent(),snapshot:snapshot("5","5",5)}));
  const canceled=await service.purchase("a","cancel",{...context,transaction:"transaction_0001",intent:intent()});
  assert.equal(canceled.status,"canceled");assert.equal(canceled.grantId,"");
  assert.equal(gold(store),config.welcome_reward.gold);
  // A delayed reserve for the fenced transaction cannot hold gold afterwards.
  assert.equal((await service.purchase("a","reserve",{...context,intent:intent(),snapshot:snapshot("40","40",40)})).status,"canceled");
  assert.equal(gold(store),config.welcome_reward.gold);
});
test("예약된 구매의 취소는 황금을 돌려주고 스킬을 지급하지 않는다",async()=>{
  const {store,service}=setup();await service.claim("a",{progress});
  await service.purchase("a","reserve",{...context,intent:intent(),snapshot:snapshot("40","40",40)});
  const canceled=await service.purchase("a","cancel",{...context,transaction:"transaction_0001",intent:intent()});
  assert.equal(canceled.status,"canceled");assert.equal(gold(store),config.welcome_reward.gold);
  assert.equal(store.docs.has("users/a/compositeSkills/tap_1"),false);
});
test("달성한 일일 미션은 서버 검증 후 정해진 황금만 한 번 지급한다",async()=>{
  const {store,service}=setup();await service.claim("a",{progress});
  const data={...context,claim:`${progress}:mission:daily:2026-10-16:taps`,kind:"mission",payload:daily("taps","50"),snapshot:snapshot("50","50",50)};
  const first=await service.reward("a",data,true);
  assert.equal(first.outcome,"eligible");assert.equal(first.gold,1);
  assert.deepEqual(await service.reward("a",data,true),first);
  assert.equal(gold(store),config.welcome_reward.gold+1);
});
test("보상량·기간·진행량이 맞지 않는 미션은 지급 없이 확정 거절한다",async()=>{
  const {store,service,clock}=setup();await service.claim("a",{progress});
  const claim=(goal:string)=>`${progress}:mission:daily:2026-10-16:${goal}`;
  const wrongGold=await service.reward("a",{...context,claim:claim("taps"),kind:"mission",payload:daily("taps","50",{gold:99}),snapshot:snapshot("50","50",50)},true);
  assert.equal(wrongGold.outcome,"unverifiable");
  const tooManyTaps=await service.reward("a",{...context,claim:claim("production"),kind:"mission",payload:daily("production","5000"),snapshot:snapshot("50","50",50)},true);
  assert.equal(tooManyTaps.outcome,"unverifiable");
  clock.now+=(config.server_validation.mission_claim_grace_days+1)*86400000;
  const late=await service.reward("a",{...context,claim:`${progress}:late`,kind:"mission",payload:daily("taps","50"),snapshot:snapshot("50","50",50)},true);
  assert.equal(late.outcome,"unverifiable");
  assert.equal(gold(store),config.welcome_reward.gold);
});
test("판매 보상은 판매 기록 수 안에서만 검증하고 서버 추첨으로 결정한다",async()=>{
  const {store,service}=setup();await service.claim("a",{progress});
  const sale=(id:string)=>({fingerprint:"local",evidence:{order:{id},products:[{batch:"b",flavor:"redbean"}],revision:config.metadata.revision,stars:5,scorePermille:900,ordinaryBuns:"60",businessIndex:1}});
  const first=await service.reward("a",{...context,claim:"order_0001",kind:"sale",payload:sale("order_0001"),snapshot:snapshot("60","60",30,1)},true);
  assert.ok(["eligible","noWin"].includes(String(first.outcome)));
  const extra=await service.reward("a",{...context,claim:"order_0002",kind:"sale",payload:sale("order_0002"),snapshot:snapshot("60","60",30,1)},true);
  assert.equal(extra.outcome,"unverifiable");
  assert.ok(gold(store)<=config.welcome_reward.gold+1);
});
test("스냅샷 없는 보상 제출은 기존처럼 대기로 남는다",async()=>{
  const {service}=setup();await service.claim("a",{progress});
  const data={...context,claim:`${progress}:mission:daily:2026-10-16:taps`,kind:"mission",payload:daily("taps","50")};
  assert.equal((await service.reward("a",data,true)).outcome,"pending");
});
