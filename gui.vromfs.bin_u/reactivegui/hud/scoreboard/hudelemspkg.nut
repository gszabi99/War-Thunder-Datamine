from "%rGui/globals/ui_library.nut" import *
import "console" as console

let teamColors = require("%rGui/style/teamColors.nut")
let { ticketHudBlurPanel } = require("%rGui/components/blurPanel.nut")
let { TOTAL_DOMINATION_START_ANIM_ID, TOTAL_DOMINATION_MULT_ANIM_ID
} = require("%rGui/hud/scoreboard/missionModeState.nut")
let { totalDomTeam, totalDomMult, totalDomEnabled } = require("%rGui/missionState.nut")
let { deferOnce } = require("dagor.workcycle")

let neutralColor = 0XFFCCCCCC
let darkColor = 0X98000000

let cpBasicSize = hdpxi(22)
let cpInZoneSize = hdpxi(40)
let superiorityIconSize = hdpxi(10)
let progressLineSize = [hdpxi(200), hdpxi(10)]
let progressGap = hdpxi(5)
let zoneSymbols = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p"]
let totalDomMultIconSize = [hdpxi(16), hdpxi(10)]

let TOTAL_DOM_MULT_FADE_DUR = 0.4
let TOTAL_DOM_MULT_CYCLES = 2

let longAnimsCount = 2
let longAnimDuration = 0.75

let shortAnimsCount = 4
let shortAnimDuration = 0.5


let mkSuperiorityIcon = @(color) {
  size = [superiorityIconSize, superiorityIconSize ]
  rendObj = ROBJ_IMAGE
  image = Picture($"ui/gameuiskin#person_icon.svg:{superiorityIconSize}:{superiorityIconSize}:P")
  color
}


let inZoneFrame = {
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
  commands = [
    [VECTOR_POLY,  5,  5, 20,  5,  5, 20],
    [VECTOR_POLY, 95,  5, 80,  5, 95, 20],
    [VECTOR_POLY,  5, 95, 20, 95,  5, 80],
    [VECTOR_POLY, 95, 95, 80, 95, 95, 80],
  ]
  lineWidth = hdpx(1)
  color = neutralColor
  fillColor = neutralColor
}

let mkProgressDecor = @(isAlly) {
  size = flex()
  rendObj = ROBJ_IMAGE
  image = Picture($"ui/gameuiskin#progres_line_decor.svg:{progressLineSize[0]}:{progressLineSize[1]}:P")
  color = darkColor
  opacity = 0.2
  flipY = !isAlly
}

let mkScoreBlinkAnim = @(trigger) {
  prop     = AnimProp.color
  from     = 0x00ffffff
  easing   = OutQuad
  duration = 2
  trigger
}

let allyProgressDecor = mkProgressDecor(true)
let enemyProgressDecor = mkProgressDecor(false)

let SUPERIORITY_STATE = {
  NO_ALLY_IN_ZONE     = 0x0000
  SOME_ALLY_IN_ZONE   = 0x0001
  PARITY_IN_ZONE      = 0x0002
  MOST_ALLY_IN_ZONE   = 0x0004
  ONLY_ALLY_IN_ZONE   = 0x0008
}

let SUPERIORITY_COLOR_BY_PLACE_AVAILABILITY = [
  @(curStateFlag) curStateFlag & (SUPERIORITY_STATE.ONLY_ALLY_IN_ZONE
                                | SUPERIORITY_STATE.MOST_ALLY_IN_ZONE
                                | SUPERIORITY_STATE.PARITY_IN_ZONE
                                | SUPERIORITY_STATE.SOME_ALLY_IN_ZONE),
  @(curStateFlag) curStateFlag & (SUPERIORITY_STATE.ONLY_ALLY_IN_ZONE
                                | SUPERIORITY_STATE.MOST_ALLY_IN_ZONE
                                | SUPERIORITY_STATE.PARITY_IN_ZONE),
  @(curStateFlag) curStateFlag & (SUPERIORITY_STATE.ONLY_ALLY_IN_ZONE
                                | SUPERIORITY_STATE.MOST_ALLY_IN_ZONE),
  @(curStateFlag) curStateFlag & (SUPERIORITY_STATE.ONLY_ALLY_IN_ZONE)
]

function mkCapZoneSuperiority(captureZoneVal, localTeamVal, teamColorsVal) {
  let { teamScoreBlueColor, teamScoreRedColor } = teamColorsVal
  let { numCapturersTeamA = 0, numCapturersTeamB = 0 } = captureZoneVal
  local myTeamCapturers = numCapturersTeamA
  local enemyTeamCapturers = numCapturersTeamB
  if (localTeamVal == 2) {
    myTeamCapturers = numCapturersTeamB
    enemyTeamCapturers = numCapturersTeamA
  }

  let zoneSuperiorityFlag = enemyTeamCapturers == 0 ? SUPERIORITY_STATE.ONLY_ALLY_IN_ZONE
    : myTeamCapturers == 0 ? SUPERIORITY_STATE.NO_ALLY_IN_ZONE
    : myTeamCapturers > enemyTeamCapturers ? SUPERIORITY_STATE.MOST_ALLY_IN_ZONE
    : enemyTeamCapturers > myTeamCapturers ? SUPERIORITY_STATE.SOME_ALLY_IN_ZONE
    : SUPERIORITY_STATE.PARITY_IN_ZONE

  return {
    flow = FLOW_HORIZONTAL
    hplace = ALIGN_CENTER
    children = [null,null,null,null].map(@(_, idx)
      mkSuperiorityIcon(SUPERIORITY_COLOR_BY_PLACE_AVAILABILITY[idx](zoneSuperiorityFlag)
        ? teamScoreBlueColor
        : teamScoreRedColor
    ))
  }
}


let mkLongSizeAnim = @(step) {
  prop = AnimProp.scale, from = [1.0, 1.0], to = [1.2, 1.2], duration = longAnimDuration,
  delay = step*longAnimDuration,
  play = false, easing = CosineFull, trigger = TOTAL_DOMINATION_START_ANIM_ID
}
let mkShortSizeAnim = @(step) {
  prop = AnimProp.scale, from = [1.0, 1.0], to = [1.2, 1.2], duration = shortAnimDuration,
  delay = longAnimsCount * longAnimDuration + step * shortAnimDuration,
  play = false, easing = CosineFull, trigger = TOTAL_DOMINATION_START_ANIM_ID
}


let capPointSizeAnimFlash = []
for (local i = 0; i < longAnimsCount; i++)
  capPointSizeAnimFlash.append(mkLongSizeAnim(i))
for (local i = 0; i < shortAnimsCount; i++)
  capPointSizeAnimFlash.append(mkShortSizeAnim(i))


let mkTeamCapPoint = @(captureZoneW, localTeamW) function() {
  let captureZoneVal = captureZoneW.get()
  if (captureZoneVal == null)
    return { watch = captureZoneW }

  let { id, progress, watchedHeroInZone, mpTimeX100 = 0 } = captureZoneVal
  let { teamScoreBlueColor, teamScoreRedColor } = teamColors.get()
  let cpSize = watchedHeroInZone ? cpInZoneSize : cpBasicSize

  let curTeam = mpTimeX100 == 0 ? 0
    : mpTimeX100 > 0 ? 2
    : 1
  let teamColor = curTeam == 0 ? neutralColor
    : curTeam == localTeamW.get() ? teamScoreBlueColor
    : teamScoreRedColor

  return {
    watch = [captureZoneW, teamColors, localTeamW]
    flow = FLOW_VERTICAL
    size = [ SIZE_TO_CONTENT, cpInZoneSize ]
    children = [
      {
        size = [ SIZE_TO_CONTENT, cpInZoneSize ]
        valign = ALIGN_CENTER
        children = {
          size = [cpSize, cpSize]
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          children = [
            {
              size = flex()
              rendObj = ROBJ_PROGRESS_CIRCULAR
              fValue = progress / 100.0
              fgColor = teamColor
              bgColor = neutralColor
              image = Picture($"ui/gameuiskin#basezone_small_rhombus.svg:{cpSize}:{cpSize}:P")
              keepAspect = true
              transform = {}
              animations = capPointSizeAnimFlash
            }
            watchedHeroInZone ? inZoneFrame : null
            {
              size = flex()
              rendObj = ROBJ_IMAGE
              image = Picture($"ui/gameuiskin#basezone_small_mark_no_bg_{zoneSymbols[id]}.svg:{cpInZoneSize}:{cpInZoneSize}:P")
              color = darkColor
            }
          ]
        }
      }
      watchedHeroInZone
        ? mkCapZoneSuperiority(captureZoneVal, localTeamW.get(), teamColors.get())
        : null
    ]
  }
}

function mkMultArrowSlotTrigger(cycle, slot) {
  return $"{TOTAL_DOMINATION_MULT_ANIM_ID}_{cycle}_{slot}"
}

let arrCountFromMult = @(mult) mult < 2 ? 0 : clamp((mult + 1) / 2, 2, 4)

let totalDomMultArrCount = keepref(Computed(@() arrCountFromMult(totalDomMult.get())))

local lastAnimatedArrCount = 0
local multAnimDone = false
let tryStartMultRelay = function() {
  let arrCount = totalDomMultArrCount.get()
  if (arrCount == 0 || arrCount == lastAnimatedArrCount || multAnimDone)
    return
  lastAnimatedArrCount = arrCount
  deferOnce(@() anim_start(mkMultArrowSlotTrigger(0, 0)))
}


let arrowOpacityCache = {}
function getArrowOpacities(arrCount) {
  if (arrCount not in arrowOpacityCache)
    arrowOpacityCache[arrCount] <- array(arrCount).map(@(_) Watched(1.0))
  return arrowOpacityCache[arrCount]
}


function restoreMultArrowsVisible() {
  lastAnimatedArrCount = 0
  foreach (opacities in arrowOpacityCache)
    foreach (o in opacities)
      o.set(1.0)
}

totalDomMultArrCount.subscribe(function(_) {
  multAnimDone = false
  restoreMultArrowsVisible()
})

totalDomTeam.subscribe(function(_) {
  multAnimDone = false
  restoreMultArrowsVisible()
})

let mkTotalDominationScoreMultiplayers = @(isAlly, teamColor) function() {
  if (totalDomTeam.get() == 0
    || (totalDomTeam.get() == 1 && isAlly)
    || (totalDomTeam.get() == 2 && !isAlly)
    || totalDomMultArrCount.get() == 0)
    return { watch = [ totalDomTeam, totalDomMultArrCount ] }

  let arrCount = totalDomMultArrCount.get()
  let lastSlot = 2 * arrCount - 2

  let mkAdvance = function(cycle, slot) {
    if (slot < lastSlot)
      return @() anim_start(mkMultArrowSlotTrigger(cycle, slot + 1))
    if (cycle < TOTAL_DOM_MULT_CYCLES - 1)
      return @() anim_start(mkMultArrowSlotTrigger(cycle + 1, 0))
    return @() multAnimDone = true
  }

  let arrowOpacities = getArrowOpacities(arrCount)
  let multArrows = []
  for (local i = 0; i < arrCount; i++) {
    let easingIdx = isAlly ? (arrCount - 1 - i) : i
    let outSlot = arrCount - 1 - easingIdx
    let inSlot = 2 * (arrCount - 1) - easingIdx
    let isStartArrow = outSlot == 0
    let arrowOpacity = arrowOpacities[i]
    let animations = []
    for (local cycle = 0; cycle < TOTAL_DOM_MULT_CYCLES; cycle++) {
      animations.append({
        prop = AnimProp.opacity, from = 1, to = 0, duration = TOTAL_DOM_MULT_FADE_DUR,
        play = false, trigger = mkMultArrowSlotTrigger(cycle, outSlot),
        onEnter = @() arrowOpacity.set(0.0),
        onFinish = mkAdvance(cycle, outSlot)
      })
      animations.append({
        prop = AnimProp.opacity, from = 0, to = 1, duration = TOTAL_DOM_MULT_FADE_DUR,
        play = false, trigger = mkMultArrowSlotTrigger(cycle, inSlot),
        onEnter = @() arrowOpacity.set(1.0),
        onFinish = mkAdvance(cycle, inSlot)
      })
    }
    multArrows.append({
      key = $"tdm_arrow_{arrCount}_{i}"
      size = totalDomMultIconSize
      rendObj = ROBJ_IMAGE
      image = Picture($"ui/gameuiskin#arrow_progress.svg:{totalDomMultIconSize[0]}:{totalDomMultIconSize[1]}:K")
      keepAspect = true
      color = teamColor
      opacity = arrowOpacity.get()
      bindProps = { opacity = arrowOpacity }
      transform = isAlly ? { rotate = 180 } : {}
      animations
      onAttach = isStartArrow ? tryStartMultRelay : null
    })
  }
  return {
    watch = [ totalDomTeam, totalDomMultArrCount ]
    flow = FLOW_HORIZONTAL
    gap = totalDomMultIconSize[0]/-3
    children = multArrows
    onDetach = restoreMultArrowsVisible
  }
}

function mkTeamProgressLine(isAlly, teamColor, progress, reflectionAnimTrigger) {
  return {
    size = [pw(progress), flex()]
    rendObj = ROBJ_SOLID
    color = teamColor
    hplace = isAlly ? ALIGN_RIGHT : ALIGN_LEFT
    clipChildren = true
    transform = {}
    animations = [ mkScoreBlinkAnim(reflectionAnimTrigger) ]
    children = {
      size = [progressLineSize[0], flex()]
      children = [
        isAlly ? allyProgressDecor : enemyProgressDecor
      ]
     }
  }
}


function mkTeamProgress(isAlly, ticketsW, maxTicketsW, reflectionAnimTrigger) {
  let teamColorW = Computed(@() isAlly
    ? teamColors.get().teamScoreBlueColor
    : teamColors.get().teamScoreRedColor)
  let progress = Computed(@() maxTicketsW.get() > 0
    ? 100.0 * ticketsW.get() / maxTicketsW.get()
    : 0)

  return {
    size = progressLineSize
    flow = FLOW_VERTICAL
    gap = progressGap
    children = [
      {
        size = progressLineSize
        halign = isAlly ? ALIGN_RIGHT : ALIGN_LEFT
        children = [
          ticketHudBlurPanel
          @() {
            watch = [progress, teamColorW]
            size = progressLineSize
            children = [
              mkTeamProgressLine(isAlly, teamColorW.get(), progress.get(), reflectionAnimTrigger)
            ]
          }
        ]
      }
      @() totalDomEnabled.get() ? {
        watch = [ totalDomEnabled, teamColorW ]
        hplace = isAlly ? ALIGN_RIGHT : ALIGN_LEFT
        children = mkTotalDominationScoreMultiplayers(isAlly, teamColorW.get())
      } : { watch = totalDomEnabled }
    ]
  }
}

local totalDomSaved = null
console.register_command(function(mult = 7, team = 2, enable = 1) {
  if (enable == 0) {
    if (totalDomSaved != null) {
      totalDomEnabled.set(totalDomSaved.enabled)
      totalDomTeam.set(totalDomSaved.team)
      totalDomMult.set(totalDomSaved.mult)
      totalDomSaved = null
    }
    return
  }
  if (totalDomSaved == null)
    totalDomSaved = {
      enabled = totalDomEnabled.get()
      team = totalDomTeam.get()
      mult = totalDomMult.get()
    }
  totalDomEnabled.set(true)
  totalDomTeam.set(clamp(team, 1, 2))
  totalDomMult.set(clamp(mult, 2, 7))
}, "debug.total_dom.show_arrows")

return {
  mkTeamCapPoint
  mkTeamProgress
}
