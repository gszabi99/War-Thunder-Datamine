from "%scripts/dagui_library.nut" import *
let { Point2 } = require("dagor.math")
let { GuiBox, getBlockFromObjData, getBoxBlkText } = require("%scripts/guiBox.nut")
let { format } = require("string")
let { LinesPriorities, createLinkLines, findGoodPosForBox
} = require("%globalScripts/guiGeom/linesGenerator.nut")

function getHelpDotMarkup(point  , tag = "helpLineDot") {
  return format("%s { pos:t='%d-0.5w, %d-0.5h'; position:t='absolute' } ", tag, point.x.tointeger(), point.y.tointeger())
}

function findGoodPos(obj, axis, obstacles, posMin, posMax, bestPos = null) {
  let box = GuiBox().setFromDaguiObj(obj)
  return findGoodPosForBox(box, axis, obstacles, posMin, posMax, bestPos)
}

function generateLinkLinesMarkup(links, obstacleBoxList, interval = "@helpLineInterval", width = "@helpLineWidth") {
  let guiScene = get_cur_gui_scene()
  let lines = createLinkLines(links, obstacleBoxList, guiScene.calcString(interval, null),
                                                 guiScene.calcString(width, null))

  let shadowOffset = to_pixels("1@helpLineShadowOffset")
  let shadowOffsetArr = [ shadowOffset, shadowOffset ]
  let shadowOffsetP2 = Point2(shadowOffset, shadowOffset)

  local data = []
  foreach (box in lines.lines)
    data.append(getBoxBlkText(box.cloneBox().incPos(shadowOffsetArr), "helpLineShadow"))
  foreach (dot in lines.dots0)
    data.append(getHelpDotMarkup(dot + shadowOffsetP2, "helpLineDotShadow"))
  foreach (box in lines.lines)
    data.append(getBoxBlkText(box, "helpLine"))
  foreach (dot in lines.dots0)
    data.append(getHelpDotMarkup(dot, "helpLineDot"))

  return "".join(data, true)
}

function getLinkLinesMarkup(config) {
  if (!config)
    return ""

  let startObjContainer = getTblValue("startObjContainer", config, null)
  if (!checkObj(startObjContainer))
    return ""

  let endObjContainer = getTblValue("endObjContainer", config, null)
  if (!checkObj(endObjContainer))
    return ""

  let linksDescription = getTblValue("links", config)
  if (!linksDescription)
    return ""

  let boxList = []
  let links = []
  foreach (_idx, linkDescriprion in linksDescription) {
    let startBlock = getBlockFromObjData(linkDescriprion.start, startObjContainer)
    if (!startBlock)
      continue

    startBlock.box.priority = getTblValue("priority", linkDescriprion.start, LinesPriorities.TEXT)
    boxList.append(startBlock.box)

    let endBlock = getBlockFromObjData(linkDescriprion.end, endObjContainer)
    if (!endBlock)
      continue

    endBlock.box.priority = getTblValue("priority", linkDescriprion.end, LinesPriorities.TARGET)
    boxList.append(endBlock.box)

    links.append([endBlock.box, startBlock.box])
  }

  let lineInterval = config?.lineInterval ?? "@helpLineInterval"
  let lineWidth = getTblValue("lineWidth", config, "@helpLineWidth")

  let obstacles = getTblValue("obstacles", config, null)
  if (obstacles != null)
    foreach (_idx, obstacle in obstacles) {
      let obstacleBlock = getBlockFromObjData(obstacle, startObjContainer) ||
                                                getBlockFromObjData(obstacle, endObjContainer)
      if (!obstacleBlock)
        continue

      obstacleBlock.box.priority = getTblValue("priority", obstacle, LinesPriorities.OBSTACLE)
      boxList.append(obstacleBlock.box)
    }

  return generateLinkLinesMarkup(links, boxList, lineInterval, lineWidth)
}

return {
  getLinkLinesMarkup
  generateLinkLinesMarkup
  findGoodPos
}