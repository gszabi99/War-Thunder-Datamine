require ecs
require DngHuman
require HumanPhys

[es(track=(gun__adsSpeedMult, human_gun_attached, animchar_attach__attachedTo), on_appear, REQUIRE_NOT=grenade_thrower_gun)]
def human_gun_to_phys_params(evt : Event;
                             human_gun_attached : bool;
                             slot_attach__weaponSlotIdx : int;
                             animchar_attach__attachedTo : EntityId;
                             weap__sprintLerpFactor : float = 1.f;
                             gun__adsSpeedMult : float = 1.0)
  if human_gun_attached && slot_attach__weaponSlotIdx != int(HUWeaponSlots.EWS_GRENADE)
    query(animchar_attach__attachedTo) <| $ [es] (var human_net_phys : HumanActor)
      human_net_phys.phys.currentState.sprintLerpSpeedMult = weap__sprintLerpFactor
      human_net_phys.phys.aimSpeed = human_net_phys.phys.defAimSpeed * gun__adsSpeedMult

[es(track=human_unarmed__active)]
def human_unarmed_sprint(evt : Event; human_unarmed__active : bool; var human_net_phys : HumanActor)
  if human_unarmed__active
    human_net_phys.phys.currentState.sprintLerpSpeedMult = 1.f
