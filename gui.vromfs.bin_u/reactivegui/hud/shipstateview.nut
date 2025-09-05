from "%rGui/globals/ui_library.nut" import *

let { speed, portSideMachine, sideboardSideMachine, stopping } = require("%rGui/shipState.nut")
let { isInitializedMeasureUnits, measureUnitsNames } = require("%rGui/options/optionsMeasureUnits.nut")

let machineDirectionLoc = [
  loc("HUD/ENGINE_REV_BACK_SHORT")
  loc("HUD/ENGINE_REV_BACK_SHORT")
  loc("HUD/ENGINE_REV_BACK_SHORT")
  ""
  loc("HUD/ENGINE_REV_AHEAD_SHORT")
  loc("HUD/ENGINE_REV_AHEAD_SHORT")
  loc("HUD/ENGINE_REV_AHEAD_SHORT")
  loc("HUD/ENGINE_REV_AHEAD_SHORT")
  loc("HUD/ENGINE_REV_AHEAD_SHORT")
  ""
  ""
  ""
]

let machineSpeedLoc = [
  loc("HUD/ENGINE_REV_FULL_SHORT")
  loc("HUD/ENGINE_REV_TWO_THIRDS_SHORT")
  loc("HUD/ENGINE_REV_ONE_THIRD_SHORT")
  loc("HUD/ENGINE_REV_STOP_SHORT")
  loc("HUD/ENGINE_REV_ONE_THIRD_SHORT")
  loc("HUD/ENGINE_REV_TWO_THIRDS_SHORT")
  loc("HUD/ENGINE_REV_STANDARD_SHORT")
  loc("HUD/ENGINE_REV_FULL_SHORT")
  loc("HUD/ENGINE_REV_FLANK_SHORT")
  "1"
  "2"
  "R"
]

let machineSpeedDirection = [
  "back"
  "back"
  "back"
  "stop"
  "forward"
  "forward"
  "forward"
  "forward"
  "forward"
  "forward"
  "forward2"
  "back"
]

local fitTextToBox = kwarg(function(box, text, font, fontSize = null, minSize = 8) {
  local sz = calc_comp_size({ rendObj = ROBJ_TEXT, text, font, fontSize })
  fontSize = fontSize ?? calc_comp_size({ rendObj = ROBJ_TEXT, text = "A", font, fontSize })
  sz = [sz[0] > 1 ? sz[0] : 1, sz[1] > 1 ? sz[1] : 1]
  let scale = min(box[0] / sz[0], box[1] / sz[1])
  if (scale >= 1.0)
    return fontSize
  let res = fontSize * scale
  if (res < minSize)
    return minSize
  return res
})

let defFont = Fonts.tiny_text_hud

function speedValue(params = {}) {
  let { font = defFont, margin = static [0, 0, 0, sh(1)], fontSize = null } = params
  return @() {
    watch = speed
    rendObj = ROBJ_TEXT
    text = speed.get().tostring()
    font
    fontSize
    margin
  }
}

function speedUnits(params = {}) {
  let { fontSize = null, box = null, font = defFont } = params
  return function() {
    let text = isInitializedMeasureUnits.get() ? loc(measureUnitsNames.get().speed) : ""
    return {
      watch = [isInitializedMeasureUnits, measureUnitsNames]
      rendObj = ROBJ_TEXT
      font
      fontSize = box ? fitTextToBox({ text, box, fontSize, font }) : fontSize
      text
      margin = static [0, 0, hdpx(1.5), sh(0.5)]
    }
  }
}

let averageSpeed = Computed(@() clamp((portSideMachine.get() + sideboardSideMachine.get()) / 2, 0, machineSpeedLoc.len()))

let machineSpeed = @(params = {}) function() {
  let { fontSize = null, box = null, font = defFont, fontColor = Color(200, 200, 200) } = params
  let speedLoc = machineSpeedLoc[averageSpeed.get()]
  let directionLoc = machineDirectionLoc[averageSpeed.get()]
  let text = "  ".join([speedLoc, directionLoc], true)
  return {
    watch = [averageSpeed, stopping]
    rendObj = ROBJ_TEXT
    font
    fontSize = box ? fitTextToBox({ fontSize, text, box, font }) : null
    color = stopping.get() ? Color(255, 100, 100) : fontColor
    text
  }
}

return {
  speedValue
  speedUnits
  machineSpeed
  averageSpeed
  machineSpeedLoc
  machineSpeedDirection
}
