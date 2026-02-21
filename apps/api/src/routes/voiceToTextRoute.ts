import { Router } from "express";
import multer from "multer";
import { env } from "../config/env";
import { HttpError } from "../lib/httpError";
import { parseBoolean, parseNumber } from "../lib/parse";
import { processVoiceToText } from "../services/voiceToTextService";
import { recordUsageEvent } from "../services/usageMeteringService";

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: env.TRANSCRIPTION_MAX_FILE_BYTES
  }
});

export const voiceToTextRouter = Router();

voiceToTextRouter.post(
  "/v1/voice-to-text",
  upload.single("file"),
  async (req, res, next): Promise<void> => {
    try {
      if (!req.file) {
        throw new HttpError(400, "Missing multipart file field 'file'");
      }

      const userId = extractUserId(req.header("x-user-id"));
      const requestId = String(res.locals.requestId ?? "unknown");
      const startedAt = Date.now();

      const voiceToTextResult = await processVoiceToText({
        fileBuffer: req.file.buffer,
        fileName: req.file.originalname || "audio.wav",
        mimeType: req.file.mimetype,
        requestId,
        userId,
        sttOptions: {
          modelId: stringOrUndefined(req.body.model_id),
          languageCode: stringOrUndefined(req.body.language_code),
          temperature: parseNumber(req.body.temperature),
          diarize: parseBoolean(req.body.diarize),
          tagAudioEvents: parseBoolean(req.body.tag_audio_events),
          keyterms: stringOrUndefined(req.body.keyterms)
        }
      });

      const totalLatencyMs = Date.now() - startedAt;

      await recordUsageEvent({
        requestId,
        userId,
        audioBytes: req.file.size,
        rawCharacters: voiceToTextResult.rawText.length,
        cleanCharacters: voiceToTextResult.cleanText.length,
        sttLatencyMs: voiceToTextResult.sttLatencyMs,
        rewriteLatencyMs: voiceToTextResult.rewriteLatencyMs
      });

      res.status(200).json({
        request_id: requestId,
        transcript: {
          raw_text: voiceToTextResult.rawText,
          clean_text: voiceToTextResult.cleanText
        },
        provider: {
          stt: {
            name: "elevenlabs",
            model_id: voiceToTextResult.sttModelId
          },
          rewrite: {
            name: "openai",
            model_id: voiceToTextResult.rewriteModel,
            status: voiceToTextResult.rewriteStatus
          }
        },
        timing: {
          stt_latency_ms: voiceToTextResult.sttLatencyMs,
          rewrite_latency_ms: voiceToTextResult.rewriteLatencyMs,
          total_latency_ms: totalLatencyMs
        },
        warnings:
          voiceToTextResult.rewriteStatus === "fallback_raw" && voiceToTextResult.rewriteError
            ? [{ code: "OPENAI_REWRITE_FALLBACK", message: voiceToTextResult.rewriteError }]
            : []
      });
    } catch (error) {
      next(error);
    }
  }
);

function stringOrUndefined(value: unknown): string | undefined {
  if (typeof value !== "string") {
    return undefined;
  }

  const normalized = value.trim();
  return normalized.length > 0 ? normalized : undefined;
}

function extractUserId(value: string | undefined): string {
  if (!value) {
    return "anonymous";
  }

  const normalized = value.trim();
  return normalized.length > 0 ? normalized : "anonymous";
}
