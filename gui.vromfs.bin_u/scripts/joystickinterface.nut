local { isWheelmenuAxisConfigurable } = require("scripts/wheelmenu/multifuncmenuShared.nut")

::joystickInterface <- {
  maxAbsoluteAxisValue = 32000
  invertedByDefault = {}

  function getAxisWatch(isForWheelmenu = false, isForArtillery = false)
  {
    local res = []
    if (isForWheelmenu) {
      if (::is_xinput_device() && isWheelmenuAxisConfigurable())
        res.append(::get_player_cur_unit()?.unitType.wheelmenuAxis ?? [])
      else
        res.append(["decal_move_x", "decal_move_y"], ["camx", "camy"])
    }
    if (isForArtillery) {
      res.append(["decal_move_x", "decal_move_y"])
    }
    return res
  }

  function getAxisStuck(watchAxis = [])
  {
    local axisData = getAxisData(watchAxis, null)
    local res = {}
    foreach (idxPair, axisPair in watchAxis)
    {
      if (!(idxPair in axisData))
        continue

      foreach(idx, axisName in axisPair)
      {
        if (axisName in res)
          continue

        res[axisName] <- ::getTblValue(idx, axisData[idxPair], 0)
      }
    }
    return res
  }

  function getAxisData(watchAxis = [], stuckAxis = {})
  {
    local device = ::joystick_get_default()
    local settings = ::joystick_get_cur_settings()
    if (!device || !settings)
      return null

    local res = []
    foreach(axisPair in watchAxis)
    {
      local pos = [0, 0]

      foreach(idx, axisName in axisPair)
      {
        local axisIndex = ::get_axis_index(axisName)
        if (axisIndex != -1)
        {
          local axis = settings.getAxis(axisIndex)
          if (axis.axisId != -1)
          {
            local sign = (axis.inverse == ::getTblValue(axisName, invertedByDefault, false)) ? 1.0 : -1.0
            local value = sign * device.getAxisPosRaw(axis.axisId)

            local stuckValue = ::getTblValue(axisName, stuckAxis, null)
            if (value == stuckValue)
              value = 0
            else if (stuckValue != null)
              delete stuckAxis[axisName]

            pos[idx] = value
          }
        }
      }

      res.append(pos)
    }
    return res
  }

  function getMaxDeviatedAxisInfo(axisData = null, limit = 32000, deadzone = 2000)
  {
    local result = {
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

    local maxDeviationSq=0, rawX=0, rawY=0
    foreach(idx, data in axisData)
    {
      local deviationSq = ::pow(data[0], 2) + ::pow(data[1], 2)
      if (deviationSq > maxDeviationSq)
      {
        maxDeviationSq = deviationSq
        rawX = data[0]
        rawY = data[1]
      }
    }

    if (::sqrt(maxDeviationSq) <= deadzone)
      return result

    local signX = rawX >= 0 ? 1 : -1
    local signY = rawY >= 0 ? 1 : -1
    local denominator = limit - deadzone //to normalize
    local rawSide = ::sqrt(::pow(rawX, 2) + ::pow(rawY, 2))

    result.x = rawX
    result.y = rawY
    result.angle = ::atan2(rawY, rawX)
    result.normX = (min(::abs(rawX), limit) - deadzone).tofloat() / denominator * signX
    result.normY = (min(::abs(rawY), limit) - deadzone).tofloat() / denominator * signY
    result.rawLength = rawSide
    result.normLength = (min(rawSide, limit) - deadzone).tofloat() / denominator

    return result
  }

  /**
   * Return array [dx, dy] of current cursor displasement with the stick.
   * dx and dy are floats [0;+1].
   *
   * @dt - time form last update
   * @NonlinearityPower - (integer) in this power length of deviation vecotr will be powered
   *   to make control more accurate. Lentgh of deviation vector is bounded in [0,+1]
   * @axisValues - result of getMaxDeviatedAxisInfo()
   */
  function getPositionDelta(dt, nonlinearityPower, axisValues)
  {
    local distance = ::pow(axisValues.normLength, nonlinearityPower) * dt
    local dx =   distance * ::cos(axisValues.angle)
    local dy = - distance * ::sin(axisValues.angle)
    return [dx, dy]
  }

  function _collectInvertedAxis()
  {
    invertedByDefault = {}
    foreach (controlsList in [::aircraft_controls_wizard_config, ::tank_controls_wizard_config])
      foreach (item in controlsList)
      {
        if (type(item) == "table" && ("id" in item) && ("type" in item))
          if (item.type == CONTROL_TYPE.AXIS && ("showInverted" in item) && item.showInverted())
            invertedByDefault[item.id] <- true
      }
  }
}

::joystickInterface._collectInvertedAxis()
