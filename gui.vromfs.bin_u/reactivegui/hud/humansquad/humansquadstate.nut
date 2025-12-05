import "%sqstd/ecs.nut" as ecs
from "%rGui/globals/ui_library.nut" import *

let { isEqual } = require("%sqstd/underscore.nut")
let { HitResult, HEAL_RES_COMMON, HEAL_RES_REVIVE, ATTACK_RES, AiActionEnum
} = require("%rGui/hud/humanSquad/humanEnums.nut")
let { watchedHeroSquadMembers, watchedHeroSquadMembersRaw, watchedHeroSquadEid,
  localPlayerHumanContext, selectedBotForOrderEid
} = require("%appGlobals/hudSquadMembers.nut")
let { getGrenadeType } = require("%rGui/hud/humanSquad/grenadeIcon.nut")


let MINES_ORDER = {
  tnt_exploder = 0
  antitank_mine = 1
  antipersonnel_mine = 2
}

let mkDefState = @() {
  watchedHeroSquadEid = ecs.INVALID_ENTITY_ID,
  controlledSquadEid = ecs.INVALID_ENTITY_ID,
  members = {}
}


let hitTriggers = {}

function getHitTrigger(id) {
  local trigger = hitTriggers?[id]
  if (trigger)
    return trigger

  trigger = {
    [HitResult.HIT_RES_NORMAL] = {}, [HitResult.HIT_RES_DOWNED] = {}, [HitResult.HIT_RES_KILLED] = {},
    [HEAL_RES_COMMON] = {}, [HEAL_RES_REVIVE] = {}, [ATTACK_RES] = {}
  }
  hitTriggers[id] <- trigger
  return trigger
}

function localizeSoldierName(soldier) {
  let { name = "", surname = "" } = soldier
  return {
    name = name == "" ? "" : loc(name)
    surname = surname == "" ? "" : loc(surname)
  }
}

let hasGrenadeType = @(grenades, grenade_type)
  grenades.findvalue(@(v) v == grenade_type) != null

let getMineType = @(mines)
  mines.reduce(@(a, b)
    (MINES_ORDER?[a] ?? 0) <= (MINES_ORDER?[b] ?? 0) ? a : b)

function getState(data) {
  let { name, surname } = localizeSoldierName({name = data.name, surname = data.surname})
  return {
    isDowned = data.isDowned
    memberIdx = data.memberIdx
    currentAiAction = data.currentAiAction
    eid = data.eid
    guid = data.guid
    name = data.callname != "" ? data.callname : $"{loc(name)} {loc(surname)}"
    isAlive = data.isAlive
    hp = data.hp.tofloat()
    maxHp = data.maxHp.tofloat()
    gunEidsList = data?.gunEidsList ?? []
    weapTemplates = data.weapTemplates
    hasAI = data.hasAI
    kills = data.kills
    targetHealCount = data.targetHealCount
    hasFlask = data.hasFlask
    targetReviveCount = data.targetReviveCount
    sKind = data.sKind
    sClassRare = data.sClassRare
    canBeLeader = data.canBeLeader
    isPersonalOrder = data.isPersonalOrder
    isActionOrder = data.isActionOrder
    hitTriggers = getHitTrigger(data.eid)
    grenadeType = getGrenadeType(data?.grenadeTypes ?? [])
    hasFragGrenade = hasGrenadeType(data?.grenadeTypes ?? [], "fougasse")
    hasSmokeGrenade = hasGrenadeType(data?.grenadeTypes ?? [], "smoke")
    hasFlashGrenade = hasGrenadeType(data?.grenadeTypes ?? [], "flash")
    mineType = getMineType(data?.mineTypes ?? [])
  }
}

function getContextState(data) {
  return {
    hasGroundVehicleAttackerAndTarget = data?.hasGroundVehicleAttackerAndTarget ?? false
    hasAirVehicleAttackerAndTarget = data?.hasAirVehicleAttackerAndTarget ?? false
  }
}

function startMemberAnimations(curState, oldState) {
  let {isAlive, isDowned, hp, currentAiAction} = curState
  if (oldState==null)
    return
  if (oldState.isAlive && !isAlive)
    anim_start(curState.hitTriggers[HitResult.HIT_RES_KILLED])
  else if (!oldState.isDowned && isDowned)
    anim_start(curState.hitTriggers[HitResult.HIT_RES_DOWNED])
  else if (oldState.hp > hp)
    anim_start(curState.hitTriggers[HitResult.HIT_RES_NORMAL])
  else if (oldState.hp < hp)
    anim_start(curState.hitTriggers[HEAL_RES_COMMON])
  else if (oldState.isDowned && !isDowned)
    anim_start(curState.hitTriggers[HEAL_RES_REVIVE])

  if (currentAiAction == AiActionEnum.AI_ACTION_ATTACK &&
      currentAiAction != oldState.currentAiAction)
    anim_start(curState.hitTriggers[ATTACK_RES])
}

ecs.register_es("track_squad_members_state_ui",
  {
    [["onChange", "onInit"]] = function trackSquad(_, comp) {
      if (!comp.is_local)
        return
      let watchedSquadEid = comp["squad_members_ui__watchedSquadEid"]
      let prevWatchedHeroSquadEid = watchedHeroSquadEid.get()
      if (prevWatchedHeroSquadEid != watchedSquadEid) {
        watchedHeroSquadMembersRaw.set(mkDefState())
      }
      let controlled = comp["squad_members_ui__controlledSquadEid"]
      let squadMembers = comp["squad_members_ui__watchedSquadState"].getAll()
      watchedHeroSquadMembersRaw.mutate(function(state) {
        let newVal = mkDefState()
        state.watchedHeroSquadEid = watchedSquadEid
        newVal.controlledSquadEid = controlled
        foreach (k, v in squadMembers) {
          let eid = k.tointeger()
          let oldState = state.members?[eid]
          let updatedState = getState(v)
          startMemberAnimations(updatedState, oldState)
          state.members[eid] <- updatedState
        }
        return state
      })
    },
  },
  { comps_track = [
      ["is_local", ecs.TYPE_BOOL],
      ["squad_members_ui__watchedSquadState", ecs.TYPE_OBJECT],
      ["squad_members_ui__watchedSquadEid", ecs.TYPE_EID],
      ["squad_members_ui__controlledSquadEid", ecs.TYPE_EID],
  ] },
  {tags = "gameClient"}
)

ecs.register_es("track_local_human_context_ui",
  {
    [["onChange", "onInit"]] = function trackContext(_, comp) {
      let ctxState = comp["local_player_human_context__ctxState"].getAll()
      localPlayerHumanContext.set(getContextState(ctxState))
    },
  },
  { comps_track = [
      ["local_player_human_context__ctxState", ecs.TYPE_OBJECT]
  ] },
  {tags = "gameClient"}
)


let watchedHeroSquadMembersGetWatched = @(eid) Computed(@() watchedHeroSquadMembersRaw.get().members?[eid])

let watchedHeroSquadMembersOrderedSet = Computed(function(old){
  let newres = watchedHeroSquadMembers.get().map(@(v) v.eid)
  if (!isEqual(newres, old))
    return newres
  return old
})


let isPersonalContextCommandMode = Watched(false)

function trackComponentsPersonalBotOrder(_evt, _eid, comp) {
  if (comp["controlledHero"] != null) {
    isPersonalContextCommandMode.set(comp["squad_member__isPersonalContextCommandMode"])
    selectedBotForOrderEid.set(comp["personal_bot_order__currentBotEid"])
  }
}

ecs.register_es("hero_personal_bot_order_ui_es",
  {
    onChange = trackComponentsPersonalBotOrder
    onInit = trackComponentsPersonalBotOrder
    onDestroy = function(_evt, _eid, _comp) {
      isPersonalContextCommandMode.set(false)
      selectedBotForOrderEid.set(ecs.INVALID_ENTITY_ID)
    }
  },
  {
    comps_track = [
      ["personal_bot_order__currentBotEid", ecs.TYPE_EID],
      ["squad_member__isPersonalContextCommandMode", ecs.TYPE_BOOL],
      ["controlledHero", ecs.TYPE_TAG, null]
    ]
  }
)

return {
  isPersonalContextCommandMode
  watchedHeroSquadMembersGetWatched
  watchedHeroSquadMembersOrderedSet
}