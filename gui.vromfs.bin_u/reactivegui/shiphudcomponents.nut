from "%rGui/style/screenState.nut" import bw, bh, rw, rh
from "%rGui/twsState.nut" import CollapsedIcon
from "%rGui/radarComponent.nut" import mkRadar
from "%rGui/fcsComponent.nut" import mkFCSComponent
from "%rGui/radarState.nut" import IsRadarVisible, IsRadar2Visible, IsRadarHudVisible
from "%rGui/fcsState.nut" import HasFcsIndication, IsFcsVisible, IsVisible
from "%rGui/radar.nut" import radarHud, radarIndication
from "%rGui/sonar.nut" import sonarIndication
from "%rGui/globals/ui_library.nut" import *

let collapsedIconPos = Computed(@() [bw.get() + 0.015 * rw.get(), bh.get() + 0.032 * rh.get()])
let radarPos = Computed(@() [bw.get(), bh.get()])
let radarColor = Watched(Color(0, 255, 0, 255))

let radarVisible = Computed(@() IsRadarVisible.get() || IsRadar2Visible.get() || !CollapsedIcon.get())
let isFcsAvailable = Computed(@() IsVisible.get() && HasFcsIndication.get())

function mkCollapsedIcon(iconName) {
 return @() {
    watch = collapsedIconPos
    rendObj = ROBJ_IMAGE
    pos = collapsedIconPos.get()
    size = sh(5)
    color = Color(71, 232, 39, 240)
    image = Picture(iconName)
  }
}
let fcsCollapsed = mkCollapsedIcon("!ui/gameuiskin#fcs_stby_icon")
let radarCollapsed = mkCollapsedIcon("!ui/gameuiskin#radar_stby_icon")

let radarComponent = @() {
  watch = [radarVisible, IsRadarHudVisible, IsFcsVisible, isFcsAvailable, radarPos]
  children = radarVisible.get() && IsRadarHudVisible.get() ? [
    mkRadar()
    radarHud(sh(30), sh(30), radarPos.get()[0], radarPos.get()[1], radarColor, const {
      hasTxtBlock = true
    })
    radarIndication(radarColor)
  ] : isFcsAvailable.get() ? [
    !IsFcsVisible.get() ? fcsCollapsed : IsRadarHudVisible.get() ? radarCollapsed : null
    IsFcsVisible.get() ? mkFCSComponent(radarPos, const [sh(20), sh(20)]) : null
  ] : IsRadarHudVisible.get() ? radarCollapsed : null
}

function mkSonar() {
  return function() {
    let res = {}
    return res.__update({
      halign = ALIGN_LEFT
      valign = ALIGN_TOP
      size = const [sw(100), sh(100)]
      children = []
    })
  }
}

let sonarComponent = @() {
  children = [ mkSonar(), sonarIndication() ]
}

return freeze({
  radarComponent
  sonarComponent
})