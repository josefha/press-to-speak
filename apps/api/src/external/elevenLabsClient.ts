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

export async function transcribeWithElevenLabs(
  input: ElevenLabsTranscriptionInput
): Promise<ElevenLabsTranscriptionResult> {
  const modelId = input.options?.modelId ?? env.ELEVENLABS_MODEL_ID;
  const apiKey = normalizeOptional(input.apiKey) ?? env.ELEVENLABS_API_KEY;
  if (!apiKey) {
    throw new HttpError(400, "ElevenLabs API key is required");
  }

  const formData = new FormData();

  const safeFileName = input.fileName || `audio-${Date.now()}.wav`;
  const mimeType = input.mimeType || "application/octet-stream";
  const fileArrayBuffer = input.fileBuffer.buffer.slice(
    input.fileBuffer.byteOffset,
    input.fileBuffer.byteOffset + input.fileBuffer.byteLength
  ) as ArrayBuffer;

  formData.append("file", new Blob([fileArrayBuffer], { type: mimeType }), safeFileName);
  formData.append("model_id", modelId);

  appendIfDefined(formData, "language_code", input.options?.languageCode);
  appendIfDefined(formData, "temperature", input.options?.temperature);
  appendIfDefined(formData, "diarize", input.options?.diarize);
  appendIfDefined(formData, "tag_audio_events", input.options?.tagAudioEvents);
  appendIfDefined(formData, "keyterms", input.options?.keyterms);

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), env.TRANSCRIPTION_REQUEST_TIMEOUT_MS);

  const baseUrl = normalizeOptional(input.baseUrl) ?? env.ELEVENLABS_API_BASE_URL;
  const endpoint = `${baseUrl.replace(/\/+$/, "")}/v1/speech-to-text`;

  try {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "xi-api-key": apiKey
      },
      body: formData,
      signal: controller.signal
    });

    const payload = await parseProviderPayload(response);

    if (!response.ok) {
      throw new HttpError(response.status, "ElevenLabs transcription request failed", {
        endpoint,
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
      modelId
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
  if (contentType.includes("application/json")) {
    return response.json();
  }

  return {
    text: await response.text()
  };
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
