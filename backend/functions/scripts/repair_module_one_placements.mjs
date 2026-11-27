/**
 * CLI for the local module-1 pointer repair (ADR 0025).
 *
 *   node scripts/repair_module_one_placements.mjs --project demo-letrando
 *   node scripts/repair_module_one_placements.mjs --project demo-letrando --apply
 *   node scripts/repair_module_one_placements.mjs --project demo-letrando --rollback
 *
 * Emulator-only; dry-run by default; output is aggregate JSON without PII.
 */
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

import {
  inventoryModuleOneRepairs,
  repairModuleOnePlacements,
  rollbackModuleOneRepairs,
} from "./module_one_repair.mjs";

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
  const before = await inventoryModuleOneRepairs(db);
  const result = rollback
    ? await rollbackModuleOneRepairs(db)
    : await repairModuleOnePlacements(db, { apply });
  const after = await inventoryModuleOneRepairs(db);
  console.log(JSON.stringify({
    project,
    mode: rollback ? "rollback" : apply ? "apply" : "dry-run",
    before,
    result,
    after,
  }, null, 2));
} finally {
  await db.terminate();
}
