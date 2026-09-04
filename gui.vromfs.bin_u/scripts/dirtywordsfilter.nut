from "eventbus" import eventbus_subscribe
from "%scripts/dagui_library.nut" import *
from "auth_wt" import getCountryCode
from "language" import getLocalLanguage

const path = "%globalScripts/dirtyWords"
let dirtyWordsFilter = require($"{path}/dirtyWords.nut")
let { init } =  dirtyWordsFilter

let initialize = @() init(getCountryCode(), getLocalLanguage(), [
  require($"{path}/dirtyWordsEnglish.nut"),
  require($"{path}/dirtyWordsRussian.nut"),
  require($"{path}/dirtyWordsChinese.nut"),
  require($"{path}/dirtyWordsJapanese.nut"),
])

initialize()

eventbus_subscribe("on_language_changed", @(_) initialize())

return dirtyWordsFilter
