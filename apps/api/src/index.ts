import { env } from "./config/env";
import { createApp } from "./app";
import { logger } from "./lib/logger";

const app = createApp();
const startupLogger = logger.child({ component: "server" });

const server = app.listen(env.PORT, () => {
  startupLogger.info({ port: env.PORT }, `PressToSpeak API listening on http://localhost:${env.PORT}`);
});

const shutdown = (signal: NodeJS.Signals) => {
  startupLogger.info({ signal }, "Shutting down API server");
  server.close(() => {
    process.exit(0);
  });
};

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
