from "%rGui/globals/ui_library.nut" import *
let { gradTranspDoubleSideX } = require("%rGui/style/gradients.nut")

let REFLECTION_LINE_SIZE          = [hdpx(20), hdpx(40)]
let REFLECTION_LINE_START_OFFSET  = -hdpx(35)
let REFLECTION_LINE_END_OFFSET    = hdpx(50)
let REFLECTION_LINE_ANIM_DELAY    = 0.25
let REFLECTION_LINE_ANIM_DURATION = 0.5
let REFLECTION_LINE_ANIM_EASING   = InOutCubic

let SCORE_TEXT_ANIM_DURATION  = 0.4
let SCORE_TEXT_ANIM_EASING    = InCubic

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
  mkReflectionLineAnimComp
  mkScoreBlinkAnim
  mkScoreTextAnim
}