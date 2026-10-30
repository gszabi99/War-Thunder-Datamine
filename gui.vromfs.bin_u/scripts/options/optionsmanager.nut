import "%sqStdLibs/helpers/subscriptions.nut" as subscriptions
from "%scripts/clientState/contentPacks.nut" import checkSpeechCountryUnitLocalizationPackageAndAskDownload
from "%scripts/dagui_natives.nut" import get_option_aerobatics_smoke_type
from "%scripts/dagui_library.nut" import *
from "%globalScripts/hangarMiscConsts.nut" import *

let checkUnitSpeechLangPackWatch = mkHardPersistWatched("options.optionsManager")("checkUnitSpeechLangPackWatch", false)

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

return freeze({
  checkUnitSpeechLangPackWatch
  isTripleColorSmokeAvailable = @() hasFeature("AerobaticTricolorSmoke") && (get_option_aerobatics_smoke_type() == TRICOLOR_INDEX)
})