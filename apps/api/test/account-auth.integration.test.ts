import { createServer, type IncomingMessage, type Server, type ServerResponse } from "node:http";
import { after, before, beforeEach, describe, test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import type express from "express";

const VALID_PASSWORD = "correct-password-123";
const PROXY_SHARED_API_KEY = "proxy-shared-test-key";
const SUPABASE_PUBLISHABLE_KEY = "supabase-publishable-test-key";

let mockSupabaseServer: Server | undefined;
let apiServer: Server | undefined;
let apiBaseUrl = "";
let restoreEnv: (() => void) | undefined;
let resetAuthRateLimiter: (() => void) | undefined;

describe("account auth routes integration", () => {
  before(async () => {
    mockSupabaseServer = createMockSupabaseServer(SUPABASE_PUBLISHABLE_KEY);
    await listen(mockSupabaseServer);
    const mockSupabaseBaseUrl = serverBaseUrl(mockSupabaseServer);

    restoreEnv = withTestEnv({
      NODE_ENV: "test",
      LOG_LEVEL: "silent",
      LOG_PRETTY: "false",
      ELEVENLABS_API_KEY: "elevenlabs-test-key",
      OPENAI_API_KEY: "openai-test-key",
      USER_AUTH_MODE: "required",
      SUPABASE_URL: mockSupabaseBaseUrl,
      SUPABASE_PUBLISHABLE_KEY,
      SUPABASE_JWT_SECRET: "",
      PROXY_SHARED_API_KEY,
      MAC_APP_LATEST_VERSION: "2.5.0",
      MAC_APP_MINIMUM_SUPPORTED_VERSION: "2.3.0",
      MAC_APP_DOWNLOAD_URL: "https://downloads.presstospeak.com/macos",
      MAC_APP_RELEASE_NOTES_URL: "https://www.presstospeak.com/releases",
      AUTH_ROUTE_RATE_LIMIT_WINDOW_MS: "60000",
      AUTH_ROUTE_RATE_LIMIT_MAX_REQUESTS: "2"
    });

    const [{ createApp }, { resetAuthRouteRateLimitBucketsForTest }] = await Promise.all([
      import("../src/app"),
      import("../src/middleware/authRouteRateLimit")
    ]);
    resetAuthRateLimiter = resetAuthRouteRateLimitBucketsForTest;

    const app: express.Express = createApp();
    apiServer = app.listen(0, "127.0.0.1");
    await onceListening(apiServer);
    apiBaseUrl = serverBaseUrl(apiServer);
  });

  after(async () => {
    if (apiServer) {
      await closeServer(apiServer);
    }

    if (mockSupabaseServer) {
      await closeServer(mockSupabaseServer);
    }

    restoreEnv?.();
  });

  beforeEach(() => {
    resetAuthRateLimiter?.();
  });

  test("signup returns account and session when email confirmation is not required", async () => {
    const response = await postJson(
      "/v1/auth/signup",
      {
        email: "basic@example.com",
        password: VALID_PASSWORD,
        profile_name: "Basic User"
      },
      authorizedHeaders()
    );

    assert.equal(response.status, 201);
    const payload = await response.json();

    assert.equal(payload.requires_email_confirmation, false);
    assert.equal(payload.account.user_id.startsWith("user-"), true);
    assert.equal(payload.account.profile_name, "Basic User");
    assert.equal(payload.account.tier, "free");
    assert.equal(typeof payload.session.access_token, "string");
    assert.equal(typeof payload.session.refresh_token, "string");
  });

  test("signup returns requires_email_confirmation when session is absent", async () => {
    const response = await postJson(
      "/v1/auth/signup",
      {
        email: "confirm.user@example.com",
        password: VALID_PASSWORD
      },
      authorizedHeaders()
    );

    assert.equal(response.status, 200);
    const payload = await response.json();

    assert.equal(payload.requires_email_confirmation, true);
    assert.equal(payload.session, null);
    assert.equal(payload.account.email, "confirm.user@example.com");
  });

  test("login returns normalized account and session", async () => {
    const response = await postJson(
      "/v1/auth/login",
      {
        email: "alice+pro@example.com",
        password: VALID_PASSWORD
      },
      authorizedHeaders()
    );

    assert.equal(response.status, 200);
    const payload = await response.json();

    assert.equal(payload.account.email, "alice+pro@example.com");
    assert.equal(payload.account.profile_name, "Alice+pro");
    assert.equal(payload.account.tier, "pro");
    assert.equal(typeof payload.session.access_token, "string");
    assert.equal(typeof payload.session.refresh_token, "string");
  });

  test("refresh returns a fresh account session", async () => {
    const response = await postJson(
      "/v1/auth/refresh",
      {
        refresh_token: "refresh-token-user-refresh@example.com"
      },
      authorizedHeaders()
    );

    assert.equal(response.status, 200);
    const payload = await response.json();

    assert.equal(payload.account.email, "user-refresh@example.com");
    assert.equal(payload.account.tier, "free");
    assert.equal(typeof payload.session.access_token, "string");
    assert.equal(typeof payload.session.refresh_token, "string");
  });

  test("logout accepts bearer token and returns success", async () => {
    const response = await postJson(
      "/v1/auth/logout",
      {},
      {
        ...authorizedHeaders(),
        Authorization: "Bearer access-token-user-logout"
      }
    );

    assert.equal(response.status, 200);
    const payload = await response.json();
    assert.equal(payload.success, true);
  });

  test("missing proxy API key is rejected", async () => {
    const response = await postJson("/v1/auth/login", {
      email: "basic@example.com",
      password: VALID_PASSWORD
    });

    assert.equal(response.status, 401);
    const payload = await response.json();
    assert.equal(payload.error.message, "Missing or invalid proxy API key");
  });

  test("auth route rate limit returns 429 with ratelimit headers", async () => {
    const headers = authorizedHeaders("rate-limit");

    const first = await postJson(
      "/v1/auth/login",
      {
        email: "basic@example.com",
        password: VALID_PASSWORD
      },
      headers
    );
    assert.equal(first.status, 200);

    const second = await postJson(
      "/v1/auth/login",
      {
        email: "basic@example.com",
        password: VALID_PASSWORD
      },
      headers
    );
    assert.equal(second.status, 200);

    const third = await postJson(
      "/v1/auth/login",
      {
        email: "basic@example.com",
        password: VALID_PASSWORD
      },
      headers
    );
    assert.equal(third.status, 429);
    assert.equal(third.headers.get("x-ratelimit-limit"), "2");
    assert.equal(third.headers.get("x-ratelimit-remaining"), "0");

    const payload = await third.json();
    assert.equal(payload.error.message, "Rate limit exceeded for auth requests");
  });

  test("update route returns latest version metadata and update flags", async () => {
    const response = await getJson("/v1/app-updates/macos?current_version=2.2.9", authorizedHeaders());

    assert.equal(response.status, 200);
    const payload = await response.json();

    assert.equal(payload.platform, "macos");
    assert.equal(payload.latest_version, "2.5.0");
    assert.equal(payload.minimum_supported_version, "2.3.0");
    assert.equal(payload.update_available, true);
    assert.equal(payload.update_required, true);
    assert.equal(payload.download_url, "https://downloads.presstospeak.com/macos");
    assert.equal(payload.release_notes_url, "https://www.presstospeak.com/releases");
  });

  test("update route reports no update when current version is latest", async () => {
    const response = await getJson("/v1/app-updates/macos?current_version=2.5.0", authorizedHeaders());

    assert.equal(response.status, 200);
    const payload = await response.json();
    assert.equal(payload.update_available, false);
    assert.equal(payload.update_required, false);
  });

  test("update route rejects malformed current version", async () => {
    const response = await getJson("/v1/app-updates/macos?current_version=2.5-beta", authorizedHeaders());

    assert.equal(response.status, 400);
    const payload = await response.json();
    assert.equal(payload.error.message, "Invalid update check query parameters");
  });

  test("update route requires proxy key when shared key is configured", async () => {
    const response = await getJson("/v1/app-updates/macos?current_version=2.5.0");

    assert.equal(response.status, 401);
    const payload = await response.json();
    assert.equal(payload.error.message, "Missing or invalid proxy API key");
  });
});

function authorizedHeaders(rateLimitKey: string = randomUUID()): Record<string, string> {
  return {
    "x-api-key": PROXY_SHARED_API_KEY,
    "x-test-rate-limit-key": rateLimitKey
  };
}

async function postJson(
  path: string,
  body: Record<string, unknown>,
  headers: Record<string, string> = {}
): Promise<Response> {
  return fetch(`${apiBaseUrl}${path}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      ...headers
    },
    body: JSON.stringify(body)
  });
}

async function getJson(path: string, headers: Record<string, string> = {}): Promise<Response> {
  return fetch(`${apiBaseUrl}${path}`, {
    method: "GET",
    headers: {
      Accept: "application/json",
      ...headers
    }
  });
}

function createMockSupabaseServer(expectedPublishableKey: string): Server {
  return createServer(async (req, res) => {
    const requestUrl = new URL(req.url ?? "/", `http://${req.headers.host ?? "127.0.0.1"}`);
    const apikey = normalizeHeader(req.headers.apikey);
    if (apikey !== expectedPublishableKey) {
      sendJson(res, 401, { message: "Invalid API key" });
      return;
    }

    if (req.method === "POST" && requestUrl.pathname === "/auth/v1/signup") {
      const body = await readJsonBody(req);
      const email = normalizeString(body.email);
      const password = normalizeString(body.password);
      if (!email || !password || password.length < 8) {
        sendJson(res, 400, { message: "Invalid signup payload" });
        return;
      }

      const requiresEmailConfirmation = email.startsWith("confirm.");
      const account = makeAccount(email, body.data?.name);
      if (requiresEmailConfirmation) {
        sendJson(res, 200, {
          user: {
            id: account.userId,
            email: account.email,
            app_metadata: { tier: account.tier },
            user_metadata: { name: account.profileName }
          }
        });
        return;
      }

      sendJson(res, 200, makeSessionResponse(account));
      return;
    }

    if (req.method === "POST" && requestUrl.pathname === "/auth/v1/token") {
      const grantType = requestUrl.searchParams.get("grant_type");
      const body = await readJsonBody(req);

      if (grantType === "password") {
        const email = normalizeString(body.email);
        const password = normalizeString(body.password);
        if (!email || password !== VALID_PASSWORD) {
          sendJson(res, 400, { message: "Invalid login credentials" });
          return;
        }

        sendJson(res, 200, makeSessionResponse(makeAccount(email)));
        return;
      }

      if (grantType === "refresh_token") {
        const refreshToken = normalizeString(body.refresh_token);
        const email = extractRefreshEmail(refreshToken);
        if (!email) {
          sendJson(res, 401, { message: "Invalid refresh token" });
          return;
        }

        sendJson(res, 200, makeSessionResponse(makeAccount(email)));
        return;
      }

      sendJson(res, 400, { message: "Unsupported grant_type" });
      return;
    }

    if (req.method === "POST" && requestUrl.pathname === "/auth/v1/logout") {
      const authorization = normalizeHeader(req.headers.authorization);
      if (!authorization?.toLowerCase().startsWith("bearer access-token-")) {
        sendJson(res, 401, { message: "Invalid access token" });
        return;
      }

      sendJson(res, 200, {});
      return;
    }

    sendJson(res, 404, { message: "Mock Supabase route not found" });
  });
}

function makeSessionResponse(account: MockAccount): Record<string, unknown> {
  const now = Math.floor(Date.now() / 1000);
  return {
    access_token: `access-token-${account.userId}`,
    refresh_token: `refresh-token-${account.email}`,
    expires_at: now + 3600,
    user: {
      id: account.userId,
      email: account.email,
      app_metadata: { tier: account.tier },
      user_metadata: { name: account.profileName }
    }
  };
}

type MockAccount = {
  userId: string;
  email: string;
  profileName: string;
  tier: "free" | "pro";
};

function makeAccount(email: string, explicitName?: unknown): MockAccount {
  const normalizedEmail = email.trim().toLowerCase();
  const localPart = normalizedEmail.split("@")[0] ?? normalizedEmail;
  const profileName =
    normalizeString(explicitName) ??
    (localPart.length > 0 ? `${localPart.slice(0, 1).toUpperCase()}${localPart.slice(1)}` : "PressToSpeak User");
  const tier: "free" | "pro" = normalizedEmail.includes("+pro@") ? "pro" : "free";
  return {
    userId: `user-${Buffer.from(normalizedEmail).toString("hex").slice(0, 12)}`,
    email: normalizedEmail,
    profileName,
    tier
  };
}

function extractRefreshEmail(token: string | undefined): string | undefined {
  if (!token) {
    return undefined;
  }

  const prefix = "refresh-token-";
  if (!token.startsWith(prefix)) {
    return undefined;
  }

  const email = token.slice(prefix.length).trim().toLowerCase();
  return email.includes("@") ? email : undefined;
}

async function readJsonBody(req: IncomingMessage): Promise<Record<string, any>> {
  const chunks: Buffer[] = [];
  for await (const chunk of req) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }

  if (chunks.length === 0) {
    return {};
  }

  try {
    const text = Buffer.concat(chunks).toString("utf8");
    return JSON.parse(text) as Record<string, any>;
  } catch {
    return {};
  }
}

function sendJson(res: ServerResponse, statusCode: number, payload: Record<string, unknown>): void {
  const body = JSON.stringify(payload);
  res.statusCode = statusCode;
  res.setHeader("Content-Type", "application/json");
  res.setHeader("Content-Length", String(Buffer.byteLength(body)));
  res.end(body);
}

function normalizeString(value: unknown): string | undefined {
  if (typeof value !== "string") {
    return undefined;
  }

  const normalized = value.trim();
  return normalized.length > 0 ? normalized : undefined;
}

function normalizeHeader(value: string | string[] | undefined): string | undefined {
  if (Array.isArray(value)) {
    return normalizeHeader(value[0]);
  }

  return normalizeString(value);
}

async function listen(server: Server): Promise<void> {
  server.listen(0, "127.0.0.1");
  await onceListening(server);
}

async function onceListening(server: Server): Promise<void> {
  if (server.listening) {
    return;
  }

  await new Promise<void>((resolve, reject) => {
    const onError = (error: Error) => {
      server.off("listening", onListening);
      reject(error);
    };
    const onListening = () => {
      server.off("error", onError);
      resolve();
    };

    server.once("error", onError);
    server.once("listening", onListening);
  });
}

function serverBaseUrl(server: Server): string {
  const address = server.address();
  if (!address || typeof address === "string") {
    throw new Error("Server did not bind to an address");
  }
  return `http://127.0.0.1:${address.port}`;
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
