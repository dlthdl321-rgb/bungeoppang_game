import { test } from "node:test";
import assert from "node:assert/strict";
import { generateKeyPairSync, sign } from "node:crypto";
import { AdMobSsvVerifier } from "../src/admob_ssv";
const {publicKey,privateKey}=generateKeyPairSync("ec",{namedCurve:"prime256v1"});
const pem=publicKey.export({type:"spki",format:"pem"}).toString();
const content=`ad_unit=unit%2F1&custom_data=${"a".repeat(64)}&transaction_id=abcdef`;
const signed=(s=content,key="1")=>`${s}&signature=${sign("sha256",Buffer.from(s),privateKey).toString("base64url")}&key_id=${key}`;
test("SSV verifies original bytes and rejects tampering, duplicate fields and wrong keys",async()=>{
  const verifier=new AdMobSsvVerifier(async()=>({keys:[{keyId:1,pem}]}));
  assert.equal((await verifier.verify(signed())).adUnit,"unit/1");
  for(const query of [signed().replace("unit%2F1","unit%2F2"),signed()+"&x=1",signed(content+"&ad_unit=evil"),signed(content,"2"),signed().replace("signature=","signature=%GG")]) {
    await assert.rejects(verifier.verify(query));
  }
});
test("key cache expires and key service failure never approves a callback",async()=>{
  let now=0,calls=0;
  const verifier=new AdMobSsvVerifier(async()=>{calls++;if(calls>1) throw new Error("offline");return {keys:[{keyId:1,pem}]};},()=>now);
  await verifier.verify(signed());await verifier.verify(signed());assert.equal(calls,1);
  now=24*60*60*1000;await assert.rejects(verifier.verify(signed()));assert.equal(calls,2);
});
