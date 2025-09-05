from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { format } = require("string")
let { rnd } = require("dagor.random")
let stdMath = require("%sqstd/math.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { get_time_msec } = require("dagor.time")
let { doesLocTextExist } = require("dagor.localize")
let { showedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { get_game_mode } = require("mission")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getUrlOrFileMissionMetaInfo } = require("%scripts/missions/missionsUtilsModule.nut")
let { isMeNewbieOnUnitType } = require("%scripts/myStats.nut")
let { currentCampaignMission } = require("%scripts/missions/missionsStates.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")
let { getRoomUnitTypesMask, getRoomRequiredUnitTypesMask } = require("%scripts/matchingRooms/sessionLobbyInfo.nut")
let { getMissionAllowedUnittypesMask } = require("%scripts/missions/missionsUtils.nut")

const GLOBAL_LOADING_TIP_BIT = 0x8000
const MISSING_TIPS_IN_A_ROW_ALLOWED = 3
const TIP_LOC_KEY_PREFIX = "loading/"
const TIP_LIFE_TIME_MSEC = 10000

let bitToTipKeys = { [GLOBAL_LOADING_TIP_BIT] = [] }
local existTipsMask = GLOBAL_LOADING_TIP_BIT
local curTip = ""
local curTipIdx = -1
local curTipUnitTypeMask = -1
local curNewbieUnitTypeMask = 0
local nextTipTime = -1
local isTipsValid = false


function getKeyFormat(typeName, isNewbie) {
  let path = typeName ? [ typeName.tolower() ] : []
  if (isNewbie)
    path.append("newbie")
  path.append("tip%d")
  return "/".join(path, true)
}


function loadTipsKeysByUnitType(unitType, isNeedOnlyNewbieTips) {
  let res = []

  let configs = []
  foreach (isNewbieTip in [ true, false ])
    configs.append({
      isNewbieTip = isNewbieTip
      keyFormat   = getKeyFormat(unitType?.name, isNewbieTip)
      isShow      = !isNeedOnlyNewbieTips || isNewbieTip
    })

  local notExistInARow = 0
  for (local idx = 0; notExistInARow <= MISSING_TIPS_IN_A_ROW_ALLOWED; idx++) { 
    local isShow = false
    local key = ""
    local tip = ""
    foreach (cfg in configs) {
      isShow = cfg.isShow
      key = format(cfg.keyFormat, idx)
      let locId = $"{TIP_LOC_KEY_PREFIX}{key}"
      tip = doesLocTextExist(locId) ? loc(locId, "") : "" 
      if (tip != "")
        break
    }

    if (tip == "") {
      notExistInARow++
      continue
    }
    notExistInARow = 0

    if (isShow && (isLoggedIn.get() || tip.indexof("{{") == null)) 
      res.append(key)
  }
  return res
}

function getNewbieUnitTypeMask() {
  local mask = 0
  foreach (unitType in unitTypes.types) {
    if (unitType == unitTypes.INVALID)
      continue
    if (isMeNewbieOnUnitType(unitType.esUnitType))
      mask = mask | unitType.bit
  }
  return mask
}

function validate() {
  if (isTipsValid)
    return

  isTipsValid = true
  bitToTipKeys.clear()
  bitToTipKeys[GLOBAL_LOADING_TIP_BIT] <- loadTipsKeysByUnitType(null, false)
  existTipsMask = GLOBAL_LOADING_TIP_BIT
  curNewbieUnitTypeMask = getNewbieUnitTypeMask()

  foreach (unitType in unitTypes.types) {
    if (unitType == unitTypes.INVALID)
      continue

    let isMeNewbie = isMeNewbieOnUnitType(unitType.esUnitType)
    local keys = loadTipsKeysByUnitType(unitType, isMeNewbie)
    if (!keys.len() && isMeNewbie)
      keys = loadTipsKeysByUnitType(unitType, false)
    if (!keys.len())
      continue

    bitToTipKeys[unitType.bit] <- keys
    existTipsMask = existTipsMask | unitType.bit
  }
}

function getDefaultUnitTypeMask() {
  if (!isLoggedIn.get() || isInMenu.get())
    return existTipsMask

  local res = 0
  let gm = get_game_mode()
  if (gm == GM_DOMINATION || gm == GM_SKIRMISH)
    res = getRoomRequiredUnitTypesMask() || getRoomUnitTypesMask()
  else if (gm == GM_TEST_FLIGHT) {
    if (showedUnit.get())
      res = showedUnit.get().unitType.bit
  }
  else if (isInArray(gm, [GM_SINGLE_MISSION, GM_CAMPAIGN, GM_DYNAMIC, GM_BUILDER, GM_DOMINATION]))
    res = unitTypes.AIRCRAFT.bit
  else 
    res = getMissionAllowedUnittypesMask(getUrlOrFileMissionMetaInfo(currentCampaignMission.get() ?? "", gm))

  return (res & existTipsMask) || existTipsMask
}

function generateNewTip(unitTypeMask = 0) {
  nextTipTime = get_time_msec() + TIP_LIFE_TIME_MSEC

  if (curNewbieUnitTypeMask && curNewbieUnitTypeMask != getNewbieUnitTypeMask())
    isTipsValid = false

  if (!isTipsValid || curTipUnitTypeMask != unitTypeMask) {
    curTipIdx = -1
    curTipUnitTypeMask = unitTypeMask
  }

  validate()

  if (!(unitTypeMask & existTipsMask))
    unitTypeMask = getDefaultUnitTypeMask()

  local totalTips = 0
  foreach (unitTypeBit, keys in bitToTipKeys)
    if (unitTypeBit & unitTypeMask)
      totalTips += keys.len()

  if (totalTips == 0) {
    curTip = ""
    curTipIdx = -1
    return
  }

  
  local newTipIdx = 0
  if (totalTips > 1) {
    let tipsToChoose = (curTipIdx >= 0) ? (totalTips - 1) : totalTips
    newTipIdx = rnd() % tipsToChoose
    if (curTipIdx >= 0 && curTipIdx <= newTipIdx)
      newTipIdx++
  }
  curTipIdx = newTipIdx

  
  local tipIdx = curTipIdx
  foreach (unitTypeBit, keys in bitToTipKeys) {
    if (!(unitTypeBit & unitTypeMask))
      continue

    if (tipIdx >= keys.len()) {
      tipIdx -= keys.len()
      continue
    }

    
    curTip = loc($"{TIP_LOC_KEY_PREFIX}{keys[tipIdx]}")

    
    if (unitTypeBit != GLOBAL_LOADING_TIP_BIT && stdMath.number_of_set_bits(unitTypeMask) > 1) {
      let icon = unitTypes.getByBit(unitTypeBit).fontIcon
      curTip = $"{colorize("fadedTextColor", icon)} {curTip}"
    }

    break
  }
}

function getTip(unitTypeMask = 0) {
  if (unitTypeMask != curTipUnitTypeMask || nextTipTime <= get_time_msec())
    generateNewTip(unitTypeMask)
  return curTip
}

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

let invalidateTips = @() isTipsValid = false

addListenersWithoutEnv({
  SignOut = @(_) invalidateTips()
  GameLocalizationChanged = @(_) invalidateTips()
  LoginComplete = @(_) invalidateTips()
  ProfileReceived = @(_) invalidateTips()
}, g_listener_priority.DEFAULT_HANDLER)

return {
  getAllTips
  getTip
}