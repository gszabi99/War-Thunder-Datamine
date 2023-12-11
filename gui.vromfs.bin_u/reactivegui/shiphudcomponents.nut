from "%rGui/globals/ui_library.nut" import *

let { bw, bh, rw, rh } = require("style/screenState.nut")
let { CollapsedIcon } = require("twsState.nut")
let { mkFCSComponent } = require("fcsComponent.nut")
let { IsRadarVisible, IsRadar2Visible, IsRadarHudVisible } = require("radarState.nut")
let { HasFcsIndication, IsFcsVisible } = require("%rGui/fcsState.nut")
let radarHud = require("%rGui/radar.nut")

let radarPic = Picture("!ui/gameuiskin#radar_stby_icon")
let fcsPic = Picture("!ui/gameuiskin#fcs_stby_icon")
let collapsedIconPos = Computed(@() [bw.value + 0.045 * rw.value, bh.value + 0.05 * rh.value])
let radarPos = Computed(@() [bw.value, bh.value])
let radarColor = Watched(Color(0, 255, 0, 255))

let radarVisible = Computed(@() IsRadarVisible.value || IsRadar2Visible.value || !CollapsedIcon.value)

let function mkCollapsedIcon(icon) {
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
  watch = [radarVisible, IsRadarHudVisible, IsFcsVisible]
  children = radarVisible.value && IsRadarHudVisible.value ? [
    radarHud(sh(40), sh(40), radarPos.value[0], radarPos.value[1], radarColor)
  ] : HasFcsIndication.value ? [
    !IsFcsVisible.value ? fcsCollapsed : IsRadarHudVisible.value ? radarCollapsed : null
    IsFcsVisible.value ? mkFCSComponent(radarPos) : null
  ] : [
    IsRadarHudVisible.value ? radarCollapsed : null
  ]
}

return {
  radarComponent
}