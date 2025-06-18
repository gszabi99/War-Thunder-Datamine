from "%rGui/globals/ui_library.nut" import *

let { round_by_value, round } = require("%sqstd/math.nut")
let { Point2, IPoint3 } = require("dagor.math")
let { Speed, Altitude, CompassValue, Mach, FuelConsume, FuelInternal, FuelTotal,
  RpmRel, RpmRel1, WaterTemp, WaterTemp1, Nozzle0, OilTemp0, Rpm, Rpm1, OilPress0,
  OilPress1, BarAltitude } = require("%rGui/planeState/planeFlyState.nut")
let string = require("string")
let { mpsToKnots, metrToFeet } = require("%rGui/planeIlses/ilsConstants.nut")
let { get_local_unixtime, unixtime_to_local_timetbl } = require("dagor.time")

let SpeedKnots = Computed(@() round(Speed.value * mpsToKnots).tointeger())
let MachRounded = Computed(@() round_by_value(Mach.value, 0.01))
let Course = Computed(@() round(CompassValue.value < 0. ? (360.0 + CompassValue.value) : CompassValue.value).tointeger())
let AltFeet = Computed(@() (Altitude.value * metrToFeet).tointeger())
let BarAltFeet = Computed(@() (BarAltitude.get() * metrToFeet).tointeger())
let FuelConsM = Computed(@() (FuelConsume.value * 60.0).tointeger())

function clockUpdate() {
  let time = unixtime_to_local_timetbl(get_local_unixtime())
  return {
    text = string.format("%02d:%02d:%02d", time.hour, time.min, time.sec)
  }
}

let valueTable = {
  ["speed"] = Speed,
  ["speed_knots"] = SpeedKnots,
  ["altitude"] = Altitude,
  ["altitude_feet"] = AltFeet,
  ["bar_altitude"] = BarAltitude,
  ["bar_altitude_feet"] = BarAltFeet,
  ["mach"] = MachRounded,
  ["course"] = Course,
  ["fuel_cons_per_m"] = FuelConsM,
  ["fuel"] = FuelInternal,
  ["total_fuel"] = FuelTotal,
  ["relative_rpm"] = RpmRel,
  ["relative_rpm1"] = RpmRel1,
  ["rpm"] = Rpm,
  ["rpm1"] = Rpm1,
  ["water_temperature"] = WaterTemp,
  ["water_temperature1"] = WaterTemp1,
  ["nozzle"] = Nozzle0,
  ["oil"] = OilTemp0,
  ["clock"] = Watched(0),
  ["oil_pressure"] = OilPress0,
  ["oil_pressure1"] = OilPress1,
}

let updateFuncs = {
  ["clock"] = clockUpdate
}

let devicesSetting = Watched([])
function devicesSettingUpd(devices_blk) {
  let res = []
  for (local i = 0; i < devices_blk.blockCount(); ++i) {
    let devBlk = devices_blk.getBlock(i)
    let valueStr = devBlk.getStr("value", "")
    if (valueStr == "")
      continue
    let devInfo = {
      pos = devBlk.getPoint2("pos", Point2(0, 0)) * 100.0
      size = devBlk.getPoint2("size", Point2(1, 1)) * 100.0
      color = devBlk.getIPoint3("color", IPoint3(255, 0, 0))
      fontSize = devBlk.getInt("fontSize", 40)
      padding = devBlk.getPoint2("padding", Point2(0, 0))
      formatStr = devBlk.getStr("format", "%d")
      value = valueStr
      fontId = Fonts?[devBlk.getStr("font", "digital")] ?? Fonts.digital
      mult = devBlk.getReal("multiplier", 1.0)
    }
    res.append(devInfo)
  }
  devicesSetting.set(res)
}

let mkChildren = @(devices_config)
  devices_config.map(function(v){
    let watch = valueTable?[v.value] ?? Watched(0)
    let upd = updateFuncs?[v.value]
    return @() {
      watch = watch
      pos = [pw(v.pos.x), ph(v.pos.y)]
      size = [pw(v.size.x), ph(v.size.y)]
      halign = ALIGN_RIGHT
      rendObj = ROBJ_TEXT
      padding = [v.padding.x, v.padding.y]
      color = Color(v.color.x, v.color.y, v.color.z)
      fontSize = v.fontSize
      font = v.fontId
      text = string.format(v.formatStr, watch.value * v.mult)
      behavior = Behaviors.RtPropUpdate
      update = upd
    }
  })

function devices(width, height, posX = 0, posY = 0) {
  return @(){
    watch = devicesSetting
    pos = [posX, posY]
    size = [width, height]
    children = mkChildren(devicesSetting.value)
  }
}

return {
  devices
  devicesSettingUpd
}