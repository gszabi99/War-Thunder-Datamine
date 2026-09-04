from "guiOptions" import get_cd_preset, set_cd_preset, getCdOption, getCdBaseDifficulty
from "guiMission" import reload_cd
from "%scripts/dagui_library.nut" import *
from "%globalScripts/difficultyConsts.nut" import *
from "%scripts/options/optionsExtNames.nut" import *
from "%scripts/controls/controlsConsts.nut" import optionControlType

let { g_difficulty } = require("%scripts/difficulty.nut")
let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { ActionsList } = require("%scripts/actionsList.nut")
let { GenericOptionsModal } = require("%scripts/genericOptions.nut")
let { getCustomDifficultyOptions } = require("%scripts/matchingRooms/matchingGameModesUtils.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { set_option, get_option } = require("%scripts/options/optionsExt.nut")

let OptionsCustomDifficultyModal = class (GenericOptionsModal) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/options/genericOptionsModal.blk"

  options = null
  afterApplyFunc = null
  applyAtClose = false

  curBaseDifficulty = DIFFICULTY_ARCADE
  ignoreUiCallbacks = false

  function initScreen() {
    this.scene.findObject("header_name").setValue(loc("profile/difficulty"))
    this.options = getCustomDifficultyOptions()
    base.initScreen()
    this.updateCurBaseDifficulty()
  }

  function reinitScreen() {
    let optListObj = this.scene.findObject(this.currentContainerName)
    if (!checkObj(optListObj))
      return
    this.options = getCustomDifficultyOptions()

    this.ignoreUiCallbacks = true
    foreach (o in this.options) {
      let option = get_option(o[0])
      let obj = optListObj.findObject(option.id)
      if (option.controlType == optionControlType.LIST && option.values[option.value] != getCdOption(option.type))
        assert(false, "".concat("[ERROR] Custom difficulty param ", option.type, " (", option.id, ") value '", getCdOption(option.type), "' is out of range."))
      if (checkObj(obj))
        obj.setValue(option.value)
    }
    this.ignoreUiCallbacks = false

    this.updateCurBaseDifficulty()
  }

  function getNavbarTplView() {
    return {
      left = [
        {
          id = "btn_back"
          text = "#mainmenu/btnBack"
          shortcut = "B"
          funcName = "goBack"
          button = true
        },
        {
          id = "btn_reset"
          text = "#mainmenu/btnReset"
          shortcut = "Y"
          funcName = "onListCdPresets"
          button = true
        },
      ],
      right = [
        {
          id = "btn_apply"
          text = "#mainmenu/btnApply"
          shortcut = "X"
          funcName = "onApply"
          isToBattle = true
          button = true
          delayed = true
        },
      ]
    }
  }

  function updateButtons() {} 

  function updateCurBaseDifficulty() {
    this.curBaseDifficulty = getCdBaseDifficulty()

    let obj = this.scene.findObject("info_text_top")
    if (!checkObj(obj))
      return
    let text = "".concat(loc("customdiff/value"), loc($"difficulty{this.curBaseDifficulty}"))
    obj.setValue(text)
  }

  function applyFunc() {
    reload_cd()
    if (this.afterApplyFunc)
      this.afterApplyFunc()
  }

  function onApply(obj) {
    
    set_cd_preset(get_cd_preset(this.curBaseDifficulty))
    base.onApply(obj)
  }

  function onCDChange(obj) {
    if (this.ignoreUiCallbacks)
      return
    let option = this.get_option_by_id(obj.id)
    if (!option)
      return
    set_option(option.type, obj.getValue(), option)
    this.updateCurBaseDifficulty()
  }

  function onListCdPresets(obj) {
    if (!checkObj(obj))
      return

    if (ActionsList.hasActionsListOnObject(obj)) {
      ActionsList.removeActionsListFromObject(obj, true)
      return
    }

    let option = get_option(USEROPT_DIFFICULTY)
    let menu = { handler = this, actions = [] }
    for (local i = 0; i < option.items.len(); i++) {
      if (option.diffCode[i] == DIFFICULTY_CUSTOM)
        continue
      let difficulty = g_difficulty.getDifficultyByDiffCode(option.diffCode[i])
      let cdPresetValue = difficulty.cdPresetValue
      menu.actions.append({
        actionName  = option.values[i]
        text        = option.items[i]
        icon        = difficulty.icon
        selected    = i == this.curBaseDifficulty
        action      = @() this.applyCdPreset(cdPresetValue)
      })
    }
    ActionsList.open(obj, menu)
  }

  function applyCdPreset(cdValue) {
    set_cd_preset(cdValue)
    this.reinitScreen()
  }
}
register_gui_handler("OptionsCustomDifficultyModal", OptionsCustomDifficultyModal)

return { OptionsCustomDifficultyModal }
