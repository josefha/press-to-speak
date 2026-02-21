import type { NextFunction, Request, Response } from "express";
import { env } from "../config/env";
import { HttpError } from "../lib/httpError";
import { getRequestUserContext } from "./authenticateRequest";

type RateLimitBucket = {
  windowStartedAtMs: number;
  count: number;
};

const unauthenticatedBuckets = new Map<string, RateLimitBucket>();
let lastCleanupAtMs = 0;
const HARD_BUCKET_LIMIT = 50_000;

export function enforceUnauthenticatedRateLimit(req: Request, res: Response, next: NextFunction): void {
  try {
    const user = getRequestUserContext(res);
    if (user.isAuthenticated) {
      next();
      return;
    }

    const maxRequests = env.UNAUTH_RATE_LIMIT_MAX_REQUESTS;
    const windowMs = env.UNAUTH_RATE_LIMIT_WINDOW_MS;
    const now = Date.now();
    const key = buildClientKey(req);
    const bucket = unauthenticatedBuckets.get(key);

    if (!bucket || now - bucket.windowStartedAtMs >= windowMs) {
      unauthenticatedBuckets.set(key, {
        windowStartedAtMs: now,
        count: 1
      });
      setRateLimitHeaders(res, maxRequests, maxRequests - 1, windowMs);
      cleanupBuckets(now, windowMs);
      next();
      return;
    }

    if (bucket.count >= maxRequests) {
      const retryAfterMs = Math.max(0, windowMs - (now - bucket.windowStartedAtMs));
      setRateLimitHeaders(res, maxRequests, 0, retryAfterMs);
      throw new HttpError(429, "Rate limit exceeded for unauthenticated requests", {
        retry_after_ms: retryAfterMs,
        window_ms: windowMs,
        max_requests: maxRequests
      });
    }

    bucket.count += 1;
    const remaining = Math.max(0, maxRequests - bucket.count);
    setRateLimitHeaders(res, maxRequests, remaining, Math.max(0, windowMs - (now - bucket.windowStartedAtMs)));
    cleanupBuckets(now, windowMs);
    next();
  } catch (error) {
    next(error);
  }
}

function buildClientKey(req: Request): string {
  const ip = req.ip || req.socket.remoteAddress || "unknown";
  return ip;
}

function setRateLimitHeaders(res: Response, limit: number, remaining: number, resetMs: number): void {
  res.setHeader("x-ratelimit-limit", String(limit));
  res.setHeader("x-ratelimit-remaining", String(Math.max(0, remaining)));
  res.setHeader("x-ratelimit-reset-ms", String(Math.max(0, resetMs)));
}

function cleanupBuckets(nowMs: number, windowMs: number): void {
  const cleanupEveryMs = Math.max(windowMs, 60_000);
  if (nowMs - lastCleanupAtMs < cleanupEveryMs && unauthenticatedBuckets.size < HARD_BUCKET_LIMIT) {
    return;
  }

  lastCleanupAtMs = nowMs;
  for (const [key, bucket] of unauthenticatedBuckets.entries()) {
    if (nowMs - bucket.windowStartedAtMs >= windowMs) {
      unauthenticatedBuckets.delete(key);
    }
  }

  if (unauthenticatedBuckets.size > HARD_BUCKET_LIMIT) {
    unauthenticatedBuckets.clear();
  }
}
