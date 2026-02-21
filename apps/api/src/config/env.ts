import path from "node:path";
import dotenv from "dotenv";
import { z } from "zod";

const envPath = process.env.API_ENV_FILE
  ? path.resolve(process.cwd(), process.env.API_ENV_FILE)
  : path.resolve(process.cwd(), ".env");

dotenv.config({ path: envPath });

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().int().min(1).max(65535).default(8787),
  LOG_LEVEL: z.string().default("info"),

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

export const env = parsed.data;
