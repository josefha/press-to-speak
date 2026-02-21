import jwt, { type JwtPayload } from "jsonwebtoken";
import jwksClient, { type JwksClient } from "jwks-rsa";
import { env } from "../config/env";
import { HttpError } from "../lib/httpError";

export type SupabaseUser = {
  userId: string;
  email?: string;
  role?: string;
};

export type AccountTier = "free" | "pro";

export type SupabaseAccount = {
  userId: string;
  email?: string;
  profileName: string;
  tier: AccountTier;
};

export type SupabaseAccountSession = SupabaseAccount & {
  accessToken: string;
  refreshToken: string;
  accessTokenExpiresAtEpochSeconds?: number;
};

export type SupabaseSignUpResult = {
  account: SupabaseAccount;
  session?: SupabaseAccountSession;
  requiresEmailConfirmation: boolean;
};

let cachedJwksClient: JwksClient | undefined;

export async function verifySupabaseAccessToken(accessToken: string): Promise<SupabaseUser> {
  const token = accessToken.trim();
  if (!token) {
    throw new HttpError(401, "Missing Supabase access token");
  }

  try {
    const payload = env.SUPABASE_JWT_SECRET
      ? verifyWithSymmetricSecret(token, env.SUPABASE_JWT_SECRET)
      : await verifyWithJwks(token);
    return mapPayloadToUser(payload);
  } catch (error) {
    throw normalizeVerificationError(error);
  }
}

export async function signUpWithSupabaseAccount(input: {
  email: string;
  password: string;
  profileName?: string;
}): Promise<SupabaseSignUpResult> {
  const payload = await performSupabaseAuthRequest({
    operation: "signup",
    method: "POST",
    path: "/auth/v1/signup",
    body: {
      email: input.email,
      password: input.password,
      ...(input.profileName
        ? {
            data: {
              name: input.profileName
            }
          }
        : {})
    }
  });

  const account = extractAccount(payload);
  const session = extractSession(payload, account);
  return {
    account,
    session,
    requiresEmailConfirmation: session === undefined
  };
}

export async function signInWithSupabaseAccount(input: {
  email: string;
  password: string;
}): Promise<SupabaseAccountSession> {
  const payload = await performSupabaseAuthRequest({
    operation: "login",
    method: "POST",
    path: "/auth/v1/token",
    query: "grant_type=password",
    body: {
      email: input.email,
      password: input.password
    }
  });

  const account = extractAccount(payload);
  const session = extractSession(payload, account);
  if (!session) {
    throw new HttpError(502, "Supabase sign-in response did not include a session");
  }

  return session;
}

export async function refreshSupabaseAccountSession(refreshToken: string): Promise<SupabaseAccountSession> {
  const payload = await performSupabaseAuthRequest({
    operation: "refresh",
    method: "POST",
    path: "/auth/v1/token",
    query: "grant_type=refresh_token",
    body: {
      refresh_token: refreshToken
    }
  });

  const account = extractAccount(payload);
  const session = extractSession(payload, account);
  if (!session) {
    throw new HttpError(502, "Supabase refresh response did not include a session");
  }

  return session;
}

export async function signOutSupabaseAccount(accessToken: string): Promise<void> {
  await performSupabaseAuthRequest({
    operation: "logout",
    method: "POST",
    path: "/auth/v1/logout",
    bearerToken: accessToken
  });
}

function verifyWithSymmetricSecret(token: string, jwtSecret: string): JwtPayload {
  const decoded = jwt.verify(token, jwtSecret, {
    algorithms: ["HS256"],
    audience: env.SUPABASE_JWT_AUDIENCE,
    issuer: env.SUPABASE_JWT_ISSUER
  });
  return assertJwtPayload(decoded);
}

async function verifyWithJwks(token: string): Promise<JwtPayload> {
  if (!env.SUPABASE_JWKS_URL) {
    throw new HttpError(500, "SUPABASE_JWKS_URL is required for asymmetric Supabase JWT verification");
  }

  const decoded = await new Promise<string | JwtPayload>((resolve, reject) => {
    jwt.verify(
      token,
      (header, callback) => {
        const kid = header.kid;
        if (!kid) {
          callback(new Error("Supabase token is missing key id (kid) header"));
          return;
        }

        getOrCreateJwksClient().getSigningKey(kid, (error, signingKey) => {
          if (error || !signingKey) {
            callback(error ?? new Error("Unable to resolve Supabase signing key"));
            return;
          }

          callback(null, signingKey.getPublicKey());
        });
      },
      {
        algorithms: ["RS256", "ES256"],
        audience: env.SUPABASE_JWT_AUDIENCE,
        issuer: env.SUPABASE_JWT_ISSUER
      },
      (error, payload) => {
        if (error || payload === undefined) {
          reject(error ?? new Error("Supabase token verification failed"));
          return;
        }

        resolve(payload);
      }
    );
  });

  return assertJwtPayload(decoded);
}

function assertJwtPayload(decoded: string | JwtPayload): JwtPayload {
  if (typeof decoded === "string") {
    throw new HttpError(401, "Supabase access token payload is invalid");
  }

  return decoded;
}

function mapPayloadToUser(payload: JwtPayload): SupabaseUser {
  const subject = payload.sub;
  if (typeof subject !== "string" || subject.trim().length === 0) {
    throw new HttpError(401, "Supabase access token is missing subject (sub)");
  }

  const email = typeof payload.email === "string" ? payload.email : undefined;
  const role = typeof payload.role === "string" ? payload.role : undefined;

  return {
    userId: subject,
    email,
    role
  };
}

function normalizeVerificationError(error: unknown): HttpError {
  if (error instanceof HttpError) {
    return error;
  }

  if (error instanceof jwt.TokenExpiredError) {
    return new HttpError(401, "Supabase access token has expired");
  }

  if (error instanceof jwt.NotBeforeError) {
    return new HttpError(401, "Supabase access token is not active yet");
  }

  if (error instanceof jwt.JsonWebTokenError) {
    return new HttpError(401, "Supabase access token is invalid", {
      reason: error.message
    });
  }

  const errorName = typeof error === "object" && error && "name" in error ? String(error.name) : "";
  if (errorName === "JwksError" || errorName === "JwksRateLimitError") {
    return new HttpError(503, "Supabase token verification service is unavailable", {
      reason: error instanceof Error ? error.message : String(error)
    });
  }

  return new HttpError(401, "Supabase access token verification failed", {
    reason: error instanceof Error ? error.message : String(error)
  });
}

function getOrCreateJwksClient(): JwksClient {
  if (cachedJwksClient) {
    return cachedJwksClient;
  }

  if (!env.SUPABASE_JWKS_URL) {
    throw new HttpError(500, "SUPABASE_JWKS_URL is not configured");
  }

  cachedJwksClient = jwksClient({
    jwksUri: env.SUPABASE_JWKS_URL,
    cache: true,
    cacheMaxEntries: 5,
    cacheMaxAge: 10 * 60 * 1000,
    rateLimit: true,
    jwksRequestsPerMinute: 10,
    timeout: env.SUPABASE_JWKS_TIMEOUT_MS
  });

  return cachedJwksClient;
}

type SupabaseAuthRequestInput = {
  operation: "signup" | "login" | "refresh" | "logout";
  method: "POST";
  path: string;
  query?: string;
  body?: Record<string, unknown>;
  bearerToken?: string;
};

async function performSupabaseAuthRequest(input: SupabaseAuthRequestInput): Promise<Record<string, unknown>> {
  const { baseUrl, publishableKey } = getSupabaseAuthClientConfiguration();
  const endpoint = `${baseUrl}${input.path}${input.query ? `?${input.query}` : ""}`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), env.SUPABASE_AUTH_TIMEOUT_MS);

  try {
    const response = await fetch(endpoint, {
      method: input.method,
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        apikey: publishableKey,
        Authorization: `Bearer ${input.bearerToken ?? publishableKey}`
      },
      body: input.body ? JSON.stringify(input.body) : undefined,
      signal: controller.signal
    });

    const payload = await parseSupabaseResponsePayload(response);

    if (!response.ok) {
      throw mapSupabaseAuthRequestError(response.status, payload, input.operation);
    }

    if (input.path === "/auth/v1/logout") {
      return {};
    }

    if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
      throw new HttpError(502, "Supabase auth response payload is invalid");
    }

    return payload as Record<string, unknown>;
  } catch (error) {
    if (error instanceof HttpError) {
      throw error;
    }

    if (error instanceof Error && error.name === "AbortError") {
      throw new HttpError(504, "Supabase auth request timed out", {
        timeout_ms: env.SUPABASE_AUTH_TIMEOUT_MS
      });
    }

    throw new HttpError(502, "Unexpected failure while calling Supabase auth", {
      reason: error instanceof Error ? error.message : String(error)
    });
  } finally {
    clearTimeout(timeout);
  }
}

function getSupabaseAuthClientConfiguration(): {
  baseUrl: string;
  publishableKey: string;
} {
  const supabaseUrl = env.SUPABASE_URL?.trim();
  const publishableKey = env.SUPABASE_PUBLISHABLE_KEY?.trim();

  if (!supabaseUrl || !publishableKey) {
    throw new HttpError(500, "Supabase auth configuration is incomplete");
  }

  const normalizedBaseUrl = supabaseUrl.replace(/\/+$/, "");
  if (!isSecureSupabaseUrl(normalizedBaseUrl)) {
    throw new HttpError(500, "Supabase auth configuration must use HTTPS in non-local environments");
  }

  return {
    baseUrl: normalizedBaseUrl,
    publishableKey
  };
}

function isSecureSupabaseUrl(rawUrl: string): boolean {
  try {
    const parsed = new URL(rawUrl);
    const scheme = parsed.protocol.toLowerCase();
    if (scheme === "https:") {
      return true;
    }

    if (scheme === "http:") {
      const host = parsed.hostname.toLowerCase();
      return host === "localhost" || host === "127.0.0.1" || host === "::1";
    }

    return false;
  } catch {
    return false;
  }
}

function mapSupabaseAuthRequestError(
  statusCode: number,
  payload: unknown,
  operation: "signup" | "login" | "refresh" | "logout"
): HttpError {
  const message = extractSupabaseErrorMessage(payload);

  if (statusCode === 429) {
    return new HttpError(429, "Supabase auth rate limit exceeded");
  }

  if (statusCode >= 400 && statusCode < 500) {
    if (operation === "login") {
      return new HttpError(401, "Invalid email or password");
    }

    if (operation === "refresh") {
      return new HttpError(401, "Invalid or expired refresh token");
    }

    if (operation === "logout") {
      return new HttpError(401, "Invalid or expired access token");
    }

    return new HttpError(statusCode, "Unable to create account");
  }

  return new HttpError(statusCode, "Supabase auth request failed", {
    reason: message
  });
}

function extractSupabaseErrorMessage(payload: unknown): string {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    return "Unknown Supabase auth error";
  }

  const record = payload as Record<string, unknown>;
  const possibleKeys = ["msg", "message", "error_description", "error"] as const;
  for (const key of possibleKeys) {
    const value = record[key];
    if (typeof value === "string" && value.trim().length > 0) {
      return value.trim();
    }
  }

  return "Unknown Supabase auth error";
}

async function parseSupabaseResponsePayload(response: Response): Promise<unknown> {
  const contentType = response.headers.get("content-type") ?? "";
  if (!contentType.includes("application/json")) {
    return {};
  }

  return response.json();
}

function extractAccount(payload: Record<string, unknown>): SupabaseAccount {
  const user = getUserRecord(payload);
  const userId = readString(user, "id");
  if (!userId) {
    throw new HttpError(502, "Supabase auth response is missing user id");
  }

  const email = readString(user, "email");
  const appMetadata = readRecord(user, "app_metadata");
  const userMetadata = readRecord(user, "user_metadata");

  const profileName =
    findMetadataString(appMetadata, ["full_name", "name", "display_name"]) ??
    findMetadataString(userMetadata, ["full_name", "name", "display_name"]) ??
    deriveProfileName(email, userId);

  // Tier should come from app_metadata only; user_metadata is user-editable.
  const tier = normalizeTier(findMetadataString(appMetadata, ["tier", "plan", "subscription_tier"])) ?? "free";

  return {
    userId,
    email,
    profileName,
    tier
  };
}

function extractSession(
  payload: Record<string, unknown>,
  account: SupabaseAccount
): SupabaseAccountSession | undefined {
  const accessToken = readString(payload, "access_token");
  const refreshToken = readString(payload, "refresh_token");

  if (!accessToken || !refreshToken) {
    return undefined;
  }

  const accessTokenExpiresAtEpochSeconds =
    readPositiveInteger(payload, "expires_at") ?? deriveExpiryFromLifetime(payload, "expires_in");

  return {
    ...account,
    accessToken,
    refreshToken,
    accessTokenExpiresAtEpochSeconds
  };
}

function getUserRecord(payload: Record<string, unknown>): Record<string, unknown> {
  const user = readRecord(payload, "user");
  if (user) {
    return user;
  }

  return payload;
}

function readRecord(record: Record<string, unknown>, key: string): Record<string, unknown> | undefined {
  const value = record[key];
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return undefined;
  }

  return value as Record<string, unknown>;
}

function readString(record: Record<string, unknown>, key: string): string | undefined {
  const value = record[key];
  if (typeof value !== "string") {
    return undefined;
  }

  const normalized = value.trim();
  return normalized.length > 0 ? normalized : undefined;
}

function readPositiveInteger(record: Record<string, unknown>, key: string): number | undefined {
  const value = record[key];
  if (typeof value === "number" && Number.isFinite(value) && value > 0) {
    return Math.floor(value);
  }

  if (typeof value === "string") {
    const parsed = Number(value);
    if (Number.isFinite(parsed) && parsed > 0) {
      return Math.floor(parsed);
    }
  }

  return undefined;
}

function deriveExpiryFromLifetime(record: Record<string, unknown>, key: string): number | undefined {
  const lifetime = readPositiveInteger(record, key);
  if (!lifetime) {
    return undefined;
  }

  const nowEpochSeconds = Math.floor(Date.now() / 1000);
  return nowEpochSeconds + lifetime;
}

function findMetadataString(
  metadata: Record<string, unknown> | undefined,
  keys: readonly string[]
): string | undefined {
  if (!metadata) {
    return undefined;
  }

  for (const key of keys) {
    const value = metadata[key];
    if (typeof value === "string" && value.trim().length > 0) {
      return value.trim();
    }
  }

  return undefined;
}

function deriveProfileName(email: string | undefined, userId: string): string {
  const fallback = email?.split("@")[0]?.trim() || userId;
  return toDisplayName(fallback);
}

function toDisplayName(value: string): string {
  const normalized = value
    .replace(/\./g, " ")
    .replace(/_/g, " ")
    .trim();

  if (!normalized) {
    return "PressToSpeak User";
  }

  return normalized
    .split(/\s+/)
    .map((segment) => segment.slice(0, 1).toUpperCase() + segment.slice(1).toLowerCase())
    .join(" ");
}

function normalizeTier(value: string | undefined): AccountTier | undefined {
  if (!value) {
    return undefined;
  }

  const normalized = value.trim().toLowerCase();
  if (normalized === "pro") {
    return "pro";
  }

  if (normalized === "free") {
    return "free";
  }

  return undefined;
}
