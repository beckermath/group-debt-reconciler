import { Ratelimit } from "@upstash/ratelimit";
import { Redis } from "@upstash/redis";

const isTest = process.env.NODE_ENV === "test" || process.env.PLAYWRIGHT_TEST === "1";

const redis = isTest
  ? undefined
  : new Redis({
      url: process.env.UPSTASH_REDIS_REST_URL!,
      token: process.env.UPSTASH_REDIS_REST_TOKEN!,
    });

// 3 OTP sends per phone per 15 minutes
export const otpSendRateLimit = redis
  ? new Ratelimit({
      redis,
      limiter: Ratelimit.slidingWindow(3, "15 m"),
      prefix: "ratelimit:otp-send",
    })
  : { limit: async () => ({ success: true }) };

// 5 OTP verification attempts per phone per 15 minutes
export const otpVerifyRateLimit = redis
  ? new Ratelimit({
      redis,
      limiter: Ratelimit.slidingWindow(5, "15 m"),
      prefix: "ratelimit:otp-verify",
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

// 30 user searches per minute per user
export const searchRateLimit = redis
  ? new Ratelimit({
      redis,
      limiter: Ratelimit.slidingWindow(30, "1 m"),
      prefix: "ratelimit:search",
    })
  : { limit: async () => ({ success: true }) };

// 10 direct invites per hour per user
export const directInviteRateLimit = redis
  ? new Ratelimit({
      redis,
      limiter: Ratelimit.slidingWindow(10, "1 h"),
      prefix: "ratelimit:direct-invite",
    })
  : { limit: async () => ({ success: true }) };
