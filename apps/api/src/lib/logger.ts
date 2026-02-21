import pino, { type LoggerOptions } from "pino";
import { env } from "../config/env";

const loggerOptions: LoggerOptions = {
  name: "press-to-speak-api",
  level: env.LOG_LEVEL,
  redact: {
    paths: [
      "req.headers.authorization",
      "req.headers.x-api-key",
      "req.headers.x-openai-api-key",
      "req.headers.x-elevenlabs-api-key",
      "req.body.password",
      "req.body.refresh_token",
      "req.body.access_token"
    ],
    censor: "[REDACTED]"
  }
};

if (env.LOG_PRETTY) {
  loggerOptions.transport = {
    target: "pino-pretty",
    options: {
      colorize: true,
      singleLine: false,
      translateTime: "SYS:standard",
      ignore: "pid,hostname"
    }
  };
}

export const logger = pino(loggerOptions);
