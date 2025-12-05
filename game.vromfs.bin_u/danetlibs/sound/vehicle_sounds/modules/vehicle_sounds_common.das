module vehicle_sounds_common shared

require ecs
require ecs.common
require vehicle_sounds.modules.vehicle_sounds_events


def set_vehicle_engine_started(isStarted : bool;
                               eid : EntityId;
                               var vehicle_engine_sound_state__isStarted : bool&;
                               var vehicle_engine_sound_state__isInited : bool&)
  let notifyStarted = vehicle_engine_sound_state__isStarted != isStarted && vehicle_engine_sound_state__isInited
  vehicle_engine_sound_state__isStarted = isStarted
  vehicle_engine_sound_state__isInited = true
  if notifyStarted
    sendEvent(eid, EventVehicleEngineSoundStarted(started = isStarted))
