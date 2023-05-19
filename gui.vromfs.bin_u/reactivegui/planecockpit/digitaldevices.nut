from "%rGui/globals/ui_library.nut" import *

let DataBlock = require("DataBlock")
let { round } =  require("math")
let { round_by_value } = require("%sqstd/math.nut")
let { Point2, IPoint3 } = require("dagor.math")
let {BlkFileName} = require("%rGui/planeState/planeToolsState.nut")
let { Speed, Altitude, CompassValue, Mach, FuelConsume, FuelInternal, FuelTotal,
  RpmRel, WaterTemp } = require("%rGui/planeState/planeFlyState.nut")
let string = require("string")
let { mpsToKnots, metrToFeet } = require("%rGui/planeIlses/ilsConstants.nut")

let SpeedKnots = Computed(@() (Speed.value * mpsToKnots).tointeger())
let MachRounded = Computed(@() round_by_value(Mach.value, 0.01))
let Course = Computed(@() round(CompassValue.value < 0. ? (360.0 + CompassValue.value) : CompassValue.value).tointeger())
let AltFeet = Computed(@() (Altitude.value * metrToFeet).tointeger())
let FuelConsM = Computed(@() (FuelConsume.value * 60.0).tointeger())

let valueTable = {
  ["speed"] = Speed,
  ["speed_knots"] = SpeedKnots,
  ["altitude"] = Altitude,
  ["altitude_feet"] = AltFeet,
  ["mach"] = MachRounded,
  ["course"] = Course,
  ["fuel_cons_per_m"] = FuelConsM,
  ["fuel"] = FuelInternal,
  ["total_fuel"] = FuelTotal,
  ["relative_rpm"] = RpmRel,
  ["water_temperature"] = WaterTemp
}

let devicesSetting = Computed(function() {
  let res = []
  if (BlkFileName.value == "")
    return res
  let blk = DataBlock()
  let fileName = $"gameData/flightModels/{BlkFileName.value}.blk"
  if (!blk.tryLoad(fileName))
    return res
  let cockpitBlk = blk.getBlockByName("cockpit")
  if (!cockpitBlk)
    return res
  let devicesBlk = cockpitBlk.getBlockByName("digitalDevices")
  if (!devicesBlk)
    return res
  for (local i = 0; i < devicesBlk.blockCount(); ++i) {
    let devBlk = devicesBlk.getBlock(i)
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
    }
    res.append(devInfo)
  }
  return res
})

let mkChildren = @(devices_config)
  devices_config.map(function(v){
    let watch = valueTable?[v.value] ?? Watched(0)
    return @() {
      watch = watch
      pos = [pw(v.pos.x), ph(v.pos.y)]
      size = [pw(v.size.x), ph(v.size.y)]
      halign = ALIGN_RIGHT
      rendObj = ROBJ_TEXT
      padding = [v.padding.x, v.padding.y]
      color = Color(v.color.x, v.color.y, v.color.z)
      fontSize = v.fontSize
      font = Fonts.digital
      text = string.format(v.formatStr, watch.value)
    }
  })

let function devices(width, height, posX = 0, posY = 0) {
  return @(){
    watch = devicesSetting
    pos = [posX, posY]
    size = [width, height]
    children = mkChildren(devicesSetting.value)
  }
}

return devices