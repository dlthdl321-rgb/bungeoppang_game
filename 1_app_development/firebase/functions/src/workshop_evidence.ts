import { Store } from "./store";
import { PurchaseContext, PurchaseEvidenceVerifier, VerifiedPurchaseEvidence, purchaseFingerprint } from "./composite_purchases";
import { CompositeIntent } from "./development_contracts";
import { SaleRewardVerifier, VerifiedSaleRewardEvidence } from "./sale_rewards";
import { EarnedGoldVerifier } from "./earned_gold";

export class WorkshopEvidenceError extends Error {}
export function evidencePath(account: string, kind: string, id: string): string {
  if (!account || account.includes("/") || account.length > 128 || !/^[a-z]+$/.test(kind) ||
      !/^[A-Za-z0-9_:-]{1,160}$/.test(id)) throw new WorkshopEvidenceError("검증 증거 식별자 오류");
  return `users/${account}/workshopEvidence/${kind}_${id}`;
}
/** These records may ONLY be written by a trusted server validation pipeline.
 * All Firestore client writes are denied. No callable in this change creates
 * or approves such records; client submissions are isolated as untrusted. */
export class StoredWorkshopEvidence implements PurchaseEvidenceVerifier {
  constructor(private readonly store: Store) {}
  async verify(context: PurchaseContext, value: CompositeIntent,
      phase: "reservation" | "debit"): Promise<VerifiedPurchaseEvidence> {
      const row = await this.read(context.account,phase,value.transaction);
      if (row.account !== context.account || row.progress !== context.progress || row.epoch !== context.epoch ||
          row.transaction !== value.transaction || row.phase !== phase || row.fingerprint !== purchaseFingerprint(value) ||
          typeof row.snapshotDigest !== "string" || !row.snapshotDigest || typeof row.availableBuns !== "string" ||
          typeof row.lifetimeBuns !== "string") throw new WorkshopEvidenceError("구매 보호 증거가 없거나 다른 진행입니다.");
      return { account:context.account,progress:context.progress,transaction:value.transaction,phase,
        fingerprint:row.fingerprint,snapshotDigest:row.snapshotDigest,availableBuns:row.availableBuns,lifetimeBuns:row.lifetimeBuns,...(typeof row.level==="number" ? {level:row.level}:{}) };
  }
  sale: SaleRewardVerifier = { verify: async (account,saleId) => {
    const row = await this.optionalRead(account,"sale",saleId);
    if (!row) return { account,saleId,progress:"unverified",revision:"unverified",fingerprint:"unverified",status:"pending",stars:1 };
    if (row.account !== account || row.saleId !== saleId || typeof row.progress !== "string" || !row.progress ||
        typeof row.revision !== "string" || !row.revision || typeof row.fingerprint !== "string" || !row.fingerprint ||
        !["verified","pending","unverifiable"].includes(String(row.status)) ||
        typeof row.stars !== "number" || !Number.isSafeInteger(row.stars) || row.stars < 1 || row.stars > 5) throw new WorkshopEvidenceError("판매 검증 기록 손상");
    return { account,saleId,progress:row.progress,revision:row.revision,fingerprint:row.fingerprint,
      status:row.status as VerifiedSaleRewardEvidence["status"],stars:row.stars };
  } };
  mission: EarnedGoldVerifier = { verify: async (account,claimId) => {
    const row = await this.read(account,"mission",claimId);
    if (row.account !== account || row.claimId !== claimId || row.kind !== "mission" ||
        typeof row.revision !== "string" || !row.revision || typeof row.fingerprint !== "string" || !row.fingerprint ||
        typeof row.gold !== "number" || !Number.isSafeInteger(row.gold) || row.gold <= 0) throw new WorkshopEvidenceError("미션/승급 검증 기록 오류");
    return { account,claimId,kind:"mission",revision:row.revision,fingerprint:row.fingerprint,gold:row.gold };
  } };
  private async optionalRead(account: string,kind: string,id: string) {
    const path = evidencePath(account,kind,id);
    return this.store.run(async tx => {
      const row = await tx.get(path);
      if (!row) return undefined;
      if (row.verifierVersion !== 1 || row.source !== "trustedServerValidation") throw new WorkshopEvidenceError("신뢰된 서버 검증 기록이 아닙니다.");
      return row;
    });
  }
  private async read(account: string,kind: string,id: string) {
    const row = await this.optionalRead(account,kind,id);
    if (!row) throw new WorkshopEvidenceError("서버 보호 증거 확인 대기 중입니다.");
    return row;
  }
}
