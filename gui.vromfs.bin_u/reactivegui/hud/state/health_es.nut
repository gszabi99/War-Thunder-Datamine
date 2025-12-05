from "%rGui/globals/ui_library.nut" import *
import "%sqstd/ecs.nut" as ecs

let { mkFrameIncrementObservable } = require("%rGui/globals/ec_to_watched.nut")
let { watchedTable2TableOfWatched } = require("%sqstd/frp.nut")
let { add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")

let defState = freeze({
  hp = 0.0
  maxHp = 0.0
  scaleHp = 0.0
  isAliveState = false
  isDownedState = false
  showHpUiState = false
  isCalledForHelp = false
  revivingStartTime = 0.0
  revivingEndTime = 0.0
  revivingUserName = ""
  totalDotAmount = 0.0
})

let {healthState, healthStateSetValue} = mkFrameIncrementObservable(defState,"healthState")
let { hp, maxHp, scaleHp, isAliveState, isDownedState, showHpUiState, isCalledForHelp,
  revivingStartTime, revivingEndTime, revivingUserName, totalDotAmount
} = watchedTable2TableOfWatched(healthState)

local currentWatchedEid = ecs.INVALID_ENTITY_ID

ecs.register_es("health_state_ui_es", {
  [["onChange", "onInit"]] = function(eid,comp) {
    currentWatchedEid = eid
    let isDowned = comp.isDowned
    healthStateSetValue({
      hp = comp.hitpoints__hp
      maxHp = !isDowned ? comp.hitpoints__maxHp : -comp.hitpoints__deathHpThreshold
      scaleHp = comp.hitpoints__scaleHp
      isAliveState = comp.isAlive
      isDownedState = isDowned
      showHpUiState = comp.human__showHpUi
      isCalledForHelp = comp.human_context_command__calledForHelp
      revivingStartTime = comp.hitpoints__revivingStartTime
      revivingEndTime = comp.hitpoints__revivingEndTime
      revivingUserName = comp.hitpoints__revivingUserName
      totalDotAmount = comp.hitpoints__totalDotAmount
    })
  }
  onDestroy = function(eid, _comp) {
    if (eid == currentWatchedEid)
      healthStateSetValue(defState)
  }
},
{
  comps_track = [
    ["hitpoints__hp", ecs.TYPE_FLOAT],
    ["hitpoints__maxHp", ecs.TYPE_FLOAT],
    ["hitpoints__scaleHp", ecs.TYPE_FLOAT],
    ["hitpoints__deathHpThreshold", ecs.TYPE_FLOAT, 0.0],
    ["hitpoints__revivingStartTime", ecs.TYPE_FLOAT],
    ["hitpoints__revivingEndTime", ecs.TYPE_FLOAT],
    ["hitpoints__revivingUserName", ecs.TYPE_STRING],
    ["hitpoints__totalDotAmount", ecs.TYPE_FLOAT],
    ["isAlive", ecs.TYPE_BOOL, true],
    ["isDowned", ecs.TYPE_BOOL, false],
    ["human__showHpUi", ecs.TYPE_BOOL, true],
    ["human_context_command__calledForHelp", ecs.TYPE_BOOL, false]
  ]
  comps_rq=[["watchedByPlr", ecs.TYPE_EID]]
})

add_event_listener("BattleEnded", @(_) healthStateSetValue(defState))
add_event_listener("PlayerQuitMission", @(_) healthStateSetValue(defState))


let needDisplayBleedingTip = Watched(false)

ecs.register_es("track_is_need_heal_bleeding_ui_es", {
  [["onChange", "onInit"]] = @(_eid, comp) needDisplayBleedingTip.set(comp.human_medkit__needDisplayBleedingTip)
  onDestroy = @(...) needDisplayBleedingTip.set(false)
},
{
  comps_track = [
    ["human_medkit__needDisplayBleedingTip", ecs.TYPE_BOOL, true],
  ]
  comps_rq=["watchedByPlr"]
})


return {
  isAlive = isAliveState
  isDowned = isDownedState
  showHpUi = showHpUiState
  isCalledForHelp
  hp
  maxHp
  scaleHp
  needDisplayBleedingTip
  revivingStartTime
  revivingEndTime
  revivingUserName
  totalDotAmount
}
