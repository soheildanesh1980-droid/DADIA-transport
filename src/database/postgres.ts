import pg from "pg";

const { Pool } = pg;

export const pool = new Pool({
  host: process.env.POSTGRES_HOST || "127.0.0.1",
  port: Number(process.env.POSTGRES_PORT || 5432),
  database: process.env.POSTGRES_DB || "dadia_transport",
  user: process.env.POSTGRES_USER || "dadia_app",
  password: process.env.POSTGRES_PASSWORD || "DadiaApp_2026",
  max: 10,
  idleTimeoutMillis: 30000,
});

export async function checkPostgres(): Promise<boolean> {
  const result = await pool.query("SELECT 1 AS ok");
  return result.rows[0]?.ok === 1;
}
