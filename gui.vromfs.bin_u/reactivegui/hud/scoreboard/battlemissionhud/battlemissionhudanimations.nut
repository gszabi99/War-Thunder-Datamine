from "%rGui/globals/ui_library.nut" import *
let { gradTranspDoubleSideX } = require("%rGui/style/gradients.nut")

let REFLECTION_LINE_SIZE          = [hdpx(20), hdpx(40)]
let REFLECTION_LINE_START_OFFSET  = -hdpx(35)
let REFLECTION_LINE_END_OFFSET    = hdpx(50)
let REFLECTION_LINE_ANIM_DELAY    = 0.35
let REFLECTION_LINE_ANIM_DURATION = 0.6
let REFLECTION_LINE_ANIM_EASING   = InOutCubic

let SCORE_TEXT_ANIM_DURATION  = 0.4
let SCORE_TEXT_ANIM_EASING    = InCubic

let CROSS_PARTICLE_LINE_SIZE   = [hdpx(15), hdpx(5)]
let CROSS_PARTICLE_ANIM_EASING = InOutCubic

let mkScoreBlinkAnim = @(trigger) {
  prop     = AnimProp.color
  from     = 0x00ffffff
  easing   = InOutCubic
  duration = 0.25
  trigger
}

let mkScoreTextAnim = @(trigger) [
  {
    prop     = AnimProp.scale,
    from     = [2.5,2.5]
    to       = [1,1]
    duration = SCORE_TEXT_ANIM_DURATION
    easing   = SCORE_TEXT_ANIM_EASING
    trigger
  }
  {
    prop     = AnimProp.opacity
    from     = 0
    to       = 1
    duration = SCORE_TEXT_ANIM_DURATION
    easing   = SCORE_TEXT_ANIM_EASING
    trigger
  }
]

let mkCrossParticleLine = @(color, ovr = {}) {
  size = CROSS_PARTICLE_LINE_SIZE
  rendObj = ROBJ_BOX
  fillColor = color
}.__update(ovr)

function mkCrossParticle(params) {
  let { delay = 0, duration, trigger, scale, startPosX, endPosX, yPos } = params
  let defaultAnimProps = { delay, duration, trigger, easing = CROSS_PARTICLE_ANIM_EASING }

  return {
    opacity = 0
    transform = { scale = [scale, scale] }

    children = [
      mkCrossParticleLine(params.color)
      mkCrossParticleLine(params.color, { transform = { rotate = 90 } })
    ]

    animations = [
      {
        prop = AnimProp.opacity
        from = 1
        to   = 0.5
      }.__update(defaultAnimProps)
      {
        prop = AnimProp.translate
        from = [startPosX, yPos]
        to   = [endPosX, yPos]
      }.__update(defaultAnimProps)
      {
        prop = AnimProp.scale,
        from = [scale, scale]
        to   = [scale * 0.5, scale * 0.5]
      }.__update(defaultAnimProps)
    ]
  }
}

let crossParticlesCloudCfg = [
  { scale = 1,   startPosX = -hdpx(52), endPosX = hdpx(40), yPos = hdpx(4),  duration = 0.7 }
  { scale = 1,   startPosX = -hdpx(70), endPosX = hdpx(25), yPos = hdpx(-3), duration = 0.7, delay = 0.1 }
  { scale = 0.8, startPosX = -hdpx(10), endPosX = hdpx(20), yPos = hdpx(-5), duration = 0.6, delay = 0.25 }
  { scale = 0.6, startPosX = -hdpx(30), endPosX = hdpx(20), yPos = hdpx(5),  duration = 0.6, delay = 0.25 }
  { scale = 1.1, startPosX = -hdpx(50), endPosX = hdpx(10),  yPos = hdpx(-3), duration = 0.5, delay = 0.35 }
  { scale = 1,   startPosX = -hdpx(35), endPosX = hdpx(10),  yPos = hdpx(2),  duration = 0.3, delay = 0.40 }
]

function mkCrossParticlesCloudComp(colorW, trigger, animsXDirectionMultiplier = 1) {
  return @() {
    watch = colorW
    children = crossParticlesCloudCfg.map(@(partCfg) mkCrossParticle(partCfg.__merge({
      color = colorW.get()
      trigger = trigger
      startPosX = partCfg.startPosX * animsXDirectionMultiplier
      endPosX   = partCfg.endPosX *   animsXDirectionMultiplier
    })))
  }
}

function mkReflectionLineAnimComp(trigger, posMult) {
  let defaultAnimProps = {
    delay    = REFLECTION_LINE_ANIM_DELAY
    duration = REFLECTION_LINE_ANIM_DURATION
    easing   = REFLECTION_LINE_ANIM_EASING
    trigger
  }

  return {
    size = REFLECTION_LINE_SIZE
    opacity = 0
    rendObj = ROBJ_IMAGE
    image =  gradTranspDoubleSideX
    transform = { rotate = 35 }
    animations = [
      {
        prop = AnimProp.translate
        from = [REFLECTION_LINE_START_OFFSET * posMult, 0]
        to   = [REFLECTION_LINE_END_OFFSET * posMult, 0]
      }.__update(defaultAnimProps)
      {
        prop = AnimProp.opacity
        from = 1
        to   = 0.7
      }.__update(defaultAnimProps)
    ]
  }
}

return {
  mkCrossParticlesCloudComp
  mkReflectionLineAnimComp
  mkScoreBlinkAnim
  mkScoreTextAnim
}