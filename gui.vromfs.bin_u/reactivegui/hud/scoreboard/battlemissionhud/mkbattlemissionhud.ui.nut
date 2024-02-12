from "%rGui/globals/ui_library.nut" import *
let { getEnemyTeamColorW, getAllyTeamColorW, getEnemyCapZoneIdxW, getAllyCapZoneIdxW, getTimeLeftStrW,
  getCountKillsToWinW, getAllyTeamScoreW, getEnemyTeamScoreW, getCapZoneStateW, getCapZoneColorW } = require("battleMissionHudState.nut")
let { mkCrossParticlesCloudComp, mkReflectionLineAnimComp,
  mkScoreBlinkAnim, mkScoreTextAnim } = require("battleMissionHudAnimations.nut")
let { setTimeout } = require("dagor.workcycle")
let { register_command } = require("console")
let { startPollingZonesState, stopPollingZonesState } = require("%rGui/hud/capZones/capZonesState.nut")

const NEUTRAL_BG_COLOR = 0x58000000
const FONT_COLOR = 0xFFFFFFFF

const HUD_SCORE_UPDATE_DELAY_SEC = 0.5

const MAIN_ANIM_TRIGGER_ALLY = "main_anim_ally"
const BLINK_ANIM_TRIGGER_ALLY = "blink_anim_ally"
const MAIN_ANIM_TRIGGER_ENEMY = "main_anim_enemy"
const BLINK_ANIM_TRIGGER_ENEMY = "blink_anim_enemy"

let TIMER_WIDTH     = hdpxi(60)
let TIMER_HEIGHT    = hdpxi(18)
let TIMER_FONT_SIZE = hdpx(16)
let TIMER_FONT      = Fonts.small_text_hud

let KILLS_TO_WIN_WIDTH     = hdpxi(48)
let KILLS_TO_WIN_HEIGHT    = hdpxi(30)
let KILLS_TO_WIN_FONT      = Fonts.big_text_hud
let KILLS_TO_WIN_FONT_SIZE = hdpx(18)

let TEAM_SCORE_INDICATOR_WIDTH  = hdpxi(40)
let TEAM_SCORE_INDICATOR_HEIGHT = hdpxi(22)
let TEAM_SCORE_FONT_SIZE        = hdpx(24)
let TEAM_SCORE_FONT             = Fonts.big_text_hud

let CAPTURE_POINT_SIZE   = hdpxi(23)
let CAPTURE_POINT_OFFSET = hdpxi(37)

let fontFx = {
  fontFxFactor = hdpx(24)
  fontFxColor = 0xFF000000
  fontFx = FFT_SHADOW
}

function mkTeamScoreBg(params) {
  let { colorW, mainAnimTrigger, blinkAnimTrigger, bgRotate = 0, animDirectionMult = 1} = params
  return {
    size = flex()
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    clipChildren = true
    children = [
      @() {
        watch = colorW
        size = [TEAM_SCORE_INDICATOR_WIDTH, TEAM_SCORE_INDICATOR_HEIGHT]
        rendObj = ROBJ_IMAGE
        image = Picture($"ui/gameuiskin#team_score_bg.svg:{TEAM_SCORE_INDICATOR_WIDTH}:{TEAM_SCORE_INDICATOR_HEIGHT}")
        color = colorW.get()
        transform = { rotate = bgRotate }
        animations = [
          mkScoreBlinkAnim(blinkAnimTrigger)
          mkScoreBlinkAnim(mainAnimTrigger)
        ]
      }
      mkReflectionLineAnimComp(mainAnimTrigger, animDirectionMult)
    ]
  }
}

function mkTeamScoreComp(params) {
  let { hudScoreW, mainAnimTrigger, ovr = {} } = params

  return {
    size = [TEAM_SCORE_INDICATOR_WIDTH, TEAM_SCORE_INDICATOR_HEIGHT]
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    children = [
      mkTeamScoreBg(params)
      @() {
        watch = hudScoreW
        rendObj = ROBJ_TEXT
        font = TEAM_SCORE_FONT
        fontSize = TEAM_SCORE_FONT_SIZE
        color = FONT_COLOR
        text = hudScoreW.get()
        transform = {pivot = [0.5,0.5]}
        animations = mkScoreTextAnim(mainAnimTrigger)
      }.__update(fontFx)
    ]
  }.__update(ovr)
}

let getZoneIcon = @(i)
  Picture($"ui/gameuiskin#basezone_small_mark_no_bg_{('a' + i).tochar()}.svg:{CAPTURE_POINT_SIZE}:{CAPTURE_POINT_SIZE}")

function mkTeamCapPoint(idxW, allyColorW, enemyColorW, ovr = {}) {
  let zoneStateW = getCapZoneStateW(idxW)
  let zoneColorW = getCapZoneColorW(zoneStateW, allyColorW, enemyColorW)

  return {
    children = [
      @() {
        watch = [zoneStateW, zoneColorW]
        size = [CAPTURE_POINT_SIZE, CAPTURE_POINT_SIZE]
        rendObj = ROBJ_PROGRESS_CIRCULAR
        fValue = 0.01 * (zoneStateW.get()?.mpTimeX100 ?? 0)
        fgColor = zoneColorW.get()
        bgColor = NEUTRAL_BG_COLOR
        image =  Picture($"ui/gameuiskin#basezone_small_rhombus.svg:{CAPTURE_POINT_SIZE}:{CAPTURE_POINT_SIZE}")
        keepAspect = true
      }
      @() {
        watch =idxW
        size = [CAPTURE_POINT_SIZE, CAPTURE_POINT_SIZE]
        rendObj = ROBJ_IMAGE
        image = getZoneIcon(idxW.get())
        keepAspect = true
      }
    ]
  }.__update(ovr)
}

function mkTimerComp() {
  let timeLeftW = getTimeLeftStrW()
  return {
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
      {
        size = [TIMER_WIDTH, TIMER_HEIGHT]
        rendObj = ROBJ_IMAGE
        image = Picture($"ui/gameuiskin#timer_bg.svg:{TIMER_WIDTH}:{TIMER_HEIGHT}:P")
        keepAspect = true
        color = NEUTRAL_BG_COLOR
      }
      @() {
        watch = timeLeftW
        rendObj = ROBJ_TEXT
        font = TIMER_FONT
        fontSize = TIMER_FONT_SIZE
        color = FONT_COLOR
        text = timeLeftW.get()
      }.__update(fontFx)
    ]
  }
}

function mkKillsToWinCountComp() {
  let killsToWinW = getCountKillsToWinW()
  return {
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
      {
        size = [KILLS_TO_WIN_WIDTH, KILLS_TO_WIN_HEIGHT]
        rendObj = ROBJ_IMAGE
        image = Picture($"ui/gameuiskin#total_score_bg.svg:{KILLS_TO_WIN_WIDTH}:{KILLS_TO_WIN_HEIGHT}:P")
        keepAspect = true
        color = NEUTRAL_BG_COLOR
      }
      @() {
        watch = killsToWinW
        rendObj = ROBJ_TEXT
        font = KILLS_TO_WIN_FONT
        fontSize = KILLS_TO_WIN_FONT_SIZE
        color = FONT_COLOR
        text = killsToWinW.get()
      }.__update(fontFx)
    ]
  }
}

function handleTeamScoreChanges(score, hudScoreW, firstBlinkAnimTrigger, mainAnimTrigger) {
  if (score == 0)
    return hudScoreW.set(0)

  anim_start(firstBlinkAnimTrigger)
  setTimeout(HUD_SCORE_UPDATE_DELAY_SEC, function() {
    hudScoreW.set(score)
    anim_start(mainAnimTrigger)
  })
}

register_command(@() anim_start(MAIN_ANIM_TRIGGER_ALLY), "ui.debug.battle_hud.play_anim_a")
register_command(@() anim_start(MAIN_ANIM_TRIGGER_ENEMY), "ui.debug.battle_hud.play_anim_b")

return function mkBattleHud() {
  let allyTeamScoreW = getAllyTeamScoreW()
  let enemyTeamScoreW = getEnemyTeamScoreW()

  let allyColorW = getAllyTeamColorW()
  let enemyColorW = getEnemyTeamColorW()

  let allyZoneIdxW = getAllyCapZoneIdxW()
  let enemyZoneIdxW = getEnemyCapZoneIdxW()

  let allyTeamScoreHUD = Watched(allyTeamScoreW.get())
  let enemyTeamScoreHUD = Watched(enemyTeamScoreW.get())

  allyTeamScoreW.subscribe(@(score)
    handleTeamScoreChanges(score, allyTeamScoreHUD, BLINK_ANIM_TRIGGER_ALLY, MAIN_ANIM_TRIGGER_ALLY))
  enemyTeamScoreW.subscribe(@(score)
    handleTeamScoreChanges(score, enemyTeamScoreHUD, BLINK_ANIM_TRIGGER_ENEMY, MAIN_ANIM_TRIGGER_ENEMY))

  return {
    key = {}
    flow = FLOW_VERTICAL
    gap = hdpx(4)
    halign = ALIGN_CENTER

    children = [
      {
        flow = FLOW_HORIZONTAL
        valign = ALIGN_CENTER
        children = [
          mkCrossParticlesCloudComp(allyColorW, MAIN_ANIM_TRIGGER_ALLY)
          mkTeamScoreComp({
            colorW = allyColorW
            hudScoreW = allyTeamScoreHUD
            bgRotate = 180
            blinkAnimTrigger = BLINK_ANIM_TRIGGER_ALLY
            mainAnimTrigger = MAIN_ANIM_TRIGGER_ALLY,
            ovr = { transform = { translate = [hdpx(1), 0] } }
          })
          mkKillsToWinCountComp()
          mkTeamScoreComp({
            colorW = enemyColorW
            hudScoreW = enemyTeamScoreHUD
            blinkAnimTrigger = BLINK_ANIM_TRIGGER_ENEMY
            mainAnimTrigger = MAIN_ANIM_TRIGGER_ENEMY
            animDirectionMult = -1
            ovr = { transform = { translate = [hdpx(-1), 0] } }
          })
          mkCrossParticlesCloudComp(enemyColorW, MAIN_ANIM_TRIGGER_ENEMY, -1)
        ]
      }
      {
        halign = ALIGN_CENTER
        valign= ALIGN_CENTER
        children = [
          mkTeamCapPoint(allyZoneIdxW, allyColorW, enemyColorW, { pos = [-CAPTURE_POINT_OFFSET, 0] })
          mkTimerComp()
          mkTeamCapPoint(enemyZoneIdxW, allyColorW, enemyColorW, { pos = [CAPTURE_POINT_OFFSET, 0] })
        ]
      }
    ]

    onAttach = startPollingZonesState
    onDetach = stopPollingZonesState
    wRefs = [allyTeamScoreW, enemyTeamScoreW]
  }
}
