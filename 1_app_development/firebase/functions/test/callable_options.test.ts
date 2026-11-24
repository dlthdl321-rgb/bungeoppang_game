import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { callableOptions } from "../src/callable_options";

test("App Check is enforced unless APP_CHECK_ENFORCED is exactly false", () => {
  assert.deepEqual(callableOptions({}), { region: "asia-northeast3", enforceAppCheck: true });
  assert.equal(callableOptions({ APP_CHECK_ENFORCED: "true" }).enforceAppCheck, true);
  assert.equal(callableOptions({ APP_CHECK_ENFORCED: "" }).enforceAppCheck, true);
  assert.equal(callableOptions({ APP_CHECK_ENFORCED: "FALSE" }).enforceAppCheck, true);
  assert.equal(callableOptions({ APP_CHECK_ENFORCED: "false" }).enforceAppCheck, false);
});

test("every callable in index.ts uses the shared App Check options", () => {
  // Compiled to lib/test, so the source is two folders up.
  const source = readFileSync(join(__dirname, "..", "..", "src", "index.ts"), "utf8");
  assert.doesNotMatch(source, /enforceAppCheck\s*:\s*false/);
  const calls = source.match(/onCall\(([^,]+),/g) ?? [];
  assert.ok(calls.length >= 20, `found ${calls.length} callables`);
  for (const call of calls) assert.equal(call.replace(/\s/g, ""), "onCall(options,", call);
  assert.match(source, /const options = callableOptions\(\);/);
});
