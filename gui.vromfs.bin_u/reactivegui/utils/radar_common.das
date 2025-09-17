module radar_common
require %rGui.utils.constants_common
require %rGui.utils.input_common
require DagorStdGuiRender
require RadarHud
require app
require Unit
require FlightModelWrap
require HeroManager
require math
require strings
require DagorMath
require darg
require DagorSystem

class Radar
  def static getModeName()
    let nameId = get_radar_hud_mode_name_id()
    let defaultStr = get_radar_hud_is_visible() ? (get_radar_hud_is_irst() ? "hud/irst" : "hud/radarEmitting") : ""
    return nameId >= 0 && nameId < radarModeNames |> length() ? radarModeNames[nameId] : defaultStr

  def static getModeNameLoc()
    return loc(Radar`getModeName())

  def static getCueHeights(var hmin : float &; var hmax : float &) : bool
    let hero = get_controlled_hero()
    if hero == null || hero.isDelayed
      return false
    let fmw = hero |> as_fmw()
    if fmw == null
      return false

    let scanElevationWidth = get_radar_hud_scan_elevation_max() - get_radar_hud_scan_elevation_min()
    let ownAltitude = hero.pos.y
    let distance = get_radar_hud_cue_distance() * get_radar_hud_distance_max() * 1000.
    let tangage = fmw.tangage * degToRad
    hmin = ownAltitude + distance * sin(get_radar_hud_scan_elevation_min() + tangage)
    hmax = ownAltitude + distance * sin(get_radar_hud_scan_elevation_max() + tangage)
    return true

  def static getImageForTarget(target : RadarTarget const const#;
      planeTargetPicture : Picture ?;
      helicopterTargetPicture : Picture ?;
      rocketTargetPicture : Picture ?) : Picture ? const
    if target.iconType == int(RadarTargetIconType.NONE)
      return null
    elif target.iconType == int(RadarTargetIconType.JET)
      return planeTargetPicture
    elif target.iconType == int(RadarTargetIconType.HELICOPTER)
      return helicopterTargetPicture
    elif target.iconType == int(RadarTargetIconType.ROCKET)
      return rocketTargetPicture
    else
      logerr("could not find picture for radar target of type {target.iconType}")
    return null

  def static changeScanPattern()
    var shortcut = "ID_SENSOR_SCAN_PATTERN_SWITCH"
    let hero = get_controlled_hero()
    if hero.isTank
      shortcut = "ID_SENSOR_SCAN_PATTERN_SWITCH_TANK"
    elif hero.isHelicopter
      shortcut = "ID_SENSOR_SCAN_PATTERN_SWITCH_HELICOPTER"
    toggle_shortcut(shortcut)

  def static changeRange()
    var shortcut = "ID_SENSOR_RANGE_SWITCH"
    let hero = get_controlled_hero()
    if hero.isTank
      shortcut = "ID_SENSOR_RANGE_SWITCH_TANK"
    elif hero.isHelicopter
      shortcut = "ID_SENSOR_RANGE_SWITCH_HELICOPTER"
    toggle_shortcut(shortcut)

  def static changeMode()
    var shortcut = "ID_SENSOR_MODE_SWITCH"
    let hero = get_controlled_hero()
    if hero.isTank
      shortcut = "ID_SENSOR_MODE_SWITCH_TANK"
    elif hero.isHelicopter
      shortcut = "ID_SENSOR_MODE_SWITCH_HELICOPTER"
    toggle_shortcut(shortcut)

  def static foreach_targets(blk : block<(target : RadarTarget const const#; i : int) : void>)
    get_radar_hud_targets() <| $(targets : array<RadarTarget> const#)
      for i, t in iter_range(targets), targets
        invoke(blk, t, i)

  def static foreach_targets(blk : block<(target : RadarTarget const const#) : void>)
    get_radar_hud_targets() <| $(targets : array<RadarTarget> const#)
      for t in targets
        invoke(blk, t)

  def static foreach_visible_target(blk : block<(target : RadarTarget const const#) : void>)
    Radar`foreach_targets() <| $(var target)
      if target.isVisible
        invoke(blk, target)

  def static foreach_own_weapon_with_target(own_weapon_index : int; own_weapon_target_index : int; blk : block<(ownWeapon : RadarTarget const const#; ownWeaponTarget : RadarTarget const const#) : void>)
    get_radar_hud_targets() <| $(targets : array<RadarTarget> const#)
      if (own_weapon_index < targets |> length() && own_weapon_target_index < targets |> length())
        invoke(blk, targets[own_weapon_index], targets[own_weapon_target_index])

  def static foreach_own_weapon_links(blk : block<(ownWeaponLink : OwnWeaponLink const const#) : void>)
    get_radar_hud_own_weapon_links() <| $(ownWeaponLinks : array<OwnWeaponLink> const#)
      for l in ownWeaponLinks
        invoke(blk, l)
