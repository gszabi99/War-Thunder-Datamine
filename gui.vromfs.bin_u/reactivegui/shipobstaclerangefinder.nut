from "%rGui/globals/ui_library.nut" import *

let { obstacleIsNear, distanceToObstacle, obstacleAngle } = require("shipState.nut")
let { alert } = require("style/colors.nut").hud.damageModule
let { cos, sin, PI, abs } = require("%sqstd/math.nut")
let { measureUnitsNames } = require("options/optionsMeasureUnits.nut")

let showCollideWarning = Computed(@() distanceToObstacle.value < 0)

let textToShow = Computed(@() (showCollideWarning.value ? loc("hud_ship_collide_warning") :
       loc("hud_ship_depth_on_course_warning"))
)

let criticalDistance = 50.0
let redGlowColor = Color(221, 17, 17, 50)
let yellowGlowColor = Color(255, 176, 37, 250)
let warningColor = Color(255, 176, 37)

let obstacleMarkRadius = sh(20)

let landIconWidth = hdpxi(35)
let landIconHeight = hdpxi(30)
let deepBgWidth = hdpxi(200)
let deepBgHeight = hdpxi(80)
let distanceBgWidth = hdpxi(50)
let distanceBgHeight = hdpxi(25)

let land_icon = Picture($"ui/gameuiskin#land_icon.svg:{landIconWidth}:{landIconHeight}:P")
let deep_bg = Picture($"ui/gameuiskin#deep_bg.svg:{deepBgWidth}:{deepBgHeight}:P")
let bg_distance = Picture($"ui/gameuiskin#bg_distance.svg:{distanceBgWidth}:{distanceBgHeight}:P")


let obstacleDistance = {
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = [
     @() {
      watch = distanceToObstacle
      size = [distanceBgWidth, distanceBgHeight]
      rendObj = ROBJ_IMAGE
      image = bg_distance
      color = distanceToObstacle.value > criticalDistance ? warningColor : alert
      transitions = [{ prop = AnimProp.color, duration = 0.3 }]
    }
    @() {
      watch = [measureUnitsNames, distanceToObstacle]
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
      watch = [distanceToObstacle, obstacleAngle]
      size = [deepBgWidth, deepBgHeight]
      rendObj = ROBJ_IMAGE
      image = deep_bg
      color = distanceToObstacle.value > criticalDistance ? warningColor : alert
      transitions = [{ prop = AnimProp.color, duration = 0.3 }]
      transform = {
        rotate = obstacleAngle.get()
      }
    }
    {
      size = [landIconWidth, landIconHeight]
      rendObj = ROBJ_IMAGE
      image = land_icon
    }
  ]
}

let obstacleDirectionMark = {
  halign = ALIGN_CENTER
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  flow = FLOW_VERTICAL
  gap = hdpx(-15) 
  children = [ obstacleDirection, obstacleDistance]
  transitions = [{ prop = AnimProp.translate, duration = 0.1, easing = InOutQuad }]
  behavior = Behaviors.RtPropUpdate
  function update() {
    let finalAngle = PI * (obstacleAngle.get() -90)/180.0
    return {
      transform = {
        translate = [ obstacleMarkRadius * cos(finalAngle), obstacleMarkRadius * sin(finalAngle) ]
      }
    }
  }
}

let obstacleWarningText = @() {
  watch = [textToShow, distanceToObstacle]
  pos = [0, hdpx(170)]
  rendObj = ROBJ_TEXT
  font = Fonts.big_text
  fontFxColor = distanceToObstacle.value > criticalDistance ? yellowGlowColor : redGlowColor
  fontFxFactor = min(64, hdpx(64))
  fontFx = FFT_GLOW
  text = textToShow.value
  color = distanceToObstacle.value > criticalDistance ? warningColor : alert
  transitions = [{ prop = AnimProp.color, duration = 0.3 }]
}

return @() {
  watch = obstacleIsNear
  size = flex()
  halign = ALIGN_CENTER
  children = !obstacleIsNear.get() ? null
    : [obstacleWarningText, obstacleDirectionMark]
}
