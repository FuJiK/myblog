<template>
  <article
    class="flex lg:h-screen w-screen lg:overflow-hidden xs:flex-col lg:flex-row"
  >
    <div class="relative lg:w-1/2 xs:w-full xs:h-84 lg:h-full post-left">
      <img
        :src="article.img"
        :alt="article.alt"
        class="absolute h-full w-full object-cover"
      />
      <div class="overlay"></div>
      <div class="absolute top-32 left-32 text-white">
        <NuxtLink to="/"><Logo /></NuxtLink>
        <!-- <NuxtLink to="/myblog/"><Logo /></NuxtLink> -->
        <div class="mt-16 -mb-3 flex uppercase text-sm">
          <p class="mr-3">
            {{ formatDate(article.updatedAt) }}
          </p>
          <span class="mr-3">•</span>
          <p>{{ article.author.name }}</p>
        </div>
        <p class="text-6xl font-bold" aria-hidden="true">
          {{ article.title }}
        </p>
        <span v-for="(tag, id) in article.tags" :key="id">
          <NuxtLink :to="`/blog/tag/${tags[tag].slug}`">
            <span
              class="truncate uppercase tracking-wider font-medium text-ss px-2 py-1 rounded-full mr-2 mb-2 border border-light-border dark:border-dark-border transition-colors duration-300 ease-linear"
            >
              {{ tags[tag].name }}
            </span>
          </NuxtLink>
        </span>
      </div>
      <div class="flex absolute top-3rem right-3rem">
        <NuxtLink
          to="/"
          class="mr-8 self-center text-white font-bold hover:underline"
        >
          All articles
        </NuxtLink>
        <!-- <a
          href="https://nuxtjs.org/blog/creating-blog-with-nuxt-content"
          class="mr-8 self-center text-white font-bold hover:underline"
        >
          Tutorial
        </a> -->
        <AppSearchInput />
      </div>
    </div>
    <div
      class="relative xs:py-8 xs:px-8 lg:py-32 lg:px-16 lg:w-1/2 xs:w-full h-full overflow-y-scroll markdown-body post-right custom-scroll"
    >
      <h1 class="font-bold text-4xl">{{ article.title }}</h1>
      <p>{{ article.description }}</p>
      <p class="pb-4">Post last updated: {{ formatDate(article.updatedAt) }}</p>
      <!-- table of contents -->
      <nav class="pb-6">
        <ul>
          <li
            v-for="link of article.toc"
            :key="link.id"
            :class="{
              'font-semibold': link.depth === 2
            }"
          >
            <nuxtLink
              :to="`#${link.id}`"
              class="hover:underline"
              :class="{
                'py-2': link.depth === 2,
                'ml-2 pb-2': link.depth === 3
              }"
              >{{ link.text }}</nuxtLink
            >
          </li>
        </ul>
      </nav>
      <!-- content from markdown -->
      <nuxt-content :document="article" />
      <AffiliateLinks />
      <!-- content author component -->
      <author :author="article.author" />
      <!-- prevNext component -->
      <PrevNext :prev="prev" :next="next" class="mt-8" />
    </div>
  </article>
</template>
<script>
const SITE_NAME = 'The Shibsters'
const SITE_URL = 'https://www.theshibsters.com'

function toAbsoluteUrl(value) {
  if (!value) {
    return SITE_URL
  }

  return new URL(value, SITE_URL).href
}

export default {
  async asyncData({ $content, params }) {
    const article = await $content('articles', params.slug).fetch()
    const tagsList = await $content('tags')
      .only(['name', 'slug'])
      .where({ name: { $containsAny: article.tags } })
      .fetch()
    const tags = Object.assign({}, ...tagsList.map((s) => ({ [s.name]: s })))
    const [prev, next] = await $content('articles')
      .only(['title', 'slug'])
      .sortBy('createdAt', 'asc')
      .surround(params.slug)
      .fetch()
    return {
      article,
      tags,
      prev,
      next
    }
  },
  head() {
    const article = this.article
    const canonicalUrl = toAbsoluteUrl(this.$route.path)
    const imageUrl = toAbsoluteUrl(article.img)
    const author = article.author || {}
    const tags = article.tags || []
    const publishedTime = article.createdAt
    const modifiedTime = article.updatedAt
    const meta = [
      {
        hid: 'description',
        name: 'description',
        content: article.description
      },
      { hid: 'robots', name: 'robots', content: 'index,follow' },
      { hid: 'og:type', property: 'og:type', content: 'article' },
      { hid: 'og:title', property: 'og:title', content: article.title },
      {
        hid: 'og:description',
        property: 'og:description',
        content: article.description
      },
      { hid: 'og:url', property: 'og:url', content: canonicalUrl },
      { hid: 'og:image', property: 'og:image', content: imageUrl },
      {
        hid: 'og:image:alt',
        property: 'og:image:alt',
        content: article.alt || article.title
      },
      {
        hid: 'og:site_name',
        property: 'og:site_name',
        content: SITE_NAME
      },
      { hid: 'og:locale', property: 'og:locale', content: 'ja_JP' },
      {
        hid: 'twitter:card',
        name: 'twitter:card',
        content: 'summary_large_image'
      },
      {
        hid: 'twitter:title',
        name: 'twitter:title',
        content: article.title
      },
      {
        hid: 'twitter:description',
        name: 'twitter:description',
        content: article.description
      },
      {
        hid: 'twitter:image',
        name: 'twitter:image',
        content: imageUrl
      },
      {
        hid: 'twitter:image:alt',
        name: 'twitter:image:alt',
        content: article.alt || article.title
      }
    ]

    if (publishedTime) {
      meta.push({
        hid: 'article:published_time',
        property: 'article:published_time',
        content: publishedTime
      })
    }

    if (modifiedTime) {
      meta.push({
        hid: 'article:modified_time',
        property: 'article:modified_time',
        content: modifiedTime
      })
    }

    tags.forEach((tag, index) => {
      meta.push({
        hid: `article:tag:${index}`,
        property: 'article:tag',
        content: tag
      })
    })

    const structuredData = {
      '@context': 'https://schema.org',
      '@type': 'TechArticle',
      headline: article.title,
      description: article.description,
      image: [imageUrl],
      datePublished: publishedTime,
      dateModified: modifiedTime,
      inLanguage: 'ja-JP',
      mainEntityOfPage: {
        '@type': 'WebPage',
        '@id': canonicalUrl
      },
      author: {
        '@type': 'Person',
        name: author.name || 'Fujikeeeen'
      },
      publisher: {
        '@type': 'Person',
        name: author.name || 'Fujikeeeen'
      },
      keywords: tags.join(', ')
    }

    return {
      title: article.title,
      link: [{ hid: 'canonical', rel: 'canonical', href: canonicalUrl }],
      meta,
      script: [
        {
          hid: 'article-structured-data',
          type: 'application/ld+json',
          json: structuredData
        }
      ]
    }
  },
  methods: {
    formatDate(date) {
      const options = { year: 'numeric', month: 'long', day: 'numeric' }
      return new Date(date).toLocaleDateString('en', options)
    }
  }
}
</script>
<style>
.nuxt-content p {
  margin-bottom: 20px;
}
.nuxt-content h2 {
  font-weight: bold;
  font-size: 28px;
}
.nuxt-content h3 {
  font-weight: bold;
  font-size: 22px;
}
.icon.icon-link {
  background-image: url('~assets/svg/icon-hashtag.svg');
  display: inline-block;
  width: 20px;
  height: 20px;
  background-size: 20px 20px;
}
</style>
