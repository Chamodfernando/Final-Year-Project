/**
 * One-time / occasional backfill: Firebase Auth users → Firestore `users/{uid}`.
 *
 * The admin Users tab reads Firestore only. Accounts created before the mobile
 * app wrote profiles will not appear until you run this or each user signs in once.
 *
 * Prerequisites:
 * - Service account JSON with Firebase Auth Admin + Firestore write (e.g. "Editor"
 *   on a dev project, or narrower roles: Firebase Authentication Admin + Cloud Datastore User).
 * - Do NOT commit the JSON file or expose it in the Vite app.
 *
 * Usage (from admin_panel):
 *   PowerShell:
 *     $env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\serviceAccount.json"
 *     npm run sync-auth-to-firestore
 *   bash:
 *     export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json
 *     npm run sync-auth-to-firestore
 */

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import admin from 'firebase-admin';

const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
if (!keyPath || !String(keyPath).trim()) {
  console.error(`
Set GOOGLE_APPLICATION_CREDENTIALS to the absolute path of your service account JSON, then:

  npm run sync-auth-to-firestore

Create the key: Google Cloud Console → IAM & Admin → Service Accounts → your SA → Keys → Add key → JSON.
Grant roles so the account can list Auth users and write Firestore (see script header).
`);
  process.exit(1);
}

const resolved = resolve(keyPath.trim());
let sa;
try {
  sa = JSON.parse(readFileSync(resolved, 'utf8'));
} catch (e) {
  console.error('Could not read JSON at', resolved, e);
  process.exit(1);
}

if (!sa.project_id) {
  console.error('JSON missing project_id');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(sa),
  projectId: sa.project_id,
});

const db = admin.firestore();
const auth = admin.auth();

function creationIso(userRecord) {
  const t = userRecord.metadata?.creationTime;
  if (t == null) return new Date().toISOString();
  if (typeof t === 'string') return new Date(t).toISOString();
  if (t instanceof Date) return t.toISOString();
  return new Date().toISOString();
}

function isAnonymous(userRecord) {
  return userRecord.providerData?.some((p) => p.providerId === 'anonymous') ?? false;
}

let total = 0;
let nextPageToken;
while (true) {
  const res = await auth.listUsers(1000, nextPageToken);
  for (const u of res.users) {
    const anon = isAnonymous(u);
    const email = u.email ?? '';
    const name =
      (u.displayName && String(u.displayName).trim()) ||
      (email ? email.split('@')[0] : anon ? 'Guest' : 'User');

    const doc = {
      email,
      name,
      role: anon ? 'Guest' : 'User',
      isAnonymous: anon,
      joined: creationIso(u),
      lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('users').doc(u.uid).set(doc, { merge: true });
    total += 1;
    console.log(`users/${u.uid}  ${email || '(no email)'}  ${name}`);
  }
  if (!res.pageToken) break;
  nextPageToken = res.pageToken;
}

console.log(`\nDone. Merged ${total} profile(s) into Firestore collection "users" (project: ${sa.project_id}).`);
console.log('Refresh the admin Users tab.');
