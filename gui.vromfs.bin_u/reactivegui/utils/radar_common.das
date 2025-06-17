module radar_common
require %rGui.utils.constants_common
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