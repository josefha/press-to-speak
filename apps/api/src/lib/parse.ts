export function parseBoolean(input: unknown): boolean | undefined {
  if (typeof input === "boolean") {
    return input;
  }

  if (typeof input !== "string") {
    return undefined;
  }

  const normalized = input.trim().toLowerCase();
  if (normalized === "true" || normalized === "1") {
    return true;
  }

  if (normalized === "false" || normalized === "0") {
    return false;
  }

  return undefined;
}

export function parseNumber(input: unknown): number | undefined {
  if (typeof input === "number" && Number.isFinite(input)) {
    return input;
  }

  if (typeof input !== "string") {
    return undefined;
  }

  const parsed = Number(input);
  return Number.isFinite(parsed) ? parsed : undefined;
}
