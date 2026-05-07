<script setup>
const props = defineProps({
  signals: {
    type: Array,
    default: () => [],
  },
  active: {
    type: String,
    default: "edge",
  },
  metrics: {
    type: Object,
    default: () => ({}),
  },
  revision: {
    type: Number,
    default: 1,
  },
  onSelect: {
    type: Function,
    default: null,
  },
});

const selectSignal = (signal) => {
  props.onSelect?.({ signal: signal.id });
};
</script>

<template>
  <section
    data-testid="showcase-vue-board"
    class="showcase-card rounded-md border border-zinc-200 bg-white p-5 shadow-sm"
  >
    <div class="flex flex-wrap items-start justify-between gap-4">
      <div>
        <p class="text-sm font-semibold uppercase text-emerald-700">
          Vue island
        </p>
        <h3 class="mt-1 text-2xl font-bold text-zinc-950">Signal board</h3>
      </div>
      <span
        data-testid="showcase-vue-revision"
        class="rounded-md bg-emerald-50 px-3 py-1 text-sm font-semibold text-emerald-700"
      >
        rev {{ revision }}
      </span>
    </div>

    <div class="mt-5 grid grid-cols-4 gap-2">
      <div
        v-for="(value, name) in metrics"
        :key="name"
        class="rounded-md border border-zinc-100 p-3"
      >
        <div class="text-xl font-bold text-zinc-950">{{ value }}</div>
        <div class="text-xs font-semibold uppercase text-zinc-500">
          {{ name }}
        </div>
      </div>
    </div>

    <div class="mt-5 grid gap-2">
      <button
        v-for="signal in signals"
        :key="signal.id"
        type="button"
        :data-testid="`showcase-vue-signal-${signal.id}`"
        class="rounded-md border p-3 text-left transition"
        :class="
          active === signal.id
            ? 'border-emerald-200 bg-emerald-50 text-emerald-800'
            : 'border-zinc-200 bg-white text-zinc-700 hover:border-zinc-300'
        "
        @click="selectSignal(signal)"
      >
        <div class="flex items-center justify-between gap-3">
          <span class="font-semibold">{{ signal.label }}</span>
          <span class="text-sm">{{ signal.score }}</span>
        </div>
      </button>
    </div>

    <div class="mt-5 rounded-md bg-emerald-950 p-4 text-white">
      <div class="text-sm font-semibold uppercase text-emerald-200">
        Vue status
      </div>
      <p data-testid="showcase-vue-active" class="mt-2 text-sm text-emerald-50">
        Active signal: {{ active }}
      </p>
    </div>
  </section>
</template>
