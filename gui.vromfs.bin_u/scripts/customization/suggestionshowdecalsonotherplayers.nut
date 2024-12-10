from "%scripts/dagui_library.nut" import *

let { get_charserver_time_sec } = require("chard")
let { get_last_skin } = require("unitCustomization")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { getMaxUnitsRank } = require("%scripts/shop/shopUnitsInfo.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_SHOW_OTHERS_DECALS
} = require("%scripts/options/optionsExtNames.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { getCachedDataByType } = require("%scripts/customization/decorCache.nut")
let { decoratorTypes } = require("%scripts/customization/types.nut")
let { isProfileReceived } = require("%scripts/login/loginStates.nut")

const SHOWED_SUGGESTED_SAVE_PATH = "seen/suggestionShowDecalsOnOtherPlayers"
const SUGGESTED_DELAY_TIME_SEC = 15552000 //180 days
const MIN_VEHICLE_RANK_FOR_CHECK_OPTIONS = 5

let SHOW_SAVE_ID = $"{SHOWED_SUGGESTED_SAVE_PATH}/show"
let LAST_SHOW_TIME_SEC_SAVE_ID = $"{SHOWED_SUGGESTED_SAVE_PATH}/lastShowTimeSec"

let enableDecalsOnOtherPlayersOpt = @() ::set_gui_option_in_mode(USEROPT_SHOW_OTHERS_DECALS, true, OPTIONS_MODE_GAMEPLAY)

let isEnableDecalsOnOtherPlayersOpt = @() ::get_gui_option_in_mode(USEROPT_SHOW_OTHERS_DECALS, OPTIONS_MODE_GAMEPLAY, false)

let class SuggestionShowDecalsOnOtherPlayers (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/customization/suggestionShowDecalsOnOtherPlayers.blk"

  function initScreen() {
    this.scene.findObject("desc_text").setValue(loc("msgbox/enable_show_others_decals_option",
      { optionPathText = " - ".concat(loc("mainmenu/btnGameplay"),
        loc("options/mainParameters"), loc("mainmenu/btnShowroom")) }))
  }

  function onOk() {
    saveLocalAccountSettings(LAST_SHOW_TIME_SEC_SAVE_ID, get_charserver_time_sec())
    enableDecalsOnOtherPlayersOpt()
    base.goBack()
  }

  function goBack() {
    saveLocalAccountSettings(LAST_SHOW_TIME_SEC_SAVE_ID, get_charserver_time_sec())
    base.goBack()
  }
}

gui_handlers.SuggestionShowDecalsOnOtherPlayers <- SuggestionShowDecalsOnOtherPlayers

function showPopupAboutSwithOption() {
 loadHandler(SuggestionShowDecalsOnOtherPlayers)
}

let checkedDecalsGroups = {
  roundels = true
  numbers = true
  un_flags = true
}

function hasInflictedForbiddenDecal() {
  let decalsData = getCachedDataByType(decoratorTypes.DECALS)
  let decalsList = {}
  foreach (group, _ in checkedDecalsGroups) {
    let groupDecals = decalsData.catToGroups?.common[group] ?? []
    foreach (decal in groupDecals)
      decalsList[decal.id] <- true
  }

  if (decalsList.len() == 0)
    return false

  let slotCount = decoratorTypes.DECALS.getMaxSlots()
  foreach (unit in getAllUnits()) {
    if (!unit.isBought())
      continue

    local skinId = get_last_skin(unit.name)
    skinId = skinId == "" ? "default" : skinId
    for (local i = 0; i < slotCount; i++) {
      let decalId = decoratorTypes.DECALS.getDecoratorNameInSlot(i, unit.name, skinId)
      if (decalId in decalsList)
        return true
    }
  }

  return false
}

function checkDecalsOnOtherPlayersOptions() {
  if (!isProfileReceived.get())
    return

  if (loadLocalAccountSettings(SHOW_SAVE_ID)) //options already checked visible
    return

  saveLocalAccountSettings(SHOW_SAVE_ID, true)
  if (isEnableDecalsOnOtherPlayersOpt())
    return

  if (getMaxUnitsRank() < MIN_VEHICLE_RANK_FOR_CHECK_OPTIONS)
    return
  if (hasInflictedForbiddenDecal()) {
    enableDecalsOnOtherPlayersOpt()
    return
  }

  showPopupAboutSwithOption()
}

function tryShowPeriodicPopupDecalsOnOtherPlayers() {
  if (!isProfileReceived.get())
    return

  if (isEnableDecalsOnOtherPlayersOpt())
    return

  if (loadLocalAccountSettings(LAST_SHOW_TIME_SEC_SAVE_ID, 0) + SUGGESTED_DELAY_TIME_SEC
      >= get_charserver_time_sec())
    return

  showPopupAboutSwithOption()
}

return {
  checkDecalsOnOtherPlayersOptions
  tryShowPeriodicPopupDecalsOnOtherPlayers
}
