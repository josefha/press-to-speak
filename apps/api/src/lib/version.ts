const VERSION_PATTERN = /^\d+(?:\.\d+){0,3}$/;

export function isDottedNumericVersion(value: string): boolean {
  return VERSION_PATTERN.test(value);
}

export function compareDottedVersions(left: string, right: string): number {
  const leftSegments = parseVersionSegments(left);
  const rightSegments = parseVersionSegments(right);

  if (!leftSegments || !rightSegments) {
    throw new Error("Version must use dotted numeric format");
  }

  const maxSegments = Math.max(leftSegments.length, rightSegments.length);

  for (let index = 0; index < maxSegments; index += 1) {
    const leftValue = leftSegments[index] ?? 0;
    const rightValue = rightSegments[index] ?? 0;

    if (leftValue < rightValue) {
      return -1;
    }

    if (leftValue > rightValue) {
      return 1;
    }
  }

  return 0;
}

function parseVersionSegments(value: string): number[] | null {
  if (!isDottedNumericVersion(value)) {
    return null;
  }

  return value.split(".").map((segment) => Number.parseInt(segment, 10));
}
