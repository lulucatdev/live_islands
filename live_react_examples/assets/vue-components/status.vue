<script setup>
defineProps({
  message: {
    type: String,
    required: true,
  },
  onPing: {
    type: Function,
    required: true,
  },
});
</script>

<template>
  <section data-testid="vue-island" class="border rounded-md p-4 space-y-3">
    <h2 class="font-semibold">Vue island</h2>
    <p data-testid="vue-message">{{ message }}</p>
    <button
      type="button"
      data-testid="vue-ping"
      class="bg-emerald-700 text-white rounded px-3 py-1"
      @click="onPing({ source: 'vue' })"
    >
      Ping Vue
    </button>
  </section>
</template>
