import type { NextFunction, Request, Response } from "express";
import { HttpError } from "../lib/httpError";
import { logger } from "../lib/logger";

const errorLogger = logger.child({ component: "error-handler" });

export function errorHandler(error: unknown, req: Request, res: Response, _next: NextFunction): void {
  if (error instanceof HttpError) {
    const logPayload: Record<string, unknown> = {
      requestId: res.locals.requestId,
      method: req.method,
      path: req.originalUrl,
      statusCode: error.statusCode,
      errorMessage: error.message
    };
    if (error.details !== undefined) {
      logPayload.errorDetails = error.details;
    }

    if (error.statusCode >= 500) {
      errorLogger.error(logPayload, "request failed with HttpError");
    } else {
      errorLogger.warn(logPayload, "request failed with HttpError");
    }

    res.status(error.statusCode).json({
      error: {
        message: error.message,
        details: error.details
      },
      request_id: res.locals.requestId
    });
    return;
  }

  const message = error instanceof Error ? error.message : "Unexpected server error";
  errorLogger.error(
    {
      requestId: res.locals.requestId,
      method: req.method,
      path: req.originalUrl,
      errorMessage: message,
      stack: error instanceof Error ? error.stack : undefined
    },
    "request failed with unexpected error"
  );
  res.status(500).json({
    error: {
      message
    },
    request_id: res.locals.requestId
  });
}

export function notFoundHandler(req: Request, res: Response): void {
  res.status(404).json({
    error: {
      message: `Route not found: ${req.method} ${req.originalUrl}`
    },
    request_id: res.locals.requestId
  });
}
