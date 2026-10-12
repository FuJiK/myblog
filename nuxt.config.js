import analyticsConfig from './analytics.config.json'

const siteName = 'The Shibsters'
const siteDescription =
  'Platform Engineering、SRE、IaC、Clojure、MCPの実装と検証を記録する技術ブログ'
const contentSecurityPolicy = [
  "default-src 'self'",
  "base-uri 'self'",
  "object-src 'none'",
  "script-src 'self' 'unsafe-inline' https://www.googletagmanager.com",
  "style-src 'self' 'unsafe-inline'",
  "img-src 'self' data: https:",
  "font-src 'self' data:",
  "connect-src 'self' https://www.google-analytics.com https://region1.google-analytics.com https://www.googletagmanager.com",
  "form-action 'self'",
  'upgrade-insecure-requests'
].join('; ')

export default {
  env: {
    GOOGLE_ANALYTICS_ID:
      process.env.GOOGLE_ANALYTICS_ID || analyticsConfig.id || ''
  },
  /*
   ** Nuxt target
   ** See https://nuxtjs.org/api/configuration-target
   */
  target: 'static',
  /*
   ** Headers of the page
   ** See https://nuxtjs.org/api/configuration-head
   */
  router: {
    //  Github pages にデプロイ時にはコメントする
    // base: '/myblog/'
  },
  head: {
    htmlAttrs: {
      lang: 'ja'
    },
    title: siteName,
    meta: [
      { charset: 'utf-8' },
      { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      {
        hid: 'csp',
        'http-equiv': 'Content-Security-Policy',
        content: contentSecurityPolicy
      },
      {
        hid: 'referrer',
        name: 'referrer',
        content: 'strict-origin-when-cross-origin'
      },
      {
        hid: 'description',
        name: 'description',
        content: siteDescription
      },
      {
        hid: 'og:site_name',
        property: 'og:site_name',
        content: siteName
      },
      {
        hid: 'og:locale',
        property: 'og:locale',
        content: 'ja_JP'
      }
    ],
    link: [{ rel: 'icon', type: 'image/x-icon', href: '/favicon.ico' }]
  },
  /*
   ** Global CSS
   */
  css: [],
  /*
   ** Plugins to load before mounting the App
   ** https://nuxtjs.org/guide/plugins
   */
  plugins: [{ src: '~/plugins/gtag.client.js', mode: 'client' }],
  /*
   ** Auto import components
   ** https://nuxtjs.org/api/configuration-components
   */
  components: true,
  /*
   ** Nuxt.js dev-modules
   */
  buildModules: [
    // Doc: https://github.com/nuxt-community/eslint-module
    '@nuxtjs/eslint-module',
    // Doc: https://github.com/nuxt-community/stylelint-module
    '@nuxtjs/stylelint-module',
    // Doc: https://github.com/nuxt-community/nuxt-tailwindcss
    '@nuxtjs/tailwindcss'
  ],
  /*
   ** Nuxt.js modules
   */
  modules: [
    // Doc: https://github.com/nuxt/content
    '@nuxt/content',
    // Restore createdAt/updatedAt from git; CI checkout mtimes are identical
    '~/modules/content-git-dates'
  ],
  /*
   ** Content module configuration
   ** See https://content.nuxtjs.org/configuration
   */
  content: {
    markdown: {
      prism: {
        theme: 'prism-themes/themes/prism-material-oceanic.css'
      }
    },
    nestedProperties: ['author.name']
  },
  /*
   ** Build configuration
   ** See https://nuxtjs.org/api/configuration-build/
   */
  build: {}
}
