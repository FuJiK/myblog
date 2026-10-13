const fs = require('fs')
const path = require('path')

const root = path.resolve(__dirname, '..')
const distDir = path.join(root, 'dist')
const articlesDir = path.join(root, 'content', 'articles')
const sitemapPath = path.join(distDir, 'sitemap.xml')

function fail(message) {
  console.error(`ERROR: ${message}`)
  process.exitCode = 1
}

function assert(condition, message) {
  if (!condition) fail(message)
}

function read(file) {
  return fs.readFileSync(file, 'utf8')
}

assert(
  fs.existsSync(distDir),
  'dist directory does not exist. Run generate first.'
)
assert(fs.existsSync(sitemapPath), 'dist/sitemap.xml does not exist.')
assert(fs.existsSync(articlesDir), 'content/articles directory does not exist.')

if (process.exitCode) process.exit(process.exitCode)

const articleFiles = fs
  .readdirSync(articlesDir)
  .filter((name) => name.endsWith('.md'))
  .sort()

assert(articleFiles.length > 0, 'No article markdown files found.')

const sitemap = read(sitemapPath)
let decodedSitemap = sitemap
try {
  decodedSitemap = decodeURIComponent(sitemap)
} catch (_) {
  // Keep the raw sitemap when a literal percent sign prevents decoding.
}

const canonicals = new Set()
const modifiedTimes = []

for (const filename of articleFiles) {
  const slug = path.basename(filename, '.md')
  const htmlPath = path.join(distDir, 'blog', slug, 'index.html')
  const relativePath = `/blog/${slug}`

  assert(
    fs.existsSync(htmlPath),
    `Generated article page is missing: ${relativePath}`
  )
  if (!fs.existsSync(htmlPath)) continue

  const html = read(htmlPath)

  assert(
    /<title>[^<]+<\/title>/i.test(html),
    `${relativePath}: title is missing`
  )
  assert(
    /<meta[^>]+name=["']description["'][^>]+content=["'][^"']+["']/i.test(
      html
    ) ||
      /<meta[^>]+content=["'][^"']+["'][^>]+name=["']description["']/i.test(
        html
      ),
    `${relativePath}: meta description is missing`
  )

  const canonicalMatch =
    html.match(/<link[^>]+rel=["']canonical["'][^>]+href=["']([^"']+)["']/i) ||
    html.match(/<link[^>]+href=["']([^"']+)["'][^>]+rel=["']canonical["']/i)

  assert(Boolean(canonicalMatch), `${relativePath}: canonical URL is missing`)
  if (canonicalMatch) {
    assert(
      !canonicals.has(canonicalMatch[1]),
      `${relativePath}: duplicate canonical URL`
    )
    canonicals.add(canonicalMatch[1])
  }

  assert(
    /<script[^>]+type=["']application\/ld\+json["'][^>]*>/i.test(html),
    `${relativePath}: JSON-LD is missing`
  )

  const modifiedMatch =
    html.match(
      /<meta[^>]+property=["']article:modified_time["'][^>]+content=["']([^"']+)["']/i
    ) ||
    html.match(
      /<meta[^>]+content=["']([^"']+)["'][^>]+property=["']article:modified_time["']/i
    )
  if (modifiedMatch) modifiedTimes.push(modifiedMatch[1])

  assert(
    decodedSitemap.includes(relativePath),
    `${relativePath}: URL is missing from sitemap.xml`
  )
}

if (modifiedTimes.length > 1) {
  const uniqueModifiedTimes = new Set(modifiedTimes)
  assert(
    uniqueModifiedTimes.size > 1,
    'All article modified times are identical; generated metadata may have collapsed to the CI checkout time.'
  )
}

if (!process.exitCode) {
  console.log(
    `Verified ${articleFiles.length} generated article pages successfully.`
  )
}
