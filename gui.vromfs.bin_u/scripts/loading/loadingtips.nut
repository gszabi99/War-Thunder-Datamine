//-file:plus-string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
let { rnd } = require("dagor.random")
let stdMath = require("%sqstd/math.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { get_time_msec } = require("dagor.time")
let { doesLocTextExist } = require("dagor.localize")
let { showedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { get_game_mode } = require("mission")

const GLOBAL_LOADING_TIP_BIT = 0x8000
const MISSING_TIPS_IN_A_ROW_ALLOWED = 3
const TIP_LOC_KEY_PREFIX = "loading/"
const TIP_LIFE_TIME_MSEC = 10000

::g_script_reloader.loadOnce("%scripts/loading/bhvLoadingTip.nut")

//for global tips typeName = null
let function getKeyFormat(typeName, isNewbie) {
  let path = typeName ? [ typeName.tolower() ] : []
  if (isNewbie)
    path.append("newbie")
  path.append("tip%d")
  return ::g_string.implode(path, "/")
}

//for global tips unitType = null
let function loadTipsKeysByUnitType(unitType, isNeedOnlyNewbieTips) {
  let res = []

  let configs = []
  foreach (isNewbieTip in [ true, false ])
    configs.append({
      isNewbieTip = isNewbieTip
      keyFormat   = getKeyFormat(unitType?.name, isNewbieTip)
      isShow      = !isNeedOnlyNewbieTips || isNewbieTip
    })

  local notExistInARow = 0
  for (local idx = 0; notExistInARow <= MISSING_TIPS_IN_A_ROW_ALLOWED; idx++) { // warning disable: -mismatch-loop-variable
    local isShow = false
    local key = ""
    local tip = ""
    foreach (cfg in configs) {
      isShow = cfg.isShow
      key = format(cfg.keyFormat, idx)
      let locId = $"{TIP_LOC_KEY_PREFIX}{key}"
      tip = doesLocTextExist(locId) ? loc(locId, "") : "" // Using doesLocTextExist() to avoid warnings spam in log.
      if (tip != "")
        break
    }

    if (tip == "") {
      notExistInARow++
      continue
    }
    notExistInARow = 0

    if (isShow && (::g_login.isLoggedIn() || tip.indexof("{{") == null)) // Not show tip with shortcuts while not profile recived
      res.append(key)
  }
  return res
}


let function isMeNewbieOnUnitType(esUnitType) {
  return ("my_stats" in getroottable()) && ::my_stats.isMeNewbieOnUnitType(esUnitType)
}


let function getNewbieUnitTypeMask() {
  local mask = 0
  foreach (unitType in unitTypes.types) {
    if (unitType == unitTypes.INVALID)
      continue
    if (isMeNewbieOnUnitType(unitType.esUnitType))
      mask = mask | unitType.bit
  }
  return mask
}



::g_tips <- {

  tipsKeys = { [GLOBAL_LOADING_TIP_BIT] = [] }
  existTipsMask = GLOBAL_LOADING_TIP_BIT

  curTip = ""
  curTipIdx = -1
  curTipUnitTypeMask = -1
  curNewbieUnitTypeMask = 0
  nextTipTime = -1

  isTipsValid = false

  function getAllTips() {
    let tipsKeysByUnitType = {}
    tipsKeysByUnitType[GLOBAL_LOADING_TIP_BIT] <- loadTipsKeysByUnitType(null, false)

    foreach (unitType in unitTypes.types) {
      if (unitType == unitTypes.INVALID)
        continue
      let keys = loadTipsKeysByUnitType(unitType, false)
      if (!keys.len())
        continue
      tipsKeysByUnitType[unitType.bit] <- keys
    }

    let tipsArray = []
    foreach (unitTypeBit, keys in tipsKeysByUnitType) {
      tipsArray.extend(keys.map(function(tipKey) {
        local tip = loc($"{TIP_LOC_KEY_PREFIX}{tipKey}")
        if (unitTypeBit != GLOBAL_LOADING_TIP_BIT) {
          let icon = unitTypes.getByBit(unitTypeBit).fontIcon
          tip = $"{colorize("fadedTextColor", icon)} {tip}"
        }
        return tip
      }))
    }

    return tipsArray
  }

  function onEventProfileReceived(_p) { this.isTipsValid = false }
}

::g_tips.getTip <- function getTip(unitTypeMask = 0) {
  if (unitTypeMask != this.curTipUnitTypeMask || this.nextTipTime <= get_time_msec())
    this.genNewTip(unitTypeMask)
  return this.curTip
}

::g_tips.resetTipTimer <- function resetTipTimer() {
  this.nextTipTime = -1
}

::g_tips.validate <- function validate() {
  if (this.isTipsValid)
    return
  this.isTipsValid = true

  this.tipsKeys.clear()
  this.tipsKeys[GLOBAL_LOADING_TIP_BIT] <- loadTipsKeysByUnitType(null, false)
  this.existTipsMask = GLOBAL_LOADING_TIP_BIT
  this.curNewbieUnitTypeMask = getNewbieUnitTypeMask()

  foreach (unitType in unitTypes.types) {
    if (unitType == unitTypes.INVALID)
      continue
    let isMeNewbie = isMeNewbieOnUnitType(unitType.esUnitType)
    local keys = loadTipsKeysByUnitType(unitType, isMeNewbie)
    if (!keys.len() && isMeNewbie)
      keys = loadTipsKeysByUnitType(unitType, false)
    if (!keys.len())
      continue
    this.tipsKeys[unitType.bit] <- keys
    this.existTipsMask = this.existTipsMask | unitType.bit
  }
}


::g_tips.getDefaultUnitTypeMask <- function getDefaultUnitTypeMask() {
  if (!::g_login.isLoggedIn() || ::isInMenu())
    return this.existTipsMask

  local res = 0
  let gm = get_game_mode()
  if (gm == GM_DOMINATION || gm == GM_SKIRMISH)
    res = ::SessionLobby.getRequiredUnitTypesMask() || ::SessionLobby.getUnitTypesMask()
  else if (gm == GM_TEST_FLIGHT) {
    if (showedUnit.value)
      res = showedUnit.value.unitType.bit
  }
  else if (isInArray(gm, [GM_SINGLE_MISSION, GM_CAMPAIGN, GM_DYNAMIC, GM_BUILDER, GM_DOMINATION]))
    res = unitTypes.AIRCRAFT.bit
  else // keep this check last
    res = ::get_mission_allowed_unittypes_mask(::get_mission_meta_info(::current_campaign_mission || ""))

  return (res & this.existTipsMask) || this.existTipsMask
}

::g_tips.genNewTip <- function genNewTip(unitTypeMask = 0) {
  this.nextTipTime = get_time_msec() + TIP_LIFE_TIME_MSEC

  if (this.curNewbieUnitTypeMask && this.curNewbieUnitTypeMask != getNewbieUnitTypeMask())
    this.isTipsValid = false

  if (!this.isTipsValid || this.curTipUnitTypeMask != unitTypeMask) {
    this.curTipIdx = -1
    this.curTipUnitTypeMask = unitTypeMask
  }

  this.validate()

  if (!(unitTypeMask & this.existTipsMask))
    unitTypeMask = this.getDefaultUnitTypeMask()

  local totalTips = 0
  foreach (unitTypeBit, keys in this.tipsKeys)
    if (unitTypeBit & unitTypeMask)
      totalTips += keys.len()
  if (totalTips == 0) {
    this.curTip = ""
    this.curTipIdx = -1
    return
  }

  //choose new tip
  local newTipIdx = 0
  if (totalTips > 1) {
    local tipsToChoose = totalTips
    if (this.curTipIdx >= 0)
      tipsToChoose--
    newTipIdx = rnd() % tipsToChoose
    if (this.curTipIdx >= 0 && this.curTipIdx <= newTipIdx)
      newTipIdx++
  }
  this.curTipIdx = newTipIdx

  //get lang for chosen tip
  local tipIdx = this.curTipIdx
  foreach (unitTypeBit, keys in this.tipsKeys) {
    if (!(unitTypeBit & unitTypeMask))
      continue
    if (tipIdx >= keys.len()) {
      tipIdx -= keys.len()
      continue
    }

    //found tip
    this.curTip = loc(TIP_LOC_KEY_PREFIX + keys[tipIdx])

    //add unit type icon if needed
    if (unitTypeBit != GLOBAL_LOADING_TIP_BIT && stdMath.number_of_set_bits(unitTypeMask) > 1) {
      let icon = unitTypes.getByBit(unitTypeBit).fontIcon
      this.curTip = colorize("fadedTextColor", icon) + " " + this.curTip
    }

    break
  }
}

::g_tips.onEventLoginComplete <- function onEventLoginComplete(_p) { this.isTipsValid = false }
::g_tips.onEventGameLocalizationChanged <- function onEventGameLocalizationChanged(_p) { this.isTipsValid = false }
::g_tips.onEventSignOut <- function onEventSignOut(_p) { this.isTipsValid = false }

::subscribe_handler(::g_tips, ::g_listener_priority.DEFAULT_HANDLER)