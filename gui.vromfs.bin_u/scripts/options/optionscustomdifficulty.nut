from "%scripts/dagui_library.nut" import *
from "%scripts/options/optionsExtNames.nut" import *
from "%scripts/controls/controlsConsts.nut" import optionControlType

let { g_difficulty } = require("%scripts/difficulty.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { getCustomDifficultyOptions } = require("%scripts/matchingRooms/matchingGameModesUtils.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { get_cd_preset, set_cd_preset, getCdOption, getCdBaseDifficulty } = require("guiOptions")
let { reload_cd } = require("guiMission")
let { set_option, get_option } = require("%scripts/options/optionsExt.nut")

gui_handlers.OptionsCustomDifficultyModal <- class (gui_handlers.GenericOptionsModal) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/options/genericOptionsModal.blk"
  titleText = loc("profile/difficulty")

  options = null
  afterApplyFunc = null
  applyAtClose = false

  curBaseDifficulty = DIFFICULTY_ARCADE
  ignoreUiCallbacks = false

  function initScreen() {
    this.scene.findObject("header_name").setValue(this.titleText)
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

  function updateButtons() {} //override from GenericOptionsModal

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
    // init custom difficulty by BaseDifficulty
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

    if (gui_handlers.ActionsList.hasActionsListOnObject(obj)) {
      gui_handlers.ActionsList.removeActionsListFromObject(obj, true)
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
    gui_handlers.ActionsList.open(obj, menu)
  }

  function applyCdPreset(cdValue) {
    set_cd_preset(cdValue)
    this.reinitScreen()
  }
}
