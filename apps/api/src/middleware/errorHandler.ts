import type { NextFunction, Request, Response } from "express";
import { HttpError } from "../lib/httpError";

export function errorHandler(error: unknown, _req: Request, res: Response, _next: NextFunction): void {
  if (error instanceof HttpError) {
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
