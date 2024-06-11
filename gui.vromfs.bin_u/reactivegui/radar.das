require darg
require DagorStdGuiRender
require math
require DagorMath
require DagorSystem
require RadarHud
require strings
require app
require hud
require FlightModelWrap
require HeroManager
require Unit

let modeNames = [[string
  "hud/standby";
  "hud/search";
  "hud/acquisition";
  "hud/ACM";
  "hud/HMD";
  "hud/BST";
  "hud/VSL";
  "hud/track";

  "hud/PD VS standby";
  "hud/PD VS search";
  "hud/PD VS acquisition";
  "hud/PD VS ACM";
  "hud/PD VS BST";
  "hud/PD VS VSL";

  "hud/PD HDN VS standby";
  "hud/PD HDN VS search";
  "hud/PD HDN VS acquisition";
  "hud/PD HDN VS ACM";
  "hud/PD HDN VS BST";
  "hud/PD HDN VS VSL";

  "hud/PD standby";
  "hud/PD search";
  "hud/PD acquisition";
  "hud/PD ACM";
  "hud/PD HMD";
  "hud/PD BST";
  "hud/PD VSL";
  "hud/PD track";

  "hud/PD HDN standby";
  "hud/PD HDN search";
  "hud/PD HDN acquisition";
  "hud/PD HDN ACM";
  "hud/PD HDN BST";
  "hud/PD HDN VSL";
  "hud/PD HDN track";

  "hud/GTM standby";
  "hud/GTM search";
  "hud/GTM acquisition";
  "hud/GTM ACM";
  "hud/GTM BST";
  "hud/GTM VSL";
  "hud/GTM track";


  "hud/LD standby";
  "hud/LD search";
  "hud/LD acquisition";
  "hud/LD ACM";
  "hud/LD track";

  "hud/MTI standby";
  "hud/MTI search";
  "hud/MTI acquisition";
  "hud/MTI ACM";
  "hud/MTI track";

  "hud/TWS standby";
  "hud/TWS search";
  "hud/TWS acquisition";
  "hud/TWS ACM";
  "hud/TWS BST";
  "hud/TWS VSL";
  "hud/TWS track";

  "hud/TWS HDN standby";
  "hud/TWS HDN search";
  "hud/TWS HDN acquisition";
  "hud/TWS HDN ACM";
  "hud/TWS HDN BST";
  "hud/TWS HDN VSL";
  "hud/TWS HDN track";

  "hud/TWS GTM standby";
  "hud/TWS GTM search";
  "hud/TWS GTM acquisition";
  "hud/TWS GTM ACM";
  "hud/TWS GTM BST";
  "hud/TWS GTM VSL";
  "hud/TWS GTM track";

  "hud/IRST standby";
  "hud/IRST search";
  "hud/IRST acquisition";
  "hud/IRST ACM";
  "hud/IRST HMD";
  "hud/IRST track";

  "hud/air_search";
  "hud/ground_search";

  "hud/auto acquisition";
  "hud/auto ACM";
  "hud/auto HMD";
  "hud/track memory";
]]

let areaBackgroundColor = E3DCOLOR(Color4(float4(0., 0., 0., 0.5)))
let transparentColor = E3DCOLOR(Color4(float4(0, 0, 0, 0)))
let elevMaxScreenRelSize = 0.25
let elevMaxInv = 1.0 / 1.2

let angularGateWidthMultMinPolar = 4.
let angularGateWidthMultMaxPolar = 6.
let angularGateWidthMultMinDistanceRelPolar = 0.06
let angularGateWidthMultMaxDistanceRelPolar = 0.33
let angularGateBeamWidthMin = 0.0348
let distanceGateWidthRelMin = 0.05
let distanceGateWidthMult = 1.
let iffDistRelMult = 0.5
let attackDistRelMult = 1.0
let attackHeightRel = 0.02
let angularGateWidthMultSquare = 4.

let metrToThsFeet = 0.00328084

struct CanvasParams
  color : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  fontId : int = -1
  fontSize : int = 20
  hasTxtBlock : bool = false
  hideBack : bool = false
  overrideMode : int = -1
  enableByMfd : bool = false
  lineWidth : float = 1.
  lineColor : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  modeColor : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  verAngleColor : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  horAngleColor : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  scaleColor : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  targetColor : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  hideBeam : bool = false
  hideLaunchZone : bool = false
  hideScale : bool = false
  hideHorAngle : bool = false
  hideVerAngle : bool = false
  targetFormType : int = 0
  hasAviaHorizont : bool = false
  backgroundColor : E3DCOLOR = E3DCOLOR(0xFF000000)
  beamShape : int = 0
  netRowCnt : int = 0
  netColor : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  hideWeaponIndication : bool = false
  showScanAzimuth : bool = false
  cueHeights : bool = false

def rad_to_deg(rad : float)
  return rad * 180. / PI

def deg_to_rad(rad : float)
  return rad * PI / 180.

def calc_angular_gate_width_polar(distance_rel : float; azimuth_half_width)
  if azimuth_half_width > 0.17
    return 2.
  let blend = min((distance_rel - angularGateWidthMultMinDistanceRelPolar) / (angularGateWidthMultMaxDistanceRelPolar - angularGateWidthMultMinDistanceRelPolar), 1.)
  return angularGateWidthMultMinPolar * blend + angularGateWidthMultMaxPolar * (1. - blend)

def get_font_fx_color(color : E3DCOLOR)
  return is_dark_color(color) ? E3DCOLOR(0x78FFFFFF) : E3DCOLOR(0x78000000)

def get_font_fx_factor(color : E3DCOLOR; var ctx : GuiContext&)
  let fontOutlineFxFactor = max(70., ctx |> hdpx(90.))
  return int(is_dark_color(color) ? fontOutlineFxFactor * 0.15 : fontOutlineFxFactor)

[export]
def setup_radar_data(props : Properties&; var storage : CanvasParams&)
  storage.color = fade_color(props |> getColor("color", E3DCOLOR(0xFFFFFFFF)), 255)
  storage.fontId = props |> getFontId()
  storage.fontSize = props |> getInt("fontSize", 20)
  storage.hasTxtBlock = props |> getBool("hasTxtBlock", false)
  storage.hideBack = props |> getBool("hideBackground", false)
  storage.enableByMfd = props |> getBool("enableByMfd", false)
  storage.overrideMode = props |> getInt("mode", -1)
  storage.lineWidth = props |> getFloat("lineWidth", 1.)
  storage.lineColor = props |> getColor("lineColor", storage.color)
  storage.modeColor = props |> getColor("modeColor", storage.color)
  storage.verAngleColor = props |> getColor("verAngleColor", storage.color)
  storage.horAngleColor = props |> getColor("horAngleColor", storage.color)
  storage.scaleColor = props |> getColor("scaleColor", storage.color)
  storage.targetColor = props |> getColor("targetColor", storage.color)
  storage.hideBeam = props |> getBool("hideBeam", false)
  storage.hideLaunchZone = props |> getBool("hideLaunchZone", false)
  storage.hideScale = props |> getBool("hideScale", false)
  storage.hideHorAngle = props |> getBool("hideHorAngle", false)
  storage.hideVerAngle = props |> getBool("hideVerAngle", false)
  storage.targetFormType = props |> getInt("targetFormType", 0)
  storage.hasAviaHorizont = props |> getBool("hasAviaHorizont", false)
  storage.backgroundColor = props |> getColor("backgroundColor", E3DCOLOR(0xFF000000))
  storage.beamShape = props |> getInt("beamShape", 0)
  storage.netRowCnt = props |> getInt("netRowCnt", 0)
  storage.netColor = props |> getColor("netColor", storage.color)
  storage.hideWeaponIndication = props |> getBool("hideWeaponIndication", false)
  storage.showScanAzimuth = props |> getBool("showScanAzimuth", false)
  storage.cueHeights = props |> getBool("cueHeights", false)

[export]
def draw_radar_hud(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  if data.enableByMfd ? !get_radar_hud_mfd_radar_enabled() : !get_radar_hud_visible()
    return
  let radarVisible = get_radar_hud_is_visible() || get_radar_hud_is_visible2()
  if !radarVisible && get_game_params().collapsedIconForRadarTws
    return

  if data.enableByMfd
    mfd_radar_background(ctx, rdata, data)

  if get_radar_hud_is_b_scope_visible()
    let mode = data.overrideMode >= 0 ? data.overrideMode : int(get_radar_hud_view_mode())
    var pos = get_radar_hud_is_c_scope_visible() ? rdata.pos - float2(0., rdata.size.y * 0.42) : rdata.pos
    if data.enableByMfd
      pos += get_radar_hud_mfd_radar_offset()
    let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
    if mode == int(RadarViewMode B_SCOPE_ROUND)
      if azimuthRange > PI + 0.035
        b_scope(ctx, rdata, data)
      else
        b_scope_half(ctx, rdata, data, pos)
    elif mode == int(RadarViewMode B_SCOPE_SQUARE)
      if azimuthRange > PI + 0.035
        b_scope(ctx, rdata, data)
      else
        b_scope_square(ctx, rdata, data, pos)

  if get_radar_hud_is_c_scope_visible()
    let size = float2(rdata.size.x, rdata.size.y * 0.42)
    let pos = rdata.pos + float2(0., rdata.size.y * 0.58)
    c_scope(ctx, data, pos, size)

def mfd_radar_background(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&)
  let scale = get_radar_hud_mfd_radar_scale() > 0. ? get_radar_hud_mfd_radar_scale() : 1.
  let size = rdata.size / scale
  let pos = float2(rdata.pos.x - (1. - scale) * 0.5 * size.x, rdata.pos.y - (1. - scale) * 0.5 * size.y)
  ctx |> set_color(data.backgroundColor)
  ctx |> render_box(pos.x, pos.y, pos.x + size.x, pos.y + size.y)

def b_scope_half(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&; pos : float2)
  let bottomOffset = b_scope_half_circle_markers(ctx, data, pos, rdata.size, data.fontSize/*hudFontHgt*/)
  let gridPos = pos - float2(0., bottomOffset)

  b_scope_half_top_markers(ctx, data, gridPos, rdata.size, data.fontSize/*hudFontHgt*/)
  if !data.hideBack
    b_scope_half_background(ctx, data, gridPos, rdata.size)

  let rb = gridPos + rdata.size
  let origin = float2(gridPos.x + rdata.size.x * 0.5, rb.y)
  let half_width = get_radar_hud_target_azimuth_width()
  if half_width > 0. && !data.hideBack
    b_scope_sector(ctx, data, origin, rdata.size, half_width, 0.5)

  let reflectionPos = gridPos + float2(0., rdata.size.y * 0.5)
  render_ground_reflection(ctx, rdata.size, reflectionPos, is_color_or_white(data.color), int2(16, 8), false)
  if get_radar_hud_is_visible() && !data.hideBeam
    if get_radar_hud_is_emitting()
      let dist = get_radar_hud_distance()
      let halfVal = get_radar_hud_azimuth_half_width()
      let isSectorView = dist == 1. && halfVal > 0.
      b_scope_azimuth(ctx, data, origin, rdata.size, isSectorView, get_radar_hud_azimuth(), halfVal, dist, 1.2 * data.lineWidth)
      b_scope_elevation(ctx, data, gridPos, rdata.size, get_radar_hud_elevation_min(), get_radar_hud_elevation_max(), get_radar_hud_elevation(), get_radar_hud_azimuth_min(),
       get_radar_hud_scan_elevation_min(), get_radar_hud_scan_elevation_max())

  if get_radar_hud_is_visible2() && !data.hideBeam
    if get_radar_hud_is_emitting2()
      let dist = get_radar_hud_distance2()
      let halfVal = get_radar_hud_azimuth_half_width2()
      let isSectorView = dist == 1. && halfVal > 0.
      b_scope_azimuth(ctx, data, origin, rdata.size, isSectorView, get_radar_hud_azimuth2(), halfVal, dist, 1.2 * data.lineWidth)
      b_scope_elevation(ctx, data, gridPos, rdata.size, get_radar_hud_elevation_min(), get_radar_hud_elevation_max(), get_radar_hud_elevation2(), get_radar_hud_azimuth_min(),
       get_radar_hud_scan_elevation_min(), get_radar_hud_scan_elevation_max())

  if !data.hideLaunchZone
    b_scope_half_launch_range(ctx, data, gridPos, rdata.size)
  polar_radar_targets(ctx, data, origin, rdata.size)
  b_scope_half_cue(ctx, data, gridPos, rdata.size)

def b_scope_half_background(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  let rb = pos + size
  let center = (pos + rb) * 0.5
  let radius = size * 0.5
  let anglesExternal = float2(get_radar_hud_azimuth_min() - PI * 0.5, get_radar_hud_azimuth_max() - PI * 0.5)
  let anglesInternal = float2(get_radar_hud_scan_azimuth_min() - PI * 0.5, get_radar_hud_scan_azimuth_max() - PI * 0.5)
  let origin = float2(center.x, rb.y)

  let color = is_color_or_white(data.lineColor)

  ctx |> render_sector_aa(origin, radius, anglesExternal, data.lineWidth, data.lineColor, areaBackgroundColor)
  let lcoord <- to_array_move([[float2[2] origin; origin + float2(cos(anglesExternal.x), sin(anglesExternal.x)) * radius]])
  ctx |> render_line_aa(lcoord, false, data.lineWidth, float2(0, 0), data.lineColor)
  let rcoord <- to_array_move([[float2[2] origin; origin + float2(cos(anglesExternal.y), sin(anglesExternal.y)) * radius]])
  ctx |> render_line_aa(rcoord, false, data.lineWidth, float2(0, 0), data.lineColor)

  let anglesInternalGrid = anglesInternal.y > anglesInternal.x ? anglesInternal : anglesExternal
  let distMinRel = max(0., get_radar_hud_distance_min() / max(get_radar_hud_distance_max(), 1.0))
  if get_radar_hud_has_distance_scale()
    let distanceMinR = 50.0 * distMinRel
    var dist = 12.5
    while dist < 37.5 + 1.0
      if dist > distanceMinR
        ctx |> render_sector_aa(origin, dist * 0.01 * size, anglesInternalGrid, data.lineWidth, color, E3DCOLOR(0u))
      dist += 12.5
    ctx |> render_sector_aa(origin, size * distMinRel * 0.5, anglesInternalGrid, data.lineWidth, color, E3DCOLOR(0u))

  let angleStep = PI * 15.0 / 180.0
  for i in range(int(anglesInternalGrid.x / angleStep), int(anglesInternalGrid.y / angleStep))
    let angle = float(i) * angleStep
    let coord <- to_array_move([[float2[2] origin + float2(cos(angle) * size.x, sin(angle) * size.y) * 0.5 * distMinRel;
     origin + float2(cos(angle) * size.x, sin(angle) * size.y) * 0.5]])
    ctx |> render_line_aa(coord, false, 1.2 * data.lineWidth, float2(0, 0), color)

  let rscoord <- to_array_move([[float2[2] origin; origin + float2(cos(anglesInternal.y) * size.x, sin(anglesInternal.y) * size.y) * 0.5]])
  ctx |> render_line_aa(rscoord, false, 2.4 * data.lineWidth, float2(0, 0), color)
  let lscoord <- to_array_move([[float2[2] origin; origin + float2(cos(anglesInternal.x) * size.x, sin(anglesInternal.x) * size.y) * 0.5]])
  ctx |> render_line_aa(lscoord, false, 2.4 * data.lineWidth, float2(0, 0), color)

def b_scope_sector(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2; half_width : float; value : float)
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  let angle = get_radar_hud_azimuth_min() + azimuthRange * value - PI * 0.5

  var color = float4(Color4(data.color))//isColorOrWhite(color) ??
  color *= 0.2
  ctx |> render_sector_aa(pos, size * 0.5 * get_radar_hud_target_distance(), float2(angle - half_width, angle + half_width), 1.2,
   E3DCOLOR(Color4(color)), E3DCOLOR(Color4(color)))

def b_scope_azimuth(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2; is_sector_view : bool;
                    value : float; half_width : float; dist : float; line_width : float)
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  let angle = get_radar_hud_azimuth_min() + azimuthRange * value - PI * 0.5

  if is_sector_view
    var color = float4(Color4(is_color_or_white(data.lineColor)))
    color *= 0.4
    let radius = float2(size.x * 0.5, size.y * 0.5)
    ctx |> render_sector_aa(pos, radius, float2(angle - half_width, angle + half_width), 1., E3DCOLOR(Color4(color)), E3DCOLOR(Color4(color)))
  else
    let len = min(dist >= 0. ? dist : 1., 1.)
    let coord <- to_array_move([[float2[2] pos; pos + float2(cos(angle), sin(angle)) * size.x * 0.5 * len]])
    let color = is_color_or_white(data.targetColor)
    if dist >= 0.
      ctx |> render_line_dashed(pos, coord[1], ctx |> hdpx(10.), ctx |> hdpx(5.), ctx |> hdpx(line_width), color)
    else
      ctx |> render_line_aa(coord, false, ctx |> hdpx(line_width), float2(0, 0), color)

def b_scope_half_top_markers(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2; font_size : int)
  if !get_radar_hud_is_visible() && !get_radar_hud_is_visible2()
    return

  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, font_size)

  let rb = pos + size
  let center = (pos + rb) * 0.5

  let nameId = get_radar_hud_mode_name_id()
  let defaultStr = get_radar_hud_is_visible() ? (get_radar_hud_is_irst() ? "hud/irst" : "hud/radarEmitting") : ""
  let modeName = loc(nameId >= 0 && nameId < modeNames |> length() ? modeNames[nameId] : defaultStr)
  let strBox = get_str_bbox(modeName, modeName |> length(), fctx)
  ctx |> goto_xy(center.x - strBox.width.x, center.y - 5.)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(font_size);
  ctx |> set_color(data.modeColor)
  ctx |> set_draw_str_attr(FontFxType FFT_GLOW, 0, 0, get_font_fx_color(data.modeColor), get_font_fx_factor(data.modeColor, ctx))
  ctx |> draw_str_scaled(1.0, modeName, modeName |> length())

  let name2Id = get_radar_hud_mode_name2_id()
  let default2Str = get_radar_hud_is_visible2() ? ("hud/radarEmitting") : ""
  let modeName2 = loc(name2Id >= 0 && name2Id < modeNames |> length() ? modeNames[name2Id] : default2Str)
  ctx |> goto_xy(center.x + 5., center.y - 5.)
  ctx |> draw_str_scaled(1.0, modeName2, modeName2 |> length())

  if get_radar_hud_noise_signal_visible() && get_radar_hud_is_visible() && get_radar_hud_noise_signal() > 0.5
    noise_signal(ctx, data, center - float2(strBox.width.x + size.x * 0.06, size.y * 0.07), float2(size.x * 0.06, size.y * 0.07),
     get_radar_hud_noise_signal())
  if get_radar_hud_noise_signal_visible() && get_radar_hud_is_visible2() && get_radar_hud_noise_signal2() > 0.5
    noise_signal(ctx, data, center, float2(size.x * 0.06, size.y * 0.07), get_radar_hud_noise_signal2())


def b_scope_elevation(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2;
                      elev_min : float; elev_max : float; elev_rel : float; azimuth_min : float;
                      elev_scan_min : float; elev_scan_max : float)
  let rb = pos + size
  let center = (pos + rb) * 0.5
  let origin = float2(center.x, rb.y)
  let sz = size * 0.5

  let elevationMin = elev_min * elevMaxInv * elevMaxScreenRelSize + 0.5
  let elevationMax = elev_max * elevMaxInv * elevMaxScreenRelSize + 0.5
  let elevation = elevationMin * (1.0 - elev_rel) + elevationMax * elev_rel
  let markLen = 0.06
  let markLenShort = 0.04
  let cosa = cos(azimuth_min)
  let sina = sin(azimuth_min)
  var color = float4(Color4(is_color_or_white(data.lineColor)))
  color *= 0.42

  let e3dColor = E3DCOLOR(Color4(color))
  ctx |> set_color(e3dColor)
  ctx |> draw_line(origin.x + elevationMin * sina * sz.x, origin.y - elevationMin * cosa * sz.y,
   origin.x + (elevationMin * sina - markLen * cosa) * sz.x, origin.y - (elevationMin * cosa + markLen * sina) * sz.y, ctx |> hdpx(4. * data.lineWidth))
  ctx |> draw_line(origin.x + 0.5 * sina * sz.x, origin.y - 0.5 * cosa * sz.y,
   origin.x + (0.5 * sina - markLenShort * cosa) * sz.x, origin.y - (0.5 * cosa + markLenShort * sina) * sz.y, ctx |> hdpx(4. * data.lineWidth))
  ctx |> draw_line(origin.x + elevationMax * sina * sz.x, origin.y - elevationMax * cosa * sz.y,
   origin.x + (elevationMax * sina - markLen * cosa) * sz.x, origin.y - (elevationMax * cosa + markLen * sina) * sz.y, ctx |> hdpx(4. * data.lineWidth))
  ctx |> draw_line(origin.x + elevation * sina * sz.x, origin.y - elevation * cosa * sz.y,
   origin.x + (elevation * sina - markLenShort * cosa) * sz.x, origin.y - (elevation * cosa + markLenShort * sina) * sz.y, ctx |> hdpx(4. * data.lineWidth))

  if elev_scan_max > elev_scan_min
    let elevationScanMin = elev_scan_min * elevMaxInv * elevMaxScreenRelSize + 0.5
    let elevationScanMax = elev_scan_max * elevMaxInv * elevMaxScreenRelSize + 0.5
    ctx |> draw_line(origin.x + elevationScanMin * sina * sz.x, origin.y - elevationScanMin * cosa * sz.y,
     origin.x + (elevationScanMin * sina - markLen * cosa) * sz.x, origin.y - (elevationScanMin * cosa + markLen * sina) * sz.y, ctx |> hdpx(4. * data.lineWidth))
    ctx |> draw_line(origin.x + elevationScanMax * sina * sz.x, origin.y - elevationScanMax * cosa * sz.y,
     origin.x + (elevationScanMax * sina - markLen * cosa) * sz.x, origin.y - (elevationScanMax * cosa + markLen * sina) * sz.y, ctx |> hdpx(4. * data.lineWidth))

def foreach_targets(blk : block<(target : RadarTarget const const#; i : int) : void>)
  get_radar_hud_targets() <| $(targets : array<RadarTarget> const#)
    for i, t in iter_range(targets), targets
      invoke(blk, t, i)

def foreach_targets(blk : block<(target : RadarTarget const const#) : void>)
  get_radar_hud_targets() <| $(targets : array<RadarTarget> const#)
    for t in targets
      invoke(blk, t)

def for_own_weapon_with_target(own_weapon_index : int; own_weapon_target_index : int; blk : block<(ownWeapon : RadarTarget const const#; ownWeaponTarget : RadarTarget const const#) : void>)
  get_radar_hud_targets() <| $(targets : array<RadarTarget> const#)
    if (own_weapon_index < targets |> length() && own_weapon_target_index < targets |> length())
      invoke(blk, targets[own_weapon_index], targets[own_weapon_target_index])

def foreach_own_weapon_links(blk : block<(ownWeaponLink : OwnWeaponLink const const#) : void>)
  get_radar_hud_own_weapon_links() <| $(ownWeaponLinks : array<OwnWeaponLink> const#)
    for l in ownWeaponLinks
      invoke(blk, l)

def polar_radar_targets(var ctx : GuiContext&; data : CanvasParams&; origin : float2; size : float2)
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  let radius = float2(size.x * 0.5, size.y * 0.5)

  foreach_targets() <| $(var target)
    var distanceRel = 0.9
    var radialWidthRel = 0.05
    if get_radar_hud_has_distance_scale() && target.distanceRel >= 0.
      distanceRel = target.distanceRel
      radialWidthRel = max(target.distanceWidthRel, 0.05)

    var angle = -PI * 0.5
    var angularWidth = azimuthRange
    if get_radar_hud_has_azimuth_scale()
      angle = get_radar_hud_azimuth_min() + azimuthRange * target.azimuthRel - PI * 0.5
      angularWidth = azimuthRange * target.azimuthWidthRel

    let sina = sin(angle)
    let cosa = cos(angle)
    let pos = origin + float2(cosa * distanceRel * radius.x, sina * distanceRel * radius.y)

    var color = float4(Color4(is_color_or_white(data.targetColor)))
    let signalRel = target.signalRel < 0.01 ? 0. : cvt(target.signalRel, 0.05, 1., 0.3, 1.)
    color *= (1. - target.ageRel) * signalRel
    let e3dColor = E3DCOLOR(Color4(color))

    if target.targetType == int(RadarTargetType TYPE_TARGET)
      let angleLeft = max(angle - 0.5 * angularWidth, get_radar_hud_azimuth_min() - PI * 0.5)
      let angleRight = min(angle + 0.5 * angularWidth, get_radar_hud_azimuth_max() - PI * 0.5)
      if target.isSelected && get_radar_hud_has_azimuth_scale()
        if target.losSpeed < 30000.
          ctx |> render_ellipse_aa(pos, radius * 0.04, ctx |> hdpx(2. * data.lineWidth), e3dColor, transparentColor)
          let losPos = origin + float2((cosa * distanceRel + (cosa * target.losSpeed + sina * target.losHorSpeed) * 0.0002) * radius.x,
           (sina * distanceRel + (sina * target.losSpeed - cosa * target.losHorSpeed) * 0.0002) * radius.y)
          ctx |> set_color(e3dColor)
          ctx |> draw_line(pos, losPos, ctx |> hdpx(2. * data.lineWidth))
        else
          ctx |> render_ellipse_aa(pos, radius * 0.04, ctx |> hdpx(2.), e3dColor, transparentColor)
      else
        ctx |> render_sector_aa(origin, radius * distanceRel, float2(angleLeft, angleRight), 100. * radialWidthRel, e3dColor, transparentColor)

      if target.isDetected
        let azimuthHalfWidth = get_radar_hud_is_visible2() ? get_radar_hud_azimuth_half_width2() : get_radar_hud_azimuth_half_width()
        let angularGateWidthMult = calc_angular_gate_width_polar(distanceRel, azimuthHalfWidth)
        let angularGateWidth = angularGateWidthMult * 2. * max(azimuthHalfWidth, angularGateBeamWidthMin)
        var angleGateLeft = angle - 0.5 * angularGateWidth
        var angleGateRight = angle + 0.5 * angularGateWidth
        if azimuthRange < PI
          angleGateLeft = max(angleGateLeft, get_radar_hud_azimuth_min() - PI * 0.5)
          angleGateRight = min(angleGateRight, get_radar_hud_azimuth_max() - PI * 0.5)
        let distanceGateHalfWidthRel = 0.5 * max(get_radar_hud_distance_gate_width_rel(), distanceGateWidthRelMin) * distanceGateWidthMult
        let radiusInner = distanceRel - distanceGateHalfWidthRel
        let radiusOuter = distanceRel + distanceGateHalfWidthRel
        let lcoord <- to_array_move([[float2[2] origin + float2(cos(angleGateLeft) * radiusInner * radius.x, sin(angleGateLeft) * radiusInner * radius.y);
          origin + float2(cos(angleGateLeft) * radiusOuter * radius.x, sin(angleGateLeft) * radiusOuter * radius.y)]])
        ctx |> render_line_aa(lcoord, false, ctx |> hdpx(3. * data.lineWidth), float2(0, 0), e3dColor)
        let rcoord <- to_array_move([[float2[2] origin + float2(cos(angleGateRight) * radiusInner * radius.x, sin(angleGateRight) * radiusInner * radius.y);
          origin + float2(cos(angleGateRight) * radiusOuter * radius.x, sin(angleGateRight) * radiusOuter * radius.y)]])
        ctx |> render_line_aa(rcoord, false, ctx |> hdpx(3. * data.lineWidth), float2(0, 0), e3dColor)

      if !target.isEnemy
        let iffDistReal = get_radar_hud_velocity_search() ? 0.9 : distanceRel + (0.5 + iffDistRelMult) * radialWidthRel
        ctx |> render_sector_aa(origin, radius * iffDistReal, float2(angleLeft, angleRight), ctx |> hdpx(3. * data.lineWidth), e3dColor, transparentColor)
        //animation targetSelectedAnim ???

      if target.isAttacked
        let attackMarkDistRel = get_radar_hud_velocity_search() ? 0.9 : distanceRel + (0.5 + attackDistRelMult) * radialWidthRel
        let coord <- to_array_move([[float2[2] origin + radius * attackMarkDistRel * float2(cos(angle), sin(angle));
         origin + (radius * (attackMarkDistRel + attackHeightRel)) * float2(cos(angle), sin(angle))]])
        ctx |> render_line_aa(coord, false, ctx |> hdpx(3. * data.lineWidth), float2(0, 0), e3dColor)

    elif target.targetType == int(RadarTargetType TYPE_OWN_WEAPON) && !data.hideWeaponIndication
      if get_radar_hud_has_azimuth_scale()
        ctx |> render_ellipse_aa(pos, radius * 0.01, ctx |> hdpx(2.), e3dColor, transparentColor)

    elif target.targetType == int(RadarTargetType TYPE_OWN_WEAPON_TARGET) && !data.hideWeaponIndication
      if get_radar_hud_has_azimuth_scale() && !target.isAttacked
        ctx |> render_ellipse_aa(pos, radius * 0.06, ctx |> hdpx(2.), e3dColor, transparentColor)

    if get_radar_hud_has_azimuth_scale() && get_radar_hud_has_distance_scale() && !data.hideWeaponIndication
      foreach_own_weapon_links() <| $(var ownWeaponLink)
        for_own_weapon_with_target(ownWeaponLink.ownWeaponIndex, ownWeaponLink.ownWeaponTargetIndex) <| $(var ownWeapon; ownWeaponTarget)
          let ownWeaponAngle = get_radar_hud_azimuth_min() + azimuthRange * ownWeapon.azimuthRel - PI * 0.5
          let ownWeaponSina = sin(ownWeaponAngle)
          let ownWeaponCosa = cos(ownWeaponAngle)
          let ownWeaponPos = origin + float2(ownWeaponCosa * ownWeapon.distanceRel * radius.x, ownWeaponSina * ownWeapon.distanceRel * radius.y)

          let ownWeaponTargetAngle = get_radar_hud_azimuth_min() + azimuthRange * ownWeaponTarget.azimuthRel - PI * 0.5
          let ownWeaponTargetSina = sin(ownWeaponTargetAngle)
          let ownWeaponTargetCosa = cos(ownWeaponTargetAngle)
          let ownWeaponTargetPos = origin + float2(ownWeaponTargetCosa * ownWeaponTarget.distanceRel * radius.x, ownWeaponTargetSina * ownWeaponTarget.distanceRel * radius.y)

          ctx |> set_color(e3dColor)
          if ownWeaponLink.lockDistanceToDistance < 1.0
            let direction = float2(ownWeaponTargetPos[0] - ownWeaponPos[0], ownWeaponTargetPos[1] - ownWeaponPos[1])
            let lockPos = float2(ownWeaponPos[0] + direction[0] * ownWeaponLink.lockDistanceToDistance, ownWeaponPos[1] + direction[1] * ownWeaponLink.lockDistanceToDistance)
            ctx |> draw_line(ownWeaponPos, lockPos, ctx |> hdpx(2.))
            ctx |> render_line_dashed(lockPos, ownWeaponTargetPos, ctx |> hdpx(10.), ctx |> hdpx(5.), ctx |> hdpx(2.), e3dColor)
          else
            ctx |> draw_line(ownWeaponPos, ownWeaponTargetPos, ctx |> hdpx(2.))


def b_scope_half_circle_markers(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2; font_size : int)
  if !get_radar_hud_is_visible() && !get_radar_hud_is_visible2()
    return 0.

  var offset = 0.
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, font_size)
  let lt = pos
  let rb = pos + size
  let center = (lt + rb) * 0.5
  let origin = float2(center.x, rb.y)

  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(font_size)

  if get_radar_hud_has_azimuth_scale() && get_radar_hud_scan_azimuth_max() > get_radar_hud_scan_azimuth_min() && !data.hideHorAngle
    ctx |> set_color(data.horAngleColor)
    ctx |> set_draw_str_attr(FontFxType FFT_GLOW, 0, 0, get_font_fx_color(data.horAngleColor), get_font_fx_factor(data.horAngleColor, ctx))
    let azText = format("%.f", floor(rad_to_deg(get_radar_hud_scan_azimuth_max() - get_radar_hud_scan_azimuth_min()) + 0.5))
    let elText = format("%.f", floor(rad_to_deg(get_radar_hud_scan_elevation_max() - get_radar_hud_scan_elevation_min()) + 0.5))
    let deg = loc("measureUnits/deg")
    let text = "{azText}{deg}x{elText}{deg}" + (get_radar_hud_scan_patterns_max() > 1 ? "*" : " ")
    let strBox = get_str_bbox(text, text |> length(), fctx)
    ctx |> goto_xy((rb.x + lt.x - strBox.width.x) * 0.5, rb.y)
    ctx |> draw_str_scaled(1.0, text, text |> length())
    offset = rb.y * 0.02 + strBox.width.y

  if get_radar_hud_has_distance_scale() && !data.hideScale
    ctx |> set_color(data.scaleColor)
    ctx |> set_draw_str_attr(FontFxType FFT_GLOW, 0, 0, get_font_fx_color(data.scaleColor), get_font_fx_factor(data.scaleColor, ctx))
    let valText = (get_radar_hud_velocity_search() ? get_measure_units_text(MeasureUnitsTypes MEASURE_UNIT_SPEED, get_radar_hud_distance_max(), true, 1.) :
     get_measure_units_text(MeasureUnitsTypes MEASURE_UNIT_DIST, get_radar_hud_distance_max() * 1000., true, 1.))
    let text = valText + (get_radar_hud_distance_scale_max() > 1 ? "*" : " ")
    let strBox = get_str_bbox(text, text |> length(), fctx)
    ctx |> goto_xy(rb.x - strBox.width.x, rb.y - offset + strBox.width.y)
    ctx |> draw_str_scaled(1.0, text, text |> length())

  if get_radar_hud_has_azimuth_scale() && !data.hideVerAngle
    ctx |> set_color(data.verAngleColor)
    ctx |> set_draw_str_attr(FontFxType FFT_GLOW, 0, 0, get_font_fx_color(data.scaleColor), get_font_fx_factor(data.scaleColor, ctx))
    let textMin = format("%.f", rad_to_deg(get_radar_hud_elevation_min())) + loc("measureUnits/deg")
    let strBoxMin = get_str_bbox(textMin, textMin |> length(), fctx)
    let azimuthMin = get_radar_hud_azimuth_min()
    let elevationScanMin = get_radar_hud_elevation_min() * elevMaxInv * elevMaxScreenRelSize + 0.5
    let posX = origin.x + elevationScanMin * sin(azimuthMin) * size.x * 0.5 - strBoxMin.width.x
    let posY = origin.y - (elevationScanMin * cos(azimuthMin) - 0.06) * size.y * 0.5 + strBoxMin.width.y - offset
    ctx |> goto_xy(posX, posY)
    ctx |> draw_str_scaled(1.0, textMin, textMin |> length())

    let textMax = format("%.f", rad_to_deg(get_radar_hud_elevation_max())) + loc("measureUnits/deg")
    let strBoxMax = get_str_bbox(textMax, textMax |> length(), fctx)
    let elevationScanMax = get_radar_hud_elevation_max() * elevMaxInv * elevMaxScreenRelSize + 0.5
    let posX2 = origin.x + elevationScanMax * sin(azimuthMin) * size.x * 0.5 - strBoxMax.width.x
    let posY2 = origin.y - (elevationScanMax * cos(azimuthMin) - 0.06) * size.y * 0.5 + strBoxMax.width.y - offset
    ctx |> goto_xy(posX2, posY2)
    ctx |> draw_str_scaled(1.0, textMax, textMax |> length())
  return offset

def b_scope_half_launch_range(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  if !get_radar_hud_aam_launch_zone_visible() || !get_radar_hud_has_distance_scale()
    return

  let rb = pos + size
  let center = (pos + rb) * 0.5
  let origin = float2(center.x, rb.y)
  let angles = float2(get_radar_hud_azimuth_min() - PI * 0.5, get_radar_hud_azimuth_max() - PI * 0.5)
  var color = float4(Color4(is_color_or_white(data.lineColor)))
  color *= 0.42
  let e3dColor = E3DCOLOR(Color4(color))
  let distMin = get_radar_hud_aam_launch_zone_dist_min()
  if distMin <= 1.
    ctx |> render_sector_aa(origin, size * 0.5 * distMin, angles, ctx |> hdpx(4. * data.lineWidth), e3dColor, transparentColor)
  let distMax = get_radar_hud_aam_launch_zone_dist_max()
  if distMax <= 1.
    ctx |> render_sector_aa(origin, size * 0.5 * distMax, angles, ctx |> hdpx(4. * data.lineWidth), e3dColor, transparentColor)
  let dgftMax = get_radar_hud_aam_launch_zone_dist_dgft_max()
  if dgftMax > 0. && dgftMax <= 1.
    ctx |> render_sector_aa(origin, size * 0.5 * dgftMax, angles, ctx |> hdpx(4. * data.lineWidth), e3dColor, transparentColor)

def noise_signal(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2; val : float)
  let quadSize = float2(size.x, size.y * 0.16)
  for i in range(0, 4)
    let p = pos + float2(0., float(i) * size.y * 0.25)
    let rb = p + quadSize
    let tc = float2(0., 0.)
    var color = float4(Color4(data.color))//isColorOrWhite(color) ??
    color *= val > float(3 - i) ? 1. : 0.21
    let e3dColor = E3DCOLOR(Color4(color))
    ctx |> set_color(e3dColor)
    ctx |> render_rect(p.x, p.y, rb.x, rb.y, tc, tc, tc)
  let p = pos - float2(size.x * 1.2, -size.y * 0.75)
  let rb = p + float2(size.x, size.y * 0.32)
  let tc = float2(0., 0.)
  ctx |> render_rect(p.x, p.y, rb.x, rb.y, tc, tc, tc)

  let aSz = float2(size.x * 0.25, size.y * 0.75)
  let aPl1 = pos - float2(size.x * 0.55, 0.)
  let arrowLines1 <- to_array_move([[float2[]
    aPl1 + float2(0.5 * aSz.x, 0.);
    aPl1 + float2(0., 0.5 * aSz.y);
    aPl1 + float2(0.35 * aSz.x, 0.5 * aSz.y);
    aPl1 + float2(0.35 * aSz.x, aSz.y);
    aPl1 + float2(0.65 * aSz.x, aSz.y);
    aPl1 + float2(0.65 * aSz.x, 0.5 * aSz.y);
    aPl1 + float2(aSz.x, 0.5 * aSz.y);
  ]])
  ctx |> render_poly(arrowLines1, data.color)
  ctx |> render_line_aa(arrowLines1, true, ctx |> hdpx(1.2), float2(0., 0.), data.color)

  let aPl2 = pos - float2(size.x * 1.05, 0.)
  let arrowLines2 <- to_array_move([[float2[]
    aPl2 + float2(0.5 * aSz.x, aSz.y);
    aPl2 + float2(0., 0.5 * aSz.y);
    aPl2 + float2(0.35 * aSz.x, 0.5 * aSz.y);
    aPl2 + float2(0.35 * aSz.x, 0.);
    aPl2 + float2(0.65 * aSz.x, 0.);
    aPl2 + float2(0.65 * aSz.x, 0.5 * aSz.y);
    aPl2 + float2(aSz.x, 0.5 * aSz.y);
  ]])
  ctx |> render_poly(arrowLines2, data.color)
  ctx |> render_line_aa(arrowLines2, true, ctx |> hdpx(1.2), float2(0., 0.), data.color)

def b_scope_half_cue(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  if !get_radar_hud_cue_visible()
    return
  let rb = pos + size
  let center = (pos + rb) * 0.5
  let origin = float2(center.x, rb.y)

  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  let cueAzimuth = get_radar_hud_cue_azimuth() * max(get_radar_hud_target_azimuth_width() - get_radar_hud_cue_azimuth_half_width_rel() * azimuthRange, 0.)
  let halfDistGateWidthRel = 0.5 * get_radar_hud_cue_dist_width_rel()
  let distRel = halfDistGateWidthRel + get_radar_hud_cue_distance() * get_radar_hud_target_distance() * (1. - 2. * halfDistGateWidthRel)
  let cueAzimuthMin = cueAzimuth - get_radar_hud_cue_azimuth_half_width_rel() * azimuthRange
  let cueAzimuthMax = cueAzimuth + get_radar_hud_cue_azimuth_half_width_rel() * azimuthRange
  let radiusMin = (distRel - halfDistGateWidthRel) * 0.5
  let radiusMax = (distRel + halfDistGateWidthRel) * 0.5

  let color = is_color_or_white(data.lineColor) //remove color_is_white if use is_color on scope_sector
  let lcoord <- to_array_move([[float2[2] origin + float2(radiusMin * sin(cueAzimuthMin) * size.x,-radiusMin * cos(cueAzimuthMin) * size.y);
   origin + float2(radiusMax * sin(cueAzimuthMin) * size.x, -radiusMax * cos(cueAzimuthMin) * size.y); ]])
  ctx |> render_line_aa(lcoord, false, 2. * data.lineWidth, float2(0, 0), color)
  let rcoord <- to_array_move([[float2[2] origin + float2(radiusMin * sin(cueAzimuthMax) * size.x,-radiusMin * cos(cueAzimuthMax) * size.y);
   origin + float2(radiusMax * sin(cueAzimuthMax) * size.x, -radiusMax * cos(cueAzimuthMax) * size.y); ]])
  ctx |> render_line_aa(rcoord, false, 2. * data.lineWidth, float2(0, 0), color)

def b_scope_square(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&; position : float2)
  let size = get_radar_hud_has_azimuth_scale() ? rdata.size : float2(rdata.size.x * 0.2, rdata.size.y)
  let offsets = b_scope_square_labels(ctx, data, position, size, data.fontSize)
  let pos = position + float2(offsets.x, offsets.y)
  let sz = size - float2(offsets.x, offsets.y + offsets.z)
  if !data.hideBack || data.showScanAzimuth
    b_scope_square_bkg(ctx, data, pos, sz)
  if !data.hideBack
    b_scope_square_target_sector(ctx, data, pos, sz)
  b_scope_square_azimuth(ctx, data, pos, sz, true, get_radar_hud_turret_azimuth(), -1., -1.)
  render_ground_reflection(ctx, sz, pos, is_color_or_white(data.color), int2(20, 10), true)
  if get_radar_hud_is_visible()
    if get_radar_hud_is_emitting() && !data.hideBeam
      b_scope_square_azimuth(ctx, data, pos, sz, false, get_radar_hud_azimuth(), get_radar_hud_distance(), get_radar_hud_azimuth_half_width())
    b_scope_square_elevation(ctx, data, pos, sz, get_radar_hud_elevation(), get_radar_hud_elevation_min(), get_radar_hud_elevation_max(),
     get_radar_hud_scan_elevation_min(), get_radar_hud_scan_elevation_max())
  if get_radar_hud_is_visible2()
    if get_radar_hud_is_emitting2() && !data.hideBeam
      b_scope_square_azimuth(ctx, data, pos, sz, false, get_radar_hud_azimuth2(), get_radar_hud_distance2(), get_radar_hud_azimuth_half_width2())
    b_scope_square_elevation(ctx, data, pos, sz, get_radar_hud_elevation2(), get_radar_hud_elevation_min(), get_radar_hud_elevation_max(),
     get_radar_hud_scan_elevation_min(), get_radar_hud_scan_elevation_max())

  if get_radar_hud_aam_launch_zone_visible() && get_radar_hud_has_azimuth_scale() && !data.hideLaunchZone
    b_scope_square_launch_range(ctx, data, pos, sz)
  square_radar_targets(ctx, data, pos, sz)
  b_scope_square_cue(ctx, data, pos, sz)
  if !data.hideHorAngle
    b_scope_square_inner_labels(ctx, data, pos, sz, data.fontSize)
  if data.hasAviaHorizont
    b_scope_square_aviahorizont(ctx, data, data.netRowCnt <= 0 ? pos : rdata.pos, data.netRowCnt <= 0 ? sz : rdata.size)
  draw_additional_net(ctx, data, rdata.pos, rdata.size)

def b_scope_square_labels(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2; font_size : int)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, font_size)
  var vertOffset = 0.
  var horOffset = 0.
  var vertOffset2 = 0.
  var bottomOffset = 0.

  let azRanText = !data.hideHorAngle ? format("%.f", floor(rad_to_deg(get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min()) + 0.5)) + loc("measureUnits/deg") : ""
  let strBoxAz = get_str_bbox(azRanText, azRanText |> length(), fctx)
  if get_radar_hud_has_azimuth_scale() && !data.hideHorAngle
    horOffset += strBoxAz.width.x

  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(font_size)
  ctx |> set_color(data.modeColor)
  ctx |> set_draw_str_attr(FontFxType FFT_GLOW, 0, 0, get_font_fx_color(data.modeColor), get_font_fx_factor(data.modeColor, ctx))

  let nameId = get_radar_hud_mode_name_id()
  let defaultStr = get_radar_hud_is_visible() ? (get_radar_hud_is_irst() ? "hud/irst" : "hud/radarEmitting") : ""
  let modeName = loc(nameId >= 0 && nameId < modeNames |> length() ? modeNames[nameId] : defaultStr)
  let strBoxMode = get_str_bbox(modeName, modeName |> length(), fctx)
  ctx |> goto_xy(pos.x + size.x * 0.5 - strBoxMode.width.x * 0.5, pos.y + strBoxMode.width.y)
  ctx |> draw_str_scaled(1.0, modeName, modeName |> length())
  vertOffset += strBoxMode.width.y + ctx |> hdpx(4.)

  if get_radar_hud_noise_signal_visible() && get_radar_hud_is_visible() && get_radar_hud_noise_signal() > 0.5
    noise_signal(ctx, data, float2(pos.x + size.x * 0.44 - strBoxMode.width.x * 0.5, pos.y - ctx |> hdpx(2.)), size * 0.06,
     get_radar_hud_noise_signal())

  if get_radar_hud_is_visible2()
    let nameId2 = get_radar_hud_mode_name2_id()
    let defaultStr2 = get_radar_hud_is_visible2() ? (get_radar_hud_is_irst() ? "hud/irst" : "hud/radarEmitting") : ""
    let modeName2 = loc(nameId2 >= 0 && nameId2 < modeNames |> length() ? modeNames[nameId2] : defaultStr2)
    let strBoxMode2 = get_str_bbox(modeName2, modeName2 |> length(), fctx)
    ctx |> goto_xy(pos.x + size.x * 0.57 + strBoxMode.width.x * 0.5, pos.y + strBoxMode2.width.y)
    ctx |> draw_str_scaled(1.0, modeName2, modeName2 |> length())

    if get_radar_hud_noise_signal_visible() && get_radar_hud_noise_signal2() > 0.5
      noise_signal(ctx, data, float2(pos.x + size.x * 0.51 + strBoxMode.width.x * 0.5, pos.y), float2(size.x * 0.06, size.y * 0.07),
     get_radar_hud_noise_signal2())

  if get_radar_hud_has_azimuth_scale()
    if get_radar_hud_scan_azimuth_max() > get_radar_hud_scan_azimuth_min()
      ctx |> set_color(data.horAngleColor)
      ctx |> set_draw_str_attr(FontFxType FFT_GLOW, 0, 0, get_font_fx_color(data.horAngleColor), get_font_fx_factor(data.horAngleColor, ctx))
      let azText = format("%.f", floor(rad_to_deg(get_radar_hud_scan_azimuth_max() - get_radar_hud_scan_azimuth_min()) + 0.5))
      let elText = format("%.f", floor(rad_to_deg(get_radar_hud_scan_elevation_max() - get_radar_hud_scan_elevation_min()) + 0.5))
      let deg = loc("measureUnits/deg")
      let text = "{azText}{deg}x{elText}{deg}" + (get_radar_hud_scan_patterns_max() > 1 ? "*" : " ")
      let strBoxScan = get_str_bbox(text, text |> length(), fctx)
      ctx |> goto_xy(pos.x + horOffset, pos.y + vertOffset + strBoxScan.width.y)
      ctx |> draw_str_scaled(1.0, text, text |> length())
      vertOffset2 += strBoxScan.width.y

  if get_radar_hud_has_distance_scale() && !data.hideScale
    ctx |> set_color(data.scaleColor)
    ctx |> set_draw_str_attr(FontFxType FFT_GLOW, 0, 0, get_font_fx_color(data.scaleColor), get_font_fx_factor(data.scaleColor, ctx))

    let textMax = (get_radar_hud_velocity_search() ? get_measure_units_text(MeasureUnitsTypes MEASURE_UNIT_SPEED, get_radar_hud_distance_max(), true, 1.) :
     get_measure_units_text(MeasureUnitsTypes MEASURE_UNIT_DIST, get_radar_hud_distance_max() * 1000., true, 1.))
    let text = textMax + (get_radar_hud_distance_scale_max() > 1 ? "*" : " ")
    let strBox = get_str_bbox(text, text |> length(), fctx)
    ctx |> goto_xy(pos.x + size.x - strBox.width.x, pos.y + vertOffset + strBox.width.y)
    ctx |> draw_str_scaled(1.0, text, text |> length())
    if vertOffset2 == 0.
      vertOffset2 += strBox.width.y

    let textMin = (get_radar_hud_velocity_search() ? get_measure_units_text(MeasureUnitsTypes MEASURE_UNIT_SPEED, get_radar_hud_distance_min(), true, 1.) :
     get_measure_units_text(MeasureUnitsTypes MEASURE_UNIT_DIST, get_radar_hud_distance_min() * 1000., true, 1.))
    let strBoxMin = get_str_bbox(textMin, textMin |> length(), fctx)
    bottomOffset = strBoxMin.width.y
    ctx |> goto_xy(pos.x + size.x - strBoxMin.width.x, pos.y + size.y)
    ctx |> draw_str_scaled(1.0, textMin, textMin |> length())

  vertOffset += vertOffset2 + ctx |> hdpx(4.)
  let sz = float2(size.x - horOffset, size.y - vertOffset - bottomOffset)

  if get_radar_hud_has_azimuth_scale()
    if !data.hideHorAngle
      ctx |> set_color(data.horAngleColor)
      ctx |> set_draw_str_attr(FontFxType FFT_GLOW, 0, 0, get_font_fx_color(data.horAngleColor), get_font_fx_factor(data.horAngleColor, ctx))
      ctx |> goto_xy(pos.x, pos.y + strBoxAz.width.y + vertOffset + ctx |> hdpx(4.))
      ctx |> draw_str_scaled(1.0, azRanText, azRanText |> length())

    if !data.hideVerAngle
      ctx |> set_color(data.verAngleColor)
      ctx |> set_draw_str_attr(FontFxType FFT_GLOW, 0, 0, get_font_fx_color(data.verAngleColor), get_font_fx_factor(data.verAngleColor, ctx))

      let elvMaxText = format("%.f", floor(rad_to_deg(get_radar_hud_elevation_max()) + 0.5)) + loc("measureUnits/deg")
      let strBoxElMax = get_str_bbox(elvMaxText, elvMaxText |> length(), fctx)

      let elvMinText = format("%.f", floor(rad_to_deg(get_radar_hud_elevation_min()) + 0.5)) + loc("measureUnits/deg")
      let strBoxElMin = get_str_bbox(elvMinText, elvMinText |> length(), fctx)

      horOffset = max(horOffset, max(strBoxElMax.width.x, strBoxElMin.width.x))

      ctx |> goto_xy(pos.x + horOffset - strBoxElMax.width.x,
      pos.y + vertOffset + (-get_radar_hud_elevation_max() * elevMaxInv * elevMaxScreenRelSize + 0.5) * sz.y + strBoxElMax.width.y)
      ctx |> draw_str_scaled(1.0, elvMaxText, elvMaxText |> length())

      ctx |> goto_xy(pos.x + horOffset - strBoxElMin.width.x,
      pos.y + vertOffset + (-get_radar_hud_elevation_min() * elevMaxInv * elevMaxScreenRelSize + 0.5) * sz.y + strBoxElMin.width.y)
      ctx |> draw_str_scaled(1.0, elvMinText, elvMinText |> length())

  return float3(horOffset, vertOffset, bottomOffset)

def b_scope_square_inner_labels(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2; font_size : int)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, font_size)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(font_size)
  let color = is_color_or_white(data.horAngleColor)
  ctx |> set_color(color)
  ctx |> set_draw_str_attr(FontFxType FFT_GLOW, 0, 0, get_font_fx_color(color), get_font_fx_factor(color, ctx))

  let azMinText = format("%.f", floor(rad_to_deg(get_radar_hud_azimuth_min()) + 0.5)) + loc("measureUnits/deg")
  let strBoxAzMin = get_str_bbox(azMinText, azMinText |> length(), fctx)
  ctx |> goto_xy(pos.x + ctx |> hdpx(4.), pos.y + strBoxAzMin.width.y + ctx |> hdpx(4.))
  ctx |> draw_str_scaled(1.0, azMinText, azMinText |> length())

  let azMaxText = format("%.f", floor(rad_to_deg(get_radar_hud_azimuth_max()) + 0.5)) + loc("measureUnits/deg")
  let strBoxAzMax = get_str_bbox(azMaxText, azMaxText |> length(), fctx)
  ctx |> goto_xy(pos.x + size.x - strBoxAzMax.width.x - ctx |> hdpx(4.), pos.y + strBoxAzMax.width.y + ctx |> hdpx(4.))
  ctx |> draw_str_scaled(1.0, azMaxText, azMaxText |> length())

def b_scope_square_bkg(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  let azimuthRangeInv = azimuthRange != 0. ? 1. / azimuthRange : 1.
  let scanAzimuthMinRelW = 0.5 + get_radar_hud_scan_azimuth_min() * azimuthRangeInv
  let scanAzimuthMaxRelW = 0.5 + get_radar_hud_scan_azimuth_max() * azimuthRangeInv
  ctx |> set_color(areaBackgroundColor)
  let rb = pos + size
  let tc = float2(0., 0.)
  ctx |> render_rect(pos.x, pos.y, rb.x, rb.y, tc, tc, tc)
  //not repeat component 'frame' from darg, i am cant see him in game (useless)

  var color = float4(Color4(is_color_or_white(data.lineColor)))
  color *= 0.7
  let e3dColor = E3DCOLOR(Color4(color))
  ctx |> set_color(e3dColor)
  if scanAzimuthMinRelW <= 1. && scanAzimuthMinRelW >= 0.
    ctx |> draw_line(pos.x + scanAzimuthMinRelW * size.x, pos.y, pos.x + scanAzimuthMinRelW * size.x, pos.y + size.y, ctx |> hdpx(1.6 * data.lineWidth))
  if scanAzimuthMaxRelW <= 1. && scanAzimuthMaxRelW >= 0.
    ctx |> draw_line(pos.x + scanAzimuthMaxRelW * size.x, pos.y, pos.x + scanAzimuthMaxRelW * size.x, pos.y + size.y, ctx |> hdpx(1.6 * data.lineWidth))

  if data.hideBack
    return

  var scanAzimuthMinRel = 0.
  var scanAzimuthMaxRel = 1.
  if scanAzimuthMinRelW - 0.5 <= scanAzimuthMaxRelW - 0.5
    scanAzimuthMinRel = scanAzimuthMinRelW
    scanAzimuthMaxRel = scanAzimuthMaxRelW

  let distMinRel = max(0., get_radar_hud_distance_min() / max(get_radar_hud_distance_max(), 1.))
  let distanceMinY = (1. - distMinRel)
  if get_radar_hud_has_distance_scale()
    var rang = 0.25
    while rang < distanceMinY + 0.01
      ctx |> draw_line(pos.x + scanAzimuthMinRel * size.x, pos.y + rang * size.y, pos.x + scanAzimuthMaxRel * size.x, pos.y + rang * size.y, ctx |> hdpx(1.2 * data.lineWidth))
      rang = rang + 0.25
    if distanceMinY % 0.25 != 0.0
      ctx |> draw_line(pos.x + scanAzimuthMinRel * size.x, pos.y + distanceMinY * size.y, pos.x + scanAzimuthMaxRel * size.x, pos.y + distanceMinY * size.y, ctx |> hdpx(1.2 * data.lineWidth))

  if get_radar_hud_has_azimuth_scale()
    let azimuthRelStep = PI / 12. * azimuthRangeInv
    var azRel = scanAzimuthMaxRel
    while azRel > scanAzimuthMinRel
      ctx |> draw_line(pos.x + azRel * size.x, pos.y, pos.x + azRel * size.x, pos.y + distanceMinY * size.y, ctx |> hdpx(1.2 * data.lineWidth))
      azRel -= azimuthRelStep

def b_scope_square_target_sector(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  let isTank = azimuthRange > PI + 0.035

  if isTank
    logerr("tank")
  else
    let halfAzimuthWidth = min(azimuthRange > 0. ? get_radar_hud_target_azimuth_width() / azimuthRange : 0., 0.5)
    let tc = float2(0., 0.)
    var color = float4(Color4(data.color))//isColorOrWhite ???
    color *= 0.2
    let e3dColor = E3DCOLOR(Color4(color))
    ctx |> set_color(e3dColor)
    ctx |> render_rect(pos.x + (0.5 - halfAzimuthWidth) * size.x, pos.y + (1. - get_radar_hud_target_distance()) * size.y,
     pos.x + (0.5 + halfAzimuthWidth) * size.x, pos.y + size.y, tc, tc, tc)

def b_scope_square_azimuth(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2; for_tank_only : bool;
                           val : float; dist : float; half_width : float)
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  if for_tank_only && azimuthRange <= PI + 0.035
    return
  let var1 = for_tank_only || (dist == 1. && half_width > 0.)
  if var1
    let halfAzimuthWidth = min(azimuthRange > 0. ? half_width / azimuthRange : 0., 0.5)
    var color = float4(Color4(is_color_or_white(data.color)))
    color *= 0.4
    let e3dColor = E3DCOLOR(Color4(color))
    ctx |> set_color(e3dColor)
    let tc = float2(0., 0.)
    if data.beamShape == 1
      ctx |> set_color(data.lineColor)
      ctx |> draw_line(pos.x + (val - 0.02) * size.x, pos.y + size.y * 0.97, pos.x + (val + 0.02) * size.x, pos.y + size.y * 0.97, ctx |> hdpx(data.lineWidth * 5.))
      ctx |> draw_line(pos.x + val * size.x, pos.y + size.y * 0.97, pos.x + val * size.x, pos.y + size.y, ctx |> hdpx(data.lineWidth * 5.))
    else
      ctx |> render_rect(pos.x + (val - halfAzimuthWidth) * size.x, pos.y,
       pos.x + (val + halfAzimuthWidth) * size.x, pos.y + size.y, tc, tc, tc)
  else
    let color = is_color_or_white(data.lineColor)
    ctx |> set_color(color)
    if for_tank_only
      ctx |> draw_line(pos.x + val * size.x, pos.y, pos.x + val * size.x, pos.y + size.y, ctx |> hdpx(1.6))
    else
      let p1 = float2(pos.x + val * size.x, pos.y + max(1. - dist, 0.) * size.y)
      let p2 = float2(pos.x + val * size.x, pos.y + size.y)
      ctx |> render_line_dashed(p1, p2, ctx |> hdpx(10.), ctx |> hdpx(5.), ctx |> hdpx(1.6 * data.lineWidth), color)

def b_scope_square_elevation(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2; elev_rel : float;
                             elev_min : float; elev_max : float; elev_scan_min : float; elev_scan_max : float)
  let elevationMin = -elev_min * elevMaxInv * elevMaxScreenRelSize + 0.5
  let elevationMax = -elev_max * elevMaxInv * elevMaxScreenRelSize + 0.5
  let elevation = elevationMin * (1. - elev_rel) + elevationMax * elev_rel

  let markLen = 0.05
  let markLenShort = 0.03
  var color = float4(Color4(is_color_or_white(data.lineColor)))
  color *= 0.42
  let e3dColor = E3DCOLOR(Color4(color))

  let minCoord <- to_array_move([[float2[2] float2(pos.x, pos.y + elevationMin * size.y); float2(pos.x + markLen * size.x, pos.y + elevationMin * size.y)]])
  ctx |> render_line_aa(minCoord, false, ctx |> hdpx(4.), float2(0, 0), e3dColor)
  let zeroCoord <- to_array_move([[float2[2] float2(pos.x, pos.y + 0.5 * size.y); float2(pos.x + markLenShort * size.x, pos.y + 0.5 * size.y)]])
  ctx |> render_line_aa(zeroCoord, false, ctx |> hdpx(4.), float2(0, 0), e3dColor)
  let maxCoord <- to_array_move([[float2[2] float2(pos.x, pos.y + elevationMax * size.y); float2(pos.x + markLen * size.x, pos.y + elevationMax * size.y)]])
  ctx |> render_line_aa(maxCoord, false, ctx |> hdpx(4.), float2(0, 0), e3dColor)
  let elevCoord <- to_array_move([[float2[2] float2(pos.x, pos.y + elevation * size.y); float2(pos.x + markLenShort * size.x, pos.y + elevation * size.y)]])
  ctx |> render_line_aa(elevCoord, false, ctx |> hdpx(4.), float2(0, 0), e3dColor)

  if elev_scan_max > elev_scan_min
    let elevationScanMin = -elev_scan_min * elevMaxInv * elevMaxScreenRelSize + 0.5
    let elevationScanMax = -elev_scan_max * elevMaxInv * elevMaxScreenRelSize + 0.5

    let scanCoord <- to_array_move([[float2[4] float2(pos.x, pos.y + elevationScanMin * size.y); float2(pos.x + markLen * size.x, pos.y + elevationScanMin * size.y);
     float2(pos.x + markLen * size.x, pos.y + elevationScanMax * size.y); float2(pos.x, pos.y + elevationScanMax * size.y)]])
    ctx |> render_line_aa(scanCoord, false, ctx |> hdpx(4.), float2(0, 0), e3dColor)

def b_scope_square_launch_range(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  var color = float4(Color4(is_color_or_white(data.lineColor)))
  color *= 0.42
  let e3dColor = E3DCOLOR(Color4(color))
  ctx |> set_color(e3dColor)

  let dist = get_radar_hud_aam_launch_zone_dist()
  if dist <= 1.
    ctx |> draw_line(pos.x + 0.8 * size.x, pos.y + (1. - dist) * size.y,
     pos.x + size.x, pos.y + (1. - dist) * size.y, ctx |> hdpx(4. * data.lineWidth))
  let distMin = get_radar_hud_aam_launch_zone_dist_min()
  if distMin <= 1.
    ctx |> draw_line(pos.x + 0.9 * size.x, pos.y + (1. - distMin) * size.y,
     pos.x + size.x, pos.y + (1. - distMin) * size.y, ctx |> hdpx(4. * data.lineWidth))
  let distMax = get_radar_hud_aam_launch_zone_dist_max()
  if distMax <= 1.
    ctx |> draw_line(pos.x + 0.9 * size.x, pos.y + (1. - get_radar_hud_aam_launch_zone_dist_max()) * size.y,
     pos.x + size.x, pos.y + (1. - get_radar_hud_aam_launch_zone_dist_max()) * size.y, ctx |> hdpx(4. * data.lineWidth))
  let dgftDistMax = get_radar_hud_aam_launch_zone_dist_dgft_max()
  let dgftDistMin = get_radar_hud_aam_launch_zone_dist_dgft_min()
  if dgftDistMax <= 1.
    ctx |> draw_line(pos.x + 0.92 * size.x, pos.y + (1. - dgftDistMax) * size.y,
     pos.x + 0.98 * size.x, pos.y + (1. - dgftDistMax) * size.y, ctx |> hdpx(4. * data.lineWidth))
  if dgftDistMin <= 1.
    ctx |> draw_line(pos.x + 0.92 * size.x, pos.y + (1. - dgftDistMin) * size.y,
     pos.x + 0.98 * size.x, pos.y + (1. - dgftDistMin) * size.y, ctx |> hdpx(4. * data.lineWidth))
  if dgftDistMax <= 1. || dgftDistMin <= 1.
    ctx |> draw_line(pos.x + 0.92 * size.x, pos.y + (1. - dgftDistMin) * size.y,
     pos.x + 0.92 * size.x, pos.y + (1. - min(dgftDistMax, 1.)) * size.y, ctx |> hdpx(4. * data.lineWidth))

def square_radar_targets(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  let hasAzimuthScale = get_radar_hud_has_azimuth_scale()
  let hasDistanceScale = get_radar_hud_has_distance_scale()
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  foreach_targets() <| $(var target)
    var angleRel = 0.5
    var angularWidthRel = 1.
    if hasAzimuthScale
      angleRel = target.azimuthRel
      angularWidthRel = target.azimuthWidthRel
    let angleLeft = max(0., angleRel - 0.5 * angularWidthRel)
    let angleRight = min(angleRel + 0.5 * angularWidthRel, 1.)

    var distanceRel = 0.9
    var radialWidthRel = 0.05
    if hasDistanceScale && target.distanceRel >= 0.
      distanceRel = target.distanceRel
      radialWidthRel = max(0.05, target.distanceWidthRel)

    let p = float2(pos.x + angleRel * size.x, pos.y + (1. - distanceRel) * size.y)

    var color = float4(Color4(is_color_or_white(data.targetColor)))
    let signalRel = target.signalRel < 0.01 ? 0. : cvt(target.signalRel, 0.05, 1., 0.3, 1.)
    color *= (1. - target.ageRel) * signalRel
    let e3dColor = E3DCOLOR(Color4(color))

    if target.targetType == int(RadarTargetType TYPE_TARGET)
      let azimuthHalfWidth = get_radar_hud_is_visible2() ? get_radar_hud_azimuth_half_width2() : get_radar_hud_azimuth_half_width()
      let angularGateHalfWidthRel = angularGateWidthMultSquare * azimuthHalfWidth / azimuthRange
      let angleGateLeftRel = angleRel - angularGateHalfWidthRel
      let angleGateRightRel = angleRel + angularGateHalfWidthRel

      let distanceGateHalfWidthRel = 0.5 * max(get_radar_hud_distance_gate_width_rel(), distanceGateWidthRelMin) * distanceGateWidthMult
      let distanceInner = distanceRel - distanceGateHalfWidthRel
      let distanceOuter = distanceRel + distanceGateHalfWidthRel

      if target.isDetected
        let lcoord <- to_array_move([[float2[2] float2(pos.x + angleGateLeftRel * size.x, pos.y + (1.- distanceInner) * size.y);
         float2(pos.x + angleGateLeftRel * size.x, pos.y + (1. - distanceOuter) * size.y)]])
        ctx |> render_line_aa(lcoord, false, ctx |> hdpx(3. * data.lineWidth), float2(0, 0), e3dColor)
        let rcoord <- to_array_move([[float2[2] float2(pos.x + angleGateRightRel * size.x, pos.y + (1.- distanceInner) * size.y);
         float2(pos.x + angleGateRightRel * size.x, pos.y + (1. - distanceOuter) * size.y)]])
        ctx |> render_line_aa(rcoord, false, ctx |> hdpx(3. * data.lineWidth), float2(0, 0), e3dColor)
      if !target.isEnemy
        let iffMarkDistRel = get_radar_hud_velocity_search() ? 0.9 : distanceRel + (0.5 + iffDistRelMult) * radialWidthRel
        let coord <- to_array_move([[float2[2] float2(pos.x + angleLeft * size.x, pos.y + (1.- iffMarkDistRel) * size.y);
         float2(pos.x + angleRight * size.x, pos.y + (1. - iffMarkDistRel) * size.y)]])
        ctx |> render_line_aa(coord, false, ctx |> hdpx(3. * data.lineWidth), float2(0, 0), e3dColor)
      if target.isAttacked
        let attackMarkDistRel = get_radar_hud_velocity_search() ? 0.9 : distanceRel + (0.5 + attackDistRelMult) * radialWidthRel
        let coord <- to_array_move([[float2[2] float2(pos.x + angleRel * size.x, pos.y + (1.- attackMarkDistRel) * size.y);
         float2(pos.x + angleRel * size.x, pos.y + (1. - attackMarkDistRel + attackHeightRel) * size.y)]])
        ctx |> render_line_aa(coord, false, ctx |> hdpx(3. * data.lineWidth), float2(0, 0), e3dColor)
      //animation

      if target.isSelected && hasAzimuthScale
        if data.targetFormType == 0
          ctx |> render_ellipse_aa(p, size * 0.02, ctx |> hdpx(2.), e3dColor, e3dColor)
        elif data.targetFormType == 1 || data.targetFormType == 2
          ctx |> render_ellipse_aa(p, size * 0.03, ctx |> hdpx(2.), e3dColor, transparentColor)
          let sign = data.targetFormType == 1 ? 1. : -1.
          let coord <- to_array_move([[float2[3]
          float2(p.x - size.x * 0.02, p.y + size.y * 0.015 * sign);
          float2(p.x, p.y - size.y * 0.03 * sign);
          float2(p.x + size.x * 0.02, p.y + size.y * 0.015 * sign)]])
          ctx |> render_line_aa(coord, true, 1., float2(0, 0), e3dColor)
        if target.losSpeed < 3000.
          let coord <- to_array_move([[float2[2] float2(pos.x + angleRel * size.x, pos.y + (1.- distanceRel) * size.y);
           float2(pos.x + (angleRel - target.losHorSpeed * 0.0002) * size.x, pos.y + (1. - (distanceRel + target.losSpeed * 0.0002)) * size.y)]])
          ctx |> render_line_aa(coord, false, ctx |> hdpx(2. * data.lineWidth), float2(0, 0), e3dColor)
      else
        let angleCenter = (angleRight + angleLeft) * 0.5
        if data.targetFormType == 0
          let coord <- to_array_move([[float2[2] float2(pos.x + angleLeft * size.x, pos.y + (1.- distanceRel) * size.y);
           float2(pos.x + angleRight * size.x, pos.y + (1. - distanceRel) * size.y)]])
          ctx |> render_line_aa(coord, false, ctx |> hdpx(100. * radialWidthRel), float2(0, 0), e3dColor)
        elif data.targetFormType == 1
          let coord <- to_array_move([[float2[3]
           float2(pos.x + angleLeft * size.x, pos.y + (1. - distanceRel + 0.02) * size.y);
           float2(pos.x + angleCenter * size.x, pos.y + (1. - distanceRel - 0.02) * size.y);
           float2(pos.x + angleRight * size.x, pos.y + (1. - distanceRel + 0.02) * size.y)]])
          ctx |> render_line_aa(coord, true, ctx |> hdpx(100. * radialWidthRel), float2(0, 0), e3dColor)
        elif data.targetFormType == 2
          let tc = float2(0., 0.)
          let boxSize = 0.02 * size.x
          ctx |> render_rect(pos.x + angleCenter * size.x - boxSize, pos.y + (1. - distanceRel) * size.y - boxSize,
           pos.x + angleCenter * size.x + boxSize, pos.y + (1. - distanceRel) * size.y + boxSize, tc, tc, tc)

    elif (target.targetType == int(RadarTargetType TYPE_OWN_WEAPON) && !data.hideWeaponIndication)
      if hasAzimuthScale
        ctx |> render_ellipse_aa(p, size * 0.005, ctx |> hdpx(2.), e3dColor, e3dColor)

    elif (target.targetType == int(RadarTargetType TYPE_OWN_WEAPON_TARGET) && !data.hideWeaponIndication)
      if hasAzimuthScale && !target.isAttacked
        ctx |> render_ellipse_aa(p, size * 0.04, ctx |> hdpx(2.), e3dColor, transparentColor)

  if hasAzimuthScale && hasDistanceScale && !data.hideWeaponIndication
    let color = float4(Color4(is_color_or_white(data.targetColor)))
    let e3dColor = E3DCOLOR(Color4(color))
    foreach_own_weapon_links() <| $(var ownWeaponLink)
      for_own_weapon_with_target(ownWeaponLink.ownWeaponIndex, ownWeaponLink.ownWeaponTargetIndex) <| $(var ownWeapon; ownWeaponTarget)
        let ownWeaponPos = float2(pos.x + ownWeapon.azimuthRel * size.x, pos.y + (1. - ownWeapon.distanceRel) * size.y)
        let ownWeaponTargetPos = float2(pos.x + ownWeaponTarget.azimuthRel * size.x, pos.y + (1. - ownWeaponTarget.distanceRel) * size.y)
        if ownWeaponLink.lockDistanceToDistance < 1.0
          let direction = float2(ownWeaponTargetPos[0] - ownWeaponPos[0], ownWeaponTargetPos[1] - ownWeaponPos[1])
          let lockPos = float2(ownWeaponPos[0] + direction[0] * ownWeaponLink.lockDistanceToDistance, ownWeaponPos[1] + direction[1] * ownWeaponLink.lockDistanceToDistance)
          let coord <- to_array_move([[float2[2] ownWeaponPos; lockPos]])
          ctx |> render_line_aa(coord, false, ctx |> hdpx(2.), float2(0, 0), e3dColor)
          ctx |> render_line_dashed(lockPos, ownWeaponTargetPos, ctx |> hdpx(10.), ctx |> hdpx(5.), ctx |> hdpx(2.), e3dColor)
        else
          let coord <- to_array_move([[float2[2] ownWeaponPos; ownWeaponTargetPos]])
          ctx |> render_line_aa(coord, false, ctx |> hdpx(2.), float2(0, 0), e3dColor)

def b_scope_square_cue(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  if !get_radar_hud_cue_visible()
    return

  let color = is_color_or_white(data.lineColor)//remove is_color_or_white if use is_color on target sector
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  let cueAzimuthHwr = get_radar_hud_cue_azimuth_half_width_rel()
  let cueDistWidthRel =  get_radar_hud_cue_dist_width_rel()
  let cuePos = pos + float2((get_radar_hud_cue_azimuth() * (get_radar_hud_target_azimuth_width() / azimuthRange - cueAzimuthHwr) + 0.5) * size.x,
          (1. - (0.5 * cueDistWidthRel + get_radar_hud_cue_distance() * get_radar_hud_target_distance() * (1. - cueDistWidthRel))) * size.y)
  let lcoord <- to_array_move([[float2[2] float2(cuePos.x- cueAzimuthHwr * size.x, cuePos.y- cueDistWidthRel * size.y * 0.5);
   float2(cuePos.x - cueAzimuthHwr * size.x, cuePos.y + cueDistWidthRel * size.y * 0.5)]])
  ctx |> render_line_aa(lcoord, false, ctx |> hdpx(2. * data.lineWidth), float2(0, 0), color)
  let rcoord <- to_array_move([[float2[2] float2(cuePos.x + cueAzimuthHwr * size.x, cuePos.y- cueDistWidthRel * size.y * 0.5);
   float2(cuePos.x + cueAzimuthHwr * size.x, cuePos.y + cueDistWidthRel * size.y * 0.5)]])
  ctx |> render_line_aa(rcoord, false, ctx |> hdpx(2. * data.lineWidth), float2(0, 0), color)

  if data.cueHeights
    let hero = get_controlled_hero()
    if hero == null || hero.isDelayed
      return
    let scanElevationWidth = get_radar_hud_scan_elevation_max() - get_radar_hud_scan_elevation_min()
    let ownAltitude = hero.pos.y
    let distance = get_radar_hud_cue_distance() * get_radar_hud_distance_max() * 1000.
    let hmin = (ownAltitude + distance * sin(get_radar_hud_scan_elevation_min() - 0.5f * scanElevationWidth)) * metrToThsFeet
    let hmax = (ownAltitude + distance * sin(get_radar_hud_scan_elevation_max() + 0.5f * scanElevationWidth)) * metrToThsFeet

    let hmaxText = format("%d", roundi(hmax))
    let hminText = format("%d", roundi(hmin))
    var fctx : StdGuiFontContext
    get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
    ctx |> set_font(data.fontId, 0, 0)
    ctx |> set_font_ht(data.fontSize)

    ctx |> goto_xy(cuePos.x + cueAzimuthHwr * size.x + 3., cuePos.y - cueDistWidthRel * size.y * 0.5)
    ctx |> draw_str_scaled(1.0, hmaxText, hmaxText |> length())

    ctx |> goto_xy(cuePos.x + cueAzimuthHwr * size.x + 3., cuePos.y + cueDistWidthRel * size.y * 0.5)
    ctx |> draw_str_scaled(1.0, hminText, hminText |> length())

def b_scope(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&)
  let offsets = b_scope_labels(ctx, rdata, data)
  let totalOffset = float2(offsets.x + offsets.z, offsets.y + offsets.w)
  let size = float2(min(rdata.size.x - totalOffset.x, rdata.size.y - totalOffset.y))
  let pos = rdata.pos + (totalOffset.x > totalOffset.y ? float2(offsets.x, (rdata.size.y - size.y) * 0.5) : float2((rdata.size.x - size.x) * 0.5, offsets.y))
  b_scope_background(ctx, data, pos, size)
  b_scope_azimuth(ctx, data, pos + size * 0.5, size, false, get_radar_hud_aim_azimuth(), 0., -1., 2.)
  b_scope_azimuth(ctx, data, pos + size * 0.5, size, false, get_radar_hud_turret_azimuth(), 0., -1., 1.)
  let half_width = get_radar_hud_target_azimuth_width()
  if half_width > 0.
    b_scope_sector(ctx, data, pos + size * 0.5, size, half_width, get_radar_hud_turret_azimuth())
  if get_radar_hud_is_visible() && get_radar_hud_is_emitting()
    let dist = get_radar_hud_distance()
    let halfVal = get_radar_hud_azimuth_half_width()
    let isSectorView = dist == 1. && halfVal > 0.
    b_scope_azimuth(ctx, data, pos + size * 0.5, size, isSectorView, get_radar_hud_azimuth(), halfVal, dist, 1.2)
  if get_radar_hud_is_visible2() && get_radar_hud_is_emitting2()
    let dist = get_radar_hud_distance2()
    let halfVal = get_radar_hud_azimuth_half_width2()
    let isSectorView = dist == 1. && halfVal > 0.
    b_scope_azimuth(ctx, data, pos + size * 0.5, size, isSectorView, get_radar_hud_azimuth2(), halfVal, dist, 1.2)
  polar_radar_targets(ctx, data, pos + size * 0.5, size)
  b_scope_cue(ctx, data, pos + size * 0.5, size)

def b_scope_labels(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize/*hudFontHgt*/)
  var topOffset = 0.
  var leftOffset = 0.
  var rightOffset = 0.
  var bottomOffset = 0.
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize);
  ctx |> set_color(data.color)
  ctx |> set_draw_str_attr(FontFxType FFT_GLOW, 0, 0, get_font_fx_color(data.color), get_font_fx_factor(data.color, ctx))

  let hideMeasures = !get_radar_hud_has_azimuth_scale() || get_radar_hud_scan_azimuth_max() <= get_radar_hud_scan_azimuth_min()
  let deg = loc("measureUnits/deg")
  let text270 = "270{deg}"
  let strBox270 = get_str_bbox(text270, text270 |> length(), fctx)
  let azText = format("%.f", floor(rad_to_deg(get_radar_hud_scan_azimuth_max() - get_radar_hud_scan_azimuth_min()) + 0.5))
  let elText = format("%.f", floor(rad_to_deg(get_radar_hud_scan_elevation_max() - get_radar_hud_scan_elevation_min()) + 0.5))
  let textMeasures = !hideMeasures ? "{azText}{deg}x{elText}{deg}" + (get_radar_hud_scan_patterns_max() > 1 ? "*" : "") : ""
  let strBoxMeas = get_str_bbox(textMeasures, textMeasures |> length(), fctx)
  leftOffset = data.hasTxtBlock ? strBox270.width.x : max(strBox270.width.x, strBoxMeas.width.x)

  let text180 = "180{deg}"
  let strBox180 = get_str_bbox(text180, text180 |> length(), fctx)
  bottomOffset = strBox180.width.y + ctx |> hdpx(4.)

  let text90 = "90{deg}"
  let strBox90 = get_str_bbox(text90, text90 |> length(), fctx)
  let textDist = (get_radar_hud_velocity_search() ? get_measure_units_text(MeasureUnitsTypes MEASURE_UNIT_SPEED, get_radar_hud_distance_max(), true, 1.) :
     get_measure_units_text(MeasureUnitsTypes MEASURE_UNIT_DIST, get_radar_hud_distance_max() * 1000., true, 1.))
  let textVel = get_radar_hud_has_distance_scale() ? textDist + (get_radar_hud_distance_scale_max() > 1 ? "*" : "") : ""
  let strBoxVel = get_str_bbox(textVel, textVel |> length(), fctx)
  rightOffset = max(strBoxVel.width.x, strBox90.width.x)

  let nameId = get_radar_hud_mode_name_id()
  let defaultStr = get_radar_hud_is_visible() ? (get_radar_hud_is_irst() ? "hud/irst" : "hud/radarEmitting") : ""
  let modeName = loc(nameId >= 0 && nameId < modeNames |> length() ? modeNames[nameId] : defaultStr)
  let strBoxMode = get_str_bbox(modeName, modeName |> length(), fctx)
  topOffset = strBoxMode.width.y + ctx |> hdpx(4.)

  let name2Id = get_radar_hud_mode_name2_id()
  let defaultStr2 = get_radar_hud_is_visible2() ? (get_radar_hud_is_irst() ? "hud/irst" : "hud/radarEmitting") : ""
  let modeName2 = loc(name2Id >= 0 && name2Id < modeNames |> length() ? modeNames[name2Id] : defaultStr2)
  let strBoxMode2 = get_str_bbox(modeName2, modeName2 |> length(), fctx)

  let text0 = "0{deg}"
  let strBox0 = get_str_bbox(text0, text0 |> length(), fctx)

  let totalOffset = float2(leftOffset + rightOffset, topOffset + bottomOffset)
  let size = float2(min(rdata.size.x - totalOffset.x, rdata.size.y - totalOffset.y))
  let pos = rdata.pos + (totalOffset.x > totalOffset.y ? float2(leftOffset, (rdata.size.y - size.y) * 0.5) : float2((rdata.size.x - size.x) * 0.5, topOffset))

  if data.hasTxtBlock
    ctx |> goto_xy(pos.x - strBoxMode.width.x, pos.y + size.y + bottomOffset + strBoxMode.width.y - ctx |> hdpx(8.))
  else
    ctx |> goto_xy(pos.x + size.x * 0.5 - strBoxMode.width.x - strBox0.width.x, pos.y - topOffset + strBoxMode.width.y)
  ctx |> draw_str_scaled(1.0, modeName, modeName |> length())

  ctx |> goto_xy(pos.x + size.x * 0.5 + strBox0.width.x, pos.y - topOffset + strBoxMode2.width.y)
  ctx |> draw_str_scaled(1.0, modeName2, modeName2 |> length())

  ctx |> goto_xy(pos.x + size.x * 0.5 - strBox0.width.x * 0.5, pos.y - topOffset + strBox0.width.y)
  ctx |> draw_str_scaled(1.0, text0, text0 |> length())

  if !hideMeasures
    if data.hasTxtBlock
      ctx |> goto_xy(pos.x - strBoxMode.width.x, pos.y + size.y + bottomOffset + strBoxMode.width.y + strBoxMeas.width.y - ctx |> hdpx(4.))
    else
      ctx |> goto_xy(pos.x - strBoxMeas.width.x, pos.y + size.y * 0.5 + strBoxMeas.width.y)
    ctx |> draw_str_scaled(1.0, textMeasures, textMeasures |> length())

  ctx |> goto_xy(pos.x - strBox270.width.x, pos.y + size.y * 0.5 - ctx |> hdpx(4.))
  ctx |> draw_str_scaled(1.0, text270, text270 |> length())

  ctx |> goto_xy(pos.x + size.x * 0.5 - strBox180.width.x * 0.5, pos.y + size.y + bottomOffset)
  ctx |> draw_str_scaled(1.0, text180, text180 |> length())

  ctx |> goto_xy(pos.x + size.x, pos.y + size.y * 0.5 - ctx |> hdpx(4.))
  ctx |> draw_str_scaled(1.0, text90, text90 |> length())

  if data.hasTxtBlock
    ctx |> goto_xy(pos.x - strBoxMode.width.x, pos.y + size.y + bottomOffset + strBoxMode.width.y + strBoxMeas.width.y + strBoxVel.width.y)
  else
    ctx |> goto_xy(pos.x + size.x, pos.y + size.y * 0.5 + strBoxVel.width.y)
  ctx |> draw_str_scaled(1.0, textVel, textVel |> length())
  return float4(leftOffset, topOffset, rightOffset, bottomOffset)

def b_scope_background(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  let center = pos + size * 0.5
  ctx |> render_ellipse_aa(center, size * 0.5, ctx |> hdpx(1.6), data.color, areaBackgroundColor)
  let color = is_color_or_white(data.color)
  if get_radar_hud_has_distance_scale()
    ctx |> render_ellipse_aa(center, size * 0.125, ctx |> hdpx(1.2), color, transparentColor)
    ctx |> render_ellipse_aa(center, size * 0.25, ctx |> hdpx(1.2), color, transparentColor)
    ctx |> render_ellipse_aa(center, size * 0.375, ctx |> hdpx(1.2), color, transparentColor)
  else
    ctx |> render_ellipse_aa(center, size * 0.45, ctx |> hdpx(1.2), color, transparentColor)

  let angle = PI / 6.
  for i in range(0, 12)
    let edge = center + float2(size.x * 0.5 * cos(float(i) * angle), size.x * 0.5 * sin(float(i) * angle))
    let coord <- to_array_move([[float2[2] center; edge]])
    ctx |> render_line_aa(coord, false, ctx |> hdpx(1.2), float2(0, 0), color)

def b_scope_cue(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  if !get_radar_hud_cue_visible()
    return
  let cueAzimuthHalfWidthRel = get_radar_hud_cue_azimuth_half_width_rel()
  let cueWidthRel = get_radar_hud_cue_dist_width_rel()
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  let cueAzimuth = get_radar_hud_cue_azimuth() * max(get_radar_hud_target_azimuth_width() - cueAzimuthHalfWidthRel * azimuthRange, 0.)
  let distRel = 0.5 * cueWidthRel + get_radar_hud_cue_distance() * get_radar_hud_target_distance() * (1. - cueWidthRel)
  let turretAzimuth = get_radar_hud_azimuth_min() + azimuthRange * get_radar_hud_turret_azimuth()
  let radiusMin = (distRel - cueWidthRel * 0.5) * 0.5
  let radiusMax = (distRel + cueWidthRel * 0.5) * 0.5
  let cueAzimuthMin = turretAzimuth + cueAzimuth - cueAzimuthHalfWidthRel * azimuthRange
  let cueAzimuthMax = turretAzimuth + cueAzimuth + cueAzimuthHalfWidthRel * azimuthRange

  let lcoord <- to_array_move([[float2[2] pos + float2(radiusMin * sin(cueAzimuthMin) * size.x,-radiusMin * cos(cueAzimuthMin) * size.y);
   pos + float2(radiusMax * sin(cueAzimuthMin) * size.x, -radiusMax * cos(cueAzimuthMin) * size.y)]])
  ctx |> render_line_aa(lcoord, false, ctx |> hdpx(2.), float2(0, 0), data.color)
  let rcoord <- to_array_move([[float2[2] pos + float2(radiusMin * sin(cueAzimuthMax) * size.x,-radiusMin * cos(cueAzimuthMax) * size.y);
   pos + float2(radiusMax * sin(cueAzimuthMax) * size.x, -radiusMax * cos(cueAzimuthMax) * size.y)]])
  ctx |> render_line_aa(rcoord, false, ctx |> hdpx(2.), float2(0, 0), data.color)

def c_scope(var ctx : GuiContext&; data : CanvasParams&; position : float2; total_size : float2)
  let offsets = c_scope_markers(ctx, data, position, total_size)
  let pos = position + offsets
  let size = total_size - offsets
  c_scope_background(ctx, data, pos, size)
  if get_radar_hud_is_visible() && get_radar_hud_is_emitting()
    c_scope_azimuth(ctx, data, pos, size, get_radar_hud_azimuth(), get_radar_hud_elevation(), get_radar_hud_azimuth_half_width(), get_radar_hud_elevation_half_width())
  if get_radar_hud_is_visible2() && get_radar_hud_is_emitting2()
    c_scope_azimuth(ctx, data, pos, size, get_radar_hud_azimuth2(), get_radar_hud_elevation2(), get_radar_hud_azimuth_half_width2(), get_radar_hud_elevation_half_width2())
  c_scope_targets(ctx, data, pos, size)
  c_scope_cue(ctx, data, pos, size)
  c_scope_inner_labels(ctx, data, pos, size)

def c_scope_markers(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize/*hudFontHgt*/)
  var topOffset = 0.
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize);
  ctx |> set_color(data.color)
  ctx |> set_draw_str_attr(FontFxType FFT_GLOW, 0, 0, get_font_fx_color(data.color), get_font_fx_factor(data.color, ctx))
  let deg = loc("measureUnits/deg")

  let textElevMax = format("%.f", floor(rad_to_deg(get_radar_hud_elevation_max()) + 0.5)) + deg
  let strBoxElMax = get_str_bbox(textElevMax, textElevMax |> length(), fctx)
  let textElevMin = format("%.f", floor(rad_to_deg(get_radar_hud_elevation_min()) + 0.5)) + deg
  let strBoxElMin = get_str_bbox(textElevMin, textElevMin |> length(), fctx)
  let textElev0 = "0{deg}"
  let strBoxEl0 = get_str_bbox(textElev0, textElev0 |> length(), fctx)
  let leftOffset = max(strBoxElMax.width.x, max(strBoxElMin.width.x, strBoxEl0.width.x))

  if !get_radar_hud_is_b_scope_visible()
    var textScanRange = ""
    var textVel = ""
    if get_radar_hud_has_azimuth_scale() && get_radar_hud_scan_azimuth_max() > get_radar_hud_scan_azimuth_min()
      let azText = format("%.f", floor(rad_to_deg(get_radar_hud_scan_azimuth_max() - get_radar_hud_scan_azimuth_min()) + 0.5))
      let elText = format("%.f", floor(rad_to_deg(get_radar_hud_scan_elevation_max() - get_radar_hud_scan_elevation_min()) + 0.5))
      textScanRange = "{azText}{deg}x{elText}{deg}" + (get_radar_hud_scan_patterns_max() > 1 ? "*" : "")
      let strBoxScan = get_str_bbox(textScanRange, textScanRange |> length(), fctx)
      topOffset = strBoxScan.width.y

    if get_radar_hud_has_distance_scale()
      let distText = (get_radar_hud_velocity_search() ? get_measure_units_text(MeasureUnitsTypes MEASURE_UNIT_SPEED, get_radar_hud_distance_max(), true, 1.) :
       get_measure_units_text(MeasureUnitsTypes MEASURE_UNIT_DIST, get_radar_hud_distance_max() * 1000., true, 1.))
      textVel = distText + (get_radar_hud_distance_scale_max() > 1 ? "*" : "")
      let strBoxVel = get_str_bbox(textVel, textVel |> length(), fctx)
      topOffset = max(topOffset, strBoxVel.width.y)

    let nameId = get_radar_hud_mode_name_id()
    let defaultStr = get_radar_hud_is_visible() ? (get_radar_hud_is_irst() ? "hud/irst" : "hud/radarEmitting") : ""
    let modeName = loc(nameId >= 0 && nameId < modeNames |> length() ? modeNames[nameId] : defaultStr)
    let strBoxMode = get_str_bbox(modeName, modeName |> length(), fctx)
    topOffset = max(strBoxMode.width.y, topOffset)

    let name2Id = get_radar_hud_mode_name2_id()
    let defaultStr2 = get_radar_hud_is_visible2() ? (get_radar_hud_is_irst() ? "hud/irst" : "hud/radarEmitting") : ""
    let modeName2 = loc(name2Id >= 0 && name2Id < modeNames |> length() ? modeNames[name2Id] : defaultStr2)
    let strBoxMode2 = get_str_bbox(modeName2, modeName2 |> length(), fctx)
    topOffset += strBoxMode2.width.y

    if textScanRange |> length() > 0
      ctx |> goto_xy(pos.x + leftOffset, pos.y + topOffset)
      ctx |> draw_str_scaled(1., textScanRange, textScanRange |> length())

    if textVel |> length() > 0
      let strBoxVel = get_str_bbox(textVel, textVel |> length(), fctx)
      ctx |> goto_xy(pos.x + size.x - strBoxVel.width.x, pos.y + topOffset)
      ctx |> draw_str_scaled(1., textVel, textVel |> length())

    ctx |> goto_xy(pos.x + (size.x - leftOffset) * 0.5, pos.y + topOffset)
    ctx |> draw_str_scaled(1., modeName, modeName |> length())

    ctx |> goto_xy(pos.x + (size.x - leftOffset) * 0.5, pos.y + topOffset - strBoxMode.width.y)
    ctx |> draw_str_scaled(1., modeName2, modeName2 |> length())

  topOffset += ctx |> hdpx(4.)
  ctx |> goto_xy(pos.x + leftOffset - strBoxElMax.width.x, pos.y + topOffset + strBoxElMax.width.y)
  ctx |> draw_str_scaled(1., textElevMax, textElevMax |> length())
  ctx |> goto_xy(pos.x + leftOffset - strBoxElMin.width.x, pos.y + size.y)
  ctx |> draw_str_scaled(1., textElevMin, textElevMin |> length())
  let elRange = (1. + get_radar_hud_elevation_min() / (get_radar_hud_elevation_max() - get_radar_hud_elevation_min())) * (size.y - topOffset)
  ctx |> goto_xy(pos.x + leftOffset - strBoxEl0.width.x, pos.y + topOffset + elRange + strBoxEl0.width.y * 0.5)
  ctx |> draw_str_scaled(1., textElev0, textElev0 |> length())

  return float2(leftOffset + ctx |> hdpx(4.), topOffset)

def c_scope_background(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  ctx |> set_color(areaBackgroundColor)
  let tc = float2(0., 0.)
  let rb = pos + size
  ctx |> render_rect(pos.x, pos.y, rb.x, rb.y, tc, tc, tc)
  ctx |> set_color(data.color)
  ctx |> render_frame(pos.x, pos.y, pos.x + size.x, pos.y + size.y, ctx |> hdpx(1.8))

  var color = float4(Color4(is_color_or_white(data.color)))
  color *= 0.62
  let e3dColor = E3DCOLOR(Color4(color))
  ctx |> set_color(e3dColor)
  ctx |> draw_line(pos.x + size.x * 0.5, pos.y, pos.x + size.x * 0.5, pos.y + size.y, ctx |> hdpx(3.))
  let elevationRange = max(0., get_radar_hud_elevation_max() - get_radar_hud_elevation_min())
  let elevationRangeInv = elevationRange != 0. ? 1. / elevationRange : 1.
  let elRange = (1. + get_radar_hud_elevation_min() * elevationRangeInv) * size.y
  ctx |> draw_line(pos.x, pos.y + elRange, pos.x + size.x, pos.y + elRange, ctx |> hdpx(3.))

  color = float4(Color4(is_color_or_white(data.color)))
  color *= 0.42
  let e3dColorGrid = E3DCOLOR(Color4(color))
  ctx |> set_color(e3dColorGrid)
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  let azimuthRangeInv = azimuthRange != 0. ? 1. / azimuthRange : 1.
  var scanAzimuthMaxRel = get_radar_hud_scan_azimuth_max() * azimuthRangeInv
  var scanAzimuthMinRel = get_radar_hud_scan_azimuth_min() * azimuthRangeInv
  if scanAzimuthMaxRel < scanAzimuthMinRel
    scanAzimuthMinRel = -0.5
    scanAzimuthMaxRel =  0.5
  let offset = (0.5 + get_radar_hud_elevation_min() * elevationRangeInv)
  var scanElevationMaxRel = (get_radar_hud_scan_elevation_max() + get_radar_hud_elevation_half_width()) * elevationRangeInv
  var scanElevationMinRel = (get_radar_hud_scan_elevation_min() - get_radar_hud_elevation_half_width()) * elevationRangeInv
  if scanElevationMaxRel < scanElevationMinRel
    scanElevationMinRel = -0.5 + offset
    scanElevationMaxRel =  0.5 + offset
  if azimuthRange != 0.
    let azimuthStep = PI / 12. * azimuthRangeInv
    var azimuth = scanAzimuthMaxRel
    let end = scanAzimuthMinRel
    while azimuth > end
      ctx |> draw_line(pos.x + (0.5 + azimuth) * size.x, pos.y + (0.5 - scanElevationMaxRel + offset) * size.y,
       pos.x + (0.5 + azimuth) * size.x, pos.y + (0.5 - scanElevationMinRel + offset) * size.y, ctx |> hdpx(1.2))
      azimuth -= azimuthStep
  if elevationRange != 0.
    let elevationStep = PI / 12. * elevationRangeInv
    var elevation = scanElevationMaxRel
    let end = scanElevationMinRel
    while elevation > end
      ctx |> draw_line(pos.x + (0.5 + scanAzimuthMinRel) * size.x, pos.y + (0.5 - elevation + offset) * size.y,
       pos.x + (0.5 + scanAzimuthMaxRel) * size.x, pos.y + (0.5 - elevation + offset) * size.y, ctx |> hdpx(1.2))
      elevation -= elevationStep

  ctx |> set_color(e3dColor)
  ctx |> render_frame(pos.x + (0.5 + scanAzimuthMinRel) * size.x, pos.y + (0.5 - scanElevationMaxRel + offset) * size.y,
    pos.x + (0.5 + scanAzimuthMaxRel) * size.x, pos.y + (0.5 - scanElevationMinRel + offset) * size.y, ctx |> hdpx(3.2))


def c_scope_azimuth(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2; azimuth : float; elevation : float;
                    half_azimuth : float; half_elevation : float)
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  let elevationRange = max(0., get_radar_hud_elevation_max() - get_radar_hud_elevation_min())
  let halfAzimuthWidth = (azimuthRange > 0. ? half_azimuth / azimuthRange : 0.) * size.x
  let halfElevationWidth = (elevationRange > 0. ? half_elevation / elevationRange : 0.) * size.y

  var color = float4(Color4(is_color_or_white(data.color)))
  color *= 0.6
  let e3dColor = E3DCOLOR(Color4(color))
  ctx |> set_color(e3dColor)
  let startPos = pos + float2(azimuth * size.x, (1. - elevation) * size.y)
  let azimuthMark <- to_array_move([[float2[]
    startPos + float2(-halfAzimuthWidth, -halfElevationWidth);
    startPos + float2(halfAzimuthWidth, -halfElevationWidth);
    startPos + float2(halfAzimuthWidth, halfElevationWidth);
    startPos + float2(-halfAzimuthWidth, halfElevationWidth);
  ]])
  ctx |> render_poly(azimuthMark, e3dColor)
  ctx |> render_line_aa(azimuthMark, true, ctx |> hdpx(1.2), float2(0., 0.), data.color)

def c_scope_targets(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  foreach_targets() <| $(var target; i)
    let azimuth = get_radar_hud_has_azimuth_scale() ? target.azimuthRel : 0.
    let azimuthLeft = azimuth - target.azimuthWidthRel * 0.5
    let elevationWidthRel = max(0.04, target.elevationWidthRel)
    let elevationLowerRel = target.elevationRel - elevationWidthRel * 0.5
    var inSelectedTargetRangeGate = false
    if get_radar_hud_has_distance_scale()
      if !get_radar_hud_cue_visible()
        if !target.isDetected
          foreach_targets() <| $(var second_target; j)
            if i != j && second_target.isDetected && abs(target.distanceRel - second_target.distanceRel) < 0.05
              inSelectedTargetRangeGate = true
              return
      else
        inSelectedTargetRangeGate = abs(target.distanceRel - get_radar_hud_cue_distance() * get_radar_hud_target_distance()) < 0.5 * get_radar_hud_cue_dist_width_rel()
    else
      inSelectedTargetRangeGate = true

    if !inSelectedTargetRangeGate
      return

    let signalRel = target.signalRel < 0.01 ? 0. : cvt(target.signalRel, 0.05, 1., 0.3, 1.)
    var color = float4(Color4(is_color_or_white(data.color)))
    color *= (1. - target.ageRel) * signalRel
    let e3dColor = E3DCOLOR(Color4(color))
    ctx |> set_color(e3dColor)

    let tc = float2(0., 0.)
    let lt = pos + float2(azimuthLeft * size.x, (1. - elevationLowerRel) * size.y)
    let rb = lt + float2(target.azimuthWidthRel * size.x, -elevationWidthRel * size.y)
    ctx |> render_rect(lt.x, lt.y, rb.x, rb.y, tc, tc, tc)

    let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
    let azimuthRangeInv = azimuthRange != 0. ? 1. / azimuthRange : 1.
    let azimuthGateWidthRel = angularGateWidthMultSquare * 2. * max(get_radar_hud_azimuth_half_width(), angularGateBeamWidthMin) * azimuthRangeInv
    let azimuthGateLeft = (azimuth - 0.5 * azimuthGateWidthRel) * size.x
    let azimuthGateRight = (azimuth + 0.5 * azimuthGateWidthRel) * size.x
    let elevationRange = max(0., get_radar_hud_elevation_max() - get_radar_hud_elevation_min())
    let elevationRangeInv = elevationRange != 0. ? 1. / elevationRange : 1.
    let elevationGateWidthRel = angularGateWidthMultSquare * 2. * max(get_radar_hud_elevation_half_width(), angularGateBeamWidthMin) * elevationRangeInv
    let elevationGateLower = (1. - target.elevationRel + 0.5 * elevationGateWidthRel) * size.y
    let elevationGateUpper = (1. - target.elevationRel - 0.5 * elevationGateWidthRel) * size.y
    if target.isDetected || target.isSelected
      let lcoord <- to_array_move([[float2[2] pos + float2(azimuthGateLeft, elevationGateLower);
        pos + float2(azimuthGateLeft, elevationGateUpper)]])
      ctx |> render_line_aa(lcoord, false, ctx |> hdpx(3.), float2(0, 0), e3dColor)
      let rcoord <- to_array_move([[float2[2] pos + float2(azimuthGateRight, elevationGateLower);
        pos + float2(azimuthGateRight, elevationGateUpper)]])
      ctx |> render_line_aa(rcoord, false, ctx |> hdpx(3.), float2(0, 0), e3dColor)
    if target.isSelected //animation ?
      let bcoord <- to_array_move([[float2[2] pos + float2(azimuthGateLeft, elevationGateLower);
        pos + float2(azimuthGateRight, elevationGateLower)]])
      ctx |> render_line_aa(bcoord, false, ctx |> hdpx(3.), float2(0, 0), e3dColor)
      let tcoord <- to_array_move([[float2[2] pos + float2(azimuthGateLeft, elevationGateUpper);
        pos + float2(azimuthGateRight, elevationGateUpper)]])
      ctx |> render_line_aa(tcoord, false, ctx |> hdpx(3.), float2(0, 0), e3dColor)

def c_scope_cue(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  if !get_radar_hud_cue_visible()
    return
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  let azimuthHalfWidth = get_radar_hud_cue_azimuth_half_width_rel()
  let lt = pos + float2(get_radar_hud_cue_azimuth() * max(get_radar_hud_target_azimuth_width() / azimuthRange - get_radar_hud_cue_azimuth_half_width_rel(), 0.) * size.x, 0.)
  ctx |> set_color(data.color)
  ctx |> draw_line(lt.x + (0.5 - azimuthHalfWidth) * size.x, lt.y, lt.x + (0.5 - azimuthHalfWidth) * size.x, lt.y + size.y, 2.)
  ctx |> draw_line(lt.x + (0.5 + azimuthHalfWidth) * size.x, lt.y, lt.x + (0.5 + azimuthHalfWidth) * size.x, lt.y + size.y, 2.)

def c_scope_inner_labels(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize/*hudFontHgt*/)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize);
  ctx |> set_color(data.color)
  ctx |> set_draw_str_attr(FontFxType FFT_GLOW, 0, 0, get_font_fx_color(data.color), get_font_fx_factor(data.color, ctx))

  let azMinText = format("%.f", floor(rad_to_deg(get_radar_hud_azimuth_min()) + 0.5)) + loc("measureUnits/deg")
  let strBoxAzMin = get_str_bbox(azMinText, azMinText |> length(), fctx)
  ctx |> goto_xy(pos.x + ctx |> hdpx(4.), pos.y + strBoxAzMin.width.y + ctx |> hdpx(4.))
  ctx |> draw_str_scaled(1.0, azMinText, azMinText |> length())

  let azMaxText = format("%.f", floor(rad_to_deg(get_radar_hud_azimuth_min()) + 0.5)) + loc("measureUnits/deg")
  let strBoxAzMax = get_str_bbox(azMaxText, azMaxText |> length(), fctx)
  ctx |> goto_xy(pos.x + size.x - strBoxAzMax.width.x - ctx |> hdpx(4.), pos.y + strBoxAzMax.width.y + ctx |> hdpx(4.))
  ctx |> draw_str_scaled(1.0, azMaxText, azMaxText |> length())

def b_scope_square_aviahorizont(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed
    return
  let fmw = hero |> as_fmw()
  if fmw == null
    return

  ctx |> setRotViewTm(pos.x + size.x * 0.5, pos.y + size.y * 0.5, deg_to_rad(fmw.roll), 0., false)

  let linePtsLeft <- to_array_move([[float2[]
    float2(pos.x + size.x * 0.2, pos.y + size.y * 0.52);
    float2(pos.x + size.x * 0.2, pos.y + size.y * 0.5);
    float2(pos.x + size.x * 0.45, pos.y + size.y * 0.5);
  ]])

  let linePtsRight <- to_array_move([[float2[]
    float2(pos.x + size.x * 0.8, pos.y + size.y * 0.52);
    float2(pos.x + size.x * 0.8, pos.y + size.y * 0.5);
    float2(pos.x + size.x * 0.55, pos.y + size.y * 0.5);
  ]])

  ctx |> render_line_aa(linePtsLeft, false, 2.0 * data.lineWidth, float2(0., 0.), data.lineColor)
  ctx |> render_line_aa(linePtsRight, false, 2.0 * data.lineWidth, float2(0., 0.), data.lineColor)

  ctx |> resetViewTm()

def draw_additional_net(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  if data.netRowCnt <= 0
    return
  ctx |> set_color(data.netColor)
  ctx |> render_frame(pos.x, pos.y, pos.x + size.x, pos.y + size.y, ctx |> hdpx(1.8 * data.lineWidth))

  for i in range(1, data.netRowCnt)
    if data.netRowCnt % 2 == 0 && i == data.netRowCnt / 2
      ctx |> draw_line(pos.x + float(i) / float(data.netRowCnt) * size.x, pos.y, pos.x + float(i) / float(data.netRowCnt) * size.x, pos.y + size.y * 0.4, 3. * data.lineWidth)
      ctx |> draw_line(pos.x + float(i) / float(data.netRowCnt) * size.x, pos.y + size.y * 0.6, pos.x + float(i) / float(data.netRowCnt) * size.x, pos.y + size.y, 3. * data.lineWidth)
    else
      ctx |> draw_line(pos.x + float(i) / float(data.netRowCnt) * size.x, pos.y, pos.x + float(i) / float(data.netRowCnt) * size.x, pos.y + size.y, 3. * data.lineWidth)
    if data.netRowCnt % 2 == 0 && i == data.netRowCnt / 2
      ctx |> draw_line(pos.x, pos.y + float(i) / float(data.netRowCnt) * size.y, pos.x + size.x * 0.4, pos.y + float(i) / float(data.netRowCnt) * size.y, 3. * data.lineWidth)
      ctx |> draw_line(pos.x + size.x * 0.6, pos.y + float(i) / float(data.netRowCnt) * size.y, pos.x + size.x, pos.y + float(i) / float(data.netRowCnt) * size.y, 3. * data.lineWidth)
    else
      ctx |> draw_line(pos.x, pos.y + float(i) / float(data.netRowCnt) * size.y, pos.x + size.x, pos.y + float(i) / float(data.netRowCnt) * size.y, 3. * data.lineWidth)