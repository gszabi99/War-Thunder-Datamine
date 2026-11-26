import "DataBlock" as DataBlock
import "%rGui/style/teamColors.nut" as teamColors
from "math" import fabs
from "guiMission" import CZ_IS_DISABLED, ECT_SUPREMACY_CAPTURE_MIDPOINT, MISSION_CAPTURED_ZONE, get_current_mission_desc
from "eventbus" import eventbus_subscribe
from "%globalScripts/mpTeamConsts.nut" import MP_TEAM_NEUTRAL, MP_TEAM_A, MP_TEAM_B
from "%rGui/missionState.nut" import localTeam, roundTimeLeft
from "%rGui/hud/scoreboard/hudElemsPkg.nut" import mkTeamCapPoint
from "%rGui/hud/scoreboard/missionModeState.nut" import zoneTimeBonus
from "%rGui/hud/capZones/capZonesState.nut" import capZones, captureZoneStateIcons
from "%rGui/respawnWndState.nut" import isInRespawnWnd
from "%rGui/globalState.nut" import isInFlight
from "dagor.time" import get_time_msec
from "%rGui/hud/scoreboard/capZonePulse.nut" import startCapZoneWave
from "%sqstd/time.nut" import secondsToTimeSimpleString
from "%rGui/globals/ui_library.nut" import *

let { playSoundByPath = @(_) null } = require_optional("sound_wt")

const FULL_PROGRESS = 100.0
const ICON_LOCKED = "ui/gameuiskin#capturezone_small_locked_no_bg"
const ICON_DEFEND = "ui/gameuiskin#capturezone_small_defend_no_bg"
const ICON_ATTACK = "ui/gameuiskin#capturezone_small_attack_no_bg"

const ZONE_TIMER_BODY_ICON = "ui/gameuiskin#capture_zone_timer_body.svg"
const ZONE_TIMER_TIP_ICON = "ui/gameuiskin#capture_zone_timer_tip.svg"

const ZONE_TIMER_HEIGHT = hdpxi(20)
const ZONE_TIMER_BODY_RASTER_WIDTH = hdpxi(46)
const ZONE_TIMER_TIP_WIDTH = hdpxi(12)
const ZONE_TIMER_TIP_OVERLAP = hdpxi(6)
const ZONE_TIMER_TEXT_PAD = hdpx(8)

const pointBaseSize = hdpxi(32)
const CP_ACTIVE_SCALE = 1.5
const CP_BASE_SCALE = 1.0
const CP_ACTIVE_OPACITY = 1.0
const CP_BASE_OPACITY = 0.5
const CP_ACTIVE_ANIM_SEC = 0.5
let CP_OPACITY_RANGE = freeze([CP_BASE_OPACITY, CP_ACTIVE_OPACITY])
let CP_SCALE_RANGE = freeze([CP_BASE_SCALE, CP_ACTIVE_SCALE])
const CP_PULSE_SEC = 10.0
const START_HINT_SEC = 5.0
const ZONE_CHANGE_HINT_SEC = 3.0
const ZONE_HINT_COLOR = 0xFFFFFFFF
const ZONE_TIME_COLOR = 0xFFFFFFFF
const ZONE_TIME_BONUS_COLOR = 0xCA0ACA0A
const ZONE_TIME_BONUS_ANIMS = [
  { prop = AnimProp.opacity, from = 0, to = 1, duration = 0.3, easing = InCubic, play = true }
  { prop = AnimProp.opacity, from = 1, to = 0, duration = 0.3, easing = InCubic, playFadeOut = true }
]
const HINT_TIMER_ID = "capZonesHint"

let getOtherTeam = @(team) team == MP_TEAM_A ? MP_TEAM_B
  : team == MP_TEAM_B ? MP_TEAM_A
  : MP_TEAM_NEUTRAL

let isFriendTeam = @(team, localTeamVal) team != MP_TEAM_NEUTRAL && team == localTeamVal
let isZoneEnabled = @(zone) (zone.flags & CZ_IS_DISABLED) == 0
let isMidpointZone = @(zone) zone.captureType == ECT_SUPREMACY_CAPTURE_MIDPOINT

function isZoneCapturing(zone) {
  let { conqTeam, mpTimeX100 } = zone
  return isZoneEnabled(zone) && conqTeam != MP_TEAM_NEUTRAL && fabs(mpTimeX100) < FULL_PROGRESS
}

function getZoneDefender(zone) {
  let { team, conqTeam, progress } = zone
  if (team != MP_TEAM_NEUTRAL)
    return team
  local leadTeam = conqTeam
  if (leadTeam == MP_TEAM_NEUTRAL && progress != 0)
    leadTeam = progress < 0 ? MP_TEAM_A : MP_TEAM_B
  return getOtherTeam(leadTeam)
}

function getCaptureFill(zone, progressToAttacker, attacker) {
  let { team } = zone
  if (!isMidpointZone(zone) || team == MP_TEAM_NEUTRAL)
    return (progressToAttacker + FULL_PROGRESS) / (FULL_PROGRESS * 2)
  return team == attacker
    ? progressToAttacker / FULL_PROGRESS
    : 1.0 + progressToAttacker / FULL_PROGRESS
}

function readFirstSideTeam() {
  let misBlk = DataBlock()
  get_current_mission_desc(misBlk)
  return misBlk.getBool("remapTeams", false) ? MP_TEAM_B : MP_TEAM_A
}

let hint = Watched(null)
local hintQueue = []
local hintSec = 0.0

function showNextHint() {
  if (hintQueue.len() == 0) {
    hint.set(null)
    return
  }
  hint.set(hintQueue.remove(0))
  gui_scene.resetTimeout(hintSec, showNextHint, HINT_TIMER_ID)
}

function showHints(locIds, sec) {
  if (isInRespawnWnd.get())
    return
  hintQueue = locIds
  hintSec = sec
  showNextHint()
}

function appendHints(locIds, sec) {
  if (isInRespawnWnd.get())
    return
  if (hint.get() == null) {
    showHints(locIds, sec)
    return
  }
  hintQueue.extend(locIds)
  hintSec = sec
}

function resetHints() {
  gui_scene.clearTimer(HINT_TIMER_ID)
  hintQueue = []
  hintSec = 0.0
  hint.set(null)
}

function showStartHintFor(attacker, localTeamVal, sec) {
  if (isFriendTeam(attacker, localTeamVal))
    appendHints(["hud/capZones/start_hint_attack"], sec)
  else if (isFriendTeam(getOtherTeam(attacker), localTeamVal))
    appendHints(["hud/capZones/start_hint_defend"], sec)
}

let missionFirstSideTeam = Computed(@() isInFlight.get() ? readFirstSideTeam() : null)

let anchor = Computed(function(prev) {
  if (!isInFlight.get())
    return null
  let zones = capZones.get()
  let zone = zones.findvalue(isZoneEnabled)
  if (zone != null)
    return { id = zone.id, owner = zone.team, defender = getZoneDefender(zone), mpTimeX100 = zone.mpTimeX100 }
  if (prev == FRP_INITIAL || prev == null)
    return null

  let prevZone = zones.findvalue(@(z) z.id == prev.id)
  let team = prevZone?.team ?? MP_TEAM_NEUTRAL
  let mpTimeX100 = prevZone?.mpTimeX100 ?? FULL_PROGRESS
  return (team == MP_TEAM_NEUTRAL || team == prev.owner) ? prev
    : { id = prev.id, owner = team, defender = team, mpTimeX100 }
})

let anchorStage = Computed(function(prev) {
  let anchorVal = anchor.get()
  if (anchorVal == null)
    return null
  let firstSideTeam = missionFirstSideTeam.get()
  if (prev != FRP_INITIAL && prev != null && prev.id == anchorVal.id) {
    if (prev.isCounterattack)
      return prev
    let zones = capZones.get()
    let isLastZone = zones.len() > 0 && zones.top().id == anchorVal.id
    let isTakenByFirstSide = anchorVal.owner == firstSideTeam
    if (!isTakenByFirstSide || !isLastZone)
      return prev
  }
  let isCounterattack = anchorVal.defender == firstSideTeam
  return { id = anchorVal.id, isCounterattack }
})

let stageAttacker = Computed(@() anchorStage.get()?.isCounterattack
  ? getOtherTeam(missionFirstSideTeam.get()) : missionFirstSideTeam.get())

function getZoneIconState(zone, anchorVal, firstSideTeam, attacker, localTeamVal, friendColor, enemyColor) {
  let { id, team, progress } = zone
  let isEnabled = isZoneEnabled(zone)
  let isCapturing = isZoneCapturing(zone)
  let isStageDefenderSide = isCapturing || team == MP_TEAM_NEUTRAL
  let sideTeam = isEnabled ? (isStageDefenderSide ? getOtherTeam(attacker) : team)
    : anchorVal == null ? MP_TEAM_NEUTRAL
    : id == anchorVal.id ? anchorVal.defender
    : id < anchorVal.id ? firstSideTeam
    : getOtherTeam(firstSideTeam)
  let isFriendSide = isFriendTeam(sideTeam, localTeamVal)
  let progressToAttacker = attacker == MP_TEAM_A ? -progress : progress
  let isActive = id == anchorVal?.id
  let bgColor = isFriendSide ? friendColor : enemyColor
  return {
    zoneId = id
    owner = team
    isEnabled
    isActive
    isCapturing
    iconPath = !isEnabled ? ICON_LOCKED
      : isFriendSide ? ICON_DEFEND
      : ICON_ATTACK
    fValue = isCapturing ? clamp(getCaptureFill(zone, progressToAttacker, attacker), 0.0, 1.0) : 0.0
    fgColor = isFriendTeam(attacker, localTeamVal) ? friendColor : enemyColor
    bgColor
    size = pointBaseSize
    scaleRange = CP_SCALE_RANGE
    opacityRange = CP_OPACITY_RANGE
    activeAnimSec = CP_ACTIVE_ANIM_SEC
  }
}

let hasZoneTime = Computed(@() roundTimeLeft.get() > 0)

local isAttachPulsePending = true
let stagePulse = Watched(null) 
let stopStagePulse = @() stagePulse.set(null)

local isStartHintShown = false
local hasHintStage = false

isInRespawnWnd.subscribe(function(isInWnd) {
  if (isInWnd) {
    resetHints()
    return
  }
  isAttachPulsePending = true
  if (isStartHintShown || !captureZoneStateIcons.get())
    return
  isStartHintShown = true
  showStartHintFor(stageAttacker.get(), localTeam.get(), START_HINT_SEC)
})

isInFlight.subscribe(function(isFlying) {
  if (isFlying)
    return
  isStartHintShown = false
  resetHints()
  hasHintStage = false
  isAttachPulsePending = true
  stagePulse.set(null)
})

let ZONE_HINT_ANIMS = freeze([
  { prop = AnimProp.opacity, from = 0, to = 1, duration = 0.3, easing = InCubic, play = true }
  { prop = AnimProp.opacity, from = 1, to = 0, duration = 0.3, easing = OutCubic, playFadeOut = true }
])

let mkZoneHint = @(hintW) @() {
  watch = hintW
  size = 0
  hplace = ALIGN_CENTER
  vplace = ALIGN_BOTTOM
  halign = ALIGN_CENTER
  children = hintW.get() == null ? null : {
    key = hintW.get()
    margin = const [hdpx(6), 0, 0, 0]
    rendObj = ROBJ_TEXT
    font = Fonts.small_text_hud
    fontFx = FFT_SHADOW
    fontFxColor = 0xFF000000
    color = ZONE_HINT_COLOR
    text = loc(hintW.get())
    animations = ZONE_HINT_ANIMS
  }
}

let zoneTimeTextStyle = freeze({
  fontSize = hdpx(14)
  monoWidth = "0"
})


let zoneTimeTextMinWidth = calc_str_box("00:00", zoneTimeTextStyle)[0] + 1

let zoneTimeText = @() zoneTimeTextStyle.__merge({
  watch = roundTimeLeft
  rendObj = ROBJ_TEXT
  minWidth = zoneTimeTextMinWidth
  halign = ALIGN_CENTER
  margin = hdpx(2)
  color = ZONE_TIME_COLOR
  text = secondsToTimeSimpleString(roundTimeLeft.get())
})


let zoneTimeBonusText = @() {
  watch = zoneTimeBonus
  size = 0
  hplace = ALIGN_CENTER
  vplace = ALIGN_BOTTOM
  halign = ALIGN_CENTER
  children = zoneTimeBonus.get() <= 0 ? null : {
    rendObj = ROBJ_TEXT
    font = Fonts.tiny_text_hud
    color = ZONE_TIME_BONUS_COLOR
    text = $"+{secondsToTimeSimpleString(zoneTimeBonus.get())}"
    animations = ZONE_TIME_BONUS_ANIMS
  }
}

let zoneTimeTextWithPad = freeze({
  padding = [0, ZONE_TIMER_TEXT_PAD]
  children = zoneTimeText
})

let zoneTimerBodyPic = Picture($"{ZONE_TIMER_BODY_ICON}:{ZONE_TIMER_BODY_RASTER_WIDTH}:{ZONE_TIMER_HEIGHT}:P")
let zoneTimerTipPic = Picture($"{ZONE_TIMER_TIP_ICON}:{ZONE_TIMER_TIP_WIDTH}:{ZONE_TIMER_HEIGHT}:P")
let flipHorizontal = freeze({ rotate = 180 })

let ZONE_TIMER_BODY_SLICE = freeze([0, (ZONE_TIMER_HEIGHT * 8.8 / 20.5 + 0.5).tointeger(), 0, 1])

let mkZoneTimerTip = @(color, isLeft) {
  size = const [ZONE_TIMER_TIP_WIDTH, ZONE_TIMER_HEIGHT]
  rendObj = ROBJ_IMAGE
  image = zoneTimerTipPic
  color
  transform = isLeft ? flipHorizontal : null
}

let mkZoneTimerBody = @(color, isLeft) {
  size = const [SIZE_TO_CONTENT, ZONE_TIMER_HEIGHT]
  valign = ALIGN_CENTER
  children = [
    {
      size = flex()
      rendObj = ROBJ_9RECT
      image = zoneTimerBodyPic
      texOffs = ZONE_TIMER_BODY_SLICE
      screenOffs = ZONE_TIMER_BODY_SLICE
      color
      transform = isLeft ? flipHorizontal : null
    }
    zoneTimeTextWithPad
    zoneTimeBonusText
  ]
}

let mkZoneTimeBlock = @(bgColorW, timerPlaceW) function() {
  let color = bgColorW.get()
  let isLeft = timerPlaceW.get()?.isLeft ?? false
  let body = mkZoneTimerBody(color, isLeft)
  let tip = mkZoneTimerTip(color, isLeft)
  return {
    watch = [bgColorW, timerPlaceW]
    margin = const [0, hdpx(6)]
    flow = FLOW_HORIZONTAL
    gap = -ZONE_TIMER_TIP_OVERLAP
    valign = ALIGN_CENTER
    children = isLeft ? [tip, body] : [body, tip]
  }
}

local capZonesStateIconsCount = 0

eventbus_subscribe("zoneCapturingEvent", function(data) {
  if (!captureZoneStateIcons.get())
    return
  let { eventId = -1, zoneIdx = -1, isMyTeam = false } = data
  if (eventId != MISSION_CAPTURED_ZONE || zoneIdx < 0)
    return
  
  startCapZoneWave(zoneIdx)
  if (isMyTeam)
    playSoundByPath("infantry/ui/counterattack/captured")
  else
    playSoundByPath("infantry/ui/counterattack/defence_failed")
  showHints(isMyTeam ? ["hud/capZones/point_captured"] : ["hud/capZones/point_lost"],
    ZONE_CHANGE_HINT_SEC)
})

function startZoneWaves(edges) {
  foreach (zoneId in edges.waveZoneIds)
    startCapZoneWave(zoneId)
}

function updateStageHints(stage) {
  let hadStage = hasHintStage
  hasHintStage = stage != null
  if (!hadStage || stage == null || !captureZoneStateIcons.get())
    return
  let attacker = stageAttacker.get()
  let localTeamVal = localTeam.get()
  if (stage.isCounterattack) {
    showStartHintFor(attacker, localTeamVal, ZONE_CHANGE_HINT_SEC)
    return
  }

  if (isFriendTeam(attacker, localTeamVal))
    appendHints(["hud/capZones/capture_next_point"], ZONE_CHANGE_HINT_SEC)
  else
    appendHints(["hud/capZones/retreat_to_next_point"], ZONE_CHANGE_HINT_SEC)
}
anchorStage.subscribe(updateStageHints)

function onZoneTimeChanged(hasTime) {
  if (hasTime || !captureZoneStateIcons.get())
    return
  let mpTimeX100 = anchor.get()?.mpTimeX100 ?? FULL_PROGRESS
  if (isFriendTeam(stageAttacker.get(), localTeam.get()) && fabs(mpTimeX100) < FULL_PROGRESS)
    playSoundByPath("infantry/ui/counterattack/not_captured")
}
hasZoneTime.subscribe(onZoneTimeChanged)

function onStageChanged(stage) {
  if (stage == null || !captureZoneStateIcons.get())
    return
  let attacker = stageAttacker.get()
  let localTeamVal = localTeam.get()
  if (isFriendTeam(attacker, localTeamVal))
    playSoundByPath("infantry/ui/counterattack/capture_start")
  else if (isFriendTeam(getOtherTeam(attacker), localTeamVal))
    playSoundByPath("infantry/ui/counterattack/defence_point")
}
anchorStage.subscribe(onStageChanged)

function mkCaptureZonesStateIcons() {
  capZonesStateIconsCount++
  let instanceId = capZonesStateIconsCount
  let pulseTimerId = $"capZonesStagePulse_{instanceId}"
  let zonesCount = Computed(@() capZones.get().len())

  let timerPlace = Computed(function() {
    let anchorId = anchor.get()?.id
    if (anchorId == null)
      return null
    let zones = capZones.get()
    let zoneIdx = zones.findindex(@(z) z.id == anchorId)
    return zoneIdx == null ? { idx = zones.len(), isLeft = true }
      : anchorStage.get()?.isCounterattack ? { idx = zoneIdx + 1, isLeft = true }
      : { idx = zoneIdx, isLeft = false }
  })

  function updateStagePulse(stage) {
    if (stage == null) {
      gui_scene.clearTimer(pulseTimerId)
      stopStagePulse()
      return
    }
    stagePulse.set({ zoneId = stage.id, endMsec = get_time_msec() + (CP_PULSE_SEC * 1000).tointeger() })
    gui_scene.resetTimeout(CP_PULSE_SEC, stopStagePulse, pulseTimerId)
  }
  function resumeStagePulse() {
    let pulse = stagePulse.get()
    if (pulse == null)
      return
    let leftSec = (pulse.endMsec - get_time_msec()) / 1000.0
    if (pulse.zoneId != anchorStage.get()?.id || leftSec <= 0) {
      stopStagePulse()
      return
    }
    gui_scene.resetTimeout(leftSec, stopStagePulse, pulseTimerId)
  }

  let zoneTimeBgColor = Computed(function() {
    let { teamScoreBlueColor, teamScoreRedColor } = teamColors.get()
    return isFriendTeam(stageAttacker.get(), localTeam.get()) ? teamScoreBlueColor : teamScoreRedColor
  })
  let zoneTimeBlock = mkZoneTimeBlock(zoneTimeBgColor, timerPlace)
  let zonePoints = {}
  function getZonePoint(idx) {
    if (idx not in zonePoints) {
      let zoneW = Computed(@() capZones.get()?[idx])
      let zoneStateW = Computed(function() {
        let zone = zoneW.get()
        if (zone == null)
          return null

        let { teamScoreBlueColor, teamScoreRedColor } = teamColors.get()
        let state = getZoneIconState(zone, anchor.get(), missionFirstSideTeam.get(), stageAttacker.get(), localTeam.get(),
          teamScoreBlueColor, teamScoreRedColor)
        state.pulseColor <- (state.zoneId == stagePulse.get()?.zoneId && state.isActive && state.isEnabled
          && !state.isCapturing) ? state.bgColor : null
        state.waveColor <- state.owner != MP_TEAM_NEUTRAL
            ? (isFriendTeam(state.owner, localTeam.get()) ? teamScoreBlueColor : teamScoreRedColor)
          : state.bgColor
        return state
      })

      zonePoints[idx] <- mkTeamCapPoint(zoneW, localTeam, zoneStateW)
    }
    return zonePoints[idx]
  }

  let zoneWaveEdges = Computed(function(prev) {
    let anchorId = anchor.get()?.id
    let hasTime = hasZoneTime.get()
    let prevEdges = prev == FRP_INITIAL ? null : prev
    let waveZoneIds = []
    local isAnchorEnabled = false
    let isTimeOut = (prevEdges?.hasZoneTime ?? false) && !hasTime
    foreach (zone in capZones.get()) {
      let { id } = zone
      if (id == anchorId)
        isAnchorEnabled = isZoneEnabled(zone)
      if (isTimeOut && id == prevEdges?.anchorId && (prevEdges?.isAnchorEnabled ?? false))
        waveZoneIds.append(id)
    }
    return { anchorId, isAnchorEnabled, hasZoneTime = hasTime, waveZoneIds }
  })

  let zonesRow = function() {
    let children = capZones.get().map(@(_cz, idx) getZonePoint(idx))
    let timerIdx = timerPlace.get()?.idx
    if (hasZoneTime.get() && timerIdx != null)
      children.insert(timerIdx, zoneTimeBlock)
    return {
      watch = [zonesCount, timerPlace, hasZoneTime]
      flow = FLOW_HORIZONTAL
      gap = hdpx(2)
      valign = ALIGN_CENTER
      children
    }
  }
  return {
    children = [zonesRow, mkZoneHint(hint)]
    onAttach = function() {
      if (isAttachPulsePending) {
        isAttachPulsePending = false
        updateStagePulse(anchorStage.get())
      }
      else
        resumeStagePulse()
      anchorStage.subscribe(updateStagePulse)
      zoneWaveEdges.get()
      zoneWaveEdges.subscribe(startZoneWaves)
    }
    onDetach = function() {
      anchorStage.unsubscribe(updateStagePulse)
      zoneWaveEdges.unsubscribe(startZoneWaves)
      gui_scene.clearTimer(pulseTimerId)
    }
  }
}

return freeze({
  mkCaptureZonesStateIcons
})