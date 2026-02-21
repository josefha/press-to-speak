import { logger } from "../lib/logger";

const usageLogger = logger.child({ component: "usage-metering" });

export type UsageEvent = {
  requestId: string;
  userId: string;
  audioBytes: number;
  rawCharacters: number;
  cleanCharacters: number;
  sttLatencyMs: number;
  rewriteLatencyMs: number;
  isAuthenticated: boolean;
  authSource: "supabase" | "legacy_header" | "byok_open" | "anonymous";
};

export async function recordUsageEvent(event: UsageEvent): Promise<void> {
  usageLogger.info(event, "usage event captured (placeholder)");
}
