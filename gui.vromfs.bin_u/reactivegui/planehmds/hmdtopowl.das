require darg
require DagorStdGuiRender
require DagorMath
require math
require Plane
require FlightModelWrap
require HeroManager
require Unit
require strings
require DagorSystem
require FlightControl
require hud
require WTCamera
require app
require Weapon
require hud
require %rGui.utils.constants_common
require app

let transparentColor = E3DCOLOR(Color4(float4(0, 0, 0, 0)))


def deg_to_rad(rad : float)
  return rad * PI / 180.

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
  let app = get_app()
  if app == null
    return
  draw_central_mark(ctx, rdata, data)
  draw_bar_altitude(ctx, rdata, data, roundi(hero.pos.y * metrToFeet))
  draw_climb(ctx, rdata, data, roundi(fmw.fm.vertSpeed * mpsToFpm))

  draw_altitude(ctx, rdata, data, roundi(fmw.fm.currentAlt * metrToFeet))
  draw_speed(ctx, rdata, data, roundi(hero.speed * mpsToKnots))
  draw_roll_pitch(ctx, rdata, data, fmw.roll, fmw.tangage)
  draw_aim_lock(ctx, rdata, data)
  let compass = rad_to_deg(norm_ang(2. * PI + atan2(hero.unitTm[0].x, hero.unitTm[0].z)))
  draw_compass(ctx, rdata, data, compass)
  draw_hmd_azimuth(ctx, rdata, data)
  draw_ground_speed(ctx, rdata, data, hero.vel)
  draw_rocket_ccip(ctx, rdata, data, app.flightControlMode, fmw)

def draw_central_mark(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&)
  ctx |> set_color(data.color)
  ctx |> draw_line(rdata.pos.x + rdata.size.x * 0.47, rdata.pos.y + rdata.size.y * 0.5, rdata.pos.x + rdata.size.x * 0.49, rdata.pos.y + rdata.size.y * 0.5, ctx |> hdpx(data.lineWidth))
  ctx |> draw_line(rdata.pos.x + rdata.size.x * 0.49, rdata.pos.y + rdata.size.y * 0.5, rdata.pos.x + rdata.size.x * 0.49, rdata.pos.y + rdata.size.y * 0.51, ctx |> hdpx(data.lineWidth))
  ctx |> draw_line(rdata.pos.x + rdata.size.x * 0.53, rdata.pos.y + rdata.size.y * 0.5, rdata.pos.x + rdata.size.x * 0.51, rdata.pos.y + rdata.size.y * 0.5, ctx |> hdpx(data.lineWidth))
  ctx |> draw_line(rdata.pos.x + rdata.size.x * 0.51, rdata.pos.y + rdata.size.y * 0.5, rdata.pos.x + rdata.size.x * 0.51, rdata.pos.y + rdata.size.y * 0.51, ctx |> hdpx(data.lineWidth))

def draw_bar_altitude(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&; alt : int)
  ctx |> set_color(data.color)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)

  let altStr = "{alt} ft"
  ctx |> goto_xy(rdata.pos.x + rdata.size.x * 0.62, rdata.pos.y + rdata.size.y * 0.35)
  ctx |> draw_str_scaled(1.0, altStr, altStr |> length())

def draw_climb(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&; vspeed : int)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, 18)
  ctx |> set_color(data.color)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(18)

  let offset = 0.345 + cvt(float(vspeed), 1000., -1000., -0.02, 0.02)
  let line <- to_array_move(fixed_array<float2>(rdata.pos + float2(rdata.size.x * 0.66, rdata.size.y * 0.345),
   rdata.pos + float2(rdata.size.x * 0.67, rdata.size.y * offset)))
  ctx |> render_line_aa(line, false, data.lineWidth, float2(0., 0.), data.color)

  let climbStr = "{vspeed}"
  let strBox = get_str_bbox(climbStr, climbStr |> length(), fctx)
  ctx |> goto_xy(rdata.pos.x + rdata.size.x * 0.67 + ctx |> hdpx(5.), rdata.pos.y + rdata.size.y * offset + strBox.width.y * 0.5)
  ctx |> draw_str_scaled(1.0, climbStr, climbStr |> length())

def draw_altitude(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&; alt : int)
  ctx |> set_color(data.color)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)

  let altStr = fmt(":03d", alt)
  let pos = float2(rdata.pos.x + rdata.size.x * 0.62, rdata.pos.y + rdata.size.y * 0.5)
  let strBox = get_str_bbox(altStr, altStr |> length(), fctx)
  ctx |> goto_xy(pos.x, pos.y + strBox.width.y * 0.5)
  ctx |> draw_str_scaled(1.0, altStr, altStr |> length())

  let coord <- to_array_move(fixed_array<float2>(pos - float2(rdata.size.x * 0.01, 0.),
   pos - float2(rdata.size.x * 0.005, 0.),
   pos - float2(0., rdata.size.y * 0.01)))
  ctx |> render_line_aa(coord, false, data.lineWidth, float2(0., 0.), data.color)
  let coord2 <- to_array_move(fixed_array<float2>(pos - float2(rdata.size.x * 0.005, 0.),
   pos + float2(0., rdata.size.y * 0.01)))
  ctx |> render_line_aa(coord2, false, data.lineWidth, float2(0., 0.), data.color)

  let totalSize = rdata.size.y * 0.1
  let scalePos = pos - float2(rdata.size.x * 0.02, 0.)
  let zeroPos = scalePos + float2(0., float(alt) * 0.1 * totalSize)
  let lineCoord <- to_array_move(fixed_array<float2>(scalePos - float2(0., totalSize),
   scalePos + float2(0., min(totalSize, zeroPos.y - scalePos.y))))
  ctx |> render_line_aa(lineCoord, false, data.lineWidth, float2(0., 0.), data.color)
  if alt <= 100
    for i in range(0, 11)
      let len = i == 0 || i == 10 ? rdata.size.x * 0.01 : rdata.size.x * 0.005
      let verOffset = alt <= 10 ? (totalSize * float(alt - i) * 0.1) : float(alt - 10 + i * 10) * 0.01 * totalSize
      if verOffset > totalSize
        continue
      let smallLineCoord <- to_array_move(fixed_array<float2>(scalePos + float2(0., verOffset),
      scalePos + float2(len, verOffset)))
      ctx |> render_line_aa(smallLineCoord, false, data.lineWidth, float2(0., 0.), data.color)

  let markFontSize = int(float(data.fontSize) * 0.8)
  get_font_context(fctx, data.fontId, 0, 0, markFontSize)
  ctx |> set_font_ht(markFontSize)
  for i in range(-2, 3)
    let markVal = (alt / 50) * 50 + i * 50
    if markVal <= 0 || alt - markVal > 100
      continue
    let markPos = scalePos + float2(0., float(alt - markVal) * 0.01 * totalSize - (alt <= 10 ? totalSize * 0.5 : 0.))
    let markEnd = markPos + float2(rdata.size.x * (markVal % 100 == 0 ? 0.008 : 0.005), 0.)
    let markCoord <- to_array_move(fixed_array<float2>(markPos, markEnd))
    ctx |> render_line_aa(markCoord, false, data.lineWidth, float2(0., 0.), data.color)
    if markVal % 100 == 0 && abs(markVal - alt) > 20
      let text = "{markVal}"
      let markStrBox = get_str_bbox(text, text |> length(), fctx)
      ctx |> goto_xy(markEnd.x + ctx |> hdpx(2.), markEnd.y + markStrBox.width.y * 0.5)
      ctx |> draw_str_scaled(1.0, text, text |> length())

def draw_speed(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&; speed : int)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_color(data.color)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)

  let spdStr = "{speed} kts"
  let strBox = get_str_bbox(spdStr, spdStr |> length(), fctx)
  ctx |> goto_xy(rdata.pos.x + rdata.size.x * 0.38 - strBox.width.x, rdata.pos.y + rdata.size.y * 0.35)
  ctx |> draw_str_scaled(1.0, spdStr, spdStr |> length())

def draw_roll_pitch(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&; roll : float; tangage : float)
  let pos = rdata.pos + rdata.size * 0.5
  let markFontSize = int(float(data.fontSize) * 0.8)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, markFontSize)
  ctx |> set_color(data.color)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(markFontSize)

  ctx |> setRotViewTm(pos.x, pos.y, deg_to_rad(-roll), 0., false)
  for i in range(-2, 3)
    let markVal = (int(tangage) / 5) * 5 + i * 5
    let markPos = pos + float2(0., (tangage - float(markVal)) * 0.01 * rdata.size.x)
    if markPos.y < rdata.size.y * 0.3
      continue
    if markVal != 0
      let markCoord1 <- to_array_move(fixed_array<float2>(markPos + float2(-rdata.size.x * 0.05, ctx |> hdpx(12.) * float(sign(markVal))),
       markPos - float2(rdata.size.x * 0.05, 0.),
       markPos - float2(rdata.size.x * 0.032, 0.)))
      ctx |> render_line_aa(markCoord1, false, data.lineWidth, float2(0., 0.), data.color)
      let markCoord2 <- to_array_move(fixed_array<float2>(markPos + float2(rdata.size.x * 0.05, ctx |> hdpx(12.) * float(sign(markVal))),
       markPos + float2(rdata.size.x * 0.05, 0.),
       markPos + float2(rdata.size.x * 0.032, 0.)))
      ctx |> render_line_aa(markCoord2, false, data.lineWidth, float2(0., 0.), data.color)
    else
      let markCoord1 <- to_array_move(fixed_array<float2>(markPos - float2(rdata.size.x * 0.05, 0.),
       markPos - float2(rdata.size.x * 0.03, 0.)))
      ctx |> render_line_aa(markCoord1, false, data.lineWidth, float2(0., 0.), data.color)
      let markCoord2 <- to_array_move(fixed_array<float2>(markPos + float2(rdata.size.x * 0.05, 0.),
       markPos + float2(rdata.size.x * 0.03, 0.)))
      ctx |> render_line_aa(markCoord2, false, data.lineWidth, float2(0., 0.), data.color)
    if markVal != 0
      let textPos1 = markPos + float2(rdata.size.x * 0.05, 0.)
      let textPos2 = markPos - float2(rdata.size.x * 0.05, 0.)
      let text = "{markVal}"
      let strBox = get_str_bbox(text, text |> length(), fctx)
      ctx |> goto_xy(textPos1.x + ctx |> hdpx(10.), textPos1.y + strBox.width.y * 0.5)
      ctx |> draw_str_scaled(1.0, text, text |> length())
      ctx |> goto_xy(textPos2.x - ctx |> hdpx(10.) - strBox.width.x, textPos2.y + strBox.width.y * 0.5)
      ctx |> draw_str_scaled(1.0, text, text |> length())

  let arrowPos = rdata.pos + float2(rdata.size.x * 0.5, rdata.size.y * 0.26)
  let arrowPoints <- to_array_move(fixed_array<float2>(arrowPos, arrowPos + float2(ctx |> hdpx(-5.), ctx |> hdpx(12.)),
   arrowPos + float2(ctx |> hdpx(5.), ctx |> hdpx(12.))))
  ctx |> render_poly(arrowPoints, data.color)
  ctx |> render_box(arrowPos.x - ctx |> hdpx(5.), arrowPos.y + ctx |> hdpx(15.), arrowPos.x + ctx |> hdpx(5.), arrowPos.y + ctx |> hdpx(20.))

  ctx |> resetViewTm()

  let origin = rdata.pos + rdata.size * 0.5
  for i in range(-3, 4)
    let angle = float(i) * PI / 18. - PI * 0.5
    let cosa = cos(angle)
    let sina = sin(angle)
    if i != 0
      let posSt = origin + float2(rdata.size.y * 0.25 * cosa, rdata.size.y * 0.25 * sina)
      let posEnd = origin + float2(rdata.size.y * (i != 3 && i != -3 ? 0.26 : 0.27) * cosa, rdata.size.y * (i != 3 && i != -3 ? 0.26 : 0.27) * sina)
      let markCoord <- to_array_move(fixed_array<float2>(posSt, posEnd))
      ctx |> render_line_aa(markCoord, false, data.lineWidth, float2(0., 0.), data.color)
    else
      let markCoord <- to_array_move(fixed_array<float2>(origin - float2(0., rdata.size.y * 0.25),
       origin - float2(ctx |> hdpx(6.), rdata.size.y * 0.265),
       origin - float2(ctx |> hdpx(-6.), rdata.size.y * 0.265)))
      ctx |> render_line_aa(markCoord, true, data.lineWidth, float2(0., 0.), data.color)

def draw_aim_lock(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&)
  var aimLock : float3
  var hmdPos : float2
  if get_point_of_interest(aimLock) && world_to_hmd_screen(aimLock, hmdPos)
    if hmdPos.y < rdata.size.y * 0.75 && hmdPos.x < rdata.size.x * 0.75 && hmdPos.y > rdata.size.y * 0.25 && hmdPos.x > rdata.size.x * 0.25
      ctx |> set_color(data.color)
      ctx |> render_frame(hmdPos.x - rdata.size.x * 0.02, hmdPos.y - rdata.size.y * 0.02, hmdPos.x + rdata.size.x * 0.02, hmdPos.y + rdata.size.y * 0.02, ctx |> hdpx(data.lineWidth))
      ctx |> draw_line(hmdPos.x, hmdPos.y - rdata.size.y * 0.02, hmdPos.x, hmdPos.y - rdata.size.y * 0.01, ctx |> hdpx(data.lineWidth))
      ctx |> draw_line(hmdPos.x, hmdPos.y + rdata.size.y * 0.02, hmdPos.x, hmdPos.y + rdata.size.y * 0.01, ctx |> hdpx(data.lineWidth))
      ctx |> draw_line(hmdPos.x - rdata.size.x * 0.02, hmdPos.y, hmdPos.x - rdata.size.x * 0.01, hmdPos.y, ctx |> hdpx(data.lineWidth))
      ctx |> draw_line(hmdPos.x + rdata.size.x * 0.02, hmdPos.y, hmdPos.x + rdata.size.x * 0.01, hmdPos.y, ctx |> hdpx(data.lineWidth))

def draw_compass(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&; compass : float)
  let pos = rdata.pos + float2(rdata.size.x * 0.5, rdata.size.y * 0.2)
  let markFontSize = int(float(data.fontSize) * 0.8)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, markFontSize)
  ctx |> set_color(data.color)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(markFontSize)

  for i in range(-3, 4)
    let markVal = (int(compass) / 5) * 5 + i * 5
    let markPos = pos + float2((-compass + float(markVal)) * 0.006 * rdata.size.x, 0.)
    let markCoord <- to_array_move(fixed_array<float2>(markPos + float2(0., -ctx |> hdpx(markVal % 10 == 0 ? 15. : 12.)),
      markPos + float2(0., markVal % 10 != 0 ? -ctx |> hdpx(3.) : 0.)))
    ctx |> render_line_aa(markCoord, false, data.lineWidth, float2(0., 0.), data.color)
    if markVal % 10 == 0
      let text = "{markVal / 10}"
      let markStrBox = get_str_bbox(text, text |> length(), fctx)
      ctx |> goto_xy(markPos.x - markStrBox.width.x * 0.5, markPos.y + markStrBox.width.y + ctx |> hdpx(5.))
      ctx |> draw_str_scaled(1.0, text, text |> length())

def draw_hmd_azimuth(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&)
  let app = get_app()
  if app == null || app.flightControlMode == null
    return
  let camera = app.flightControlMode.cameraControl.cur
  if camera == null
    return
  let lookDir = normalize(camera.viewData.lookAt - camera.viewData.lookFrom)
  let azimuth = rad_to_deg(norm_ang(2. * PI + atan2(lookDir.x, lookDir.z)))

  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_color(data.color)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)

  let azStr = fmt(":d", roundi(azimuth))
  let strBox = get_str_bbox(azStr, azStr |> length(), fctx)
  ctx |> goto_xy(rdata.pos.x + rdata.size.x * 0.5 - strBox.width.x * 0.5, rdata.pos.y + rdata.size.y * 0.15)
  ctx |> draw_str_scaled(1.0, azStr, azStr |> length())

  ctx |> render_frame(rdata.pos.x + rdata.size.x * 0.486, rdata.pos.y + rdata.size.y * 0.15 - strBox.width.y - ctx |> hdpx(5.),
   rdata.pos.x + rdata.size.x * 0.514, rdata.pos.y + rdata.size.y * 0.15 + ctx |> hdpx(8.), ctx |> hdpx(data.lineWidth))

def draw_ground_speed(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&; vel : float3)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_color(data.color)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)

  let gs = roundi(length(float2(vel.x, vel.z)) * mpsToKnots)
  let spdStr = "GS {gs}"
  let strBox = get_str_bbox(spdStr, spdStr |> length(), fctx)
  ctx |> goto_xy(rdata.pos.x + rdata.size.x * 0.35 - strBox.width.x, rdata.pos.y + rdata.size.y * 0.65)
  ctx |> draw_str_scaled(1.0, spdStr, spdStr |> length())

def draw_rocket_ccip(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&; fcm : FlightControlMode?; fmw : FlightModelWrap?)
  ctx |> set_color(data.color)

  if (!fcm.isRocketsConstantlyComputingSightActive || !fcm.isRocketImpactValid)
    return

  if (fmw.sightMode != int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_ROCKET))
    return

  let impactPos = fcm.rocketImpactPosition
  var screenPos = float2(0.f)
  if world_to_screen(impactPos, screenPos)
    ctx |> draw_line(
      screenPos.x,
      screenPos.y - rdata.size.y * 0.03,
      screenPos.x,
      screenPos.y - rdata.size.y * 0.005,
      ctx |> hdpx(data.lineWidth))

    ctx |> draw_line(
      screenPos.x,
      screenPos.y + rdata.size.y * 0.005,
      screenPos.x,
      screenPos.y + rdata.size.y * 0.03,
      ctx |> hdpx(data.lineWidth))

    ctx |> draw_line(
      screenPos.x - rdata.size.x * 0.005,
      screenPos.y + rdata.size.y * 0.03,
      screenPos.x + rdata.size.x * 0.005,
      screenPos.y + rdata.size.y * 0.03,
      ctx |> hdpx(data.lineWidth))

    ctx |> draw_line(
      screenPos.x - rdata.size.x * 0.005,
      screenPos.y - rdata.size.y * 0.03,
      screenPos.x + rdata.size.x * 0.005,
      screenPos.y - rdata.size.y * 0.03,
      ctx |> hdpx(data.lineWidth))