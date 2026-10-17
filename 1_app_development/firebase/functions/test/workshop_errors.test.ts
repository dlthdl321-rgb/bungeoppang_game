import { test } from "node:test";
import assert from "node:assert/strict";
import { workshopFailure } from "../src/workshop_errors";
import { ActiveProgressError } from "../src/active_progress";
import { WorkshopEvidenceError } from "../src/workshop_evidence";
import { AlreadyExists } from "../src/store";
test("callable errors expose stable reasons without leaking underlying details",()=>{
  assert.deepEqual(workshopFailure(new AlreadyExists("private path")),{code:"aborted",reason:"transaction-retry",retryable:true});
  assert.equal(workshopFailure(new ActiveProgressError("private state")).retryable,false);
  assert.equal(workshopFailure(new WorkshopEvidenceError("private evidence")).reason,"evidence-required");
  assert.deepEqual(workshopFailure(new Error("private token")),{code:"unavailable",reason:"service-unavailable",retryable:true});
});
