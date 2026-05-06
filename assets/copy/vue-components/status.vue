<script setup>
defineProps({
  message: {
    type: String,
    default: "Vue island ready",
  },
});
</script>

<template>
  <section>
    <h2>Vue island</h2>
    <p>{{ message }}</p>
  </section>
</template>
