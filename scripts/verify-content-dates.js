const assert = require('assert')
const fs = require('fs')
const path = require('path')
const { applyContentGitDates, frontmatterHas } = require('./content-git-dates')

function documentFor(relativePath) {
  const withoutContent = relativePath.replace(/^content/, '')
  const extension = path.extname(withoutContent)

  return {
    path: withoutContent.slice(0, -extension.length),
    extension,
    createdAt: new Date('2000-01-01T00:00:00.000Z'),
    updatedAt: new Date('2000-01-01T00:00:00.000Z')
  }
}

function isoDay(value) {
  return new Date(value).toISOString().slice(0, 10)
}

function main() {
  const about = 'content/articles/このブログについて.md'
  const platformMvp = 'content/articles/platform-engineering-mvp.md'
  const javascript = 'content/tags/javascript.md'
  const politics = 'content/tags/politics.md'

  assert.strictEqual(frontmatterHas(about, 'createdAt'), true)
  assert.strictEqual(frontmatterHas(about, 'updatedAt'), false)
  assert.strictEqual(frontmatterHas(javascript, 'createdAt'), false)

  const aboutDoc = documentFor(about)
  applyContentGitDates(aboutDoc)
  assert.strictEqual(
    isoDay(aboutDoc.createdAt),
    '2000-01-01',
    'frontmatter createdAt must not be replaced with git or fs timestamps'
  )
  assert.notStrictEqual(
    isoDay(aboutDoc.updatedAt),
    '2000-01-01',
    'updatedAt without frontmatter must come from git history'
  )

  const platformMvpDoc = documentFor(platformMvp)
  applyContentGitDates(platformMvpDoc)
  assert.strictEqual(isoDay(platformMvpDoc.createdAt), '2000-01-01')

  const javascriptDoc = documentFor(javascript)
  applyContentGitDates(javascriptDoc)
  assert.strictEqual(
    isoDay(javascriptDoc.createdAt),
    '2021-09-09',
    'tags without frontmatter dates must use the first git author date'
  )

  const politicsDoc = documentFor(politics)
  applyContentGitDates(politicsDoc)
  assert.strictEqual(isoDay(politicsDoc.createdAt), '2022-04-09')

  const articleDays = fs
    .readdirSync(path.join('content', 'articles'))
    .filter((name) => name.endsWith('.md'))
    .map((name) => {
      const relativePath = path.join('content', 'articles', name)
      const source = fs.readFileSync(relativePath, 'utf8')
      const created = source.match(/^createdAt:\s*(.+)$/m)

      assert.ok(
        created,
        `${relativePath} needs an explicit createdAt so gh-pages deploys keep the original post date`
      )

      return created[1].trim()
    })

  assert.ok(
    new Set(articleDays).size > 1,
    `article createdAt values must not all collapse to one day, got ${articleDays.join(
      ', '
    )}`
  )
}

main()
