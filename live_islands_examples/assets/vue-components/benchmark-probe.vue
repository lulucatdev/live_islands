<template>
  <section
    data-testid="benchmark-vue-probe"
    class="rounded-md border border-zinc-200 bg-white p-5 shadow-sm"
  >
    <div class="flex flex-wrap items-start justify-between gap-4">
      <div>
        <h2 class="text-xl font-semibold">Vue benchmark probe</h2>
        <p class="text-sm text-zinc-600">{{ message }}</p>
      </div>
      <span
        class="rounded bg-sky-50 px-2 py-1 text-sm font-medium text-sky-700"
      >
        Vue island
      </span>
    </div>

    <div class="mt-5 grid gap-2 sm:grid-cols-3 lg:grid-cols-6">
      <div
        v-for="sample in samples"
        :key="sample.id"
        class="rounded border border-zinc-100 p-3"
      >
        <div class="text-xs uppercase text-zinc-500">{{ sample.label }}</div>
        <div class="mt-1 text-xl font-semibold">{{ sample.value }}</div>
      </div>
    </div>
  </section>
</template>

<script setup>
defineProps({
  message: {
    type: String,
    required: true,
  },
  samples: {
    type: Array,
    default: () => [],
  },
});
</script>
