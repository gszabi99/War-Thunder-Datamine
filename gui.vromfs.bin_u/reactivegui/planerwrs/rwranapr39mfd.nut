from "%rGui/globals/ui_library.nut" import *

let math = require("math")
let { degToRad } = require("%sqstd/math_ex.nut")

let { color, rwrTargetsComponent } = require("rwrAnApr39Components.nut")

function makeGridCommands() {
  let commands = [
    [VECTOR_ELLIPSE, 0, 0, 100, 100],
    [VECTOR_ELLIPSE, 0, 0, 5, 5],
    [VECTOR_LINE, -5, 0, 5, 0],
    [VECTOR_LINE, 0, -5, 0, 5]  ]
  local azimuthMarkIndex =  0
  let middleMarkLen = 0.05
  for (local az = 0.0; az < 360.0; az += 30) {
    let sinAz = math.sin(degToRad(az))
    let cosAz = math.cos(degToRad(az))
    let azimuthMarkLen = azimuthMarkIndex % 3 == 0 ? 0.25 : 0.15
    commands.append([ VECTOR_LINE,
                      sinAz * 100.0,
                      cosAz * 100.0,
                      sinAz * (1.0 - azimuthMarkLen) * 100.0,
                      cosAz * (1.0 - azimuthMarkLen) * 100.0])
    commands.append([ VECTOR_LINE,
                      sinAz * 50.0 + cosAz * middleMarkLen * 100.0,
                      cosAz * 50.0 - sinAz * middleMarkLen * 100.0,
                      sinAz * 50.0 - cosAz * middleMarkLen * 100.0,
                      cosAz * 50.0 + sinAz * middleMarkLen * 100.0])
    ++azimuthMarkIndex
  }
  return commands
}

let gridCommands = makeGridCommands()

function createGrid() {
  return {
    pos = [pw(50), ph(50)]
    size = flex()
    color = color
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(4)
    fillColor = 0
    commands = gridCommands
  }
}

function scope(scale, fontSizeMult) {
  return {
    size = [pw(scale), ph(scale)]
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = [
      createGrid(),
      rwrTargetsComponent(fontSizeMult)
    ]
  }
}

let function tws(posWatched, sizeWatched, scale, fontSizeMult) {
  return @() {
    watch = [posWatched, sizeWatched]
    size = sizeWatched.get()
    pos = posWatched.get()
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = scope(scale, fontSizeMult)
  }
}

return tws