from "%rGui/globals/ui_library.nut" import *

let { bw, bh, rw, rh } = require("style/screenState.nut")
let { CollapsedIcon } = require("twsState.nut")
let { mkRadar } = require("radarComponent.nut")
let { mkFCSComponent } = require("fcsComponent.nut")
let { IsRadarVisible, IsRadar2Visible, IsRadarHudVisible } = require("radarState.nut")
let { HasFcsIndication, IsFcsVisible, IsVisible } = require("%rGui/fcsState.nut")
let { radarHud, radarIndication } = require("%rGui/radar.nut")

let radarPic = Picture("!ui/gameuiskin#radar_stby_icon")
let fcsPic = Picture("!ui/gameuiskin#fcs_stby_icon")
let collapsedIconPos = Computed(@() [bw.value + 0.015 * rw.value, bh.value + 0.032 * rh.value])
let radarPos = Computed(@() [bw.value, bh.value])
let radarColor = Watched(Color(0, 255, 0, 255))

let radarVisible = Computed(@() IsRadarVisible.value || IsRadar2Visible.value || !CollapsedIcon.value)
let isFcsAvailable = Computed(@() IsVisible.value && HasFcsIndication.value)

function mkCollapsedIcon(icon) {
 return @() {
    watch = collapsedIconPos
    rendObj = ROBJ_IMAGE
    pos = collapsedIconPos.value
    size = [sh(5), sh(5)]
    color = Color(71, 232, 39, 240)
    image = icon
  }
}
let fcsCollapsed = mkCollapsedIcon(fcsPic)
let radarCollapsed = mkCollapsedIcon(radarPic)

let radarComponent = @() {
  watch = [radarVisible, IsRadarHudVisible, IsFcsVisible, isFcsAvailable]
  children = radarVisible.value && IsRadarHudVisible.value ? [
    mkRadar()
    radarHud(sh(30), sh(30), radarPos.value[0], radarPos.value[1], radarColor, true)
    radarIndication(radarColor)
  ] : isFcsAvailable.value ? [
    !IsFcsVisible.value ? fcsCollapsed : IsRadarHudVisible.value ? radarCollapsed : null
    IsFcsVisible.value ? mkFCSComponent(radarPos, [sh(20), sh(20)]) : null
  ] : [
    IsRadarHudVisible.value ? radarCollapsed : null
  ]
}

return {
  radarComponent
}