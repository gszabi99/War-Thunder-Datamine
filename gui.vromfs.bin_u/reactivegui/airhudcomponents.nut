from "%rGui/globals/ui_library.nut" import *

//script used for common script between Helicopter and aircraft
let { bw, bh, rw, rh } = require("style/screenState.nut")
let { IsTwsActivated, CollapsedIcon, IsRwrHudVisible, IsMlwsLwsHudVisible } = require("twsState.nut")
let { mkRadar } = require("radarComponent.nut")
let { IsRadarVisible, IsRadar2Visible, IsRadarHudVisible } = require("radarState.nut")
let tws = require("tws.nut")


let rwrPic = Picture("!ui/gameuiskin#rwr_stby_icon")

let twsElement = @(colorWatch, posWatched, size) function() {
  let res = { watch = [IsMlwsLwsHudVisible, IsRwrHudVisible, IsTwsActivated, CollapsedIcon, colorWatch, rw, bw, rh, bh] }
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
      pos = [bw.value + 0.75 * rw.value, bh.value + 0.03 * rh.value]
      size = [sh(5), sh(5)]
      rendObj = ROBJ_IMAGE
      image = rwrPic
      color = colorWatch.value
    })
  }
  return res
}

let radarPic = Picture("!ui/gameuiskin#radar_stby_icon")

//radar posX is watched because it use safeAreaSize on aircraftHud
let radarElement = @(colorWatch, posWatched, size) function() {
  let radarVisible = IsRadarVisible.value || IsRadar2Visible.value
  let res = { watch = [IsRadarVisible, IsRadar2Visible, colorWatch, rw, bw, rh, bh, CollapsedIcon, IsRadarHudVisible] }
  if (radarVisible || !CollapsedIcon.value) {
    return res.__update({
      children = mkRadar(posWatched, size, true, colorWatch)
    })
  }
  if (IsRadarHudVisible.value) {
    return res.__update({
      pos = [bw.value + 0.75 * rw.value, bh.value + 0.1 * rh.value]
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