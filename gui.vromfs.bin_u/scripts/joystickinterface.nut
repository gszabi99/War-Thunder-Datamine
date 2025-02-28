from "%scripts/dagui_natives.nut" import get_axis_value, get_axis_index, joystick_get_default
from "%scripts/dagui_library.nut" import *

let { hasXInputDevice } = require("controls")
let { is_stereo_mode } = require("vr")
let { sin, cos, pow, atan2, abs, sqrt } = require("math")
let { joystickGetCurSettings } = require("%scripts/controls/controlsCompatibility.nut")

let defaultAxisWatch = ["decal_move_x", "decal_move_y"]
const maxAbsoluteAxisValue = 1.0
let getArtilleryAxisWatch = @() [defaultAxisWatch]

/**
* Return array [dx, dy] of current cursor displasement with the stick.
* dx and dy are floats [0;+1].
*
* @dt - time form last update
* @NonlinearityPower - (integer) in this power length of deviation vecotr will be powered
*   to make control more accurate. Lentgh of deviation vector is bounded in [0,+1]
* @axisValues - result of getMaxDeviatedAxisInfo()
*/

function getPositionDelta(dt, nonlinearityPower, axisValues) {
  let distance = pow(axisValues.normLength, nonlinearityPower) * dt
  let dx = distance * cos(axisValues.angle)
  let dy = -distance * sin(axisValues.angle)
  return [dx, dy]
}

function getMaxDeviatedAxisInfo(axisData = null, deadzone = 0.0652) {
  let result = {
    x = 0,
    y = 0,
    angle = 0,
    normX = 0,
    normY = 0,
    rawLength = 0,
    normLength = 0
  }

  if (!axisData)
    return result

  local maxDeviationSq = 0, rawX = 0, rawY = 0
  foreach (_idx, data in axisData) {
    let deviationSq = pow(data[0], 2) + pow(data[1], 2)
    if (deviationSq > maxDeviationSq) {
      maxDeviationSq = deviationSq
      rawX = data[0]
      rawY = data[1]
    }
  }

  if (sqrt(maxDeviationSq) <= deadzone)
    return result

  let signX = rawX >= 0 ? 1 : -1
  let signY = rawY >= 0 ? 1 : -1
  let denominator = maxAbsoluteAxisValue - deadzone //to normalize
  let rawSide = sqrt(pow(rawX, 2) + pow(rawY, 2))

  result.x = rawX
  result.y = rawY
  result.angle = atan2(rawY, rawX)
  result.normX = (min(abs(rawX), maxAbsoluteAxisValue) - deadzone).tofloat() / denominator * signX
  result.normY = (min(abs(rawY), maxAbsoluteAxisValue) - deadzone).tofloat() / denominator * signY
  result.rawLength = rawSide
  result.normLength = (min(rawSide, maxAbsoluteAxisValue) - deadzone).tofloat() / denominator

  return result
}

function getWheelMenuAxisWatch(unitType) {
  if (hasXInputDevice() || is_stereo_mode()) {
    if ((unitType?.wheelmenuAxis ?? []).len() > 0)
      return [unitType.wheelmenuAxis]
  }
  return [defaultAxisWatch, ["camx", "camy"]]
}

function getAxisData(watchAxis = [], stuckAxis = {}) {
  let device = joystick_get_default()
  let settings = joystickGetCurSettings()
  if (!device || !settings)
    return null

  let res = []
  foreach (axisPair in watchAxis) {
    let pos = [0, 0]

    foreach (idx, axisName in axisPair) {
      let axisIndex = get_axis_index(axisName)
      if (axisIndex != -1) {
        local value = get_axis_value(axisIndex)

        let stuckValue = stuckAxis?[axisName]
        if (value == stuckValue)
          value = 0
        else if (stuckValue != null)
          stuckAxis.$rawdelete(axisName)

        pos[idx] = value
      }
    }

    res.append(pos)
  }
  return res
}

function getAxisStuck(watchAxis = []) {
  let axisData = getAxisData(watchAxis, null)
  let res = {}
  foreach (idxPair, axisPair in watchAxis) {
    if (!(idxPair in axisData))
      continue

    foreach (idx, axisName in axisPair) {
      if (axisName in res)
        continue

      res[axisName] <- getTblValue(idx, axisData[idxPair], 0)
    }
  }
  return res
}

return {
  getPositionDelta
  getArtilleryAxisWatch
  getMaxDeviatedAxisInfo
  getWheelMenuAxisWatch
  getAxisData
  getAxisStuck
}