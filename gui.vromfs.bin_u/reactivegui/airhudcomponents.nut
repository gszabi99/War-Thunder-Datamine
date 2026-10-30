from "%rGui/style/screenState.nut" import bw, bh, rw, rh
from "%rGui/twsState.nut" import IsTwsActivated, CollapsedIcon, IsRwrHudVisible, IsMlwsLwsHudVisible
from "%rGui/radarComponent.nut" import mkRadar
from "%rGui/radarState.nut" import IsRadarVisible, IsRadar2Visible, IsRadarHudVisible, isCollapsedRadarInReplay
from "%rGui/tws.nut" import twsDas
from "%rGui/hudState.nut" import isPlayingReplay
from "eventbus" import eventbus_send
from "%rGui/globals/ui_library.nut" import *



const collapseIconSize = sh(3)

function mkCollapseButton(position, direction){
  let collapsePicUp = Picture($"ui/gameuiskin#spinnerListBox_arrow_up.svg:{collapseIconSize}:{collapseIconSize}")
  return  @(){
    watch = direction
    pos = position
    size = collapseIconSize
    rendObj = ROBJ_IMAGE
    flipY = !direction.get()
    image = collapsePicUp
    color = Color(255, 255, 255, 255)
    onClick = @() direction.set(!direction.get())
    behavior = Behaviors.Button
  }
}

function twsElement(colorWatch, posWatched, size) {
  let sizeWatched = Watched(size)
  let rwrPic = Picture("!ui/gameuiskin#rwr_stby_icon")
  return function() {
    let res = {
      watch = [IsMlwsLwsHudVisible, IsRwrHudVisible, IsTwsActivated, CollapsedIcon, colorWatch, rw, bw, rh, bh, isPlayingReplay]
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
      let picPos = [posWatched.get()[0] + size[0] - collapseIconSize, posWatched.get()[1] + size[1] - collapseIconSize]
      return res.__update({
        children = (!IsMlwsLwsHudVisible.get() && !IsRwrHudVisible.get()) ? null :
          [
            twsDas({
              colorWatched = colorWatch,
              posWatched = posWatched,
              sizeWatched = sizeWatched,
            }),
            
            
            
            
            
            
            isPlayingReplay.get() ? mkCollapseButton(picPos, CollapsedIcon) : null
          ]
      })
    }
    if (IsMlwsLwsHudVisible.get() || IsRwrHudVisible.get()) {
      let picPos = [posWatched.get()[0] + size[0] - sh(5) - collapseIconSize, posWatched.get()[1] + size[1] - sh(5)]
      return res.__update({
        pos = isPlayingReplay.get() ? picPos : [bw.get() + 0.75 * rw.get(), bh.get() + 0.03 * rh.get()]
        size = sh(5)
        rendObj = ROBJ_IMAGE
        image = rwrPic
        color = colorWatch.get()
        children = isPlayingReplay.get() ? mkCollapseButton([pw(100), sh(5) - collapseIconSize], CollapsedIcon) : null
      })
    }
    return res
  }
}


function radarElement(colorWatch, position, size, isSquareRadar) {
  let radarPic = Picture("!ui/gameuiskin#radar_stby_icon")
  return function() {
    let radarVisible = (IsRadarVisible.get() || IsRadar2Visible.get()) && (!isCollapsedRadarInReplay.get() || !isPlayingReplay.get())
    let res = { watch = [IsRadarVisible, IsRadar2Visible, colorWatch, rw, bw, rh, bh, isCollapsedRadarInReplay, IsRadarHudVisible, isPlayingReplay, CollapsedIcon] }
    if (radarVisible || (!CollapsedIcon.get() && IsRadarHudVisible.get())) {
      return res.__update({
        children = [
          mkRadar(true, colorWatch)
          isPlayingReplay.get()
            ? mkCollapseButton([
                position[0] + size[0] - sh(2),
                position[1] + size[1] + (isSquareRadar ? sh(4) : sh(12))
              ], isCollapsedRadarInReplay)
            : null
        ]
      })
    }

    if (IsRadarHudVisible.get()) {
      return res.__update({
        pos = isPlayingReplay.get()
          ? [position[0] + size[0] - sh(6), position[1] + size[1] + (isSquareRadar ? 0 : sh(8))]
          : [bw.get() + 0.75 * rw.get(), bh.get() + 0.1 * rh.get()]
        size = sh(5)
        rendObj = ROBJ_IMAGE
        image = radarPic
        color = colorWatch.get()
        children = isPlayingReplay.get() ? mkCollapseButton(const [sh(4), sh(4)], isCollapsedRadarInReplay) : null
      })
    }
    return res
  }
}


return freeze({
  radarElement
  twsElement
  mkCollapseButton
})