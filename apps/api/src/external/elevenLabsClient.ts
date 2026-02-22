import { env } from "../config/env";
import { HttpError } from "../lib/httpError";

export type ElevenLabsRequestOptions = {
  modelId?: string;
  languageCode?: string;
  temperature?: number;
  diarize?: boolean;
  tagAudioEvents?: boolean;
  keyterms?: string;
};

export type ElevenLabsTranscriptionInput = {
  fileBuffer: Buffer;
  fileName: string;
  mimeType?: string;
  options?: ElevenLabsRequestOptions;
  apiKey?: string;
  baseUrl?: string;
};

export type ElevenLabsTranscriptionResult = {
  rawText: string;
  providerPayload: unknown;
  modelId: string;
};

const TEXT_KEYS = ["text", "transcript", "result", "output", "content"] as const;
const RETRYABLE_STATUS_CODES = new Set([408, 429, 500, 502, 503, 504]);
const MAX_TRANSCRIPTION_ATTEMPTS = 3;
const RETRY_BASE_DELAY_MS = 150;

export async function transcribeWithElevenLabs(
  input: ElevenLabsTranscriptionInput
): Promise<ElevenLabsTranscriptionResult> {
  const modelId = input.options?.modelId ?? env.ELEVENLABS_MODEL_ID;
  const apiKey = normalizeOptional(input.apiKey) ?? env.ELEVENLABS_API_KEY;
  if (!apiKey) {
    throw new HttpError(400, "ElevenLabs API key is required");
  }

  const baseUrl = normalizeOptional(input.baseUrl) ?? env.ELEVENLABS_API_BASE_URL;
  const endpoint = `${baseUrl.replace(/\/+$/, "")}/v1/speech-to-text`;

  let lastError: HttpError | undefined;
  for (let attempt = 1; attempt <= MAX_TRANSCRIPTION_ATTEMPTS; attempt += 1) {
    try {
      const result = await sendTranscriptionRequest({
        endpoint,
        apiKey,
        modelId,
        input
      });
      return result;
    } catch (error) {
      const normalizedError = normalizeTranscriptionError(error);
      const canRetry = attempt < MAX_TRANSCRIPTION_ATTEMPTS && RETRYABLE_STATUS_CODES.has(normalizedError.statusCode);
      if (!canRetry) {
        throw withAttemptCount(normalizedError, attempt);
      }

      lastError = withAttemptCount(normalizedError, attempt);
      await wait(computeRetryDelayMs(attempt));
    }
  }

  throw lastError ?? new HttpError(502, "Unexpected failure while calling ElevenLabs");
}

async function sendTranscriptionRequest(input: {
  endpoint: string;
  apiKey: string;
  modelId: string;
  input: ElevenLabsTranscriptionInput;
}): Promise<ElevenLabsTranscriptionResult> {
  const formData = createTranscriptionFormData({
    fileBuffer: input.input.fileBuffer,
    fileName: input.input.fileName,
    mimeType: input.input.mimeType,
    modelId: input.modelId,
    options: input.input.options
  });

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), env.TRANSCRIPTION_REQUEST_TIMEOUT_MS);

  try {
    const response = await fetch(input.endpoint, {
      method: "POST",
      headers: {
        "xi-api-key": input.apiKey
      },
      body: formData,
      signal: controller.signal
    });

    const payload = await parseProviderPayload(response);

    if (!response.ok) {
      throw new HttpError(response.status, "ElevenLabs transcription request failed", {
        endpoint: input.endpoint,
        status: response.status,
        payload
      });
    }

    const rawText = extractTranscriptText(payload);
    if (!rawText) {
      throw new HttpError(502, "ElevenLabs response did not include transcript text", {
        payload
      });
    }

    return {
      rawText,
      providerPayload: payload,
      modelId: input.modelId
    };
  } catch (error) {
    if (error instanceof HttpError) {
      throw error;
    }

    if (error instanceof Error && error.name === "AbortError") {
      throw new HttpError(504, "ElevenLabs transcription request timed out", {
        timeoutMs: env.TRANSCRIPTION_REQUEST_TIMEOUT_MS
      });
    }

    throw new HttpError(502, "Unexpected failure while calling ElevenLabs", {
      cause: error instanceof Error ? error.message : String(error)
    });
  } finally {
    clearTimeout(timeout);
  }
}

function createTranscriptionFormData(input: {
  fileBuffer: Buffer;
  fileName: string;
  mimeType?: string;
  modelId: string;
  options?: ElevenLabsRequestOptions;
}): FormData {
  const formData = new FormData();
  const safeFileName = input.fileName || `audio-${Date.now()}.wav`;
  const mimeType = input.mimeType || "application/octet-stream";
  const fileArrayBuffer = input.fileBuffer.buffer.slice(
    input.fileBuffer.byteOffset,
    input.fileBuffer.byteOffset + input.fileBuffer.byteLength
  ) as ArrayBuffer;

  formData.append("file", new Blob([fileArrayBuffer], { type: mimeType }), safeFileName);
  formData.append("model_id", input.modelId);

  appendIfDefined(formData, "language_code", input.options?.languageCode);
  appendIfDefined(formData, "temperature", input.options?.temperature);
  appendIfDefined(formData, "diarize", input.options?.diarize);
  appendIfDefined(formData, "tag_audio_events", input.options?.tagAudioEvents);
  appendIfDefined(formData, "keyterms", input.options?.keyterms);

  return formData;
}

function normalizeTranscriptionError(error: unknown): HttpError {
  if (error instanceof HttpError) {
    return error;
  }

  return new HttpError(502, "Unexpected failure while calling ElevenLabs", {
    cause: error instanceof Error ? error.message : String(error)
  });
}

function withAttemptCount(error: HttpError, attempts: number): HttpError {
  if (attempts <= 1) {
    return error;
  }

  return new HttpError(error.statusCode, error.message, mergeDetails(error.details, { attempts }));
}

function mergeDetails(details: unknown, extra: Record<string, unknown>): unknown {
  if (!details || typeof details !== "object" || Array.isArray(details)) {
    return {
      ...extra,
      details
    };
  }

  return {
    ...(details as Record<string, unknown>),
    ...extra
  };
}

function computeRetryDelayMs(attempt: number): number {
  return RETRY_BASE_DELAY_MS * attempt;
}

async function wait(durationMs: number): Promise<void> {
  await new Promise((resolve) => {
    setTimeout(resolve, durationMs);
  });
}

function normalizeOptional(value: string | undefined): string | undefined {
  if (value === undefined) {
    return undefined;
  }

  const normalized = value.trim();
  return normalized.length > 0 ? normalized : undefined;
}

function appendIfDefined(formData: FormData, key: string, value: string | number | boolean | undefined): void {
  if (value === undefined || value === null || value === "") {
    return;
  }

  formData.append(key, String(value));
}

async function parseProviderPayload(response: Response): Promise<unknown> {
  const contentType = response.headers.get("content-type") ?? "";
  const rawText = await response.text();
  if (!rawText) {
    return null;
  }

  if (contentType.includes("application/json") || looksLikeJson(rawText)) {
    return parsePossiblyJsonText(rawText);
  }

  return {
    text: rawText
  };
}

function parsePossiblyJsonText(value: string): unknown {
  try {
    return JSON.parse(value);
  } catch {
    return { text: value };
  }
}

function looksLikeJson(value: string): boolean {
  const normalized = value.trim();
  return normalized.startsWith("{") || normalized.startsWith("[");
}

function extractTranscriptText(payload: unknown): string | null {
  if (!payload || typeof payload !== "object") {
    return null;
  }

  const data = payload as Record<string, unknown>;
  for (const key of TEXT_KEYS) {
    const value = data[key];
    if (typeof value === "string" && value.trim()) {
      return value.trim();
    }
  }

  return null;
}
