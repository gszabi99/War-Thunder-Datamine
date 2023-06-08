from "%rGui/globals/ui_library.nut" import *

let { bw, bh, rw, rh } = require("style/screenState.nut")
let { CollapsedIcon } = require("twsState.nut")
let { mkRadar } = require("radarComponent.nut")
let { mkFCSComponent } = require("fcsComponent.nut")
let { IsRadarVisible, IsRadar2Visible, IsRadarHudVisible } = require("radarState.nut")
let { IsFCSVisible } = require("%rGui/fcsState.nut")

let radarPic = Picture("!ui/gameuiskin#radar_stby_icon")
let radarCollapsedPos = Computed(@() [bw.value + 0.055 * rw.value, bh.value + 0.05 * rh.value])
let radarPos = Computed(@() [bw.value, bh.value])

let radarVisible = Computed(@() IsRadarVisible.value || IsRadar2Visible.value || !CollapsedIcon.value)

let radarCollapsed = @() {
  watch = radarCollapsedPos
  rendObj = ROBJ_IMAGE
  image = radarPic
  pos = radarCollapsedPos.value
  size = [sh(5), sh(5)]
  color = Color(71, 232, 39, 240)
}

let radarComponent = @() {
  watch = [radarVisible, IsRadarHudVisible, IsFCSVisible]
  children = radarVisible.value ? mkRadar(radarPos)
    : IsRadarHudVisible.value ? [ radarCollapsed, IsFCSVisible.value ? mkFCSComponent(radarPos) : null ]
    : null
}

return {
  radarComponent
}