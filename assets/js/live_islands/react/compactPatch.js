import { OperationError } from "./jsonPatch";

const opByCode = {
  a: "add",
  d: "remove",
  r: "replace",
  u: "upsert",
  l: "limit",
};

const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder();

export function decodeCompactPatch(payload) {
  if (!payload) return [];

  const operations = [];
  let offset = 0;

  while (offset < payload.length) {
    const code = payload[offset++];

    if (code === "n") {
      const result = readDigits(payload, offset);
      offset = result.offset;
      continue;
    }

    const op = opByCode[code];
    if (!op)
      throw new OperationError(
        `Unknown LiveIslands patch operation code: ${code}`,
      );

    const pathLength = readLength(payload, offset);
    offset = pathLength.offset;

    const pathResult = readUtf8Bytes(payload, offset, pathLength.value);
    offset = pathResult.offset;
    const path = decodePath(pathResult.value);

    if (op === "remove") {
      operations.push({ op, path });
      continue;
    }

    const valueResult = readValue(payload, offset);
    offset = valueResult.offset;
    operations.push({ op, path, value: valueResult.value });
  }

  return operations;
}

function decodePath(path) {
  if (path === "") return "";

  return `/${path
    .split(".")
    .map((segment) => segment.replace(/~2/g, "."))
    .join("/")}`;
}

function readValue(payload, offset) {
  const tag = payload[offset++];

  switch (tag) {
    case "z":
      return { value: null, offset };
    case "b":
      return { value: payload[offset++] === "1", offset };
    case "n": {
      const result = readLengthPrefixed(payload, offset);
      return { value: Number(result.value), offset: result.offset };
    }
    case "s":
      return readLengthPrefixed(payload, offset);
    case "J": {
      const result = readLengthPrefixed(payload, offset);
      return {
        value: JSON.parse(fromBase64Url(result.value)),
        offset: result.offset,
      };
    }
    default:
      throw new OperationError(`Unknown LiveIslands patch value tag: ${tag}`);
  }
}

function readLengthPrefixed(payload, offset) {
  const length = readLength(payload, offset);
  const value = readUtf8Bytes(payload, length.offset, length.value);
  return { value: value.value, offset: value.offset };
}

function readLength(payload, offset) {
  const result = readDigits(payload, offset);
  if (payload[result.offset] !== ":")
    throw new OperationError("Invalid LiveIslands patch length prefix");
  return { value: Number(result.value), offset: result.offset + 1 };
}

function readDigits(payload, offset) {
  const start = offset;
  while (
    offset < payload.length &&
    payload.charCodeAt(offset) >= 48 &&
    payload.charCodeAt(offset) <= 57
  ) {
    offset++;
  }
  return { value: payload.slice(start, offset), offset };
}

function readUtf8Bytes(payload, offset, byteLength) {
  let end = offset;
  let bytes = 0;

  while (end < payload.length && bytes < byteLength) {
    const codePoint = payload.codePointAt(end);
    if (codePoint === undefined) break;

    const char = String.fromCodePoint(codePoint);
    bytes += textEncoder.encode(char).length;
    end += char.length;
  }

  if (bytes !== byteLength)
    throw new OperationError("Invalid LiveIslands patch UTF-8 byte length");

  return { value: payload.slice(offset, end), offset: end };
}

function fromBase64Url(value) {
  const padded = value
    .replace(/-/g, "+")
    .replace(/_/g, "/")
    .padEnd(Math.ceil(value.length / 4) * 4, "=");
  const binary = atob(padded);
  const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
  return textDecoder.decode(bytes);
}
