import path from "node:path";
import dotenv from "dotenv";
import { z } from "zod";

const envPath = process.env.API_ENV_FILE
  ? path.resolve(process.cwd(), process.env.API_ENV_FILE)
  : path.resolve(process.cwd(), ".env");

dotenv.config({ path: envPath });

function parseEnvBoolean(value: string | undefined, fallback: boolean, name: string): boolean {
  if (value === undefined) {
    return fallback;
  }

  const normalized = value.trim().toLowerCase();

  if (normalized === "true" || normalized === "1" || normalized === "yes" || normalized === "on") {
    return true;
  }

  if (normalized === "false" || normalized === "0" || normalized === "no" || normalized === "off") {
    return false;
  }

  throw new Error(`Invalid API environment configuration: ${name} must be true/false/1/0/yes/no/on/off`);
}

function trimToUndefined(value: string | undefined): string | undefined {
  if (value === undefined) {
    return undefined;
  }

  const normalized = value.trim();
  return normalized.length > 0 ? normalized : undefined;
}

const optionalStringEnv = z.preprocess((value) => {
  if (typeof value !== "string") {
    return value;
  }

  const normalized = value.trim();
  return normalized.length > 0 ? normalized : undefined;
}, z.string().optional());

const optionalUrlEnv = z.preprocess((value) => {
  if (typeof value !== "string") {
    return value;
  }

  const normalized = value.trim();
  return normalized.length > 0 ? normalized : undefined;
}, z.string().url().optional());

const envSchema = z
  .object({
    NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
    PORT: z.coerce.number().int().min(1).max(65535).default(8787),
    LOG_LEVEL: z.string().default("info"),
    LOG_PRETTY: z.string().optional(),
    LOG_PIPELINE_TEXT: z.string().optional(),
    LOG_PROVIDER_PAYLOADS: z.string().optional(),
    LOG_TEXT_MAX_CHARS: z.coerce.number().int().positive().default(1200),

    ELEVENLABS_API_KEY: z.string().min(1, "ELEVENLABS_API_KEY is required"),
    ELEVENLABS_API_BASE_URL: z.string().url().default("https://api.elevenlabs.io"),
    ELEVENLABS_MODEL_ID: z.string().min(1).default("scribe_v1"),
    TRANSCRIPTION_REQUEST_TIMEOUT_MS: z.coerce.number().int().positive().default(20_000),
    TRANSCRIPTION_MAX_FILE_BYTES: z.coerce.number().int().positive().default(25 * 1024 * 1024),

    OPENAI_API_KEY: z.string().min(1, "OPENAI_API_KEY is required"),
    OPENAI_API_BASE_URL: z.string().url().default("https://api.openai.com/v1"),
    OPENAI_MODEL: z.string().default("gpt-5-mini"),
    OPENAI_REWRITE_TIMEOUT_MS: z.coerce.number().int().positive().default(2000),

    PROXY_SHARED_API_KEY: optionalStringEnv,
    USER_AUTH_MODE: z.enum(["off", "optional", "required"]).default("required"),
    ALLOW_UNAUTHENTICATED_BYOK: z.string().optional(),
    BYOK_HEADER_MAX_CHARS: z.coerce.number().int().positive().default(512),
    UNAUTH_RATE_LIMIT_WINDOW_MS: z.coerce.number().int().positive().default(60_000),
    UNAUTH_RATE_LIMIT_MAX_REQUESTS: z.coerce.number().int().positive().default(20),
    SUPABASE_URL: optionalUrlEnv,
    SUPABASE_PUBLISHABLE_KEY: optionalStringEnv,
    SUPABASE_JWT_SECRET: optionalStringEnv,
    SUPABASE_JWT_AUDIENCE: z.string().default("authenticated"),
    SUPABASE_JWT_ISSUER: optionalUrlEnv,
    SUPABASE_JWKS_URL: optionalUrlEnv,
    SUPABASE_JWKS_TIMEOUT_MS: z.coerce.number().int().positive().default(2000),
    SUPABASE_AUTH_TIMEOUT_MS: z.coerce.number().int().positive().default(5000),
    AUTH_ROUTE_RATE_LIMIT_WINDOW_MS: z.coerce.number().int().positive().default(60_000),
    AUTH_ROUTE_RATE_LIMIT_MAX_REQUESTS: z.coerce.number().int().positive().default(20)
  })
  .superRefine((value, ctx) => {
    if (value.USER_AUTH_MODE === "off") {
      return;
    }

    const normalizedJwtSecret = trimToUndefined(value.SUPABASE_JWT_SECRET);
    if (normalizedJwtSecret?.startsWith("sb_secret_")) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["SUPABASE_JWT_SECRET"],
        message:
          "SUPABASE_JWT_SECRET expects the legacy JWT signing secret, not a Supabase secret API key (sb_secret_*). Remove SUPABASE_JWT_SECRET to use JWKS verification."
      });
    }

    const hasSupabaseUrl = Boolean(trimToUndefined(value.SUPABASE_URL));
    const hasJwtSecret = Boolean(normalizedJwtSecret);
    const hasJwksUrl = Boolean(trimToUndefined(value.SUPABASE_JWKS_URL));
    const hasIssuer = Boolean(trimToUndefined(value.SUPABASE_JWT_ISSUER));

    if (!hasJwtSecret && !hasSupabaseUrl && !hasJwksUrl) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["SUPABASE_URL"],
        message:
          "SUPABASE_URL (or SUPABASE_JWKS_URL) is required when USER_AUTH_MODE is optional/required and SUPABASE_JWT_SECRET is not set"
      });
    }

    if (!hasIssuer && !hasSupabaseUrl) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["SUPABASE_JWT_ISSUER"],
        message: "SUPABASE_JWT_ISSUER is required when USER_AUTH_MODE is optional/required and SUPABASE_URL is not set"
      });
    }
  });

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  const issues = parsed.error.issues
    .map((issue) => `${issue.path.join(".") || "env"}: ${issue.message}`)
    .join("; ");
  throw new Error(`Invalid API environment configuration: ${issues}`);
}

const parsedEnv = parsed.data;
const supabaseUrl = trimToUndefined(parsedEnv.SUPABASE_URL)?.replace(/\/+$/, "");
const supabaseJwtIssuer =
  trimToUndefined(parsedEnv.SUPABASE_JWT_ISSUER) ?? (supabaseUrl ? `${supabaseUrl}/auth/v1` : undefined);
const supabaseJwksUrl =
  trimToUndefined(parsedEnv.SUPABASE_JWKS_URL) ??
  (supabaseUrl ? `${supabaseUrl}/auth/v1/.well-known/jwks.json` : undefined);

export const env = {
  ...parsedEnv,
  PROXY_SHARED_API_KEY: trimToUndefined(parsedEnv.PROXY_SHARED_API_KEY),
  ALLOW_UNAUTHENTICATED_BYOK: parseEnvBoolean(
    parsedEnv.ALLOW_UNAUTHENTICATED_BYOK,
    false,
    "ALLOW_UNAUTHENTICATED_BYOK"
  ),
  SUPABASE_URL: supabaseUrl,
  SUPABASE_PUBLISHABLE_KEY: trimToUndefined(parsedEnv.SUPABASE_PUBLISHABLE_KEY),
  SUPABASE_JWT_SECRET: trimToUndefined(parsedEnv.SUPABASE_JWT_SECRET),
  SUPABASE_JWT_ISSUER: supabaseJwtIssuer,
  SUPABASE_JWKS_URL: supabaseJwksUrl,
  LOG_PRETTY: parseEnvBoolean(parsedEnv.LOG_PRETTY, parsedEnv.NODE_ENV === "development", "LOG_PRETTY"),
  LOG_PIPELINE_TEXT: parseEnvBoolean(
    parsedEnv.LOG_PIPELINE_TEXT,
    parsedEnv.NODE_ENV === "development",
    "LOG_PIPELINE_TEXT"
  ),
  LOG_PROVIDER_PAYLOADS: parseEnvBoolean(
    parsedEnv.LOG_PROVIDER_PAYLOADS,
    parsedEnv.NODE_ENV === "development",
    "LOG_PROVIDER_PAYLOADS"
  )
};
