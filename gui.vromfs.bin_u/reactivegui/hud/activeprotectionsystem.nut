local { ActiveProtectionSystemModulesCount, activeProtectionSystemModules } = require("tankState.nut")
local colors = require("reactiveGui/style/colors.nut")
local { PI, cos, sin } = require("std/math.nut")

local greenColor = Color(10, 202, 10, 250)

local function createModule(module) {
  local { horAnglesX, horAnglesY, shotCountRemain, timeToReady } = module
  return function() {
    local color = shotCountRemain.value == 0 ? colors.hud.damageModule.alert
      : timeToReady.value > 0 ? colors.menu.commonTextColor
      : greenColor
    local angelOffset = horAnglesY.value < 0 && horAnglesX.value > 0 ? 90 : -90
    local angel = (horAnglesX.value + angelOffset + (horAnglesY.value - horAnglesX.value)*0.5) * PI / 180.0
    return {
      rendObj = ROBJ_VECTOR_CANVAS
      watch = [horAnglesX, horAnglesX, shotCountRemain]
      size = flex()
      fillColor = colors.transparent
      color
      lineWidth = hdpx(2) * LINE_WIDTH
      commands = [
        [ VECTOR_SECTOR, 50, 50, 50, 50, horAnglesX.value - 90, horAnglesY.value - 90]
      ]
      padding = [::shHud(1), ::shHud(1)]
      children = {
        rendObj = ROBJ_DTEXT
        pos = [pw(47 + 50*cos(angel)), ph(45 + 50*sin(angel))]
        font = Fonts.hud
        color = colors.menu.activeTextColor
        fontFxFactor = 5
        fontFx = FFT_SHADOW
        text = shotCountRemain.value
      }
    }
  }
}

local activeProtection = @() {
  size = [pw(110), ph(110)]
  watch = [ActiveProtectionSystemModulesCount]
  children = ActiveProtectionSystemModulesCount.value == 0 ? null
    : activeProtectionSystemModules.map(@(module) createModule(module))
}

return activeProtection