'use strict';

const admin = require('firebase-admin');
const {
  auditLegacyBusinessProfileScope,
} = require('../business_profile_legacy_audit');

function argument(name) {
  const index = process.argv.indexOf(`--${name}`);
  return index === -1 ? '' : String(process.argv[index + 1] || '').trim();
}

async function main() {
  const project = argument('project');
  const ownerUid = argument('owner-uid');
  if (!project || !ownerUid) {
    throw new Error('Usage: node audit_business_profile_scope.js --project PROJECT_ID --owner-uid OWNER_UID');
  }
  if (admin.apps.length === 0) {
    admin.initializeApp({ projectId: project });
  }
  const result = await auditLegacyBusinessProfileScope({
    firestore: admin.firestore(),
    ownerUid,
  });
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
}

main().catch((error) => {
  process.stderr.write(`${error.message}\n`);
  process.exitCode = 1;
});
