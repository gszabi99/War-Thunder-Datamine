require ecs
require math.base
require PhysVars
require DngHuman
require %game.events
require DagorMath


[es(on_appear, before=anim_phys_init_es)]
def grenade_anim_init(evt : Event;
                      var grenade__throwProgressVarId : int&;
                      var phys_vars : PhysVars)
  grenade__throwProgressVarId = phys_vars |> registerVar("throw_progress", 0.0)












[es(tag=gameClient, before=anim_phys_init_es, on_appear)]
def gun_lean_anim_init(evt : Event;
                       gun_tilt__weaponRootRotateVarName : string;
                       gun_tilt__weaponRoot2RotateVarName : string;
                       var gun_tilt__weaponRootRotateVarId : int&;
                       var gun_tilt__weaponRoot2RotateVarId : int&;
                       var phys_vars : PhysVars)
  gun_tilt__weaponRootRotateVarId = phys_vars |> registerVar(gun_tilt__weaponRootRotateVarName, 0.0)
  gun_tilt__weaponRoot2RotateVarId = phys_vars |> registerVar(gun_tilt__weaponRoot2RotateVarName, 0.0)

def private approach_var(var phys_vars : PhysVars&;
                         var_id : int;
                         target_value : float;
                         dt : float;
                         viscosity : float)
  let new_value = approach(getVar(phys_vars, var_id), target_value, dt, viscosity)
  phys_vars |> setVar(var_id, new_value)

[es(tag=gameClient, no_order)]
def gun_lean_anim_update(info : ParallelUpdateFrameDelayed;
                         gun__owner : EntityId;
                         human_gun_attached : bool;
                         gun_anim__reloadProgress : float;
                         gun_tilt__reloadProgressLimit : float;
                         gun_tilt__weaponRootRotateVarId : int;
                         gun_tilt__weaponRoot2RotateVarId : int;
                         gun_tilt__defaultAngle : float;
                         gun_tilt__tpsAngle : float;
                         gun_tilt__leanTpsAngle : float2 const?;
                         gun_tilt__fpsAngle : float;
                         gun_tilt__fpsAngleOptional : float const?;
                         gun_tilt__leanFpsAngle : float2 const?;
                         gun_tilt__leanTpsElbows : float3 const?;
                         gun_tilt__viscocity : float;
                         var phys_vars : PhysVars;
                         animchar__visible : bool = true;
                         grenade_thrower__projectileEntity : EntityId const?;
                         subsidiaryGunEid : EntityId const?)
  if !animchar__visible
    return
  assume phys = human_net_phys.phys
  assume curSt = phys.currentState
  assume prevSt = phys.previousState

  query(gun__owner) <| $ [es] (human_net_phys : HumanActor;
                               human_net_phys__curMoveState : int;
                               human_anim__isFpv : bool;
                               isTpsView : bool;
                               human_net_phys__isCrawl : bool;
                               bipod__enabled : bool = false)
    if !human_gun_attached
      if grenade_thrower__projectileEntity != null
        query(*grenade_thrower__projectileEntity) <| $ [es] (gun_tilt__weaponRoot2RotateVarId : int; var phys_vars aka grenade_phys_vars : PhysVars)
          grenade_phys_vars |> setVar(gun_tilt__weaponRoot2RotateVarId, 0.)
      else
        phys_vars |> setVar(gun_tilt__weaponRoot2RotateVarId, 0.)
      return

    assume isAim = is_control_bit_set(phys.appliedCT, HumanPhysControlType.HCT_AIM)
    assume isCrawl = human_net_phys__isCrawl
    assume isReloading = gun_anim__reloadProgress > 0.
    assume isEndOfReloading = gun_anim__reloadProgress > gun_tilt__reloadProgressLimit
    assume isInSprint = human_net_phys__curMoveState == int(HUMoveState.EMS_SPRINT)

    let isWearingWeaponMod = subsidiaryGunEid != null
    let isWearingOffWeaponMod = isWearingWeaponMod && isReloading

    let isTpsViewOnSoldier = !human_anim__isFpv || isTpsView
    var targetTilt = 0.0
    var elbowTilt = 0.0

    let interpK = get_phys_interpk_clamped(phys, info.curTime)
    let lean = lerp(prevSt.leanPosition, curSt.leanPosition, interpK)

    
    if ((isReloading && !isEndOfReloading) || isAim || isCrawl || bipod__enabled || isWearingWeaponMod || isInSprint) && !isWearingOffWeaponMod
      targetTilt = gun_tilt__defaultAngle
    else
      assume leanTilt = isTpsViewOnSoldier ? gun_tilt__leanTpsAngle : gun_tilt__leanFpsAngle
      var tilt = isTpsViewOnSoldier ? gun_tilt__tpsAngle : gun_tilt__fpsAngle
      var useNeoclassicalTilt = false
      find_query() <| $ [es] (neoclassical_tilt__enable : bool)
        useNeoclassicalTilt = neoclassical_tilt__enable
        return true

      if useNeoclassicalTilt && gun_tilt__fpsAngleOptional != null && !isTpsViewOnSoldier
        tilt += *gun_tilt__fpsAngleOptional
      if leanTilt != null
        targetTilt = (lean < 0.0
          ? cvt(lean, -phys.leanDegrees, 0.0, (*leanTilt).x, tilt)
          : cvt(lean, 0.0, phys.leanDegrees, tilt, (*leanTilt).y))
      else
        targetTilt = tilt

    if gun_tilt__leanTpsElbows != null
      elbowTilt = (lean < 0.0
        ? cvt(lean, -phys.leanDegrees, 0.0, (*gun_tilt__leanTpsElbows).x, (*gun_tilt__leanTpsElbows).y)
        : cvt(lean, 0.0, phys.leanDegrees, (*gun_tilt__leanTpsElbows).y, (*gun_tilt__leanTpsElbows).z))

    if grenade_thrower__projectileEntity != null
      query(*grenade_thrower__projectileEntity) <| $ [es] (gun_tilt__weaponRoot2RotateVarId : int; var phys_vars aka grenade_phys_vars : PhysVars)
        grenade_phys_vars |> approach_var(gun_tilt__weaponRootRotateVarId, elbowTilt, info.dt, gun_tilt__viscocity)
        grenade_phys_vars |> approach_var(gun_tilt__weaponRoot2RotateVarId, targetTilt - elbowTilt, info.dt, gun_tilt__viscocity)
    else
      phys_vars |> approach_var(gun_tilt__weaponRootRotateVarId, elbowTilt, info.dt, gun_tilt__viscocity)
      phys_vars |> approach_var(gun_tilt__weaponRoot2RotateVarId, targetTilt - elbowTilt, info.dt, gun_tilt__viscocity)
