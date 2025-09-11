require darg
require DagorStdGuiRender
require DagorMath
require RadarHud
require FlightControl
require strings
require HeroManager
require Unit
require FlightModelWrap
require math
require GamePhys
require %rGui.utils.radar_common

let white = E3DCOLOR(Color4(float4(1.0, 1.0, 1.0, 1.)))
let red = E3DCOLOR(Color4(float4(1., 0., 0., 1.)))
let green = E3DCOLOR(Color4(float4(0., 1., 0., 1.)))
let transparentColor = E3DCOLOR(Color4(float4(0., 0., 0., 0.)))

let kmToNm = 1.0 / 1.85
let speedMaxInv = 1.0 / 700.0

struct CanvasParams
  color : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  fontId : int = -1
  fontSize : int = 20
  useArea : float4 = float4(0., 0., 1., 1.)
  lineWidth : float = 1.

[export]
def setup_radar_data(props : Properties&; var storage : CanvasParams&)
  storage.color = props |> getColor("color", E3DCOLOR(0xFFFFFFFF))
  storage.fontId = props |> getFontId()
  storage.fontSize = props |> getInt("fontSize", 20)
  storage.useArea = float4(0.13, 0., 0.87, 1.0)
  storage.lineWidth = props |> getFloat("lineWidth", 1.) * 1.

[export, unused_argument(rstate)]
def draw_radar_hud(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  if !get_radar_hud_mfd_radar_enabled()
    return

  let pos = rdata.pos + float2(data.useArea.x * rdata.size.x, data.useArea.y * rdata.size.y)
  let size = float2(rdata.size.x * (data.useArea.z - data.useArea.x), rdata.size.y * (data.useArea.w - data.useArea.y))

  let azimuthSectorPos = pos + float2(size.x * 0.05, size.y * 0.1)
  let azimuthSectorSize = float2(size.x * 0.9, size.y * 0.85)
  draw_round_radar(ctx, data, azimuthSectorPos, azimuthSectorSize)

  let separator <- to_array_move(fixed_array<float2>(pos + float2(-size.x * 0.1, size.y * 0.65), pos + float2(size.x * 1.1, size.y * 0.65)))
  ctx |> render_line_aa(separator, false, data.lineWidth, float2(0., 0.), radarScanZoneAzimuthColor)

  let elevationSectorPos = pos + float2(size.x * 0.05, size.y * 0.23)
  let elevationSectorSize = float2(size.x * 1.0, size.y * 0.85)
  draw_rectangle_radar(ctx, data, elevationSectorPos, elevationSectorSize)

let allyColor = green
let enemyColor = red

def draw_targets(var ctx : GuiContext&; data : CanvasParams&; origin : float2; size : float2)
  let radius = size.y * 0.5
  let vectorLenMax = radius * 0.2
  let shapeRadius = size * 0.02

  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())

  Radar`foreach_visible_target() <| $(var target)
    if target.targetType == int(RadarTargetType.TYPE_TARGET)
      var distanceRel = 0.9
      var radialWidthRel = 0.05
      if get_radar_hud_has_distance_scale() && target.distanceRel >= 0.
        distanceRel = target.distanceRel
        radialWidthRel = max(target.distanceWidthRel, 0.05)

      var angle = -PI * 0.5
      if get_radar_hud_has_azimuth_scale()
        angle = get_radar_hud_azimuth_min() + azimuthRange * target.azimuthRel - PI * 0.5

      let targetColor = E3DCOLOR(Color4(!target.isEnemy ? allyColor : enemyColor))
      ctx |> set_color(targetColor)

      let sina = sin(angle)
      let cosa = cos(angle)
      let pos = origin + float2(cosa * distanceRel * radius, sina * distanceRel * radius)
      if target.isSelected && get_radar_hud_has_azimuth_scale() && target.losSpeed < 30000.0
        let losAngle = atan2(target.losHorSpeed, -target.losSpeed)
        ctx |> setRotViewTm(pos.x, pos.y, losAngle, 0., false)

        let los = sqrt(target.losSpeed * target.losSpeed + target.losHorSpeed * target.losHorSpeed) * speedMaxInv * vectorLenMax
        let spd <- to_array_move(fixed_array<float2>(pos, pos + float2(0., los)))
        ctx |> render_line_aa(spd, false, data.lineWidth, float2(0, 0), targetColor)

        if target.isEnemy
          let shape <- to_array_move(fixed_array<float2>(pos + float2(-shapeRadius.x, -shapeRadius.y), pos, pos + float2(shapeRadius.x, -shapeRadius.y)))
          if target.isDetected || target.isTracked
            ctx |> render_poly(shape, targetColor)
          else
            ctx |> render_line_aa(shape, false, data.lineWidth, float2(0, 0), targetColor)
        else
          ctx |> render_sector_aa(pos + float2(0.0, -shapeRadius.y), shapeRadius, float2(0, PI), 1., targetColor, target.isDetected || target.isTracked ? targetColor : transparentColor)
        ctx |> resetViewTm()
      else
        ctx |> render_ellipse_aa(pos, float2(shapeRadius.y), 1., targetColor, target.isDetected || target.isTracked ? targetColor : transparentColor)

let compassColor = white

def draw_compass(var ctx : GuiContext&; data : CanvasParams&; origin : float2; radius : float; compass : float)

  ctx |> set_color(compassColor)
  ctx |> render_sector_aa(origin, float2(radius), float2(PI, 2.0 * PI), data.lineWidth, compassColor, transparentColor)

  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, 15)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(15)
  for i in range(-9, 10)
    let markVal = (int(compass) / 10) * 10 + i * 10
    let diff = (compass - float(markVal)) * PI / 180.
    let markDir = float2(-sin(diff), -cos(diff))
    let markPos1 = origin + markDir * radius
    let markPos2 = origin + markDir * radius * 0.95
    let markCoord <- to_array_move(fixed_array<float2>(markPos1,
      markPos2))
    ctx |> render_line_aa(markCoord, false, data.lineWidth, float2(0., 0.), compassColor)
    let azimuth = floori(norm_ang_deg(float(markVal)))
    if azimuth % 30 == 0
      var text = ""
      if azimuth == 0
        text = "N"
      elif azimuth == 90
        text = "E"
      elif azimuth == 180
        text = "S"
      elif azimuth == 270
        text = "W"
      else
        text = fmt(":02d", azimuth / 10)
      let markStrBox = get_str_bbox(text, text |> length(), fctx)
      let markTextDist = ctx |> hdpx(7.0)
      ctx |> goto_xy(markPos2.x - markDir.x * markTextDist - 0.5 * markStrBox.width.x, markPos2.y - markDir.y * markTextDist + 0.5 * markStrBox.width.y)
      ctx |> draw_str_scaled(1.0, text, text |> length())

let ownShipColor = white
let radarScanZoneAzimuthColor = white
let radarScanZoneElevationMarksColor = green
let radarInnerRingColor = red
let radarSpiColor = red
let radarInfoColor = white

def draw_round_radar(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  let radius = size.y * 0.5
  let radius2 = float2(radius)
  let origin = pos + size * 0.5

  let ownShipRadius = float2(0.02, 0.05) * radius
  let ownShip <- to_array_move(fixed_array<float2>(origin + float2(0, -ownShipRadius.y), origin, origin + float2(-ownShipRadius.x, ownShipRadius.y), origin + float2(ownShipRadius.x, ownShipRadius.y), origin))
  ctx |> render_line_aa(ownShip, false, data.lineWidth, float2(0., 0.), ownShipColor)

  let elevationRangeInv = 1.0 / max(get_radar_hud_elevation_max() - get_radar_hud_elevation_min(), 0.0)
  let elevationMarks = fixed_array(-60.0, -40.0, -20.0, -10.0, -5.0, 0.0, 5.0, 10.0, 20.0, 40.0, 60.0)
  let elevationScaleHalfSize = size.y * 0.5
  let elevationMarkLen = radius * 0.07
  for elevationMark in elevationMarks
    let elevationMarkLine <- to_array_move(fixed_array<float2>(origin + float2(-radius + size.x * 0.1, -0.25 * size.y + elevationMark * PI / 180.0 * elevationRangeInv * elevationScaleHalfSize), origin + float2(-radius + size.x * 0.1 - elevationMarkLen, -0.25 * size.y + elevationMark * PI / 180.0 * elevationRangeInv * elevationScaleHalfSize)))
    ctx |> render_line_aa(elevationMarkLine, false, data.lineWidth, float2(0., 0.), radarScanZoneElevationMarksColor)
  let tc = float2(0., 0.)

  let elevationZoneLen = 0.5 * elevationMarkLen
  let scanElevationMin = get_radar_hud_scan_elevation_min()
  let scanElevationMax = get_radar_hud_scan_elevation_max()
  if (scanElevationMax - scanElevationMin > 0.01)
    ctx |> set_color(radarScanZoneElevationMarksColor)
    ctx |> render_rect(origin.x - radius + size.x * 0.15, origin.y - 0.25 * size.y - scanElevationMin * elevationRangeInv * elevationScaleHalfSize,
      origin.x - radius + size.x * 0.15 - elevationZoneLen, origin.y - 0.25 * size.y - scanElevationMax * elevationRangeInv * elevationScaleHalfSize, tc, tc, tc)

  let scanAzimuthMin = get_radar_hud_scan_azimuth_min()
  let scanAzimuthMax = get_radar_hud_scan_azimuth_max()
  if (scanAzimuthMax - scanAzimuthMin > 0.01)
    let scanSectorLeftDir = float2(cos(scanAzimuthMin + PI * 0.5), sin(scanAzimuthMin + PI * 0.5))
    let scanSectorLeft <- to_array_move(fixed_array<float2>(origin - scanSectorLeftDir * 0.2 * radius, origin - scanSectorLeftDir * 1.1 * radius))
    ctx |> render_line_aa(scanSectorLeft, false, data.lineWidth, float2(0., 0.), radarScanZoneAzimuthColor)
    let scanSectorRightDir = float2(cos(scanAzimuthMax + PI * 0.5), sin(scanAzimuthMax + PI * 0.5))
    let scanSectorRight <- to_array_move(fixed_array<float2>(origin - scanSectorRightDir * 0.2 * radius, origin - scanSectorRightDir * 1.1 * radius))
    ctx |> render_line_aa(scanSectorRight, false, data.lineWidth, float2(0., 0.), radarScanZoneAzimuthColor)
    ctx |> render_sector_aa(origin, radius2 * 1.1, float2(scanAzimuthMin - PI * 0.5, scanAzimuthMax - PI * 0.5), data.lineWidth, radarScanZoneAzimuthColor, transparentColor)

  draw_targets(ctx, data, origin, size)

  let spiRadius = 0.02 * radius
  var spiPos : float3
  if get_point_of_interest(spiPos)
    let hero = get_controlled_hero()
    if hero != null && !hero.isDelayed
      let dirToSpi = spiPos - hero.unitTm[3]
      let dirToSpi2 = float2(dirToSpi.x, dirToSpi.z)
      let fwd = normalize(float2(hero.unitTm[0].x, hero.unitTm[0].z))
      let left = float2(fwd.y, -fwd.x)
      let spiScreenPos = origin + float2(dot(left, dirToSpi2), -dot(fwd, dirToSpi2)) / (get_radar_hud_distance_max() * 1000.0) * radius

      let spiShape1 <- to_array_move(fixed_array<float2>(spiScreenPos - float2(-spiRadius, -spiRadius), spiScreenPos - float2(spiRadius,  spiRadius)))
      ctx |> render_line_aa(spiShape1, false, data.lineWidth, float2(0., 0.), radarSpiColor)
      let spiShape2 <- to_array_move(fixed_array<float2>(spiScreenPos - float2(-spiRadius,  spiRadius), spiScreenPos - float2(spiRadius, -spiRadius)))
      ctx |> render_line_aa(spiShape2, false, data.lineWidth, float2(0., 0.), radarSpiColor)

  if get_radar_hud_cue_visible()
    let cueAzimuthHalfWidthRel = get_radar_hud_cue_azimuth_half_width_rel()
    let designationAzimuthWidth = get_radar_hud_target_azimuth_width() * (1.0 - 2.0 * cueAzimuthHalfWidthRel)
    let cueAzimuthRel = get_radar_hud_cue_azimuth()
    let cueAzimuthLeft  = (cueAzimuthRel - cueAzimuthHalfWidthRel) * designationAzimuthWidth
    let cueAzimuthRight = (cueAzimuthRel + cueAzimuthHalfWidthRel) * designationAzimuthWidth

    let cueDistRel = get_radar_hud_cue_distance()
    let cueDistHalfWidthRel = 0.5 * get_radar_hud_cue_dist_width_rel()
    let cueRadiusNear = (cueDistRel - cueDistHalfWidthRel) * radius
    let cueRadiusFar  = (cueDistRel + cueDistHalfWidthRel) * radius

    let cueLeftDir = float2(cos(cueAzimuthLeft + PI * 0.5), sin(cueAzimuthLeft + PI * 0.5))
    let cueLeft <- to_array_move(fixed_array<float2>(origin - cueLeftDir * cueRadiusNear, origin - cueLeftDir * cueRadiusFar))
    ctx |> render_line_aa(cueLeft, false, data.lineWidth, float2(0., 0.), radarScanZoneAzimuthColor)
    let cueRightDir = float2(cos(cueAzimuthRight + PI * 0.5), sin(cueAzimuthRight + PI * 0.5))
    let cueRight <- to_array_move(fixed_array<float2>(origin - cueRightDir * cueRadiusNear, origin - cueRightDir * cueRadiusFar))
    ctx |> render_line_aa(cueRight, false, data.lineWidth, float2(0., 0.), radarScanZoneAzimuthColor)

  ctx |> set_color(radarInfoColor)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(15)

  let distMaxStr = "{fmt(": 3d", roundi(get_radar_hud_distance_max() * kmToNm))} NM"
  ctx |> goto_xy(pos.x + size.x * 1.0, pos.y + size.y * 0.05)
  ctx |> draw_str_scaled(1.5, distMaxStr, distMaxStr |> length())

  var compass = 0.
  let hero = get_controlled_hero()
  if hero != null && !hero.isDelayed
    compass = (norm_ang(2. * PI + atan2(hero.unitTm[0].x, hero.unitTm[0].z))) * 180. / PI
  let compassBoundingRadius = radius * 1.1
  ctx |> set_viewport(origin.x - compassBoundingRadius, origin.y - compassBoundingRadius, origin.x + compassBoundingRadius, origin.y + size.y * 0.1)
  draw_compass(ctx, data, origin, radius * 1.0, compass)
  ctx |> restore_viewport()

  ctx |> render_sector_aa(origin, radius2 * 0.5, float2(PI, 2.0 * PI), data.lineWidth, radarInnerRingColor, transparentColor)

  let lowerBorder <- to_array_move(fixed_array<float2>(origin + float2(-radius2.x, 0.0), origin + float2(-radius2.x, size.y * 0.1), origin + float2(radius2.x, size.y * 0.1), origin + float2(radius2.x, 0.0)))
  ctx |> render_line_aa(lowerBorder, false, data.lineWidth, float2(0., 0.), radarScanZoneAzimuthColor)

def draw_targets_hei(var ctx : GuiContext&; data : CanvasParams&; origin : float2; size : float2)
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed
    return

  let radius = size.y * 0.5
  let vectorLenMax = radius * 0.2
  let shapeRadius = float2(size.y, size.x) * 0.05

  let distMax = get_radar_hud_distance_max()
  let maxHei = size.y / size.x * distMax * 1000.

  Radar`foreach_visible_target() <| $(var target)
    if target.targetType == int(RadarTargetType.TYPE_TARGET)
      var distanceRel = 0.9
      var heiRel = 0.
      if get_radar_hud_has_distance_scale() && target.distanceRel >= 0.
        distanceRel = target.distanceRel
        if distMax > 0.
          heiRel = (target.height - hero.pos.y) / maxHei

      let targetColor = E3DCOLOR(Color4(!target.isEnemy ? allyColor : enemyColor))
      ctx |> set_color(targetColor)

      let pos = origin + float2(distanceRel * size.x, -heiRel * size.y)

      if target.isSelected && get_radar_hud_has_azimuth_scale() && target.losSpeed < 30000.0
        let losAngle = atan2(distanceRel * distMax * 1000.0, target.height - hero.pos.y) + atan2(target.losVerSpeed, -target.losSpeed)
        ctx |> setRotViewTm(pos.x, pos.y, losAngle, 0., false)

        let los = sqrt(target.losSpeed * target.losSpeed + target.losHorSpeed * target.losHorSpeed) * speedMaxInv * vectorLenMax
        let spd <- to_array_move(fixed_array<float2>(pos, pos + float2(0., los)))
        ctx |> render_line_aa(spd, false, data.lineWidth, float2(0, 0), targetColor)

        if target.isEnemy
          let shape <- to_array_move(fixed_array<float2>(pos + float2(-shapeRadius.x, -shapeRadius.y), pos, pos + float2(shapeRadius.x, -shapeRadius.y)))
          if target.isDetected || target.isTracked
            ctx |> render_poly(shape, targetColor)
          else
            ctx |> render_line_aa(shape, false, data.lineWidth, float2(0, 0), targetColor)
        else
          ctx |> render_sector_aa(pos + float2(0.0, -shapeRadius.y), shapeRadius, float2(0, PI), 1., targetColor, target.isDetected || target.isTracked ? targetColor : transparentColor)
        ctx |> resetViewTm()
      else
        ctx |> render_ellipse_aa(pos, float2(shapeRadius.x), 1., targetColor, target.isDetected || target.isTracked ? targetColor : transparentColor)

let radarElevationVerticalColor = white
let radarElevationGridColor = green
let radarScanZoneElevationColor = white

def draw_rectangle_radar(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)

  let origin = pos + float2(0.0, size.y * 0.5)

  let verticalSize = float2(size.x * 0.85, size.y * 0.3)
  let vertical <- to_array_move(fixed_array<float2>(origin + float2(size.x - verticalSize.x, 0.0), origin + float2(size.x - verticalSize.x, verticalSize.y)))
  ctx |> render_line_aa(vertical, false, data.lineWidth, float2(0., 0.), radarElevationVerticalColor)

  let plotSize = float2(size.x * 0.75, size.y * 0.25)
  let plotOrigin = origin + float2(size.x - plotSize.x, (verticalSize.y - plotSize.y) * 0.5 + plotSize.y)

  let altitudeDistanceCorner <- to_array_move(fixed_array<float2>(origin + float2(size.x - plotSize.x, (verticalSize.y - plotSize.y) * 0.5),
    origin + float2(size.x - plotSize.x, (verticalSize.y - plotSize.y) * 0.5 + plotSize.y),
    origin + float2(size.x, (verticalSize.y - plotSize.y) * 0.5 + plotSize.y)))
  ctx |> render_line_aa(altitudeDistanceCorner, false, data.lineWidth, float2(0., 0.), radarElevationGridColor)

  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, 12)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(12)
  ctx |> set_color(radarElevationGridColor)

  for i in range(-1, 3)
    let rangeMarkPos = float2(plotOrigin.x + (0.25 + float(i) * 0.25) * plotSize.x, plotOrigin.y)
    let rangeMark <- to_array_move(fixed_array<float2>(rangeMarkPos, rangeMarkPos + float2(0, -size.y * 0.02)))
    ctx |> render_line_aa(rangeMark, false, data.lineWidth, float2(0., 0.), radarElevationGridColor)

    let distMaxStr = "{fmt(":d", roundi(get_radar_hud_distance_max() * (0.25 + float(i) * 0.25) * kmToNm))}"
    let distMaxStrBox = get_str_bbox(distMaxStr, distMaxStr |> length(), fctx)
    ctx |> goto_xy(plotOrigin.x + (0.25 + float(i) * 0.25) * plotSize.x - 0.5 * distMaxStrBox.width.x, plotOrigin.y + distMaxStrBox.width.y)
    ctx |> draw_str_scaled(1.0, distMaxStr, distMaxStr |> length())

  let altMax = get_radar_hud_distance_max() / 1.6
  let altMaxStr = "{fmt(":d", roundi(altMax * kmToNm))}"
  let altMaxStrBox = get_str_bbox(altMaxStr, altMaxStr |> length(), fctx)
  ctx |> goto_xy(plotOrigin.x - altMaxStrBox.width.x, plotOrigin.y - plotSize.y + altMaxStrBox.width.y)
  ctx |> draw_str_scaled(1.0, altMaxStr, altMaxStr |> length())

  let hero = get_controlled_hero()
  if hero != null && !hero.isDelayed
    let ownAlt = hero.unitTm[3].y
    let ownShipPos = plotOrigin + float2(0, -min(ownAlt / altMax * 0.001, 1.0) * plotSize.y)

    let ownShipRadius = float2(0.03, 0.01) * size.y
    let ownShip <- to_array_move(fixed_array<float2>(ownShipPos + float2(ownShipRadius.x, 0), ownShipPos, ownShipPos + float2(-ownShipRadius.x, -ownShipRadius.y), ownShipPos + float2(-ownShipRadius.x, ownShipRadius.y), ownShipPos))
    ctx |> render_line_aa(ownShip, false, data.lineWidth, float2(0., 0.), ownShipColor)

    var pitch = 0.0
    let fmw = hero |> as_fmw()
    if fmw != null
      pitch = -fmw.tangage * PI / 180.0

    ctx |> set_viewport(plotOrigin.x, plotOrigin.y, plotOrigin.x + plotSize.x, plotOrigin.y - plotSize.y)

    let scanElevationMin = get_radar_hud_scan_elevation_min()
    let scanElevationMax = get_radar_hud_scan_elevation_max()
    if scanElevationMax - scanElevationMin > 0.01
      let scanElevationRange = float2(pitch - scanElevationMin, pitch - scanElevationMax)
      let scanElevationMinDir = float2(cos(scanElevationRange.x), sin(scanElevationRange.x))
      let scanElevationMinLine <- to_array_move(fixed_array<float2>(ownShipPos + scanElevationMinDir * plotSize.x * 0.2, ownShipPos + scanElevationMinDir * plotSize.x))
      ctx |> render_line_aa(scanElevationMinLine, false, data.lineWidth, float2(0., 0.), radarScanZoneElevationColor)
      let scanElevationMaxDir = float2(cos(scanElevationRange.y), sin(scanElevationRange.y))
      let scanElevationMaxLine <- to_array_move(fixed_array<float2>(ownShipPos + scanElevationMaxDir * plotSize.x * 0.2, ownShipPos + scanElevationMaxDir * plotSize.x))
      ctx |> render_line_aa(scanElevationMaxLine, false, data.lineWidth, float2(0., 0.), radarScanZoneElevationColor)

    draw_targets_hei(ctx, data, ownShipPos, plotSize)

    ctx |> restore_viewport()