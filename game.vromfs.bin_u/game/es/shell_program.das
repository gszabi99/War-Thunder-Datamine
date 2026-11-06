require ecs
require net
require math
require app
require Unit
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
