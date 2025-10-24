from "%rGui/globals/ui_library.nut" import *

let { round_by_value, round } = require("%sqstd/math.nut")
let { Point2, IPoint3 } = require("dagor.math")
let { Speed, Altitude, CompassValue, Mach, FuelConsume, FuelInternal, FuelTotal,
  RpmRel, RpmRel1, WaterTemp, WaterTemp1, Nozzle0, OilTemp0, Rpm, Rpm1, OilPress0,
  OilPress1, BarAltitude } = require("%rGui/planeState/planeFlyState.nut")
let string = require("string")
let { mpsToKnots, metrToFeet } = require("%rGui/planeIlses/ilsConstants.nut")
let { get_local_unixtime, unixtime_to_local_timetbl } = require("dagor.time")

let SpeedKnots = Computed(@() round(Speed.get() * mpsToKnots).tointeger())
let MachRounded = Computed(@() round_by_value(Mach.get(), 0.01))
let Course = Computed(@() round(CompassValue.get() < 0. ? (360.0 + CompassValue.get()) : CompassValue.get()).tointeger())
let AltFeet = Computed(@() (Altitude.get() * metrToFeet).tointeger())
let BarAltFeet = Computed(@() (BarAltitude.get() * metrToFeet).tointeger())
let FuelConsM = Computed(@() (FuelConsume.get() * 60.0).tointeger())

function clockUpdate() {
  let time = unixtime_to_local_timetbl(get_local_unixtime())
  return {
    text = string.format("%02d:%02d:%02d", time.hour, time.min, time.sec)
  }
}

function clockUpdateLsdMin() {
  let time = unixtime_to_local_timetbl(get_local_unixtime())
  return {
    text = string.format("%02d:%02d", time.hour, time.min)
  }
}

function clockUpdateLsdSec() {
  let time = unixtime_to_local_timetbl(get_local_unixtime())
  return {
    text = string.format("%02d", time.sec)
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
  ["clock_lsd"] = Watched(0),
  ["oil_pressure"] = OilPress0,
  ["oil_pressure1"] = OilPress1,
}

let updateFuncs = {
  ["clock"] = clockUpdate,
  ["clock_lsd"] = clockUpdateLsdMin
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
      needBack = devBlk.getBool("needBackground", false)
      background = devBlk.getIPoint3("backgroundColor", IPoint3(0, 0, 0))
    }
    res.append(devInfo)
  }
  devicesSetting.set(res)
}

function digital_lsd_clock(v) {
  return {
    pos = [pw(v.pos.x), ph(v.pos.y)]
    size = [pw(v.size.x), ph(v.size.y)]
    rendObj = ROBJ_SOLID
    color = Color(v.background.x, v.background.y, v.background.z)
    flow = FLOW_HORIZONTAL
    halign = ALIGN_RIGHT
    children = [
      {
        halign = ALIGN_RIGHT
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        padding = [v.padding.x, 0, v.padding.x, v.padding.y]
        color = Color(v.color.x, v.color.y, v.color.z)
        fontSize = v.fontSize
        font = v.fontId
        text = "22:22"
        behavior = Behaviors.RtPropUpdate
        update = clockUpdateLsdMin
      }
      {
        halign = ALIGN_RIGHT
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        padding = [v.padding.x + v.fontSize * 0.2 - 2, v.padding.y, v.padding.x, 5]
        color = Color(v.color.x, v.color.y, v.color.z)
        fontSize = v.fontSize * 0.8
        font = v.fontId
        behavior = Behaviors.RtPropUpdate
        update = clockUpdateLsdSec
        text = "22"
      }
    ]
  }
}

let mkChildren = @(devices_config)
  devices_config.map(function(v){
    let watch = valueTable?[v.value] ?? Watched(0)
    let upd = updateFuncs?[v.value]
    return v.value != "clock_lsd" ? {
      pos = [pw(v.pos.x), ph(v.pos.y)]
      size = [pw(v.size.x), ph(v.size.y)]
      rendObj = ROBJ_SOLID
      color = !v.needBack ? 0 : Color(v.background.x, v.background.y, v.background.z)
      children = @() {
        watch = watch
        size = flex()
        halign = ALIGN_RIGHT
        rendObj = ROBJ_TEXT
        padding = [v.padding.x, v.padding.y]
        color = Color(v.color.x, v.color.y, v.color.z)
        fontSize = v.fontSize
        font = v.fontId
        text = string.format(v.formatStr, watch.get() * v.mult)
        behavior = Behaviors.RtPropUpdate
        update = upd
      }
    } : digital_lsd_clock(v)
  })

function devices(width, height, posX = 0, posY = 0) {
  return @(){
    watch = devicesSetting
    pos = [posX, posY]
    size = [width, height]
    children = mkChildren(devicesSetting.get())
  }
}

return {
  devices
  devicesSettingUpd
}