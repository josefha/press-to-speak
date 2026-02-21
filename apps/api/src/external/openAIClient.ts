import { env } from "../config/env";
import { HttpError } from "../lib/httpError";

export type OpenAIRewriteResult = {
  cleanText: string;
  model: string;
  providerPayload: unknown;
};

export type OpenAIRewriteOptions = {
  apiKey?: string;
  baseUrl?: string;
  model?: string;
  timeoutMs?: number;
};

const CLEANUP_INSTRUCTIONS = [
  "You are a transcript cleanup engine.",
  "Rewrite spoken transcript into clean written text.",
  "Fix punctuation, capitalization, and grammar.",
  "Remove filler words like 'uh', 'um', and 'hmm' when they add no meaning.",
  "Preserve the original meaning and tone.",
  "Return only the final cleaned text with no extra commentary."
].join(" ");

export async function rewriteTranscriptWithOpenAI(
  rawText: string,
  options?: OpenAIRewriteOptions
): Promise<OpenAIRewriteResult> {
  const transcript = rawText.trim();
  const model = normalizeOptional(options?.model) ?? env.OPENAI_MODEL;
  const apiKey = normalizeOptional(options?.apiKey) ?? env.OPENAI_API_KEY;
  const timeoutMs = options?.timeoutMs ?? env.OPENAI_REWRITE_TIMEOUT_MS;
  const baseUrl = normalizeOptional(options?.baseUrl) ?? env.OPENAI_API_BASE_URL;

  if (!apiKey) {
    throw new HttpError(400, "OpenAI API key is required");
  }

  if (!transcript) {
    return {
      cleanText: "",
      model,
      providerPayload: { skipped: true }
    };
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  const endpoint = `${baseUrl.replace(/\/+$/, "")}/responses`;

  try {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`
      },
      body: JSON.stringify({
        model,
        instructions: CLEANUP_INSTRUCTIONS,
        input: transcript,
        max_output_tokens: Math.min(Math.max(transcript.length * 2, 120), 1_000),
        reasoning: {
          effort: "minimal"
        },
        store: false
      }),
      signal: controller.signal
    });

    const payload = await parseProviderPayload(response);

    if (!response.ok) {
      throw new HttpError(response.status, "OpenAI rewrite request failed", {
        endpoint,
        status: response.status,
        payload
      });
    }

    const cleanText = extractOutputText(payload);
    if (!cleanText) {
      throw new HttpError(502, "OpenAI response did not include rewritten text", {
        payload
      });
    }

    return {
      cleanText,
      model,
      providerPayload: payload
    };
  } catch (error) {
    if (error instanceof HttpError) {
      throw error;
    }

    if (error instanceof Error && error.name === "AbortError") {
      throw new HttpError(504, "OpenAI rewrite request timed out", {
        timeoutMs
      });
    }

    throw new HttpError(502, "Unexpected failure while calling OpenAI", {
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

async function parseProviderPayload(response: Response): Promise<unknown> {
  const contentType = response.headers.get("content-type") ?? "";
  if (contentType.includes("application/json")) {
    return response.json();
  }

  return {
    text: await response.text()
  };
}

function extractOutputText(payload: unknown): string | null {
  if (!payload || typeof payload !== "object") {
    return null;
  }

  const data = payload as Record<string, unknown>;
  const direct = data.output_text;
  if (typeof direct === "string" && direct.trim()) {
    return direct.trim();
  }

  const output = data.output;
  if (!Array.isArray(output)) {
    return null;
  }

  const parts: string[] = [];
  for (const item of output) {
    if (!item || typeof item !== "object") {
      continue;
    }

    const content = (item as Record<string, unknown>).content;
    if (!Array.isArray(content)) {
      continue;
    }

    for (const chunk of content) {
      if (!chunk || typeof chunk !== "object") {
        continue;
      }

      const chunkRecord = chunk as Record<string, unknown>;
      const text = typeof chunkRecord.text === "string" ? chunkRecord.text : undefined;
      const outputText = typeof chunkRecord.output_text === "string" ? chunkRecord.output_text : undefined;
      const value = text ?? outputText;
      if (value && value.trim()) {
        parts.push(value.trim());
      }
    }
  }

  if (!parts.length) {
    return null;
  }

  return parts.join(" ").replace(/\s+/g, " ").trim();
}
