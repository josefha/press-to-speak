import cors from "cors";
import express from "express";
import helmet from "helmet";
import pinoHttp from "pino-http";
import { requestContext } from "./middleware/requestContext";
import { errorHandler, notFoundHandler } from "./middleware/errorHandler";
import { accountAuthRouter } from "./routes/accountAuthRoute";
import { appUpdateRouter } from "./routes/appUpdateRoute";
import { voiceToTextRouter } from "./routes/voiceToTextRoute";
import { logger } from "./lib/logger";

export function createApp(): express.Express {
  const app = express();

  app.disable("x-powered-by");
  app.use(helmet());
  app.use(cors());
  app.use(express.json({ limit: "1mb" }));
  app.use(requestContext);
  app.use(
    pinoHttp({
      logger,
      genReqId: (req, res) => {
        const requestId = String(res.locals.requestId || req.id || "unknown");
        return requestId;
      }
    })
  );

  app.get("/healthz", (_req, res) => {
    res.status(200).json({
      status: "ok",
      service: "press-to-speak-api",
      timestamp: new Date().toISOString(),
      request_id: res.locals.requestId
    });
  });

  app.use(appUpdateRouter);
  app.use(accountAuthRouter);
  app.use(voiceToTextRouter);
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
