import {
  transcribeWithElevenLabs,
  type ElevenLabsRequestOptions
} from "../external/elevenLabsClient";
import { rewriteTranscriptWithOpenAI } from "../external/openAIClient";
import { env } from "../config/env";

export type VoiceToTextInput = {
  fileBuffer: Buffer;
  fileName: string;
  mimeType?: string;
  sttOptions?: ElevenLabsRequestOptions;
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
  const sttStartedAt = Date.now();
  const sttResult = await transcribeWithElevenLabs({
    fileBuffer: input.fileBuffer,
    fileName: input.fileName,
    mimeType: input.mimeType,
    options: input.sttOptions
  });
  const sttLatencyMs = Date.now() - sttStartedAt;

  const rewriteStartedAt = Date.now();

  try {
    const rewriteResult = await rewriteTranscriptWithOpenAI(sttResult.rawText);
    return {
      rawText: sttResult.rawText,
      cleanText: rewriteResult.cleanText,
      sttModelId: sttResult.modelId,
      rewriteModel: rewriteResult.model,
      rewriteStatus: "completed",
      sttLatencyMs,
      rewriteLatencyMs: Date.now() - rewriteStartedAt
    };
  } catch (error) {
    return {
      rawText: sttResult.rawText,
      cleanText: sttResult.rawText,
      sttModelId: sttResult.modelId,
      rewriteModel: env.OPENAI_MODEL,
      rewriteStatus: "fallback_raw",
      sttLatencyMs,
      rewriteLatencyMs: Date.now() - rewriteStartedAt,
      rewriteError: error instanceof Error ? error.message : String(error)
    };
  }
}
