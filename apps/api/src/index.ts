import { env } from "./config/env";
import { createApp } from "./app";

const app = createApp();

const server = app.listen(env.PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`PressToSpeak API listening on http://localhost:${env.PORT}`);
});

const shutdown = (signal: NodeJS.Signals) => {
  // eslint-disable-next-line no-console
  console.log(`Received ${signal}. Shutting down API server...`);
  server.close(() => {
    process.exit(0);
  });
};

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
