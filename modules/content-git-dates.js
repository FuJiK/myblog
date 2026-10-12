const { applyContentGitDates } = require('../scripts/content-git-dates')

module.exports = function contentGitDatesModule() {
  this.nuxt.hook('content:file:beforeInsert', (document) => {
    applyContentGitDates(document)
  })
}
