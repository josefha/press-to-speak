import assert from "node:assert/strict";
import { createServer, type IncomingMessage, type Server, type ServerResponse } from "node:http";
import { after, before, beforeEach, describe, test } from "node:test";

type PlannedResponse = {
  statusCode: number;
  headers?: Record<string, string>;
  body?: string;
};

let mockElevenLabsServer: Server | undefined;
let mockServerBaseUrl = "";
let requestCount = 0;
let plannedResponses: PlannedResponse[] = [];
let restoreEnv: (() => void) | undefined;

let transcribeWithElevenLabs: typeof import("../src/external/elevenLabsClient").transcribeWithElevenLabs;

describe("elevenLabsClient", () => {
  before(async () => {
    mockElevenLabsServer = createMockElevenLabsServer();
    await listen(mockElevenLabsServer);
    mockServerBaseUrl = serverBaseUrl(mockElevenLabsServer);

    restoreEnv = withTestEnv({
      NODE_ENV: "test",
      LOG_LEVEL: "silent",
      LOG_PRETTY: "false",
      LOG_PIPELINE_TEXT: "false",
      LOG_PROVIDER_PAYLOADS: "false",
      ELEVENLABS_API_KEY: "elevenlabs-test-key",
      ELEVENLABS_API_BASE_URL: mockServerBaseUrl,
      ELEVENLABS_MODEL_ID: "scribe_v2",
      TRANSCRIPTION_REQUEST_TIMEOUT_MS: "2000",
      TRANSCRIPTION_MAX_FILE_BYTES: "26214400",
      OPENAI_API_KEY: "openai-test-key",
      OPENAI_API_BASE_URL: "https://api.openai.com/v1",
      OPENAI_MODEL: "gpt-5-mini",
      OPENAI_REWRITE_TIMEOUT_MS: "2000",
      USER_AUTH_MODE: "off",
      MAC_APP_LATEST_VERSION: "0.1.0",
      MAC_APP_MINIMUM_SUPPORTED_VERSION: "0.1.0",
      MAC_APP_DOWNLOAD_URL: "https://www.presstospeak.com/",
      MAC_APP_RELEASE_NOTES_URL: "https://www.presstospeak.com/"
    });

    ({ transcribeWithElevenLabs } = await import("../src/external/elevenLabsClient"));
  });

  after(async () => {
    if (mockElevenLabsServer) {
      await closeServer(mockElevenLabsServer);
    }
    restoreEnv?.();
  });

  beforeEach(() => {
    requestCount = 0;
    plannedResponses = [];
  });

  test("retries transient 502 errors and returns transcript on success", async () => {
    plannedResponses = [
      {
        statusCode: 502,
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ message: "Bad gateway (first attempt)" })
      },
      {
        statusCode: 502,
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ message: "Bad gateway (second attempt)" })
      },
      {
        statusCode: 200,
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ text: "clean transcript" })
      }
    ];

    const result = await transcribeWithElevenLabs({
      fileBuffer: Buffer.from("fake-audio"),
      fileName: "sample.wav",
      mimeType: "audio/wav"
    });

    assert.equal(result.rawText, "clean transcript");
    assert.equal(result.modelId, "scribe_v2");
    assert.equal(requestCount, 3);
  });

  test("returns upstream status details when provider sends empty JSON body", async () => {
    plannedResponses = [
      {
        statusCode: 502,
        headers: { "content-type": "application/json" },
        body: ""
      },
      {
        statusCode: 502,
        headers: { "content-type": "application/json" },
        body: ""
      },
      {
        statusCode: 502,
        headers: { "content-type": "application/json" },
        body: ""
      }
    ];

    await assert.rejects(
      () =>
        transcribeWithElevenLabs({
          fileBuffer: Buffer.from("fake-audio"),
          fileName: "sample.wav",
          mimeType: "audio/wav"
        }),
      (error: unknown) => {
        const httpError = error as { statusCode?: number; message?: string; details?: unknown };
        assert.equal(httpError.statusCode, 502);
        assert.equal(httpError.message, "ElevenLabs transcription request failed");
        assert.deepEqual(httpError.details, {
          endpoint: `${mockServerBaseUrl}/v1/speech-to-text`,
          status: 502,
          payload: null,
          attempts: 3
        });
        assert.equal(requestCount, 3);
        return true;
      }
    );
  });

  test("does not retry on non-retryable provider errors", async () => {
    plannedResponses = [
      {
        statusCode: 400,
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ detail: "invalid model" })
      }
    ];

    await assert.rejects(
      () =>
        transcribeWithElevenLabs({
          fileBuffer: Buffer.from("fake-audio"),
          fileName: "sample.wav",
          mimeType: "audio/wav"
        }),
      (error: unknown) => {
        const httpError = error as { statusCode?: number; message?: string };
        assert.equal(httpError.statusCode, 400);
        assert.equal(httpError.message, "ElevenLabs transcription request failed");
        assert.equal(requestCount, 1);
        return true;
      }
    );
  });
});

function createMockElevenLabsServer(): Server {
  return createServer(async (req, res) => {
    await consumeRequestBody(req);

    if (req.method !== "POST" || req.url !== "/v1/speech-to-text") {
      sendJson(res, 404, { error: "not_found" });
      return;
    }

    requestCount += 1;

    const nextResponse = plannedResponses.shift() ?? {
      statusCode: 500,
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ message: "Missing planned response" })
    };

    const headers = nextResponse.headers ?? { "content-type": "application/json" };
    for (const [headerName, headerValue] of Object.entries(headers)) {
      res.setHeader(headerName, headerValue);
    }

    res.statusCode = nextResponse.statusCode;
    res.end(nextResponse.body ?? "");
  });
}

function sendJson(res: ServerResponse, statusCode: number, payload: unknown): void {
  res.statusCode = statusCode;
  res.setHeader("content-type", "application/json");
  res.end(JSON.stringify(payload));
}

async function consumeRequestBody(req: IncomingMessage): Promise<void> {
  await new Promise<void>((resolve, reject) => {
    req.on("data", () => {
      // Consume request stream for completeness.
    });
    req.on("end", () => resolve());
    req.on("error", reject);
  });
}

async function listen(server: Server): Promise<void> {
  await new Promise<void>((resolve, reject) => {
    server.listen(0, "127.0.0.1", () => resolve());
    server.on("error", reject);
  });
}

async function closeServer(server: Server): Promise<void> {
  await new Promise<void>((resolve, reject) => {
    server.close((error) => {
      if (error) {
        reject(error);
        return;
      }
      resolve();
    });
  });
}

function serverBaseUrl(server: Server): string {
  const address = server.address();
  if (!address || typeof address === "string") {
    throw new Error("Server is not listening on a TCP port");
  }
  return `http://127.0.0.1:${address.port}`;
}

function withTestEnv(overrides: Record<string, string>): () => void {
  const previous = new Map<string, string | undefined>();
  for (const [key, value] of Object.entries(overrides)) {
    previous.set(key, process.env[key]);
    process.env[key] = value;
  }

  return () => {
    for (const [key, value] of previous.entries()) {
      if (value === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = value;
      }
    }
  };
}
