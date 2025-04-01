require ecs
require math.base
require DngHuman
require DngHumanAnim
require PhysVars
require DagorRandom
require DagorMath
require DagorSystem
require DngWeapon
require %game.events
require PropsManager

def set_phys_selected_weapon_var_from_props(var phys_vars : PhysVars;
                                            gunPropsId : PropsId;
                                            gun_eid : EntityId;
                                            human_anim__selectedWeaponVarId : int;
                                            func_name : string)
  let result = get_props_GunToAnimProps(gunPropsId) <| $(gunAnimProps : GunToAnimProps)
    phys_vars |> setVar(human_anim__selectedWeaponVarId, float(gunAnimProps.enumVarId))

  if !result
    query(gun_eid) <| $ [es] (gun__blk : string = "";
                              melee_weapon__blk : string = "")
      logerr("Can't get GunToAnimProps in {func_name} with id {gunPropsId} in gun__propsId,
             eid/template {gun_eid}<{getEntityTemplateName(gun_eid)}> gunBlk: {gun__blk} meleeBlk: {melee_weapon__blk}")

[es(tag=gameClient)]
def human_anim_update_was_aim(info : ParallelUpdateFrameDelayed;
                              var human_anim__isAiming : bool&;
                              var human_anim__wasAiming : bool&;
                              human_net_phys : HumanActor)
  let isAiming = is_control_bit_set(human_net_phys.phys.appliedCT, HumanPhysControlType HCT_AIM)
  if isAiming != human_anim__isAiming || human_anim__isAiming != human_anim__wasAiming
    human_anim__wasAiming = human_anim__isAiming
    human_anim__isAiming = isAiming

[es(REQUIRE_NOT=deadEntity)]
def human_anim_weap_es(info : ParallelUpdateFrameDelayed;
                       human_weap__gunEids : EidList;
                       human_weap__radioMode : bool = false;
                       animchar__visible : bool = true;
                       human_anim__selectedWeaponVarId : int;
                       human_net_phys : HumanActor;
                       var phys_vars : PhysVars)
  if human_weap__radioMode || !animchar__visible
    return

  let gunSlot = determine_current_weapon_slot(info.curTime, human_net_phys)
  if int(gunSlot) >= length(human_weap__gunEids)
    return

  assume phys = human_net_phys.phys
  query(human_weap__gunEids[int(gunSlot)]) <| $ [es(REQUIRE_NOT=grenade_thrower)] (gun__propsId : PropsId)
    if gun__propsId.valid && human_anim__selectedWeaponVarId >= 0 && phys.canSwitchWeapon
      set_phys_selected_weapon_var_from_props(phys_vars, gun__propsId,
                                              human_weap__gunEids[int(gunSlot)],
                                              human_anim__selectedWeaponVarId, "human_anim_weap_es")

  query(human_weap__gunEids[int(gunSlot)]) <| $ [es(REQUIRE=grenade_thrower)] (grenade_thrower__selectedGrenadeVarId : int)
    if grenade_thrower__selectedGrenadeVarId >= 0 && human_anim__selectedWeaponVarId >= 0 && phys.canSwitchWeapon
      phys_vars |> setVar(human_anim__selectedWeaponVarId, float(grenade_thrower__selectedGrenadeVarId))































[es(REQUIRE_NOT=deadEntity, REQUIRE=menuChar)]
def base_menu_animchar_set_weapon_selected(info : ParallelUpdateFrameDelayed;
                                           human_weap__gunEids : EidList;
                                           human_anim__selectedWeaponVarId : int;
                                           human_weap__currentGunSlot : int;
                                           animchar__visible : bool = true;
                                           var phys_vars : PhysVars)
  if !animchar__visible || human_anim__selectedWeaponVarId < 0 || length(human_weap__gunEids) == 0
    return

  if human_weap__currentGunSlot < 0 || human_weap__currentGunSlot >= length(human_weap__gunEids)
    return

  let gunEid = human_weap__gunEids[human_weap__currentGunSlot]

  query(gunEid) <| $ [es] (gun__propsId : PropsId)
    if gun__propsId.valid
      set_phys_selected_weapon_var_from_props(phys_vars, gun__propsId, gunEid,
                                              human_anim__selectedWeaponVarId, "base_menu_animchar_set_weapon_selected")
