let path = "%scripts/dirtyWords"
let dirtyWordsFilter = require($"{path}/dirtyWords.nut")

dirtyWordsFilter.init([
  require($"{path}/dirtyWordsEnglish.nut"),
  require($"{path}/dirtyWordsRussian.nut"),
  require($"{path}/dirtyWordsJapanese.nut"),
])

return dirtyWordsFilter
