require ecs
require math.base
require DagorMathUtils
require DngHuman
require HumanPhys
require Unit
require %game.events


[es(on_appear, on_event=(EventUnitSpawned, EventUnitRespawn))]
def human_spawn_orientation_es(evt : Event;
                               unit__ref : UnitRef;
                               var human_net_phys : HumanActor&)
  let transform = unit__ref.unit.unitTm
  let spawnDir = normalize(transform[0])
  let spawnAngles = dir_to_angles(spawnDir)
  let spawnDirXZ = normalize(spawnDir.xz)

  assume currentState = human_net_phys.phys.currentState
  currentState.gunDir = spawnDir
  currentState.headDir = spawnDir
  currentState.gunAngles = spawnAngles
  currentState.walkDir = spawnDirXZ
  currentState.bodyOrientDir = spawnDirXZ
  currentState.prevAngles = spawnAngles
  currentState.gunSpd = float2(0.0, 0.0)
  currentState.targetGunSpd = float2(0.0, 0.0)

  assume previousState = human_net_phys.phys.previousState
  previousState.gunDir = spawnDir
  previousState.headDir = spawnDir
  previousState.gunAngles = spawnAngles
  previousState.walkDir = spawnDirXZ
  previousState.bodyOrientDir = spawnDirXZ

  human_net_phys.phys.producedCT |> human_control_state_set_wish_shoot_dir(spawnDir)
  human_net_phys.phys.producedCT |> human_control_state_set_wish_look_dir(spawnDir)
  human_net_phys.phys.appliedCT |> human_control_state_set_wish_shoot_dir(spawnDir)
  human_net_phys.phys.appliedCT |> human_control_state_set_wish_look_dir(spawnDir)
