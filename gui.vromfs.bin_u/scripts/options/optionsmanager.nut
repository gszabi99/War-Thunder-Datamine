from "%scripts/dagui_natives.nut" import get_option_aerobatics_smoke_type
from "%scripts/dagui_library.nut" import *

let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { checkSpeechCountryUnitLocalizationPackageAndAskDownload } = require("%scripts/clientState/contentPacks.nut")

let checkUnitSpeechLangPackWatch = mkWatched(persist, "checkUnitSpeechLangPackWatch", false)

function checkUnitSpeechLangPack(_params) {
  if (!checkUnitSpeechLangPackWatch.get())
    return

  get_cur_gui_scene().performDelayed(
    {},
    function() {
      checkSpeechCountryUnitLocalizationPackageAndAskDownload()
    }
  )

  checkUnitSpeechLangPackWatch.set(false)
}


subscriptions.addListenersWithoutEnv({
  ActiveHandlersChanged = checkUnitSpeechLangPack
})

return {
  checkUnitSpeechLangPackWatch
  isTripleColorSmokeAvailable = @() hasFeature("AerobaticTricolorSmoke") && (get_option_aerobatics_smoke_type() == TRICOLOR_INDEX)
}