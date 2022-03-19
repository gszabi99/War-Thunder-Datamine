local { markupTooltipHoldChild } = require("scripts/utils/delayedTooltip.nut")

::gui_choose_slotbar_preset <- function gui_choose_slotbar_preset(owner = null)
{
  return ::handlersManager.loadHandler(::gui_handlers.ChooseSlotbarPreset, { ownerWeak = owner })
}

class ::gui_handlers.ChooseSlotbarPreset extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/slotbar/slotbarChoosePreset.blk"

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

    local objPresets = scene.findObject("items_list")
    if (!::checkObj(objPresets))
      return

    local view = { items = [] }
    foreach (idx, preset in presets)
    {
      local title = preset.title
      if (idx == activePreset)
        title += ::nbsp + ::loc("shop/current")

      view.items.append({
        itemTag = preset.enabled ? "mission_item_unlocked" : "mission_item_locked"
        id = "preset" + idx
        isSelected = idx == chosenValue
        itemText = title
        isNeedOnHover = ::show_console_buttons
      })
    }

    local data = ::handyman.renderCached("gui/missions/missionBoxItemsList", view)
    guiScene.replaceContentFromText(objPresets, data, data.len(), this)
    for (local i = 0; i < objPresets.childrenCount(); i++)
      objPresets.getChild(i).setIntProp(listIdxPID, i)
    onItemSelect(objPresets)
    restoreFocusDelayed()
  }

  function updateDescription()
  {
    local objDesc = scene.findObject("item_desc")
    if (!::checkObj(objDesc))
      return

    if (chosenValue in presets)
    {
      local preset = presets[chosenValue]
      local perRow = 3
      local unitItems = []

      local presetBattleRatingText = ""
      if (::has_feature("SlotbarShowBattleRating"))
      {
        local ediff = getCurrentEdiff()
        local battleRatingMin = 0
        local battleRatingMax = 0
        foreach (unitId in preset.units)
        {
          local unit = ::getAircraftByName(unitId)
          local br = unit ? unit.getBattleRating(ediff) : 0.0
          battleRatingMin = !battleRatingMin ? br : ::min(battleRatingMin, br)
          battleRatingMax = !battleRatingMax ? br : ::max(battleRatingMax, br)
        }
        local battleRatingRange = ::format("%.1f %s %.1f", battleRatingMin, ::loc("ui/mdash"), battleRatingMax)
        presetBattleRatingText = ::loc("shop/battle_rating") + ::loc("ui/colon") + battleRatingRange + "\n"
      }

      local gameMode = ::game_mode_manager.getGameModeById(preset.gameModeId)??
                       ::game_mode_manager.getCurrentGameMode()
      local presetGameMode = gameMode != null ? ::loc("options/mp_mode") +
                                                ::loc("ui/colon") + gameMode.text + "\n" : ""

      local header = "".concat(::g_string.stripTags(presetBattleRatingText),
        ::g_string.stripTags(presetGameMode),
        ::loc("shop/slotbarPresets/contents"),
        ::loc("ui/colon"))
      local markupList = ["textarea{ text:t='{0}' padding:t='0, 8*@sf/@pf_outdated' } ".subst(header)]

      local unitsMarkupList = []
      local filteredUnits = preset.units.filter(@(u) u != "")
      foreach(idx, unitId in filteredUnits)
      {
        local unit = ::getAircraftByName(unitId)
        if (!unit)
          continue
        local params = {
          hasActions = false
          status = unit.unitType.isAvailable() ? "owned" : "locked"
          showBR = ::has_feature("SlotbarShowBattleRating")
          getEdiffFunc = getCurrentEdiff.bindenv(this)
          position = "absolute"
          posX = idx % perRow
          posY = idx / perRow
        }
        unitsMarkupList.append(::build_aircraft_item(unitId, unit, params))
        unitItems.append({ id = unitId, unit = unit, params = params })
      }
      local sizeStr = "size:t='{0}@slot_width, {1}@slot_height + {1}*2@slot_interval';".subst(
        perRow, ::ceil(filteredUnits.len().tofloat() / perRow).tointeger())
      markupList.append("slotbarPresetsTable { {0} {1} {2} }"
        .subst(sizeStr, ::show_console_buttons ? markupTooltipHoldChild : "", " ".join(unitsMarkupList)))

      if (!preset.enabled)
        markupList.append("textarea{ text:t='{0}' padding:t='0, 8*@sf/@pf_outdated' } "
          .subst(::colorize("badTextColor", ::g_string.stripTags(::loc("shop/slotbarPresets/forbidden/unitTypes")))))

      local markup = "\n".join(markupList)
      guiScene.replaceContentFromText(objDesc, markup, markup.len(), this)
      foreach (unitItem in unitItems)
        ::fill_unit_item_timers(objDesc.findObject(unitItem.id), unitItem.unit, unitItem.params)
    }
    else
    {
      local data = ::format("textarea{ text:t='%s' width:t='pw' } ", ::g_string.stripTags(::loc("shop/slotbarPresets/presetUnknown")))
      guiScene.replaceContentFromText(objDesc, data, data.len(), this)
    }

    updateButtons()
  }

  function getCurrentEdiff()
  {
    local slotbar = ownerWeak && ownerWeak.getSlotbar()
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
      local isAnyPresetHovered = hoveredValue != -1
      local isShowContextActions = ::is_mouse_last_time_used() || (isAnyPresetHovered && hoveredValue == chosenValue)
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

    local isAnyPresetSelected = chosenValue != -1
    local isCurrentPresetSelected = chosenValue == activePreset
    local isNonCurrentPresetSelected = isAnyPresetSelected && !isCurrentPresetSelected
    local selectedPresetEnabled = isCurrentPresetSelected || ((chosenValue in presets) ? presets[chosenValue].enabled : false)
    local canEdit = ::slotbarPresets.canEditCountryPresets(::get_profile_country_sq())

    ::enableBtnTable(scene, {
        btn_preset_create = canEdit
        btn_preset_rename = canEdit
        btn_preset_delete = canEdit && ::slotbarPresets.canErase() && isNonCurrentPresetSelected
        btn_preset_load   = ::slotbarPresets.canLoad()  && isAnyPresetSelected && selectedPresetEnabled
        btn_preset_move_up= canEdit && isAnyPresetSelected && chosenValue > 0
        btn_preset_move_dn= canEdit && isAnyPresetSelected && chosenValue < presets.len() - 1
    })

    local objBtn = scene.findObject("btn_preset_load")
    if (::checkObj(objBtn))
      objBtn.text = ::loc(isNonCurrentPresetSelected ? "mainmenu/btnApply" : "mainmenu/btnClose")
  }

  function onItemSelect(obj)
  {
    local objPresets = scene.findObject("items_list")
    if (!::checkObj(objPresets))
      return
    chosenValue = objPresets.getValue()
    updateDescription()
  }

  function onBtnPresetAdd(obj)
  {
    if (::slotbarPresets.canCreate())
      ::slotbarPresets.create()
    else
    {
      local reason = ::slotbarPresets.havePresetsReserve() ?
                              ::loc("shop/slotbarPresetsReserve",
                                { tier = ::roman_numerals[::slotbarPresets.eraIdForBonus],
                                  unitTypes = ::slotbarPresets.getPresetsReseveTypesText()})
                             :
                              ::loc("shop/slotbarPresetsMax")

      showInfoMsgBox(::format(::loc("weaponry/action_not_allowed"), reason))
    }
  }

  function onBtnPresetDelete(obj)
  {
    if (!::slotbarPresets.canErase() || !(chosenValue in presets))
      return

    local preset = presets[chosenValue]
    local msgText = ::loc("msgbox/genericRequestDelete", { item = preset.title })

    local unitNames = []
    foreach (unitId in preset.units)
      unitNames.append(::loc(unitId + "_shop"))
    local comment = "(" + ::loc("shop/slotbarPresets/contents") + ::loc("ui/colon") + ::g_string.implode(unitNames, ::loc("ui/comma")) + ")"
    comment = ::format("textarea{overlayTextColor:t='bad'; text:t='%s'}", ::g_string.stripTags(comment))

    msgBox("question_delete_preset", msgText,
    [
      ["delete", (@(chosenValue) function() { ::slotbarPresets.erase(chosenValue) })(chosenValue) ],
      ["cancel", function() {} ]
    ], "cancel", { data_below_text = comment })
  }

  function onBtnPresetLoad(obj)
  {
    local handler = this
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
    local isHover = obj.isHovered()
    local idx = obj.getIntProp(listIdxPID, -1)
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
    reinit(::getTblValue("showPreset", params, -1))
  }

  function onEventModalWndDestroy(params)
  {
    if (isSceneActiveNoModals())
      restoreFocusDelayed()
  }
}
