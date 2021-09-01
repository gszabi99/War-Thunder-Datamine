//script used for common script between Helicopter and aircraft
local { bw, bh, rw, rh } = require("style/screenState.nut")
local {IsTwsActivated, CollapsedIcon, IsRwrHudVisible, IsMlwsLwsHudVisible} = require("twsState.nut")
local {mkRadar} = require("radarComponent.nut")
local {IsRadarVisible, IsRadar2Visible, IsRadarHudVisible} = require("radarState.nut")
local tws = require("tws.nut")


local rwrPic = Picture("!ui/gameuiskin#rwr_stby_icon")

local twsElement = @(colorWatch, posWatched, size) function() {
  local res = { watch = [IsMlwsLwsHudVisible, IsRwrHudVisible, IsTwsActivated, CollapsedIcon, colorWatch, rw, bw, rh, bh] }
  if (IsTwsActivated.value || !CollapsedIcon.value) {
    return res.__update({
      children = (!IsMlwsLwsHudVisible.value && !IsRwrHudVisible.value) ? null :
        tws({
          colorWatched = colorWatch,
          posWatched,
          sizeWatched = Watched([size, size]),
          relativCircleSize = 43
        })
    })
  }
  if (IsMlwsLwsHudVisible.value || IsRwrHudVisible.value) {
    return res.__update({
      pos = [bw.value + 0.74 * rw.value, bh.value + 0.03 * rh.value]
      size = [sh(5), sh(5)]
      rendObj = ROBJ_IMAGE
      image = rwrPic
      color = colorWatch.value
    })
  }
  return res
}

local radarPic = Picture("!ui/gameuiskin#radar_stby_icon")

//radar posX is watched because it use safeAreaSize on aircraftHud
local radarElement = @(colorWatch, posWatched, size) function() {
  local radarVisible = IsRadarVisible.value || IsRadar2Visible.value
  local res = { watch = [IsRadarVisible, IsRadar2Visible, colorWatch, rw, bw, rh, bh, CollapsedIcon, IsRadarHudVisible] }
  if (radarVisible || !CollapsedIcon.value){
    return res.__update({
      children = mkRadar(posWatched, size, true, colorWatch)
    })
  }
  if (IsRadarHudVisible.value){
    return res.__update({
      pos = [bw.value + 0.74 * rw.value, bh.value + 0.3 * rh.value]
      size = [sh(5), sh(5)]
      rendObj = ROBJ_IMAGE
      image = radarPic
      color = colorWatch.value
    })
  }
  return res
}


return {
  radarElement
  twsElement
}