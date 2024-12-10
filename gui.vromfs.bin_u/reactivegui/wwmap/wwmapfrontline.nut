from "%rGui/globals/ui_library.nut" import *

let { pow, sqrt } = require("math")
let { createZoneFrontLine, getZones } = require("%rGui/wwMap/wwMapZonesData.nut")
let { zoneSideType } = require("%rGui/wwMap/wwMapTypes.nut")
let { zonesSides } = require("%rGui/wwMap/wwMapStates.nut")
let { isPlayerSide } = require("%rGui/wwMap/wwOperationStates.nut")
let { getMapColor } = require("%rGui/wwMap/wwMapUtils.nut")
let { activeAreaBounds, gridWidth } = require("%rGui/wwMap/wwOperationConfiguration.nut")

let partsCache = {}

let distance = @(p1, p2) sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2))

function equationOfTheLine(p1, p2) {
  let a = p2.y - p1.y
  let b = p1.x - p2.x
  let c = -p1.x * (p2.y - p1.y) + p1.y * (p2.x - p1.x)
  return { a, b, c }
}

function intersection(eq1, eq2) {
  let d = eq1.a * eq2.b - eq1.b * eq2.a
  let dx = -eq1.c * eq2.b + eq1.b * eq2.c
  let dy = -eq1.a * eq2.c + eq1.c * eq2.a
  return { x = dx / d, y = dy / d }
}

function movePoint(l, ip) {
  if (distance(l.p1, ip) < distance(ip, l.p2)) {
    l.p1.x = ip.x
    l.p1.y = ip.y
  }
  else {
    l.p2.x = ip.x
    l.p2.y = ip.y
  }
}

function findIntersection(l1, l2) {
  let eq1 = equationOfTheLine(l1.p1, l1.p2)
  let eq2 = equationOfTheLine(l2.p1, l2.p2)
  let ip = intersection(eq1, eq2)
  movePoint(l1, ip)
  movePoint(l2, ip)
}

function findNearest(point, lines) {
  let result = { dist = 1, point = null, line = null }
  for (local i = 0; i < lines.len(); i++) {
    let line = lines[i]
    local dist = distance(line.p1, point)
    if (dist < result.dist) {
      result.dist = dist
      result.point = line.p1
      result.line = line
    }
    dist = distance(point, line.p2)
    if (dist < result.dist) {
      result.dist = dist
      result.point = line.p2
      result.line = line
    }
  }

  return result
}

function joinFrontLine(lines) {
  let delta = 0.02
  let res = []
  while (lines.len() > 0) {
    let line = lines.pop()

    local nearest = findNearest(line.p1, lines)
    if (nearest.dist > 0 && nearest.dist < delta)
      findIntersection(line, nearest.line)

    nearest = findNearest(line.p2, lines)
    if (nearest.dist > 0 && nearest.dist < delta)
      findIntersection(line, nearest.line)

    res.append(line)
  }
  return res
}

function findCommonPart(zone1, zone2) {
  let hash = ".".join([zone1.id, zone2.id].sort(@(v1, v2) v1 <=> v2))
  if (partsCache?[hash] != null)
    return null
  partsCache[hash] <- true

  local res = {}
  zone1.parts.each(@(p1) zone2.parts.each(function(p2) {
    if (p1.hash == p2.hash) {
      res = p1
      p1.ownZones <- [zone1.id, zone2.id].filter(@(id) zonesSides.get()[id] != zoneSideType.SIDE_NONE)
    }
  }))
  return res.len() > 0 ? res : null
}

function buildFrontLines(zones, sides) {
  partsCache.clear()
  let frontLine = []
  for (local i = 0; i < zones.len(); i++) {
    let zone = zones[i]
    if (zone.isOutBound)
      continue
    let neighbors = zone.neighbors
    for (local j = 0; j < neighbors.len(); j++) {
      if (sides[zone.id] == sides[neighbors[j].id])
        continue
      let commonPart = findCommonPart(zone, neighbors[j])
      if (commonPart != null)
        frontLine.append(commonPart)
    }
  }

  let res = {}
  frontLine.each(function(part) {
    part.ownZones.each(function(zoneId) {
      let zoneSide = zonesSides.get()[zoneId]
      let side = res?[zoneSide] ?? []
      side.append(createZoneFrontLine(zoneId, part))
      res[zoneSide] <- side
    })
  })
  return res
}

function mkFrontLine(lines, allies, lineWidth) {
  if (lines.len() == 0)
    return null
  let color = allies ? "alliesFrontLineColor" : "enemiesFrontLineColor"
  let commands = []
  foreach(line in lines)
    commands.append([VECTOR_LINE, line.p1.x * 100, line.p1.y * 100, line.p2.x * 100, line.p2.y * 100])

  return {
    rendObj = ROBJ_VECTOR_CANVAS
    color = getMapColor(color)
    lineWidth
    size = flex()
    commands
  }
}

let mkMapFrontLine = function() {
  if (zonesSides.get().len() == 0)
    return {
      watch = [zonesSides, activeAreaBounds, gridWidth]
    }

  let frontLine = buildFrontLines(getZones(), zonesSides.get())
  let linesSide1 = joinFrontLine(frontLine[zoneSideType.SIDE_1])
  let linesSide2 = joinFrontLine(frontLine[zoneSideType.SIDE_2])

  return {
    watch = [zonesSides, activeAreaBounds, gridWidth]
    size = activeAreaBounds.get().size
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = [
      mkFrontLine(linesSide1, isPlayerSide(zoneSideType.SIDE_1), gridWidth.get()),
      mkFrontLine(linesSide2, isPlayerSide(zoneSideType.SIDE_2), gridWidth.get())
    ]
  }
}

return {
  mkMapFrontLine
}