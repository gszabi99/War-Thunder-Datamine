require ecs
require DagorMathUtils
require DngHuman
require HumanPhys

[es(tag=gameClient, REQUIRE=menuSoldier, on_appear)]
def menu_soldier_init(evt : Event;
                      squad_member__memberIdx : int;
                      var human_net_phys : HumanActor)
  query() <| $ [es(REQUIRE=hangar_human_spawn_point)] (hangar_human__soldierIdx : int; transform : float3x4)
    if hangar_human__soldierIdx == squad_member__memberIdx
      var spawnDir = normalize(float3(transform[0]))
      human_net_phys.phys.currentState.gunDir = spawnDir
      human_net_phys.phys.currentState.gunAngles = dir_to_angles(spawnDir)
      human_net_phys.phys.producedCT |> human_control_state_set_wish_shoot_dir(spawnDir)
      human_net_phys.phys.producedCT |> human_control_state_set_wish_look_dir(spawnDir)