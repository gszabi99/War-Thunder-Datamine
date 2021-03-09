local { getBestUnitForPreview } = require("scripts/customization/contentPreview.nut")
local { aeroSmokesList } = require("scripts/unlocks/unlockSmoke.nut")

class ::items_classes.Smoke extends ::BaseItem
{
  static iType = itemType.SMOKE

  needUpdateListAfterAction = true
  usingStyle = ""
  unlockType = ""
  tags = null

  constructor(blk, invBlk = null, slotData = null)
  {
    base.constructor(blk, invBlk, slotData)
    id = blk.unlockId
    usingStyle = getUsingStyle(blk)
    canBuy = true
    unlockType = ::get_unlock_type_by_id(id)
    tags = []
    local tagsBlk = blk?.tags
    if (tagsBlk)
      for (local i=0; i < tagsBlk.paramCount(); i++)
        if (tagsBlk.getParamValue(i))
          tags.append(tagsBlk.getParamName(i))
  }

  function getOptionData()
  {
    local option = ::get_option(::USEROPT_AEROBATICS_SMOKE_TYPE)
    if (!option)
      return {}

    local unlockId = id
    local idx = option.unlocks.findindex(@(v) v == unlockId)

    return {option = option, currIdx = idx}
  }

  isUnlocked = @() ::is_unlocked_scripted(unlockType, id)

  isShowPrise = @() !isUnlocked()

  function isActive()
  {
    if (!isUnlocked())
      return false

    local data = getOptionData()

    return data?.currIdx && data.option.value == data.currIdx
  }

  getName = @(colored = true)// Used with type name in buy dialog message only
    $"{::loc("itemTypes/aerobatic_smoke")} {base.getName(colored)}"

  getDescriptionTitle = @() base.getName()

  getIcon = @(addItemName = true)
    ::LayersIcon.getIconData(usingStyle, defaultIcon, 1.0, defaultIconStyle)

  getBigIcon = @() ::LayersIcon.getIconData($"{usingStyle}_big", defaultIcon, 1.0, defaultIconStyle)

  getMainActionData = @(isShort = false, params = {}) isActive() ? null : {
      btnName = isUnlocked() ? ::loc("item/consume") : getBuyText(false, isShort)
    }

  getDescription = @() getTagsDesc()

  isAllowedByUnitTypes = @(tag) tag == "air"
  isAvailable = @(unit, checkUnitUsable = true) !!unit
    && unit.isAir() && ::isTestFlightAvailable(unit) && (!checkUnitUsable || unit.isUsable())

  canPreview = @() true

  function doPreview()
  {
    local unit = getBestUnitForPreview(isAllowedByUnitTypes, isAvailable)
    if (!unit)
      return

    local currUnit = ::get_player_cur_unit()
    if (unit.name == currUnit?.name)
    {
      openTestFlight(unit)
      return
    }

    local item = this
    ::scene_msg_box("offer_unit_change", null, ::loc("decoratorPreview/autoselectedUnit", {
        previewUnit = ::colorize("activeTextColor", ::getUnitName(unit))
        hangarUnit = ::colorize("activeTextColor", ::getUnitName(currUnit))
      }),
      [
        ["yes", @() item.openTestFlight(unit)],
        ["no", @() null ]
      ], "yes", { cancel_fn = function() {} })

  }

  function openTestFlight(unit)
  {
    local curItem = this
    ::last_called_gui_testflight = @() ::gui_start_itemsShop({curTab = -1, curItem})
    ::test_flight_aircraft <- unit
    ::cur_aircraft_name = unit.name
    local defaultValues = {
      [::USEROPT_WEAPONS] = "",
      [::USEROPT_AIRCRAFT] = unit.name,
      [::USEROPT_WEATHER] = "clear",
      [::USEROPT_TIME] = "Day",
      [::USEROPT_SKIN] = "default",
      [::USEROPT_DIFFICULTY] = "arcade",
      [::USEROPT_LIMITED_FUEL] = "no",
      [::USEROPT_LIMITED_AMMO] = "no",
      [::USEROPT_MODIFICATIONS] = "yes",
      [::USEROPT_LOAD_FUEL_AMOUNT] = "300000"
    }

    foreach (idx, val in defaultValues)
      ::set_gui_option_in_mode(idx, val, ::OPTIONS_MODE_TRAINING)

    local misName = "aerobatic_smoke_preview"
    local misInfo = ::get_mission_meta_info(misName)
    if (!misInfo)
      return ::script_net_assert_once("Wrong testflight mission",
        "ItemSmoke: No meta info for aerobatic_smoke_preview")

    local unlockId = id
    local smokeId = aeroSmokesList.value.findvalue(@(p) p.unlockId == unlockId)?.id
    if (!smokeId)
      return ::script_net_assert_once("Wrong smoke option value",
        "ItemSmoke: No option has such index")

    ::mergeToBlk({
      isPersistentSmoke = true
      persistentSmokeId = smokeId
    }, misInfo)

    ::select_training_mission(misInfo)
    ::queues.checkAndStart(@() ::get_cur_base_gui_handler().goForward(::gui_start_flight),
      null, "isCanNewflight")
  }

  function getCost(ignoreCanBuy = false)
  {
    return (isCanBuy() || ignoreCanBuy) && !isUnlocked()
      ? ::get_unlock_cost(id).multiply(getSellAmount())
      : ::Cost()
  }

  function getUsingStyle(blk)
  {
    local pref = []
    foreach (pos in ["rightwing", "leftwing", "tail"])
      if (blk?[pos] != "")
        pref.append(pos)
  pref = ["aerobatic_smoke", blk.rarity].extend(pref.len() < 3 ? pref : ["triple"])
    return ::g_string.implode(pref, "_")
  }

  function setCurrOption()
  {
    local data = getOptionData()
    local idx = data?.currIdx
    if (!idx)
      return

    ::set_option (data.option.type, idx, data.option)
  }

  function consumeSmoke(cb)
  {
    setCurrOption()
    if (cb)
      cb(true)
  }

  function doMainAction(cb, handler, params = null)
  {
    return isUnlocked()
      ? consumeSmoke(cb)
      : buy(cb, handler, params)
  }

  function _buy(cb, params = null)
  {
    ::g_unlocks.buyUnlock(id, ::Callback(@() cb(true), this))
  }

  function getTagsDesc()
  {
    if (tags.len() == 0)
      return ""

    local tagsLoc = tags.map(@(t) ::colorize("activeTextColor", ::loc($"content/tag/{t}")))
    return $"{::loc("ugm/tags")}{::loc("ui/colon")}{::loc("ui/comma").join(tagsLoc)}"
  }
}
