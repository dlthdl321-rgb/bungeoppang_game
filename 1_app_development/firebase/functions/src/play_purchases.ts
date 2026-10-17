import type { androidpublisher_v3 } from "googleapis/build/src/apis/androidpublisher/v3";
import type { PlayPurchases } from "./wallet";
import { catalog } from "./catalog";
/** Keep billing SDK initialization out of function discovery and unrelated calls.
 * The service account still needs Play Console financial/order permissions. */
export function createPlayPurchases():PlayPurchases {
  let publisher:Promise<androidpublisher_v3.Androidpublisher>|undefined;
  const api=()=>publisher??=import("googleapis/build/src/apis/androidpublisher").then(({androidpublisher,auth})=>
    androidpublisher({version:"v3",auth:new auth.GoogleAuth({scopes:["https://www.googleapis.com/auth/androidpublisher"]})}));
  return {
    async get(productId,token) {
      const {data}=await (await api()).purchases.products.get({packageName:catalog.packageName,productId,token});
      return {purchaseState:data.purchaseState??1,consumptionState:data.consumptionState??0,orderId:data.orderId??""};
    },
    async consume(productId,token) {
      await (await api()).purchases.products.consume({packageName:catalog.packageName,productId,token});
    },
  };
}
