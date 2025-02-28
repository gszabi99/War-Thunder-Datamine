from "%scripts/dagui_library.nut" import *
let { eventbus_subscribe } = require("eventbus")

let path = "%globalScripts/dirtyWords"
let dirtyWordsFilter = require($"{path}/dirtyWords.nut")
let { init } =  dirtyWordsFilter

let initialize = @() init([
  require($"{path}/dirtyWordsEnglish.nut"),
  require($"{path}/dirtyWordsRussian.nut"),
  require($"{path}/dirtyWordsChinese.nut"),
  require($"{path}/dirtyWordsJapanese.nut"),
])

initialize()

eventbus_subscribe("on_language_changed", @(_) initialize())

return dirtyWordsFilter
