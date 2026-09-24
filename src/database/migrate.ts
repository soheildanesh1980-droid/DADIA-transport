import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { pool } from "./postgres.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const migrationsDir = path.resolve(
  __dirname,
  "../../src/database/migrations"
);

async function migrate() {
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    const files = (await fs.readdir(migrationsDir))
      .filter((name) => /^\d+_.*\.sql$/.test(name))
      .sort((a, b) => {
        const na = Number(a.match(/^\d+/)?.[0] ?? 0);
        const nb = Number(b.match(/^\d+/)?.[0] ?? 0);
        return na - nb;
      });

    for (const name of files) {
      const existing = await client.query(
        "SELECT 1 FROM schema_migrations WHERE name = $1",
        [name]
      );

      if ((existing.rowCount ?? 0) > 0) {
        console.log("Migration already applied:", name);
        continue;
      }

      const sql = await fs.readFile(
        path.join(migrationsDir, name),
        "utf8"
      );

      await client.query(sql);

      await client.query(
        "INSERT INTO schema_migrations (name) VALUES ($1)",
        [name]
      );

      console.log("Migration applied:", name);
    }

    await client.query("COMMIT");
    console.log("All migrations completed successfully.");
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("Migration failed:", error);
    process.exitCode = 1;
  } finally {
    client.release();
    await pool.end();
  }
}

migrate();
