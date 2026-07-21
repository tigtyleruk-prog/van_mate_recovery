'use strict';

const admin = require('firebase-admin');
const {
  assertDevelopmentProject,
  assertDevelopmentStorageBucket,
  buildCleanupPlan,
  collectCleanupCandidates,
  executeCleanup,
} = require('../business_mate_dev_cleanup');

function argumentsByName(argv) {
  const values = new Map();
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (!argument.startsWith('--')) continue;
    const name = argument.slice(2);
    if (name === 'execute') {
      values.set(name, true);
      continue;
    }
    values.set(name, argv[index + 1] || '');
    index += 1;
  }
  return values;
}

async function main() {
  const args = argumentsByName(process.argv.slice(2));
  const requestedProject = String(args.get('project') || '').trim();
  const expectedProject = String(
    process.env.BUSINESS_MATE_DEV_PROJECT_ID || '',
  ).trim();
  const allowedProjectIds = String(
    process.env.BUSINESS_MATE_DEV_ALLOWED_PROJECT_IDS || '',
  ).trim();
  const allowedTargets = String(
    process.env.BUSINESS_MATE_DEV_ALLOWED_TARGETS || '',
  ).trim();
  const allowedStorageBuckets = String(
    process.env.BUSINESS_MATE_DEV_ALLOWED_STORAGE_BUCKETS || '',
  ).trim();
  const storageBucket = String(
    args.get('storage-bucket') ||
      process.env.BUSINESS_MATE_DEV_STORAGE_BUCKET ||
      '',
  ).trim();
  assertDevelopmentProject({
    actualProjectId: requestedProject,
    expectedProjectId: expectedProject,
    allowedProjectIds,
  });
  assertDevelopmentStorageBucket({
    storageBucket,
    projectId: requestedProject,
    allowedStorageBuckets,
  });

  const plan = buildCleanupPlan({
    ownerUid: args.get('owner-uid'),
    businessProfileId: args.get('business-profile-id'),
    allowedTargets,
  });
  const execute = args.get('execute') === true;
  if (execute) {
    if (args.get('confirm-project') !== requestedProject) {
      throw new Error('Execution requires --confirm-project matching --project.');
    }
    if (args.get('confirm-owner') !== plan.target.ownerUid) {
      throw new Error('Execution requires --confirm-owner matching --owner-uid.');
    }
    if (args.get('confirm-business') !== plan.target.businessProfileId) {
      throw new Error(
        'Execution requires --confirm-business matching --business-profile-id.',
      );
    }
  }

  admin.initializeApp({
    projectId: requestedProject,
    ...(storageBucket ? { storageBucket } : {}),
  });
  const actualProject = admin.app().options.projectId;
  assertDevelopmentProject({
    actualProjectId: actualProject,
    expectedProjectId: expectedProject,
    allowedProjectIds,
  });

  const firestore = admin.firestore();
  const candidates = await collectCleanupCandidates({
    firestore,
    target: plan.target,
  });

  console.log(JSON.stringify({
    mode: execute ? 'execute' : 'dry-run',
    projectId: actualProject,
    storageBucket: storageBucket || null,
    target: plan.target,
    targetedLocations: candidates.locationCounts,
    documents: candidates.documentPaths,
    bookingPhotoObjects: candidates.photoPaths,
    protectedFinancialDocuments: candidates.skippedFinancialDocuments,
    uncertainOwnershipDocuments: candidates.uncertainOwnershipDocuments,
    preservedCollections: plan.preservedCollections,
    authenticationUsersDeleted: false,
  }, null, 2));

  if (!execute) {
    console.log('Dry run only. No Firebase data was deleted.');
    return;
  }
  if (candidates.uncertainOwnershipDocuments.length > 0) {
    console.log(
      `Preserving ${candidates.uncertainOwnershipDocuments.length} documents with uncertain ownership.`,
    );
  }
  if (candidates.photoPaths.length > 0 && !storageBucket) {
    throw new Error(
      'Execution found booking photos and requires --storage-bucket or BUSINESS_MATE_DEV_STORAGE_BUCKET.',
    );
  }
  const bucket = storageBucket ? admin.storage().bucket(storageBucket) : null;
  await executeCleanup({ firestore, bucket, candidates });
  console.log(
    `Deleted ${candidates.documentPaths.length} documents and ${candidates.photoPaths.length} booking photo objects.`,
  );
}

main().catch((error) => {
  console.error(error.message || error);
  process.exitCode = 1;
});
