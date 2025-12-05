require ecs
require GamePhys
require HumanPhys
require DngHuman
require math.base
require DagorMath
require DagorMathUtils
require %game.events
require %appGame.infantry.es.human_weap_common

def binary_search_height(var phys : HumanPhys;
                         tm : float3x4;
                         check_offset_up : float;
                         check_offset_right : float;
                         var bad_ht : float;
                         var good_ht : float;
                         iter : int;
                         lean : float;
                         gun_mat_id : int;
                         max_backoff : float;
                         gun_angles : float)
  for _i in range(iter)
    let midHt = (bad_ht + good_ht) * 0.5
    var midGunTm : float3x4
    human_phys_calcGunTm(phys, PrecomputedPresetMode.TPV, tm, gun_angles, lean, midHt, midGunTm)
    var backoff : float
    if !check_gun_trace(phys, midGunTm, check_offset_up, check_offset_right, 1., gun_mat_id, max_backoff, backoff)
      good_ht = midHt
    else
      bad_ht = midHt
  return good_ht


def check_height(var phys : HumanPhys;
                 tm : float3x4;
                 check_offset_up : float;
                 check_offset_right : float;
                 gun_angles : float;
                 lean : float;
                 ht : float;
                 prev_ht : float;
                 iter : int;
                 gun_mat_id : int;
                 max_backoff : float;
                 var res_ht : float&)
  if saturate(ht) == saturate(prev_ht)
    return false 
  var gunTm : float3x4
  human_phys_calcGunTm(phys, PrecomputedPresetMode.TPV, tm, gun_angles, lean, saturate(ht), gunTm)
  var backoff : float
  if check_gun_trace(phys, gunTm, check_offset_up, check_offset_right, 1., gun_mat_id, max_backoff, backoff)
    return false
  res_ht = binary_search_height(phys, tm, check_offset_up, check_offset_right, saturate(prev_ht), saturate(ht), iter, lean, gun_mat_id, max_backoff, gun_angles)
  return true

def binary_search_lean(var phys : HumanPhys;
                       tm : float3x4;
                       check_offset_up : float;
                       check_offset_right : float;
                       var bad_lean : float;
                       var good_lean : float;
                       iter : int;
                       height : float;
                       gun_mat_id : int;
                       max_backoff : float;
                       gun_angles : float)
  for _i in range(iter)
    let midLean = (bad_lean + good_lean) * 0.5
    var midGunTm : float3x4
    human_phys_calcGunTm(phys, PrecomputedPresetMode.TPV, tm, gun_angles, midLean, height, midGunTm)
    var backoff : float
    if !check_gun_trace(phys, midGunTm, check_offset_up, check_offset_right, 1., gun_mat_id, max_backoff, backoff)
      good_lean = midLean
    else
      bad_lean = midLean
  return good_lean

def clamp_lean(val, limit : float)
  return clamp(val, -limit, limit)

def check_lean(var phys : HumanPhys;
               tm : float3x4;
               check_offset_up : float;
               check_offset_right : float;
               gun_angles : float;
               ht : float;
               lean : float;
               prev_lean : float;
               iter : int;
               gun_mat_id : int;
               max_backoff : float;
               var res_lean : float&)
  if clamp_lean(lean, phys.leanDegrees) == clamp_lean(prev_lean, phys.leanDegrees)
    return false 
  var gunTm : float3x4
  human_phys_calcGunTm(phys, PrecomputedPresetMode.TPV, tm, gun_angles, clamp_lean(lean, phys.leanDegrees), ht, gunTm)
  var backoff : float
  if check_gun_trace(phys, gunTm, check_offset_up, check_offset_right, 1., gun_mat_id, max_backoff, backoff)
    return false
  res_lean = binary_search_lean(phys, tm, check_offset_up, check_offset_right, clamp_lean(prev_lean, phys.leanDegrees),
                                clamp_lean(lean, phys.leanDegrees), iter, ht, gun_mat_id, max_backoff, gun_angles)
  return true

def find_better_height(var phys : HumanPhys;
                       tm : float3x4;
                       check_offset_up : float;
                       check_offset_right : float;
                       wish_height : float;
                       wish_lean : float;
                       gun_mat_id : int;
                       max_backoff : float;
                       var res_height : float&)
  let heightCount = 4
  let binaryIter = 5
  for h in range(heightCount - 1)
    let height = cvt(float(h + 1), 0., float(heightCount - 1), 0., 1.)
    let prevHeight = cvt(float(h), 0., float(heightCount - 1), 0., 1.)
    let gunAngles = phys.currentState.gunAngles
    if (check_height(phys, tm, check_offset_up, check_offset_right, gunAngles.y, wish_lean, wish_height - height, wish_height - prevHeight, binaryIter, gun_mat_id, max_backoff, res_height) ||
        check_height(phys, tm, check_offset_up, check_offset_right, gunAngles.y, wish_lean, wish_height + height, wish_height + prevHeight, binaryIter, gun_mat_id, max_backoff, res_height))
      return true
  return false

def find_better_lean(var phys : HumanPhys;
                     tm : float3x4;
                     check_offset_up : float;
                     check_offset_right : float;
                     wish_height : float;
                     wish_lean : float;
                     gun_mat_id : int;
                     max_backoff : float;
                     var res_lean : float&)
  let leanCount = 4
  let binaryIter = 5
  for l in range(leanCount - 1)
    let lean = cvt(float(l + 1), 0., float(leanCount - 1), 0., 1.) * phys.leanDegrees
    let prevLean = cvt(float(l), 0., float(leanCount - 1), 0., 1.) * phys.leanDegrees
    let gunAngles = phys.currentState.gunAngles
    if (check_lean(phys, tm, check_offset_up, check_offset_right, gunAngles.y, wish_height, wish_lean + lean, wish_lean + prevLean, binaryIter, gun_mat_id, max_backoff, res_lean) ||
        check_lean(phys, tm, check_offset_up, check_offset_right, gunAngles.y, wish_height, wish_lean - lean, wish_lean - prevLean, binaryIter, gun_mat_id, max_backoff, res_lean))
      return true
  return false


[es(REQUIRE_NOT=deadEntity, after=human_lean_controls, before=human_lean_apply)]
def human_weap_auto_height_lean(evt : CmdPostPhysUpdate;
                                human_weap__currentGunEid : EntityId;
                                human_weap__gunMatId : int;
                                human_weap__gunMaxBackoff : float = 0.0;
                                human_weap__gunEquipAIForce  : bool = false;
                                human_net_phys__isSimplifiedPhys : bool = false;
                                var human_net_phys__wishLean : float&;
                                var human_net_phys : HumanActor&)
  assume phys = human_net_phys.phys
  assume currentState = phys.currentState
  assume appliedCT = phys.appliedCT

  let autoleanSettingOn = find_query() <| $ [es] (autolean_settings__autolean : bool) => autolean_settings__autolean
  if !autoleanSettingOn
    return

  if !human_net_phys__isSimplifiedPhys
    human_phys_state_set_forceWeaponUp(currentState, false)
  else
    human_phys_state_set_forceWeaponUp(currentState, human_weap__gunEquipAIForce)

  let isCrawling = (int(currentState.states) & int(StateFlag.ST_CRAWL)) != 0
  let isAiming = is_control_bit_set(appliedCT, HumanPhysControlType.HCT_AIM)

  if !phys.hasGuns || isCrawling || human_net_phys__isSimplifiedPhys
    phys.hasExternalHeight = false
    return
  phys.hasExternalHeight = true

  let updateLean = isAiming

  let wishLean = human_net_phys__wishLean
  let wishHeight = currentState.extHeight
  var tm : float3x4
  currentState.location |> location_toTM(tm)

  var gunTm : float3x4
  human_phys_calcGunTm(phys, PrecomputedPresetMode.TPV, tm, currentState.gunAngles.y, wishLean, wishHeight, gunTm)

  var resLean = wishLean
  var resHeight = wishHeight
  var checkOffsetUp = 0.f
  var checkOffsetRight = 0.f
  query(human_weap__currentGunEid) <| $ [es] (human_weap__gunCheckOffsetUp : float; human_weap__gunCheckOffsetRight : float)
    checkOffsetUp = human_weap__gunCheckOffsetUp
    checkOffsetRight = human_weap__gunCheckOffsetRight

  var backoff : float
  if check_gun_trace(phys, gunTm, checkOffsetUp, checkOffsetRight, 1., human_weap__gunMatId, human_weap__gunMaxBackoff, backoff)
    
    
    var betterHeight = resHeight
    if find_better_height(phys, tm, checkOffsetUp, checkOffsetRight, wishHeight, wishLean, human_weap__gunMatId, human_weap__gunMaxBackoff, betterHeight)
      human_phys_state_set_forceWeaponUp(currentState, true)

    
    var betterLean = resLean
    if updateLean && find_better_lean(phys, tm, checkOffsetUp, checkOffsetRight, wishHeight, wishLean, human_weap__gunMatId, human_weap__gunMaxBackoff, betterLean)
      human_phys_state_set_forceWeaponUp(currentState, true)

    let htIsBetter = abs(betterHeight - resHeight) < abs(betterLean - resLean) * safeinv(phys.leanDegrees)
    if betterHeight != resHeight && (htIsBetter || betterLean == resLean)
      resHeight = betterHeight
      resLean = wishLean
    elif betterLean != resLean
      resHeight = wishHeight
      resLean = betterLean
    else
      resLean = wishLean
      resHeight = wishHeight

  currentState.extHeight = resHeight
  human_net_phys__wishLean = resLean
