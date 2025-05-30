from "%scripts/dagui_library.nut" import *
import "%sqStdLibs/helpers/enums.nut" as enums

let { format } = require("string")
let { fabs } = require("math")
let { getMeasureTypeBySkillParameterName } = require("%scripts/crew/crewSkills.nut")
let { measureType } = require("%scripts/measureType.nut")
let { getCachedCrewUnit } = require("%scripts/crew/crewShortCache.nut")
let { skillParametersRequestType } = require("%scripts/crew/skillParametersRequestType.nut")
let skillParametersColumnType = require("%scripts/crew/skillParametersColumnType.nut")

let g_skill_parameters_type = {
  types = []
}

let cache = {
  byParamName = {}
}

let defaultGetValue = @(requestType, parametersByRequestType, params = null)
  parametersByRequestType?[requestType][params?.parameterName ?? -1][params?.idx ?? -1].value ?? 0

g_skill_parameters_type.template <- {
  paramNames = []
  getValue = defaultGetValue

  parseColumns = function(paramData, columnTypes,
      parametersByRequestType, selectedParametersByRequestType, resArray) {
    let parameterName = paramData.name
    local measure = getMeasureTypeBySkillParameterName(parameterName)
    let isNotFoundMeasureType = measure == measureType.UNKNOWN
    let sign = this.getDiffSign(parametersByRequestType, parameterName)
    let needMemberName = paramData.valuesArr.len() > 1
    let parsedMembers = []
    foreach (idx, value in paramData.valuesArr) {
      if (isInArray(value.memberName, parsedMembers))
        continue

      if (isNotFoundMeasureType)
        measure = getMeasureTypeBySkillParameterName(value.skillName)

      let parameterView = {
        descriptionLabel = parameterName.indexof("weapons/") == 0 ? loc(parameterName)
          : loc(format("crewSkillParameter/%s", parameterName))
        valueItems = []
      }

      if (needMemberName)
        parameterView.descriptionLabel = "".concat(parameterView.descriptionLabel, format(" (%s)", loc($"crew/{value.memberName}")))

      let params = {
        idx = idx
        parameterName = parameterName
      }
      this.parseColumnTypes(columnTypes, parametersByRequestType, selectedParametersByRequestType,
        measure, sign, parameterView, params)

      parameterView.progressBarValue <- this.getProgressBarValue(parametersByRequestType, params)
      parameterView.progressBarSelectedValue <- this.getProgressBarValue(selectedParametersByRequestType, params)
      resArray.append(parameterView)
      parsedMembers.append(value.memberName)
    }
  }

  parseColumnTypes = function(columnTypes, parametersByRequestType, selectedParametersByRequestType,
    measure, sign, parameterView, params = null) {
    foreach (columnType in columnTypes) {
      let prevValue = this.getValue(
        columnType.previousParametersRequestType, parametersByRequestType, params)

      let curValue = this.getValue(
        columnType.currentParametersRequestType, parametersByRequestType, params)

      let prevSelectedValue = this.getValue(
        columnType.previousParametersRequestType, selectedParametersByRequestType, params)

      let curSelectedValue = this.getValue(
        columnType.currentParametersRequestType, selectedParametersByRequestType, params)

      let valueItem = columnType.createValueItem(
        prevValue, curValue, prevSelectedValue, curSelectedValue, measure, sign)

      parameterView.valueItems.append(valueItem)
    }
  }

  getDiffSign = function(parametersByRequestType, parameterName) {
    let params = { parameterName = parameterName, idx = 0, columnIndex = 0 }
    let baseValue = this.getValue(
      skillParametersColumnType.BASE.currentParametersRequestType, parametersByRequestType, params)
    let maxValue = this.getValue(
      skillParametersColumnType.MAX.currentParametersRequestType, parametersByRequestType, params)
    return maxValue >= baseValue
  }

  getProgressBarValue = function(parametersByRequestType, params = null) {
    let currentParameterValue = this.getValue(
      skillParametersRequestType.CURRENT_VALUES, parametersByRequestType, params)
    let maxParameterValue = this.getValue(
      skillParametersRequestType.MAX_VALUES, parametersByRequestType, params)
    let baseParameterValue = this.getValue(
      skillParametersRequestType.BASE_VALUES, parametersByRequestType, params)
    let curDiff = fabs(currentParameterValue - baseParameterValue)
    let maxDiff = fabs(maxParameterValue - baseParameterValue)
    if (maxDiff > 0.0)
      return (1000 * (curDiff / maxDiff)).tointeger()
    return 0
  }
}

enums.enumsAddTypes(g_skill_parameters_type, {
  DEFAULT = {}

  DISTANCE_ERROR = {
    paramNames = [
      "tankGunnerDistanceError",
      "shipGunnerFuseDistanceError"
    ]

    parseColumns = function(paramData, columnTypes,
                            parametersByRequestType, selectedParametersByRequestType, resArray) {
      let currentDistanceErrorData = paramData.valuesArr
      if (!currentDistanceErrorData.len())
        return

      let sign = this.getDiffSign(parametersByRequestType, paramData.name)

      foreach (i, parameterTable in currentDistanceErrorData[0].value) {
        let descriptionLocParams = {
          errorText = measureType.ALTITUDE.getMeasureUnitsText(parameterTable.error, true, true)
        }
        let parameterView = {
          descriptionLabel = loc($"crewSkillParameter/{paramData.name}", descriptionLocParams)
          valueItems = []
        }
        let params = {
          columnIndex = i
          parameterName = paramData.name
        }
        this.parseColumnTypes(columnTypes, parametersByRequestType, selectedParametersByRequestType,
          measureType.DISTANCE, sign, parameterView, params)
        parameterView.progressBarValue <- this.getProgressBarValue(parametersByRequestType, params)
        resArray.append(parameterView)
      }
    }

    getValue = @(requestType, parametersByRequestType, params = null)
      parametersByRequestType?[requestType][params?.parameterName ?? -1][0].value[params?.columnIndex ?? -1].distance ?? 0
  }

  INTERCHANGE_ABILITY = {
    paramNames = "interchangeAbility"

    getValue = @(requestType, parametersByRequestType, params = null) !requestType || !getCachedCrewUnit() ? 0
      : getCachedCrewUnit().getCrewTotalCount() - defaultGetValue(requestType, parametersByRequestType, params)
  }

  BASE_HEARING_DISTANCE = {
    paramNames = "hearingDistance"
    parseColumns = function(_paramData, _columnTypes, _parametersByRequestType, _selectedParametersByRequestType, _resArray) {
      
    }
  }
})

g_skill_parameters_type.getTypeByParamName <- function getTypeByParamName(paramName) {
  return enums.getCachedType("paramNames", paramName, cache.byParamName, this, this.DEFAULT)
}
return {
  g_skill_parameters_type
}