import jwt, { type JwtPayload } from "jsonwebtoken";
import jwksClient, { type JwksClient } from "jwks-rsa";
import { env } from "../config/env";
import { HttpError } from "../lib/httpError";

export type SupabaseUser = {
  userId: string;
  email?: string;
  role?: string;
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
        algorithms: ["RS256"],
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
