import "%sqstd/ecs.nut" as ecs
from "%scripts/dagui_library.nut" import *

let { controlledHeroEid } = require("%appGlobals/controlledHeroEid.nut")
let { currentGunEid } = require("%appGlobals/currentGunEid.nut")
let { eventbus_send } = require("eventbus")
let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let { watchedHeroSquadMembersAliveCount } = require("%appGlobals/hudSquadMembers.nut")

let canSwitchFireMods = Watched(false)
let switchFireModOn = Watched("")
let canSwithchOnUnbarrelLauncher = Watched(false)
let unbarrelSwitchStatus = Watched(false)
let hasLaserMod = Watched(false)
let laserModActive = Watched(false)
let hasFlashlightMod = Watched(false)
let flashlightModActive = Watched(false)
let nextSoldierSpawnTime = Watched(-1.0)
let needShowWeaponMenu = Computed(@() canSwitchFireMods.get() || canSwithchOnUnbarrelLauncher.get() || hasLaserMod.get() || hasFlashlightMod.get())

let NO_FIRE_MODS = "no_fire_mods"

let currentGunQuery = ecs.SqQuery("currentGunQuery", {
  comps_ro=[["gun__firingModeIndex", ecs.TYPE_INT, -1],
            ["gun__firingModeNames", ecs.TYPE_ARRAY, []]]
})

let unbarrelModQuery = ecs.SqQuery("unbarrelModQuery", {
  comps_ro=[["weapon_mod__active", ecs.TYPE_BOOL]]
})

let gunOwnerQuery = ecs.SqQuery("gunOwnerQuery", {
  comps_ro = [["gun__owner", ecs.TYPE_EID]]
})

let laserModQuery = ecs.SqQuery("laserModQuery", {
  comps_ro=[["laserActive", ecs.TYPE_BOOL]]
})

let flashlightModQuery = ecs.SqQuery("flashlightModQuery", {
  comps_ro=[["flashlight__on", ecs.TYPE_BOOL]]
})

let currentHeroQuery = ecs.SqQuery("currentHeroQuery", {
  comps_ro=[["human_weap__currentGunModEids", ecs.TYPE_EID_LIST]]
})

function getModOwnerEid(animchar_attach__attachedTo){
  return gunOwnerQuery(animchar_attach__attachedTo, function(_, comp) {
    return comp.gun__owner
  })
}

function updateFireMode(fireMods, curFireModInd) {
  let currentFiringMode = curFireModInd >= 0 ? fireMods[curFireModInd] : NO_FIRE_MODS
  let nextFireMod = curFireModInd >= 0 ? fireMods[(curFireModInd + 1) % fireMods.len()] : NO_FIRE_MODS
  switchFireModOn.set(nextFireMod)
  canSwitchFireMods.set(currentFiringMode != nextFireMod && currentFiringMode != NO_FIRE_MODS)
  eventbus_send("onFireModChanged")
}

currentGunEid.subscribe(@(v) currentGunQuery(v, function(_, comp) {
  updateFireMode(comp.gun__firingModeNames?.getAll() ?? [], comp.gun__firingModeIndex)
}))

ecs.register_es("current_gun_eid_init_es", {
  [["onInit", "onChange"]] = function(_eid, comp){
    currentGunEid.set(comp.human_weap__currentGunEid)
  },
  [["onDestroy"]] = function(_, _) {
    currentGunEid.set(ecs.INVALID_ENTITY_ID)
  }
}, {comps_track=[["human_weap__currentGunEid", ecs.TYPE_EID]], comps_rq=["controlledHero"]})

ecs.register_es("on_fire_mode_changed_es", {
  [["onInit", "onChange"]] = function(eid, comp){
    if (eid == currentGunEid.get()) {
      updateFireMode(comp.gun__firingModeNames?.getAll() ?? [], comp.gun__firingModeIndex)
    }
  }
}, {comps_track=[["gun__firingModeIndex", ecs.TYPE_INT]], comps_ro=[["gun__firingModeNames", ecs.TYPE_ARRAY]]})

function updateUnbarrel(canSwitch, isActive) {
  canSwithchOnUnbarrelLauncher.set(canSwitch)
  unbarrelSwitchStatus.set(isActive)
  eventbus_send("onUnbarrelModChanged")
}

function updateLaser(hasLaser, laserActive) {
  hasLaserMod.set(hasLaser)
  laserModActive.set(laserActive)
  eventbus_send("onLaserModChanged")
}

function updateFlashlight(hasFlashlight, flashlightActive) {
  hasFlashlightMod.set(hasFlashlight)
  flashlightModActive.set(flashlightActive)
  eventbus_send("onFlashlightModChanged")
}

function onHeroUpdated(human_weap__currentGunModEids) {
  local unbarrelModFound = false
  local laserModFound = false
  local flashlightModFound = false
  foreach (mod in human_weap__currentGunModEids) {
    if (!unbarrelModFound)
      unbarrelModQuery(mod, function(_, comp) {
        updateUnbarrel(true, comp.weapon_mod__active)
        unbarrelModFound = true
      })
    if (!laserModFound)
      laserModQuery(mod, function(_, comp) {
        updateLaser(true, comp.laserActive)
        laserModFound = true
      })
    if (!flashlightModFound)
      flashlightModQuery(mod, function(_, comp) {
        updateFlashlight(true, comp.flashlight__on)
        flashlightModFound = true
      })
  }
  if (!unbarrelModFound)
    updateUnbarrel(false, false)
  if (!laserModFound)
    updateLaser(false, false)
  if (!flashlightModFound)
    updateFlashlight(false, false)
}

controlledHeroEid.subscribe(@(v) currentHeroQuery(v, function(_, comp) {
  onHeroUpdated(comp.human_weap__currentGunModEids)
}))

ecs.register_es("on_weapon_mode_changed_es", {
  [["onInit", "onChange"]] = function(_eid, comp){
    if (comp.gun__owner == controlledHeroEid.get())
      updateUnbarrel(true, comp.weapon_mod__active)
  },
  [["onDestroy"]] = function(_, _) {
    updateUnbarrel(false, false)
  }
},
{
  comps_track=[["weapon_mod__active", ecs.TYPE_BOOL], ["gun__owner", ecs.TYPE_EID]],
  comps_rq=["watchedPlayerItem"]
})

ecs.register_es("on_laser_mode_changed_es", {
  [["onInit", "onChange"]] = function(_eid, comp){
    if (getModOwnerEid(comp.animchar_attach__attachedTo) == controlledHeroEid.get()
        && currentGunEid.get() == comp.animchar_attach__attachedTo)
      updateLaser(true, comp.laserActive)
  },
  [["onDestroy"]] = function(_, _) {
    updateLaser(false, false)
  }
},
{
  comps_track=[["laserActive", ecs.TYPE_BOOL], ["animchar_attach__attachedTo", ecs.TYPE_EID]],
  comps_rq=["watchedPlayerItem"]
})

ecs.register_es("on_flashlight_mode_changed_es", {
  [["onInit", "onChange"]] = function(_eid, comp){
    if (getModOwnerEid(comp.animchar_attach__attachedTo) == controlledHeroEid.get()
        && currentGunEid.get() == comp.animchar_attach__attachedTo)
      updateFlashlight(true, comp.flashlight__on)
  },
  [["onDestroy"]] = function(_, _) {
    updateFlashlight(false, false)
  }
},
{
  comps_track=[["flashlight__on", ecs.TYPE_BOOL], ["animchar_attach__attachedTo", ecs.TYPE_EID]],
  comps_rq=["watchedPlayerItem"]
})

ecs.register_es("current_mod_eid_init_es", {
  [["onInit", "onChange"]] = function(_eid, comp){
    onHeroUpdated(comp.human_weap__currentGunModEids)
  },
  [["onDestroy"]] = function(_, _) {
    onHeroUpdated([])
  }
},
{
  comps_track=[["human_weap__currentGunModEids", ecs.TYPE_EID_LIST]],
  comps_rq=["controlledHero"]
})

ecs.register_es("next_soldier_spawn_time_es", {
  [["onInit", "onChange"]] = function(_eid, comp){
    nextSoldierSpawnTime.set(comp.unit__deathControlLostAtTime)
  },
  [["onDestroy"]] = function(_, _) {
    nextSoldierSpawnTime.set(-1.0)
  }
}, {
  comps_track=[["unit__deathControlLostAtTime", ecs.TYPE_FLOAT, -1.0]],
  comps_rq=["controlledHero"]
})


let showNextSoldierHint = keepref(Computed(@()
  nextSoldierSpawnTime.get() > 0.0 && watchedHeroSquadMembersAliveCount.get() > 0
))
showNextSoldierHint.subscribe(function(v) {
  g_hud_event_manager.onHudEvent( v
    ? "hint:squad:next_soldier_after_death_show"
    : "hint:squad:next_soldier_after_death_hide"
)
})

return {
  currentGunEid
  canSwitchFireMods
  switchFireModOn
  canSwithchOnUnbarrelLauncher
  unbarrelSwitchStatus
  hasLaserMod
  laserModActive
  hasFlashlightMod
  flashlightModActive
  needShowWeaponMenu
}