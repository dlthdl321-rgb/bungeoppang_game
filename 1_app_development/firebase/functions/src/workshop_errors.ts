import { ProtectedPurchaseError } from "./protected_purchase_pipeline";
import { ActiveProgressError } from "./active_progress";
import { EarnedGoldError } from "./earned_gold";
import { SaleRewardError } from "./sale_rewards";
import { CompositePurchaseError } from "./composite_purchases";
import { DevelopmentContractError } from "./development_contracts";
import { WorkshopEvidenceError } from "./workshop_evidence";
import { WorkshopServiceError } from "./workshop_service";
import { WorkshopAdError } from "./workshop_ads";
import { AlreadyExists } from "./store";
/** Stable, non-sensitive callable contract. Unknown infrastructure failures are retryable. */
export function workshopFailure(error: unknown) {
  if (error instanceof AlreadyExists) return {code:"aborted" as const,reason:"transaction-retry",retryable:true};
  if (error instanceof WorkshopEvidenceError) return {code:"failed-precondition" as const,reason:"evidence-required",retryable:false};
  if (error instanceof WorkshopServiceError) return {code:"failed-precondition" as const,reason:"request-or-evidence-required",retryable:false};
  if (error instanceof ProtectedPurchaseError || error instanceof CompositePurchaseError || error instanceof DevelopmentContractError || error instanceof WorkshopAdError || error instanceof ActiveProgressError || error instanceof EarnedGoldError || error instanceof SaleRewardError) {
    return {code:"failed-precondition" as const,reason:"state-check-required",retryable:false};
  }
  return {code:"unavailable" as const,reason:"service-unavailable",retryable:true};
}
