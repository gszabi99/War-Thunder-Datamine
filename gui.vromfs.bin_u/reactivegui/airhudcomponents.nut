from "%rGui/globals/ui_library.nut" import *


let { bw, bh, rw, rh } = require("%rGui/style/screenState.nut")
let { IsTwsActivated, IsTwsDamaged, CollapsedIcon, IsRwrHudVisible, IsMlwsLwsHudVisible } = require("%rGui/twsState.nut")
let { mkRadar } = require("%rGui/radarComponent.nut")
let { IsRadarVisible, IsRadar2Visible, IsRadarDamaged, IsRadarHudVisible, isCollapsedRadarInReplay } = require("%rGui/radarState.nut")
let { tws } = require("%rGui/tws.nut")
let { isPlayingReplay } = require("%rGui/hudState.nut")
let { eventbus_send } = require("eventbus")


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
    flipY = !direction.get()
    image = collapsePicUp
    color = Color(255, 255, 255, 255)
    onClick = @() direction.set(!direction.get())
    behavior = Behaviors.Button
  }
}

let twsElement = @(colorWatch, posWatched, size) function() {
  let res = {
    watch = [IsMlwsLwsHudVisible, IsRwrHudVisible, IsTwsActivated, IsTwsDamaged, CollapsedIcon, colorWatch, rw, bw, rh, bh, isPlayingReplay]
    behavior = Behaviors.RecalcHandler
    function onRecalcLayout(_initial, elem) {
      if (elem.getWidth() > 1 && elem.getHeight() > 1) {
        eventbus_send("update_tws_panel_state", {
          pos = [posWatched.get()[0], posWatched.get()[1]]
          size = [elem.getWidth(), elem.getHeight()]
          visible = IsTwsActivated.get()
        })
      }
      else
        eventbus_send("update_tws_panel_state", {})
    }
  }
  if (IsTwsActivated.get() || !CollapsedIcon.get()) {
    let picPos = [posWatched.get()[0] + size + bw.get(), rh.get() - sh(2)]
    return res.__update({
      children = (!IsMlwsLwsHudVisible.get() && !IsRwrHudVisible.get()) ? null :
        [
          tws({
            colorWatched = colorWatch,
            posWatched,
            sizeWatched = Watched([size, size]),
            relativCircleSize = 43
          }),
          isPlayingReplay.get() ? mkCollapseButton(picPos, CollapsedIcon) : null
        ]
    })
  }
  if (IsMlwsLwsHudVisible.get() || IsRwrHudVisible.get()) {
    return res.__update({
      pos = isPlayingReplay.get() ? [posWatched.get()[0], bh.get() + 0.95 * rh.get()] : [bw.get() + 0.75 * rw.get(), bh.get() + 0.03 * rh.get()]
      size = sh(5)
      rendObj = ROBJ_IMAGE
      image = !IsTwsDamaged.get() ? rwrPic : rwrPicDamaged
      color = colorWatch.get()
      children = isPlayingReplay.get() ? mkCollapseButton([sh(5), sh(2)], CollapsedIcon) : null
    })
  }
  return res
}

let radarPic = Picture("!ui/gameuiskin#radar_stby_icon")
let radarPicDamaged = Picture("!ui/gameuiskin#radar_stby_icon")


let radarElement = @(colorWatch, position) function() {
  let radarVisible = (IsRadarVisible.get() || IsRadar2Visible.get()) && (!isCollapsedRadarInReplay.get() || !isPlayingReplay.get())
  let res = { watch = [IsRadarVisible, IsRadar2Visible, IsRadarDamaged, colorWatch, rw, bw, rh, bh, isCollapsedRadarInReplay, IsRadarHudVisible, isPlayingReplay] }
  if (radarVisible || (!CollapsedIcon.get() && IsRadarHudVisible.get())) {
    return res.__update({
      children = [
        mkRadar(true, colorWatch)
        isPlayingReplay.get() ? mkCollapseButton([position[0], rh.get() - sh(2)], isCollapsedRadarInReplay) : null
      ]
    })
  }

  if (IsRadarHudVisible.get()) {
    return res.__update({
      pos = isPlayingReplay.get() ? [bw.get() + 0.75 * rw.get(), bh.get() + 0.95 * rh.get()] : [bw.get() + 0.75 * rw.get(), bh.get() + 0.1 * rh.get()]
      size = sh(5)
      rendObj = ROBJ_IMAGE
      image = !IsRadarDamaged.get() ? radarPic : radarPicDamaged
      color = colorWatch.get()
      children = isPlayingReplay.get() ? mkCollapseButton([sh(5), sh(2)], isCollapsedRadarInReplay) : null
    })
  }
  return res
}


return {
  radarElement
  twsElement
  mkCollapseButton
}