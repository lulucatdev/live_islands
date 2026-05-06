export class OperationError extends Error {}

function deepClone(obj) {
  if (obj === null || typeof obj !== "object") return obj;
  if (obj instanceof Date) return new Date(obj.getTime());
  if (Array.isArray(obj)) return obj.map((item) => deepClone(item));

  const cloned = {};
  for (const key in obj) {
    if (Object.prototype.hasOwnProperty.call(obj, key)) {
      cloned[key] = deepClone(obj[key]);
    }
  }
  return cloned;
}

function unescapePathComponent(path) {
  return path.replace(/~1/g, "/").replace(/~0/g, "~");
}

function resolvePathComponent(component, arrayObj) {
  if (!component.startsWith("$$")) return component;

  const targetId = component.substring(2);
  const index = arrayObj.findIndex(
    (item) => item && typeof item === "object" && item.__dom_id == targetId,
  );

  if (index === -1) return null;

  return index.toString();
}

export function getValueByPointer(document, pointer) {
  if (pointer === "") return document;

  const keys = pointer.split("/").slice(1);
  let obj = document;

  for (const key of keys) {
    let resolvedKey =
      key.indexOf("~") !== -1 ? unescapePathComponent(key) : key;

    if (Array.isArray(obj)) {
      if (resolvedKey.startsWith("$$")) {
        const resolved = resolvePathComponent(resolvedKey, obj);
        if (resolved === null) return undefined;
        resolvedKey = resolved;
      }
      obj =
        obj[resolvedKey === "-" ? obj.length - 1 : parseInt(resolvedKey, 10)];
    } else if (obj && typeof obj === "object") {
      obj = obj[resolvedKey];
    } else {
      return undefined;
    }
  }

  return obj;
}

export function applyOperation(document, operation) {
  if (operation.path === "") {
    switch (operation.op) {
      case "add":
      case "replace":
        return operation.value;
      case "move":
      case "copy":
        return getValueByPointer(document, operation.from);
      case "test":
        return document;
      case "remove":
        return null;
      default:
        return document;
    }
  }

  const keys = operation.path.split("/").slice(1);
  let obj = document;

  for (let i = 0; i < keys.length - 1; i++) {
    let key =
      keys[i].indexOf("~") !== -1 ? unescapePathComponent(keys[i]) : keys[i];

    if (Array.isArray(obj)) {
      if (key.startsWith("$$")) {
        const resolved = resolvePathComponent(key, obj);
        if (resolved === null) return document;
        key = resolved;
      }
      obj = obj[key === "-" ? obj.length - 1 : parseInt(key, 10)];
    } else {
      obj = obj[key];
    }

    if (obj === undefined || obj === null) return document;
  }

  const finalKey = keys[keys.length - 1];
  const unescapedKey =
    finalKey.indexOf("~") !== -1 ? unescapePathComponent(finalKey) : finalKey;

  if (Array.isArray(obj)) {
    let index;

    if (unescapedKey.startsWith("$$")) {
      const resolved = resolvePathComponent(unescapedKey, obj);
      if (resolved === null) return document;
      index = parseInt(resolved, 10);
    } else {
      index = unescapedKey === "-" ? obj.length : parseInt(unescapedKey, 10);
    }

    switch (operation.op) {
      case "add":
        obj.splice(index, 0, operation.value);
        break;
      case "remove":
        obj.splice(index, 1);
        break;
      case "replace":
        obj[index] = operation.value;
        break;
      case "upsert": {
        const upsertValue = operation.value;
        if (
          upsertValue &&
          typeof upsertValue === "object" &&
          "__dom_id" in upsertValue
        ) {
          const existingIndex = obj.findIndex(
            (item) =>
              item &&
              typeof item === "object" &&
              item.__dom_id === upsertValue.__dom_id,
          );
          if (existingIndex !== -1) {
            obj[existingIndex] = upsertValue;
          } else {
            obj.splice(index, 0, upsertValue);
          }
        } else {
          obj.splice(index, 0, upsertValue);
        }
        break;
      }
      case "move": {
        const moveValue = getValueByPointer(document, operation.from);
        if (moveValue === undefined) return document;
        applyOperation(document, { op: "remove", path: operation.from });
        obj.splice(index, 0, moveValue);
        break;
      }
      case "copy":
        obj.splice(
          index,
          0,
          deepClone(getValueByPointer(document, operation.from)),
        );
        break;
      case "limit":
        applyLimit(obj, operation.value);
        break;
      case "test":
        break;
    }
  } else if (obj && typeof obj === "object") {
    switch (operation.op) {
      case "add":
      case "replace":
        obj[unescapedKey] = operation.value;
        break;
      case "remove":
        delete obj[unescapedKey];
        break;
      case "move": {
        const moveValue = getValueByPointer(document, operation.from);
        applyOperation(document, { op: "remove", path: operation.from });
        obj[unescapedKey] = moveValue;
        break;
      }
      case "copy":
        obj[unescapedKey] = deepClone(
          getValueByPointer(document, operation.from),
        );
        break;
      case "limit":
        if (Array.isArray(obj[unescapedKey]))
          applyLimit(obj[unescapedKey], operation.value);
        break;
      case "test":
        break;
    }
  }

  return document;
}

function applyLimit(array, limit) {
  if (limit >= 0) {
    if (limit < array.length) array.splice(limit);
  } else {
    const keepCount = Math.abs(limit);
    if (keepCount < array.length) array.splice(0, array.length - keepCount);
  }
}

export function applyPatch(document, patch) {
  let result = document;

  for (const operation of patch) {
    result = applyOperation(result, operation);
  }

  return result;
}
