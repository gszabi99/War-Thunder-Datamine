from "%rGui/globals/ui_library.nut" import *

let interopGen = require("%rGui/interopGen.nut")

let Speed = Watched(0)
let Altitude = Watched(0.0)
let BarAltitude = Watched(0.0)
let ClimbSpeed = Watched(0.0)
let Tangage = Watched(0.0)
let Roll = Watched(0.0)
let CompassValue = Watched(0.0)
let Aos = Watched(0.0)
let Aoa = Watched(0.0)
let Mach = Watched(0.0)
let Overload = Watched(0.0)
let VertOverload = Watched(0.0)
let MaxOverload = Watched(0.0)
let Tas = Watched(0.0)
let Accel = Watched(0.0)
let HorizonX = Watched(0)
let HorizonY = Watched(0)

let planeState = {
  Speed,
  Altitude,
  BarAltitude,
  ClimbSpeed,
  Tangage,
  Roll,
  CompassValue,
  Aos,
  Aoa,
  Mach,
  Overload,
  Accel,
  Tas,
  HorizonX,
  HorizonY,
  VertOverload,
  MaxOverload
}

interopGen({
  stateTable = planeState
  prefix = "plane"
  postfix = "Update"
})

return planeState