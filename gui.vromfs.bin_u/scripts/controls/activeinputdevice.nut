from "eventbus" import eventbus_subscribe
from "lastInputMonitor" import DEV_GAMEPAD, INPUT_DEVICE_USED_EVENT, get_last_used_device_mask
from "dagor.localize" import doesLocTextExist
from "%sqstd/platform.nut" import isPC
from "%scripts/dagui_library.nut" import *

let lastUsedDeviceMask = Watched(get_last_used_device_mask())
eventbus_subscribe(INPUT_DEVICE_USED_EVENT, @(ev) lastUsedDeviceMask.set(ev.mask))

let isGamepadInputActive = Computed(@() lastUsedDeviceMask.get() == 0 ? !isPC
  : (lastUsedDeviceMask.get() & DEV_GAMEPAD) != 0)

function getInputDeviceLocId(locId) {
  let gamepadLocId = $"{locId}_gamepad"
  return isGamepadInputActive.get() && doesLocTextExist(gamepadLocId) ? gamepadLocId : locId
}

let locByInputDevice = @(locId) loc(getInputDeviceLocId(locId))

return freeze({
  isGamepadInputActive
  locByInputDevice
})
