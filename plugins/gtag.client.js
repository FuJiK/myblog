const GA_MEASUREMENT_ID = process.env.GOOGLE_ANALYTICS_ID

export default ({ app }) => {
  if (!GA_MEASUREMENT_ID) {
    return
  }

  window.dataLayer = window.dataLayer || []
  function gtag() {
    window.dataLayer.push(arguments)
  }
  window.gtag = gtag
  gtag('js', new Date())
  gtag('config', GA_MEASUREMENT_ID, { send_page_view: false })

  const script = document.createElement('script')
  script.async = true
  script.src = `https://www.googletagmanager.com/gtag/js?id=${GA_MEASUREMENT_ID}`
  document.head.appendChild(script)

  app.router.afterEach((to) => {
    gtag('config', GA_MEASUREMENT_ID, { page_path: to.fullPath })
  })

  gtag('config', GA_MEASUREMENT_ID, {
    page_path: app.router.currentRoute.fullPath
  })
}
