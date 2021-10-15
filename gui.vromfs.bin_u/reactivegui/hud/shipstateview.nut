local {speed, portSideMachine, sideboardSideMachine, stopping } = require("reactiveGui/shipState.nut")

local machineDirectionLoc = [
  ::loc("HUD/ENGINE_REV_BACK_SHORT")
  ::loc("HUD/ENGINE_REV_BACK_SHORT")
  ::loc("HUD/ENGINE_REV_BACK_SHORT")
  ""
  ::loc("HUD/ENGINE_REV_AHEAD_SHORT")
  ::loc("HUD/ENGINE_REV_AHEAD_SHORT")
  ::loc("HUD/ENGINE_REV_AHEAD_SHORT")
  ::loc("HUD/ENGINE_REV_AHEAD_SHORT")
  ::loc("HUD/ENGINE_REV_AHEAD_SHORT")
  ""
  ""
  ""
]

local machineSpeedLoc = [
  ::loc("HUD/ENGINE_REV_FULL_SHORT")
  ::loc("HUD/ENGINE_REV_TWO_THIRDS_SHORT")
  ::loc("HUD/ENGINE_REV_ONE_THIRD_SHORT")
  ::loc("HUD/ENGINE_REV_STOP_SHORT")
  ::loc("HUD/ENGINE_REV_ONE_THIRD_SHORT")
  ::loc("HUD/ENGINE_REV_TWO_THIRDS_SHORT")
  ::loc("HUD/ENGINE_REV_STANDARD_SHORT")
  ::loc("HUD/ENGINE_REV_FULL_SHORT")
  ::loc("HUD/ENGINE_REV_FLANK_SHORT")
  "1"
  "2"
  "R"
]

local fitTextToBox = ::kwarg(function(box, text, font, fontSize=null, minSize = 8){
  local sz = ::calc_comp_size({rendObj = ROBJ_DTEXT, text, font, fontSize})
  fontSize = fontSize ?? ::calc_comp_size({rendObj = ROBJ_DTEXT, text = "A", font, fontSize})
  sz = [sz[0] > 1 ? sz[0] : 1, sz[1] > 1 ? sz[1] : 1]
  local scale = min(box[0]/sz[0], box[1]/sz[1])
  if (scale >= 1.0)
    return fontSize
  local res = fontSize*scale
  if (res < minSize)
    return minSize
  return res
})

local defFont = Fonts.tiny_text_hud

local function speedValue(params = {}) {
  local { font = defFont, margin = [0,0,0,sh(1)] } = params
  return @() {
    watch = speed
    rendObj = ROBJ_DTEXT
    text = speed.value.tostring()
    font
    margin
  }
}

local function speedUnits(params = {}) {
  local { fontSize = null, box = null, font = defFont } = params
  local text = ::cross_call.measureTypes.SPEED.getMeasureUnitsName()
  return {
    rendObj = ROBJ_DTEXT
    font
    fontSize = box ? fitTextToBox({text, box, fontSize, font}) : null
    text = ::cross_call.measureTypes.SPEED.getMeasureUnitsName()
    margin = [0,0,hdpx(1.5),sh(0.5)]
  }
}

local averageSpeed = Computed(@() clamp((portSideMachine.value + sideboardSideMachine.value) / 2, 0, machineSpeedLoc.len()))

local machineSpeed = @(params = {}) function() {
  local { fontSize = null, box = null, font = defFont, fontColor = Color(200, 200, 200) } = params
  local speedLoc = machineSpeedLoc[averageSpeed.value]
  local directionLoc = machineDirectionLoc[averageSpeed.value]
  local text = "  ".join([speedLoc, directionLoc], true)
  return {
    watch = [averageSpeed, stopping]
    rendObj = ROBJ_DTEXT
    font
    fontSize = box ? fitTextToBox({fontSize, text, box, font}) : null
    color = stopping.value ? Color(255, 100, 100) : fontColor
    text
  }
}

return {
  speedValue
  speedUnits
  machineSpeed
}
