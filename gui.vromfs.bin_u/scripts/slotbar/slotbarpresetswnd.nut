from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let { markupTooltipHoldChild } = require("%scripts/utils/delayedTooltip.nut")

::gui_choose_slotbar_preset <- function gui_choose_slotbar_preset(owner = null)
{
  return ::handlersManager.loadHandler(::gui_handlers.ChooseSlotbarPreset, { ownerWeak = owner })
}

::gui_handlers.ChooseSlotbarPreset <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/slotbar/slotbarChoosePreset.blk"

  ownerWeak = null
  presets = []
  activePreset = null
  chosenValue = -1

  listIdxPID = ::dagui_propid.add_name_id("listIdx")
  hoveredValue = -1

  function initScreen()
  {
    if (ownerWeak)
      ownerWeak = ownerWeak.weakref()
    reinit(null, true)
  }

  function reinit(showPreset = null, verbose = false)
  {
    if (!::slotbarPresets.canLoad(verbose))
      return goBack()

    presets = ::slotbarPresets.list()
    activePreset = ::slotbarPresets.getCurrent()
    chosenValue = showPreset != null ? showPreset : activePreset != null ? activePreset : -1
    hoveredValue = -1

    let objPresets = scene.findObject("items_list")
    if (!checkObj(objPresets))
      return

    let view = { items = [] }
    foreach (idx, preset in presets)
    {
      local title = preset.title
      if (idx == activePreset)
        title += ::nbsp + loc("shop/current")

      view.items.append({
        itemTag = preset.enabled ? "mission_item_unlocked" : "mission_item_locked"
        id = "preset" + idx
        isSelected = idx == chosenValue
        itemText = title
        isNeedOnHover = ::show_console_buttons
      })
    }

    let data = ::handyman.renderCached("%gui/missions/missionBoxItemsList", view)
    guiScene.replaceContentFromText(objPresets, data, data.len(), this)
    for (local i = 0; i < objPresets.childrenCount(); i++)
      objPresets.getChild(i).setIntProp(listIdxPID, i)
    onItemSelect(objPresets)
    restoreFocusDelayed()
  }

  function updateDescription()
  {
    let objDesc = scene.findObject("item_desc")
    if (!checkObj(objDesc))
      return

    if (chosenValue in presets)
    {
      let preset = presets[chosenValue]
      let perRow = 3
      let unitItems = []

      local presetBattleRatingText = ""
      if (hasFeature("SlotbarShowBattleRating"))
      {
        let ediff = getCurrentEdiff()
        local battleRatingMin = 0
        local battleRatingMax = 0
        foreach (unitId in preset.units)
        {
          let unit = ::getAircraftByName(unitId)
          let br = unit ? unit.getBattleRating(ediff) : 0.0
          battleRatingMin = !battleRatingMin ? br : min(battleRatingMin, br)
          battleRatingMax = !battleRatingMax ? br : max(battleRatingMax, br)
        }
        let battleRatingRange = format("%.1f %s %.1f", battleRatingMin, loc("ui/mdash"), battleRatingMax)
        presetBattleRatingText = loc("shop/battle_rating") + loc("ui/colon") + battleRatingRange + "\n"
      }

      let gameMode = ::game_mode_manager.getGameModeById(preset.gameModeId)??
                       ::game_mode_manager.getCurrentGameMode()
      let presetGameMode = gameMode != null ? loc("options/mp_mode") +
                                                loc("ui/colon") + gameMode.text + "\n" : ""

      let header = "".concat(::g_string.stripTags(presetBattleRatingText),
        ::g_string.stripTags(presetGameMode),
        loc("shop/slotbarPresets/contents"),
        loc("ui/colon"))
      let markupList = ["textarea{ text:t='{0}' padding:t='0, 8*@sf/@pf_outdated' } ".subst(header)]

      let unitsMarkupList = []
      let filteredUnits = preset.units.filter(@(u) u != "")
      foreach(idx, unitId in filteredUnits)
      {
        let unit = ::getAircraftByName(unitId)
        if (!unit)
          continue
        let params = {
          hasActions = false
          status = unit.unitType.isAvailable() ? "owned" : "locked"
          showBR = hasFeature("SlotbarShowBattleRating")
          getEdiffFunc = getCurrentEdiff.bindenv(this)
          position = "absolute"
          posX = idx % perRow
          posY = idx / perRow
        }
        unitsMarkupList.append(::build_aircraft_item(unitId, unit, params))
        unitItems.append({ id = unitId, unit = unit, params = params })
      }
      let sizeStr = "size:t='{0}@slot_width, {1}@slot_height + {1}*2@slot_interval';".subst(
        perRow, ::ceil(filteredUnits.len().tofloat() / perRow).tointeger())
      markupList.append("slotbarPresetsTable { {0} {1} {2} }"
        .subst(sizeStr, ::show_console_buttons ? markupTooltipHoldChild : "", " ".join(unitsMarkupList)))

      if (!preset.enabled)
        markupList.append("textarea{ text:t='{0}' padding:t='0, 8*@sf/@pf_outdated' } "
          .subst(colorize("badTextColor", ::g_string.stripTags(loc("shop/slotbarPresets/forbidden/unitTypes")))))

      let markup = "\n".join(markupList)
      guiScene.replaceContentFromText(objDesc, markup, markup.len(), this)
      foreach (unitItem in unitItems)
        ::fill_unit_item_timers(objDesc.findObject(unitItem.id), unitItem.unit, unitItem.params)
    }
    else
    {
      let data = format("textarea{ text:t='%s' width:t='pw' } ", ::g_string.stripTags(loc("shop/slotbarPresets/presetUnknown")))
      guiScene.replaceContentFromText(objDesc, data, data.len(), this)
    }

    updateButtons()
  }

  function getCurrentEdiff()
  {
    let slotbar = ownerWeak && ownerWeak.getSlotbar()
    return slotbar ? slotbar.getCurrentEdiff() : ::get_current_ediff()
  }

  restoreFocusDelayed = @() guiScene.performDelayed(this, function() {
    if (isValid())
      ::move_mouse_on_child_by_value(scene.findObject("items_list"))
  })

  function updateButtons()
  {
    if (::show_console_buttons)
    {
      let isAnyPresetHovered = hoveredValue != -1
      let isShowContextActions = ::is_mouse_last_time_used() || (isAnyPresetHovered && hoveredValue == chosenValue)
      ::showBtnTable(scene, {
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

    let isAnyPresetSelected = chosenValue != -1
    let isCurrentPresetSelected = chosenValue == activePreset
    let isNonCurrentPresetSelected = isAnyPresetSelected && !isCurrentPresetSelected
    let selectedPresetEnabled = isCurrentPresetSelected || ((chosenValue in presets) ? presets[chosenValue].enabled : false)
    let canEdit = ::slotbarPresets.canEditCountryPresets(::get_profile_country_sq())

    ::enableBtnTable(scene, {
        btn_preset_create = canEdit
        btn_preset_copy = canEdit
        btn_preset_rename = canEdit
        btn_preset_delete = canEdit && ::slotbarPresets.canErase() && isNonCurrentPresetSelected
        btn_preset_load   = ::slotbarPresets.canLoad()  && isAnyPresetSelected && selectedPresetEnabled
        btn_preset_move_up= canEdit && isAnyPresetSelected && chosenValue > 0
        btn_preset_move_dn= canEdit && isAnyPresetSelected && chosenValue < presets.len() - 1
    })

    let objBtn = scene.findObject("btn_preset_load")
    if (checkObj(objBtn))
      objBtn.text = loc(isNonCurrentPresetSelected ? "mainmenu/btnApply" : "mainmenu/btnClose")
  }

  function onItemSelect(obj)
  {
    let objPresets = scene.findObject("items_list")
    if (!checkObj(objPresets))
      return
    chosenValue = objPresets.getValue()
    updateDescription()
  }

  function showNotAllowedMessage()
  {
    let reason = ::slotbarPresets.havePresetsReserve()
      ? loc("shop/slotbarPresetsReserve",
        { tier = ::roman_numerals[::slotbarPresets.eraIdForBonus], unitTypes = ::slotbarPresets.getPresetsReseveTypesText()})
      : loc("shop/slotbarPresetsMax")
    ::showInfoMsgBox(format(loc("weaponry/action_not_allowed"), reason))
  }

  function onBtnPresetAdd(obj)
  {
    if (::slotbarPresets.canCreate())
      ::slotbarPresets.create()
    else
      showNotAllowedMessage()
  }

  function onBtnPresetCopy(obj)
  {
    if (!(chosenValue in presets))
      return

    if (::slotbarPresets.canCreate())
      ::slotbarPresets.copyPreset(presets[chosenValue])
    else
      showNotAllowedMessage()
  }

  function onBtnPresetDelete(obj)
  {
    if (!::slotbarPresets.canErase() || !(chosenValue in presets))
      return

    let preset = presets[chosenValue]
    let msgText = loc("msgbox/genericRequestDelete", { item = preset.title })

    let unitNames = []
    foreach (unitId in preset.units)
      unitNames.append(loc(unitId + "_shop"))
    local comment = "(" + loc("shop/slotbarPresets/contents") + loc("ui/colon") + ::g_string.implode(unitNames, loc("ui/comma")) + ")"
    comment = format("textarea{overlayTextColor:t='bad'; text:t='%s'}", ::g_string.stripTags(comment))

    this.msgBox("question_delete_preset", msgText,
    [
      ["delete", (@(chosenValue) function() { ::slotbarPresets.erase(chosenValue) })(chosenValue) ],
      ["cancel", function() {} ]
    ], "cancel", { data_below_text = comment })
  }

  function onBtnPresetLoad(obj)
  {
    let handler = this
    checkedCrewModify((@(handler, chosenValue) function () {
      if (::slotbarPresets.canLoad())
        if (chosenValue in presets)
        {
          ::slotbarPresets.load(chosenValue)
          handler.goBack()
        }
    })(handler, chosenValue))
  }

  function onBtnPresetMoveUp(obj)
  {
    ::slotbarPresets.move(chosenValue, -1)
  }

  function onBtnPresetMoveDown(obj)
  {
    ::slotbarPresets.move(chosenValue, 1)
  }

  function onBtnPresetRename(obj)
  {
    ::slotbarPresets.rename(chosenValue)
  }

  function onBtnPresetSelect(obj)
  {
    if(hoveredValue != -1)
      scene.findObject("items_list")?.setValue(hoveredValue)
  }

  function onItemHover(obj)
  {
    if (!::show_console_buttons)
      return
    let isHover = obj.isHovered()
    let idx = obj.getIntProp(listIdxPID, -1)
    if (isHover == (hoveredValue == idx))
      return
    hoveredValue = isHover ? idx : -1
    updateButtons()
  }

  function onItemDblClick(obj)
  {
    if (::show_console_buttons)
      return
    onBtnPresetLoad(obj)
  }

  function onEventSlotbarPresetLoaded(params)
  {
    reinit()
  }

  function onEventSlotbarPresetsChanged(params)
  {
    reinit(getTblValue("showPreset", params, -1))
  }

  function onEventModalWndDestroy(params)
  {
    if (isSceneActiveNoModals())
      restoreFocusDelayed()
  }
}
