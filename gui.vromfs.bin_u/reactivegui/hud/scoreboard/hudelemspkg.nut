import "%rGui/style/teamColors.nut" as teamColors
import "console" as console
from "%rGui/hud/scoreboard/missionModeState.nut" import TOTAL_DOMINATION_START_ANIM_ID, TOTAL_DOMINATION_MULT_ANIM_ID
from "%rGui/missionState.nut" import totalDomTeam, totalDomMult, totalDomEnabled
from "dagor.workcycle" import deferOnce
from "dagor.time" import get_time_msec
from "math" import pow
from "%rGui/hud/scoreboard/capZonePulse.nut" import mkCapZonePulse, mkCapZoneWave
from "%rGui/globals/ui_library.nut" import *

let { ticketHudBlurPanel } = require("%rGui/components/blurPanel.nut")

const neutralColor = 0XFFCCCCCC
const darkColor = 0X98000000

const pointBaseSize = hdpxi(22)
const pointInZoneSize = hdpxi(40)
const superiorityIconSize = hdpxi(10)
let progressLineSize = [hdpxi(200), hdpxi(10)]
const progressGap = hdpxi(5)
let zoneSymbols = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p"]
let totalDomMultIconSize = [hdpxi(16), hdpxi(10)]

const TOTAL_DOM_MULT_FADE_DUR = 0.4
const TOTAL_DOM_MULT_CYCLES = 2

const longAnimsCount = 2
const longAnimDuration = 0.75

const shortAnimsCount = 4
const shortAnimDuration = 0.5

const ZONE_ICON_PATH = "ui/gameuiskin#basezone_small_mark_no_bg"

let mkSuperiorityIcon = @(color) {
  size = const [superiorityIconSize, superiorityIconSize ]
  rendObj = ROBJ_IMAGE
  image = Picture($"ui/gameuiskin#person_icon.svg:{superiorityIconSize}:{superiorityIconSize}:P")
  color
}


let inZoneFrame = {
  size = FLEX
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
  size = FLEX
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


let easeInOutCubic = @(t) t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2

function mkTween() {
  let st = { from = 0.0, to = null, startMs = 0, durMs = 0 }
  function get() {
    if (st.to == null)
      return 0.0
    let t = st.durMs <= 0 ? 1.0 : clamp((get_time_msec() - st.startMs).tofloat() / st.durMs, 0.0, 1.0)
    return st.from + (st.to - st.from) * easeInOutCubic(t)
  }
  function setTarget(to, durSec) {
    if (to == st.to)
      return
    st.from = st.to == null ? to : get()
    st.to = to
    st.startMs = get_time_msec()
    st.durMs = (durSec * 1000).tointeger()
  }
  return { get, setTarget }
}

let lerpRange = @(range, t) range == null ? 1.0 : range[0] + (range[1] - range[0]) * t
let getScaledSize = @(t, pointSize, scaleRange) (pointSize * lerpRange(scaleRange, t) + 0.5).tointeger()

function mkTeamCapPointImpl(captureZoneW, localTeamW, zoneStateW, activeTween) {
  let captureZoneVal = captureZoneW.get()
  if (captureZoneVal == null)
    return { watch = captureZoneW }

  let zoneState = zoneStateW?.get()
  let { id, progress, watchedHeroInZone, mpTimeX100 = 0 } = captureZoneVal
  let { teamScoreBlueColor, teamScoreRedColor } = teamColors.get()
  let pointSize = zoneState?.size ?? (watchedHeroInZone ? pointInZoneSize : pointBaseSize)

  let { isActive = false, scaleRange = null, opacityRange = null, activeAnimSec = 0 } = zoneState ?? {}
  let hasActiveAnim = scaleRange != null || opacityRange != null
  if (hasActiveAnim)
    activeTween.setTarget(isActive ? 1.0 : 0.0, activeAnimSec)
  let scaleMax = scaleRange == null ? 1.0 : max(scaleRange[0], scaleRange[1])
  function updateActiveProps() {
    let t = activeTween.get()
    return { size = getScaledSize(t, pointSize, scaleRange), opacity = lerpRange(opacityRange, t) }
  }
  let activeProps = updateActiveProps()
  
  let rasterSize = (pointSize * max(scaleMax, 1.0) + 0.5).tointeger()
  
  let slotH = ((zoneState?.size ?? max(pointInZoneSize, pointBaseSize)) * max(scaleMax, 1.0) + 0.5).tointeger()

  let curTeam = mpTimeX100 == 0 ? 0
    : mpTimeX100 > 0 ? 2
    : 1
  let teamColor = curTeam == 0 ? neutralColor
    : curTeam == localTeamW.get() ? teamScoreBlueColor
    : teamScoreRedColor

  let pulseColor = zoneState?.pulseColor
  let waveColor = zoneState?.waveColor

  local capzoneIcon = zoneState?.iconPath
  if (capzoneIcon == null) {
    let zSymbol = zoneSymbols?[id] ?? zoneSymbols[zoneSymbols.len() - 1]
    capzoneIcon = $"{ZONE_ICON_PATH}_{zSymbol}"
  }

  return {
    watch = [captureZoneW, teamColors, localTeamW, zoneStateW]
    flow = FLOW_VERTICAL
    size = [ SIZE_TO_CONTENT, slotH ]
    children = [
      {
        size = [ SIZE_TO_CONTENT, slotH ]
        valign = ALIGN_CENTER
        children = {
          size = activeProps.size
          opacity = activeProps.opacity
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          behavior = hasActiveAnim ? Behaviors.RtPropUpdate : null
          rtRecalcLayout = true
          update = updateActiveProps
          children = [
            pulseColor == null ? null : mkCapZonePulse(id, rasterSize, pulseColor)
            waveColor == null ? null
              : mkCapZoneWave(id, getScaledSize(isActive ? 1.0 : 0.0, pointSize, scaleRange), waveColor)
            {
              size = FLEX
              rendObj = ROBJ_PROGRESS_CIRCULAR
              fValue = zoneState?.fValue ?? (progress / 100.0)
              fgColor = zoneState?.fgColor ?? teamColor
              bgColor = zoneState?.bgColor ?? neutralColor
              image = Picture($"ui/gameuiskin#basezone_small_rhombus.svg:{rasterSize}:{rasterSize}:P")
              keepAspect = true
              transform = {}
              animations = capPointSizeAnimFlash
            }
            watchedHeroInZone ? inZoneFrame : null
            {
              size = FLEX
              rendObj = ROBJ_IMAGE
              image = Picture($"{capzoneIcon}.svg:{rasterSize}:{rasterSize}:P")
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

function mkTeamCapPoint(captureZoneW, localTeamW, zoneStateW = null) {
  let activeTween = mkTween()
  return @() mkTeamCapPointImpl(captureZoneW, localTeamW, zoneStateW, activeTween)
}

function mkMultArrowSlotTrigger(cycle, slot) {
  return $"{TOTAL_DOMINATION_MULT_ANIM_ID}_{cycle}_{slot}"
}

let arrCountFromMult = @(mult) mult < 1 ? 0
  : mult < 2 ? 1
  : mult < 4 ? 2
  : mult < 10 ? 3
  : 4

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
      transform = isAlly ? const { rotate = 180 } : true
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
    size = [pw(progress), FLEX]
    rendObj = ROBJ_SOLID
    color = teamColor
    hplace = isAlly ? ALIGN_RIGHT : ALIGN_LEFT
    clipChildren = true
    transform = {}
    animations = [ mkScoreBlinkAnim(reflectionAnimTrigger) ]
    children = {
      size = [progressLineSize[0], FLEX]
      children = isAlly ? allyProgressDecor : enemyProgressDecor
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
            children = mkTeamProgressLine(isAlly, teamColorW.get(), progress.get(), reflectionAnimTrigger)
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
  totalDomMult.set(clamp(mult, 1, 10))
}, "debug.total_dom.show_arrows")

return freeze({
  mkTeamCapPoint
  mkTeamProgress
})
