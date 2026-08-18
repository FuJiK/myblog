const fs = require('fs')
const path = require('path')

const SITE_URL = (
  process.env.SITE_URL || 'https://www.theshibsters.com'
).replace(/\/$/, '')
const DIST_DIR = path.resolve(__dirname, '..', 'dist')
const SITEMAP_PATH = path.join(DIST_DIR, 'sitemap.xml')

function collectIndexFiles(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const entryPath = path.join(directory, entry.name)

    if (entry.isDirectory()) {
      return collectIndexFiles(entryPath)
    }

    return entry.isFile() && entry.name === 'index.html' ? [entryPath] : []
  })
}

function toRoute(indexFile) {
  const relativeDirectory = path.relative(DIST_DIR, path.dirname(indexFile))

  if (!relativeDirectory) {
    return '/'
  }

  return `/${relativeDirectory.split(path.sep).join('/')}`
}

function escapeXml(value) {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;')
}

if (!fs.existsSync(DIST_DIR)) {
  throw new Error(`Generated directory not found: ${DIST_DIR}`)
}

const routes = collectIndexFiles(DIST_DIR).map(toRoute).sort()
const urlEntries = routes
  .map((route) => {
    const absoluteUrl = new URL(route, `${SITE_URL}/`).href
    return `  <url><loc>${escapeXml(absoluteUrl)}</loc></url>`
  })
  .join('\n')
const sitemap = [
  '<?xml version="1.0" encoding="UTF-8"?>',
  '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
  urlEntries,
  '</urlset>',
  ''
].join('\n')

fs.writeFileSync(SITEMAP_PATH, sitemap, 'utf8')
process.stdout.write(
  `Generated sitemap with ${routes.length} routes: ${SITEMAP_PATH}\n`
)
