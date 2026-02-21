import { randomUUID } from "node:crypto";
import type { NextFunction, Request, Response } from "express";

export function requestContext(req: Request, res: Response, next: NextFunction): void {
  const inboundRequestId = req.header("x-request-id");
  const requestId = inboundRequestId?.trim() || randomUUID();

  res.locals.requestId = requestId;
  res.setHeader("x-request-id", requestId);

  next();
}
