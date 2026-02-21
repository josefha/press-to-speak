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

const envSchema = z.object({
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
  OPENAI_REWRITE_TIMEOUT_MS: z.coerce.number().int().positive().default(700)
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  const issues = parsed.error.issues
    .map((issue) => `${issue.path.join(".") || "env"}: ${issue.message}`)
    .join("; ");
  throw new Error(`Invalid API environment configuration: ${issues}`);
}

const parsedEnv = parsed.data;

export const env = {
  ...parsedEnv,
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
