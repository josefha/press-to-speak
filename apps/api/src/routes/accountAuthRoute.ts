import { Router } from "express";
import { z } from "zod";
import {
  refreshSupabaseAccountSession,
  signInWithSupabaseAccount,
  signOutSupabaseAccount,
  signUpWithSupabaseAccount,
  type SupabaseAccount,
  type SupabaseAccountSession
} from "../external/supabaseAuthClient";
import { HttpError } from "../lib/httpError";
import { enforceProxyApiKey } from "../middleware/enforceProxyApiKey";
import { enforceAuthRouteRateLimit } from "../middleware/authRouteRateLimit";

const emailSchema = z.string().trim().email().max(254);
const passwordSchema = z.string().min(8).max(256);
const profileNameSchema = z.string().trim().min(1).max(80);

const signUpSchema = z.object({
  email: emailSchema,
  password: passwordSchema,
  profile_name: profileNameSchema.optional()
});

const signInSchema = z.object({
  email: emailSchema,
  password: passwordSchema
});

const refreshSchema = z.object({
  refresh_token: z.string().trim().min(1).max(4096)
});

const signOutSchema = z.object({
  access_token: z.string().trim().min(1).max(4096).optional()
});

export const accountAuthRouter = Router();

accountAuthRouter.post(
  "/v1/auth/signup",
  enforceProxyApiKey,
  enforceAuthRouteRateLimit,
  async (req, res, next): Promise<void> => {
    try {
      const input = parseBody(signUpSchema, req.body, "signup");
      const result = await signUpWithSupabaseAccount({
        email: input.email,
        password: input.password,
        profileName: input.profile_name
      });

      res.status(result.requiresEmailConfirmation ? 200 : 201).json({
        request_id: res.locals.requestId,
        account: mapAccount(result.account),
        session: result.session ? mapSession(result.session) : null,
        requires_email_confirmation: result.requiresEmailConfirmation
      });
    } catch (error) {
      next(error);
    }
  }
);

accountAuthRouter.post(
  "/v1/auth/login",
  enforceProxyApiKey,
  enforceAuthRouteRateLimit,
  async (req, res, next): Promise<void> => {
    try {
      const input = parseBody(signInSchema, req.body, "login");
      const session = await signInWithSupabaseAccount({
        email: input.email,
        password: input.password
      });

      res.status(200).json({
        request_id: res.locals.requestId,
        account: mapAccount(session),
        session: mapSession(session)
      });
    } catch (error) {
      next(error);
    }
  }
);

accountAuthRouter.post(
  "/v1/auth/refresh",
  enforceProxyApiKey,
  enforceAuthRouteRateLimit,
  async (req, res, next): Promise<void> => {
    try {
      const input = parseBody(refreshSchema, req.body, "refresh");
      const session = await refreshSupabaseAccountSession(input.refresh_token);

      res.status(200).json({
        request_id: res.locals.requestId,
        account: mapAccount(session),
        session: mapSession(session)
      });
    } catch (error) {
      next(error);
    }
  }
);

accountAuthRouter.post(
  "/v1/auth/logout",
  enforceProxyApiKey,
  enforceAuthRouteRateLimit,
  async (req, res, next): Promise<void> => {
    try {
      const body = parseBody(signOutSchema, req.body, "logout");
      const accessToken = body.access_token ?? extractBearerToken(req.header("authorization"));
      if (!accessToken) {
        throw new HttpError(400, "Missing access token for logout");
      }

      await signOutSupabaseAccount(accessToken);

      res.status(200).json({
        request_id: res.locals.requestId,
        success: true
      });
    } catch (error) {
      next(error);
    }
  }
);

function parseBody<T extends z.ZodTypeAny>(schema: T, body: unknown, operation: string): z.infer<T> {
  const parsed = schema.safeParse(body);
  if (parsed.success) {
    return parsed.data;
  }

  throw new HttpError(400, `Invalid auth ${operation} payload`, {
    issues: parsed.error.issues.map((issue) => ({
      path: issue.path.join("."),
      message: issue.message
    }))
  });
}

function mapAccount(account: SupabaseAccount): {
  user_id: string;
  email?: string;
  profile_name: string;
  tier: "free" | "pro";
} {
  return {
    user_id: account.userId,
    email: account.email,
    profile_name: account.profileName,
    tier: account.tier
  };
}

function mapSession(session: SupabaseAccountSession): {
  access_token: string;
  refresh_token: string;
  expires_at?: number;
} {
  return {
    access_token: session.accessToken,
    refresh_token: session.refreshToken,
    expires_at: session.accessTokenExpiresAtEpochSeconds
  };
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
    return undefined;
  }

  const token = parts.join(" ").trim();
  return token || undefined;
}
