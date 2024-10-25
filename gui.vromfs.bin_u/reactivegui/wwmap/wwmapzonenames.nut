from "%rGui/globals/ui_library.nut" import *

let { getMapColor } = require("%rGui/wwMap/wwMapUtils.nut")
let { hoveredZone, getZones } = require("%rGui/wwMap/wwMapZonesData.nut")
let { activeAreaBounds } = require("%rGui/wwMap/wwOperationConfiguration.nut")
let fontsState = require("%rGui/style/fontsState.nut")

let mkMapZoneName = @(zone, areaBounds) function() {
  let { areaWidth, areaHeight } = areaBounds
  return {
    rendObj = ROBJ_TEXT
    size = [(zone.coords[5].x - zone.coords[0].x) * areaWidth, SIZE_TO_CONTENT]
    pos = [zone.coords[0].x * areaWidth, zone.coords[0].y * areaHeight]
    margin = [0.006 * areaWidth, 0, 0, 0]
    halign = ALIGN_RIGHT
    text = zone.name
    color = getMapColor("zonesNameColor")
    fontSize = hdpx(17)
    font = fontsState.get("bigBold")
  }
}

let mkMapZonesNamePermanent = @(areaBounds) function() {
  let children = []
  getZones().each(function(zone) {
    if (zone.isAlwaysShowName && !zone.isOutBound)
      children.append(mkMapZoneName(zone, areaBounds))
  })
  return {
    children
  }
}

let mkMapHoveredZoneName = @(areaBounds) function() {
  let zone = hoveredZone.get()
  if (zone == null || zone.isAlwaysShowName)
    return { watch = hoveredZone }

  return {
    watch = hoveredZone
    children = mkMapZoneName(zone, areaBounds)
  }
}

let mkMapZoneNames = @() {
  watch = activeAreaBounds
  size = activeAreaBounds.get().size
  vplace = ALIGN_CENTER
  hplace = ALIGN_CENTER
  children = [mkMapZonesNamePermanent(activeAreaBounds.get()), mkMapHoveredZoneName(activeAreaBounds.get())]
}

return {
  mkMapZoneNames
}
