import {
  transcribeWithElevenLabs,
  type ElevenLabsRequestOptions
} from "../external/elevenLabsClient";
import { rewriteTranscriptWithOpenAI } from "../external/openAIClient";
import { env } from "../config/env";
import { HttpError } from "../lib/httpError";
import { logger } from "../lib/logger";

export type VoiceToTextInput = {
  fileBuffer: Buffer;
  fileName: string;
  mimeType?: string;
  sttOptions?: ElevenLabsRequestOptions;
  providerOverrides?: {
    elevenLabsApiKey?: string;
    elevenLabsBaseUrl?: string;
    openAIApiKey?: string;
    openAIBaseUrl?: string;
    openAIModel?: string;
    openAITimeoutMs?: number;
  };
  requestId?: string;
  userId?: string;
};

export type VoiceToTextResult = {
  rawText: string;
  cleanText: string;
  sttModelId: string;
  rewriteModel: string;
  rewriteStatus: "completed" | "fallback_raw";
  sttLatencyMs: number;
  rewriteLatencyMs: number;
  rewriteError?: string;
};

export async function processVoiceToText(input: VoiceToTextInput): Promise<VoiceToTextResult> {
  const requestLogger = logger.child({
    component: "voice-to-text",
    requestId: input.requestId ?? "unknown",
    userId: input.userId ?? "anonymous"
  });

  requestLogger.info(
    {
      stage: "pipeline_start",
      fileName: input.fileName,
      mimeType: input.mimeType ?? "application/octet-stream",
      fileBytes: input.fileBuffer.byteLength,
      sttOptions: input.sttOptions ?? {}
    },
    "voice-to-text pipeline started"
  );

  const sttStartedAt = Date.now();
  const sttResult = await transcribeWithElevenLabs({
    fileBuffer: input.fileBuffer,
    fileName: input.fileName,
    mimeType: input.mimeType,
    options: input.sttOptions,
    apiKey: input.providerOverrides?.elevenLabsApiKey,
    baseUrl: input.providerOverrides?.elevenLabsBaseUrl
  });
  const sttLatencyMs = Date.now() - sttStartedAt;

  const sttLog: Record<string, unknown> = {
    stage: "elevenlabs_stt",
    sttModelId: sttResult.modelId,
    sttLatencyMs,
    rawTextChars: sttResult.rawText.length,
    rawTextWords: countWords(sttResult.rawText)
  };
  if (env.LOG_PIPELINE_TEXT) {
    sttLog.rawText = clipText(sttResult.rawText);
  }
  if (env.LOG_PROVIDER_PAYLOADS) {
    sttLog.elevenLabsPayload = buildPayloadPreview(sttResult.providerPayload);
  }
  requestLogger.info(sttLog, "ElevenLabs transcription completed");

  const rewriteStartedAt = Date.now();

  try {
    const rewriteResult = await rewriteTranscriptWithOpenAI(sttResult.rawText, {
      apiKey: input.providerOverrides?.openAIApiKey,
      baseUrl: input.providerOverrides?.openAIBaseUrl,
      model: input.providerOverrides?.openAIModel,
      timeoutMs: input.providerOverrides?.openAITimeoutMs
    });
    const rewriteLatencyMs = Date.now() - rewriteStartedAt;
    const comparison = compareTexts(sttResult.rawText, rewriteResult.cleanText);

    const rewriteLog: Record<string, unknown> = {
      stage: "openai_rewrite",
      rewriteModel: rewriteResult.model,
      rewriteLatencyMs,
      rewriteStatus: "completed",
      comparison
    };
    if (env.LOG_PIPELINE_TEXT) {
      rewriteLog.rawText = clipText(sttResult.rawText);
      rewriteLog.cleanText = clipText(rewriteResult.cleanText);
    }
    if (env.LOG_PROVIDER_PAYLOADS) {
      rewriteLog.openAIPayload = buildPayloadPreview(rewriteResult.providerPayload);
    }
    requestLogger.info(rewriteLog, "OpenAI rewrite completed");

    return {
      rawText: sttResult.rawText,
      cleanText: rewriteResult.cleanText,
      sttModelId: sttResult.modelId,
      rewriteModel: rewriteResult.model,
      rewriteStatus: "completed",
      sttLatencyMs,
      rewriteLatencyMs
    };
  } catch (error) {
    const rewriteLatencyMs = Date.now() - rewriteStartedAt;
    const rewriteError = error instanceof Error ? error.message : String(error);
    const rewriteErrorDetails = error instanceof HttpError ? error.details : undefined;
    const rewriteErrorStatusCode = error instanceof HttpError ? error.statusCode : undefined;
    const fallbackLog: Record<string, unknown> = {
      stage: "openai_rewrite",
      rewriteModel: input.providerOverrides?.openAIModel ?? env.OPENAI_MODEL,
      rewriteLatencyMs,
      rewriteStatus: "fallback_raw",
      rewriteError,
      comparison: compareTexts(sttResult.rawText, sttResult.rawText)
    };
    if (rewriteErrorStatusCode !== undefined) {
      fallbackLog.rewriteErrorStatusCode = rewriteErrorStatusCode;
    }
    if (rewriteErrorDetails !== undefined) {
      fallbackLog.rewriteErrorDetails = rewriteErrorDetails;
    }
    if (env.LOG_PIPELINE_TEXT) {
      fallbackLog.rawText = clipText(sttResult.rawText);
      fallbackLog.cleanText = clipText(sttResult.rawText);
    }
    requestLogger.warn(fallbackLog, "OpenAI rewrite failed; returning raw transcript");

    return {
      rawText: sttResult.rawText,
      cleanText: sttResult.rawText,
      sttModelId: sttResult.modelId,
      rewriteModel: input.providerOverrides?.openAIModel ?? env.OPENAI_MODEL,
      rewriteStatus: "fallback_raw",
      sttLatencyMs,
      rewriteLatencyMs,
      rewriteError
    };
  }
}

function compareTexts(rawText: string, cleanText: string): {
  changed: boolean;
  rawChars: number;
  cleanChars: number;
  charDelta: number;
  rawWords: number;
  cleanWords: number;
  wordDelta: number;
} {
  const rawChars = rawText.length;
  const cleanChars = cleanText.length;
  const rawWords = countWords(rawText);
  const cleanWords = countWords(cleanText);
  const rawNormalized = normalizeText(rawText);
  const cleanNormalized = normalizeText(cleanText);

  return {
    changed: rawNormalized !== cleanNormalized,
    rawChars,
    cleanChars,
    charDelta: cleanChars - rawChars,
    rawWords,
    cleanWords,
    wordDelta: cleanWords - rawWords
  };
}

function countWords(value: string): number {
  const normalized = value.trim();
  if (!normalized) {
    return 0;
  }

  return normalized.split(/\s+/).length;
}

function normalizeText(value: string): string {
  return value.trim().replace(/\s+/g, " ").toLowerCase();
}

function clipText(value: string): string {
  const normalized = value.replace(/\s+/g, " ").trim();
  if (normalized.length <= env.LOG_TEXT_MAX_CHARS) {
    return normalized;
  }

  const clipped = normalized.slice(0, env.LOG_TEXT_MAX_CHARS);
  const truncatedChars = normalized.length - env.LOG_TEXT_MAX_CHARS;
  return `${clipped}... [truncated ${truncatedChars} chars]`;
}

function buildPayloadPreview(payload: unknown): unknown {
  const serialized = safeJsonStringify(payload);
  if (serialized.length <= env.LOG_TEXT_MAX_CHARS) {
    return payload;
  }

  return {
    preview: `${serialized.slice(0, env.LOG_TEXT_MAX_CHARS)}...`,
    truncatedChars: serialized.length - env.LOG_TEXT_MAX_CHARS
  };
}

function safeJsonStringify(value: unknown): string {
  try {
    return JSON.stringify(value);
  } catch (error) {
    return `[unserializable payload: ${error instanceof Error ? error.message : String(error)}]`;
  }
}
