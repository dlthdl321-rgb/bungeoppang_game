import { createHash } from "node:crypto";
import { Store } from "./store";
import { VerifiedEarnedGold } from "./earned_gold";
export class WorkshopMissionError extends Error {}
/** Account+goal/period is the payout identity, independent of device progress.
 * Transferring/reinstalling must not pay the same daily/weekly/level again. */
function semantic(payload:Record<string,unknown>):string {
  if (Number.isSafeInteger(payload.level) && (payload.level as number)>=2 && (payload.level as number)<=50) return `level:${payload.level}`;
  const scope=payload.scope,period=payload.period,goal=payload.goal;
  const allowed=scope==="daily" ? ["taps","production","purchases","auto","all"]:
    scope==="weekly" ? ["taps","days","purchases","dailyAll"]:[];
  if(typeof period!=="string" || !/^\d{4}-\d{2}-\d{2}$/.test(period) ||
      !Number.isFinite(Date.parse(`${period}T00:00:00Z`)) || new Date(`${period}T00:00:00Z`).toISOString().slice(0,10)!==period ||
      (scope==="weekly" && new Date(`${period}T00:00:00Z`).getUTCDay()!==1) || typeof goal!=="string" || !allowed.includes(goal)) {
    throw new WorkshopMissionError("미션 지급 대상 형식 오류");
  }
  return `${scope}:${period}:${goal}`;
}
export async function creditWorkshopMission(store:Store,verified:VerifiedEarnedGold,payload:Record<string,unknown>,serverNowMs:number) {
  if(verified.kind!=="mission" || !verified.account || verified.account.includes("/") || !verified.claimId ||
      !verified.revision || !verified.fingerprint || !Number.isSafeInteger(verified.gold) || verified.gold<=0 ||
      !Number.isSafeInteger(serverNowMs) || serverNowMs<0) throw new WorkshopMissionError("미션 지급 검증 결과 오류");
  const goal=semantic(payload),base=`users/${verified.account}`;
  const identity=createHash("sha256").update(goal).digest("hex");
  const claim=createHash("sha256").update(JSON.stringify(["mission",verified.claimId])).digest("hex");
  return store.run(async tx=>{
    const lockPath=`${base}/workshopMissionClaims/${identity}`,ledgerPath=`${base}/ledger/earned_${claim}`;
    const old=await tx.get(lockPath),ledger=await tx.get(ledgerPath),wallet=await tx.get(base);
    if(old) {
      if(old.claimId!==verified.claimId) return {outcome:"unverifiable",gold:0};
      if(!ledger || old.fingerprint!==verified.fingerprint || old.gold!==verified.gold) throw new WorkshopMissionError("미션 지급 원장 충돌");
      for(const field of ["account","claimId","kind","revision","fingerprint","gold"] as const) {
        if(ledger[field]!==verified[field]) throw new WorkshopMissionError("미션 지급 영수증 불일치");
      }
      return {outcome:"eligible",gold:verified.gold};
    }
    if(ledger) throw new WorkshopMissionError("미션 지급 원장 보호 기록 재대조 필요");
    const balance=wallet?.gold ?? 0;
    if(typeof balance!=="number" || !Number.isSafeInteger(balance) || balance<0 ||
        BigInt(balance)+BigInt(verified.gold)>BigInt(Number.MAX_SAFE_INTEGER)) throw new WorkshopMissionError("황금 지갑 범위 오류");
    tx.set(base,{...wallet,gold:balance+verified.gold});
    tx.create(ledgerPath,{...verified,type:"missionGold",delta:verified.gold,atMs:serverNowMs});
    tx.create(lockPath,{claimId:verified.claimId,fingerprint:verified.fingerprint,gold:verified.gold,goal});
    return {outcome:"eligible",gold:verified.gold};
  });
}
