local stdMath = require("std/math.nut")

local battlesFilters = [
  {
    multiSelectId = "by_unit_type"
    title = @() ::loc("worldwar/battlesFilter/byUnitType")
    flow = "horizontal"
    onCancelEdit = "goBack"
    needWrapNavigation = true
    list = []
    visibleFilterByUnitTypeMasks = [::g_unit_type.AIRCRAFT.bit, ::g_unit_type.TANK.bit,
      ::g_unit_type.SHIP.bit, ::g_unit_type.AIRCRAFT.bit | ::g_unit_type.TANK.bit,
      ::g_unit_type.AIRCRAFT.bit | ::g_unit_type.SHIP.bit]
    checkChangeValue = function(filterBitMasks, newFilterBitMasks, apply, cancel) {
      local id = "by_unit_type"
      local filterMasks = filterBitMasks?[id] ?? {}
      foreach(mask, value in newFilterBitMasks)
        filterMasks[mask] <- value

      apply(id, filterMasks)
    }
    getFilterMaskByObj = function(obj, valueList) {
      local masks = get_array_by_bit_value(obj.getValue(), valueList)
      local masksList = {}
      foreach(mask in valueList)
        masksList[mask.tostring()] <- ::isInArray(mask, masks)

      return masksList
    }
  },
  {
    multiSelectId = "by_available_battles"
    title = @() ::loc("worldwar/battlesFilter/byAvailableBattles")
    onCancelEdit = "goBack"
    needWrapNavigation = true
    list = [
      {
        value = UNAVAILABLE_BATTLES_CATEGORIES.NO_AVAILABLE_UNITS
        text = @() ::loc("worldwar/battle/filter/show_if_no_avaliable_units")
        needShow = function(bitMask) {
          local unitAvailability = ::g_world_war.getSetting("checkUnitAvailability",
            WW_BATTLE_UNITS_REQUIREMENTS.BATTLE_UNITS)
          return unitAvailability != WW_BATTLE_UNITS_REQUIREMENTS.NO_REQUIREMENTS
        }
      },
      {
        value = UNAVAILABLE_BATTLES_CATEGORIES.NO_FREE_SPACE
        text = @() ::loc("worldwar/battle/filter/show_if_no_space")
      },
      {
        value = UNAVAILABLE_BATTLES_CATEGORIES.IS_UNBALANCED
        text = @()  ::loc("worldwar/battle/filter/show_unbalanced")
      },
      {
        value = UNAVAILABLE_BATTLES_CATEGORIES.LOCK_BY_TIMER
        text = @()  ::loc("worldwar/battle/filter/show_if_lock_by_timer")
      },
      {
        value = UNAVAILABLE_BATTLES_CATEGORIES.NOT_STARTED
        text = @()  ::loc("worldwar/battle/filter/show_not_started")
      },
    ]
    checkChangeValue = function(filterBitMasks, newFilterBitMasks, apply, cancel) {
      local filterId = "by_available_battles"
      if (!(UNAVAILABLE_BATTLES_CATEGORIES.NOT_STARTED & filterBitMasks.by_available_battles)
        && (UNAVAILABLE_BATTLES_CATEGORIES.NOT_STARTED & newFilterBitMasks))
      {
        ::scene_msg_box("showNotStarted", null,::loc("worldwar/showNotStarted/msgBox"),
          [["yes", @() apply(filterId, newFilterBitMasks) ],
            ["no", @() cancel(filterId)]],
          "no", { cancel_fn = @() cancel(filterId)})
        return false
      }
      else
        return true
    }
    getFilterMaskByObj = @(obj, valueList) obj.getValue()
  }
]

class ::gui_handlers.wwBattlesFilterMenu extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType      = handlerType.MODAL
  sceneTplName = "gui/worldWar/wwBattlesFilterMenu"
  shouldBlurSceneBg = false
  needVoiceChat = false

  rows = null
  align = "top"
  alignObj = null
  filterBitMasks = null

  onChangeValuesBitMaskCb = null

  function getSceneTplView()
  {
    initListValues()

    return {
      rows = rows
    }
  }

  function initScreen()
  {
    align = ::g_dagui_utils.setPopupMenuPosAndAlign(alignObj, align, scene.findObject("main_frame"))
    restoreFocus()
  }

  function initListValues()
  {
    rows = []
    focusArray = []
    foreach(filterCategory in battlesFilters)
    {
      if (filterCategory.multiSelectId == "by_unit_type")
        filterCategory.list = createUnitTypesFilterList(filterCategory)
      else
      {
        local bitMask = filterBitMasks?[filterCategory.multiSelectId] ?? 0
        filterCategory.value <- bitMask
        foreach (option in filterCategory.list)
          option.show <- option?.needShow?(bitMask) ?? true
      }

      if(filterCategory.list.len() <= 0)
        continue

      rows.append(filterCategory)
      focusArray.append(filterCategory.multiSelectId)
    }
  }

  function createUnitTypesFilterList(category)
  {
    local filterMasks = filterBitMasks?.by_unit_type ?? []
    local categoryMask = 0
    local list = []
    foreach(idx, unitTypeMask in category.visibleFilterByUnitTypeMasks)
    {
      local option = {}
      local isSelected = filterMasks?[unitTypeMask.tostring()] ?? true
      option.text <- ::g_string.implode(
        ::g_unit_type.getArrayBybitMask(unitTypeMask).map(@(u) u.getArmyLocName()),
        " + ")
      option.show <- option.text != ""
      categoryMask = stdMath.change_bit(categoryMask, idx, isSelected)
      list.append(option)
    }
    category.value <- categoryMask
    return list
  }

  function onChangeValue(obj)
  {
    local filterId = obj.id
    local apply = ::Callback(function(id, selBitMask)
      {
        filterBitMasks[id] <- selBitMask
        if (onChangeValuesBitMaskCb)
          onChangeValuesBitMaskCb(filterBitMasks)
      }, this)
    local cancel = ::Callback(function(id)
      {
        local multiSelectObj = scene.findObject(id)
        if (::check_obj(multiSelectObj))
          multiSelectObj.setValue(filterBitMasks[id])
      }, this)

    local filterCategory = ::u.search(battlesFilters, @(filter) filter.multiSelectId == filterId)
    local newFilterBitMasks = filterCategory.getFilterMaskByObj(obj, filterCategory?.visibleFilterByUnitTypeMasks ?? [])
    if (filterCategory?.checkChangeValue?(filterBitMasks, newFilterBitMasks, apply, cancel) ?? true)
      apply(filterId, newFilterBitMasks)
  }
}

local validateFilterMask = function(filterMask)
{
  local validFilterMask = null
  if (::u.isDataBlock(filterMask))    //  needs because it saves as boolean before
    validFilterMask = ::buildTableFromBlk(filterMask)
  else
    validFilterMask = { by_available_battles = (filterMask ?? 0).tointeger() }

  return validFilterMask
}

return {
  open = @(params = {}) ::gui_start_modal_wnd(::gui_handlers.wwBattlesFilterMenu, params)
  validateFilterMask = validateFilterMask
}