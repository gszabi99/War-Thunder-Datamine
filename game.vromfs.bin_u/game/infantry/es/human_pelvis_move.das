require ecs
require PhysVars
require DngHuman
require math
require math.base
require math.ang
require DagorMath
require %game.events


[es(tag=gameClient, on_appear, before=anim_phys_init_es)]
def human_pelvis_move_init_phys_vars(evt : Event;
                                     var human_anim__pelvisMoveEnabledId : int&;
                                     var human_anim__pelvisMoveOffsetId : int&;
                                     var human_anim__pelvisMoveOffsetCourseId : int&;
                                     var phys_vars : PhysVars&)
  human_anim__pelvisMoveEnabledId = phys_vars |> registerPullVar("pelvis_move_enabled", 0.0f)
  human_anim__pelvisMoveOffsetId = phys_vars |> registerVar("pelvis_move_offset", 0.0f)
  human_anim__pelvisMoveOffsetCourseId = phys_vars |> registerVar("pelvis_move_course", 0.0f)

[es(tag=gameClient, after=after_net_phys_sync, before=(before_animchar_update_sync, slot_attach_init_tms_es), REQUIRE_NOT=deadEntity)]
def human_pelvis_move_compensation(info : ParallelUpdateFrameDelayed;
                                   human_anim__pelvisMoveEnabledId : int;
                                   human_anim__pelvisMoveOffsetId : int&;
                                   human_anim__pelvisMoveOffsetCourseId : int&;
                                   human_anim__pelvisMoveGunPitchCompensation : float2; 
                                   human_anim__pelvisMoveLeanCompensation : float2; 
                                   isTpsView : bool = false;
                                   hero : Tag const?;
                                   human_net_phys : HumanActor;
                                   var phys_vars : PhysVars&)
  
  
  
  let isPelvisMoveEnabled = phys_vars |> getVar(human_anim__pelvisMoveEnabledId) > 0.0
  let isTpsViewOnSoldier = hero == null || isTpsView
  if !isTpsViewOnSoldier || !isPelvisMoveEnabled
    phys_vars |> setVar(human_anim__pelvisMoveOffsetId, 0.0)
    return

  assume phys = human_net_phys.phys
  assume curState = phys.currentState
  assume prevState = phys.previousState

  let gunDir = curState.gunDir
  let horizontalGunDir = normalize(float3(gunDir.x, 0.0, gunDir.z))
  let horizontalSideGunDir = normalize(float3(gunDir.z, 0.0, -gunDir.x))
  let verticalGunDir = gunDir.y

  let interpK = get_phys_interpk_clamped(phys, info.curTime)
  let standHeight = lerp(prevState.height, curState.height, interpK)
  let lean = lerp(prevState.leanPosition, curState.leanPosition, interpK) / phys.leanDegrees

  let gunPitchOffset = -verticalGunDir * horizontalGunDir * lerp(
    human_anim__pelvisMoveGunPitchCompensation.x, human_anim__pelvisMoveGunPitchCompensation.y, standHeight)

  let leanOffset = horizontalSideGunDir * lean * lerp(
    human_anim__pelvisMoveLeanCompensation.x, human_anim__pelvisMoveLeanCompensation.y, standHeight)

  let horizontalOffset = gunPitchOffset + leanOffset

  
  let forward = float3(1.0, 0.0, 0.0)
  let up = float3(0.0, 1.0, 0.0)
  
  let offsetCourse = rad_to_deg(atan2(dot(cross(horizontalOffset, forward), up), dot(forward, horizontalOffset)))

  phys_vars |> setVar(human_anim__pelvisMoveOffsetCourseId, offsetCourse)
  phys_vars |> setVar(human_anim__pelvisMoveOffsetId, -length(horizontalOffset))
