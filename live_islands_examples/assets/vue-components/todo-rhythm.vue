<script setup>
const props = defineProps({
  stats: {
    type: Object,
    default: () => ({}),
  },
  mode: {
    type: String,
    default: "Launch",
  },
  readonly: {
    type: Boolean,
    default: false,
  },
  onMode: {
    type: Function,
    default: null,
  },
});

const modes = [
  {
    id: "Launch",
    testid: "launch",
    label: "Launch",
    detail: "Ship visible work",
  },
  { id: "Plan", testid: "plan", label: "Plan", detail: "Reduce ambiguity" },
  {
    id: "Deep Work",
    testid: "deep-work",
    label: "Deep Work",
    detail: "Protect focus blocks",
  },
];

const chooseMode = (mode) => {
  if (props.readonly || !props.onMode) return;
  props.onMode({ mode });
};
</script>

<template>
  <section
    data-testid="todo-rhythm"
    class="todo-card border border-zinc-200 bg-white p-5 shadow-sm"
  >
    <div class="flex items-start justify-between gap-3">
      <div>
        <p class="text-sm font-semibold uppercase tracking-wide text-zinc-500">
          Vue island
        </p>
        <h3 class="mt-1 text-xl font-bold text-zinc-950">Team rhythm</h3>
      </div>
      <span
        class="todo-rhythm-pulse rounded-full bg-emerald-50 px-3 py-1 text-sm font-semibold text-emerald-700"
      >
        {{ mode }}
      </span>
    </div>

    <div class="mt-5 grid grid-cols-3 gap-2">
      <div class="rounded-md border border-zinc-100 bg-zinc-50 p-3">
        <div class="text-xl font-bold text-zinc-950">{{ stats.open || 0 }}</div>
        <div class="text-xs uppercase text-zinc-500">Open</div>
      </div>
      <div class="rounded-md border border-zinc-100 bg-zinc-50 p-3">
        <div class="text-xl font-bold text-zinc-950">{{ stats.done || 0 }}</div>
        <div class="text-xs uppercase text-zinc-500">Done</div>
      </div>
      <div class="rounded-md border border-zinc-100 bg-zinc-50 p-3">
        <div class="text-xl font-bold text-zinc-950">
          {{ stats.focus || 0 }}%
        </div>
        <div class="text-xs uppercase text-zinc-500">Focus</div>
      </div>
    </div>

    <div class="mt-5 grid gap-2">
      <button
        v-for="item in modes"
        :key="item.id"
        type="button"
        :disabled="readonly"
        :data-testid="`todo-mode-${item.testid}`"
        class="group rounded-md border p-3 text-left transition"
        :class="
          mode === item.id
            ? 'border-zinc-950 bg-zinc-950 text-white'
            : 'border-zinc-200 bg-white text-zinc-700 hover:border-zinc-300 hover:bg-zinc-50'
        "
        @click="chooseMode(item.id)"
      >
        <div class="font-semibold">{{ item.label }}</div>
        <div
          class="mt-1 text-sm"
          :class="mode === item.id ? 'text-zinc-300' : 'text-zinc-500'"
        >
          {{ item.detail }}
        </div>
      </button>
    </div>

    <p class="mt-4 text-sm leading-6 text-zinc-600">
      <span v-if="readonly">
        Server-rendered Vue proof with no client hydration.
      </span>
      <span v-else>
        Hydrates on visibility and pushes mode changes back into LiveView.
      </span>
    </p>
  </section>
</template>
