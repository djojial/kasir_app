// One-time migration: activity_logs -> stok_log (log_type=activity)
// Usage:
//   node migrate_activity_logs.js --project <projectId> [--delete]
// Requires GOOGLE_APPLICATION_CREDENTIALS env var pointing to service account JSON.

const admin = require('firebase-admin');

const args = process.argv.slice(2);
const projectArgIndex = args.indexOf('--project');
const projectId =
  projectArgIndex >= 0 && args[projectArgIndex + 1]
    ? args[projectArgIndex + 1]
    : process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT_ID;
const shouldDelete = args.includes('--delete');

if (!projectId) {
  console.error('Missing project id. Use --project <projectId>.');
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

const db = admin.firestore();
const activityRef = db.collection('activity_logs');
const stokRef = db.collection('stok_log');

async function migrateBatch(lastDoc) {
  let query = activityRef.orderBy(admin.firestore.FieldPath.documentId()).limit(500);
  if (lastDoc) query = query.startAfter(lastDoc);
  const snap = await query.get();
  if (snap.empty) return { done: true, last: lastDoc, count: 0 };

  const batch = db.batch();
  const now = admin.firestore.Timestamp.now();
  snap.docs.forEach((doc) => {
    const data = doc.data() || {};
    const createdAt = data.created_at || now;
    const payload = {
      ...data,
      log_type: 'activity',
      waktu: data.waktu || createdAt,
      created_at: createdAt,
      migrated_from: 'activity_logs',
      migrated_at: now,
    };
    batch.set(stokRef.doc(doc.id), payload, { merge: true });
  });
  await batch.commit();
  return { done: false, last: snap.docs[snap.docs.length - 1], count: snap.size };
}

async function deleteBatch(lastDoc) {
  let query = activityRef.orderBy(admin.firestore.FieldPath.documentId()).limit(500);
  if (lastDoc) query = query.startAfter(lastDoc);
  const snap = await query.get();
  if (snap.empty) return { done: true, last: lastDoc, count: 0 };

  const batch = db.batch();
  snap.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
  return { done: false, last: snap.docs[snap.docs.length - 1], count: snap.size };
}

async function run() {
  console.log(`Migrating activity_logs -> stok_log (project: ${projectId})`);
  let last = null;
  let total = 0;
  while (true) {
    const res = await migrateBatch(last);
    total += res.count;
    last = res.last;
    if (res.done) break;
    console.log(`Migrated ${total} docs...`);
  }
  console.log(`Migration done. Total migrated: ${total}`);

  if (shouldDelete) {
    console.log('Deleting activity_logs collection...');
    last = null;
    let deleted = 0;
    while (true) {
      const res = await deleteBatch(last);
      deleted += res.count;
      last = res.last;
      if (res.done) break;
      console.log(`Deleted ${deleted} docs...`);
    }
    console.log(`Delete done. Total deleted: ${deleted}`);
  }
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
