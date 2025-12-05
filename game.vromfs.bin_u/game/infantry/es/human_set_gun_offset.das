require ecs
require HumanPhys
require DngHuman
require %game.events

[es(before=before_net_phys_sync)]
def human_phys_set_gun_offset_es(info : ParallelUpdateFrameDelayed;
                                 human_weap__currentGunEid : EntityId;
                                 var human_net_phys : HumanActor)
  human_net_phys.phys.gunOffset = float3(0.0)
  query(human_weap__currentGunEid) <| $ [es] (gun__animOffset : float3 = float3();
                                              gun_dynamic_position__offset : float3 = float3())
    human_net_phys.phys.gunOffset = gun__animOffset + gun_dynamic_position__offset