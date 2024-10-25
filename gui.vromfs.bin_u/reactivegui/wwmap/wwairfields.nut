from "%rGui/globals/ui_library.nut" import *

let { floor } = require("math")
let { airfieldsInfo, hoveredAirfield, selectedAirfield } = require("%rGui/wwMap/wwAirfieldsStates.nut")
let { activeAreaBounds } = require("%rGui/wwMap/wwOperationConfiguration.nut")
let { getZoneSize } = require("%rGui/wwMap/wwMapZonesData.nut")

function mkAirfield(airfieldInfo, areaBounds) {
  let { airfieldPos, aircraftTextures, airfieldIdx } = airfieldInfo

  let aircraftTexture = Computed(@()
    selectedAirfield.get()?.airfieldIdx == airfieldIdx ? aircraftTextures["airfieldTexSelected"]
      : hoveredAirfield.get()?.airfieldIdx == airfieldIdx ? aircraftTextures["airfieldTexHover"]
      : aircraftTextures["airfieldTex"])

  let { areaWidth, areaHeight } = areaBounds

  let zoneSize = getZoneSize()

  let size = [floor(areaWidth * zoneSize.w), floor(areaHeight * zoneSize.w)]
  let pos = [areaWidth * airfieldPos.x - size[0] / 2, areaHeight * airfieldPos.y - size[1] / 2]

  return @() {
    rendObj = ROBJ_IMAGE
    watch = aircraftTexture
    pos
    size
    keepAspect = true
    image = Picture($"{aircraftTexture.get()}:{size[0]}:{size[1]}")
  }
}

let mkAirfields = @() {
  watch = [airfieldsInfo, activeAreaBounds]
  size = activeAreaBounds.get().size
  vplace = ALIGN_CENTER
  hplace = ALIGN_CENTER
  children = airfieldsInfo.get().map(@(airfieldInfo) mkAirfield(airfieldInfo, activeAreaBounds.get()))
}

return {
  mkAirfields
}