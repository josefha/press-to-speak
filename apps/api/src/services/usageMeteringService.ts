import pino from "pino";

const logger = pino({ name: "usage-metering" });

export type UsageEvent = {
  requestId: string;
  userId: string;
  audioBytes: number;
  rawCharacters: number;
  cleanCharacters: number;
  sttLatencyMs: number;
  rewriteLatencyMs: number;
};

export async function recordUsageEvent(event: UsageEvent): Promise<void> {
  logger.info(event, "usage event captured (placeholder)");
}
