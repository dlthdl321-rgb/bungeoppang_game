import { createHash } from "node:crypto";
import { Store } from "./store";
import { queryDevelopmentAd, recordDevelopmentAdVerification } from "./development_contracts";
import { creditVerifiedEarnedGold } from "./earned_gold";

export class WorkshopAdError extends Error {}
export interface VerifiedAdMobSsv {
  provider:"admob"; transaction:string; adUnit:string; customData:string;
}
/** Implement with the installed AdMob specification: original signed query
 * bytes, trusted current public keys, signature/key ID and issuer checks.
 * No implementation or HTTP callback is enabled until SDK/official review. */
export interface WorkshopSsvVerifier { verify(rawQuery:string):Promise<VerifiedAdMobSsv> }
export async function creditWorkshopAd(store:Store,account:string,attempt:string,clock:()=>number):Promise<Record<string,unknown>> {
  const record=await queryDevelopmentAd(store,account,attempt);
  if (!record) return {account,attempt,status:"unknown"};
  if (record.status!=="verified") return {...record,paid:false};
  const fingerprint=JSON.stringify([account,attempt,record.revision,record.providerProofKey]);
  await creditVerifiedEarnedGold(store,{verify:async()=>({account,claimId:attempt,kind:"rewardedAd",
    revision:record.revision,fingerprint,gold:record.gold})},account,attempt,clock());
  return {...record,receiptId:`rewardedAd_${attempt}`,paid:true};
}
/** Only the verified SDK adapter supplies raw signed bytes. Completion and
 * dismiss callbacks from the app never call this function or mark verified. */
export async function acceptWorkshopSsv(store:Store,verifier:WorkshopSsvVerifier,rawQuery:string,
    allowedAdUnits:ReadonlySet<string>,clock:()=>number) {
  const proof={...await verifier.verify(rawQuery)};
  if (proof.provider!=="admob" || !proof.transaction || !allowedAdUnits.has(proof.adUnit) ||
      !/^[a-f0-9]{64}$/.test(proof.customData)) throw new WorkshopAdError("광고 서버 검증 대상 오류");
  const digest=createHash("sha256").update(proof.customData).digest("hex");
  const token=await store.run(tx=>tx.get(`workshopAdTokenIndex/${digest}`));
  if (!token || typeof token.account!=="string" || typeof token.attempt!=="string" || typeof token.revision!=="string") {
    throw new WorkshopAdError("광고 시작 승인 근거가 없습니다.");
  }
  await recordDevelopmentAdVerification(store,token.account,token.attempt,"eligible",{
    provider:"admob",transaction:proof.transaction,account:token.account,attempt:token.attempt,revision:token.revision });
  return creditWorkshopAd(store,token.account,token.attempt,clock);
}
