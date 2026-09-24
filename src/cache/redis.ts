import Redis from "ioredis";

export const redis: any = new (Redis as any)({
  host: process.env.REDIS_HOST ?? "127.0.0.1",
  port: Number(process.env.REDIS_PORT ?? 6379),
  lazyConnect: true,
});

export async function checkRedis(): Promise<boolean> {
  if (redis.status === "wait") {
    await redis.connect();
  }

  const result = await redis.ping();
  return result === "PONG";
}
