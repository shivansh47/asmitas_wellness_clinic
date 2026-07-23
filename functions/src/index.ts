import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();
const COUNTER_DOC = db.collection("counters").doc("clientIDCounter");

interface RegisterUserData {
  uid: string;
  email: string;
  displayName: string;
  role: "client";
  clientID: string;
  createdAt: admin.firestore.Timestamp;
}

/**
 * Generates a ClientID for a new registering user in an AWC#### format
 * @return {string} A promise resolving to the new ClientID
 * @throws {Error} If the firestore transaction fails
*/
function generateClientID(): Promise<string> {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(COUNTER_DOC);
    const lastNum = snap.exists ? (snap.data()?.lastNum || 0) : 0;
    const newNum = lastNum + 1;
    tx.set(COUNTER_DOC, {lastNum: newNum});
    return "AWC" + newNum.toString().padStart(4, "0");
  });
}

export const onUserCreated = functions.auth.user().onCreate(async (user) => {
  const {uid, email} = user;
  console.log("onCreate: ${uid} (${email})");

  const clientID = await generateClientID();
  console.log("Generated ClientID: ${clientID} for ${email}");

  const doc: RegisterUserData = {
    uid,
    email: email ?? "",
    displayName: "",
    role: "client",
    clientID,
    createdAt: admin.firestore.Timestamp.now(),
  };

  await db.collection("users").doc(uid).set(doc);
  await admin.auth().setCustomUserClaims(uid, {role: "client"});

  console.log("onCreate complete: ${email} -> ${clientID}");
});

