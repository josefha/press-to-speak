import { timingSafeEqual } from "node:crypto";
import type { NextFunction, Request, Response } from "express";
import { env } from "../config/env";
import { HttpError } from "../lib/httpError";

export function enforceProxyApiKey(req: Request, _res: Response, next: NextFunction): void {
  try {
    const expectedKey = env.PROXY_SHARED_API_KEY;
    if (!expectedKey) {
      next();
      return;
    }

    const inboundApiKey = normalizeHeader(req.header("x-api-key"));
    if (inboundApiKey && safeEqualsSecret(inboundApiKey, expectedKey)) {
      next();
      return;
    }

    throw new HttpError(401, "Missing or invalid proxy API key");
  } catch (error) {
    next(error);
  }
}

function normalizeHeader(rawValue: string | undefined): string | undefined {
  if (!rawValue) {
    return undefined;
  }

  const normalized = rawValue.trim();
  return normalized.length > 0 ? normalized : undefined;
}

function safeEqualsSecret(input: string, expected: string): boolean {
  const inputBuffer = Buffer.from(input, "utf8");
  const expectedBuffer = Buffer.from(expected, "utf8");

  if (inputBuffer.length !== expectedBuffer.length) {
    return false;
  }

  return timingSafeEqual(inputBuffer, expectedBuffer);
}
