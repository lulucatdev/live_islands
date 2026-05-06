import React from "react";

export interface LiveProps {
  pushEvent: (
    event: string,
    payload?: Record<string, any>,
    onReply?: (reply: Record<string, any>) => void,
  ) => Promise<any> | void;
  pushEventTo: (
    phxTarget: string | HTMLElement,
    event: string,
    payload?: Record<string, any>,
    onReply?: (reply: Record<string, any>) => void,
  ) => Promise<any> | void;
  handleEvent: (
    event: string,
    callback: (payload: Record<string, any>) => void,
  ) => string;
  removeHandleEvent: (callbackRef: string) => void;
  upload: (name: string, files: FileList | File[]) => void;
  uploadTo: (target: string, name: string, files: FileList | File[]) => void;
  liveSocket?: any;
  el?: HTMLElement;
}

export interface LinkProps
  extends React.AnchorHTMLAttributes<HTMLAnchorElement> {
  /** Uses browser navigation to the new location. The page is reloaded. */
  href?: string | null;
  /** Patches the current LiveView. */
  patch?: string | null;
  /** Navigates to a LiveView in the same live_session. */
  navigate?: string | null;
  /** Replaces the browser history entry instead of pushing one. */
  replace?: boolean;
  children?: React.ReactNode;
}

export interface UploadEntry {
  ref: string;
  client_name?: string;
  client_size?: number;
  client_type?: string;
  progress?: number;
  done?: boolean;
  valid?: boolean;
  preflighted?: boolean;
  errors?: any[];
}

export interface UploadConfig {
  ref: string;
  name: string;
  accept?: string;
  max_entries: number;
  auto_upload?: boolean;
  entries: UploadEntry[];
  errors: any[] | Record<string, any>;
}

export interface UseLiveUploadReturn {
  entries: UploadEntry[];
  showFilePicker: () => void;
  addFiles: (files: (File | Blob)[] | DataTransfer) => void;
  submit: () => void;
  cancel: (ref?: string) => void;
  clear: () => void;
  progress: number;
  inputEl: React.MutableRefObject<HTMLInputElement | null>;
  valid: boolean;
}

export interface Form<T extends object> {
  name: string;
  values: T;
  errors: any;
  valid: boolean;
}

export interface FieldOptions {
  type?: string;
  value?: any;
}

export interface FormOptions {
  changeEvent?: string | null;
  submitEvent?: string;
  debounceInMiliseconds?: number;
  prepareData?: (data: any) => any;
}

export interface FormField<T = any> {
  value: T;
  setValue: (value: T) => void;
  errors: string[];
  errorMessage?: string;
  isValid: boolean;
  isDirty: boolean;
  isTouched: boolean;
  inputAttrs: Record<string, any>;
  field: (path: string, options?: FieldOptions) => FormField;
  fieldArray: (path: string) => FormFieldArray;
  blur: () => void;
}

export interface FormFieldArray<T = any> extends FormField<T[]> {
  add: (item?: Partial<T>) => void;
  remove: (index: number) => void;
  move: (from: number, to: number) => void;
  fields: FormField<T>[];
}

export interface UseLiveFormReturn<T extends object> {
  isValid: boolean;
  isDirty: boolean;
  isTouched: boolean;
  isValidating: boolean;
  submitCount: number;
  initialValues: T;
  values: T;
  errors: any;
  field: (path: string, options?: FieldOptions) => FormField;
  fieldArray: (path: string) => FormFieldArray;
  submit: () => Promise<any>;
  reset: () => void;
}

export function useLiveReact(): LiveProps;
export function useLiveEvent<T = any>(
  event: string,
  callback: (data: T) => void,
): void;
export function useLiveNavigation(): {
  patch: (
    hrefOrQueryParams: string | Record<string, string>,
    opts?: { replace?: boolean },
  ) => void;
  navigate: (href: string, opts?: { replace?: boolean }) => void;
};
export function useEventReply<
  T = any,
  P extends Record<string, any> | void = Record<string, any>,
>(
  eventName: string,
  options?: {
    defaultValue?: T;
    updateData?: (reply: T, currentData: T | null) => T;
  },
): {
  data: T | null;
  isLoading: boolean;
  execute: (params?: P) => Promise<T>;
  cancel: () => void;
};
export function useLiveConnection(): {
  connectionState: string;
  isConnected: boolean;
};
export function useLiveUpload(
  config: UploadConfig | (() => UploadConfig),
  options: {
    changeEvent?: string;
    submitEvent: string;
  },
): UseLiveUploadReturn;
export function useLiveForm<T extends object>(
  form: Form<T>,
  options?: FormOptions,
): UseLiveFormReturn<T>;
export function LiveFormProvider(props: {
  form: UseLiveFormReturn<any>;
  children?: React.ReactNode;
}): React.ReactElement;
export function useField<T = any>(
  path: string,
  options?: FieldOptions,
): FormField<T>;
export function useArrayField<T = any>(path: string): FormFieldArray<T>;
export function Link(props: LinkProps): React.ReactElement;
