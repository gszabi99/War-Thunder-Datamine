require ecs
require %game.events
require DngHuman

[es(REQUIRE=gun__bipodMandatory)]
def check_can_operate_gun_mandatory_bipod(evt : CmdWeapPhysUpdate)
  query(evt.owner) <| $ [es] (human_net_phys__isCrawl : bool; bipod__enabled : bool; var human_weap__canOperate : bool&)
    human_weap__canOperate = human_net_phys__isCrawl || bipod__enabled

[es(tag=server, track=human_weap__canOperate)]
def interrupt_reload_weapon_that_cannot_operate_without_bipod(evt : Event; eid : EntityId; human_weap__canOperate : bool)
  if !human_weap__canOperate
    sendEvent(eid, CmdInterruptReloadImmediately())

[es(tag=gameClient, REQUIRE=hero, track=human_weap__canOperate)]
def interrupt_reload_weapon_that_cannot_operate_without_bipod_local(evt : Event; eid : EntityId; human_weap__canOperate : bool)
  if !human_weap__canOperate
    sendEvent(eid, CmdInterruptReloadImmediately())

[es(tag=server, track=human_weap__currentGunEid)]
def check_can_operate_gun_on_weapon_change(evt : Event; human_weap__currentGunEid : EntityId; var human_weap__canOperate : bool&)
  human_weap__canOperate = !has(human_weap__currentGunEid, "gun__bipodMandatory")

[es(tag=gameClient, REQUIRE=hero, track=human_weap__currentGunEid)]
def check_can_operate_gun_on_weapon_change_local(evt : Event; human_weap__currentGunEid : EntityId; var human_weap__canOperate : bool&)
  human_weap__canOperate = !has(human_weap__currentGunEid, "gun__bipodMandatory")

[es]
def human_weap_force_weapon_down(evt : CmdPostPhysUpdate; human_weap__canOperate : bool; var human_net_phys : HumanActor&)
  human_net_phys.phys.currentState |> human_phys_state_set_forceWeaponDown(!human_weap__canOperate)
