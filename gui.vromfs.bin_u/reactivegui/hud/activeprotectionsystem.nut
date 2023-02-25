from "%rGui/globals/ui_library.nut" import *

let { ActiveProtectionSystemModulesCount, activeProtectionSystemModules } = require("tankState.nut")
let colors = require("%rGui/style/colors.nut")
let { PI, cos, sin } = require("%sqstd/math.nut")

let greenColor = Color(10, 202, 10, 250)

let function createModule(module) {
  let { horAnglesX, horAnglesY, shotCountRemain, timeToReady } = module
  return function() {
    let color = shotCountRemain.value == 0 ? colors.hud.damageModule.alert
      : timeToReady.value > 0 ? colors.menu.commonTextColor
      : greenColor
    let denormDiff = (horAnglesY.value - horAnglesX.value - 180.0) % 360.0 + 180.0
    let sectorSize = denormDiff < 0.0 ? 360.0 + denormDiff : denormDiff
    let angel = (horAnglesX.value - 90.0 + sectorSize * 0.5) * PI / 180.0
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
      padding = [shHud(1), shHud(1)]
      children = {
        rendObj = ROBJ_TEXT
        pos = [pw(47 + 50 * cos(angel)), ph(45 + 50 * sin(angel))]
        font = Fonts.hud
        color = colors.menu.activeTextColor
        fontFxFactor = 5
        fontFx = FFT_SHADOW
        text = shotCountRemain.value
      }
    }
  }
}

let activeProtection = @() {
  size = [pw(70), ph(70)]
  watch = [ActiveProtectionSystemModulesCount]
  children = ActiveProtectionSystemModulesCount.value == 0 ? null
    : activeProtectionSystemModules.map(@(module) createModule(module))
}

return activeProtection