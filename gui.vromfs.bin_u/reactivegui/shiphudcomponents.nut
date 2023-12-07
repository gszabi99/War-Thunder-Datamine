from "%rGui/globals/ui_library.nut" import *

let { bw, bh, rw, rh } = require("style/screenState.nut")
let { CollapsedIcon } = require("twsState.nut")
let { mkShipRadar } = require("radarComponent.nut")
let { mkFCSComponent } = require("fcsComponent.nut")
let { IsRadarVisible, IsRadar2Visible, IsRadarHudVisible } = require("radarState.nut")
let { IsFCSVisible } = require("%rGui/fcsState.nut")

let radarPic = Picture("!ui/gameuiskin#radar_stby_icon")
let fcsPic = Picture("!ui/gameuiskin#fcs_stby_icon")
let collapsedIconPos = Computed(@() [bw.value + 0.045 * rw.value, bh.value + 0.05 * rh.value])
let radarPos = Computed(@() [bw.value, bh.value])

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
  watch = [radarVisible, IsRadarHudVisible, IsFCSVisible]
  children = radarVisible.value && IsRadarHudVisible.value ? [
    IsFCSVisible.value ? fcsCollapsed : null
    mkShipRadar(radarPos)
  ] : [
    IsRadarHudVisible.value ? radarCollapsed : null
    IsFCSVisible.value ? mkFCSComponent(radarPos) : null
  ]
}

return {
  radarComponent
}