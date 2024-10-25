from "%scripts/dagui_library.nut" import *

let path = "%globalScripts/dirtyWords"
let dirtyWordsFilter = require($"{path}/dirtyWords.nut")

dirtyWordsFilter.init([
  require($"{path}/dirtyWordsEnglish.nut"),
  require($"{path}/dirtyWordsRussian.nut"),
  require($"{path}/dirtyWordsChinese.nut"),
  require($"{path}/dirtyWordsJapanese.nut"),
])

return dirtyWordsFilter
