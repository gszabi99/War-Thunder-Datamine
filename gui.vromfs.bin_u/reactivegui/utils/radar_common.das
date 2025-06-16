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

  def static drawTargetAnnotation(var ctx : GuiContext &; target : RadarTarget const const#; fctx : StdGuiFontContext; pos : float2; drawBelow : bool;
      planeTargetPicture : Picture ?;
      helicopterTargetPicture : Picture ?;
      rocketTargetPicture : Picture ?)
    var picture = null
    if target.iconType == int(RadarTargetIconType.NONE)
      picture = null
    elif target.iconType == int(RadarTargetIconType.JET)
      picture = planeTargetPicture
    elif target.iconType == int(RadarTargetIconType.HELICOPTER)
      picture = helicopterTargetPicture
    elif target.iconType == int(RadarTargetIconType.ROCKET)
      picture = rocketTargetPicture
    else
      logerr("could not find picture for radar target of type {target.iconType}")

    let annotation = "{int(target.persistentIndex)}"
    let annotationBox = get_str_bbox(annotation, annotation |> length(), fctx)

    var offsetX = 0.0
    if picture == null
      offsetX = -annotationBox.width.x * 0.5

    let offsetY = drawBelow ? \
      - float(get_font_descent(fctx)) : \
      + annotationBox.width.y + float(get_font_ascent(fctx))
    let anchorPos = pos + float2(offsetX, offsetY)

    if picture != null
      let pictureSize = float2(annotationBox.width.y * 1.5)
      let pictureOffset = float2(0.0, -annotationBox.width.y * 0.5 + pictureSize.y * 0.5)
      let picturePos = anchorPos + pictureOffset - pictureSize
      let c = E3DCOLOR(0xFF37FF37)
      render_picture(ctx, picture, picturePos, pictureSize, c)
    ctx |> goto_xy(anchorPos.x, anchorPos.y)
    ctx |> draw_str_scaled(1.0, annotation, annotation |> length())