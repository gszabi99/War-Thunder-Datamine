require ecs
require ecs.common
require ecs.safe
require app
require net
require math.base
require DngHuman
require DagorSystem
require AnimV20
require GeomNodeTree
require %game.events
require %appGame.infantry.es.human_weap_common

require %appGame.wt_events




















































def human_weap_mod_activate(eid : EntityId;
                            isDowned : bool;
                            human_weap__gunEids : EidList;
                            human_weap__gunMods : Array;
                            human_weap__reloadFinishTime : float;
                            slot_id : int;
                            activate : bool;
                            var human_weap__weapModActivateStartTime : float&;
                            var human_weap__weapModActivateFinishTime : float&)
  verify(is_server())

  if slot_id < 0 || slot_id >= length(human_weap__gunMods) || isDowned
    return

  let curTime = get_sync_time()

  if !human_weap_can_reload(eid, human_weap__gunEids[slot_id]) || (human_weap__reloadFinishTime > curTime)
    sendEventImmediate(eid, EventOnSelectWeap(curr_gun_slot_id = slot_id))
    sendEventImmediate(eid, CmdInterruptReloadImmediately())

  let gunModEids = get_ecs_EidList(human_weap__gunMods[slot_id])
  for gunMod in *gunModEids
    query(gunMod) <| $ [es] (var weapon_mod__wantActiveState : bool&;
                             weapon_mod__activateTime : float;
                             weapon_mod__deactivateTime : float;
                             gun__ammo : int;
                             gun__totalAmmo : int;
                             ramrodGun : Tag const?)
      if weapon_mod__wantActiveState == activate || (
        ramrodGun != null && gun__ammo == 0 && gun__totalAmmo == 0)
        return
      weapon_mod__wantActiveState = activate
      if human_weap__weapModActivateFinishTime > 0.
        human_weap__weapModActivateStartTime = human_weap__weapModActivateFinishTime - curTime
      else
        human_weap__weapModActivateStartTime = curTime
      human_weap__weapModActivateFinishTime = human_weap__weapModActivateStartTime + (activate ? weapon_mod__activateTime : weapon_mod__deactivateTime)



[es]
def human_weap_mod_toggle_es(evt : CmdWeapModToggle; eid : EntityId; human_weap__gunMods : Array)
  if evt.slotId < 0 || evt.slotId >= length(human_weap__gunMods)
    return

  let gunModEids = get_ecs_EidList(human_weap__gunMods[evt.slotId])
  for gunMod in *gunModEids
    query(gunMod) <| $ [es] (weapon_mod__wantActiveState : bool)
      sendEvent(eid, CmdWeapModActivate(slotId = evt.slotId, activate = !weapon_mod__wantActiveState))


[es(tag=server, REQUIRE=human_weap__currentGunEid, track=human_weap__currentGunEid)]
def human_weap_mod_toggle_cancel_es(evt : Event;
                                    var human_weap__weapModActivateStartTime : float&;
                                    var human_weap__weapModActivateFinishTime : float&)
  human_weap__weapModActivateStartTime = -1.0
  human_weap__weapModActivateFinishTime = -1.0


[es(tag=server)]
def human_weap_mod_activate_server_es(evt : CmdWeapModActivate;
                                      eid : EntityId;
                                      isDowned : bool;
                                      human_weap__gunEids : EidList;
                                      human_weap__gunMods : Array;
                                      human_weap__reloadFinishTime : float;
                                      var human_weap__weapModActivateStartTime : float&;
                                      var human_weap__weapModActivateFinishTime : float&)
  human_weap_mod_activate(eid, isDowned, human_weap__gunEids, human_weap__gunMods,
                          human_weap__reloadFinishTime,
                          evt.slotId, evt.activate,
                          human_weap__weapModActivateStartTime,
                          human_weap__weapModActivateFinishTime)


[es(tag=netClient)]
def human_weap_mod_activate_client_es(evt : CmdWeapModActivate; eid : EntityId)
  send_net_event(eid, HumanRequestModActivate(slotId = evt.slotId, activate = evt.activate))


[es(tag=server)]
def human_weap_mod_activate_req_es(evt : HumanRequestModActivate;
                                   eid : EntityId;
                                   isDowned : bool;
                                   human_weap__gunEids : EidList;
                                   human_weap__gunMods : Array;
                                   human_weap__reloadFinishTime : float;
                                   var human_weap__weapModActivateStartTime : float&;
                                   var human_weap__weapModActivateFinishTime : float&)
  human_weap_mod_activate(eid, isDowned, human_weap__gunEids, human_weap__gunMods,
                          human_weap__reloadFinishTime,
                          evt.slotId, evt.activate,
                          human_weap__weapModActivateStartTime,
                          human_weap__weapModActivateFinishTime)


[es(REQUIRE=watchedByPlr, after=after_net_phys_sync, REQUIRE_NOT=deadEntity)]
def human_optics_camera_es(info : ParallelUpdateFrameDelayed;
                           human_net_phys : HumanActor;
                           human_weap__currentGunEid : EntityId;
                           human_weap__currentScope : EntityId;
                           var camera__magnification : float&;
                           var human_weap__opticsAttached : bool&)
  var gunScopeEid = human_weap__currentScope
  let isIntegratedScope = get_bool(human_weap__currentGunEid, "gun__integratedScope") ?? false

  if isIntegratedScope && !gunScopeEid
    gunScopeEid = human_weap__currentGunEid

  if !human_weap__currentGunEid
    camera__magnification = 1.0
    return

  let interpK = get_phys_interpk_clamped(human_net_phys.phys, info.curTime)
  let aimPosition = lerp(human_net_phys.phys.previousState.aimPosition, human_net_phys.phys.currentState.aimPosition, interpK)

  let zoomFactor = get_float(gunScopeEid, "gunmod__zoomFactor") ?? 0.0
  let zoomPosition = lerp(human_net_phys.phys.previousState.zoomPosition,
                          human_net_phys.phys.currentState.zoomPosition, interpK)

  human_weap__opticsAttached = zoomFactor > 0.0

  if !human_weap__opticsAttached
    let gunMagnification = get_float(human_weap__currentGunEid, "gun__magnification") ?? 1.5
    camera__magnification = lerp(1.0, gunMagnification, zoomPosition)
    return

  camera__magnification = lerp(1.0, zoomFactor, lerp(0.0, zoomPosition, aimPosition))

[es(tag=gameClient, on_appear, REQUIRE=(deadEntity, watchedByPlr), after=camera_set_sync, before=before_camera_sync)]
def human_reset_optics_on_die_es(evt : Event; var camera__magnification : float&)
  camera__magnification = 1.0

[es(tag=gameClient, on_appear)]
def human_optics_init_cam_node(evt : Event;
                               eid : EntityId;
                               animchar : AnimcharBaseComponent;
                               gunmod__camNode : string;
                               gunmod__frontsightCamNode : string;
                               var gunmod__camNodeId : int&;
                               var gunmod__frontsightCamNodeId : int&)
  gunmod__camNodeId = geomtree_findNodeIndex(*animchar.nodeTree, gunmod__camNode)
  if gunmod__camNodeId < 0
    logerr("node '{gunmod__camNode}' not found in animchar of gun '{getEntityTemplateName(eid)}'")

  if !empty(gunmod__frontsightCamNode)
    gunmod__frontsightCamNodeId = geomtree_findNodeIndex(*animchar.nodeTree, gunmod__frontsightCamNode)
    if gunmod__frontsightCamNodeId < 0
      logerr("node '{gunmod__frontsightCamNode}' not found in animchar of gun '{getEntityTemplateName(eid)}'")

[es(tag=gameClient)]
def human_weap_change_zoom_to_next(evt : NextVariableZoomGunScope;
                                   human_weap__currentScope : EntityId;
                                   human_weap__currentGunEid : EntityId)
  var gunScopeEid = human_weap__currentScope
  let isIntegratedScope = get_bool(human_weap__currentGunEid, "gun__integratedScope") ?? false

  if isIntegratedScope && !gunScopeEid
    gunScopeEid = human_weap__currentGunEid
  query(gunScopeEid) <| $ [es] (gunmod__variableZoomOptions : Array;
                                gunmod__zoomFactor : float;
                                gunmod__camShiftMin : float;
                                gunmod__camShiftMax : float;
                                var gunmod__previousZoomFactor : float&;
                                var gunmod__previousCamShiftMin : float&;
                                var gunmod__previousCamShiftMax : float&;
                                var gunmod__currentZoomIndex : int&;
                                var gunmod__zoomAnimationTime : float&)
    gunmod__previousZoomFactor = gunmod__zoomFactor
    gunmod__previousCamShiftMin = gunmod__camShiftMin
    gunmod__previousCamShiftMax = gunmod__camShiftMax
    gunmod__currentZoomIndex = (gunmod__currentZoomIndex + 1) % length(gunmod__variableZoomOptions)
    gunmod__zoomAnimationTime = 0.0

[es(tag=gameClient, no_order)]
def human_weap_zoom_animation(info : UpdateStageInfoAct;
                              gunmod__previousZoomFactor : float;
                              gunmod__previousCamShiftMin : float;
                              gunmod__previousCamShiftMax : float;
                              gunmod__currentZoomIndex : int;
                              gunmod__variableZoomOptions : Array;
                              gunmod__zoomAnimationViscocity : float;
                              var gunmod__zoomAnimationTime : float&;
                              var gunmod__zoomFactor : float&;
                              var gunmod__camShiftMin : float&;
                              var gunmod__camShiftMax : float&)
  let zoomOptions = gunmod__variableZoomOptions?[gunmod__currentZoomIndex] ?as Object
  let targetZoomFactor = zoomOptions?.gunmod__zoomFactor ?? gunmod__previousZoomFactor
  let targetCamShiftMin = zoomOptions?.gunmod__camShiftMin ?? gunmod__previousCamShiftMin
  let targetCamShiftMax = zoomOptions?.gunmod__camShiftMax ?? gunmod__previousCamShiftMax

  gunmod__zoomAnimationTime += info.dt
  gunmod__zoomFactor = approach(gunmod__previousZoomFactor, targetZoomFactor, gunmod__zoomAnimationTime, gunmod__zoomAnimationViscocity)
  gunmod__camShiftMin = approach(gunmod__previousCamShiftMin, targetCamShiftMin, gunmod__zoomAnimationTime, gunmod__zoomAnimationViscocity)
  gunmod__camShiftMax = approach(gunmod__previousCamShiftMax, targetCamShiftMax, gunmod__zoomAnimationTime, gunmod__zoomAnimationViscocity)

[es(tag=server)]
def toogle_laser_es(evt : LaserToggle;
                    squad_member__squad : EntityId;
                    human_weap__currentGunModEids : EidList;
                    human_weap__gunModsBySlot : Array)
  let gunModInSlot = human_weap__gunModsBySlot[evt.slotId] |> get_ecs_object()
  if gunModInSlot == null
    return
  for eid in human_weap__currentGunModEids
    query(eid) <| $ [es] (gunAttachable__slotTag : string;
                          var laserActive : bool&) 
      for kv in *gunModInSlot
        let slotTag := get_string(kv.value, "")
        if slotTag == gunAttachable__slotTag
          laserActive = !laserActive
          query(squad_member__squad) <| $ [es] (var squad__laserActive : bool&)
            squad__laserActive = laserActive
          return

[es(tag=server)]
def toogle_flash_light_es(evt : FlashLightToggle;
                          squad_member__squad : EntityId;
                          human_weap__currentGunModEids : EidList;
                          human_weap__gunModsBySlot : Array)
  let gunModInSlot = human_weap__gunModsBySlot[evt.slotId] |> get_ecs_object()
  if gunModInSlot == null
    return
  for eid in human_weap__currentGunModEids
    query(eid) <| $ [es] (gunAttachable__slotTag : string;
                          var flashlight__on : bool&) 
      for kv in *gunModInSlot
        let slotTag := get_string(kv.value, "")
        if slotTag == gunAttachable__slotTag
          flashlight__on = !flashlight__on
          query(squad_member__squad) <| $ [es] (var squad__flashlightOn : bool&)
            squad__flashlightOn = flashlight__on
          return

[es(tag=server, on_appear, track=(possessedByPlr, human_weap__currentGunEid))]
def update_tactical_device_state_on_hero_change_es(evt : Event;
                                                   possessedByPlr : EntityId;
                                                   human_weap__currentGunEid : EntityId;
                                                   squad_member__squad : EntityId;
                                                   human_weap__currentGunModEids : EidList;
                                                   human_weap__gunModsBySlot : Array;
                                                   human_weap__currentGunSlot : int)
  if !possessedByPlr
    return
  if human_weap__currentGunSlot < 0
    return

  query(human_weap__currentGunEid) <| $ [es] (gun__firingModes : Array; var gun__firingModeIndex : int&)
    query(squad_member__squad) <| $ [es] (squad__firingModeIndex : int)
      let gunModesSize = length(gun__firingModes)
      if squad__firingModeIndex >= gunModesSize
        return
      gun__firingModeIndex = squad__firingModeIndex

  let gunModInSlot = human_weap__gunModsBySlot[human_weap__currentGunSlot] |> get_ecs_object()
  if gunModInSlot == null
    return
  for gunMod in human_weap__currentGunModEids
    query(gunMod) <| $ [es] (gunAttachable__slotTag : string;
                             var flashlight__on : bool?;
                             var laserActive : bool?)
      for kv in *gunModInSlot
        let slotTag := get_string(kv.value, "")
        if slotTag == gunAttachable__slotTag
          query(squad_member__squad) <| $ [es] (squad__flashlightOn, squad__laserActive : bool)
            if flashlight__on != null
              *flashlight__on = squad__flashlightOn
            if laserActive != null
              *laserActive = squad__laserActive
      return

[es(tag=server, on_appear, track=human_gun_attached)]
def update_tactical_device_on_weapon_change_es(evt : Event;
                                               eid : EntityId;
                                               human_gun_attached : bool)
  if human_gun_attached
    return
  query() <| $ [es(REQUIRE=weaponMod)] (animchar_attach__attachedTo : EntityId;
                                        var flashlight__on : bool?;
                                        var laserActive : bool?)
    if animchar_attach__attachedTo == eid
      if flashlight__on != null
        *flashlight__on = false
      if laserActive != null
        *laserActive = false
















