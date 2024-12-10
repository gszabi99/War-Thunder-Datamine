from "%rGui/globals/ui_library.nut" import *

let { getSettings } = require("%appGlobals/worldWar/wwSettings.nut")
let { selectColorBySide } = require("%rGui/wwMap/wwMapUtils.nut")
let { zoneSideType } = require("%rGui/wwMap/wwMapTypes.nut")
let { zonesSides, zonesConnectedToRear } = require("%rGui/wwMap/wwMapStates.nut")
let { activeAreaBounds } = require("%rGui/wwMap/wwOperationConfiguration.nut")
let { getZones } = require("%rGui/wwMap/wwMapZonesData.nut")
let { isShowZonesFilter } = require("%appGlobals/worldWar/wwMapFilters.nut")

let transparentColor = 0x00000000

function getBackgroundParams(zoneSide, rearForTeam, zoneConnectedToRear) {
  if (zoneSide == zoneSideType.SIDE_NONE)
    return { color = transparentColor, isRounded = false }

  local zoneState = ""
  if (rearForTeam != zoneSideType.SIDE_NONE && rearForTeam == zoneSide)
    zoneState = "Rear"
  else if (zoneConnectedToRear == 0)
    zoneState = "Rounded"
  let color = selectColorBySide(zoneSide, $"alliesZonesColor{zoneState}", $"enemiesZonesColor{zoneState}")
  return { color, isRounded = zoneState == "Rounded" }
}

let mkMapZoneBackground = @(zoneData) function() {
  let isShowZoneBackground = Computed(@() zonesSides.get().len() > 0 && zonesConnectedToRear.get().len() > 0 && isShowZonesFilter.get())
  if (!isShowZoneBackground.get())
    return {
      watch = [isShowZoneBackground, zonesSides, zonesConnectedToRear]
    }

  let { pos, size, coords, rearForTeam, id } = zoneData
  let command = coords.reduce(@(res, coord) res.append(100 * (coord.x - pos.x) / size.w, 100 * (coord.y - pos.y) / size.h), [VECTOR_POLY])

  let { color, isRounded } = getBackgroundParams(zonesSides.get()[id], rearForTeam, zonesConnectedToRear.get()[id])
  return {
    watch = [isShowZoneBackground, zonesSides, zonesConnectedToRear]
    rendObj = ROBJ_VECTOR_CANVAS
    pos = [pw(100 * pos.x), ph(100 * pos.y)]
    size = [pw(100 * size.w), ph(100 * size.h)]
    lineWidth = 0
    color = transparentColor
    fillColor = color
    commands = [command]
    children = isRounded ? {
      rendObj = ROBJ_IMAGE
      size = flex()
      image = Picture($"{getSettings("imageZoneRounded")}:{hdpx(218)}:{hdpx(207)}")
      color = Color(0, 0, 0, 26)
    } : null
  }
}

let mkMapZonesBackground = @() {
  watch = activeAreaBounds
  size = activeAreaBounds.get().size
  vplace = ALIGN_CENTER
  hplace = ALIGN_CENTER
  children = getZones().filter(@(value) !value.isOutBound).map(@(value) mkMapZoneBackground(value))
}

return mkMapZonesBackground