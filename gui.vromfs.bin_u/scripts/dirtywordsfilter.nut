//checked for plus_string
from "%scripts/dagui_library.nut" import *

let path = "%scripts/dirtyWords"
let dirtyWordsFilter = require($"{path}/dirtyWords.nut")

dirtyWordsFilter.init([
  require($"{path}/dirtyWordsEnglish.nut"),
  require($"{path}/dirtyWordsRussian.nut"),
  require($"{path}/dirtyWordsJapanese.nut"),
])

return dirtyWordsFilter
