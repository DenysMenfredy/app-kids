/**
 * CLI rehearsal for the legacy `primary` child migration.
 *
 *   node scripts/migrate_primary_children.mjs --project demo-letrando
 *   node scripts/migrate_primary_children.mjs --project demo-letrando --apply
 *   node scripts/migrate_primary_children.mjs --project demo-letrando --rollback
 *
 * Only the Firestore emulator is accepted; no remote project or Production
 * credentials are read. Output is aggregate JSON and contains no child data.
 */
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

import {
  inventoryPrimaryChildren,
  migratePrimaryChildren,
  rollbackPrimaryMigration,
} from "./primary_migration.mjs";

function arg(name) {
  const index = process.argv.indexOf(`--${name}`);
  return index === -1 ? undefined : process.argv[index + 1];
}

const project = arg("project") ?? process.env.GCLOUD_PROJECT;
if (!project) {
  console.error("Missing --project <demo-project>");
  process.exit(2);
}
if (/production/i.test(project)) {
  console.error("Refusing a production project; this tool is emulator-only.");
  process.exit(2);
}
if (!/^(localhost|127\.0\.0\.1):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST ?? "")) {
  console.error("Refusing a non-emulator run: set FIRESTORE_EMULATOR_HOST.");
  process.exit(2);
}

const rollback = process.argv.includes("--rollback");
const apply = process.argv.includes("--apply") && !rollback;
initializeApp({ projectId: project });
const db = getFirestore();

try {
  const before = await inventoryPrimaryChildren(db);
  const result = rollback
    ? await rollbackPrimaryMigration(db)
    : await migratePrimaryChildren(db, { apply });
  const after = await inventoryPrimaryChildren(db);
  console.log(JSON.stringify({ project, mode: rollback ? "rollback" : apply ? "apply" : "dry-run", before, result, after }, null, 2));
} finally {
  await db.terminate();
}
