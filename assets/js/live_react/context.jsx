import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";

export const LiveReactContext = createContext(null);
export const LiveFormContext = createContext(null);

export function LiveReactProvider({ children, ...props }) {
  return (
    <LiveReactContext.Provider value={props}>
      {children}
    </LiveReactContext.Provider>
  );
}

export function useLiveReact() {
  const live = useContext(LiveReactContext);
  if (!live)
    throw new Error(
      "LiveReact not provided. Use this hook inside a LiveReact component.",
    );
  return live;
}

export function useLiveEvent(event, callback) {
  const live = useLiveReact();
  const callbackRef = useRef(callback);

  useEffect(() => {
    callbackRef.current = callback;
  }, [callback]);

  useEffect(() => {
    const handlerRef = live.handleEvent(event, (payload) =>
      callbackRef.current(payload),
    );
    return () => {
      if (handlerRef) live.removeHandleEvent(handlerRef);
    };
  }, [event, live]);
}

export function useLiveNavigation() {
  const live = useLiveReact();
  const liveSocket = live.liveSocket;
  if (!liveSocket) throw new Error("LiveSocket not initialized");

  const patch = useCallback(
    (hrefOrQueryParams, opts = {}) => {
      let href =
        typeof hrefOrQueryParams === "string"
          ? hrefOrQueryParams
          : window.location.pathname;

      if (hrefOrQueryParams && typeof hrefOrQueryParams === "object") {
        const queryParams = new URLSearchParams(hrefOrQueryParams);
        href = `${href}?${queryParams.toString()}`;
      }

      liveSocket.pushHistoryPatch(
        new Event("click"),
        href,
        opts.replace ? "replace" : "push",
        null,
      );
    },
    [liveSocket],
  );

  const navigate = useCallback(
    (href, opts = {}) => {
      liveSocket.historyRedirect(
        new Event("click"),
        href,
        opts.replace ? "replace" : "push",
        null,
        null,
      );
    },
    [liveSocket],
  );

  return { patch, navigate };
}

export function useEventReply(eventName, options = {}) {
  const live = useLiveReact();
  const [data, setData] = useState(options.defaultValue ?? null);
  const [isLoading, setIsLoading] = useState(false);
  const isLoadingRef = useRef(false);
  const executionToken = useRef(0);
  const pendingReject = useRef(null);

  useEffect(() => {
    isLoadingRef.current = isLoading;
  }, [isLoading]);

  const execute = useCallback(
    (params = {}) => {
      if (isLoadingRef.current) {
        return Promise.reject(
          new Error(`Event "${eventName}" is already executing`),
        );
      }

      setIsLoading(true);
      isLoadingRef.current = true;
      const currentToken = ++executionToken.current;

      return new Promise((resolve, reject) => {
        pendingReject.current = reject;

        live.pushEvent(eventName, params, (reply) => {
          if (currentToken === executionToken.current) {
            setData((currentData) =>
              options.updateData
                ? options.updateData(reply, currentData)
                : reply,
            );
            setIsLoading(false);
            isLoadingRef.current = false;
            pendingReject.current = null;
            resolve(reply);
          }
        });
      });
    },
    [eventName, live, options],
  );

  const cancel = useCallback(() => {
    if (pendingReject.current) {
      pendingReject.current(new Error(`Event "${eventName}" was cancelled`));
      pendingReject.current = null;
    }

    executionToken.current += 1;
    setIsLoading(false);
    isLoadingRef.current = false;
  }, [eventName]);

  return { data, isLoading, execute, cancel };
}

export function useLiveConnection() {
  const live = useLiveReact();
  const liveSocket = live.liveSocket;
  if (!liveSocket) throw new Error("LiveSocket not initialized");

  const socket = liveSocket.socket;
  if (!socket) throw new Error("Socket not available");

  const [connectionState, setConnectionState] = useState(
    socket.connectionState(),
  );

  useEffect(() => {
    const openRef = socket.onOpen(() => setConnectionState("open"));
    const closeRef = socket.onClose(() => setConnectionState("closed"));
    const errorRef = socket.onError(() =>
      setConnectionState(socket.connectionState()),
    );

    return () => {
      const refs = [openRef, closeRef, errorRef].filter(Boolean);
      if (refs.length > 0) socket.off(refs);
    };
  }, [socket]);

  return {
    connectionState,
    isConnected: connectionState === "open",
  };
}

export function useLiveUpload(uploadConfig, options = {}) {
  const live = useLiveReact();
  const inputEl = useRef(null);
  const config = resolveValue(uploadConfig) || {};
  const configSignature = JSON.stringify(config);

  useEffect(() => {
    if (inputEl.current || !live.el) return undefined;

    const form = document.createElement("form");
    if (options.changeEvent)
      form.setAttribute("phx-change", options.changeEvent);
    if (options.submitEvent)
      form.setAttribute("phx-submit", options.submitEvent);
    form.style.display = "none";

    const input = document.createElement("input");
    input.type = "file";
    applyUploadConfig(input, config);
    input.setAttribute("data-phx-hook", "Phoenix.LiveFileUpload");
    input.setAttribute("data-phx-update", "ignore");
    form.appendChild(input);
    live.el.appendChild(form);
    inputEl.current = input;

    return () => {
      inputEl.current = null;
      form.remove();
    };
  }, [live.el, options.changeEvent, options.submitEvent]);

  useEffect(() => {
    const input = inputEl.current;
    if (!input) return;

    const previousRef = input.getAttribute("data-phx-upload-ref");
    applyUploadConfig(input, config);

    if (previousRef && previousRef !== config.ref) input.value = "";
  }, [configSignature]);

  const entries = config.entries || [];
  const progress =
    entries.length === 0
      ? 0
      : Math.round(
          entries.reduce((sum, entry) => sum + (entry.progress || 0), 0) /
            entries.length,
        );

  const showFilePicker = useCallback(() => inputEl.current?.click(), []);

  const addFiles = useCallback((input) => {
    if (!inputEl.current) return;

    if (typeof DataTransfer !== "undefined" && input instanceof DataTransfer) {
      inputEl.current.files = input.files;
    } else if (Array.isArray(input)) {
      const dataTransfer = new DataTransfer();
      input.forEach((file) => dataTransfer.items.add(file));
      inputEl.current.files = dataTransfer.files;
    }

    setTimeout(() => {
      inputEl.current?.dispatchEvent(
        new Event("change", { bubbles: true, cancelable: true }),
      );
    }, 0);
  }, []);

  const submit = useCallback(() => {
    inputEl.current?.form?.dispatchEvent(
      new Event("submit", { bubbles: true, cancelable: true }),
    );
  }, []);

  const cancel = useCallback(
    (ref) => {
      if (ref) {
        live.pushEvent("cancel-upload", { ref });
      } else {
        entries.forEach((entry) =>
          live.pushEvent("cancel-upload", { ref: entry.ref }),
        );
      }
    },
    [entries, live],
  );

  const clear = useCallback(() => {
    if (inputEl.current) inputEl.current.value = "";
  }, []);

  return {
    entries,
    showFilePicker,
    addFiles,
    submit,
    cancel,
    clear,
    progress,
    inputEl,
    valid: Object.keys(config.errors || {}).length === 0,
  };
}

export function useLiveForm(form, options = {}) {
  const live = useLiveReact();
  const {
    changeEvent = null,
    submitEvent = "submit",
    debounceInMiliseconds = 300,
    prepareData = (data) => data,
  } = options;

  const initialForm = form || {
    name: "form",
    values: {},
    errors: {},
    valid: true,
  };
  const formSignature = JSON.stringify(initialForm);
  const initialValues = useRef(deepClone(initialForm.values || {}));
  const [values, setValues] = useState(() =>
    deepClone(initialForm.values || {}),
  );
  const [errors, setErrors] = useState(() =>
    deepClone(initialForm.errors || {}),
  );
  const [touchedFields, setTouchedFields] = useState(() => new Set());
  const [submitCount, setSubmitCount] = useState(0);
  const [isValidating, setIsValidating] = useState(false);
  const debounceTimer = useRef(null);
  const pendingResolvers = useRef([]);
  const valuesRef = useRef(values);

  useEffect(() => {
    valuesRef.current = values;
  }, [values]);

  const scheduleChanges = useCallback(
    (nextValues) => {
      if (!changeEvent) return Promise.resolve(null);

      if (debounceTimer.current) clearTimeout(debounceTimer.current);
      setIsValidating(true);

      return new Promise((resolve, reject) => {
        pendingResolvers.current.push({ resolve, reject });

        debounceTimer.current = setTimeout(() => {
          const resolvers = pendingResolvers.current;
          pendingResolvers.current = [];
          debounceTimer.current = null;

          live.pushEvent(
            changeEvent,
            { [initialForm.name]: prepareData(nextValues) },
            (reply) => {
              setIsValidating(false);
              resolvers.forEach(({ resolve }) => resolve(reply));
            },
          );
        }, debounceInMiliseconds);
      });
    },
    [changeEvent, debounceInMiliseconds, initialForm.name, live, prepareData],
  );

  useEffect(() => {
    setErrors(deepClone(initialForm.errors || {}));
    if (!isValidating) setValues(deepClone(initialForm.values || {}));
  }, [formSignature]);

  useEffect(
    () => () => {
      if (debounceTimer.current) clearTimeout(debounceTimer.current);
      pendingResolvers.current.forEach(({ reject }) =>
        reject(new Error("Form unmounted")),
      );
    },
    [],
  );

  const updateValue = useCallback(
    (path, nextValue) => {
      setValues((previous) => {
        const next = deepClone(previous);
        setValueByPath(next, parsePath(path), nextValue);
        scheduleChanges(next);
        return next;
      });
    },
    [scheduleChanges],
  );

  const markTouched = useCallback((path) => {
    setTouchedFields((previous) => new Set(previous).add(path));
  }, []);

  const createField = useCallback(
    (path, fieldOptions = {}) => {
      const keys = parsePath(path);
      const value = getValueByPath(values, keys);
      const fieldErrors = normalizeErrors(getValueByPath(errors, keys));
      const fieldId =
        sanitizeId(path) +
        (fieldOptions.value !== undefined
          ? `_${sanitizeId(String(fieldOptions.value))}`
          : "");
      const isMultiCheckboxValue =
        fieldOptions.type === "checkbox" && Array.isArray(value);

      const setFieldValue = (nextValue) => updateValue(path, nextValue);
      const blur = () => markTouched(path);

      let inputAttrs;
      if (isMultiCheckboxValue) {
        inputAttrs = {
          name: path,
          id: fieldId,
          type: fieldOptions.type,
          value: fieldOptions.value,
          checked: (value || []).includes(fieldOptions.value),
          "aria-invalid": fieldErrors.length > 0,
          "aria-describedby":
            fieldErrors.length > 0 ? `${fieldId}-error` : undefined,
          onBlur: blur,
          onChange: (event) => {
            const currentArray = Array.isArray(value) ? [...value] : [];
            const index = currentArray.indexOf(fieldOptions.value);
            if (event.target.checked && index === -1)
              currentArray.push(fieldOptions.value);
            if (!event.target.checked && index !== -1)
              currentArray.splice(index, 1);
            setFieldValue(currentArray);
          },
        };
      } else if (fieldOptions.type === "checkbox") {
        const checkedValue =
          fieldOptions.value !== undefined ? fieldOptions.value : true;
        inputAttrs = {
          name: path,
          id: fieldId,
          type: fieldOptions.type,
          value: fieldOptions.value,
          checked: value === checkedValue,
          "aria-invalid": fieldErrors.length > 0,
          "aria-describedby":
            fieldErrors.length > 0 ? `${fieldId}-error` : undefined,
          onBlur: blur,
          onChange: (event) =>
            setFieldValue(event.target.checked ? checkedValue : null),
        };
      } else {
        inputAttrs = {
          name: path,
          id: fieldId,
          type: fieldOptions.type,
          value: value ?? "",
          "aria-invalid": fieldErrors.length > 0,
          "aria-describedby":
            fieldErrors.length > 0 ? `${fieldId}-error` : undefined,
          onBlur: blur,
          onChange: (event) => setFieldValue(event.target.value),
        };
      }

      return {
        value,
        setValue: setFieldValue,
        errors: fieldErrors,
        errorMessage: fieldErrors[0],
        isValid: fieldErrors.length === 0,
        isDirty: !deepEqual(value, getValueByPath(initialValues.current, keys)),
        isTouched: submitCount > 0 || touchedFields.has(path),
        inputAttrs,
        field: (key, options) =>
          createField(path ? `${path}.${String(key)}` : String(key), options),
        fieldArray: (key) =>
          createFieldArray(path ? `${path}.${String(key)}` : String(key)),
        blur,
      };
    },
    [errors, markTouched, submitCount, touchedFields, updateValue, values],
  );

  const createFieldArray = useCallback(
    (path) => {
      const baseField = createField(path);
      const arrayValue = Array.isArray(baseField.value) ? baseField.value : [];

      const setArray = (nextArray) => updateValue(path, nextArray);

      return {
        ...baseField,
        add: (item = {}) => setArray([...arrayValue, item]),
        remove: (index) =>
          setArray(
            arrayValue.filter((_item, itemIndex) => itemIndex !== index),
          ),
        move: (from, to) => {
          if (
            from < 0 ||
            from >= arrayValue.length ||
            to < 0 ||
            to >= arrayValue.length
          )
            return;
          const next = [...arrayValue];
          const [item] = next.splice(from, 1);
          next.splice(to, 0, item);
          setArray(next);
        },
        fields: arrayValue.map((_item, index) =>
          createField(`${path}[${index}]`),
        ),
        field: (pathOrIndex, options) =>
          createField(
            typeof pathOrIndex === "number"
              ? `${path}[${pathOrIndex}]`
              : `${path}${pathOrIndex}`,
            options,
          ),
        fieldArray: (pathOrIndex) =>
          createFieldArray(
            typeof pathOrIndex === "number"
              ? `${path}[${pathOrIndex}]`
              : `${path}${pathOrIndex}`,
          ),
      };
    },
    [createField, updateValue],
  );

  const reset = useCallback(() => {
    setValues(deepClone(initialValues.current));
    setTouchedFields(new Set());
    setSubmitCount(0);
  }, []);

  const submit = useCallback(() => {
    setSubmitCount((count) => count + 1);
    const data = prepareData(deepClone(valuesRef.current));

    return new Promise((resolve) => {
      live.pushEvent(submitEvent, { [initialForm.name]: data }, (reply) => {
        if (reply && reply.reset) {
          initialValues.current = deepClone(valuesRef.current);
          reset();
        }
        resolve(reply);
      });
    });
  }, [initialForm.name, live, prepareData, reset, submitEvent]);

  const formApi = useMemo(
    () => ({
      isValid: !hasAnyErrors(errors),
      isDirty: !deepEqual(values, initialValues.current),
      isTouched: submitCount > 0 || touchedFields.size > 0,
      isValidating,
      submitCount,
      initialValues: initialValues.current,
      values,
      errors,
      field: createField,
      fieldArray: createFieldArray,
      submit,
      reset,
    }),
    [
      createField,
      createFieldArray,
      errors,
      isValidating,
      reset,
      submit,
      submitCount,
      touchedFields,
      values,
    ],
  );

  return formApi;
}

export function LiveFormProvider({ form, children }) {
  return (
    <LiveFormContext.Provider value={form}>{children}</LiveFormContext.Provider>
  );
}

export function useField(path, options) {
  const form = useContext(LiveFormContext);
  if (!form)
    throw new Error("useField() requires a LiveFormProvider ancestor.");
  return form.field(path, options);
}

export function useArrayField(path) {
  const form = useContext(LiveFormContext);
  if (!form)
    throw new Error("useArrayField() requires a LiveFormProvider ancestor.");
  return form.fieldArray(path);
}

function applyUploadConfig(input, config) {
  const entries = config.entries || [];
  const joinEntries = (items) => items.map((entry) => entry.ref).join(",");

  input.id = config.ref || "";
  input.name = config.name || "";
  input.setAttribute("data-phx-upload-ref", config.ref || "");

  if (config.accept && typeof config.accept === "string") {
    input.accept = config.accept;
  } else {
    input.removeAttribute("accept");
  }

  if (config.auto_upload) {
    input.setAttribute("data-phx-auto-upload", "true");
  } else {
    input.removeAttribute("data-phx-auto-upload");
  }

  input.multiple = (config.max_entries || 1) > 1;
  input.setAttribute("data-phx-active-refs", joinEntries(entries));
  input.setAttribute(
    "data-phx-done-refs",
    joinEntries(entries.filter((entry) => entry.done)),
  );
  input.setAttribute(
    "data-phx-preflighted-refs",
    joinEntries(entries.filter((entry) => entry.preflighted)),
  );
}

function resolveValue(value) {
  return typeof value === "function" ? value() : value;
}

function deepClone(value) {
  if (value === undefined) return undefined;
  if (typeof structuredClone === "function") {
    try {
      return structuredClone(value);
    } catch (_error) {
      return JSON.parse(JSON.stringify(value));
    }
  }
  return JSON.parse(JSON.stringify(value));
}

function deepEqual(first, second) {
  return JSON.stringify(first) === JSON.stringify(second);
}

function parsePath(path) {
  if (!path) return [];

  const keys = [];
  let current = "";
  let i = 0;

  while (i < path.length) {
    const char = path[i];

    if (char === ".") {
      if (current) {
        keys.push(current);
        current = "";
      }
    } else if (char === "[") {
      if (current) {
        keys.push(current);
        current = "";
      }

      i += 1;
      let bracketContent = "";
      while (i < path.length && path[i] !== "]") {
        bracketContent += path[i];
        i += 1;
      }

      const index = parseInt(bracketContent, 10);
      keys.push(Number.isNaN(index) ? bracketContent : index);
    } else {
      current += char;
    }

    i += 1;
  }

  if (current) keys.push(current);
  return keys;
}

function getValueByPath(obj, keys) {
  return keys.reduce(
    (current, key) => (current == null ? undefined : current[key]),
    obj,
  );
}

function setValueByPath(obj, keys, value) {
  if (keys.length === 0) return value;

  let current = obj;
  for (let index = 0; index < keys.length - 1; index++) {
    const key = keys[index];
    const nextKey = keys[index + 1];
    if (current[key] == null)
      current[key] = typeof nextKey === "number" ? [] : {};
    current = current[key];
  }

  current[keys[keys.length - 1]] = value;
  return obj;
}

function normalizeErrors(errors) {
  return Array.isArray(errors) ? errors : [];
}

function hasAnyErrors(errors) {
  if (Array.isArray(errors)) {
    if (errors.length === 0) return false;
    if (typeof errors[0] === "string") return true;
    return errors.some((item) => hasAnyErrors(item));
  }

  if (errors && typeof errors === "object") {
    return Object.values(errors).some((value) => hasAnyErrors(value));
  }

  return false;
}

function sanitizeId(path) {
  return path.replace(/[^a-zA-Z0-9_-]/g, "_");
}
