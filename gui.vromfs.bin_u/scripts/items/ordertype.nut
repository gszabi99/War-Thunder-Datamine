//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { isArray, isTable, isString } = require("%sqStdLibs/helpers/u.nut")
let { format } = require("string")
let enums = require("%sqStdLibs/helpers/enums.nut")
let time = require("%scripts/time.nut")
let { number_of_set_bits, round } = require("%sqstd/math.nut")
let { getUnitClassTypesFromCodeMask, getUnitClassTypesByEsUnitType
} = require("%scripts/unit/unitClassType.nut")
let { get_mplayer_by_userid, get_mp_local_team } = require("mission")
let { userIdInt64 } = require("%scripts/user/profileStates.nut")
let { getCurrentGameMode } = require("%scripts/gameModes/gameModeManagerState.nut")

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

/** Standard comparator for players' score data. */
function sortPlayerScores(data1, data2) {
  let score1 = data1?.score ?? 0
  let score2 = data2?.score ?? 0
  return score2 <=> score1
}

/** Returns string with properly formatted score. */
let formatScore = @(scoreValue) $"{round(scoreValue).tostring()}{loc("icon/orderScore")}"

let orderTypes = {
  types = []
  cache = {
    byName = {}
  }
  template = {
    name = ""
    awardUnit = "groundVehicle"

    formatScore
    sortPlayerScores

    getTypeDescription = @(colorScheme) colorize(colorScheme.typeDescriptionColor,
      loc(format("items/order/type/%s/description", this.name)))

    /** Description of order type-specific parameters. */
    function getParametersDescription(typeParams, colorScheme) {
      local description = ""
      foreach (paramName, paramValue in typeParams) {
        let checkValueType = !isTable(paramValue) && !isArray(paramValue)
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
    getObjectiveDescription = @(typeParams, colorScheme, _targetPlayer, emptyColorScheme)
      this.getObjectiveDescriptionByKey(typeParams, colorScheme,
        "items/order/type/%s/statusDescription", emptyColorScheme)

    /** Returns localized text to show as score header in order status. */
    function getScoreHeaderText() {
      let locPrefix = "items/order/scoreTable/scoreHeader/"
      return loc(locPrefix + this.name, loc(locPrefix + "default"))
    }

    /** Returns localized text to form proper award mode description. */
    getAwardUnitText = @() loc($"items/order/awardUnit/{this.awardUnit}")

    function getParameterDescription(paramName, paramValue, localizeStringValue, colorScheme) {
      let localizedParamName = loc(format("items/order/type/%s/param/%s", this.name, paramName))
      // If parameter has no value then it's name will be colored with value-color.
      if (isString(paramValue) && paramValue.len() == 0)
        return colorize(colorScheme.parameterValueColor, localizedParamName)

      local description = colorize(colorScheme.parameterLabelColor, localizedParamName)
      if (localizeStringValue && isString(paramValue))
        paramValue = loc(format("items/order/type/%s/param/%s/value/%s", this.name, paramName, paramValue))
      description += colorize(colorScheme.parameterValueColor, paramValue)
      return description
    }

    function getObjectiveDescriptionByKey(typeParams, colorScheme, statusDescriptionKey, emptyColorScheme) {
      let defaultText = this.getTypeDescription(emptyColorScheme)
      let uncoloredText = loc(format(statusDescriptionKey, this.name), defaultText)
      local description = colorize(colorScheme.objectiveDescriptionColor, uncoloredText)
      let typeParamsDescription = this.getParametersDescription(typeParams, colorScheme)
      if (description.len() > 0 && typeParamsDescription.len() > 0)
        description += "\n"

      description += typeParamsDescription
      return description
    }

    function getObjectiveDecriptionRelativeTarget(typeParams, colorScheme, targetPlayer, emptyColorScheme) {
      let targetPlayerUserId = targetPlayer?.userId.tointeger()
      let statusDescriptionKeyPostfix = targetPlayerUserId == null ? ""
        : targetPlayerUserId == userIdInt64.get() ? "/self"
        : get_mplayer_by_userid(targetPlayerUserId)?.team == get_mp_local_team() ? "/ally"
        : "/enemy"
      return this.getObjectiveDescriptionByKey(typeParams, colorScheme,
        $"items/order/type/%s/statusDescription{statusDescriptionKeyPostfix}", emptyColorScheme)
    }
  }
}

enums.addTypes(orderTypes, {
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

    function getObjectiveDescription(typeParams, colorScheme, _targetPlayer, _emptyColorScheme) {
      let reqUnitTypes = getCurrentGameMode()?.unitTypes ?? allEsUnitTypes
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
    getObjectiveDescription = @(typeParams, colorScheme, targetPlayer, emptyColorScheme)
      this.getObjectiveDecriptionRelativeTarget(typeParams, colorScheme, targetPlayer, emptyColorScheme)
  }

  REVENGE_HUNT = {
    name = "revengeHunt"
    getObjectiveDescription = @(typeParams, colorScheme, targetPlayer, emptyColorScheme)
      this.getObjectiveDecriptionRelativeTarget(typeParams, colorScheme, targetPlayer, emptyColorScheme)
  }

  EVENT_MUL = {
    name = "eventMul"
  }

  UNKNOWN = {
    name = "unknown"
  }
})

orderTypes.getOrderTypeByName <- function getOrderTypeByName(typeName) {
  return enums.getCachedType("name", typeName, this.cache.byName,
    this, this.UNKNOWN)
}

return {
  orderTypes
}