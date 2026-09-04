from "%rGui/shipState.nut" import obstacleIsNear, distanceToObstacle, obstacleAngle
from "%rGui/options/optionsMeasureUnits.nut" import measureUnitsNames
from "%sqstd/math.nut" import cos, sin, PI, abs
from "%rGui/globals/ui_library.nut" import *

let { alert } = require("%rGui/style/colors.nut").hud.damageModule

let showCollideWarning = Computed(@() distanceToObstacle.get() < 0)

let textToShow = Computed(@() (showCollideWarning.get() ? loc("hud_ship_collide_warning") :
       loc("hud_ship_depth_on_course_warning"))
)

const criticalDistance = 50.0
const redGlowColor = Color(221, 17, 17, 50)
const yellowGlowColor = Color(255, 176, 37, 250)
const warningColor = Color(255, 176, 37)

const obstacleMarkRadius = sh(20)

const landIconWidth = hdpxi(35)
const landIconHeight = hdpxi(30)
const deepBgWidth = hdpxi(200)
const deepBgHeight = hdpxi(80)
const distanceBgWidth = hdpxi(50)
const distanceBgHeight = hdpxi(25)

let land_icon = Picture($"ui/gameuiskin#land_icon.svg:{landIconWidth}:{landIconHeight}:P")
let deep_bg = Picture($"ui/gameuiskin#deep_bg.svg:{deepBgWidth}:{deepBgHeight}:P")
let bg_distance = Picture($"ui/gameuiskin#bg_distance.svg:{distanceBgWidth}:{distanceBgHeight}:P")


let obstacleDistance = {
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = [
     @() {
      watch = distanceToObstacle
      size = const [distanceBgWidth, distanceBgHeight]
      rendObj = ROBJ_IMAGE
      image = bg_distance
      color = distanceToObstacle.get() > criticalDistance ? warningColor : alert
      transitions = [{ prop = AnimProp.color, duration = 0.3 }]
    }
    @() {
      watch = [measureUnitsNames, distanceToObstacle]
      rendObj = ROBJ_TEXT
      font = Fonts.tiny_text
      fontFxColor = Color(250, 250, 250, 250)
      fontFxFactor = min(64, hdpx(64))
      fontFx = FFT_GLOW
      text = "".concat(abs(distanceToObstacle.get()), loc(measureUnitsNames.get()?.meters_alt ?? ""))
    }
  ]
}

let obstacleDirection = {
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = [
    @() {
      watch = [distanceToObstacle, obstacleAngle]
      size = const [deepBgWidth, deepBgHeight]
      rendObj = ROBJ_IMAGE
      image = deep_bg
      color = distanceToObstacle.get() > criticalDistance ? warningColor : alert
      transitions = [{ prop = AnimProp.color, duration = 0.3 }]
      transform = {
        rotate = obstacleAngle.get()
      }
    }
    {
      size = const [landIconWidth, landIconHeight]
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
  pos = const [0, hdpx(170)]
  rendObj = ROBJ_TEXT
  font = Fonts.big_text
  fontFxColor = distanceToObstacle.get() > criticalDistance ? yellowGlowColor : redGlowColor
  fontFxFactor = min(64, hdpx(64))
  fontFx = FFT_GLOW
  text = textToShow.get()
  color = distanceToObstacle.get() > criticalDistance ? warningColor : alert
  transitions = [{ prop = AnimProp.color, duration = 0.3 }]
}

return @() {
  watch = obstacleIsNear
  size = FLEX
  halign = ALIGN_CENTER
  children = !obstacleIsNear.get() ? null
    : [obstacleWarningText, obstacleDirectionMark]
}
