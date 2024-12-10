from "%rGui/globals/ui_library.nut" import *
let { fabs, cos, sin, PI, sqrt } = require("math")
let { zoneSideType, zoneSideTypeStr } = require("%rGui/wwMap/wwMapTypes.nut")
let { sendToDagui } = require("%rGui/wwMap/wwMapUtils.nut")

let sqrt32 = sqrt(3) / 2

let cachedZones = []
let zonesForSearch = []
let hoveredZone = Watched(null)

function getZoneBounds(coords) {
  let ltPoint = coords.reduce(function(res, point) {
    return { x = min(point.x, res.x), y = min(point.y, res.y) }
  }, { x = 1, y = 1 })
  let rbPoint = coords.reduce(function(res, point) {
    return { x = max(point.x, res.x), y = max(point.y, res.y) }
  }, { x = -1, y = -1 })

  let cPoint = { x = (rbPoint.x + ltPoint.x) / 2, y = (rbPoint.y + ltPoint.y) / 2 }
  return { ltPoint, rbPoint, cPoint }
}

function takeApart(coords) {
  let parts = coords.reduce(function(res, point, index) {
    if (index == coords.len() - 1)
      return res
    let part = [point, coords[index + 1]]
    part.sort(@(p1, p2) p1.x <=> p2.x || p1.y <=> p2.y)
    res.append({ line = part, hash = $"{part[0].x},{part[0].y},{part[1].x},{part[1].y}"})
    return res
  }, [])

  return parts
}

function addNeighbors(zone, zones) {
  if (zone.isOutBound)
    return
  let zoneWidth = zone.size.w
  let zoneHeight = zone.size.h
  for (local i = 0; i < zones.len(); i++) {
    if (zones[i].isOutBound)
      continue
    if (fabs(zones[i].center.x - zone.center.x) < 0.8 * zoneWidth &&
      fabs(zones[i].center.y - zone.center.y) < 1.1 * zoneHeight) {
      zone.neighbors.append({
        id = zones[i].id
        parts = zones[i].parts
      })
      zones[i].neighbors.append({
        id = zone.id
        parts = zone.parts
      })
    }
  }
}

function processCoords(coords) {
  let { ltPoint, rbPoint, cPoint } = getZoneBounds(coords)
  let zoneWidth = rbPoint.x - ltPoint.x
  let zoneHeight = rbPoint.y - ltPoint.y
  return {
    pos = ltPoint
    size = { w = zoneWidth, h = zoneHeight }
    coords
    isOutBound = ltPoint.x < 0 || ltPoint.y < 0 || rbPoint.x > 1 || rbPoint.y > 1
    center = cPoint
  }
}

function parseZones(zonesBlk) {
  cachedZones.clear()
  zonesForSearch.clear()
  let cnt = zonesBlk.blockCount()
  local firstLetterOfName = "A"
  for (local i = 0; i < cnt; i++) {
    let zoneBlk = zonesBlk.getBlock(i)
    let name = zoneBlk.getBlockName()
    let { pos, size, coords, isOutBound, center } = processCoords(zoneBlk % "p")
    let zone = {
      center
      isOutBound
      size
      pos
      coords
      id = i
      name = name
      isAlwaysShowName = name.contains("A") || name.slice(0, 1) != firstLetterOfName
      parts = takeApart(coords)
      rear = zoneBlk?.rear ?? "SIDE_NONE"
      rearForTeam = zoneSideType[zoneBlk?.rear ?? "SIDE_NONE"]
      neighbors = []
    }
    addNeighbors(zone, cachedZones)
    cachedZones.append(zone)
    if (!zone.isOutBound) {
      firstLetterOfName = name.slice(0, 1)
      zonesForSearch.append({
        l = pos.x
        t = pos.y
        r = pos.x + size.w
        b = pos.y + size.h
        idx = cachedZones.len() - 1
        coords
      })
    }
  }
}

function isPointInZone(zone, x, y) {
  local intersectCount = 0
  let coords = zone.coords
  for (local i = 0; i < coords.len() - 1; i++) {
    let dx1 = coords[i].x - x
    let dx2 = coords[i + 1].x - x
    let minX = min(coords[i].x, coords[i + 1].x)
    let leftDx = minX - x
    if (leftDx == 0 || dx1 * dx2 < 0) {
      if (coords[i].y > y && coords[i+1].y > y)
        intersectCount++
      else if (!(coords[i].y < y && coords[i+1].y < y)) {
        let dx = coords[i+1].x - coords[i].x
        let dy = coords[i+1].y - coords[i].y
        if (fabs(dx) > 1e-6) {
          let d = (x - coords[i].x) * dy - (y - coords[i].y) * dx
          if (dx * d > 0) {
            intersectCount++
          }
        }
      }
    }
  }
  return (intersectCount & 1) == 1
}

let getZoneById = @(id) cachedZones.findvalue(@(zone) zone.id == id)

let calcCorrectCoeff = @(coords) sqrt32 / ((coords[2].y - coords[0].y) / (coords[4].x - coords[1].x))

function createZoneFrontLine(id, part) {
  let zone = getZoneById(id)
  let partIndex = zone.parts.findindex(@(p) p.hash == part.hash) ?? 0
  let correctKoeff = calcCorrectCoeff(zone.coords)
  let r = 0.9 * zone.size.w / 2

  let line = [partIndex, partIndex + 1].map(function(index) {
    let res = {}
    res.x <- r * sin(-PI / 6 - index * PI / 3) + zone.center.x
    res.y <- r * -cos(-PI / 6 - index * PI / 3) / correctKoeff + zone.center.y
    return res
  })

  return { p1 = line[0], p2 = line[1] }
}

function getZoneSize() {
  return cachedZones[0].size
}

let updateHoveredZone = @(zone) hoveredZone.set(zone)

function updateSelectedRearZone(zone) {
  if (zone == null || zone.rearForTeam == 0)
    return
  sendToDagui("ww.selectRearZone", { side = zoneSideTypeStr[zone.rearForTeam] })
}

function getZoneByPoint(pos) {
  let zone = zonesForSearch.findvalue(@(zone) zone.l < pos.x && zone.r > pos.x && zone.t < pos.y && zone.b > pos.y &&
    isPointInZone(zone, pos.x, pos.y))
  return cachedZones?[zone?.idx]
}

return {
  parseZones
  getZones = @() cachedZones
  getZoneById
  createZoneFrontLine
  getZoneByPoint
  getZoneSize
  hoveredZone
  updateHoveredZone
  updateSelectedRearZone
}