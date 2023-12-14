//checked for plus_string
from "%scripts/dagui_natives.nut" import get_option_aerobatics_smoke_type
from "%scripts/dagui_library.nut" import *

let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")

let checkUnitSpeechLangPackWatch = mkWatched(persist, "checkUnitSpeechLangPackWatch", false)

let function checkUnitSpeechLangPack(_params) {
  if (!checkUnitSpeechLangPackWatch.value)
    return

  get_cur_gui_scene().performDelayed(
    {},
    function() {
      ::check_speech_country_unit_localization_package_and_ask_download()
    }
  )

  checkUnitSpeechLangPackWatch(false)
}


subscriptions.addListenersWithoutEnv({
  ActiveHandlersChanged = checkUnitSpeechLangPack
})

return {
  checkUnitSpeechLangPackWatch
  isTripleColorSmokeAvailable = @() hasFeature("AerobaticTricolorSmoke") && (get_option_aerobatics_smoke_type() == TRICOLOR_INDEX)
}