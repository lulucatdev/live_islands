import React, { useState } from "react";
import { useEventReply, useLiveForm, useLiveUpload } from "live_react";

export function Capabilities({
  entries = [],
  profile,
  documentUpload,
  uploadedFiles = [],
  pushEvent,
}) {
  const [selectedName, setSelectedName] = useState("");
  const reply = useEventReply("lookup", {
    defaultValue: { message: "No reply yet" },
  });
  const form = useLiveForm(profile, {
    changeEvent: "profile-validate",
    submitEvent: "profile-save",
    debounceInMiliseconds: 100,
  });
  const email = form.field("email", { type: "email" });
  const liveUpload = useLiveUpload(documentUpload, {
    changeEvent: "validate-upload",
    submitEvent: "save-upload",
  });

  const selectFile = (event) => {
    const files = Array.from(event.target.files || []);
    if (files.length === 0) return;
    setSelectedName(files[0].name);
    liveUpload.addFiles(files);
  };

  return (
    <div className="grid gap-6 max-w-3xl">
      <section className="border rounded-md p-4 space-y-3">
        <div className="flex items-center justify-between gap-4">
          <h2 className="font-semibold">Phoenix streams</h2>
          <button
            type="button"
            data-testid="stream-add"
            className="bg-black text-white rounded px-3 py-1"
            onClick={() => pushEvent("add-stream")}
          >
            Add row
          </button>
        </div>
        <ul data-testid="stream-list" className="divide-y">
          {entries.map((entry) => (
            <li key={entry.__dom_id || entry.id} className="py-2">
              {entry.body}
            </li>
          ))}
        </ul>
      </section>

      <section className="border rounded-md p-4 space-y-3">
        <h2 className="font-semibold">Event reply</h2>
        <button
          type="button"
          data-testid="reply-button"
          className="bg-black text-white rounded px-3 py-1"
          onClick={() => reply.execute({ query: "react" })}
        >
          Request reply
        </button>
        <p data-testid="reply-result">{reply.data?.message}</p>
      </section>

      <section className="border rounded-md p-4 space-y-3">
        <h2 className="font-semibold">Live form</h2>
        <form
          className="space-y-2"
          onSubmit={(event) => {
            event.preventDefault();
            form.submit();
          }}
        >
          <label className="grid gap-1">
            <span>Email</span>
            <input
              data-testid="email-input"
              className="border rounded px-2 py-1"
              {...email.inputAttrs}
            />
          </label>
          <p data-testid="email-error" className="text-red-700 min-h-6">
            {email.errorMessage || ""}
          </p>
          <button
            type="submit"
            data-testid="form-submit"
            className="bg-black text-white rounded px-3 py-1"
          >
            Save form
          </button>
          <p data-testid="form-state">
            {form.isDirty ? "dirty" : "clean"} /{" "}
            {form.isValid ? "valid" : "invalid"}
          </p>
        </form>
      </section>

      <section className="border rounded-md p-4 space-y-3">
        <h2 className="font-semibold">Live upload</h2>
        <input
          data-testid="upload-input"
          type="file"
          accept=".txt"
          onChange={selectFile}
        />
        <div className="flex items-center gap-3">
          <button
            type="button"
            data-testid="upload-submit"
            className="bg-black text-white rounded px-3 py-1"
            onClick={liveUpload.submit}
          >
            Submit upload
          </button>
          <span data-testid="upload-progress">{liveUpload.progress}</span>
        </div>
        <p data-testid="selected-file">{selectedName}</p>
        <ul data-testid="uploaded-files" className="divide-y">
          {uploadedFiles.map((file) => (
            <li key={`${file.name}-${file.size}`} className="py-2">
              {file.name} ({file.size} bytes)
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}
