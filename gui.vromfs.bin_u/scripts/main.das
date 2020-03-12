options no_aot = true//since this is merely loader
require ecs
require DagorSystem

//load_es("scripts/game/vehicleInited.das") - sample for include systems

[init]
def load
  logwarn("Das scripts are loaded")