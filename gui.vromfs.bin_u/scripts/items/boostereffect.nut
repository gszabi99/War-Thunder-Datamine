from "%scripts/dagui_natives.nut" import get_current_booster_uid, get_current_booster_count
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType
from "%scripts/invalid_user_id.nut" import INVALID_USER_ID

let { calc_personal_boost, calc_public_boost } = require("%appGlobals/ranks_common_shared.nut")
let { registerBoosterUpdateTimer } = require("%scripts/items/boosterActions.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { havePremium } = require("%scripts/user/premium.nut")
let { get_warpoints_blk, get_ranks_blk } = require("blkGetters")
let { measureType } = require("%scripts/measureType.nut")
let { getCyberCafeBonusByEffectType, getSquadBonusForSameCyberCafe
} = require("%scripts/items/bonusEffectsGetters.nut")
let { format } = require("string")
let { getFullUnlockCondsDescInline } = require("%scripts/unlocks/unlocksViewModule.nut")
let { boosterEffectType } = require("%scripts/items/boosterEffectTypes.nut")
let { getInventoryList, findItemByUid } = require("%scripts/items/itemsManagerModule.nut")

function getActiveBoostersArray(effectType = null) {
  let res = []
  let total = get_current_booster_count(INVALID_USER_ID)
  let bonusType = effectType ? effectType.name : null
  for (local i = 0; i < total; i++) {
    let uid = get_current_booster_uid(INVALID_USER_ID, i)
    let item = findItemByUid(uid, itemType.BOOSTER)
    if (!item || (bonusType && item[bonusType] == 0) || !item.isActive(true))
      continue

    res.append(item)
  }

  if (res.len())
    registerBoosterUpdateTimer(res)

  return res
}

function sortByParam(arr, param) {
  let sortByBonus =  function(a, b) {
    if (a[param] != b[param])
      return a[param] > b[param] ? -1 : 1
    return 0
  }

  arr.sort(sortByBonus)
  return arr
}













function sortBoosters(boosters, effectType) {
  let res = {
    maxSortOrder = 0
  }
  foreach (booster in boosters) {
    res.maxSortOrder = max(getTblValue("maxSortOrder", res, 0), booster.sortOrder)
    if (!getTblValue(booster.sortOrder, res))
      res[booster.sortOrder] <- {
        personal = [],
        public = [],
      }

    if (booster.personal)
      res[booster.sortOrder].personal.append(booster)
    else
      res[booster.sortOrder].public.append(booster)
  }

  for (local i = 0; i <= res.maxSortOrder; i++)
    if (i in res && res[i].len())
      foreach (arr in res[i])
        sortByParam(arr, effectType.name)
  return res
}

function getBoostersEffectsArray(itemsArray, effectType) {
  let res = []
  foreach (item in itemsArray)
    res.append(item[effectType.name])
  return res
}







function getBoostersEffects(boosters) {
  let result = {}
  foreach (effectType in boosterEffectType) {
    result[effectType.name] <- 0
    let sortedBoosters = sortBoosters(boosters, effectType)
    for (local i = 0; i <= sortedBoosters.maxSortOrder; i++) {
      if (!(i in sortedBoosters))
        continue
      result[effectType.name] +=
        calc_public_boost(getBoostersEffectsArray(sortedBoosters[i].public, effectType))
        + calc_personal_boost(getBoostersEffectsArray(sortedBoosters[i].personal, effectType))
    }
  }
  return result
}

function hasActiveBoosters(effectType, personal) {
  let items = getInventoryList(itemType.BOOSTER,
    @(item) item.isActive(true) && effectType.checkBooster(item)
        && item.personal == personal)
  return items.len() != 0
}

function haveActiveBonusesByEffectType(effectType, personal = false) {
  return hasActiveBoosters(effectType, personal)
    || (personal
        && (getCyberCafeBonusByEffectType(effectType) > 0.0
            || getSquadBonusForSameCyberCafe(effectType)))
}

function getActiveBoostersDescription(boostersArray, effectType, selectedItem = null, plainText = false) {
  if (!boostersArray || boostersArray.len() == 0)
    return ""

  let getColoredNumByType =  function(num) {
    let value = plainText ? $"+{num.tointeger()}%" : colorize("activeTextColor", $"+{num.tointeger()}%")
    let currency = effectType.getCurrencyMark(plainText)
    return "".concat(value, currency)
  }

  let separateBoosters = []

  let itemsArray = []
  foreach (booster in boostersArray) {
    if (booster.showBoosterInSeparateList)
      separateBoosters.append($"{booster.getName()}{loc("ui/colon")}{booster.getEffectDesc(true, effectType, plainText)}")
    else
      itemsArray.append(booster)
  }
  if (separateBoosters.len())
    separateBoosters.append("\n")

  let sortedItemsTable = sortBoosters(itemsArray, effectType)
  let detailedDescription = []
  for (local i = 0; i <= sortedItemsTable.maxSortOrder; i++) {
    let arraysList = getTblValue(i, sortedItemsTable)
    if (!arraysList || arraysList.len() == 0)
      continue

    let personalTotal = arraysList.personal.len() == 0
      ? 0
      : calc_personal_boost(getBoostersEffectsArray(arraysList.personal, effectType))

    let publicTotal = arraysList.public.len() == 0
      ? 0
      : calc_public_boost(getBoostersEffectsArray(arraysList.public, effectType))

    let isBothBoosterTypesAvailable = personalTotal != 0 && publicTotal != 0

    local header = ""
    let detailedArray = []
    local insertedSubHeader = false

    foreach (_j, arrayName in ["personal", "public"]) {
      let arr = arraysList[arrayName]
      if (arr.len() == 0)
        continue

      let personal = arr[0].personal
      let boostNum = personal ? personalTotal : publicTotal

      header = arr[0].eventConditions
        ? getFullUnlockCondsDescInline(arr[0].eventConditions)
        : loc("mainmenu/boosterType/common")

      local subHeader = "".concat("* ", loc($"mainmenu/booster/{arrayName}"))
      if (isBothBoosterTypesAvailable)
        subHeader = loc("ui/colon").concat(subHeader, getColoredNumByType(boostNum))


      detailedArray.append(subHeader)

      let effectsArray = []
      foreach (idx, item in arr) {
        let effOld = personal ? calc_personal_boost(effectsArray) : calc_public_boost(effectsArray)
        effectsArray.append(item[effectType.name])
        let effNew = personal ? calc_personal_boost(effectsArray) : calc_public_boost(effectsArray)

        local string = arr.len() == 1 ? "" : $"{idx+1}) "
        string = $"{string}{item.getEffectDesc(false, null, plainText)}{loc("ui/comma")}"
        string = $"{string}{loc("items/booster/giveRealBonus", {realBonus = getColoredNumByType(format("%.02f", effNew - effOld).tofloat())})}"
        string = $"{string}{idx == arr.len()-1 ? loc("ui/dot") : loc("ui/semicolon")}"

        if (selectedItem != null && selectedItem.id == item.id)
          string = colorize("userlogColoredText", string)

        detailedArray.append(string)
      }

      if (!insertedSubHeader) {
        let totalBonus = publicTotal + personalTotal
        header = $"{header}{loc("ui/colon")}{getColoredNumByType(totalBonus)}"
        detailedArray.insert(0, header)
        insertedSubHeader = true
      }
    }
    detailedDescription.append("\n".join(detailedArray, true))
  }

  let description = $"{loc("mainmenu/boostersTooltip", { currencyMark = effectType.getCurrencyMark(plainText) })}{loc("ui/colon")}\n"
  return $"{description}{"\n".join(separateBoosters, true)}{"\n\n".join(detailedDescription, true)}"
}

function getCurrentBonusesText(effectType) {
  let tooltipText = []

  if (havePremium.get()) {
    local rate = ""
    if (effectType == boosterEffectType.WP) {
      let blk = get_warpoints_blk()
      rate = "".concat("+", measureType.PERCENT_FLOAT.getMeasureUnitsText((blk?.wpMultiplier ?? 1.0) - 1.0))
      rate = $"{colorize("activeTextColor", rate)}{loc("warpoints/short/colored")}"
    }
    else if (effectType == boosterEffectType.RP) {
      let blk = get_ranks_blk()
      rate = "".concat("+", measureType.PERCENT_FLOAT.getMeasureUnitsText((blk?.xpMultiplier ?? 1.0) - 1.0))
      rate = $"{colorize("activeTextColor", rate)}{loc("currency/researchPoints/sign/colored")}"
    }
    tooltipText.append("".concat(loc("mainmenu/activePremium"), loc("ui/colon"), rate))
  }

  local value = getCyberCafeBonusByEffectType(effectType)
  if (value > 0.0) {
    value = measureType.PERCENT_FLOAT.getMeasureUnitsText(value)
    value = effectType.getText(colorize("activeTextColor", value), true)
    tooltipText.append("".concat(loc("mainmenu/bonusCyberCafe"), loc("ui/colon"), value))
  }

  value = getSquadBonusForSameCyberCafe(effectType)
  if (value > 0.0) {
    value = measureType.PERCENT_FLOAT.getMeasureUnitsText(value)
    value = effectType.getText(colorize("activeTextColor", value), true)
    tooltipText.append(loc("item/FakeBoosterForNetCafeLevel/squad", { num = loc("ui/colon").concat(g_squad_manager.getSameCyberCafeMembersNum(), value) }))
  }

  let boostersArray = getActiveBoostersArray(effectType)
  let boostersDescription = getActiveBoostersDescription(boostersArray, effectType)
  if (boostersDescription != "")
    tooltipText.append("".concat((havePremium.get() ? "\n" : ""), boostersDescription))

  local bonusText = "\n".join(tooltipText, true)
  if (bonusText != "")
    bonusText = $"\n<b>{loc("mainmenu/bonusTitle")}{loc("ui/colon")}</b>\n{bonusText}"

  return bonusText
}

return {
  boosterEffectType
  sortBoosters
  getBoostersEffects
  getBoostersEffectsArray
  getActiveBoostersArray
  haveActiveBonusesByEffectType
  getCurrentBonusesText
  getActiveBoostersDescription
}
