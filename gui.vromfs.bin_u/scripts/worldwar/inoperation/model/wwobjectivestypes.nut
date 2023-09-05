//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")


let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { split_by_chars } = require("string")
let enums = require("%sqStdLibs/helpers/enums.nut")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let time = require("%scripts/time.nut")
let { round, round_by_value } = require("%sqstd/math.nut")
let DataBlock  = require("DataBlock")


::g_ww_objective_type <- {
  types = []
  cache = {
    byTypeName = {}
  }
}

::g_ww_objective_type.template <- {
  defenderString = "Defender"
  attackerString = "Attacker"
  prefixNameLocId = "wwar_obj/types/"
  prefixParamLocId = "wwar_obj/params/"

  invertUpdateValue = false

  titleParams = []
  defaultValuesTable = {}
  paramsArray = []
  updateArray = []
  currentStateParam = ""

  needStopTimer = function(_statusBlk, _tm) { return true }
  isDefender = function(blk, side) {
    if (blk?.defenderSide && type(side) != type(blk.defenderSide))
      script_net_assert_once("invalid operation objective data", "Func isDefender: " + blk.defenderSide + " never be equal " + side)

    return blk?.defenderSide == side
  }
  getActionString = function(blk, side) { return this.isDefender(blk, side)
                                    ? this.defenderString
                                    : this.attackerString }

  getNameId = function(dataBlk, _side) { return this.getParamId(dataBlk, "title") }

  getName = function(dataBlk, statusBlk, side) {
    return this.getLocText(dataBlk, side, this.prefixNameLocId, "/name",
      this.getNameSpecification(dataBlk, statusBlk),
      this.getTitleLocId(dataBlk, statusBlk),
      this.getTitleLocParams(dataBlk, statusBlk, side))
  }
  getNameSpecification = @(_dataBlk, _statusBlk) ""

  getDesc = function(dataBlk, statusBlk, side) {
    let additionalTextLocId = dataBlk?.additionalDescriptionTextLocId
    let descList = [
      additionalTextLocId ? loc(additionalTextLocId, "") : "",
      this.getLocText(dataBlk, side, this.prefixNameLocId, "/desc", "", this.getTitleLocId(dataBlk, statusBlk))
    ]

    return "\n".join(descList, true)
  }

  getParamName = function(blk, side, paramName) {
    return this.getLocText(blk, side, this.prefixParamLocId, "/name", "", paramName)
  }

  getLocText = function(blk, side, prefix = "", postfix = "", spec = "", name = "", params = null) {
    if (name != "" && name == this.currentStateParam)
      return loc("wwar_obj/params/currentState/name")
    local locText = loc(prefix + name + postfix, "", params)
    if (blk?.type == null)
      return locText

    if (locText == "")
      locText = loc(prefix + blk.type + "/" + name + postfix, "", params)
    if (locText == "")
      locText = loc(prefix + blk.type + "/" + this.getActionString(blk, side) + postfix, "", params)
    if (locText == "")
      locText = loc(prefix + blk.type + "/" + this.getActionString(blk, side) + "/" + name + postfix + spec, "", params)
    if (locText == "")
      locText = loc(prefix + blk.type + postfix, "", params)
    return locText
  }
  getTitleLocId = function(dataBlk, _statusBlk) { return dataBlk?.id }
  getTitleLocParams = function(dataBlk, statusBlk, side) {
    let res = {}
    foreach (paramName in this.titleParams)
      res[paramName] <- (paramName in dataBlk)   ? this.getValueByParam(paramName, dataBlk, side)
                      : (paramName in statusBlk) ? this.getValueByParam(paramName, statusBlk, side)
                      : this.getTitleLocParamsDefaultValue(dataBlk, paramName)
    return res
  }

  getTitleLocParamsDefaultValue = function(dataBlk, pName) {
    if (pName in this.defaultValuesTable) {
      let value = this.defaultValuesTable[pName]
      return u.isFunction(value) ? value(dataBlk) : value
    }
    return ""
  }

  specificClassParamConvertion = {}
  convertParamValue = {
    timeSecScaled = @(value, _blk)
      time.hoursToString(time.secondsToHours(value - ::g_world_war.getOperationTimeSec()), false, true)
    holdTimeSec = @(value, _blk)
      time.hoursToString(time.secondsToHours(value), false, true)
    zonePercent_ = @(value, _blk)
      ::g_measure_type.getTypeByName("percent", true).getMeasureUnitsText(value)
    zonesPercent = @(value, _blk)
      ::g_measure_type.getTypeByName("percent", true).getMeasureUnitsText(value)
    unitCount = @(value, blk)
      value + ::g_ww_unit_type.getUnitTypeByTextCode(blk?.unitType).fontIcon
    advantage = @(value, _blk)
      loc("wwar_obj/params/advantage/value", { advantageFactor = round_by_value(value, 0.01) })
  }

  isParamVisible = {
    holdTimeSec = @(value) value > 0
  }

  colorize = {
    holdTimeSec = "warning"
  }
  getColorizeByParam = function(param) { return getTblValue(param, this.colorize) }

  getValueByParam = function(param, blk, side = null, useConverter = true) {
    local value = blk?[param]
    if (param in this.specificClassParamConvertion)
      value = this.specificClassParamConvertion[param](value, blk, side, this)
    if (useConverter && param in this.convertParamValue)
      value = this.convertParamValue[param](value, blk)
    return value
  }

  getParamId = function(blk, paramName) { return blk.getBlockName() + "_" + this.typeName + "_" + paramName }
  getParamsArray = function(blk, side) {
    let res = []
    foreach (paramName in this.paramsArray)
      if (paramName in blk) {
        res.append({
          id = this.getParamId(blk, paramName)
          pName = this.getParamName(blk, side, paramName)
          pValue = this.getValueByParam(paramName, blk, side)
        })
      }
    return res
  }

  getObjectiveStatus = function(sideValue, side) {
    local statusCode = -1
    if (sideValue)
      statusCode = sideValue == side ? MISSION_OBJECTIVE_STATUS_COMPLETED : MISSION_OBJECTIVE_STATUS_FAILED
    return ::g_objective_status.getObjectiveStatusByCode(statusCode)
  }

  getUpdatableZonesParams = function(_dataBlk, _statusBlk, _side) {
    return []
  }

  getUpdatableParamsArray = function(dataBlk, statusBlk, side) {
    if (!statusBlk)
      return []

    side = this.invertUpdateValue ?
      ::ww_side_val_to_name(::g_world_war.getOppositeSide(::ww_side_name_to_val(side))) :
      side

    let res = []
    foreach (paramName in this.updateArray) {
      let checkName = paramName in statusBlk ? paramName : paramName + side
      if (checkName in statusBlk) {
        let val = statusBlk?[checkName]

        local block = statusBlk?[checkName]
        let isDataBlock = u.isDataBlock(val)
        if (!isDataBlock) {
          block = DataBlock()
          block[checkName] = val
        }

        foreach (name, value in block) {
          let pValueParam = isDataBlock ? name : paramName
          res.append({
            id = checkName
            pName = this.getParamName(dataBlk, side, pValueParam)
            pValue = paramName in this.convertParamValue ? this.convertParamValue?[pValueParam](value, dataBlk) : value
            colorize = this.getColorizeByParam(pValueParam)
          })
        }
      }
    }
    return res
  }

  getUpdatableParamsDescriptionText = @(_dataBlk, _statusBlk, _side) ""
  getUpdatableParamsDescriptionTooltip = @(_dataBlk, _statusBlk, _side) ""
  getReinforcementSpeedupPercent = @(_dataBlk, _statusBlk, _side) 0

  timersArrayByParamName = {}
  timerSetVisibleFunctionTable = {}
  timerUpdateFunctionTables = {
    timeSecScaled = function(nestObj, dataBlk, statusBlk, t, _updateParam, side) {
      if (!checkObj(nestObj))
        return true

      let sideName = ::ww_side_val_to_name(side)
      let operationTime = (statusBlk?.timeSecScaled ?? 0) - ::g_world_war.getOperationTimeSec()
      nestObj.setValue(t.getName(dataBlk, statusBlk, sideName))
      let needStopTimer = t.needStopTimer(statusBlk, operationTime)
      return needStopTimer
    }
    zones = function(nestObj, dataBlk, _statusBlk, _t, zoneName) {
      let valueObj = nestObj.findObject("pValue")
      if (!checkObj(valueObj))
        return true

      let captureTimeSec = ::ww_get_zone_capture_time_sec(zoneName)
      let captureTimeEnd = dataBlk?.holdTimeSec ?? 0

      valueObj.setValue(time.hoursToString(time.secondsToHours(captureTimeSec), false, true))

      return captureTimeSec > captureTimeEnd
    }
  }

  timerFunc = function(handler, scene, objId, updateParam, timerParam, dataBlk, statusBlk, side) {
    let t = this
    let obj = scene.findObject(objId)
    if (!checkObj(obj))
      return []

    let setVisibleFunc = ::g_ww_objective_type.getTimerSetVisibleFunctionTableByParam(t, timerParam)
    let isVisible = setVisibleFunc(obj, dataBlk, statusBlk, t, side)
    if (!isVisible)
      return []

    let updateFunc = ::g_ww_objective_type.getTimerUpdateFuncByParam(t, timerParam)
    let update = Callback(function(nestObj, dataBlk) {
      return updateFunc(nestObj, dataBlk, statusBlk, t, updateParam, side)
    }, handler)

    return [SecondsUpdater(obj, update, false, dataBlk)]
  }
}

enums.addTypesByGlobalName("g_ww_objective_type", {
  UNKNOWN = {}

  OT_CAPTURE_ZONE = {
    titleParams = ["num", "timeSecScaled"]
    updateArray = ["holdTimeSec"]

    getNameId = function(dataBlk, _side) { return this.getParamId(dataBlk, "timeSecScaled") }
    getTitleLocId = function(dataBlk, statusBlk) {
      let hasAmount = dataBlk?.num != null
      let hasTime = (statusBlk?.timeSecScaled ?? 0) - ::g_world_war.getOperationTimeSec() > 0
      return (hasAmount ? "Amount" : "Specified") + (hasTime ? "" : "Timeless")
    }

    timersArrayByParamName = {
      timeSecScaled = function (handler, scene, param, dataBlk, statusBlk, t, side) {
        let paramId = t.getParamId(dataBlk, param)
        return [t.timerFunc(handler, scene, paramId, param, param, dataBlk, statusBlk, side)]
      }
      holdTimeSec = function (handler, scene, param, dataBlk, statusBlk, t, side) {
        let paramId = t.getParamId(dataBlk, param)
        return [t.timerFunc(handler, scene, paramId, param, param, dataBlk, statusBlk, side)]
      }
    }

    timerUpdateFunctionTables = {
      timeSecScaled = function(nestObj, dataBlk, statusBlk, t, _updateParam, side) {
        let sideName = ::ww_side_val_to_name(side)
        let timeSec = (statusBlk?.timeSecScaled ?? 0) - ::g_world_war.getOperationTimeSec()
        nestObj.setValue(t.getName(dataBlk, statusBlk, sideName))
        return t.needStopTimer(statusBlk, timeSec)
      }
      holdTimeSec = function(nestObj, dataBlk, statusBlk, t, updateParam, _side) {
        let pValueObj = nestObj.findObject("pValue")
        if (!checkObj(pValueObj))
          return

        let zonesArray = split_by_chars(dataBlk.zone, ";")
        local minCapturedTimeSec = -1
        for (local i = 0; i < zonesArray.len(); i++) {
          if (minCapturedTimeSec < 0)
            minCapturedTimeSec = ::ww_get_zone_capture_time_sec(zonesArray[i])
          else
            minCapturedTimeSec = min(minCapturedTimeSec, ::ww_get_zone_capture_time_sec(zonesArray[i]))
        }

        let leftTime = ((dataBlk?[updateParam] ?? 0) - minCapturedTimeSec) / ::ww_get_speedup_factor()
        let pValueText = t.convertParamValue?[updateParam](leftTime, dataBlk)
        pValueObj.setValue(pValueText)
        nestObj.show(!u.isEmpty(pValueText))

        return t.needStopTimer(statusBlk, leftTime)
      }
    }

    timerSetVisibleFunctionTable = {
      holdTimeSec = function(nestObj, dataBlk, statusBlk, t, side) {
        if (!checkObj(nestObj))
          return false

        local show = false
        if (statusBlk?.winner == null) {
          let sideName = ::ww_side_val_to_name(side)
          let block = statusBlk.getBlockByName("zones")
          local num = t.getValueByParam("num", dataBlk, sideName, false)
          foreach (_zoneName, holderSide in block)
            if (holderSide == sideName)
              num--

          show = t.isDefender(dataBlk, sideName) ? num > 0 : num <= 0
        }

        nestObj.show(show)
        return show
      }
    }

    specificClassParamConvertion = {
      num = function(value, blk, side, t) {
        let zones = split_by_chars(blk.zone, ";")
        return t.isDefender(blk, side) ? zones.len() - value + 1 : value
      }
    }

    needStopTimer = function(statusBlk, tm) {
      return tm < 0 || statusBlk?.winner
    }

    getUpdatableZonesParams = function(dataBlk, statusBlk, side) {
      if (!statusBlk)
        return []

      let zonesArray = []
      let data = statusBlk?.zones ?? dataBlk?.zones
      if (u.isDataBlock(data)) {
        let num = data.paramCount()
        let lastZoneName = data.getParamName(num - 1)
        foreach (zoneName, holderSide in data) {
          local teamName = "none"
          local mapLayer = WW_MAP_HIGHLIGHT.LAYER_0
          if (holderSide != ::ww_side_val_to_name(SIDE_NONE)) {
            teamName = side == holderSide ? "blue" : "red"
            mapLayer = side == holderSide ? WW_MAP_HIGHLIGHT.LAYER_1 : WW_MAP_HIGHLIGHT.LAYER_2
          }

          zonesArray.append({
            id = zoneName
            text = zoneName + (zoneName != lastZoneName ? ", " : "")
            team = teamName
            mapLayer = mapLayer
          })
        }
      }

      return zonesArray
    }

    getUpdatableParamsArray = function(dataBlk, _statusBlk, side) {
      let paramName = "holdTimeSec"
      let paramValue = dataBlk?[paramName]

      return this.isParamVisible[paramName](paramValue)
        ? [{ id = this.getParamId(dataBlk, paramName)
             pName = this.getParamName(dataBlk, side, paramName)
             pValue = this.getValueByParam(paramName, dataBlk, side)
             colorize = this.getColorizeByParam(paramName) }]
        : []
    }

    getUpdatableParamsDescriptionText = function(dataBlk, statusBlk, side) {
      let speedupPerc = this.getReinforcementSpeedupPercent(dataBlk, statusBlk, side)
      if (speedupPerc <= 0)
        return ""

      local speedupText = loc("worldwar/valueWithPercent", { percent = speedupPerc })
      speedupText = colorize("goodTextColor", loc("keysPlus") + speedupText)
      speedupText = loc("worldWar/iconReinforcement") + speedupText
      return loc("ui/parentheses", { text = speedupText })
    }

    getReinforcementSpeedupPercent = function(_dataBlk, statusBlk, side) {
      let sideIdx = ::ww_side_name_to_val(side)
      let paramName = "rSpeedMulStatus" + sideIdx + "New"
      let speedupFactor = statusBlk?[paramName] ?? 1
      return round(max(speedupFactor - 1, 0) * 100)
    }

    getNameSpecification = function(dataBlk, statusBlk) {
      let zonesNeeded = dataBlk?.num
      if (!zonesNeeded)
        return ""

      let zonesData = dataBlk?.zones ?? statusBlk?.zones
      let zonesCount = u.isDataBlock(zonesData) ? zonesData.paramCount() : 0
      return zonesNeeded < zonesCount ? "/approximate" : "/accurate"
    }

    getUpdatableParamsDescriptionTooltip = @(...) loc("worldwar/state/reinforcement_arrival_speedup")
  }

  OT_DOMINATION_ZONE = {
    titleParams = ["zonesPercent", "timeSecScaled"]
    updateArray = ["zonePercent_"]
    currentStateParam = "zonePercent_"

    getNameId = function(dataBlk, _side) { return this.getParamId(dataBlk, "timeSecScaled") }
    getTitleLocId = function(_dataBlk, statusBlk) {
      let hasTime = (statusBlk?.timeSecScaled ?? 0) - ::g_world_war.getOperationTimeSec() > 0
      return "Percentage" + (hasTime ? "" : "Timeless")
    }

    timersArrayByParamName = {
      timeSecScaled = function (handler, scene, timerParam, dataBlk, statusBlk, t, side) {
        let objId = t.getParamId(dataBlk, timerParam)
        return [t.timerFunc(handler, scene, objId, timerParam, timerParam, dataBlk, statusBlk, side)]
      }
    }

    needStopTimer = function(statusBlk, tm) {
      return tm < 0 || statusBlk?.winner
    }

    specificClassParamConvertion = {
      zonesPercent = function(value, blk, side, t) {
        return t.isDefender(blk, side) ? 100 - value + 1 : value
      }
    }

    timerSetVisibleFunctionTable = {
      timeSec = function(nestObj, dataBlk, statusBlk, _t, _side) {
        if (!checkObj(nestObj))
          return false

        let attackerSide = ::g_world_war.getOppositeSide(::ww_side_name_to_val(dataBlk?.defenderSide ?? ""))
        let zonesPercent = dataBlk?.zonesPercent ?? 0
        let capturedPercent = statusBlk?["zonePercent_" + attackerSide] ?? 0

        let isVisible = zonesPercent <= capturedPercent
        nestObj.show(isVisible)

        return isVisible
      }
    }
  }

  OT_COUNT_UNIT_LESS = {
    titleParams = ["num"]
    updateArray = ["unitCount"]
    currentStateParam = "unitCount"
    invertUpdateValue = true

    specificClassParamConvertion = {
      num = function(value, blk, _side, _t) { return value + ::g_ww_unit_type.getUnitTypeByTextCode(blk?.unitType).fontIcon }
    }
  }

  OT_DOMINATION_UNIT = {
    titleParams = ["fontIcon", "advantageFactor"]
    defaultValuesTable = {
      fontIcon = @(dataBlk) ::g_ww_unit_type.getUnitTypeByTextCode(dataBlk?.unitType).fontIcon
    }
    updateArray = ["advantage"]
  }

  OT_DONT_AFK = {
    getName = function(_dataBlk, _statusBlk, side) {
      let isMeLost = side != ::ww_side_val_to_name(::ww_get_operation_winner())
      return loc(isMeLost
        ? "worldwar/objectives/myTechnicalDefeat"
        : "worldwar/objectives/enemyTechnicalDefeat")
    }
  }

}, null, "typeName")

::g_ww_objective_type.getTypeByTypeName <- function getTypeByTypeName(typeName) {
  return enums.getCachedType("typeName", typeName, ::g_ww_objective_type.cache.byTypeName, ::g_ww_objective_type, ::g_ww_objective_type.UNKNOWN)
}

::g_ww_objective_type.getTimerUpdateFuncByParam <- function getTimerUpdateFuncByParam(t, param) {
  if (param in t.timerUpdateFunctionTables)
    return t.timerUpdateFunctionTables[param]

  return function(...) {}
}

::g_ww_objective_type.getTimerSetVisibleFunctionTableByParam <- function getTimerSetVisibleFunctionTableByParam(t, param) {
  if (param in t.timerSetVisibleFunctionTable)
    return t.timerSetVisibleFunctionTable[param]

  return function(...) { return true }
}
