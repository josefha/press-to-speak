import { Router } from "express";
import { z } from "zod";
import { env } from "../config/env";
import { HttpError } from "../lib/httpError";
import { compareDottedVersions, isDottedNumericVersion } from "../lib/version";
import { enforceProxyApiKey } from "../middleware/enforceProxyApiKey";

const querySchema = z.object({
  current_version: z
    .string()
    .trim()
    .max(32)
    .refine((value) => isDottedNumericVersion(value), "current_version must use dotted numeric format (for example 1.2.3)")
    .optional()
});

export const appUpdateRouter = Router();

appUpdateRouter.get("/v1/app-updates/macos", enforceProxyApiKey, (req, res, next): void => {
  try {
    const input = parseQuery(req.query);
    const currentVersion = input.current_version;

    const updateAvailable =
      currentVersion !== undefined ? compareDottedVersions(currentVersion, env.MAC_APP_LATEST_VERSION) < 0 : undefined;
    const updateRequired =
      currentVersion !== undefined
        ? compareDottedVersions(currentVersion, env.MAC_APP_MINIMUM_SUPPORTED_VERSION) < 0
        : undefined;

    res.set("Cache-Control", "no-store");
    res.status(200).json({
      request_id: res.locals.requestId,
      platform: "macos",
      latest_version: env.MAC_APP_LATEST_VERSION,
      minimum_supported_version: env.MAC_APP_MINIMUM_SUPPORTED_VERSION,
      update_available: updateAvailable,
      update_required: updateRequired,
      download_url: env.MAC_APP_DOWNLOAD_URL,
      release_notes_url: env.MAC_APP_RELEASE_NOTES_URL
    });
  } catch (error) {
    next(error);
  }
});

function parseQuery(query: unknown): z.infer<typeof querySchema> {
  const parsed = querySchema.safeParse(query);
  if (parsed.success) {
    return parsed.data;
  }

  throw new HttpError(400, "Invalid update check query parameters", {
    issues: parsed.error.issues.map((issue) => ({
      path: issue.path.join("."),
      message: issue.message
    }))
  });
}
