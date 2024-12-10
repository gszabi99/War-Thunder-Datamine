from "%rGui/globals/ui_library.nut" import *

let { floor } = require("math")
let { airfieldsInfo, hoveredAirfield, selectedAirfield, hoveredAirfieldIndex } = require("%rGui/wwMap/wwAirfieldsStates.nut")
let { activeAreaBounds } = require("%rGui/wwMap/wwOperationConfiguration.nut")
let { getZoneSize } = require("%rGui/wwMap/wwMapZonesData.nut")
let { even } = require("%rGui/wwMap/wwUtils.nut")

let hoverBounds = [0.2666, 0.2941, 0.7333, 0.7059]
let airfieldImageAspectRatio = 68.0 / 60

function createHoverBounds(imageWidth, imageHeight) {
  let boundPos = [hoverBounds[0] * imageWidth, hoverBounds[1] * imageHeight]
  let boundSize = [(hoverBounds[2] - hoverBounds[0]) * imageWidth, (hoverBounds[3] - hoverBounds[1]) * imageHeight]
  return {
    boundPos
    boundSize
  }
}

function mkAirfield(airfieldInfo, areaBounds) {
  let { airfieldPos, airfieldTextures, airfieldIdx } = airfieldInfo

  let airfieldTexture = Computed(@()
    selectedAirfield.get()?.airfieldIdx == airfieldIdx ? airfieldTextures["airfieldTexSelected"]
      : hoveredAirfield.get()?.airfieldIdx == airfieldIdx ? airfieldTextures["airfieldTexHover"]
      : airfieldTextures["airfieldTex"])

  let { areaWidth, areaHeight } = areaBounds

  let zoneSize = getZoneSize()
  let imageWidth = even(areaWidth * zoneSize.w * 0.606492)
  let imageHeight = imageWidth * airfieldImageAspectRatio
  let pos = [floor(areaWidth * airfieldPos.x - imageWidth / 2), floor(areaHeight * airfieldPos.y - imageHeight / 2)]
  let { boundPos, boundSize } = createHoverBounds(imageWidth, imageHeight)

  return @() {
    rendObj = ROBJ_IMAGE
    watch = airfieldTexture
    pos
    size = [imageWidth, imageHeight]
    subPixel = true
    image = Picture($"{airfieldTexture.get()}:{floor(imageWidth)}:{floor(imageHeight)}")
    children = {
      pos = boundPos
      size = boundSize
      onElemState = @(s) hoveredAirfieldIndex.set(((s & S_HOVER) == S_HOVER) ? airfieldIdx : null)
      behavior = Behaviors.Button
    }
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