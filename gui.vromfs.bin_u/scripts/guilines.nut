//-file:plus-string
from "%scripts/dagui_library.nut" import *


let { Point2 } = require("dagor.math")
let { format } = require("string")
//let { get_time_msec } = require("dagor.time")
let { abs } = require("math")
/* guiBox API
  isIntersect(box)      - (bool) return true if box intersect current

  addBox(box)           - modify current box to minimal size which contains both boxes
  cutBox(boxToCutFrom)  - return array of boxes which fill full empty space of boxToCutFrom not intersect with current
                          return null when no intersections with boxToCutFrom
                          return empty array when boxToCutFrom completely inside current box

  incSize(kAdd, kMul)   - increase box size around
  setFromDaguiObj(obj)  - set size and pos from dagui object params
  cloneBox(incSize = 0) - clones box. can increase new box size when incSize != 0
  getBlkText(tag)       - generate text with this tag for replaceContentFromText in guiScene


  LinesGenerator API
  createLinkLines(links, obstacles, interval = 0, lineWidth = 1, priority = 0)
                     - return { lines = array(::GuiBox), dots0 = array(Point2), dots1  = array(Point2)}
                     - links = array([box from, box to])
                     - obstacles = array(::GuiBox)
                     - interval - minimum interval between lines
                     - priority - start priority

  findGoodPos(obj, axis, obstacles, min, max, bestPos = null)   - integer
                     - search good position for dagui object by axis to not intersect with any obstacles
                     - between min and max value
                     - preffered bestPos, but if it null, than middle pos between min and max.
                     - return null when not found any position without intersect something

  getLinkLinesMarkup(config)
                     - config = {
                         startObjContainer - container using for find start's views
                         endObjContainer - container using for find end's views
                         lineInterval - minimal interval between lines
                         lineWidth - width of lines
                         obstacles - list of object (or object id) to view (required) which will be taken into
                         account in the lines generation. in addition to linked objects
                         links = [
                           {
                             start - object (or object id) to view (required)
                             or
                             {
                               obj - object (or object id) to view (required)
                               priority - priority of obstacles from lines_priorities (lines_priorities.TARGET by default)
                             }
                             end - object (or object id) to view (required)
                             or
                              {
                               obj - object (or object id) to view (required)
                               priority - priority of obstacles from lines_priorities (lines_priorities.TEXT by default)
                             }
                           }
                         ]
                       }

  generateLinkLinesMarkup(links, obstacleBoxList, interval = "@helpLineInterval", width = "@helpLineWidth")
                     - links - pairs of boxes which need link
                     - obstacleBoxList - lines will try to come round boxes in this list
                     - interval - minimal interval between lines
                     - width - line width
*/

enum lines_priorities { //lines intersect priority
  OBSTACLE = 0
  TARGET   = 1,
  LINE     = 2,
  TEXT     = 3,

  MAXIMUM  = 3
}

::GuiBox <- class {
  c1 = null  //[x1, y1]
  c2 = null  //[x2, y2]
  priority = 0
  isToStringForDebug = true

  constructor(vx1 = 0, vy1 = 0, vx2 = 0, vy2 = 0, vpriority = 0) {
    this.c1 = [vx1, vy1]
    this.c2 = [vx2, vy2]
    this.priority = vpriority
  }

  function setFromDaguiObj(obj) {
    let size = obj.getSize()
    let pos = obj.getPosRC()
    this.c1 = [pos[0], pos[1]]
    this.c2 = [pos[0] + size[0], pos[1] + size[1]]
    return this
  }

  function addBox(box) {
    for (local i = 0; i < 2; i++) {
      if (box.c1[i] < this.c1[i])
        this.c1[i] = box.c1[i]
      if (box.c2[i] > this.c2[i])
        this.c2[i] = box.c2[i]
    }
  }

  function _tostring() {
    return format("GuiBox((%d,%d), (%d,%d)%s)", this.c1[0], this.c1[1], this.c2[0], this.c2[1],
      this.priority ? (", priority = " + this.priority) : "")
  }

  function isIntersect(box) {
    return  !(box.c1[0] >= this.c2[0] || this.c1[0] >= box.c2[0]
           || box.c1[1] >= this.c2[1] || this.c1[1] >= box.c2[1])
  }

  function isInside(box) {
    return   (box.c1[0] <= this.c1[0] && this.c2[0] <= box.c2[0]
           && box.c1[1] <= this.c1[1] && this.c2[1] <= box.c2[1])
  }

  function getIntersectCorner(box) {
    if (!this.isIntersect(box))
      return null

    return Point2((box.c2[0] > this.c1[0]) ? this.c1[0] : this.c2[0],
                    (box.c2[1] > this.c1[1]) ? this.c1[1] : this.c2[1])
  }

  function cutBox(box) { //return array of boxes cutted from box
    if (!this.isIntersect(box))
      return null

    let cutList = []
    if (box.c1[0] < this.c1[0])
      cutList.append(::GuiBox(box.c1[0], box.c1[1], this.c1[0], box.c2[1]))
    if (box.c2[0] > this.c2[0])
      cutList.append(::GuiBox(this.c2[0], box.c1[1], box.c2[0], box.c2[1]))

    let offset1 = max(this.c1[0], box.c1[0])
    let offset2 = min(this.c2[0], box.c2[0])
    if (box.c1[1] < this.c1[1])
      cutList.append(::GuiBox(offset1, box.c1[1], offset2, this.c1[1]))
    if (box.c2[1] > this.c2[1])
      cutList.append(::GuiBox(offset1, this.c2[1], offset2, box.c2[1]))

    return cutList
  }

  function incPos(inc) {
    for (local i = 0; i < 2; i++) {
      this.c1[i] += inc[i]
      this.c2[i] += inc[i]
    }
    return this
  }

  function incSize(kAdd, kMul = 0) {
    for (local i = 0; i < 2; i++) {
      local inc = kAdd
      if (kMul)
        inc += ((this.c2[i] - this.c1[i]) * kMul).tointeger()
      if (inc) {
        this.c1[i] -= inc
        this.c2[i] += inc
      }
    }
    return this
  }

  function cloneBox(incSzX = 0, incSzY = null) {
    incSzY = incSzY ?? incSzX
    return ::GuiBox(this.c1[0] - incSzX, this.c1[1] - incSzY, this.c2[0] + incSzX, this.c2[1] + incSzY)
  }

  function getBlkText(tag) {
    return format("%s { size:t='%d, %d'; pos:t='%d, %d'; position:t='absolute' } ", tag, this.c2[0] - this.c1[0], this.c2[1] - this.c1[1], this.c1[0], this.c1[1])
  }
}

function getHelpDotMarkup(point /*Point2*/ , tag = "helpLineDot") {
  return format("%s { pos:t='%d-0.5w, %d-0.5h'; position:t='absolute' } ", tag, point.x.tointeger(), point.y.tointeger())
}

::LinesGenerator <- {
}

::LinesGenerator.getLinkLinesMarkup <- function getLinkLinesMarkup(config) {
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
    let startBlock = ::guiTutor.getBlockFromObjData(linkDescriprion.start, startObjContainer)
    if (!startBlock)
      continue

    startBlock.box.priority = getTblValue("priority", linkDescriprion.start, lines_priorities.TEXT)
    boxList.append(startBlock.box)

    let endBlock = ::guiTutor.getBlockFromObjData(linkDescriprion.end, endObjContainer)
    if (!endBlock)
      continue

    endBlock.box.priority = getTblValue("priority", linkDescriprion.end, lines_priorities.TARGET)
    boxList.append(endBlock.box)

    links.append([endBlock.box, startBlock.box])
  }

  let lineInterval = config?.lineInterval ?? "@helpLineInterval"
  let lineWidth = getTblValue("lineWidth", config, "@helpLineWidth")

  let obstacles = getTblValue("obstacles", config, null)
  if (obstacles != null)
    foreach (_idx, obstacle in obstacles) {
      let obstacleBlock = ::guiTutor.getBlockFromObjData(obstacle, startObjContainer) ||
                                                ::guiTutor.getBlockFromObjData(obstacle, endObjContainer)
      if (!obstacleBlock)
        continue

      obstacleBlock.box.priority = getTblValue("priority", obstacle, lines_priorities.OBSTACLE)
      boxList.append(obstacleBlock.box)
    }

  return this.generateLinkLinesMarkup(links, boxList, lineInterval, lineWidth)
}

::LinesGenerator.generateLinkLinesMarkup <- function generateLinkLinesMarkup(links, obstacleBoxList, interval = "@helpLineInterval", width = "@helpLineWidth") {
  let guiScene = get_cur_gui_scene()
  let lines = this.createLinkLines(links, obstacleBoxList, guiScene.calcString(interval, null),
                                                 guiScene.calcString(width, null))

  let shadowOffset = to_pixels("1@helpLineShadowOffset")
  let shadowOffsetArr = [ shadowOffset, shadowOffset ]
  let shadowOffsetP2 = Point2(shadowOffset, shadowOffset)

  local data = []
  foreach (box in lines.lines)
    data.append(box.cloneBox().incPos(shadowOffsetArr).getBlkText("helpLineShadow"))
  foreach (dot in lines.dots0)
    data.append(getHelpDotMarkup(dot + shadowOffsetP2, "helpLineDotShadow"))
  foreach (box in lines.lines)
    data.append(box.getBlkText("helpLine"))
  foreach (dot in lines.dots0)
    data.append(getHelpDotMarkup(dot, "helpLineDot"))

  return "".join(data, true)
}

::LinesGenerator.createLinkLines <- function createLinkLines(links, obstacles, interval = 0, lineWidth = 1, priority = 0, initial = true) {
  let res = {
    lines = []
    dots0 = []
    dots1 = []
  }
  if (initial) {
    let _links = links
    links = []
    for (local i = _links.len() - 1; i >= 0; i--) //reverse to save order of links generation
      links.append(_links[i])
    let _obstacles = obstacles
    obstacles = []
    for (local i = 0; i < _obstacles.len(); i++)
      if (_obstacles[i].priority >= priority)
        obstacles.append(interval ? _obstacles[i].cloneBox(interval) : _obstacles[i])
    this.checkLinkIntersect(res, links)
  }
  else
    for (local i = obstacles.len() - 1; i >= 0; i--)
      if (obstacles[i].priority < priority)
        obstacles.remove(i)

  this.genMonoLines  (res, links, obstacles, interval, lineWidth, priority)
  this.genDoubleLines(res, links, obstacles, interval, lineWidth, priority)

  //local _timer = get_time_msec()
  //dlog("GP: after priority " + priority + ", links " + links.len() + ", obstacles = " + obstacles.len() + ", time = " + (get_time_msec() - _timer))
  if (links.len() && priority < lines_priorities.MAXIMUM) {
    let addRes = ::LinesGenerator.createLinkLines(links, obstacles, interval, lineWidth, priority + 1, false)
    foreach (key in ["lines", "dots0", "dots1"])
      res[key].extend(addRes[key])
  }
  return res
}

::LinesGenerator.checkLinkIntersect <- function checkLinkIntersect(res, links) {
  for (local i = links.len() - 1; i >= 0; i--) {
    let link = links[i]
    let dot = link[1].getIntersectCorner(link[0])
    if (!dot)
      continue

    res.dots0.append(dot)
    res.dots1.append(dot)
    links.remove(i)
  }
  return res
}

::LinesGenerator.genMonoLines <- function genMonoLines(res, links, obstacles, interval, lineWidth, priority) {
  for (local i = links.len() - 1; i >= 0; i--) {
    let link = links[i]
    //find box of available lines
    local checkBox = null
    local axis = 0 //intersection axis
    for (local a = 0; a < 2; a++)
      if (link[0].c2[a] > link[1].c1[a]
        && link[1].c2[a] > link[0].c1[a]) {
        axis = a
        checkBox = ::GuiBox()
        checkBox.c1[1 - a] = min(link[0].c2[1 - a], link[1].c2[1 - a])
        checkBox.c2[1 - a] = max(link[0].c1[1 - a], link[1].c1[1 - a])
        checkBox.c1[a] = max(link[0].c1[a], link[1].c1[a])
        checkBox.c2[a] = min(link[0].c2[a], link[1].c2[a])
        break
      }
    if (!checkBox)
      continue

    //count available diapasons array by obstacles
    let diapason = this.monoLineCountDiapason(link, checkBox, axis, obstacles)
    if (!diapason || !diapason.len())
      continue

    //search best position from available diapasons array
    let pos = this.monoLineGetBestPos(diapason, checkBox, axis, lineWidth)
    if (pos == null)
      continue

    //add lines and dots
    checkBox.c1[axis] = pos
    checkBox.c2[axis] = pos + lineWidth
    res.lines.append(checkBox)
    this.addLinesBoxes(obstacles, [checkBox], priority, interval)

    let dotPos = pos + (0.5 * lineWidth).tointeger()
    let dot0 = this.getP2byAxisCoords(axis, dotPos, checkBox.c1[1 - axis])
    let dot1 = this.getP2byAxisCoords(axis, dotPos, checkBox.c2[1 - axis])
    let invertDots = link[0].c1[1 - axis] > link[1].c1[1 - axis]
    res.dots0.append(invertDots ? dot1 : dot0)
    res.dots1.append(invertDots ? dot0 : dot1)
    links.remove(i)
  }
  return res
}

::LinesGenerator.monoLineCountDiapason <- function monoLineCountDiapason(link, checkBox, axis, obstacles) {
  //check obstacles to get available diapaosn of line variants
  local diapason = [[checkBox.c1[axis], checkBox.c2[axis]]]
  for (local j = obstacles.len() - 1; j >= 0; j--) {
    let box = obstacles[j]
    if (!box.isIntersect(checkBox))
      continue
    if (link && (link[0].isInside(box) || link[1].isInside(box)))
      continue

    if (box.c1[axis] < checkBox.c1[axis] && box.c2[axis] > checkBox.c2[axis]) {
      diapason = null
      break
    }

    local found = false
    let start = box.c1[axis]
    let end = box.c2[axis]
    for (local d = diapason.len() - 1; d >= 0; d--) {
      let segment = diapason[d]
      if (segment[1] < start)
        break
      if (!found && segment[0] > end)
        continue

      diapason.remove(d)
      if (!found && segment[1] > end)
        diapason.insert(d, [end + 1, segment[1]])
      found = true

      if (segment[0] < start) {
        diapason.insert(d, [segment[0], start - 1])
        break
      }
    }
  }
  return diapason
}

::LinesGenerator.monoLineGetBestPos <- function monoLineGetBestPos(diapason, checkBox, axis, lineWidth, bestPos = null) { //return null -> not found
  if (bestPos == null)
    bestPos = ((checkBox.c1[axis] + checkBox.c2[axis] - lineWidth) / 2).tointeger()

  local found = false
  local pos = 0
  for (local d = diapason.len() - 1; d >= 0; d--) {
    let segment = diapason[d]
    if (segment[1] - segment[0] < lineWidth)
      continue

    if (segment[0] > bestPos) {
      pos = segment[0]
      found = true
      continue
    }

    let _pos = min(bestPos, segment[1] - lineWidth)
    if (!found || (bestPos - _pos) < (pos - bestPos))
      pos = _pos
    found = true
    break
  }
  return found ? pos : null
}

::LinesGenerator.findGoodPos <- function findGoodPos(obj, axis, obstacles, posMin, posMax, bestPos = null) {
  let box = ::GuiBox().setFromDaguiObj(obj)
  let objWidth = box.c2[axis] - box.c1[axis]
  box.c1[axis] = posMin
  box.c2[axis] = posMax

  let diapason = this.monoLineCountDiapason(null, box, axis, obstacles)
  if (diapason && diapason.len())
    return this.monoLineGetBestPos(diapason, box, axis, objWidth, bestPos)
  return null
}

::LinesGenerator.genDoubleLines <- function genDoubleLines(res, links, obstacles, interval, lineWidth, priority) {
  for (local i = links.len() - 1; i >= 0; i--) {
    let link = links[i]
    local zones = this.doubleLineGetZones(link)

    //apply obstacles to zones diapason
    zones = this.doubleLineZoneCheckObstacles(zones, link, obstacles)
    if (!zones.len())
      continue

    //sort by corners priority.  left/top corner is the best
    zones.sort(function(a, b) {
        if (a.axis != b.axis)
          return a.axis ? 1 : -1
        if (a.wayAxis != b.wayAxis)
          return a.wayAxis ? -1 : 1
        if (a.wayAltAxis != b.wayAltAxis)
          return a.wayAltAxis ? -1 : 1
        return 0;
      })

    //choose best double Line
    for (local z = 0; z < zones.len(); z++) {
      let zoneData = zones[z]
      let lineData = this.doubleLineChooseBestInZone(zoneData, link, lineWidth)
      if (!lineData)
        continue

      let axis = zoneData.axis
      let box = zoneData.box
      let halfWidth = (0.5 * lineWidth).tointeger()
      let dot0 = this.getP2byAxisCoords(axis, zoneData.wayAxis ? box.c1[axis] : box.c2[axis], lineData[1])
      let dot1 = this.getP2byAxisCoords(axis, lineData[0], lineData[1])
      let dot2 = this.getP2byAxisCoords(axis, lineData[0], zoneData.wayAltAxis ? box.c2[1 - axis] : box.c1[1 - axis])

      let linesList = [ this.getLineBoxByP2(dot0, dot1, lineWidth)
                          this.getLineBoxByP2(dot1, dot2, lineWidth)
                        ]
      res.lines.extend(linesList)
      this.addLinesBoxes(obstacles, linesList, priority, interval)

      dot0.x += halfWidth
      dot0.y += halfWidth
      dot2.x += halfWidth
      dot2.y += halfWidth
      res.dots0.append(dot0)
      res.dots1.append(dot2)
      links.remove(i)
      break
    }
  }
  return res
}

::LinesGenerator.doubleLineGetZones <- function doubleLineGetZones(link) {
  let zones = []  //list of available zones for double line
                    //{ box, zone, axis, wayAxis, wayAltAxis }
  for (local j = 0; j < 2; j++) { //check all variants, but here can be only 2
    if (link[0].c1[j] > link[1].c1[j]) {  //main way left/top
      if (link[0].c1[1 - j] < link[1].c1[1 - j]) //alt way bottom / right
        zones.append({
          box = this.getBoxByAxis(j, link[1].c1[j], link[0].c1[j], link[0].c1[1 - j], link[1].c1[1 - j])
          zone = [{ start = link[1].c1[j]
                    end   = min(link[0].c1[j],   link[1].c2[j])
                    diapason = [[link[0].c1[1 - j], min(link[1].c1[1 - j], link[0].c2[1 - j])]]
                 }]
          axis = j
          wayAxis = false
          wayAltAxis = true
        })
      if (link[0].c2[1 - j] > link[1].c2[1 - j])  //alt way top / left
        zones.append({
          box = this.getBoxByAxis(j, link[1].c1[j], link[0].c1[j], link[1].c2[1 - j], link[0].c2[1 - j])
          zone = [{ start = link[1].c1[j]
                    end   = min(link[0].c1[j],   link[1].c2[j])
                    diapason = [[max(link[1].c2[1 - j], link[0].c1[1 - j]), link[0].c2[1 - j]]]
                 }]
          axis = j
          wayAxis = false
          wayAltAxis = false
        })
    }
    if (link[0].c2[j] < link[1].c2[j]) {  //main way right / bottom
      if (link[0].c1[1 - j] < link[1].c1[1 - j])  //alt way bottom / right
        zones.append({
          box = this.getBoxByAxis(j, link[0].c2[j], link[1].c2[j], link[0].c1[1 - j], link[1].c1[1 - j])
          zone = [{ start = max(link[0].c2[j], link[1].c1[j])
                    end   = link[1].c2[j]
                    diapason = [[link[0].c1[1 - j], min(link[1].c1[1 - j], link[0].c2[1 - j])]]
                 }]
          axis = j
          wayAxis = true
          wayAltAxis = true
        })
      if (link[0].c2[1 - j] > link[1].c2[1 - j]) //alt way top / left
        zones.append({
          box = this.getBoxByAxis(j, link[0].c2[j], link[1].c2[j], link[1].c2[1 - j], link[0].c2[1 - j])
          zone = [{ start = max(link[0].c2[j], link[1].c1[j])
                    end   = link[1].c2[j]
                    diapason = [[max(link[1].c2[1 - j], link[0].c1[1 - j]), link[0].c2[1 - j]]]
                 }]
          axis = j
          wayAxis = true
          wayAltAxis = false
        })
    }
  }
  return zones
}

::LinesGenerator.doubleLineZoneCheckObstacles <- function doubleLineZoneCheckObstacles(zones, link, obstacles) {
  for (local o = obstacles.len() - 1; o >= 0; o--) {
    let box = obstacles[o]
    for (local z = zones.len() - 1; z >= 0; z--) {
      let zoneData = zones[z]
      if (!box.isIntersect(zoneData.box))
        continue

      if (link[0].isInside(box) || link[1].isInside(box))
        continue //ignore boxes intersect and full override this side

      let count = this.doubleLineCutZoneList(zoneData, box)
      if (!count)
        zones.remove(z)
    }
    if (!zones.len())
      break
  }
  return zones
}

::LinesGenerator.doubleLineCutZoneList <- function doubleLineCutZoneList(zoneData, box) {
  let axis = zoneData.axis
  let zoneList = zoneData.zone
  let wayAxis = zoneData.wayAxis
  let wayAltAxis = zoneData.wayAltAxis

  let zStart = box.c1[axis]
  let zEnd   = box.c2[axis]
  let dStart = box.c1[1 - axis]
  let dEnd   = box.c2[1 - axis]
  for (local z = zoneList.len() - 1; z >= 0; z--) {
    local zone = zoneList[z]
    if (zone.end > zEnd && zone.start < zEnd) {
      let newZone = this.cloneDoubleLineZone(zone)
      zone.end = zEnd
      newZone.start = zEnd + 1
      zoneList.insert(++z, newZone)
      zone = newZone
    }
    else if (zone.end > zStart && zone.start < zStart) {
      let newZone = this.cloneDoubleLineZone(zone)
      zone.end = zStart - 1
      newZone.start = zStart
      zoneList.insert(++z, newZone)
      zone = newZone
    }

    if ((!wayAxis && zone.start > zEnd)
        || (wayAxis && zone.end < zStart))
      continue //inside corners not blocked by box

    local found = false
    let diapason = zone.diapason
    let zoneFree = zone.start >= zEnd || zone.end <= zStart
    for (local d = diapason.len() - 1; d >= 0; d--) {
      let segment = diapason[d]
      if (segment[1] < dStart)
        if (!zoneFree && wayAltAxis) {
          diapason.remove(d)
          continue
        }
        else
          break

      if (!found && segment[0] > dEnd) {
        if (!zoneFree && !wayAltAxis)
          diapason.remove(d)
        continue
      }

      diapason.remove(d)
      if ((zoneFree || wayAltAxis) && !found && segment[1] > dEnd)
        diapason.insert(d, [dEnd + 1, segment[1]])
      found = true

      if ((zoneFree || !wayAltAxis) && segment[0] < dStart) {
        diapason.insert(d, [segment[0], dStart - 1])
        break
      }
    }
    if (!diapason.len())
      zoneList.remove(z)
  }
  return zoneList.len()
}

::LinesGenerator.doubleLineChooseBestInZone <- function doubleLineChooseBestInZone(zoneData, link, lineWidth) {
  let axis = zoneData.axis
  let bestPos =    ((link[1].c1[axis] + link[1].c2[axis] - lineWidth) / 2).tointeger()
  let altBestPos = ((link[0].c1[1 - axis] + link[0].c2[1 - axis] - lineWidth) / 2).tointeger()
  local found = false
  local posAxis = 0
  local posAltAxis = 0
  local bestDiff = 0
  for (local z = zoneData.zone.len() - 1; z >= 0; z--) {
    let zone = zoneData.zone[z]
    if (zone.end - zone.start < lineWidth)
      continue

    let _posAxis = (zone.start > bestPos) ? zone.start : min(bestPos, zone.end - lineWidth)
    local _posAltAxis = 0
    local dFound = false
    let diapason = zone.diapason
    for (local d = diapason.len() - 1; d >= 0; d--) {
      let segment = diapason[d]
      if (segment[1] - segment[0] < lineWidth)
        continue

      if (segment[0] > altBestPos) {
        _posAltAxis = segment[0]
        dFound = true
        continue
      }

      let _dpos = min(altBestPos, segment[1] - lineWidth)
      if (!dFound || (altBestPos - _dpos) < (_posAltAxis - altBestPos))
        _posAltAxis = _dpos
      dFound = true
      break
    }

    if (!dFound)
      continue

    let _bestDiff = abs(_posAxis - bestPos) + abs(_posAltAxis - altBestPos)
    if (!found || _bestDiff < bestDiff) {
      found = true
      bestDiff = _bestDiff
      posAxis = _posAxis
      posAltAxis = _posAltAxis
      if (bestDiff == 0)
        break
    }
  }
  if (found)
    return [posAxis, posAltAxis]
  return null
}

::LinesGenerator.cloneDoubleLineZone <- function cloneDoubleLineZone(zone) {
  let diapason = []
  foreach (d in zone.diapason)
    diapason.append([d[0], d[1]])
  return {
    start = zone.start
    end = zone.end
    diapason = diapason
  }
}

::LinesGenerator.addLinesBoxes <- function addLinesBoxes(obstacles, linesBoxes, priority, interval) {
  if (priority > lines_priorities.LINE)
    return

  foreach (box in linesBoxes) {
    let newBox = interval ? box.cloneBox(interval) : box
    newBox.priority = lines_priorities.LINE
    obstacles.append(newBox)
  }
}

::LinesGenerator.getP2byAxisCoords <- function getP2byAxisCoords(axis, axisValue, altAxisValue) {
  return Point2(axis ? altAxisValue : axisValue, axis ? axisValue : altAxisValue)
}

::LinesGenerator.getBoxByAxis <- function getBoxByAxis(axisIdx, axis0, axis1, altAxis0, altAxis1) {
  if (axisIdx)
    return ::GuiBox(altAxis0, axis0, altAxis1, axis1)
  return ::GuiBox(axis0, altAxis0, axis1, altAxis1)
}

::LinesGenerator.getLineBoxByP2 <- function getLineBoxByP2(dot1, dot2, lineWidth) {
  return ::GuiBox(min(dot1.x, dot2.x), min(dot1.y, dot2.y),
                  max(dot1.x, dot2.x) + ((dot1.x == dot2.x) ? lineWidth : 0),
                  max(dot1.y, dot2.y) + ((dot1.y == dot2.y) ? lineWidth : 0))
}
