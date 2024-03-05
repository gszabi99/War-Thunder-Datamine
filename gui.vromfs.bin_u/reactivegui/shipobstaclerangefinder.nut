from "%rGui/globals/ui_library.nut" import *

let { obstacleIsNear, distanceToObstacle } = require("shipState.nut")
let { alert } = require("style/colors.nut").hud.damageModule
let { abs } = require("%sqstd/math.nut")
let { measureUnitsNames } = require("options/optionsMeasureUnits.nut")

let showCollideWarning = Computed(@() distanceToObstacle.value < 0)

let textToShow = Computed(@() (showCollideWarning.value ? loc("hud_ship_collide_warning") :
       loc("hud_ship_depth_on_course_warning"))
)

local criticalDistance = 50.0
local redGlowColor = Color(221, 17, 17, 50)
local yellowGlowColor = Color(255, 176, 37, 250)
local warningColor = Color(255, 176, 37)

let land_icon = Picture($"ui/gameuiskin#land_icon.svg:{hdpx(35)}:{hdpx(30)}:P")
let deep_yelow_bg = Picture($"ui/gameuiskin#deep_yelow_bg.avif:{hdpx(200)}:{hdpx(80)}:P")
let deep_red_bg = Picture($"ui/gameuiskin#deep_red_bg.avif:{hdpx(200)}:{hdpx(80)}:P")
let bg_yelow_distance = Picture($"ui/gameuiskin#bg_yelow_distance.avif:{hdpx(50)}:{hdpx(25)}:P")
let bg_red_distance = Picture($"ui/gameuiskin#bg_red_distance.avif:{hdpx(50)}:{hdpx(25)}:P")


let obstacleDistance = @() {
  watch = distanceToObstacle
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  pos = [0, hdpx(65)]
  children = [
    {
      rendObj = ROBJ_IMAGE
      image = distanceToObstacle.value > criticalDistance
              ? bg_yelow_distance
              : bg_red_distance
      size = [hdpx(50), hdpx(25)]
    }
    @() {
      watch = measureUnitsNames
      rendObj = ROBJ_TEXT
      font = Fonts.tiny_text
      fontFxColor = Color(250, 250, 250, 250)
      fontFxFactor = min(64, hdpx(64))
      fontFx = FFT_GLOW
      text = "".concat(abs(distanceToObstacle.value), loc(measureUnitsNames.value?.meters_alt ?? ""))
    }
  ]
}

let obstacleDirection = {
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = [
    @() {
      watch = distanceToObstacle
      rendObj = ROBJ_IMAGE
      image = distanceToObstacle.value > criticalDistance
              ? deep_yelow_bg
              : deep_red_bg
      size = [hdpx(200), hdpx(80)]
    }
    {
      rendObj = ROBJ_IMAGE
      image = land_icon
      size = [hdpx(35), hdpx(30)]
    }
  ]
}

return @() {
  watch = [ obstacleIsNear, distanceToObstacle ]
  size = SIZE_TO_CONTENT
  halign = ALIGN_CENTER
  isHidden = !obstacleIsNear.value
  children = [
    @() {
      watch = textToShow
      pos = [0, hdpx(170)]
      rendObj = ROBJ_TEXT
      font = Fonts.big_text
      fontFxColor = distanceToObstacle.value > criticalDistance
                    ? yellowGlowColor
                    : redGlowColor
      fontFxFactor = min(64, hdpx(64))
      fontFx = FFT_GLOW
      text = textToShow.value
      color = distanceToObstacle.value > criticalDistance
              ? warningColor
              : alert
    }
    {
      pos = [0, hdpx(300)]
      halign = ALIGN_CENTER
      children = [ obstacleDirection, obstacleDistance]
    }
  ]
}
