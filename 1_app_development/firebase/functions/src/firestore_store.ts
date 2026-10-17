import { Firestore } from "firebase-admin/firestore";
import { Store, Tx, Doc } from "./store";
/** Shared production adapter. Real Firestore retries provide CAS serialization. */
export function firestoreStore(fs:Firestore):Store {
  return {
    run:fn=>fs.runTransaction(async t=>{
      const tx:Tx={get:async path=>(await t.get(fs.doc(path))).data() as Doc|undefined,
        create:(path,data)=>void t.create(fs.doc(path),data),set:(path,data)=>void t.set(fs.doc(path),data)};
      return fn(tx);
    }),
    list:async collection=>(await fs.collection(collection).orderBy("__name__").get()).docs.map(d=>({id:d.id,data:d.data()})),
  };
}

/** Discovery and disabled endpoints do not need a Firestore client. */
export function lazyFirestoreStore(getFirestore:()=>Firestore):Store {
  let current:Store|undefined;
  const acquire=()=>current??=firestoreStore(getFirestore());
  return {run:fn=>acquire().run(fn),list:collection=>acquire().list(collection)};
}
