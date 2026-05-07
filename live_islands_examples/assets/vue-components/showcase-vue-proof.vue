<script setup>
defineProps({
  testid: {
    type: String,
    default: "showcase-vue-proof",
  },
  framework: {
    type: String,
    default: "Vue",
  },
  mode: {
    type: String,
    default: "server-only",
  },
  title: {
    type: String,
    default: "Server proof",
  },
  body: {
    type: String,
    default: "Rendered by SSR.",
  },
  metrics: {
    type: Array,
    default: () => [],
  },
});
</script>

<template>
  <section
    :data-testid="testid"
    class="showcase-card rounded-md border border-zinc-200 bg-white p-5 shadow-sm"
  >
    <div class="flex items-start justify-between gap-3">
      <div>
        <p class="text-sm font-semibold uppercase text-emerald-700">
          {{ framework }}
        </p>
        <h3 class="mt-1 text-lg font-bold text-zinc-950">{{ title }}</h3>
      </div>
      <span
        class="rounded-md bg-emerald-50 px-2 py-1 text-xs font-semibold text-emerald-700"
      >
        {{ mode }}
      </span>
    </div>
    <p class="mt-3 text-sm leading-6 text-zinc-600">{{ body }}</p>
    <div class="mt-5 grid grid-cols-3 gap-2">
      <div
        v-for="metric in metrics"
        :key="metric.label"
        class="rounded-md bg-zinc-50 p-3"
      >
        <div class="text-xs font-semibold uppercase text-zinc-500">
          {{ metric.label }}
        </div>
        <div class="mt-1 text-sm font-bold text-zinc-950">
          {{ metric.value }}
        </div>
      </div>
    </div>
  </section>
</template>
