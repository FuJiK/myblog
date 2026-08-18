<template>
  <aside
    v-if="enabled && links.length"
    class="mt-8 pt-6 border-t border-gray-300 text-sm text-gray-600"
  >
    <p class="mb-3">{{ disclosure }}</p>
    <ul class="space-y-2">
      <li v-for="(link, index) in links" :key="index">
        <a
          :href="link.url"
          class="text-blue-600 hover:underline"
          target="_blank"
          rel="noopener noreferrer sponsored"
        >
          {{ link.label }}
        </a>
      </li>
    </ul>
  </aside>
</template>

<script>
import affiliateConfig from '~/content/affiliate-links.json'

export default {
  data() {
    return {
      enabled: affiliateConfig.enabled,
      disclosure: affiliateConfig.disclosure,
      links: affiliateConfig.links || []
    }
  }
}
</script>
