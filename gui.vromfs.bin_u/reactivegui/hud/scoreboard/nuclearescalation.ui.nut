from "%rGui/globals/ui_library.nut" import *

let { scoreLimit, localTeam, ticketsTeamA, ticketsTeamB } = require("%rGui/missionState.nut")
let { mkTeamProgress } = require("%rGui/hud/scoreboard/hudElemsPkg.nut")
let { isInFlight } = require("%rGui/globalState.nut")
let { get_current_mission_desc } = require("guiMission")
let DataBlock = require("DataBlock")
let { eventbus_send } = require("eventbus")
let { yieldLimitFromStage } = require("%appGlobals/missions/nuclearEscalationCfg.nut")

const ANIM_TRIGGER_ALLY = "main_anim_ally"
const ANIM_TRIGGER_ENEMY = "main_anim_enemy"

const ESCALATION_FG_COLOR = 0xFFFFD807
const ESCALATION_BG_COLOR = 0xFFF2F2F2
const NUCLEAR_ICON_BORDER_COLOR = 0xFFE2482F
const NUCLEAR_ICON_BORDER_SIZE = hdpx(2)
const NUCLEAR_ICON_SIZE = hdpxi(22)

const NUCLEAR_STAGES_COUNT = 3

let nuclearStagesCache = []

function cacheNuclearStages() {
  if (nuclearStagesCache.len() != 0)
    return

  let misBlk = DataBlock()
  get_current_mission_desc(misBlk)
  for (local idx = 0; idx < NUCLEAR_STAGES_COUNT; idx++)
    nuclearStagesCache.append(misBlk.getInt($"nuclearEscalationStage{idx+1}", 0))
}

isInFlight.subscribe(@(v) !v ? nuclearStagesCache.clear() : null)

let calcStageFill = @(totalScore, stageStart, stageEnd) stageEnd > stageStart
  ? clamp((totalScore - stageStart).tofloat() / (stageEnd - stageStart), 0.0, 1.0)
  : 0.0

let calcTeamScore = @(limit, tickets) tickets > 0 ? max(0, limit - tickets) : 0

let mkNuclearIcon = @(progressFillW) @() {
  watch = progressFillW
  size = NUCLEAR_ICON_SIZE
  rendObj = ROBJ_PROGRESS_CIRCULAR
  fValue = progressFillW.get()
  fgColor = ESCALATION_FG_COLOR
  bgColor = ESCALATION_BG_COLOR
  image = Picture($"ui/gameuiskin#basezone_small_nuclear_escalate.svg:{NUCLEAR_ICON_SIZE}:P")
  
  children = progressFillW.get() == 1.0 ? {
    size = NUCLEAR_ICON_SIZE + NUCLEAR_ICON_BORDER_SIZE
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = NUCLEAR_ICON_BORDER_SIZE
    color = NUCLEAR_ICON_BORDER_COLOR
    fillColor = 0x00000000
    commands = [[VECTOR_ELLIPSE, 50, 50, 50, 50]]
  } : null
}

function getNuclearStageDesc(stage) {
  let isLastStage = stage > NUCLEAR_STAGES_COUNT
  if (isLastStage)
    return ""

  local yieldLimit = yieldLimitFromStage?[stage]
  if (!yieldLimit)  
    return ""

  let isNextLevelStrategic = yieldLimit > 100
  if (stage == NUCLEAR_STAGES_COUNT) 
    yieldLimit = yieldLimitFromStage[stage - 1]

  let val = yieldLimit >= 1000
    ? " ".concat(yieldLimit * 0.001, loc("hud/nuclear_escalation/megaton"))
    : " ".concat(yieldLimit, loc("hud/nuclear_escalation/kiloton"))

  let desc = isNextLevelStrategic
    ? loc("hud/nuclear_escalation/strategic_nuclear", { val })
    : loc("hud/nuclear_escalation/tactical_nuclear", { val })

  return loc("hud/nuclear_escalation/nextLevel", { nextLevel = desc })
}

function getTooltipText(totalScore) {
  if (nuclearStagesCache.len() == 0)
    return ""

  let curStage = nuclearStagesCache.findindex(@(t) totalScore < t) ?? NUCLEAR_STAGES_COUNT
  let nextThreshold = curStage < NUCLEAR_STAGES_COUNT ? nuclearStagesCache[curStage]
    : nuclearStagesCache.top()

  let nextNuclearStageDesc = getNuclearStageDesc(curStage + 1)
  let mainDesc = loc("hud/nuclear_escalation/tooltip",
    { level = curStage, nextThreshold, maxLevel = NUCLEAR_STAGES_COUNT, score = totalScore })

  return "\n".join([mainDesc, nextNuclearStageDesc], true)
}

let iconsKey = {}

function showTooltip(score) {
  let rect = gui_scene.getCompAABBbyKey(iconsKey)
  if (rect == null)
    return
  eventbus_send("scoreboardTooltipUpdate", {
    show = true
    text = getTooltipText(score)
    dargCompAABB = rect
  })
}

return function mkNuclearEscalationHud() {
  cacheNuclearStages()

  let localTeamTicketsW = Computed(@() localTeam.get() == 2
    ? ticketsTeamB.get()
    : ticketsTeamA.get())
  let enemyTeamTicketsW = Computed(@() localTeam.get() == 2
    ? ticketsTeamA.get()
    : ticketsTeamB.get())

  localTeamTicketsW.subscribe(@(score) score > 0 && anim_start(ANIM_TRIGGER_ALLY))
  enemyTeamTicketsW.subscribe(@(score) score > 0 && anim_start(ANIM_TRIGGER_ENEMY))

  let totalScoreW = Computed(@()
    calcTeamScore(scoreLimit.get(), ticketsTeamA.get())
      + calcTeamScore(scoreLimit.get(), ticketsTeamB.get()))
  let stagesProgressW = nuclearStagesCache.map(@(stageEnd, idx)
    Computed(function() {
      let stageStart = idx > 0 ? nuclearStagesCache[idx - 1] : 0
      return calcStageFill(totalScoreW.get(), stageStart, stageEnd)
    }))

  let isHoveredW = Watched(false)

  totalScoreW.subscribe(function updateOpenedTooltipOnScoreChange(score) {
    if (isHoveredW.get())
      eventbus_send("scoreboardTooltipUpdate", {
        show = true
        text = getTooltipText(score)
      })
  })

  let nuclearIconsBlock = {
    key = iconsKey
    flow = FLOW_HORIZONTAL
    behavior = Behaviors.Button
    function onElemState(sf) {
      if ((sf & S_HOVER) != 0) {
        isHoveredW.set(true)
        showTooltip(totalScoreW.get())
      }
      else {
        isHoveredW.set(false)
        eventbus_send("scoreboardTooltipUpdate", { show = false })
      }
    }
    gap = hdpx(4)
    padding = hdpx(4)
    children = stagesProgressW.map(mkNuclearIcon)
    onDetach = @() eventbus_send("scoreboardTooltipUpdate", { show = false })
  }

  return {
    flow = FLOW_VERTICAL
    children = [
      {
        size = FLEX_H
        flow = FLOW_HORIZONTAL
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        children = [
          mkTeamProgress(true, localTeamTicketsW, scoreLimit, ANIM_TRIGGER_ALLY)
          nuclearIconsBlock
          mkTeamProgress(false, enemyTeamTicketsW, scoreLimit, ANIM_TRIGGER_ENEMY)
        ]
      }
    ]
  }
}