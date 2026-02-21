import { timingSafeEqual } from "node:crypto";
import type { NextFunction, Request, Response } from "express";
import { env } from "../config/env";
import { verifySupabaseAccessToken } from "../external/supabaseAuthClient";
import { HttpError } from "../lib/httpError";

export type AuthSource = "supabase" | "legacy_header" | "byok_open" | "anonymous";

export type RequestUserContext = {
  userId: string;
  isAuthenticated: boolean;
  authSource: AuthSource;
  email?: string;
  role?: string;
};

const ANONYMOUS_USER_CONTEXT: RequestUserContext = {
  userId: "anonymous",
  isAuthenticated: false,
  authSource: "anonymous"
};

export async function authenticateRequest(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    enforceProxySharedApiKey(req);

    const rawAuthorization = req.header("authorization");
    const bearerToken =
      env.USER_AUTH_MODE === "off" ? tryExtractBearerToken(rawAuthorization) : extractBearerToken(rawAuthorization);
    const legacyUserId = extractLegacyUserId(req.header("x-user-id"));
    const hasByokProviderKeys = hasBringYourOwnProviderKeys(req);

    if (env.USER_AUTH_MODE === "off") {
      setUserContext(res, buildUnauthenticatedContext(legacyUserId, hasByokProviderKeys));
      next();
      return;
    }

    if (!bearerToken || isSharedProxyKeyBearerToken(bearerToken)) {
      if (env.USER_AUTH_MODE === "required") {
        if (hasByokProviderKeys && env.ALLOW_UNAUTHENTICATED_BYOK) {
          setUserContext(res, buildUnauthenticatedContext(undefined, true));
          next();
          return;
        }

        throw new HttpError(401, "Missing Supabase Bearer access token");
      }

      setUserContext(res, buildUnauthenticatedContext(legacyUserId, hasByokProviderKeys));
      next();
      return;
    }

    const verifiedUser = await verifySupabaseAccessToken(bearerToken);
    setUserContext(res, {
      userId: verifiedUser.userId,
      email: verifiedUser.email,
      role: verifiedUser.role,
      isAuthenticated: true,
      authSource: "supabase"
    });
    next();
  } catch (error) {
    next(error);
  }
}

export function getRequestUserContext(res: Response): RequestUserContext {
  const candidate = res.locals.user as RequestUserContext | undefined;

  if (!candidate || typeof candidate.userId !== "string" || typeof candidate.isAuthenticated !== "boolean") {
    return { ...ANONYMOUS_USER_CONTEXT };
  }

  return candidate;
}

function setUserContext(res: Response, context: RequestUserContext): void {
  res.locals.user = context;
}

function buildUnauthenticatedContext(legacyUserId: string | undefined, hasByokProviderKeys: boolean): RequestUserContext {
  if (hasByokProviderKeys) {
    return {
      userId: "byok-open",
      isAuthenticated: false,
      authSource: "byok_open"
    };
  }

  if (!legacyUserId) {
    return { ...ANONYMOUS_USER_CONTEXT };
  }

  return {
    userId: legacyUserId,
    isAuthenticated: false,
    authSource: "legacy_header"
  };
}

function extractLegacyUserId(rawValue: string | undefined): string | undefined {
  if (!rawValue) {
    return undefined;
  }

  const normalized = rawValue.trim();
  if (!normalized) {
    return undefined;
  }

  return normalized;
}

function enforceProxySharedApiKey(req: Request): void {
  const expectedKey = env.PROXY_SHARED_API_KEY;
  if (!expectedKey) {
    return;
  }

  const inboundApiKey = normalizeHeader(req.header("x-api-key"));
  if (inboundApiKey && safeEqualsSecret(inboundApiKey, expectedKey)) {
    return;
  }

  const legacyBearerToken = tryExtractBearerToken(req.header("authorization"));
  if (legacyBearerToken && safeEqualsSecret(legacyBearerToken, expectedKey)) {
    return;
  }

  throw new HttpError(401, "Missing or invalid proxy API key");
}

function extractBearerToken(rawAuthorization: string | undefined): string | undefined {
  if (!rawAuthorization) {
    return undefined;
  }

  const normalized = rawAuthorization.trim();
  if (!normalized) {
    return undefined;
  }

  const [scheme, ...parts] = normalized.split(/\s+/);
  if (!/^Bearer$/i.test(scheme)) {
    throw new HttpError(401, "Invalid Authorization header format; expected Bearer token");
  }

  const token = parts.join(" ").trim();
  if (!token) {
    throw new HttpError(401, "Missing Bearer token in Authorization header");
  }

  return token;
}

function tryExtractBearerToken(rawAuthorization: string | undefined): string | undefined {
  if (!rawAuthorization) {
    return undefined;
  }

  const normalized = rawAuthorization.trim();
  if (!normalized) {
    return undefined;
  }

  const [scheme, ...parts] = normalized.split(/\s+/);
  if (!/^Bearer$/i.test(scheme)) {
    return undefined;
  }

  const token = parts.join(" ").trim();
  return token || undefined;
}

function normalizeHeader(rawValue: string | undefined): string | undefined {
  if (!rawValue) {
    return undefined;
  }

  const normalized = rawValue.trim();
  return normalized.length > 0 ? normalized : undefined;
}

function isSharedProxyKeyBearerToken(token: string): boolean {
  return Boolean(env.PROXY_SHARED_API_KEY && safeEqualsSecret(token, env.PROXY_SHARED_API_KEY));
}

export function hasBringYourOwnProviderKeys(req: Request): boolean {
  const hasElevenLabsKey = Boolean(normalizeHeader(req.header("x-elevenlabs-api-key")));
  const hasOpenAIKey = Boolean(normalizeHeader(req.header("x-openai-api-key")));
  return hasElevenLabsKey || hasOpenAIKey;
}

function safeEqualsSecret(input: string, expected: string): boolean {
  const inputBuffer = Buffer.from(input, "utf8");
  const expectedBuffer = Buffer.from(expected, "utf8");

  if (inputBuffer.length !== expectedBuffer.length) {
    return false;
  }

  return timingSafeEqual(inputBuffer, expectedBuffer);
}
