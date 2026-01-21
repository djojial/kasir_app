const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const usersRef = admin.firestore().collection("users");

async function getUserRoleByUidOrEmail(uid, email) {
  if (uid) {
    const doc = await usersRef.doc(uid).get();
    if (doc.exists) {
      const role = (doc.data().role || "").toString().toLowerCase();
      if (role) return role;
    }
  }

  const emailLower = (email || "").trim().toLowerCase();
  if (!emailLower) return "";

  let snap = await usersRef.where("email", "==", emailLower).limit(1).get();
  if (snap.empty && emailLower !== email) {
    snap = await usersRef.where("email", "==", email).limit(1).get();
  }
  if (snap.empty) return "";
  const role = (snap.docs[0].data().role || "").toString().toLowerCase();
  return role;
}

exports.setUserPassword = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed." });
  }

  const authHeader = req.get("Authorization") || "";
  if (!authHeader.startsWith("Bearer ")) {
    return res.status(401).json({ error: "Unauthorized." });
  }

  let decoded;
  try {
    decoded = await admin.auth().verifyIdToken(authHeader.slice(7));
  } catch (err) {
    return res.status(401).json({ error: "Invalid token." });
  }

  const callerUid = decoded.uid;
  const callerRole = await getUserRoleByUidOrEmail(callerUid, "");
  if (callerRole !== "admin") {
    return res.status(403).json({ error: "Forbidden." });
  }

  let body = {};
  try {
    body =
      typeof req.body === "string"
        ? JSON.parse(req.body || "{}")
        : req.body || {};
  } catch (err) {
    return res.status(400).json({ error: "Payload tidak valid." });
  }
  const email = body.email || "";
  const password = body.password || "";
  if (typeof email !== "string" || email.trim() === "") {
    return res.status(400).json({ error: "Email wajib diisi." });
  }
  if (typeof password !== "string" || password.length < 6) {
    return res.status(400).json({ error: "Password minimal 6 karakter." });
  }

  let userRecord;
  try {
    userRecord = await admin.auth().getUserByEmail(email.trim());
  } catch (err) {
    return res.status(404).json({ error: "User tidak ditemukan." });
  }

  const targetUid = userRecord.uid;
  const targetRole = await getUserRoleByUidOrEmail(targetUid, email);
  if (targetRole === "admin") {
    return res
      .status(400)
      .json({ error: "Reset admin harus lewat email." });
  }
  if (targetRole !== "owner" && targetRole !== "operator") {
    return res.status(400).json({ error: "Role tidak didukung." });
  }

  await admin.auth().updateUser(targetUid, { password });
  return res.json({ ok: true });
});
