from "%rGui/globals/ui_library.nut" import *
let { isInVr } = require("%rGui/style/screenState.nut")
let { altCircle, altitude, weapons, mach, speed, aamScale, canShoot, flightTime } = require("%rGui/planeIlses/ilsTyphoon.nut")
let { floor } = require("%sqstd/math.nut")
let { Roll, Tangage } = require("%rGui/planeState/planeFlyState.nut")
let { sin, cos, PI } = require("math")
let { cvt } = require("dagor.math")
let { TATargetVisible } = require("%rGui/airState.nut")
let { TargetX, TargetY } = require("%rGui/hud/targetTrackerState.nut")
let { TrackerVisible, TrackerX, TrackerY, GuidanceLockState } = require("%rGui/rocketAamAimState.nut")
let { GuidanceLockResult } = require("guidanceConstants")
let { getDasScriptByPath } = require("%rGui/utils/cacheDasScriptForView.nut")

let baseColor = isInVr ? Color(10, 255, 10, 30) : Color(10, 255, 10, 10)
let baseLineWidth = floor(LINE_WIDTH + 0.5)

let radarMarks = {
  rendObj = ROBJ_DAS_CANVAS
  script = getDasScriptByPath("%rGui/planeIlses/ilsTyphoonUtil.das")
  drawFunc = "draw_hmd_radar_mark"
  setupFunc = "setup_data"
  size = flex()
  color = baseColor
  font = Fonts.hud
  fontSize = 20
  lineWidth = baseLineWidth
  markSize = 20.0
}

let addAngle = Computed(@() cvt(Tangage.get(), -90.0, 90.0, -75.0, 75.0))
let rollRad = Computed(@() -Roll.get() * PI / 180.0)
let angleStart = Computed(@() addAngle.get() * PI / 180.0 + rollRad.get())
let angleEnd   = Computed(@() (180.0 - addAngle.get()) * PI / 180.0 + rollRad.get())
let rollPitch = @(){
  watch = [Tangage, Roll]
  rendObj = ROBJ_VECTOR_CANVAS
  size = ph(20)
  pos = [pw(50), ph(50)]
  color = baseColor
  fillColor = 0
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_SECTOR, 0, 0, 100, 100, addAngle.get() - Roll.get(), 180 - addAngle.get() - Roll.get()],
    [VECTOR_LINE, 100 * cos(angleStart.get()), 100 * sin(angleStart.get()), 110 * cos(angleStart.get()), 110 * sin(angleStart.get())],
    [VECTOR_LINE, 100 * cos(angleEnd.get()), 100 * sin(angleEnd.get()), 110 * cos(angleEnd.get()), 110 * sin(angleEnd.get())],
  ]
}

let airSymbol = {
  rendObj = ROBJ_VECTOR_CANVAS
  size = const [pw(2), ph(5)]
  pos = [pw(49), ph(45)]
  color = baseColor
  fillColor = 0
  commands = [
    [VECTOR_POLY, 50, 0, 100, 100, 0, 100],
    [VECTOR_LINE, 50, 50, 50, 120]
  ]
}

function ccrpReticle(width, height) {
  return @() {
    watch = TATargetVisible
    size = ph(3)
    children = TATargetVisible.get() ? [
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = baseColor
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth
        commands = [
          [VECTOR_POLY, 0, -100, 100, 100, -100, 100],
          [VECTOR_LINE, 0, -50, 60, 70],
          [VECTOR_LINE, 20, 70, 60, 70],
          [VECTOR_LINE, 0, -50, -60, 70],
          [VECTOR_LINE, -20, 70, -60, 70],
          [VECTOR_LINE, 100, 50, 170, 20],
          [VECTOR_LINE, 150, -10, 170, 20],
          [VECTOR_LINE, -100, 50, -170, 20],
          [VECTOR_LINE, -150, -10, -170, 20],
          [VECTOR_LINE, 120, 100, 190, 120],
          [VECTOR_LINE, 185, 150, 190, 120],
          [VECTOR_LINE, -120, 100, -190, 120],
          [VECTOR_LINE, -185, 150, -190, 120],
        ]
      }
    ] : null
    animations = [
      { prop = AnimProp.opacity, from = 1, to = -1, duration = 0.5, loop = true, easing = InOutSine, trigger = "aim_lock_limit" }
    ]
    behavior = Behaviors.RtPropUpdate
    update = function() {
      local target = [TargetX.get() - width * 0.25, TargetY.get() - height * 0.2]
      let leftBorder = 0
      let rightBorder = width * 0.5
      let topBorder = 0
      let bottomBorder = height * 0.6
      if (target[0] < leftBorder || target[0] > rightBorder || target[1] < topBorder || target[1] > bottomBorder)
        anim_start("aim_lock_limit")
      else
        anim_request_stop("aim_lock_limit")
      target = [clamp(target[0], leftBorder, rightBorder), clamp(target[1], topBorder, bottomBorder)]
      return {
        transform = {
          translate = target
        }
      }
    }
  }
}

let isAAMMode = Computed(@() GuidanceLockState.get() > GuidanceLockResult.RESULT_STANDBY)
function aamReticle(width, height) {
  return @() {
    watch = isAAMMode
    size = ph(2.0)
    animations = [
      { prop = AnimProp.opacity, from = 1, to = -1, duration = 0.5, loop = true, easing = InOutSine, trigger = "aam_seeker_limit" }
    ]
    children = isAAMMode.get() ? [
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = baseColor
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth
        commands = [
          [VECTOR_POLY, -100, 0, 0, -100, 100, 0, 0, 100]
        ]
      }
    ] : null
    behavior = Behaviors.RtPropUpdate
    update = function() {
      let atAamSeekerLimit =
        TrackerX.get() < width * 0.25
        || TrackerX.get() > width * 0.75
        || TrackerY.get() < height * 0.2
        || TrackerY.get() > height * 0.8
      if (atAamSeekerLimit)
        anim_start("aam_seeker_limit")
      else
        anim_request_stop("aam_seeker_limit")
      return {
        transform = {
          translate = TrackerVisible.get() ? [
            clamp(TrackerX.get() - width * 0.25, 0, width * 0.5),
            clamp(TrackerY.get() - height * 0.2, 0, height * 0.6)
          ]
          : [width * 0.5, height * 0.5]
        }
      }
    }
  }
}

function hmd(width, height) {
  return {
    size = [width * 0.5, height * 0.6]
    pos = [width * 0.25, height * 0.2]
    children = [
      altCircle(baseLineWidth * 2.0, 30, baseColor)
      altitude(30, baseColor)
      weapons(30, baseColor)
      mach(30, baseColor)
      speed(30, baseColor)
      aamScale(20, baseColor)
      radarMarks
      canShoot(30, baseColor)
      flightTime(30, baseColor)
      rollPitch
      airSymbol
      ccrpReticle(width, height)
      aamReticle(width, height)
    ]
  }
}

return hmd