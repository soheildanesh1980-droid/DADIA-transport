import "dotenv/config";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { pool } from "./postgres.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function main() {
  const migration = path.resolve(__dirname, "../../src/database/migrations/002_auth_schema.sql");
  const sql = await fs.readFile(migration, "utf8");
  await pool.query(sql);
  console.log("Migration applied: 002_auth_schema.sql");
  await pool.end();
}

main().catch(async (error) => {
  console.error(error);
  await pool.end();
  process.exit(1);
});
