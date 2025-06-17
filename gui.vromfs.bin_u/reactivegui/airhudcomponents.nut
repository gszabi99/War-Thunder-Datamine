from "%rGui/globals/ui_library.nut" import *


let { bw, bh, rw, rh } = require("style/screenState.nut")
let { IsTwsActivated, IsTwsDamaged, CollapsedIcon, IsRwrHudVisible, IsMlwsLwsHudVisible } = require("twsState.nut")
let { mkRadar } = require("radarComponent.nut")
let { IsRadarVisible, IsRadar2Visible, IsRadarDamaged, IsRadarHudVisible, isCollapsedRadarInReplay } = require("radarState.nut")
let { tws } = require("tws.nut")
let { isPlayingReplay } = require("hudState.nut")


let rwrPic = Picture("!ui/gameuiskin#rwr_stby_icon")
let rwrPicDamaged = Picture("!ui/gameuiskin#rwr_stby_icon")
let collapseIconSize = sh(3)
let collapsePicUp = Picture($"ui/gameuiskin#spinnerListBox_arrow_up.svg:{collapseIconSize}:{collapseIconSize}")
function mkCollapseButton(position, direction){
  return  @(){
    watch = direction
    pos = position
    size = sh(3)
    rendObj = ROBJ_IMAGE
    flipY = !direction.value
    image = collapsePicUp
    color = Color(255, 255, 255, 255)
    onClick = @() direction(!direction.value)
    behavior = Behaviors.Button
  }
}

let twsElement = @(colorWatch, posWatched, size) function() {
  let res = { watch = [IsMlwsLwsHudVisible, IsRwrHudVisible, IsTwsActivated, IsTwsDamaged, CollapsedIcon, colorWatch, rw, bw, rh, bh, isPlayingReplay] }
  if (IsTwsActivated.value || !CollapsedIcon.value) {
    let picPos = [posWatched.value[0] + size + bw.value, rh.value - sh(2)]
    return res.__update({
      children = (!IsMlwsLwsHudVisible.value && !IsRwrHudVisible.value) ? null :
        [
          tws({
            colorWatched = colorWatch,
            posWatched,
            sizeWatched = Watched([size, size]),
            relativCircleSize = 43
          }),
          isPlayingReplay.value ? mkCollapseButton(picPos, CollapsedIcon) : null
        ]
    })
  }
  if (IsMlwsLwsHudVisible.value || IsRwrHudVisible.value) {
    return res.__update({
      pos = isPlayingReplay.value ? [posWatched.value[0], bh.value + 0.95 * rh.value] : [bw.value + 0.75 * rw.value, bh.value + 0.03 * rh.value]
      size = sh(5)
      rendObj = ROBJ_IMAGE
      image = !IsTwsDamaged.value ? rwrPic : rwrPicDamaged
      color = colorWatch.value
      children = isPlayingReplay.value ? mkCollapseButton([sh(5), sh(2)], CollapsedIcon) : null
    })
  }
  return res
}

let radarPic = Picture("!ui/gameuiskin#radar_stby_icon")
let radarPicDamaged = Picture("!ui/gameuiskin#radar_stby_icon")


let radarElement = @(colorWatch, position) function() {
  let radarVisible = (IsRadarVisible.value || IsRadar2Visible.value) && (!isCollapsedRadarInReplay.value || !isPlayingReplay.value)
  let res = { watch = [IsRadarVisible, IsRadar2Visible, IsRadarDamaged, colorWatch, rw, bw, rh, bh, isCollapsedRadarInReplay, IsRadarHudVisible, isPlayingReplay] }
  if (radarVisible || (!CollapsedIcon.value && IsRadarHudVisible.value)) {
    return res.__update({
      children = [
        mkRadar(true, colorWatch)
        isPlayingReplay.value ? mkCollapseButton([position[0], rh.value - sh(2)], isCollapsedRadarInReplay) : null
      ]
    })
  }

  if (IsRadarHudVisible.value) {
    return res.__update({
      pos = isPlayingReplay.value ? [bw.value + 0.75 * rw.value, bh.value + 0.95 * rh.value] : [bw.value + 0.75 * rw.value, bh.value + 0.1 * rh.value]
      size = sh(5)
      rendObj = ROBJ_IMAGE
      image = !IsRadarDamaged.value ? radarPic : radarPicDamaged
      color = colorWatch.value
      children = isPlayingReplay.value ? mkCollapseButton([sh(5), sh(2)], isCollapsedRadarInReplay) : null
    })
  }
  return res
}


return {
  radarElement
  twsElement
  mkCollapseButton
}