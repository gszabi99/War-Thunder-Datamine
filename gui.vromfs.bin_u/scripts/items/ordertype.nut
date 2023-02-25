//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
let enums = require("%sqStdLibs/helpers/enums.nut")
let time = require("%scripts/time.nut")
let { number_of_set_bits, round } = require("%sqstd/math.nut")
let { getUnitClassTypesFromCodeMask, getUnitClassTypesByEsUnitType
} = require("%scripts/unit/unitClassType.nut")

let allEsUnitTypes = [
  ES_UNIT_TYPE_AIRCRAFT,
  ES_UNIT_TYPE_TANK,
  ES_UNIT_TYPE_SHIP,
  ES_UNIT_TYPE_BOAT,
  ES_UNIT_TYPE_HELICOPTER
]

let getUnitClassNamesByEsUnitTypes = @(esUnitTypes) esUnitTypes
  .reduce(@(acc, val) acc.extend(getUnitClassTypesByEsUnitType(val)), [])
  .filter(@(t) !t.isDeprecated)
  .map(@(t) t.getName())

::g_order_type <- {
  types = []
}

::g_order_type.template <- {
  name = ""
  awardUnit = "groundVehicle"

  /** Returns simple order type description base only on type name. */
  getTypeDescription = @(colorScheme) colorize(colorScheme.typeDescriptionColor,
    loc(format("items/order/type/%s/description", this.name)))

  /** Description of order type-specific parameters. */
  function getParametersDescription(typeParams, colorScheme) {
    local description = ""
    foreach (paramName, paramValue in typeParams) {
      let checkValueType = !::u.isTable(paramValue) && !::u.isArray(paramValue)
      if (paramName == "type" || !checkValueType)
        continue
      if (description.len() > 0)
        description += "\n"

      local localizeStringValue = true
      local paramValueFormatted
      if (paramName == "huntTime") {
        localizeStringValue = false
        paramValueFormatted = time.secondsToString(paramValue, true, true)
      }
      else
        paramValueFormatted = paramValue

      description += this.getParameterDescription(paramName,
        paramValueFormatted, localizeStringValue, colorScheme)
    }
    return description
  }

  /** In-battle order description. */
  getObjectiveDescription = @(typeParams, colorScheme)
    this.getObjectiveDescriptionByKey(typeParams, colorScheme, "items/order/type/%s/statusDescription")

  /** Returns localized text to show as score header in order status. */
  function getScoreHeaderText() {
    let locPrefix = "items/order/scoreTable/scoreHeader/"
    return loc(locPrefix + this.name, loc(locPrefix + "default"))
  }

  /** Returns localized text to form proper award mode description. */
  getAwardUnitText = @() loc("items/order/awardUnit/" + this.awardUnit)

  /** Standard comparator for players' score data. */
  function sortPlayerScores(data1, data2) {
    let score1 = getTblValue("score", data1, 0)
    let score2 = getTblValue("score", data2, 0)
    return score2 <=> score1
  }

  /** Returns string with properly formatted score. */
  formatScore = @(scoreValue) round(scoreValue).tostring() + loc("icon/orderScore")

  function getParameterDescription(paramName, paramValue, localizeStringValue, colorScheme) {
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

  function getObjectiveDescriptionByKey(typeParams, colorScheme, statusDescriptionKey) {
    let defaultText = this.getTypeDescription(::g_orders.emptyColorScheme)
    let uncoloredText = loc(format(statusDescriptionKey, this.name), defaultText)
    local description = colorize(colorScheme.objectiveDescriptionColor, uncoloredText)
    let typeParamsDescription = this.getParametersDescription(typeParams, colorScheme)
    if (description.len() > 0 && typeParamsDescription.len() > 0)
      description += "\n"

    description += typeParamsDescription
    return description
  }

  function getObjectiveDecriptionRelativeTarget(typeParams, colorScheme) {
    local statusDescriptionKeyPostfix = ""
    local targetPlayerUserId = null

    if (::g_orders.activeOrder.targetPlayer != null)
      targetPlayerUserId = getTblValue("userId", ::g_orders.activeOrder.targetPlayer, null)

    if (targetPlayerUserId != null)
      if (targetPlayerUserId == ::my_user_id_str)
        statusDescriptionKeyPostfix = "/self"
      else {
        let myTeam = ::get_mp_local_team()
        let myTeamPlayers = ::get_mplayers_list(myTeam, true)
        statusDescriptionKeyPostfix = "/enemy"
        foreach (_idx, teamMember in myTeamPlayers) {
          if (getTblValue("userId", teamMember, null) == targetPlayerUserId) {
            statusDescriptionKeyPostfix = "/ally"
            break
          }
        }
      }

    return this.getObjectiveDescriptionByKey(typeParams, colorScheme,
      "items/order/type/%s/statusDescription" + statusDescriptionKeyPostfix)
  }
}

enums.addTypesByGlobalName("g_order_type", {
  SCORE = {
    name = "score"
  }

  UNIVERSAL_KILLER = {
    name = "universalKiller"

    function sortPlayerScores(data1, data2) {
      let score1 = number_of_set_bits(data1?.score.tointeger() ?? 0)
      let score2 = number_of_set_bits(data2?.score.tointeger() ?? 0)
      return score2 <=> score1
    }

    function formatScore(scoreValue) {
      let types = getUnitClassTypesFromCodeMask(scoreValue)
      if (types.len() == 0)
        return "-"
      let names = types.map(@(t) t.getName())
      return ", ".join(names, true)
    }

    function getObjectiveDescription(typeParams, colorScheme) {
      let reqUnitTypes = ::game_mode_manager.getCurrentGameMode()?.unitTypes ?? allEsUnitTypes
      let unitClasses = ", ".join(getUnitClassNamesByEsUnitTypes(reqUnitTypes), true)
      let desc = loc($"items/order/type/{this.name}/description", { unitClasses })
      let typeParamsDesc = this.getParametersDescription(typeParams, colorScheme)
      return "\n".join([
        colorize(colorScheme.objectiveDescriptionColor, desc),
        typeParamsDesc
      ], true)
    }

    function getTypeDescription(colorScheme) {
      let unitClasses = ", ".join(getUnitClassNamesByEsUnitTypes(allEsUnitTypes))
      let desc = loc($"items/order/type/{this.name}/description", { unitClasses })
      return colorize(colorScheme.typeDescriptionColor, desc)
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
    getObjectiveDescription = @(typeParams, colorScheme)
      this.getObjectiveDecriptionRelativeTarget(typeParams, colorScheme)
  }

  REVENGE_HUNT = {
    name = "revengeHunt"
    getObjectiveDescription = @(typeParams, colorScheme)
      this.getObjectiveDecriptionRelativeTarget(typeParams, colorScheme)
  }

  EVENT_MUL = {
    name = "eventMul"
  }

  UNKNOWN = {
    name = "unknown"
  }
})

::g_order_type.getOrderTypeByName <- function getOrderTypeByName(typeName) {
  return enums.getCachedType("name", typeName, ::g_order_type_cache.byName,
    ::g_order_type, ::g_order_type.UNKNOWN)
}

::g_order_type_cache <- {
  byName = {}
}
