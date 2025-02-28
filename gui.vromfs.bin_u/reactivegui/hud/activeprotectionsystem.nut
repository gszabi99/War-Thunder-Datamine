from "%rGui/globals/ui_library.nut" import *

let { activeProtectionSystemModulesCount, activeProtectionSystemModules } = require("tankState.nut")
let colors = require("%rGui/style/colors.nut")
let { PI, cos, sin, fabs } = require("%sqstd/math.nut")

let greenColor = Color(10, 202, 10, 250)

function createModule(module) {
  let { horAnglesX, horAnglesY, shotCountRemain, shotCount, timeToReady } = module
  return function() {
    let color = shotCountRemain.value == 0 && shotCount.value > 0 ? colors.hud.damageModule.alert
      : timeToReady.value > 0 ? colors.menu.commonTextColor
      : greenColor
    let denormDiff = (horAnglesY.value - horAnglesX.value - 180.0) % 360.0 + 180.0
    let sectorSize = denormDiff < 0.0 ? 360.0 + denormDiff : denormDiff
    let angel = (horAnglesX.value - 90.0 + sectorSize * 0.5) * PI / 180.0
    return {
      rendObj = ROBJ_VECTOR_CANVAS
      watch = [horAnglesX, horAnglesX, shotCountRemain, shotCount]
      size = flex()
      fillColor = colors.transparent
      color
      lineWidth = hdpx(2) * LINE_WIDTH
      commands = [
        fabs(horAnglesY.value - horAnglesX.value - 360) % 360 > 0.1
          ? [ VECTOR_SECTOR, 50, 50, 50, 50, horAnglesX.value - 90, horAnglesY.value - 90]
          : [ VECTOR_ELLIPSE, 50, 50, 50, 50 ]
      ]
      padding = [shHud(1), shHud(1)]
      children = shotCount.value > 0
        ? {
          rendObj = ROBJ_TEXT
          pos = [pw(47 + 50 * cos(angel)), ph(45 + 50 * sin(angel))]
          font = Fonts.hud
          color = colors.menu.activeTextColor
          fontFxFactor = 5
          fontFx = FFT_SHADOW
          text = shotCountRemain.value
        }
        : null
    }
  }
}

let activeProtection = @() {
  size = [pw(70), ph(70)]
  watch = [activeProtectionSystemModulesCount]
  children = activeProtectionSystemModulesCount.value == 0 ? null
    : activeProtectionSystemModules.map(@(module) createModule(module))
}

return activeProtection