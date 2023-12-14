//-file:plus-string
from "%scripts/dagui_natives.nut" import is_mouse_last_time_used
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_child_by_value, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { markupTooltipHoldChild } = require("%scripts/utils/delayedTooltip.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { ceil } = require("math")
let { stripTags } = require("%sqstd/string.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { buildUnitSlot, fillUnitSlotTimers } = require("%scripts/slotbar/slotbarView.nut")

::gui_choose_slotbar_preset <- function gui_choose_slotbar_preset(owner = null) {
  return handlersManager.loadHandler(gui_handlers.ChooseSlotbarPreset, { ownerWeak = owner })
}

gui_handlers.ChooseSlotbarPreset <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/slotbar/slotbarChoosePreset.blk"

  ownerWeak = null
  presets = []
  activePreset = null
  chosenValue = -1

  listIdxPID = dagui_propid_add_name_id("listIdx")
  hoveredValue = -1

  function initScreen() {
    if (this.ownerWeak)
      this.ownerWeak = this.ownerWeak.weakref()
    this.reinit(null, true)
  }

  function reinit(showPreset = null, verbose = false) {
    if (!::slotbarPresets.canLoad(verbose))
      return this.goBack()

    this.presets = ::slotbarPresets.list()
    this.activePreset = ::slotbarPresets.getCurrent()
    this.chosenValue = showPreset != null ? showPreset : this.activePreset != null ? this.activePreset : -1
    this.hoveredValue = -1

    let objPresets = this.scene.findObject("items_list")
    if (!checkObj(objPresets))
      return

    let view = { items = [] }
    foreach (idx, preset in this.presets) {
      local title = preset.title
      if (idx == this.activePreset)
        title += nbsp + loc("shop/current")

      view.items.append({
        itemTag = preset.enabled ? "mission_item_unlocked" : "mission_item_locked"
        id = "preset" + idx
        isSelected = idx == this.chosenValue
        itemText = title
        isNeedOnHover = showConsoleButtons.value
      })
    }

    let data = handyman.renderCached("%gui/missions/missionBoxItemsList.tpl", view)
    this.guiScene.replaceContentFromText(objPresets, data, data.len(), this)
    for (local i = 0; i < objPresets.childrenCount(); i++)
      objPresets.getChild(i).setIntProp(this.listIdxPID, i)
    this.onItemSelect(objPresets)
    this.restoreFocusDelayed()
  }

  function updateDescription() {
    let objDesc = this.scene.findObject("item_desc")
    if (!checkObj(objDesc))
      return

    if (this.chosenValue in this.presets) {
      let preset = this.presets[this.chosenValue]
      let perRow = 3
      let unitItems = []

      local presetBattleRatingText = ""
      if (hasFeature("SlotbarShowBattleRating")) {
        let ediff = this.getCurrentEdiff()
        local battleRatingMin = 0
        local battleRatingMax = 0
        foreach (unitId in preset.units) {
          let unit = getAircraftByName(unitId)
          let br = unit ? unit.getBattleRating(ediff) : 0.0
          battleRatingMin = !battleRatingMin ? br : min(battleRatingMin, br)
          battleRatingMax = !battleRatingMax ? br : max(battleRatingMax, br)
        }
        let battleRatingRange = format("%.1f %s %.1f", battleRatingMin, loc("ui/mdash"), battleRatingMax)
        presetBattleRatingText = loc("shop/battle_rating") + loc("ui/colon") + battleRatingRange + "\n"
      }

      let gameMode = ::game_mode_manager.getGameModeById(preset.gameModeId) ??
                       ::game_mode_manager.getCurrentGameMode()
      let presetGameMode = gameMode != null ? loc("options/mp_mode") +
                                                loc("ui/colon") + gameMode.text + "\n" : ""

      let header = "".concat(stripTags(presetBattleRatingText),
        stripTags(presetGameMode),
        loc("shop/slotbarPresets/contents"),
        loc("ui/colon"))
      let markupList = ["textarea{ text:t='{0}' padding:t='0, 8*@sf/@pf_outdated' } ".subst(header)]

      let unitsMarkupList = []
      let filteredUnits = preset.units.filter(@(u) u != "")
      foreach (idx, unitId in filteredUnits) {
        let unit = getAircraftByName(unitId)
        if (!unit)
          continue
        let params = {
          hasActions = false
          status = unit.unitType.isAvailable() ? "owned" : "locked"
          showBR = hasFeature("SlotbarShowBattleRating")
          getEdiffFunc = this.getCurrentEdiff.bindenv(this)
          position = "absolute"
          posX = idx % perRow
          posY = idx / perRow
        }
        unitsMarkupList.append(buildUnitSlot(unitId, unit, params))
        unitItems.append({ id = unitId, unit = unit, params = params })
      }
      let sizeStr = "size:t='{0}@slot_width, {1}@slot_height + {1}*2@slot_interval';".subst(
        perRow, ceil(filteredUnits.len().tofloat() / perRow).tointeger())
      markupList.append("slotbarPresetsTable { {0} {1} {2} }"
        .subst(sizeStr, showConsoleButtons.value ? markupTooltipHoldChild : "", " ".join(unitsMarkupList)))

      if (!preset.enabled)
        markupList.append("textarea{ text:t='{0}' padding:t='0, 8*@sf/@pf_outdated' } "
          .subst(colorize("badTextColor", stripTags(loc("shop/slotbarPresets/forbidden/unitTypes")))))

      let markup = "\n".join(markupList)
      this.guiScene.replaceContentFromText(objDesc, markup, markup.len(), this)
      foreach (unitItem in unitItems)
        fillUnitSlotTimers(objDesc.findObject(unitItem.id), unitItem.unit)
    }
    else {
      let data = format("textarea{ text:t='%s' width:t='pw' } ", stripTags(loc("shop/slotbarPresets/presetUnknown")))
      this.guiScene.replaceContentFromText(objDesc, data, data.len(), this)
    }

    this.updateButtons()
  }

  function getCurrentEdiff() {
    let slotbar = this.ownerWeak && this.ownerWeak.getSlotbar()
    return slotbar ? slotbar.getCurrentEdiff() : ::get_current_ediff()
  }

  restoreFocusDelayed = @() this.guiScene.performDelayed(this, function() {
    if (this.isValid())
      move_mouse_on_child_by_value(this.scene.findObject("items_list"))
  })

  function updateButtons() {
    if (showConsoleButtons.value) {
      let isAnyPresetHovered = this.hoveredValue != -1
      let isShowContextActions = is_mouse_last_time_used() || (isAnyPresetHovered && this.hoveredValue == this.chosenValue)
      showObjectsByTable(this.scene, {
        btn_preset_rename   = isShowContextActions
        btn_preset_delete   = isShowContextActions
        btn_preset_load     = isShowContextActions
        btn_preset_move_up  = isShowContextActions
        btn_preset_move_dn  = isShowContextActions
        btn_preset_select   = !isShowContextActions && isAnyPresetHovered
      })
      if (!isShowContextActions)
        return
    }

    let isAnyPresetSelected = this.chosenValue != -1
    let isCurrentPresetSelected = this.chosenValue == this.activePreset
    let isNonCurrentPresetSelected = isAnyPresetSelected && !isCurrentPresetSelected
    let selectedPresetEnabled = isCurrentPresetSelected || ((this.chosenValue in this.presets) ? this.presets[this.chosenValue].enabled : false)
    let canEdit = ::slotbarPresets.canEditCountryPresets(profileCountrySq.value)

    ::enableBtnTable(this.scene, {
        btn_preset_create = canEdit
        btn_preset_copy = canEdit
        btn_preset_rename = canEdit
        btn_preset_delete = canEdit && ::slotbarPresets.canErase() && isNonCurrentPresetSelected
        btn_preset_load   = ::slotbarPresets.canLoad()  && isAnyPresetSelected && selectedPresetEnabled
        btn_preset_move_up = canEdit && isAnyPresetSelected && this.chosenValue > 0
        btn_preset_move_dn = canEdit && isAnyPresetSelected && this.chosenValue < this.presets.len() - 1
    })

    let objBtn = this.scene.findObject("btn_preset_load")
    if (checkObj(objBtn))
      objBtn.text = loc(isNonCurrentPresetSelected ? "mainmenu/btnApply" : "mainmenu/btnClose")
  }

  function onItemSelect(_obj) {
    let objPresets = this.scene.findObject("items_list")
    if (!checkObj(objPresets))
      return
    this.chosenValue = objPresets.getValue()
    this.updateDescription()
  }

  function showNotAllowedMessage() {
    let reason = ::slotbarPresets.havePresetsReserve()
      ? loc("shop/slotbarPresetsReserve",
        { tier = ::roman_numerals[::slotbarPresets.eraIdForBonus], unitTypes = ::slotbarPresets.getPresetsReseveTypesText() })
      : loc("shop/slotbarPresetsMax")
    showInfoMsgBox(format(loc("weaponry/action_not_allowed"), reason))
  }

  function onBtnPresetAdd(_obj) {
    if (::slotbarPresets.canCreate())
      ::slotbarPresets.create()
    else
      this.showNotAllowedMessage()
  }

  function onBtnPresetCopy(_obj) {
    if (!(this.chosenValue in this.presets))
      return

    if (::slotbarPresets.canCreate())
      ::slotbarPresets.copyPreset(this.presets[this.chosenValue])
    else
      this.showNotAllowedMessage()
  }

  function onBtnPresetDelete(_obj) {
    if (!::slotbarPresets.canErase() || !(this.chosenValue in this.presets))
      return

    let preset = this.presets[this.chosenValue]
    let msgText = loc("msgbox/genericRequestDelete", { item = preset.title })

    let unitNames = []
    foreach (unitId in preset.units)
      unitNames.append(loc(unitId + "_shop"))
    local comment = "(" + loc("shop/slotbarPresets/contents") + loc("ui/colon") + loc("ui/comma").join(unitNames, true) + ")"
    comment = format("textarea{overlayTextColor:t='bad'; text:t='%s'}", stripTags(comment))

    this.msgBox("question_delete_preset", msgText,
    [
      ["delete", (@(chosenValue) function() { ::slotbarPresets.erase(chosenValue) })(this.chosenValue) ], //-ident-hides-ident
      ["cancel", function() {} ]
    ], "cancel", { data_below_text = comment })
  }

  function onBtnPresetLoad(_obj) {
    let handler = this
    this.checkedCrewModify(function () {
      if (::slotbarPresets.canLoad())
        if (this.chosenValue in this.presets) {
          ::slotbarPresets.load(this.chosenValue)
          handler.goBack()
        }
    })
  }

  function onBtnPresetMoveUp(_obj) {
    ::slotbarPresets.move(this.chosenValue, -1)
  }

  function onBtnPresetMoveDown(_obj) {
    ::slotbarPresets.move(this.chosenValue, 1)
  }

  function onBtnPresetRename(_obj) {
    ::slotbarPresets.rename(this.chosenValue)
  }

  function onBtnPresetSelect(_obj) {
    if (this.hoveredValue != -1)
      this.scene.findObject("items_list")?.setValue(this.hoveredValue)
  }

  function onItemHover(obj) {
    if (!showConsoleButtons.value)
      return
    let isHover = obj.isHovered()
    let idx = obj.getIntProp(this.listIdxPID, -1)
    if (isHover == (this.hoveredValue == idx))
      return
    this.hoveredValue = isHover ? idx : -1
    this.updateButtons()
  }

  function onItemDblClick(obj) {
    if (showConsoleButtons.value)
      return
    this.onBtnPresetLoad(obj)
  }

  function onEventSlotbarPresetLoaded(_params) {
    this.reinit()
  }

  function onEventSlotbarPresetsChanged(params) {
    this.reinit(getTblValue("showPreset", params, -1))
  }

  function onEventModalWndDestroy(params) {
    base.onEventModalWndDestroy(params)
    if (this.isSceneActiveNoModals())
      this.restoreFocusDelayed()
  }
}
