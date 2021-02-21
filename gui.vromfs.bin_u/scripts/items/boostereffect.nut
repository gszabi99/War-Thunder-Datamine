local boosterEffectType = {
  RP = {
    name = "xpRate"
    currencyMark = ::loc("currency/researchPoints/sign/colored")
    abbreviation = "xp"
    checkBooster = function(booster)
    {
      return ::getTblValue("xpRate", booster, 0) != 0
    }
    getValue = function(booster)
    {
      return ::getTblValue("xpRate", booster, 0)
    }
    getText = function(value, colored = false, showEmpty = true)
    {
      if (value == 0 && !showEmpty)
        return ""
      return ::Cost().setRp(value).toStringWithParams({isColored = colored})
    }
  }
  WP = {
    name = "wpRate"
    currencyMark = ::loc("warpoints/short/colored")
    abbreviation = "wp"
    checkBooster = function(booster)
    {
      return ::getTblValue("wpRate", booster, 0) != 0
    }
    getValue = function(booster)
    {
      return ::getTblValue("wpRate", booster, 0)
    }
    getText = function(value, colored = false, showEmpty = true)
    {
      if (value == 0 && !showEmpty)
        return ""
      return ::Cost(value).toStringWithParams({isWpAlwaysShown = true, isColored = colored})
    }
  }
}

local function getActiveBoostersArray(effectType = null)
{
  local res = []
  local total = ::get_current_booster_count(::INVALID_USER_ID)
  local bonusType = effectType ? effectType.name : null
  for (local i = 0; i < total; i++)
  {
    local uid = ::get_current_booster_uid(::INVALID_USER_ID, i)
    local item = ::ItemsManager.findItemByUid(uid, itemType.BOOSTER)
    if (!item || (bonusType && item[bonusType] == 0) || !item.isActive(true))
      continue

    res.append(item)
  }

  if (res.len())
    ::ItemsManager.registerBoosterUpdateTimer(res)

  return res
}

local function sortByParam(arr, param)
{
  local sortByBonus = (@(param) function(a, b) {
    if (a[param] != b[param])
      return a[param] > b[param]? -1 : 1
    return 0
  })(param)

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
local function sortBoosters(boosters, effectType)
{
  local res = {
    maxSortOrder = 0
  }
  foreach(booster in boosters)
  {
    res.maxSortOrder = ::max(::getTblValue("maxSortOrder", res, 0), booster.sortOrder)
    if (!::getTblValue(booster.sortOrder, res))
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

local function getBoostersEffectsArray(itemsArray, effectType)
{
  local res = []
  foreach(item in itemsArray)
    res.append(item[effectType.name])
  return res
}

/**
 * Summs effects of passed boosters and returns table in format:
 * {
 *   <boosterEffectType.name> = <value in percent>
 * }
 */
local function getBoostersEffects(boosters)
{
  local result = {}
  foreach (effectType in boosterEffectType)
  {
    result[effectType.name] <- 0
    local sortedBoosters = sortBoosters(boosters, effectType)
    for (local i = 0; i <= sortedBoosters.maxSortOrder; i++)
    {
      if (!(i in sortedBoosters))
        continue
      result[effectType.name] +=
        ::calc_public_boost(getBoostersEffectsArray(sortedBoosters[i].public, effectType))
        + ::calc_personal_boost(getBoostersEffectsArray(sortedBoosters[i].personal, effectType))
    }
  }
  return result
}

local function hasActiveBoosters(effectType, personal)
{
  local items = ::ItemsManager.getInventoryList(itemType.BOOSTER, (
      @(effectType, personal) @(item) item.isActive(true) && effectType.checkBooster(item)
        && item.personal == personal )(effectType, personal))
  return items.len() != 0
}

local function haveActiveBonusesByEffectType(effectType, personal = false)
{
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
