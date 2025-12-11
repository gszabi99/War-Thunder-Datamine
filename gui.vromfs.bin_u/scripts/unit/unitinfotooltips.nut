from "%scripts/dagui_library.nut" import *

let { format } = require("string")
let { abs } = require("math")
let { getTooltipType, addTooltipTypes } = require("%scripts/utils/genericTooltipTypes.nut")
let { getEsUnitType, getFullUnitBlk } = require("%scripts/unit/unitParams.nut")
let dmViewer = require("%scripts/dmViewer/dmViewer.nut")
let { DM_VIEWER_XRAY } = require("hangar")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { get_unittags_blk } = require("blkGetters")
let { appendOnce } = require("%sqStdLibs/helpers/u.nut")

let anyAirVehicle = [ ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_HELICOPTER ]
let anyWaterVehicle = [ ES_UNIT_TYPE_BOAT, ES_UNIT_TYPE_SHIP ]
let notTankVehicle = [].extend(anyAirVehicle, anyWaterVehicle)

let objectsWithTooltip = {
  horsePowers = {
    showForTypes = [ES_UNIT_TYPE_TANK]
    getTooltipId = function(id, _params) {
      let params = {
        unitId = id
        value = "engine"
      }

      return getTooltipType("UNIT_DM_TOOLTIP").getTooltipId(id, params)
    }
  }
  maxSpeed = {
    showForTypes = notTankVehicle
    getTooltipId = function(id, p) {
      let params = {
        unitId = id
        value = "engine"
      }
      return anyWaterVehicle.contains(p.unitType) ? getTooltipType("SHIP_ENGINE_TOOLTIP").getTooltipId(id, params)
        : getTooltipType("UNIT_SIMPLE_TOOLTIP").getTooltipId(id, { unitId = id, value = "maxSpeed" })
    }
  }
  maxSpeedBoth = {
    showForTypes = [ES_UNIT_TYPE_TANK]
    getTooltipId = function(id, _params) {
      let params = {
        unitId = id
        value = "transmission"
      }

      return getTooltipType("UNIT_DM_TOOLTIP").getTooltipId(id, params)
    }
  }
  climbSpeed = {
    showForTypes = anyAirVehicle
    getTooltipId = function(id, _params) {
      let params = {
        unitId = id
        value = "climbSpeed"
      }

      return getTooltipType("UNIT_SIMPLE_TOOLTIP").getTooltipId(id, params)
    }
  }
  turnTime = {
    showForTypes = anyAirVehicle
    getTooltipId = function(id, _params) {
      let params = {
        unitId = id
        value = "turnTime"
      }

      return getTooltipType("UNIT_SIMPLE_TOOLTIP").getTooltipId(id, params)
    }
  }
  maxAltitude = {
    showForTypes = anyAirVehicle
    getTooltipId = function(id, _params) {
      let params = {
        unitId = id
        value = "maxAltitude"
      }

      return getTooltipType("UNIT_SIMPLE_TOOLTIP").getTooltipId(id, params)
    }
  }
  wingLoading = {
    showForTypes = anyAirVehicle
    getTooltipId = function(id, _params) {
      let params = {
        unitId = id
        value = "wingLoading"
      }

      return getTooltipType("UNIT_SIMPLE_TOOLTIP").getTooltipId(id, params)
    }
  }
}

function fillTooltipsIds(holderObj, unit, params = {}) {
  foreach (objId, data in objectsWithTooltip) {
    let unitType = getEsUnitType(unit)

    if (!isInArray(unitType, data.showForTypes))
      continue

    let tooltipObjs = []

    local tooltipObj = holderObj.findObject($"{objId}-tooltip")
    if (tooltipObj?.isValid()) {
      tooltipObjs.append(tooltipObj)
      tooltipObj = tooltipObj.findObject($"{objId}-tooltip-obj")
      if (tooltipObj?.isValid())
        tooltipObjs.append(tooltipObj)
    }

    let objectsWithSomeTooltip = data?.objectsWithSomeTooltip ?? []
    if (objectsWithSomeTooltip.len() > 0)
      objectsWithSomeTooltip.each(function(o) {
        let tObj = holderObj.findObject(o)
        if (tObj?.isValid())
          tooltipObjs.append(tObj)
      })
    params.__update({ unitType })
    tooltipObjs.each(@(t) t.tooltipId = objectsWithTooltip[objId].getTooltipId(unit.name, params))
  }
}

function updateDMTooltipView(obj, info) {
  info.title = info.title.replace(" ", nbsp)
  obj.findObject("dmviewer_title").setValue(info.title)
  let descObj = obj.findObject("dmviewer_desc")

  if (info.desc != null) {
    let items = info.desc.map(@(v) "value" in v ? v : { value = v })
    let data = handyman.renderCached("%gui/dmViewer/dmViewerHintDescItem.tpl", { items })
    obj.getScene().replaceContentFromText(descObj, data, data.len(), null)
    obj.findObject("topValueHint").show(info.desc.findindex(@(v) "topValue" in v) != null)

  }
  showObjById("dmviewer_anim", !!info.animation, obj)["movie-load"] = info.animation
  let needShowExtHint = info.extDesc != ""
  let extHintObj = obj.findObject("dmviewer_ext_hint")
  extHintObj.show(needShowExtHint)
  if (needShowExtHint) {
    obj.getScene().applyPendingChanges(false)
    extHintObj.width = max(extHintObj.getSize()[0], descObj.getSize()[0])
    obj.findObject("dmviewer_ext_hint_desc").setValue(info.extDesc)
    obj.findObject("dmviewer_ext_hint_icon")["background-image"] = info.extIcon
    obj.findObject("dmviewer_ext_hint_shortcut").setValue(info.extShortcut)
  }
}

function updateAPSTooltipView(obj, aps) {
  let { model, reactionTime = null,
    reloadTime = null, targetSpeed = null,
    shotCount = null, horAngles = null,
    verAngles = null
  } = aps

  let deg = loc("measureUnits/deg")
  let colon = loc("ui/colon")

  let title = "".concat(loc("xray/model"), loc("ui/colon"), loc($"aps/{model}"))
  obj.findObject("dmviewer_title").setValue(title)

  let desc = []
  let descObj = obj.findObject("dmviewer_desc")

  if (horAngles)
    desc.append("".concat(loc("xray/aps/protected_sector/hor"), colon,
      (horAngles.x + horAngles.y == 0
        ? format("±%d%s", abs(horAngles.y), deg)
        : format("%+d%s/%+d%s", horAngles.x, deg, horAngles.y, deg))))
  if (verAngles)
    desc.append("".concat(loc("xray/aps/protected_sector/vert"), colon,
      (verAngles.x + verAngles.y == 0
        ? format("±%d%s", abs(verAngles.y), deg)
        : format("%+d%s/%+d%s", verAngles.x, deg, verAngles.y, deg))))
  if (reloadTime)
    desc.append("".concat(loc("xray/aps/reloadTime"), colon,
      reloadTime, " ", loc("measureUnits/seconds")))
  if (reactionTime)
    desc.append("".concat(loc("xray/aps/reactionTime"), colon,
      reactionTime * 1000, " ", loc("measureUnits/milliseconds")))
  if (targetSpeed)
    desc.append("".concat(loc("xray/aps/targetSpeed"), colon,
      $"{targetSpeed.x}-{targetSpeed.y}", " ", loc("measureUnits/metersPerSecond_climbSpeed")))
  if (shotCount)
    desc.append("".concat(loc("xray/aps/shotCount"), colon,
      shotCount, " " , loc("measureUnits/pcs")))
  if (desc.len() == 0)
    return

  let items = desc.map(@(v) { value = v })
  let data = handyman.renderCached("%gui/dmViewer/dmViewerHintDescItem.tpl", { items })
  obj.getScene().replaceContentFromText(descObj, data, data.len(), null)
}

addTooltipTypes({
  UNIT_DM_TOOLTIP = {
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, _id, params) {
      if (!obj?.isValid())
        return false

      let { unitId, value = null, dmPart = null } = params
      let unit = getAircraftByName(unitId)
      if (!unit || (value == null && dmPart == null))
        return false

      let guiScene = obj.getScene()
      guiScene.replaceContent(obj, "%gui/unitInfo/dmViewerHint.blk", handler)
      dmViewer.updateUnitInfo(unitId)
      let info = dmViewer.getPartTooltipInfo(value, { name = dmPart ?? $"{value}1_dm", viewMode = DM_VIEWER_XRAY })
      updateDMTooltipView(obj, info)
      return true
    }
  }
  UNIT_INFO_ARMOR = {
    isCustomTooltipFill = true
    isModalTooltip = true
    fillTooltip = function(obj, handler, _id, params) {
      if (!obj?.isValid())
        return false

      let { unitId, armor } = params

      let guiScene = obj.getScene()
      guiScene.createElementByObject(obj, "%gui/unitInfo/protectionHint.blk", "modalInfoContent", handler)
      obj.findObject("description").setValue(loc($"info/material/{armor}/tooltip"))

      let btn = showObjById("protection-btn", true, obj)
      btn["unit"] = unitId
      showObjById("analysis-btn", false, obj)
      return true
    }
  }
  UNIT_INFO_PROTECTION_TYPE = {
    isCustomTooltipFill = true
    isModalTooltip = true
    fillTooltip = function(obj, handler, _id, params) {
      if (!obj?.isValid())
        return false

      let { unitId, protectionType } = params

      let guiScene = obj.getScene()
      guiScene.createElementByObject(obj, "%gui/unitInfo/protectionHint.blk", "modalInfoContent", handler)
      obj.findObject("description").setValue(loc($"info/material/{protectionType}/tooltip"))
      obj.findObject("protection-btn").show(false)

      let btn = showObjById("analysis-btn", true, obj)
      btn["unit"] = unitId
      return true
    }
  }

  UNIT_SIMPLE_TOOLTIP = {
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, _id, params) {
      if (!obj?.isValid())
        return false

      let { value = null, textLoc = null } = params
      let guiScene = obj.getScene()
      guiScene.replaceContent(obj, "%gui/unitInfo/simpleTooltip.blk", handler)
      obj.findObject("description").setValue(loc(textLoc ?? $"info/{value}/tooltip"))
      obj.findObject("button-div").show(false)
      return true
    }
  }

  UNIT_INFO_APS = {
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, _id, params) {
      if (!obj?.isValid())
        return false

      let blk = getFullUnitBlk(params.unitId)
      let aps = blk.ActiveProtectionSystem

      let guiScene = obj.getScene()
      guiScene.replaceContent(obj, "%gui/unitInfo/dmViewerHint.blk", handler)
      updateAPSTooltipView(obj, aps)
      return true
    }
  }

  SHIP_ENGINE_TOOLTIP = {
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, _id, params) {
      if (!obj?.isValid())
        return false

      let descriptionArr = []
      let unitTags = get_unittags_blk()?[params.unitId] ?? {}
      let blk = getFullUnitBlk(params.unitId)
      let engines = blk.ShipPhys.engines % "engine"

      let enginesArr = []
      let transmissionsArr = []
      engines.each(function(engine) {
        let engineDmParts = engine % "engineDmPart"
        engineDmParts.each(function(part) {
          appendOnce(part, enginesArr)
        })

        let transmissionDmParts = engine % "transmissionDmPart"
        transmissionDmParts.each(function(part) {
          appendOnce(part, transmissionsArr)
        })
      })

      if (unitTags?.tags.type_boat == true) {
        descriptionArr.append(loc("info/num_engines", { num = enginesArr.len() }))
        descriptionArr.append(loc("info/num_transmissions", { num = transmissionsArr.len() }))
      }
      else {
        descriptionArr.append(loc("info/num_boilers", { num = enginesArr.len() }))
        descriptionArr.append(loc("info/num_engine_rooms", { num = transmissionsArr.len() }))
      }

      let guiScene = obj.getScene()
      guiScene.replaceContent(obj, "%gui/unitInfo/simpleTooltip.blk", handler)
      obj.findObject("title").setValue(loc($"armor_class/engine"))
      obj.findObject("description").setValue("\n".join(descriptionArr))
      obj.findObject("button-div").show(false)
      return true
    }
  }


})

return {
  fillTooltipsIds
}