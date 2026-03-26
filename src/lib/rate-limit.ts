import { Ratelimit } from "@upstash/ratelimit";
import { Redis } from "@upstash/redis";

const isTest = process.env.NODE_ENV === "test" || process.env.PLAYWRIGHT_TEST === "1";

const redis = isTest
  ? undefined
  : new Redis({
      url: process.env.UPSTASH_REDIS_REST_URL!,
      token: process.env.UPSTASH_REDIS_REST_TOKEN!,
    });

// 5 login attempts per 15 minutes per IP
export const loginRateLimit = redis
  ? new Ratelimit({
      redis,
      limiter: Ratelimit.slidingWindow(5, "15 m"),
      prefix: "ratelimit:login",
    })
  : { limit: async () => ({ success: true }) };

// 3 registration attempts per hour per IP
export const registerRateLimit = redis
  ? new Ratelimit({
      redis,
      limiter: Ratelimit.slidingWindow(3, "1 h"),
      prefix: "ratelimit:register",
    })
  : { limit: async () => ({ success: true }) };

// 60 mutations per minute per user
export const mutationRateLimit = redis
  ? new Ratelimit({
      redis,
      limiter: Ratelimit.slidingWindow(60, "1 m"),
      prefix: "ratelimit:mutation",
    })
  : { limit: async () => ({ success: true }) };

// 10 invite attempts per hour per user
export const inviteRateLimit = redis
  ? new Ratelimit({
      redis,
      limiter: Ratelimit.slidingWindow(10, "1 h"),
      prefix: "ratelimit:invite",
    })
  : { limit: async () => ({ success: true }) };
