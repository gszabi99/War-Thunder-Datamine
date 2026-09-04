require ecs
require math.base
require DagorMathUtils
require DngHuman
require HumanPhys
require %appGame.wt_events

[es(tag=gameClient, REQUIRE=menuSoldier, on_appear)]
def menu_soldier_init(evt : Event;
                      squad_member__memberIdx : int;
                      transform : float3x4;
                      var human_net_phys : HumanActor;
                      var menu_soldier__baseGunDir : float3&;
                      var menu_soldier__targetYaw : float&;
                      var menu_soldier__curYaw : float&)
  
  menu_soldier__baseGunDir = normalize(float3(transform[0]))
  menu_soldier__targetYaw = 0.0
  menu_soldier__curYaw = 0.0
  query() <| $ [es(REQUIRE=hangar_human_spawn_point)] (hangar_human__soldierIdx : int; transform aka spawn_transform : float3x4)
    if hangar_human__soldierIdx == squad_member__memberIdx
      let spawnDir = normalize(float3(spawn_transform[0]))
      human_net_phys.phys.currentState.gunDir = spawnDir
      human_net_phys.phys.currentState.gunAngles = dir_to_angles(spawnDir)
      human_net_phys.phys.producedCT |> human_control_state_set_wish_shoot_dir(spawnDir)
      human_net_phys.phys.producedCT |> human_control_state_set_wish_look_dir(spawnDir)
      menu_soldier__baseGunDir = spawnDir



[es(tag=gameClient, REQUIRE=menuSoldier)]
def menu_soldier_rotate_input_es(evt : EventHangarCameraRotated;
                                 squad_member__memberIdx : int;
                                 var menu_soldier__targetYaw : float&;
                                 menu_soldier__rotationSpeed : float = 1.0)
  if squad_member__memberIdx != 0 
    return
  
  
  var weaponRaised = false
  query() <| $ [es] (hangar_weapon__raiseProgress : float)
    if hangar_weapon__raiseProgress > 0.0
      weaponRaised = true
  if weaponRaised
    return
  menu_soldier__targetYaw += evt.anglesDiff.x * menu_soldier__rotationSpeed



[es(tag=gameClient, no_order, REQUIRE=menuSoldier)]
def menu_soldier_rotate_apply_es(info : UpdateStageInfoAct;
                                 squad_member__memberIdx : int;
                                 menu_soldier__baseGunDir : float3;
                                 menu_soldier__targetYaw : float;
                                 var menu_soldier__curYaw : float&;
                                 var human_net_phys : HumanActor;
                                 menu_soldier__rotationViscosity : float = 0.1)
  if squad_member__memberIdx != 0
    return
  if length_sq(menu_soldier__baseGunDir) < FLT_EPSILON 
    return

  menu_soldier__curYaw = approach(menu_soldier__curYaw, menu_soldier__targetYaw, info.dt, menu_soldier__rotationViscosity)

  var angles = dir_to_angles(menu_soldier__baseGunDir)
  angles.x += menu_soldier__curYaw 
  let dir = angles_to_dir(angles)

  assume currentState = human_net_phys.phys.currentState
  currentState.gunDir = dir
  currentState.gunAngles = angles
  human_net_phys.phys.producedCT |> human_control_state_set_wish_shoot_dir(dir)
  human_net_phys.phys.producedCT |> human_control_state_set_wish_look_dir(dir)
