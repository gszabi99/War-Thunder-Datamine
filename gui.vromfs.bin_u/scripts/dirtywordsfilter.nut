local path = "scripts/dirtyWords"
local dirtyWordsFilter = require($"{path}/dirtyWords.nut")

dirtyWordsFilter.init([
  require($"{path}/dirtyWordsEnglish.nut"),
  require($"{path}/dirtyWordsRussian.nut"),
  require($"{path}/dirtyWordsJapanese.nut"),
])

return dirtyWordsFilter
