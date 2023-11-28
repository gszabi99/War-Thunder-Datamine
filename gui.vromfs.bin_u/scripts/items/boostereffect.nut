from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let { Cost } = require("%scripts/money.nut")

let boosterEffectType = {
  RP = {
    name = "xpRate"
    currencyMark = loc("currency/researchPoints/sign/colored")
    currencyText = "money/rpText"
    abbreviation = "xp"
    checkBooster = @(booster) this.getValue(booster) != 0
    getValue = @(booster) booster?.xpRate ?? 0
    getText = function(value, colored = false, showEmpty = true) {
      if (value == 0 && !showEmpty)
        return ""
      return Cost().setRp(value).toStringWithParams({ isColored = colored })
    }
    getCurrencyMark = @(plainText = false) plainText ? loc(this.currencyText) : this.currencyMark
  }
  WP = {
    name = "wpRate"
    currencyMark = loc("warpoints/short/colored")
    currencyText = "money/wpText"
    abbreviation = "wp"
    checkBooster = @(booster) this.getValue(booster) != 0
    getValue = @(booster) booster?.wpRate ?? 0
    getText = function(value, colored = false, showEmpty = true) {
      if (value == 0 && !showEmpty)
        return ""
      return Cost(value).toStringWithParams({ isWpAlwaysShown = true, isColored = colored })
    }
    getCurrencyMark = @(plainText = false) plainText ? loc(this.currencyText) : this.currencyMark
  }
}

let function getActiveBoostersArray(effectType = null) {
  let res = []
  let total = ::get_current_booster_count(::INVALID_USER_ID)
  let bonusType = effectType ? effectType.name : null
  for (local i = 0; i < total; i++) {
    let uid = ::get_current_booster_uid(::INVALID_USER_ID, i)
    let item = ::ItemsManager.findItemByUid(uid, itemType.BOOSTER)
    if (!item || (bonusType && item[bonusType] == 0) || !item.isActive(true))
      continue

    res.append(item)
  }

  if (res.len())
    ::ItemsManager.registerBoosterUpdateTimer(res)

  return res
}

let function sortByParam(arr, param) {
  let sortByBonus =  function(a, b) {
    if (a[param] != b[param])
      return a[param] > b[param] ? -1 : 1
    return 0
  }

  arr.sort(sortByBonus)
  return arr
}

/**
 * Returns structure table of boosters.
 * This structure looks like this:
 * {
 *   <sort_order> = {
 *     publick = [array of public boosters]
 *     personal = [array of personal boosters]
 *   }
 *  maxSortOrder = <maximum sort_order>
 * }
 * Public and personal arrays of boosters sorted by effect type
 */
let function sortBoosters(boosters, effectType) {
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

let function getBoostersEffectsArray(itemsArray, effectType) {
  let res = []
  foreach (item in itemsArray)
    res.append(item[effectType.name])
  return res
}

/**
 * Summs effects of passed boosters and returns table in format:
 * {
 *   <boosterEffectType.name> = <value in percent>
 * }
 */
let function getBoostersEffects(boosters) {
  let result = {}
  foreach (effectType in boosterEffectType) {
    result[effectType.name] <- 0
    let sortedBoosters = sortBoosters(boosters, effectType)
    for (local i = 0; i <= sortedBoosters.maxSortOrder; i++) {
      if (!(i in sortedBoosters))
        continue
      result[effectType.name] +=
        ::calc_public_boost(getBoostersEffectsArray(sortedBoosters[i].public, effectType))
        + ::calc_personal_boost(getBoostersEffectsArray(sortedBoosters[i].personal, effectType))
    }
  }
  return result
}

let function hasActiveBoosters(effectType, personal) {
  let items = ::ItemsManager.getInventoryList(itemType.BOOSTER,
    @(item) item.isActive(true) && effectType.checkBooster(item)
        && item.personal == personal)
  return items.len() != 0
}

let function haveActiveBonusesByEffectType(effectType, personal = false) {
  return hasActiveBoosters(effectType, personal)
    || (personal
        && (::get_cyber_cafe_bonus_by_effect_type(effectType) > 0.0
            || ::get_squad_bonus_for_same_cyber_cafe(effectType)))
}

return {
  boosterEffectType             = boosterEffectType
  sortBoosters                  = sortBoosters
  getBoostersEffects            = getBoostersEffects
  getBoostersEffectsArray       = getBoostersEffectsArray
  getActiveBoostersArray        = getActiveBoostersArray
  haveActiveBonusesByEffectType = haveActiveBonusesByEffectType
}
