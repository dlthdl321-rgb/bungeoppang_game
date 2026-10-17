import { test } from "node:test";
import assert from "node:assert/strict";
import { createPlayPurchases } from "../src/play_purchases";
test("creating callable dependencies does not load the Play SDK or contact a provider",()=>{
  const sdk=require.resolve("googleapis/build/src/apis/androidpublisher");
  assert.equal(require.cache[sdk],undefined);
  const play=createPlayPurchases();
  assert.equal(typeof play.get,"function");assert.equal(typeof play.consume,"function");
  assert.equal(require.cache[sdk],undefined);
});
