require ecs
require Unit
require UnitFx
require WTDamageModel
require %game.events
require %game.fire_system_events
require %game.utils_common


[es]
def unit_fx_updater_es(info : ParallelUpdateFrameDelayed;
                       uid : int;
                       active : bool;
                       var unit_fx : UnitFx)
  if active
    get_unit_for_edit(uid) <| $(var unit)
      unit_fx |> update(*unit, info.dt)


[es(on_event=CmdUpdateRelativeUnitHealth)]
def unit_fx_update_rel_health_es(evt : Event;
                                 uid : int;
                                 active : bool;
                                 var unit_fx : UnitFx)
  if active
    get_unit_for_edit(uid) <| $(var unit)
      unit_fx |> updateRelativeHealth(*unit)


[es]
def unit_fx_stop_all_es(evt : CmdUnitFxStopAll;
                        active : bool;
                        var unit_fx : UnitFx)
  if active
    unit_fx |> stopAll(evt.immediately)


[es]
def unit_fx_hide_es(evt : CmdUnitFxHide;
                    uid : int;
                    active : bool;
                    var unit_fx : UnitFx)
  let unit = get_unit(uid)
  if active && unit != null && !unit.isDelayed
    unit_fx |> hide(evt.hide)


[es(on_event=EventBecameDelayed)]
def unit_fx_became_delayed_es(evt : Event;
                              active : bool;
                              var unit_fx : UnitFx)
  if active
    unit_fx |> stopAll(true)


[es(REQUIRE = fire_damage__isBurn)]
def unit_fx_event_on_start_burn_es(evt : EventOnStartSingleBurn;
                                   active : bool;
                                   uid : int;
                                   var unit_fx : UnitFx;
                                   var fire_fx__id : ecs::IntList;
                                   var fire_fx__fxId : ecs::IntList;
                                   var fire_fx__paramsId : ecs::IntList)
  let unit = get_unit(uid)
  if !active || unit == null || unit.isDelayed || !unit.isAuthority
    return

  let fireParams = get_fire_params(evt.fireParamsId);
  assert(fireParams != null)
  if fireParams == null
    return

  if !fireParams.allowMultipleFx
    for paramsId in fire_fx__paramsId
      if paramsId == evt.fireParamsId
        return

  var eventId = evt.fireFxId
  if eventId == -1
    eventId = unit_fx.engineFireFxEventId
    if fireParams.fxPresetName != ""
      eventId = unit_fx |> getEventIdByName(fireParams.fxPresetName)

  let fxId = unit_fx |> startFxEvent(eventId, evt.nodeId, evt.offset, evt.dmgPos)
  fire_fx__id |> push(evt.fireId)
  fire_fx__fxId |> push(fxId)
  fire_fx__paramsId |> push(evt.fireParamsId)


[es(REQUIRE = fire_damage__isBurn)]
def unit_fx_stop_single_burn_es(evt : EventOnStopSingleBurn;
                                active : bool;
                                uid : int;
                                var unit_fx : UnitFx;
                                var fire_fx__id : ecs::IntList;
                                var fire_fx__fxId : ecs::IntList;
                                var fire_fx__paramsId : ecs::IntList)
  let unit = get_unit(uid)
  if !active || unit == null || unit.isDelayed
    return

  var i = length(fire_fx__paramsId)
  while --i >= 0
    if fire_fx__id[i] == evt.fireId
      unit_fx |> stopFxEventByIndex(fire_fx__fxId[i], false)
      fire_fx__id |> erase(i)
      fire_fx__fxId |> erase(i)
      fire_fx__paramsId |> erase(i)


[es(REQUIRE = fire_damage__isBurn, on_event=EventOnStopBurn)]
def unit_fx_stop_burn_es(evt : Event;
                         active : bool;
                         uid : int;
                         var unit_fx : UnitFx;
                         var fire_fx__id : ecs::IntList;
                         var fire_fx__fxId : ecs::IntList;
                         var fire_fx__paramsId : ecs::IntList)
  let unit = get_unit(uid)
  if !active || unit == null || unit.isDelayed
    return

  for fxId in fire_fx__fxId
    unit_fx |> stopFxEventByIndex(fxId, false);
  fire_fx__id |> clear()
  fire_fx__fxId |> clear()
  fire_fx__paramsId |> clear()
