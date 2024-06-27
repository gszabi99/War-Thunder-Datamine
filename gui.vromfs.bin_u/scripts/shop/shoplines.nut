//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { stripTags } = require("%sqstd/string.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { buildDateStr } = require("%scripts/time.nut")
let { format } = require("string")
let { abs } = require("math")

let pad1 = "1@lines_pad"
let pad2 = "1@lines_pad"
let interval1 = "1@lines_shop_interval"
let interval2 = "1@lines_shop_interval"
let allowToModifyed = [
  "vertical",
  "horisontal",
  "alarmIcon_vertical",
  "alarmIcon_horizontal"
]

function getLineType(r0, c0, r1, c1, lineConfig) {
  let {reqAir = null} = lineConfig
  let isFakeUnitReq = reqAir?.isFakeUnit

  if (c0 == c1)
    return "vertical"
  if (r0 == r1)
    return "horizontal"
  if (isFakeUnitReq)
    return "fakeUnitReq"
  return "double"
}

let ShopLines = class {
  lastLineIndex = 1
  linesByContainer = null

  constructor() {
    this.linesByContainer = {}
  }

  function getLinesData(containerId) {
    local linesData = this.linesByContainer?[containerId]
    if (linesData == null) {
      linesData = { avalible = {}, added = {} }
      this.linesByContainer[containerId] <- linesData
    }
    return linesData
  }

  function getAddedLinesByType(containerId, lineType) {
    local linesData = this.getLinesData(containerId)
    local lineTypeArr = linesData.added?[lineType]
    if (lineTypeArr == null) {
      lineTypeArr = []
      linesData.added[lineType] <- lineTypeArr
    }
    return lineTypeArr
  }


  function addToLineData(containerId, lineType, objForAdd) {
    let lineTypeArr = this.getAddedLinesByType(containerId, lineType)
    lineTypeArr.append({obj = objForAdd})
  }


  function prepareGenerateLines() {
    foreach (linesData in this.linesByContainer) {
      if (linesData == null)
        continue
      let avalibleLines = linesData.avalible
      let addedLines = linesData.added
      foreach(lineType, added in addedLines) {
        if (added == null)
          continue
        let avalibles = avalibleLines?[lineType]
        if (avalibles == null)
          avalibleLines[lineType] <- added
        else
          foreach (lineData in added)
            avalibles.append(lineData)

        addedLines[lineType] = []
      }
    }
  }

  function completeGenerateLines(guiScene) {
    foreach (linesData in this.linesByContainer) {
      if (linesData == null)
        continue
      let linesForHide = linesData.avalible
      foreach(lineType, lines in linesForHide) {
        if (allowToModifyed.contains(lineType)) {
          foreach (lineData in lines)
            lineData.obj.show(false)
        } else {
          foreach (lineData in lines)
            guiScene.destroyElement(lineData.obj)
          linesForHide[lineType] = []
        }
      }
    }
  }


  function getAlarmIconTooltip(lineConfig) {
    let { air = null, reqAir = null } = lineConfig
    let endReleaseDate = reqAir?.getEndRecentlyReleasedTime() ?? 0
    if (endReleaseDate > 0) {
      let hasReqAir = (air?.reqAir ?? "") != ""
      let locId = air?.futureReqAirDesc ?? (hasReqAir ? "shop/futureReqAir/desc" : "shop/futureReqAir/desc/withoutReqAir")
      return loc(locId, {
        futureReqAir = getUnitName(air?.futureReqAir)
        curAir = getUnitName(air)
        reqAir = hasReqAir ? getUnitName(air.reqAir) : ""
        date = buildDateStr(endReleaseDate)
      })
    }
    return ""
  }


  function createAlarmIcon(lineType, r0, c0, r1, c1, lineConfig = {}, edge = "no") {
    let { air = null, reqAir = null, arrowCount = 1, hasNextFutureReqLine = false } = lineConfig
    let isFutureReqAir = air?.futureReqAir != null && air.futureReqAir == reqAir?.name
    let isMultipleArrow = arrowCount > 1
    let isLineParallelFutureReqLine = isMultipleArrow
      && !isFutureReqAir && air?.futureReqAir != null
    let isLineShiftedToRight = hasNextFutureReqLine

    local posX = 0
    local height = 0
    local width = 0
    local posY = 0
    local offset = isLineParallelFutureReqLine ? -0.1
        : isLineShiftedToRight ? 0.1
        : 0

    this.lastLineIndex++
    let idString = $"id:t='line_{this.lastLineIndex}';"
    let alarmTooltip = stripTags(this.getAlarmIconTooltip(lineConfig))
    let alarmIconFormat = "".concat("shopAlarmIcon { %s pos:t='%s, %s'; onEdge:t='%s'; tooltip:t='",
        alarmTooltip, "'; } ")

    if (lineType == "alarmIcon_horizontal") {
      posX = $"{(c0 + 1)}@shop_width - {interval1}"
      width = $"{(c1 - c0 - 1)}@shop_width + {interval1} + {interval2}"
      posY = $"{(r0 + 0.5 + offset)}@shop_height - 0.5@modArrowWidth"
      return format(alarmIconFormat, idString, $"{posX} + 0.5*({width}) - 0.5w",
        $"{posY} + 0.5@modArrowWidth - 0.5h", edge)

    } else if (lineType == "alarmIcon_vertical") {
      posX = $"{(c0 + 0.5 + offset)}@shop_width - 0.5@modArrowWidth"
      height = $"{pad1} + {pad2} + {(r1 - r0 - 1)}@shop_height"
      posY = $"{(r0 + 1)}@shop_height - {pad1}"
      return format(alarmIconFormat, idString, $"{posX} + 0.5@modArrowWidth - 0.5w",
        $"{posY} + 0.5*({height}) - 0.5h", edge)
    }
    return null
  }


  function createLine(lineType, r0, c0, r1, c1, status, lineConfig = {}) {
    let { air = null, reqAir = null, arrowCount = 1, hasNextFutureReqLine = false } = lineConfig
    let isFutureReqAir = air?.futureReqAir != null && air.futureReqAir == reqAir?.name
    let isMultipleArrow = arrowCount > 1
    let isLineParallelFutureReqLine = isMultipleArrow
      && !isFutureReqAir && air?.futureReqAir != null
    let isLineShiftedToRight = hasNextFutureReqLine

    local posX = 0
    local height = 0
    local width = 0
    local posY = 0
    local offset = isLineParallelFutureReqLine ? -0.1
        : isLineShiftedToRight ? 0.1
        : 0

    if (lineType == "")
      lineType = getLineType(r0, c0, r1, c1, lineConfig)

    this.lastLineIndex++
    let idString = $"id:t='line_{this.lastLineIndex}';"
    local lines = ""
    let arrowProps = $"shopStat:t='{status}'; isOutlineIcon:t={isFutureReqAir ? "yes" : "no"};"
    let arrowFormat = "".concat("shopArrow { %s type:t='%s'; size:t='%s, %s';",
      "pos:t='%s, %s'; rotation:t='%s';", arrowProps, " } ")
    let lineFormat = "".concat("shopLine { size:t='%s, %s'; pos:t='%s, %s'; rotation:t='%s';",
      arrowProps, " } ")
    let angleFormat = "".concat("shopAngle { size:t='%s, %s'; pos:t='%s, %s'; rotation:t='%s';",
      arrowProps, " } ")

    if (lineType == "vertical") {
      posX = $"{(c0 + 0.5 + offset)}@shop_width - 0.5@modArrowWidth"
      height = $"{pad1} + {pad2} + {(r1 - r0 - 1)}@shop_height"
      posY = $"{(r0 + 1)}@shop_height - {pad1}"
      lines += format(arrowFormat, idString, "vertical", "1@modArrowWidth", height,
        posX, posY, "0")

    }
    else if (lineType == "horizontal") {
      posX = $"{(c0 + 1)}@shop_width - {interval1}"
      width = $"{(c1 - c0 - 1)}@shop_width + {interval1} + {interval2}"
      posY = $"{(r0 + 0.5 + offset)}@shop_height - 0.5@modArrowWidth"
      lines += format(arrowFormat, idString, "horizontal", width, "1@modArrowWidth",
        posX, posY, "0")

    }
    else if (lineType == "fakeUnitReq") { //special line for fake unit. Line is go to unit plate on side
      lines += "tdiv { " + idString
      lines += format(lineFormat,
                       pad1 + " + " + (r1 - r0 - 0.5) + "@shop_height", //height
                       "1@modLineWidth", //width
                       (c0 + 0.5) + "@shop_width" + ((c0 > c1) ? "- 0.5@modLineWidth" : "+ 0.5@modLineWidth"), //posX
                       (r0 + 1) + "@shop_height - " + pad1 + ((c0 > c1) ? "+w" : ""), // posY
                       (c0 > c1) ? "-90" : "90")
      lines += format(arrowFormat, "",
                       "horizontal",  //type
                       (abs(c1 - c0) - 0.5) + "@shop_width + " + interval1, //width
                       "1@modArrowWidth", //height
                       (c1 > c0 ? (c0 + 0.5) : c0) + "@shop_width" + (c1 > c0 ? "" : (" - " + interval1)), //posX
                       (r1 + 0.5) + "@shop_height - 0.5@modArrowWidth", // posY
                       (c0 > c1) ? "180" : "0")
      lines += format(angleFormat,
                       "1@modAngleWidth", //width
                       "1@modAngleWidth", //height
                       (c0 + 0.5) + "@shop_width - 0.5@modAngleWidth", //posX
                       (r1 + 0.5) + "@shop_height - 0.5@modAngleWidth", // posY
                       (c0 > c1 ? "-90" : "0"))
      lines += "}"
    }
    else {
      let lh = 0
      offset = isMultipleArrow ? 0.1 : 0
      let arrowOffset = c0 > c1 ? -offset : offset
      lines += "tdiv { " + idString
      lines += format(lineFormat,
                       pad1 + " + " + lh + "@shop_height", //height
                       "1@modLineWidth", //width
                       (c0 + 0.5 + arrowOffset) + "@shop_width" + ((c0 > c1) ? "-" : "+") + " 0.5@modLineWidth", //posX
                       (r0 + 1) + "@shop_height - " + pad1 + ((c0 > c1) ? "+ w " : ""), // posY
                       (c0 > c1) ? "-90" : "90")

      lines += format(lineFormat,
                      (abs(c1 - c0) - offset) + "@shop_width",
                      "1@modLineWidth", //height
                      (min(c0, c1) + 0.5 + (c0 > c1 ? 0 : offset)) + "@shop_width",
                      (lh + r0 + 1) + "@shop_height - 0.75@modLineWidth",
                      "0")
      lines += format(angleFormat,
                       "1@modAngleWidth", //width
                       "1@modAngleWidth", //height
                       (c0 + 0.5 + arrowOffset) + "@shop_width - 0.5@modAngleWidth", //posX
                       (lh + r0 + 1) + "@shop_height - 0.75@modLineWidth", // posY
                       (c0 > c1 ? "-90" : "0"))
      lines += format(arrowFormat, "",
                      "vertical",
                      "1@modArrowWidth",
                      pad2 + " + " + (r1 - r0 - 1 - lh) + "@shop_height + 0.25@modArrowWidth",
                      (c1 + 0.5) + "@shop_width - 0.5@modArrowWidth",
                      (lh + r0 + 1) + "@shop_height - 0.25@modLineWidth",
                      "0")
      lines += format(angleFormat,
                       "1@modAngleWidth", //width
                       "1@modAngleWidth", //height
                       (c1 + 0.5) + "@shop_width - 0.5@modAngleWidth",
                       (lh + r0 + 1) + "@shop_height - 0.75@modLineWidth",
                       (c0 > c1 ? "90" : "180"))
      lines += "}"
    }

    return lines
  }


  function modifyLine(lineObj, r0, c0, r1, c1, lineType, lineConfig, status, edge = "no") {
    let { air = null, reqAir = null, arrowCount = 1, hasNextFutureReqLine = false } = lineConfig
    let isFutureReqAir = air?.futureReqAir != null && air.futureReqAir == reqAir?.name
    let isMultipleArrow = arrowCount > 1
    let isLineParallelFutureReqLine = isMultipleArrow
      && !isFutureReqAir && air?.futureReqAir != null
    let isLineShiftedToRight = hasNextFutureReqLine

    local posX = 0
    local height = 0
    local width = 0
    local posY = 0

    let offset = isLineParallelFutureReqLine ? -0.1
        : isLineShiftedToRight ? 0.1
        : 0

    if (lineType == "vertical") {
      posX = $"{(c0 + 0.5 + offset)}@shop_width - 0.5@modArrowWidth"
      height = $"{pad1} + {pad2} + {(r1 - r0 - 1)}@shop_height"
      posY = $"{(r0 + 1)}@shop_height - {pad1}"
      lineObj.pos = $"{posX}, {posY}"
      lineObj["isOutlineIcon"] = isFutureReqAir ? "yes" : "no"
      lineObj.size = $"1@modArrowWidth, {height}"

    } else if (lineType == "horizontal") {
      posX = $"{(c0 + 1)}@shop_width - {interval1}"
      width = $"{(c1 - c0 - 1)}@shop_width + {interval1} + {interval2}"
      posY = $"{(r0 + 0.5 + offset)}@shop_height - 0.5@modArrowWidth"
      lineObj.pos = $"{posX}, {posY}"
      lineObj["isOutlineIcon"] = isFutureReqAir ? "yes" : "no"
      lineObj.width = width

    } else if (lineType == "alarmIcon_horizontal") {
      posX = $"{(c0 + 1)}@shop_width - {interval1}"
      width = $"{(c1 - c0 - 1)}@shop_width + {interval1} + {interval2}"
      posY = $"{(r0 + 0.5 + offset)}@shop_height - 0.5@modArrowWidth"
      lineObj.pos = $"{posX} + 0.5*({width}) - 0.5w, {posY} + 0.5@modArrowWidth - 0.5h"
      lineObj.onEdge = edge
      lineObj.tooltip = this.getAlarmIconTooltip(lineConfig)

    } else if (lineType == "alarmIcon_vertical") {
      posX = $"{(c0 + 0.5 + offset)}@shop_width - 0.5@modArrowWidth"
      height = $"{pad1} + {pad2} + {(r1 - r0 - 1)}@shop_height"
      posY = $"{(r0 + 1)}@shop_height - {pad1}"
      lineObj.pos = $"{posX} + 0.5@modArrowWidth - 0.5w, {posY} + 0.5*({height}) - 0.5h"
      lineObj.onEdge = edge
      lineObj.tooltip = this.getAlarmIconTooltip(lineConfig)
    }

    lineObj.shopStat = status
    lineObj.show(true)
  }

  function tryModifyLine(containerIndex, lineType, lc, status, edge = "no") {
    if (!allowToModifyed.contains(lineType))
      return false

    let linesData = this.getLinesData(containerIndex)
    let avalibleLines = linesData.avalible?[lineType]
    let avalibleCount = avalibleLines?.len() ?? 0
    if (avalibleCount > 0) {
      let lineData = avalibleLines?[avalibleCount-1]
      this.modifyLine(lineData?.obj, lc.line[0], lc.line[1], lc.line[2], lc.line[3], lineType, lc, status, edge)
      avalibleLines?.remove(avalibleCount-1)

      local modifiedLines = this.getAddedLinesByType(containerIndex,lineType)
      modifiedLines.append(lineData)
      return true
    }
    return false
  }

  function addLine(handler, arrowsContainer, lineType, containerIndex, lc, status) {
    let lineBlk = this.createLine(lineType, lc.line[0], lc.line[1], lc.line[2], lc.line[3], status, lc)
    handler.guiScene.appendWithBlk(arrowsContainer, lineBlk, this)
    let lineObj = arrowsContainer.findObject($"line_{this.lastLineIndex}")
    this.addToLineData(containerIndex, lineType, lineObj)
  }

  function addAlarmIcon(handler, arrowsContainer, lineType, containerIndex, lc, edge = "no") {
    let alarmBlk = this.createAlarmIcon(lineType, lc.line[0], lc.line[1], lc.line[2], lc.line[3], lc, edge)
    handler.guiScene.appendWithBlk(arrowsContainer, alarmBlk, this)
    let lineObj = arrowsContainer.findObject($"line_{this.lastLineIndex}")
    this.addToLineData(containerIndex, lineType, lineObj)
  }

  function modifyOrAddLine(handler, arrowsContainer, alarmIconsContainer,
      containerIndex, lc, status, edge = "no") {
    let { air = null, reqAir = null } = lc

    let lineType = getLineType(lc.line[0], lc.line[1], lc.line[2], lc.line[3], lc)
    if (!this.tryModifyLine(containerIndex, lineType, lc, status, edge))
      this.addLine(handler, arrowsContainer, lineType, containerIndex, lc, status)

    let isFutureReqAir = air?.futureReqAir != null && air.futureReqAir == reqAir?.name
    if (isFutureReqAir) {
      let alarmIconType = $"alarmIcon_{lineType}"
      if (!this.tryModifyLine(containerIndex, alarmIconType, lc, status, edge)) {
        this.addAlarmIcon(handler, alarmIconsContainer, alarmIconType, containerIndex, lc, edge)
      }
    }
  }

}

return {
  ShopLines
}