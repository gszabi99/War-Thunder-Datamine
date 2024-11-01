from "%rGui/globals/ui_library.nut" import *

let interopGen = require("%rGui/interopGen.nut")

let Speed = Watched(0.0)
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
let Bank = Watched(0.0)
let HorizonX = Watched(0)
let HorizonY = Watched(0)
let FuelConsume = Watched(0.0)
let FuelInternal = Watched(0)
let FuelTotal = Watched(0)
let RpmRel = Watched(0)
let RpmRel1 = Watched(0)
let Rpm = Watched(0)
let Rpm1 = Watched(0)
let WaterTemp = Watched(0)
let WaterTemp1 = Watched(0)
let HorAccelX = Watched(0.0)
let HorAccelY = Watched(0.0)
let Nozzle0 = Watched(0)
let OilTemp0 = Watched(0)
let TurnRate = Watched(0.0)
let OilPress0 = Watched(0)
let OilPress1 = Watched(0)

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
  MaxOverload,
  FuelConsume,
  FuelInternal,
  FuelTotal,
  RpmRel,
  RpmRel1,
  Rpm,
  Rpm1,
  WaterTemp,
  WaterTemp1,
  Bank,
  HorAccelX,
  HorAccelY,
  Nozzle0,
  OilTemp0,
  TurnRate,
  OilPress0,
  OilPress1
}

interopGen({
  stateTable = planeState
  prefix = "plane"
  postfix = "Update"
})

return planeState