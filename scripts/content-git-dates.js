const { execFileSync } = require('child_process')
const fs = require('fs')
const path = require('path')

function frontmatterHas(filePath, key) {
  const source = fs.readFileSync(filePath, 'utf8')
  const match = source.match(/^---\r?\n([\s\S]*?)\r?\n---/)

  if (!match) {
    return false
  }

  return new RegExp(`^${key}\\s*:`, 'm').test(match[1])
}

function gitIsoDate(relativePath, { first } = {}) {
  try {
    const args = first
      ? ['log', '--follow', '--format=%aI', '--reverse', '--', relativePath]
      : ['log', '-1', '--format=%aI', '--', relativePath]
    const output = execFileSync('git', args, {
      cwd: process.cwd(),
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore']
    })
    const line = output
      .split('\n')
      .map((value) => value.trim())
      .find(Boolean)

    return line || null
  } catch {
    return null
  }
}

function applyContentGitDates(document) {
  if (!document || !document.path || !document.extension) {
    return
  }

  const relativePath = path.join(
    'content',
    `${String(document.path).replace(/^\//, '')}${document.extension}`
  )
  const absolutePath = path.join(process.cwd(), relativePath)

  if (!fs.existsSync(absolutePath)) {
    return
  }

  const keepCreated = frontmatterHas(absolutePath, 'createdAt')
  const keepUpdated = frontmatterHas(absolutePath, 'updatedAt')

  if (keepCreated && keepUpdated) {
    return
  }

  if (!fs.existsSync(path.join(process.cwd(), '.git'))) {
    return
  }

  if (!keepCreated) {
    const created = gitIsoDate(relativePath, { first: true })

    if (created) {
      document.createdAt = new Date(created)
    }
  }

  if (!keepUpdated) {
    const updated = gitIsoDate(relativePath, { first: false })

    if (updated) {
      document.updatedAt = new Date(updated)
    }
  }
}

module.exports = {
  applyContentGitDates,
  frontmatterHas,
  gitIsoDate
}
