import { createPublicKey, KeyObject, verify } from "node:crypto";
import { WorkshopAdError, WorkshopSsvVerifier, VerifiedAdMobSsv } from "./workshop_ads";
const KEY_URL="https://www.gstatic.com/admob/reward/verifier-keys.json";
const TTL=23*60*60*1000;
export class AdMobKeyUnavailable extends Error {}
/** Fixed HTTPS trust source; never fetch a URL supplied by the callback. */
export async function fetchAdMobKeys():Promise<unknown> {
  try {
    const response=await fetch(KEY_URL,{redirect:"error",signal:AbortSignal.timeout(5000)});
    if (!response.ok) throw new Error();
    const text=await response.text();
    if (text.length>65536) throw new Error();
    return JSON.parse(text);
  } catch { throw new AdMobKeyUnavailable("AdMob key service unavailable"); }
}
/** Verify original escaped query bytes, ECDSA SHA256 DER. No client fallback.
 * Loader injection is only for deterministic crypto tests, never request data. */
export class AdMobSsvVerifier implements WorkshopSsvVerifier {
  private keys=new Map<string,KeyObject>();
  private expires=0;
  constructor(private readonly load:()=>Promise<unknown>=fetchAdMobKeys,private readonly clock:()=>number=Date.now) {}
  private async key(id:string):Promise<KeyObject> {
    if(this.clock()>=this.expires || !this.keys.has(id)) {
      const raw=await this.load() as {keys?:Array<{keyId:unknown;pem:unknown}>};
      const next=new Map<string,KeyObject>();
      try {
        if(!Array.isArray(raw.keys) || raw.keys.length===0 || raw.keys.length>100) throw new Error();
        for(const row of raw.keys) {
          if(typeof row.keyId!=="number" || !Number.isSafeInteger(row.keyId) || row.keyId<0 || typeof row.pem!=="string" || next.has(String(row.keyId))) throw new Error();
          const key=createPublicKey(row.pem);
          if(key.asymmetricKeyType!=="ec" || key.asymmetricKeyDetails?.namedCurve!=="prime256v1") throw new Error();
          next.set(String(row.keyId),key);
        }
      } catch { throw new AdMobKeyUnavailable("Invalid AdMob key set"); }
      this.keys=next;this.expires=this.clock()+TTL;
    }
    const key=this.keys.get(id);
    if(!key) throw new WorkshopAdError("Unknown SSV signing key");
    return key;
  }
  async verify(rawQuery:string):Promise<VerifiedAdMobSsv> {
    if(typeof rawQuery!=="string" || rawQuery.length>16384 || /[^\x21-\x7e]/.test(rawQuery) || /%(?![a-fA-F0-9]{2})/.test(rawQuery)) throw new WorkshopAdError("Invalid SSV query");
    const match=/^(.+)&signature=([A-Za-z0-9_%-]+={0,2})&key_id=(0|[1-9][0-9]*)$/.exec(rawQuery);
    if(!match) throw new WorkshopAdError("Invalid SSV signature envelope");
    const params=new URLSearchParams(rawQuery),seen=new Set<string>();
    for(const [name] of params) {
      if(seen.has(name)) throw new WorkshopAdError("Duplicate SSV parameter");
      seen.add(name);
    }
    const signature=decodeURIComponent(match[2]);
    if(!/^[A-Za-z0-9_-]+={0,2}$/.test(signature)) throw new WorkshopAdError("Invalid SSV signature encoding");
    if(!verify("sha256",Buffer.from(match[1],"utf8"),await this.key(match[3]),Buffer.from(signature,"base64url"))) throw new WorkshopAdError("Invalid SSV signature");
    const transaction=params.get("transaction_id")??"",adUnit=params.get("ad_unit")??"",customData=params.get("custom_data")??"";
    if(!/^[a-fA-F0-9]{1,256}$/.test(transaction) || !adUnit || !/^[a-f0-9]{64}$/.test(customData)) throw new WorkshopAdError("Invalid SSV attribution");
    return {provider:"admob",transaction,adUnit,customData};
  }
}
