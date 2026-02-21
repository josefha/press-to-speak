import pino, { type LoggerOptions } from "pino";
import { env } from "../config/env";

const loggerOptions: LoggerOptions = {
  name: "press-to-speak-api",
  level: env.LOG_LEVEL
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
