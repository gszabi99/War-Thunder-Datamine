require ecs
require net
require math
require app
require Unit
require MPlayer
require Weapon
require PropsManager
require ProximityFuse
require %game.player_events
require %appGame.wt_events
require %game.utils.utils_common


def private find_torpedo_props_with_magnetic_fuse(unit : Unit) : TorpedoProperties const?
  var result : TorpedoProperties const?
  if unit.weap == null
    return result
  foreach_torpedo_gun(unit.weap.Weapons) <| $(weapon)
    if result == null && weapon.prop.shellProps != null
      let torpedoProps = try_get_props_TorpedoProperties(weapon.prop.shellProps.shellPropsId)
      if torpedoProps != null && length(torpedoProps.proximityFuseProps.magneticSensitivityPresets) > 0
        result = torpedoProps
  return result

def private init_magnetic_fuse(player_eid : EntityId; unit : Unit)
  let torpedoProps = find_torpedo_props_with_magnetic_fuse(unit)
  query(player_eid) <| $ [es] (is_local : bool;
                               shell_program__magneticFuseSensitivityPreset : int;
                               var shell_program__magneticFuseSensitivityPresetValues : FloatList)
    if !is_local && !is_server()
      return
    shell_program__magneticFuseSensitivityPresetValues |> clear()
    if torpedoProps == null
      return
    assume fuseProps = torpedoProps.proximityFuseProps
    for preset in fuseProps.magneticSensitivityPresets
      shell_program__magneticFuseSensitivityPresetValues |> push(preset)
    if is_local && (shell_program__magneticFuseSensitivityPreset < 0 || shell_program__magneticFuseSensitivityPreset >= length(fuseProps.magneticSensitivityPresets))
      send_net_event(player_eid, CmdSetMagneticFuseSensitivityPreset(presetIdx = fuseProps.magneticDefaultSensitivityIndex))

struct private TorpedoCourseRun
  props : TorpedoProperties const?
  distToLive : float
  maxSpeed : float

def private find_torpedo_course_run(unit : Unit const?) : TorpedoCourseRun
  var result : TorpedoCourseRun
  if unit == null || unit.weap == null
    return result
  foreach_torpedo_gun(unit.weap.Weapons) <| $(weapon)
    if result.props == null && weapon.prop.shellProps != null
      let torpedoProps = try_get_props_TorpedoProperties(weapon.prop.shellProps.shellPropsId)
      if torpedoProps != null && torpedoProps.gyroProgramProps.courseModesMask != 0
        let speedMult = get_difficulty_config().torpedoSpeedMultFromDist
        result.props = torpedoProps
        result.distToLive = weapon.prop.distToLive
        result.maxSpeed = weapon.prop.rawMaxSpeedInWater * max(speedMult.x, speedMult.y)
  return result

def private get_course_run_factor(run : TorpedoCourseRun; mode : int) : float
  if mode == int(TorpedoCourseMode.CIRCLE)
    return 2.0 * PI
  return max(float(run.props.gyroProgramProps.minSectionsAfterStart) - 1.5, 0.5)

def private get_path_section_min(run : TorpedoCourseRun; mode : int) : float
  assume gyroProps = run.props.gyroProgramProps
  let turnMult = mode == int(TorpedoCourseMode.CIRCLE) ? gyroProps.radiusMinTurnMult : gyroProps.pathSectionMinTurnMult
  let turnRadius = gyroProps.turnAngularSpeed > 0.0 ? run.maxSpeed / gyroProps.turnAngularSpeed : 0.0
  return max(gyroProps.pathSectionMin, turnMult * turnRadius)

def private get_start_section_max(run : TorpedoCourseRun; mode : int; path_section : float) : float
  return max(run.distToLive - get_course_run_factor(run, mode) * path_section, run.props.gyroProgramProps.startSectionMin)

def private get_path_section_max(run : TorpedoCourseRun; mode : int; start_section : float) : float
  return max((run.distToLive - start_section) / get_course_run_factor(run, mode), get_path_section_min(run, mode))

def private is_course_mode_valid(run : TorpedoCourseRun; mode : int) : bool
  assume gyroProps = run.props.gyroProgramProps
  if mode == int(TorpedoCourseMode.NONE)
    return true
  if !(gyroProps |> isModeAllowed(mode))
    return false
  let runAfterStart = get_course_run_factor(run, mode) * get_path_section_min(run, mode)
  return gyroProps.startSectionMin + runAfterStart <= run.distToLive

def private get_valid_course_modes_mask(run : TorpedoCourseRun) : int
  var mask = 0
  for mode in range(int(TorpedoCourseMode.TRIANGULAR_ZIGZAG), int(TorpedoCourseMode.CIRCLE) + 1)
    if is_course_mode_valid(run, mode)
      mask |= 1 << mode
  return mask

def private update_course_program(run : TorpedoCourseRun;
                                  is_start_section_changed : bool;
                                  var mode : int&;
                                  var start_section : float&;
                                  var path_section : float&;
                                  var modes_mask : int&;
                                  var start_section_min : float&;
                                  var start_section_max : float&;
                                  var path_section_min : float&;
                                  var path_section_max : float&)
  modes_mask = 0
  start_section_min = 0.0
  start_section_max = 0.0
  path_section_min = 0.0
  path_section_max = 0.0
  if run.props == null
    mode = int(TorpedoCourseMode.NONE)
    return
  assume gyroProps = run.props.gyroProgramProps
  modes_mask = get_valid_course_modes_mask(run)
  if !is_course_mode_valid(run, mode)
    mode = int(TorpedoCourseMode.NONE)
  if start_section < 0.0
    start_section = gyroProps.startSectionDefault
  if path_section < 0.0
    path_section = gyroProps.pathSectionDefault
  if mode == int(TorpedoCourseMode.NONE)
    return
  start_section_min = gyroProps.startSectionMin
  path_section_min = get_path_section_min(run, mode)
  if is_start_section_changed
    start_section = clamp(start_section, start_section_min, get_start_section_max(run, mode, path_section_min))
    path_section = clamp(path_section, path_section_min, get_path_section_max(run, mode, start_section))
  else
    path_section = clamp(path_section, path_section_min, get_path_section_max(run, mode, start_section_min))
    start_section = clamp(start_section, start_section_min, get_start_section_max(run, mode, path_section))
  start_section_max = get_start_section_max(run, mode, path_section)
  path_section_max = get_path_section_max(run, mode, start_section)

def private init_course_program(player_eid : EntityId; unit : Unit const?)
  let run = find_torpedo_course_run(unit)
  query(player_eid) <| $ [es] (is_local : bool;
                               shell_program__torpedoGuidanceMode : int;
                               var shell_program__torpedoCourseMode : int&;
                               var shell_program__torpedoCourseStartSection : float&;
                               var shell_program__torpedoCoursePathSection : float&;
                               var shell_program__torpedoCourseModesMask : int&;
                               var shell_program__torpedoCourseStartSectionMin : float&;
                               var shell_program__torpedoCourseStartSectionMax : float&;
                               var shell_program__torpedoCoursePathSectionMin : float&;
                               var shell_program__torpedoCoursePathSectionMax : float&)
    if !is_local && !is_server()
      return
    update_course_program(run, false, shell_program__torpedoCourseMode,
      shell_program__torpedoCourseStartSection, shell_program__torpedoCoursePathSection,
      shell_program__torpedoCourseModesMask,
      shell_program__torpedoCourseStartSectionMin, shell_program__torpedoCourseStartSectionMax,
      shell_program__torpedoCoursePathSectionMin, shell_program__torpedoCoursePathSectionMax)
    if !is_local || run.props == null
      return
    send_net_event(player_eid, CmdSetTorpedoCourseProgram(
      guidanceMode = shell_program__torpedoGuidanceMode,
      mode = shell_program__torpedoCourseMode,
      startSection = shell_program__torpedoCourseStartSection,
      pathSection = shell_program__torpedoCoursePathSection))

def private init_dive_depth(player_eid : EntityId)
  if get_difficulty_config().shipTorpedoAutoUpdateDepth
    return
  query(player_eid) <| $ [es] (is_local : bool; shell_program__torpedoDiveDepth : float)
    if !is_local
      return
    let depth = get_option_torpedo_dive_depth()
    if depth != shell_program__torpedoDiveDepth
      send_net_event(player_eid, CmdSetTorpedoDiveDepth(depth = depth))

[es]
def shell_program_init_es(evt : EventPlayerChangeControlTo; unit__ref : UnitRef)
  if !evt.isOwned || unit__ref.unit == null
    return
  init_magnetic_fuse(evt.playerEid, *unit__ref.unit)
  init_dive_depth(evt.playerEid)
  init_course_program(evt.playerEid, unit__ref.unit)

[es]
def shell_program_on_set_magnetic_fuse_sensitivity_preset_es(evt : CmdSetMagneticFuseSensitivityPreset;
                                                             var shell_program__magneticFuseSensitivityPreset : int&)
  shell_program__magneticFuseSensitivityPreset = evt.presetIdx

[es]
def shell_program_on_set_torpedo_dive_depth_es(evt : CmdSetTorpedoDiveDepth;
                                               is_local : bool;
                                               var shell_program__torpedoDiveDepth : float&)
  if get_difficulty_config().shipTorpedoAutoUpdateDepth
    return
  shell_program__torpedoDiveDepth = clamp(evt.depth, get_difficulty_config().shipTorpedoDepthMin, get_difficulty_config().shipTorpedoDepthMax)
  if is_local
    set_option_torpedo_dive_depth(shell_program__torpedoDiveDepth)

[es]
def shell_program_on_set_torpedo_course_program_es(evt : CmdSetTorpedoCourseProgram;
                                                   eid : EntityId;
                                                   var shell_program__torpedoGuidanceMode : int&;
                                                   var shell_program__torpedoCourseMode : int&;
                                                   var shell_program__torpedoCourseStartSection : float&;
                                                   var shell_program__torpedoCoursePathSection : float&;
                                                   var shell_program__torpedoCourseModesMask : int&;
                                                   var shell_program__torpedoCourseStartSectionMin : float&;
                                                   var shell_program__torpedoCourseStartSectionMax : float&;
                                                   var shell_program__torpedoCoursePathSectionMin : float&;
                                                   var shell_program__torpedoCoursePathSectionMax : float&)
  var unit : Unit const?
  let player = player_get_by_eid(eid)
  if player != null
    unit = getOwnedUnit(*player)
  let run = find_torpedo_course_run(unit)
  let isStartSectionChanged = evt.startSection != shell_program__torpedoCourseStartSection
  shell_program__torpedoGuidanceMode = evt.guidanceMode
  shell_program__torpedoCourseMode = evt.mode
  shell_program__torpedoCourseStartSection = evt.startSection
  shell_program__torpedoCoursePathSection = evt.pathSection
  update_course_program(run, isStartSectionChanged, shell_program__torpedoCourseMode,
    shell_program__torpedoCourseStartSection, shell_program__torpedoCoursePathSection,
    shell_program__torpedoCourseModesMask,
    shell_program__torpedoCourseStartSectionMin, shell_program__torpedoCourseStartSectionMax,
    shell_program__torpedoCoursePathSectionMin, shell_program__torpedoCoursePathSectionMax)
