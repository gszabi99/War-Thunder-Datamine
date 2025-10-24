from "%rGui/globals/ui_library.nut" import *

let { bw, bh, rw, rh } = require("%rGui/style/screenState.nut")
let { CollapsedIcon } = require("%rGui/twsState.nut")
let { mkRadar } = require("%rGui/radarComponent.nut")
let { mkFCSComponent } = require("%rGui/fcsComponent.nut")
let { IsRadarVisible, IsRadar2Visible, IsRadarHudVisible } = require("%rGui/radarState.nut")
let { HasFcsIndication, IsFcsVisible, IsVisible } = require("%rGui/fcsState.nut")
let { radarHud, radarIndication } = require("%rGui/radar.nut")
let { sonarIndication } = require("%rGui/sonar.nut")

let radarPic = Picture("!ui/gameuiskin#radar_stby_icon")
let fcsPic = Picture("!ui/gameuiskin#fcs_stby_icon")
let collapsedIconPos = Computed(@() [bw.get() + 0.015 * rw.get(), bh.get() + 0.032 * rh.get()])
let radarPos = Computed(@() [bw.get(), bh.get()])
let radarColor = Watched(Color(0, 255, 0, 255))

let radarVisible = Computed(@() IsRadarVisible.get() || IsRadar2Visible.get() || !CollapsedIcon.get())
let isFcsAvailable = Computed(@() IsVisible.get() && HasFcsIndication.get())

function mkCollapsedIcon(icon) {
 return @() {
    watch = collapsedIconPos
    rendObj = ROBJ_IMAGE
    pos = collapsedIconPos.get()
    size = sh(5)
    color = Color(71, 232, 39, 240)
    image = icon
  }
}
let fcsCollapsed = mkCollapsedIcon(fcsPic)
let radarCollapsed = mkCollapsedIcon(radarPic)

let radarComponent = @() {
  watch = [radarVisible, IsRadarHudVisible, IsFcsVisible, isFcsAvailable]
  children = radarVisible.get() && IsRadarHudVisible.get() ? [
    mkRadar()
    radarHud(sh(30), sh(30), radarPos.get()[0], radarPos.get()[1], radarColor, {
      hasTxtBlock = true
    })
    radarIndication(radarColor)
  ] : isFcsAvailable.get() ? [
    !IsFcsVisible.get() ? fcsCollapsed : IsRadarHudVisible.get() ? radarCollapsed : null
    IsFcsVisible.get() ? mkFCSComponent(radarPos, [sh(20), sh(20)]) : null
  ] : [
    IsRadarHudVisible.get() ? radarCollapsed : null
  ]
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

return {
  radarComponent
  sonarComponent
}