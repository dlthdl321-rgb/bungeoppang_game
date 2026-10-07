import catalogJson from "./catalog.json";

// The price list shared with the app. catalog.json is written from the Dart
// config (lib/premium_config.dart) by test/premium_catalog_test.dart, so the
// app and the server can never disagree on a price.

export type SpendKind = "cosmetic" | "skill" | "boost";

export interface Product {
  id: string;
  gold: number;
}

export interface Catalog {
  version: string;
  packageName: string;
  products: Product[];
  spend: Record<SpendKind, Record<string, number>>;
}

/** Boosts are used up; cosmetics and skill unlocks are owned for good. */
export const isConsumable = (kind: SpendKind) => kind === "boost";

export const catalog: Catalog = catalogJson as Catalog;
