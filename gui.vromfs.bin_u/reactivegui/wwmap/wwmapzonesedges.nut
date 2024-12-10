from "%rGui/globals/ui_library.nut" import *
let { zoneStatusTypes } = require("%rGui/wwMap/wwMapTypes.nut")
let { zonesHighlightedFlag } = require("%rGui/wwMap/wwMapStates.nut")
let { hoveredZone, getZones } = require("%rGui/wwMap/wwMapZonesData.nut")
let { getMapColor } = require("%rGui/wwMap/wwMapUtils.nut")
let { activeAreaBounds, gridWidth } = require("%rGui/wwMap/wwOperationConfiguration.nut")
let { isShowZonesFilter } = require("%appGlobals/worldWar/wwMapFilters.nut")

function mkZonesLines(parts, lineWidth) {
  if (parts.len() == 0)
    return null

  let commands = [[VECTOR_LINE_INDENT_PCT, 0.2, 0.2]]
  local prevColor = -1
  foreach(part in parts) {
    if (part.color != prevColor) {
      commands.append([VECTOR_COLOR, getMapColor(part.color)])
      prevColor = part.color
    }
    commands.append([VECTOR_LINE, part.line[0].x * 100, part.line[0].y * 100, part.line[1].x * 100, part.line[1].y * 100])
  }

  return {
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth
    size = flex()
    commands
  }
}

function reorderZones(zones, highlightedFlag) {
  let highlighted = []
  let outlined = []
  let ordinary = []

  foreach(zone in zones) {
    if (zone.isOutBound)
      continue

    let flag = highlightedFlag[zone.id]
    let zoneStatus = zoneStatusTypes.reduce(@(res, status) (flag & status.mask) == status.mask ? status : res,
      { mask = 0, type = "ordinary", color = "" })
    zone.order <- zoneStatus?.order ?? 0
    zone.color <- zoneStatus.color
    if (zoneStatus.type == "highlighted")
      highlighted.append(zone)
    else if (zoneStatus.type == "outlined")
      outlined.append(zone)
    else {
      zone.color = "alliesZonesGridColor"
      ordinary.append(zone)
    }
  }

  highlighted.sort(@(a, b) a.order <=> b.order)
  return [].extend(outlined, highlighted, ordinary)
}

function getUniqParts(zones) {
  let partHashes = {}
  let uniqParts = []
  foreach (zone in zones) {
    let parts = zone.parts
    foreach (part in parts) {
      part.color <- zone.color
      if (partHashes?[part.hash] == null) {
        partHashes[part.hash] <- true
        uniqParts.insert(0, part)
      }
    }
  }
  return uniqParts
}

function mkMapHoveredZone() {
  if (hoveredZone.get() == null)
    return {
      watch = hoveredZone
    }

  let parts = hoveredZone.get().parts

  let commands = []
  foreach(part in parts)
    commands.append([VECTOR_LINE, part.line[0].x * 100, part.line[0].y * 100, part.line[1].x * 100, part.line[1].y * 100])

  return {
    watch = [hoveredZone, activeAreaBounds, gridWidth]
    rendObj = ROBJ_VECTOR_CANVAS
    size = activeAreaBounds.get().size
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    color = getMapColor("outlinedZonesGridColor")
    lineWidth = gridWidth.get()
    commands
  }
}

function mkMapZonesEdges() {
  let isShowGrid = Computed(@() zonesHighlightedFlag.get().len() > 0 && isShowZonesFilter.get())
  if (!isShowGrid.get())
    return {
      watch = [isShowGrid, activeAreaBounds, gridWidth]
    }

  let uniqParts = getUniqParts(reorderZones(getZones(), zonesHighlightedFlag.get()))

  return {
    watch = [isShowGrid, activeAreaBounds, gridWidth]
    size = activeAreaBounds.get().size
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = mkZonesLines(uniqParts, gridWidth.get())
  }
}

return {
  mkMapZonesEdges
  mkMapHoveredZone
}
