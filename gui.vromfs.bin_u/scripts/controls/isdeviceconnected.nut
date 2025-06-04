from "%scripts/dagui_natives.nut" import fill_joysticks_desc
from "%scripts/dagui_library.nut" import *

let DataBlock  = require("DataBlock")

function isDeviceConnected(devId = null) {
  if (!devId)
    return false

  let blk = DataBlock()
  fill_joysticks_desc(blk)

  for (local i = 0; i < blk.blockCount(); i++) {
    let device = blk.getBlock(i)
    if (device?.disconnected)
      continue

    if (device?.devId && device.devId.tolower() == devId.tolower())
      return true
  }

  return false
}

return {
  isDeviceConnected
}