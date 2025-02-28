// Based on hmdA10c.das
require darg
require DagorStdGuiRender
require DagorMath
require math
require Plane
require FlightModelWrap
require HeroManager
require Unit
require strings
require app
require WTCamera
require hud
require DagorMathUtils
require FlightControl
require DagorSystem
require DagorStdGuiRender
require Mission

let transparentColor = E3DCOLOR(Color4(float4(0, 0, 0, 0)))
let mpsToKnots = 1.94384
let metrToFeet = 3.28084

def rad_to_deg(rad : float)
  return rad * 180. / PI

struct CanvasParams
  color : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  fontId : int = -1
  fontSize : int = 20
  lineWidth : float = 2.

[export]
def setup_hmd_data(props : Properties&; var storage : CanvasParams&)
  storage.color = props |> getColor("color", E3DCOLOR(0xFFFFFFFF))
  storage.fontId = props |> getFontId()
  storage.fontSize = props |> getInt("fontSize", 20)
  storage.lineWidth = props |> getFloat("lineWidth", 2.)

[export, unused_argument(rstate)]
def draw_hmd(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed
    return
  let fmw = hero |> as_fmw()
  if fmw == null
    return
  draw_ias(ctx, rdata, data, fmw)
  draw_forestall(ctx, rdata, data)
  draw_bar_alt(ctx, rdata, data, hero)
  draw_ralt(ctx, rdata, data, fmw)
  draw_horizont(ctx, rdata, data, hero)
  draw_hmd_azimuth(ctx, rdata, data)
  draw_plane_azimuth(ctx, rdata, data, hero)
  draw_aim_lock(ctx, rdata, data)
  draw_plane_marks(ctx, rdata, data, hero)
  draw_laser_indicator(ctx, rdata, data, fmw)
  draw_ir_aam_seeker(ctx, rdata, data)

def draw_forestall(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&)
  ctx |> set_color(data.color)
  let size = rdata.size.y * 0.02
  ctx |> draw_line(rdata.pos.x + rdata.size.x * 0.5 - size, rdata.pos.y + rdata.size.y * 0.5,
   rdata.pos.x + rdata.size.x * 0.5 + size, rdata.pos.y + rdata.size.y * 0.5, ctx |> hdpx(data.lineWidth))
  ctx |> draw_line(rdata.pos.x + rdata.size.x * 0.5, rdata.pos.y + rdata.size.y * 0.5 - size,
   rdata.pos.x + rdata.size.x * 0.5, rdata.pos.y + rdata.size.y * 0.5 + size, ctx |> hdpx(data.lineWidth))

def draw_ias(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&; fmw : FlightModelWrap?)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)

  ctx |> set_color(data.color)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)

  let iasStr = fmt(":d", roundi(fmw.ias * mpsToKnots))
  let strBox = get_str_bbox(iasStr, iasStr |> length(), fctx)
  ctx |> goto_xy(rdata.pos.x + rdata.size.x * 0.38 - strBox.width.x, rdata.pos.y + rdata.size.y * 0.5)
  ctx |> draw_str_scaled(1.0, iasStr, iasStr |> length())

def draw_bar_alt(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&; hero : Unit?)
  ctx |> set_color(data.color)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)

  let altStr = fmt(":d", roundi(hero.pos.y * metrToFeet))
  ctx |> goto_xy(rdata.pos.x + rdata.size.x * 0.62, rdata.pos.y + rdata.size.y * 0.5)
  ctx |> draw_str_scaled(1.0, altStr, altStr |> length())

def draw_ralt(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&; fmw : FlightModelWrap?)
  ctx |> set_color(data.color)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(int(float(data.fontSize) * 0.9));

  let altStr = "{fmt(":d", roundi(fmw.fm.currentAlt * metrToFeet))}R"
  ctx |> goto_xy(rdata.pos.x + rdata.size.x * 0.62, rdata.pos.y + rdata.size.y * 0.65)
  ctx |> draw_str_scaled(1.0, altStr, altStr |> length())

def draw_horizont(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&; hero : Unit?)
  let app = get_app()
  if app == null || app.flightControlMode == null
    return
  let camera = app.flightControlMode.cameraControl.cur
  if camera == null
    return
  ctx |> set_color(data.color)
  let lookDir = normalize(camera.viewData.lookAt - camera.viewData.lookFrom)
  let horDir = normalize(float3(lookDir.x, 0., lookDir.z))
  let normalDir = cross(horDir, float3(0., 1., 0.))
  var worldPos = hero.unitTm * camera.viewData.lookFrom
  worldPos.y = 0.
  let horizontPoint1 = worldPos + horDir * 100000. + normalDir * 50000.
  let horizontPoint2 = worldPos + horDir * 100000. - normalDir * 50000.
  var hmdPos1 : float2
  var hmdPos2 : float2
  if world_to_hmd_screen(horizontPoint1, hmdPos1) && world_to_hmd_screen(horizontPoint2, hmdPos2)
    if hmdPos1.y < rdata.size.y * 0.75 && hmdPos2.y < rdata.size.y * 0.75 && hmdPos1.y > rdata.size.y * 0.25 && hmdPos2.y > rdata.size.y * 0.25
      ctx |> draw_line(hmdPos1.x, hmdPos1.y, hmdPos2.x, hmdPos2.y, ctx |> hdpx(data.lineWidth))
    else
      let dir = hmdPos2 - hmdPos1
      let newP1 = float2(hmdPos1.x, clamp(hmdPos1.y, rdata.size.y * 0.25, rdata.size.y * 0.75))
      let newP2 = newP1 + dir
      ctx |> render_line_dashed(newP1, newP2, ctx |> hdpx(15.), ctx |> hdpx(10.), ctx |> hdpx(data.lineWidth), data.color)

  var fctx : StdGuiFontContext
  let fontSize = int(float(data.fontSize) * 0.9)
  get_font_context(fctx, data.fontId, 0, 0, fontSize)
  ctx |> set_color(data.color)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(fontSize)

  let startStep = roundi(dir_to_angles(lookDir).y / (PI * 0.5) * 9.)
  for i in range(-2, 3)
    if startStep + i == 0
      continue
    let angle = PI / 18. * float(startStep + i)
    let anglePoint = hero.unitTm * camera.viewData.lookFrom + (float3(0, sin(angle), 0) + horDir * cos(angle)) * 1000.
    var hmdAngPos : float2
    if !world_to_hmd_screen(anglePoint, hmdAngPos)
      continue

    let p1 = anglePoint - normalDir * 100.;
    let p2 = anglePoint + normalDir * 100.;
    var hmdAngPos1 : float2
    var hmdAngPos2 : float2
    world_to_hmd_screen(p1, hmdAngPos1)
    world_to_hmd_screen(p2, hmdAngPos2)
    let dir = hmdAngPos2 - hmdAngPos1
    let rightPoint = hmdAngPos1 + dir * 0.3
    let lightPoint = hmdAngPos1 + dir * 0.7
    let dirNormal = float2(dir.y, -dir.x * float(sign(startStep + i))) * 0.03
    let downPos1 = hmdAngPos1 + dirNormal
    let downPos2 = hmdAngPos2 + dirNormal

    if startStep + i > 0
      ctx |> draw_line(hmdAngPos1.x, hmdAngPos1.y, rightPoint.x, rightPoint.y, ctx |> hdpx(data.lineWidth))
      ctx |> draw_line(lightPoint.x, lightPoint.y, hmdAngPos2.x, hmdAngPos2.y, ctx |> hdpx(data.lineWidth))
      ctx |> draw_line(hmdAngPos1.x, hmdAngPos1.y, downPos1.x, downPos1.y, ctx |> hdpx(data.lineWidth))
      ctx |> draw_line(hmdAngPos2.x, hmdAngPos2.y, downPos2.x, downPos2.y, ctx |> hdpx(data.lineWidth))
    else
      ctx |> render_line_dashed(hmdAngPos1, rightPoint, ctx |> hdpx(10.), ctx |> hdpx(10.), ctx |> hdpx(data.lineWidth), data.color)
      ctx |> render_line_dashed(hmdAngPos2, lightPoint, ctx |> hdpx(10.), ctx |> hdpx(10.), ctx |> hdpx(data.lineWidth), data.color)
      ctx |> draw_line(hmdAngPos1.x, hmdAngPos1.y, downPos1.x, downPos1.y, ctx |> hdpx(data.lineWidth))
      ctx |> draw_line(hmdAngPos2.x, hmdAngPos2.y, downPos2.x, downPos2.y, ctx |> hdpx(data.lineWidth))

    let angleStr = fmt(":02d", (startStep + i) * 10)
    let strBox = get_str_bbox(angleStr, angleStr |> length(), fctx)
    let textPos1 = hmdAngPos1 + normalize(hmdAngPos1 - hmdAngPos2) * 5. + normalize(downPos1 - hmdAngPos1) * strBox.width.y * 0.5 * float(sign(startStep + i))
    ctx |> goto_xy(textPos1.x, textPos1.y)
    ctx |> draw_str_scaled(1., angleStr, angleStr |> length())

    let textPos2 = hmdAngPos2 + normalize(hmdAngPos2 - hmdAngPos1) * (strBox.width.x + 5.) + normalize(downPos2 - hmdAngPos2) * strBox.width.y * 0.5 * float(sign(startStep + i))
    ctx |> goto_xy(textPos2.x, textPos2.y)
    ctx |> draw_str_scaled(1., angleStr, angleStr |> length())

def draw_hmd_azimuth(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&)
  let app = get_app()
  if app == null || app.flightControlMode == null
    return
  let camera = app.flightControlMode.cameraControl.cur
  if camera == null
    return
  let lookDir = normalize(camera.viewData.lookAt - camera.viewData.lookFrom)
  let azimuth = rad_to_deg(norm_ang(dir_to_angles(lookDir).x + PI * 0.5))

  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_color(data.color)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize);

  let azStr = fmt(":d", roundi(azimuth))
  let strBox = get_str_bbox(azStr, azStr |> length(), fctx)
  ctx |> goto_xy(rdata.pos.x + rdata.size.x * 0.5 - strBox.width.x * 0.5, rdata.pos.y + rdata.size.y * 0.3)
  ctx |> draw_str_scaled(1.0, azStr, azStr |> length())

def draw_plane_azimuth(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&; hero : Unit?)
  let azimuth = rad_to_deg(norm_ang(dir_to_angles(hero.unitTm[0]).x + PI * 0.5))

  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_color(data.color)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize);

  let azStr = fmt(":d", roundi(azimuth))
  let strBox = get_str_bbox(azStr, azStr |> length(), fctx)
  ctx |> goto_xy(rdata.pos.x + rdata.size.x * 0.5 - strBox.width.x * 0.5, rdata.pos.y + rdata.size.y * 0.7)
  ctx |> draw_str_scaled(1.0, azStr, azStr |> length())

def draw_aim_lock(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&)
  var aimLock : float3
  var hmdPos : float2
  if get_point_of_interest(aimLock) && world_to_hmd_screen(aimLock, hmdPos)
    if hmdPos.y < rdata.size.y * 0.75 && hmdPos.x < rdata.size.x * 0.75 && hmdPos.y > rdata.size.y * 0.25 && hmdPos.x > rdata.size.x * 0.25
      ctx |> set_color(data.color)
      let size = rdata.size.y * 0.01
      ctx |> render_frame(hmdPos.x - size, hmdPos.y - size, hmdPos.x + size, hmdPos.y + size, ctx |> hdpx(data.lineWidth))
      let tc = float2(0., 0.)
      ctx |> render_rect(hmdPos.x - 1., hmdPos.y - 1., hmdPos.x + 1., hmdPos.y + 1., tc, tc, tc)

      var fctx : StdGuiFontContext
      let labelFontSize = int(float(data.fontSize) * 0.8)
      get_font_context(fctx, data.fontId, 0, 0, labelFontSize)
      let labelColor = E3DCOLOR(Color4(float4(0.1, 0.2, 1., 1.)))
      ctx |> set_color(labelColor)
      ctx |> set_font(data.fontId, 0, 0)
      ctx |> set_font_ht(labelFontSize);
      let str = "MRK A"
      let strBox = get_str_bbox(str, str |> length(), fctx)
      ctx |> goto_xy(hmdPos.x - strBox.width.x * 0.5, hmdPos.y + strBox.width.y + size + ctx |> hdpx(5.))
      ctx |> draw_str_scaled(1.0, str, str |> length())

def foreach_targets(blk : block<(unit : Unit? const const#) : void>)
  get_all_units() <| $(units : array<Unit?> const#)
    for u in units
      invoke(blk, u)

def draw_plane_marks(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&; hero : Unit?)
  var fctx : StdGuiFontContext
  let labelFontSize = int(float(data.fontSize) * 0.9)
  get_font_context(fctx, data.fontId, 0, 0, labelFontSize)

  ctx |> set_color(data.color)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(labelFontSize);
  foreach_targets() <| $(var unit)
    if unit != null && !unit.isDelayed && (!unit.isFarAway || !unit.isFarAwayForSensors) && unit != hero && unit.army == hero.army
      var screenPos : float2
      if world_to_hmd_screen(unit.pos, screenPos)
        if unit.isFlightModelWrap
          ctx |> render_ellipse_aa(screenPos, float2(rdata.size.y * 0.02), ctx |> hdpx(data.lineWidth), data.color, transparentColor)
          let number = "{unit.id}"
          let strBox = get_str_bbox(number, number |> length(), fctx)
          ctx |> goto_xy(screenPos.x - strBox.width.x * 0.5, screenPos.y + rdata.size.y * 0.02 + strBox.width.y + ctx |> hdpx(5.))
          ctx |> draw_str_scaled(1.0, number, number |> length())
        elif unit.isTank || unit.isShip
          let halfSize = rdata.size.y * 0.01
          ctx |> draw_line(screenPos.x - halfSize, screenPos.y - halfSize, screenPos.x + halfSize, screenPos.y + halfSize, ctx |> hdpx(data.lineWidth))
          ctx |> draw_line(screenPos.x - halfSize, screenPos.y + halfSize, screenPos.x + halfSize, screenPos.y - halfSize, ctx |> hdpx(data.lineWidth))


def draw_laser_indicator(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&; fmw : FlightModelWrap?)
  var aimLock : float3
  if get_point_of_interest(aimLock) || fmw.sightMode >= int(CockpitSightMode HUD_SIGHT_MODE_GROUND_CANNONS)
    let str = "*"
    ctx |> set_color(data.color)
    ctx |> goto_xy(rdata.pos.x + rdata.size.x * 0.375, rdata.pos.y + rdata.size.y * 0.58)
    ctx |> draw_str_scaled(1.0, str, str |> length())


def draw_ir_aam_seeker(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&)
  static_if typeinfo(builtin_function_exists @@ < () : bool > _::get_aam_tracker_visible)
    static_if typeinfo(builtin_function_exists @@ < () : float2 > _::get_screen_aam_tracker_pos)
      let aamLockState = get_aam_guidance_lock_state()
      if int(aamLockState) <= int(GuidanceLockState.RESULT_STANDBY)
        return
      if get_cur_weapon_guidance_type() != GuidanceType.TYPE_OPTICAL
        return

      let pos = get_aam_tracker_visible() ? get_screen_aam_tracker_pos() : float2(rdata.size * 0.5)
      let maxOffs = 0.25
      let posClamped = clamp(pos, rdata.size * maxOffs, rdata.size * (1.f - maxOffs))
      let blinksPerSecond = 4.0
      let isBlink = fract(blinksPerSecond * float(get_total_time())) < 0.5
      if isBlink && posClamped != pos
        return
      render_ellipse_aa(ctx, posClamped, float2(rdata.size.y * 0.02), ctx |> hdpx(data.lineWidth), data.color, transparentColor)
      if aamLockState != GuidanceLockState.RESULT_TRACKING
        return
      render_ellipse_aa(ctx, posClamped, float2(rdata.size.y * 0.025), ctx |> hdpx(data.lineWidth), data.color, transparentColor)

