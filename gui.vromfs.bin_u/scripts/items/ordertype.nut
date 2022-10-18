from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
let enums = require("%sqStdLibs/helpers/enums.nut")
let time = require("%scripts/time.nut")
let { number_of_set_bits, round} = require("%sqstd/math.nut")
let { getUnitClassTypesFromCodeMask } = require("%scripts/unit/unitClassType.nut")


::g_order_type <- {
  types = []
}

::g_order_type._getDescription <- function _getDescription(colorScheme)
{
  return colorize(colorScheme.typeDescriptionColor,
    loc(format("items/order/type/%s/description", this.name)))
}

::g_order_type._getParametersDescription <- function _getParametersDescription(typeParams, colorScheme)
{
  local description = ""
  foreach (paramName, paramValue in typeParams)
  {
    let checkValueType = !::u.isTable(paramValue) && !::u.isArray(paramValue)
    if (paramName == "type" || !checkValueType)
      continue
    if (description.len() > 0)
      description += "\n"
    local localizeStringValue = true
    local paramValueFormatted
    if (paramName == "huntTime")
    {
      localizeStringValue = false
      paramValueFormatted = time.secondsToString(paramValue, true, true)
    }
    else
      paramValueFormatted = paramValue
    description += ::g_order_type._getParameterDescription.call(this, paramName,
      paramValueFormatted, localizeStringValue, colorScheme)
  }
  return description
}

::g_order_type._getParameterDescription <- function _getParameterDescription(paramName, paramValue, localizeStringValue, colorScheme)
{
  let localizedParamName = loc(format("items/order/type/%s/param/%s", this.name, paramName))
  // If parameter has no value then it's name will be colored with value-color.
  if (::u.isString(paramValue) && paramValue.len() == 0)
    return colorize(colorScheme.parameterValueColor, localizedParamName)
  local description = colorize(colorScheme.parameterLabelColor, localizedParamName)
  if (localizeStringValue && ::u.isString(paramValue))
    paramValue = loc(format("items/order/type/%s/param/%s/value/%s", this.name, paramName, paramValue))
  description += colorize(colorScheme.parameterValueColor, paramValue)
  return description
}

::g_order_type._getObjectiveDescriptionByKey <- function _getObjectiveDescriptionByKey(typeParams, colorScheme, statusDescriptionKey)
{
  let defaultText = ::g_order_type._getDescription.call(this, ::g_orders.emptyColorScheme)
  let uncoloredText = loc(format(statusDescriptionKey, this.name), defaultText)
  local description = colorize(colorScheme.objectiveDescriptionColor, uncoloredText)
  let typeParamsDescription = ::g_order_type._getParametersDescription.call(this, typeParams, colorScheme)
  if (description.len() > 0 && typeParamsDescription.len() > 0)
    description += "\n"
  description += typeParamsDescription

  return description
}

::g_order_type._getObjectiveDescription <- function _getObjectiveDescription(typeParams, colorScheme)
{
  return ::g_order_type._getObjectiveDescriptionByKey.call(this, typeParams, colorScheme, "items/order/type/%s/statusDescription")
}

::g_order_type._getObjectiveDecriptionRelativeTarget <- function _getObjectiveDecriptionRelativeTarget(typeParams, colorScheme)
{
  local statusDescriptionKeyPostfix = ""
  local targetPlayerUserId = null

  if (::g_orders.activeOrder.targetPlayer != null)
    targetPlayerUserId = getTblValue("userId", ::g_orders.activeOrder.targetPlayer, null)

  if (targetPlayerUserId != null)
    if (targetPlayerUserId == ::my_user_id_str)
      statusDescriptionKeyPostfix = "/self"
    else
    {
      let myTeam = ::get_mp_local_team()
      let myTeamPlayers = ::get_mplayers_list(myTeam, true)
      statusDescriptionKeyPostfix = "/enemy"
      foreach(_idx, teamMember in myTeamPlayers)
      {
        if (getTblValue("userId", teamMember, null) == targetPlayerUserId)
        {
          statusDescriptionKeyPostfix = "/ally"
          break
        }
      }
    }

  return ::g_order_type._getObjectiveDescriptionByKey.call(this, typeParams, colorScheme, "items/order/type/%s/statusDescription" + statusDescriptionKeyPostfix)
}

::g_order_type._getScoreHeaderText <- function _getScoreHeaderText()
{
  let locPrefix = "items/order/scoreTable/scoreHeader/"
  return loc(locPrefix + this.name, loc(locPrefix + "default"))
}

::g_order_type._getAwardUnitText <- function _getAwardUnitText()
{
  return loc("items/order/awardUnit/" + this.awardUnit)
}

::g_order_type._sortPlayerScores <- function _sortPlayerScores(data1, data2)
{
  let score1 = getTblValue("score", data1, 0)
  let score2 = getTblValue("score", data2, 0)
  if (score1 != score2)
    return score1 > score2 ? -1 : 1
  return 0
}

::g_order_type._formatScore <- function _formatScore(scoreValue)
{
  return round(scoreValue).tostring() + loc("icon/orderScore")
}

::g_order_type.template <- {
  awardUnit = "groundVehicle"

  /** Returns simple order type description base only on type name. */
  getTypeDescription = ::g_order_type._getDescription

  /** Description of order type-specific parameters. */
  getParametersDescription = ::g_order_type._getParametersDescription

  /** In-battle order description. */
  getObjectiveDescription = ::g_order_type._getObjectiveDescription

  /** Returns localized text to show as score header in order status. */
  getScoreHeaderText = ::g_order_type._getScoreHeaderText

  /** Returns localized text to form proper award mode description. */
  getAwardUnitText = ::g_order_type._getAwardUnitText

  /** Standard comparator for players' score data. */
  sortPlayerScores = ::g_order_type._sortPlayerScores

  /** Returns string with properly formatted score. */
  formatScore = ::g_order_type._formatScore
}

enums.addTypesByGlobalName("g_order_type", {
  SCORE = {
    name = "score"
  }

  UNIVERSAL_KILLER = {
    name = "universalKiller"
    sortPlayerScores = function (data1, data2) {
      let score1 = number_of_set_bits(getTblValue("score", data1, 0).tointeger())
      let score2 = number_of_set_bits(getTblValue("score", data2, 0).tointeger())
      if (score1 != score2)
        return score1 > score2 ? -1 : 1
      return 0
    }
    formatScore = function (scoreValue) {
      let types = getUnitClassTypesFromCodeMask(scoreValue)
      if (types.len() == 0)
        return "-"
      let names = types.map(@(t) t.getName())
      return ::g_string.implode(names, ", ")
    }
  }

  STREAK = {
    name = "streak"
  }

  ROCKET_MAN = {
    name = "rocketMan"
  }

  RANDOM_HUNT = {
    name = "randomHunt"
    getObjectiveDescription = ::g_order_type._getObjectiveDecriptionRelativeTarget
  }

  REVENGE_HUNT = {
    name = "revengeHunt"
    getObjectiveDescription = ::g_order_type._getObjectiveDecriptionRelativeTarget
  }

  EVENT_MUL = {
    name = "eventMul"
  }

  UNKNOWN = {
    name = "unknown"
  }
})

::g_order_type.getOrderTypeByName <- function getOrderTypeByName(typeName)
{
  return enums.getCachedType("name", typeName, ::g_order_type_cache.byName,
    ::g_order_type, ::g_order_type.UNKNOWN)
}

::g_order_type_cache <- {
  byName = {}
}
