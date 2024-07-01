from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { Cost } = require("%scripts/money.nut")
let { getBestUnitForPreview } = require("%scripts/customization/contentPreview.nut")
let { aeroSmokesList } = require("%scripts/unlocks/unlockSmoke.nut")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { select_training_mission, get_meta_mission_info_by_name } = require("guiMission")
let { getUnlockCost, getUnlockType, isUnlockOpened
} = require("%scripts/unlocks/unlocksModule.nut")
let { buyUnlock } = require("%scripts/unlocks/unlocksAction.nut")
let { set_option } = require("%scripts/options/optionsExt.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { OPTIONS_MODE_TRAINING, USEROPT_AEROBATICS_SMOKE_TYPE, USEROPT_WEAPONS,
  USEROPT_AIRCRAFT, USEROPT_CLIME, USEROPT_TIME, USEROPT_SKIN, USEROPT_DIFFICULTY,
  USEROPT_LIMITED_FUEL, USEROPT_LIMITED_AMMO, USEROPT_MODIFICATIONS, USEROPT_LOAD_FUEL_AMOUNT
} = require("%scripts/options/optionsExtNames.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { get_cur_base_gui_handler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { set_last_called_gui_testflight } = require("%scripts/missionBuilder/testFlightState.nut")
let { BaseItem } = require("%scripts/items/itemsClasses/itemsBase.nut")
let { guiStartFlight } = require("%scripts/missions/startMissionsList.nut")

function mergeToBlk(sourceTable, blk) {
  foreach (idx, val in sourceTable)
    blk[idx] = val
}

let Smoke = class (BaseItem) {
  static iType = itemType.SMOKE
  static name = "Smoke"

  needUpdateListAfterAction = true
  usingStyle = ""
  unlockType = ""
  tags = null

  constructor(blk, invBlk = null, slotData = null) {
    base.constructor(blk, invBlk, slotData)
    this.id = blk.unlockId
    this.usingStyle = this.getUsingStyle(blk)
    this.canBuy = true
    this.unlockType = getUnlockType(this.id)
    this.tags = []
    let tagsBlk = blk?.tags
    if (tagsBlk)
      for (local i = 0; i < tagsBlk.paramCount(); i++)
        if (tagsBlk.getParamValue(i))
          this.tags.append(tagsBlk.getParamName(i))
  }

  function getOptionData() {
    let option = ::get_option(USEROPT_AEROBATICS_SMOKE_TYPE)
    if (!option)
      return {}

    let unlockId = this.id
    let idx = option.unlocks.findindex(@(v) v == unlockId)

    return { option = option, currIdx = idx }
  }

  isUnlocked = @() isUnlockOpened(this.id, this.unlockType)

  isShowPrise = @() !this.isUnlocked()

  function isActive() {
    if (!this.isUnlocked())
      return false

    let data = this.getOptionData()

    return data?.currIdx && data.option.value == data.currIdx
  }

  getName = @(colored = true) // Used with type name in buy dialog message only
    $"{loc("itemTypes/aerobatic_smoke")} {base.getName(colored)}"

  getDescriptionTitle = @() base.getName()

  getIcon = @(_addItemName = true)
    LayersIcon.getIconData(this.usingStyle, this.defaultIcon, 1.0, this.defaultIconStyle)

  getBigIcon = @() LayersIcon.getIconData($"{this.usingStyle}_big", this.defaultIcon, 1.0, this.defaultIconStyle)

  getMainActionData = @(isShort = false, _params = {}) this.isActive() ? null : {
      btnName = this.isUnlocked() ? loc("item/consume") : this.getBuyText(false, isShort)
    }

  getDescription = @() this.getTagsDesc()

  isAllowedByUnitTypes = @(tag) tag == "air"
  isAvailable = @(unit, checkUnitUsable = true) !!unit
    && unit.isAir() && ::isTestFlightAvailable(unit) && (!checkUnitUsable || unit.isUsable())

  canPreview = @() true

  function doPreview() {
    let unit = getBestUnitForPreview(this.isAllowedByUnitTypes, this.isAvailable)
    if (!unit)
      return

    let currUnit = getPlayerCurUnit()
    if (unit.name == currUnit?.name) {
      this.openTestFlight(unit)
      return
    }

    let item = this
    scene_msg_box("offer_unit_change", null, loc("decoratorPreview/autoselectedUnit", {
        previewUnit = colorize("activeTextColor", getUnitName(unit))
        hangarUnit = colorize("activeTextColor", getUnitName(currUnit))
      }),
      [
        ["yes", @() item.openTestFlight(unit)],
        ["no", @() null ]
      ], "yes", { cancel_fn = function() {} })

  }

  function openTestFlight(unit) {
    let curItem = this
    set_last_called_gui_testflight({ eventbusName = "gui_start_itemsShop",
      params = { curTab = -1, itemId = curItem.id } })
    ::update_test_flight_unit_info({unit})
    ::cur_aircraft_name = unit.name
    let defaultValues = {
      [USEROPT_WEAPONS] = "",
      [USEROPT_AIRCRAFT] = unit.name,
      [USEROPT_CLIME] = "clear",
      [USEROPT_TIME] = "Day",
      [USEROPT_SKIN] = "default",
      [USEROPT_DIFFICULTY] = "arcade",
      [USEROPT_LIMITED_FUEL] = "no",
      [USEROPT_LIMITED_AMMO] = "no",
      [USEROPT_MODIFICATIONS] = "yes",
      [USEROPT_LOAD_FUEL_AMOUNT] = "300000"
    }

    foreach (idx, val in defaultValues)
      ::set_gui_option_in_mode(idx, val, OPTIONS_MODE_TRAINING)

    let misName = "aerobatic_smoke_preview"
    let misInfo = get_meta_mission_info_by_name(misName)
    if (!misInfo)
      return script_net_assert_once("Wrong testflight mission",
        "ItemSmoke: No meta info for aerobatic_smoke_preview")

    let unlockId = this.id
    let smokeId = aeroSmokesList.value.findvalue(@(p) p.unlockId == unlockId)?.id
    if (!smokeId)
      return script_net_assert_once("Wrong smoke option value",
        "ItemSmoke: No option has such index")

    mergeToBlk({
      isPersistentSmoke = true
      persistentSmokeId = smokeId
    }, misInfo)

    select_training_mission(misInfo)
    ::queues.checkAndStart(@() get_cur_base_gui_handler().goForward(guiStartFlight),
      null, "isCanNewflight")
  }

  function getCost(ignoreCanBuy = false) {
    return (this.isCanBuy() || ignoreCanBuy) && !this.isUnlocked()
      ? getUnlockCost(this.id).multiply(this.getSellAmount())
      : Cost()
  }

  function getUsingStyle(blk) {
    local pref = []
    foreach (pos in ["rightwing", "leftwing", "tail"])
      if (blk?[pos] != "")
        pref.append(pos)
  pref = ["aerobatic_smoke", blk.rarity].extend(pref.len() < 3 ? pref : ["triple"])
    return "_".join(pref, true)
  }

  function setCurrOption() {
    let data = this.getOptionData()
    let idx = data?.currIdx
    if (!idx)
      return

    set_option(data.option.type, idx, data.option)
  }

  function consumeSmoke(cb) {
    this.setCurrOption()
    if (cb)
      cb(true)
  }

  function doMainAction(cb, handler, params = null) {
    return this.isUnlocked()
      ? this.consumeSmoke(cb)
      : this.buy(cb, handler, params)
  }

  function _buy(cb, _params = null) {
    buyUnlock(this.id, Callback(@() cb(true), this))
  }

  function getTagsDesc() {
    if (this.tags.len() == 0)
      return ""

    let tagsLoc = this.tags.map(@(t) colorize("activeTextColor", loc($"content/tag/{t}")))
    return $"{loc("ugm/tags")}{loc("ui/colon")}{loc("ui/comma").join(tagsLoc)}"
  }
}
return {Smoke}