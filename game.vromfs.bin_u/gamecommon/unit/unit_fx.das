require ecs
require Unit
require UnitFx
require DmFire
require WTDamageModel
require %game.utils.utils_common
require %game.dm.fire_system_events
require %game.events
require %game.unit.unit_events


[es(no_order)]
def unit_fx_updater_es(info : UpdateStageInfoAct;
                       var unit__ref : UnitRef;
                       active : bool;
                       var unit_fx : UnitFx)
  if active
    unit_fx |> update(*unit__ref.unit, info.dt)


[es(on_event=CmdUpdateRelativeUnitHealth)]
def unit_fx_update_rel_health_es(evt : Event;
                                 var unit__ref : UnitRef;
                                 active : bool;
                                 var unit_fx : UnitFx)
  if active
    unit_fx |> updateRelativeHealth(*unit__ref.unit)


[es]
def unit_fx_stop_all_es(evt : CmdUnitFxStopAll;
                        active : bool;
                        var unit_fx : UnitFx)
  if active
    unit_fx |> stopAll(evt.immediately)


[es]
def unit_fx_hide_es(evt : CmdUnitFxHide;
                    active : bool;
                    var unit_fx : UnitFx)
  if active
    unit_fx |> hide(evt.hide)


[es]
def unit_fx_became_delayed_es(evt : EventUnitDelayedStatusChanged;
                              var unit_fx : UnitFx)
  if evt.isDelayed
    unit_fx |> stopAll(true)


[es(REQUIRE = fire_damage__isBurn, tag=server)]
def unit_fx_event_on_start_burn_es(evt : EventOnStartSingleBurn;
                                   active : bool;
                                   var unit_fx : UnitFx;
                                   var fire_fx__id : ecs::IntList;
                                   var fire_fx__fxId : ecs::IntList;
                                   var fire_fx__paramsId : ecs::IntList)
  if !active
    return

  let fireParams = get_fire_params(evt.fireParamsId)
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
                                var unit_fx : UnitFx;
                                var fire_fx__id : ecs::IntList;
                                var fire_fx__fxId : ecs::IntList;
                                var fire_fx__paramsId : ecs::IntList)
  if !active
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
                         var unit_fx : UnitFx;
                         var fire_fx__id : ecs::IntList;
                         var fire_fx__fxId : ecs::IntList;
                         var fire_fx__paramsId : ecs::IntList)
  if !active
    return
  for fxId in fire_fx__fxId
    unit_fx |> stopFxEventByIndex(fxId, false)
  fire_fx__id |> clear()
  fire_fx__fxId |> clear()
  fire_fx__paramsId |> clear()
