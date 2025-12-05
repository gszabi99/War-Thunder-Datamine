from "%rGui/globals/ui_library.nut" import *
import "%sqstd/ecs.nut" as ecs

let { HitResult, DamageType } = require("%rGui/hud/humanSquad/humanEnums.nut")
let { get_time_msec } = require("dagor.time")
let { EventAnyEntityDied, CmdShowHitMark } = require("dasevents")
let { watchedHeroEid } = require("%rGui/hud/state/watched_hero.nut")
let { localTeam } = require("%rGui/missionState.nut")

let showWorldKillMark = Watched(false)

let hitMarks = mkWatched(persist, "hits", [])
let killMarks = mkWatched(persist, "killMarks", [])
let hitMarkEid = Watched(ecs.INVALID_ENTITY_ID)

const DM_DIED = "DM_DIED"

function removePreviousHitmarksByVictimEid(state, eid) {
  state.set(state.get().filter((@(mark) mark.victimEid != eid)))
}

function addMark(hitMark, state){
  state.mutate(function(v) {
    return v.append(hitMark)
  })
}

local counter = 0

local cachedShowWorldKillMark = showWorldKillMark.get()
showWorldKillMark.subscribe(@(v) cachedShowWorldKillMark = v)

function addHitMark(hitMark){
  addMark(hitMark, hitMarks)
}

function addKillMark(hitMark){
  let victim = hitMark?.victimEid
  if (hitMark?.killPos == null || victim == null)
    return
  killMarks.set(killMarks.get().filter(@(v) v.victimEid != victim))
  addMark(hitMark, killMarks)
}

let getVictimQuery = ecs.SqQuery("getVictimQuery", {
  comps_ro=[
    ["team", ecs.TYPE_INT],
    ["dm_parts__type", ecs.TYPE_STRING_LIST],
    ["hit_mark__armorEfficiencyThreshold", ecs.TYPE_FLOAT],
    ["hit_mark__armorUnbreakableEfficiencyThreshold", ecs.TYPE_FLOAT],
    ["hit_mark__armorUnbreakableDamageToArmorThreshold", ecs.TYPE_FLOAT]
  ],
  comps_no=["stationary_gun"]
})

let getVictimTeamQuery = ecs.SqQuery("getVictimTeamQuery", {
  comps_ro=[
    ["team", ecs.TYPE_INT]
  ],
  comps_no=["stationary_gun"]
})

let getVictimImmunityTimerQuery = ecs.SqQuery("getVictimImmunityTimerQuery", {
  comps_ro=[
    ["spawn_immunity__timer", ecs.TYPE_FLOAT]
  ]
})

function onHit(victimEid, _offender, extHitPos, damageType, hitRes) {
  counter++
  let time = get_time_msec()

  local hitPos = null
  let isDownedHit = hitRes == HitResult.HIT_RES_DOWNED
  let isKillHit = hitRes == HitResult.HIT_RES_KILLED
  let independentKill = damageType == DM_DIED
  let isMelee = [DamageType.DM_BACKSTAB, DamageType.DM_MELEE].indexof(damageType)!=null
  if (isMelee)
    hitPos = [extHitPos.x, extHitPos.y, extHitPos.z]
  local killPos = null
  if (isKillHit || isDownedHit || independentKill) {
    killPos = ecs.obsolete_dbg_get_comp_val(victimEid, "transform", null)
    killPos = killPos!=null ? killPos.getcol(3) : hitPos
    hitPos = [extHitPos.x, extHitPos.y, extHitPos.z]
    killPos = [killPos.x, killPos.y+0.6, killPos.z]
  }
  local immunityTimer = -1.;
  getVictimImmunityTimerQuery.perform(victimEid, function(_eid, comp) {
    immunityTimer = comp["spawn_immunity__timer"]
  })

  let hitMark = {
    id = counter,
    victimEid,
    time,
    hitPos,
    hitRes,
    killPos = cachedShowWorldKillMark ? killPos : null,
    isKillHit,
    isDownedHit,
    isMelee,
    isImmunityHit = immunityTimer > 0,
  }
  if (!independentKill) {
    removePreviousHitmarksByVictimEid(hitMarks, victimEid)
    addHitMark(hitMark)
  }
  if (cachedShowWorldKillMark && (isKillHit || isDownedHit))
    addKillMark(hitMark)
}

function onHitWithArmor(victimEid, hitRes, isVitalPart, isCritical, isArmorEffective,
    isArmorUnbreakable, isFriendlyFire
  ) {
  counter++
  let time = get_time_msec()
  let hitMark = {
    id=counter,
    victimEid,
    time,
    isImmunityHit = false,
    isVitalPart,
    isCritical,
    isArmorEffective,
    isArmorUnbreakable,
    isFriendlyFire,
    hitRes,
    isDownedHit = hitRes == HitResult.HIT_RES_DOWNED,
    isKillHit = hitRes == HitResult.HIT_RES_KILLED
  }
  addHitMark(hitMark)
}


















function onEntityHit(evt, eid, _comp) {
  let victimEid = evt.victim
  let offender = eid
  local victimTeam = 0
  local isVitalPart = false
  local isCritical = false
  local isFriendlyFire = false
  local armorEfficiencyThreshold = 0.4
  local armorUnbreakableEfficiencyThreshold = 0.9
  local armorUnbreakableDamageToArmorThreshold = 0.1
  getVictimQuery.perform(victimEid, function(_eid, comp) {
    victimTeam = comp.team
    let part = comp.dm_parts__type?[evt.collNodeId]
    isCritical = part == "head"
    isVitalPart = isCritical || part == "torso"
    isFriendlyFire = localTeam.get() == victimTeam
    armorEfficiencyThreshold = comp.hit_mark__armorEfficiencyThreshold
    armorUnbreakableEfficiencyThreshold = comp.hit_mark__armorUnbreakableEfficiencyThreshold
    armorUnbreakableDamageToArmorThreshold = comp.hit_mark__armorUnbreakableDamageToArmorThreshold
  })

  if (offender != watchedHeroEid.get() || victimEid == offender || victimTeam == -2)
    return

  let isArmorEffective = evt.armorEfficiency > armorEfficiencyThreshold
  let isArmorUnbreakable = evt.armorEfficiency > armorUnbreakableEfficiencyThreshold &&
                           evt.damageToArmorPercent < armorUnbreakableDamageToArmorThreshold

  onHitWithArmor(victimEid, evt.hitResult, isVitalPart, isCritical, isArmorEffective,
    isArmorUnbreakable, isFriendlyFire)
}

function onEntityDied(evt, _eid, _comp) {
  let { victim, offender } = evt
  local victimTeam = 0
  getVictimTeamQuery.perform(victim, @(_eid, comp) victimTeam = comp["team"])

  if (offender != watchedHeroEid.get() || victim == offender || victimTeam == 0)
    return
  let tm = ecs.obsolete_dbg_get_comp_val(victim, "transform", null)
  onHit(victim, offender, tm.getcol(3), DM_DIED, HitResult.HIT_RES_KILLED)
}


ecs.register_es("script_hit_marks_with_armor_es", {
    [CmdShowHitMark] = onEntityHit,
  },
  { comps_rq = ["watchedByPlr"] }
)

ecs.register_es("script_hit_marks_es", {
    [EventAnyEntityDied] = onEntityDied,

  }, {}
)

ecs.register_es("script_hit_marks_position_es",
  {
    [["onInit", "onChange"]] = @(_eid, comp)
      hitMarkEid.set(comp["human_net_phys__isAiming"] ? comp["human__hitmarkEid"]
        : ecs.INVALID_ENTITY_ID)
    onDestroy = @(...) hitMarkEid.set(ecs.INVALID_ENTITY_ID)
  },
  {
    comps_track = [
      ["human__hitmarkEid", ecs.TYPE_EID],
      ["human_net_phys__isAiming", ecs.TYPE_BOOL]
    ]
    comps_rq = ["watchedByPlr"]
  }
)

return {
  hitMarks
  killMarks
  showWorldKillMark
  hitMarkEid
}
