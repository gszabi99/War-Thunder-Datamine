from "%globalScripts/systemConfig.nut" import getSystemConfigOption, setSystemConfigOption
from "dagor.localize" import doesLocTextExist
from "%scripts/dagui_library.nut" import *

let langs = {
  "mainmenu/custom_lang_info": "Custom localization enabled",
  "mainmenu/custom_lang_info/tooltip": "You have custom localization enabled. If some texts in the game are displayed incorrectly, contact the author of the installed custom localization (mod) or disable it.",
  "options/customLang": "Custom localization *",
  "guiHints/customLang": "Use custom localization from the lang folder instead of the official localization. Using a custom localization may lead to errors and make the text in the game unreadable."
}

local onLoadValue = null

let isEnabledCustomLocalization = @() getSystemConfigOption("debug/testLocalization", false)

function isUsedCustomLocalization() {
  if(onLoadValue == null)
    onLoadValue = isEnabledCustomLocalization()
  return onLoadValue
}

let setCustomLocalization = @(value) setSystemConfigOption("debug/testLocalization", value)

let hasCustomLocalizationFlag = @()
  getSystemConfigOption("debug/testLocalization") != null

let getLocalization = @(lang) doesLocTextExist(lang) ? loc(lang) : langs[lang]

let hasWarningIcon = @() !doesLocTextExist("options/customLang")

return {
  isUsedCustomLocalization
  isEnabledCustomLocalization
  setCustomLocalization
  hasCustomLocalizationFlag
  getLocalization
  hasWarningIcon
}