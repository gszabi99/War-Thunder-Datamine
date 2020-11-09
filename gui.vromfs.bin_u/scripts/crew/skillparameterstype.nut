local { getMeasureTypeBySkillParameterName } = require("scripts/crew/crewSkills.nut")

local enums = ::require("sqStdlibs/helpers/enums.nut")
::g_skill_parameters_type <- {
  types = []
}

local cache = {
  byParamName = {}
}

local defaultGetValue = @(requestType, parametersByRequestType, params = null)
  parametersByRequestType?[requestType][params?.parameterName ?? -1][params?.idx ?? -1].value ?? 0

::g_skill_parameters_type.template <- {
  paramNames = []
  getValue = defaultGetValue

  parseColumns = function(paramData, columnTypes,
    parametersByRequestType, selectedParametersByRequestType, resArray)
  {
    local parameterName = paramData.name
    local measureType = getMeasureTypeBySkillParameterName(parameterName)
    local isNotFoundMeasureType = measureType == ::g_measure_type.UNKNOWN
    local sign = getDiffSign(parametersByRequestType, parameterName)
    local needMemberName = paramData.valuesArr.len() > 1
    local parsedMembers = []
    foreach(idx, value in paramData.valuesArr)
    {
      if(::isInArray(value.memberName, parsedMembers))
        continue

      if(isNotFoundMeasureType)
        measureType = getMeasureTypeBySkillParameterName(value.skillName)

      local parameterView = {
        descriptionLabel = parameterName.indexof("weapons/") == 0 ? ::loc(parameterName)
          : ::loc(::format("crewSkillParameter/%s", parameterName))
        valueItems = []
      }

      if (needMemberName)
        parameterView.descriptionLabel += ::format(" (%s)", ::loc("crew/" + value.memberName))

      local params = {
        idx = idx
        parameterName = parameterName
      }
      parseColumnTypes(columnTypes, parametersByRequestType, selectedParametersByRequestType,
        measureType, sign, parameterView, params)

      parameterView.progressBarValue <- getProgressBarValue(parametersByRequestType, params)
      parameterView.progressBarSelectedValue <- getProgressBarValue(selectedParametersByRequestType, params)
      resArray.append(parameterView)
      parsedMembers.append(value.memberName)
    }
  }

  parseColumnTypes = function(columnTypes, parametersByRequestType, selectedParametersByRequestType,
    measureType, sign, parameterView, params = null)
  {
    foreach (columnType in columnTypes)
    {
      local prevValue = getValue(
        columnType.previousParametersRequestType, parametersByRequestType, params)

      local curValue = getValue(
        columnType.currentParametersRequestType, parametersByRequestType, params)

      local prevSelectedValue = getValue(
        columnType.previousParametersRequestType, selectedParametersByRequestType, params)

      local curSelectedValue = getValue(
        columnType.currentParametersRequestType, selectedParametersByRequestType, params)

      local valueItem = columnType.createValueItem(
        prevValue, curValue, prevSelectedValue, curSelectedValue, measureType, sign)

      parameterView.valueItems.append(valueItem)
    }
  }

  getDiffSign = function(parametersByRequestType, parameterName)
  {
    local params = { parameterName = parameterName, idx = 0, columnIndex = 0 }
    local baseValue = getValue(
      ::g_skill_parameters_column_type.BASE.currentParametersRequestType, parametersByRequestType, params)
    local maxValue = getValue(
      ::g_skill_parameters_column_type.MAX.currentParametersRequestType, parametersByRequestType, params)
    return maxValue >= baseValue
  }

  getProgressBarValue = function(parametersByRequestType, params = null)
  {
    local currentParameterValue = getValue(
      ::g_skill_parameters_request_type.CURRENT_VALUES, parametersByRequestType, params)
    local maxParameterValue = getValue(
      ::g_skill_parameters_request_type.MAX_VALUES, parametersByRequestType, params)
    local baseParameterValue = getValue(
      ::g_skill_parameters_request_type.BASE_VALUES, parametersByRequestType, params)
    local curDiff = ::fabs(currentParameterValue - baseParameterValue)
    local maxDiff = ::fabs(maxParameterValue - baseParameterValue)
    if (maxDiff > 0.0)
      return (1000 * (curDiff / maxDiff)).tointeger()
    return 0
  }
}

enums.addTypesByGlobalName("g_skill_parameters_type", {
  DEFAULT = {}

  DISTANCE_ERROR = {
    paramNames = [
      "tankGunnerDistanceError",
      "shipGunnerFuseDistanceError"
    ]

    parseColumns = function(paramData, columnTypes,
                            parametersByRequestType, selectedParametersByRequestType, resArray)
    {
      local currentDistanceErrorData = paramData.valuesArr
      if (!currentDistanceErrorData.len())
        return

      local sign = getDiffSign(parametersByRequestType, paramData.name)

      foreach (i, parameterTable in currentDistanceErrorData[0].value)
      {
        local descriptionLocParams = {
          errorText = ::g_measure_type.ALTITUDE.getMeasureUnitsText(parameterTable.error, true, true)
        }
        local parameterView = {
          descriptionLabel = ::loc("crewSkillParameter/" + paramData.name, descriptionLocParams)
          valueItems = []
        }
        local params = {
          columnIndex = i
          parameterName = paramData.name
        }
        parseColumnTypes(columnTypes, parametersByRequestType, selectedParametersByRequestType,
          ::g_measure_type.DISTANCE, sign, parameterView, params)
        parameterView.progressBarValue <- getProgressBarValue(parametersByRequestType, params)
        resArray.append(parameterView)
      }
    }

    getValue = @(requestType, parametersByRequestType, params = null)
      parametersByRequestType?[requestType][params?.parameterName ?? -1][0].value[params?.columnIndex ?? -1].distance ?? 0
  }

  INTERCHANGE_ABILITY = {
    paramNames = "interchangeAbility"

    getValue = @(requestType, parametersByRequestType, params = null) !requestType || !::g_crew_short_cache.unit ? 0
      : ::g_crew_short_cache.unit.getCrewTotalCount() - defaultGetValue(requestType, parametersByRequestType, params)
  }
})

g_skill_parameters_type.getTypeByParamName <- function getTypeByParamName(paramName)
{
  return enums.getCachedType("paramNames", paramName, cache.byParamName, this, DEFAULT)
}