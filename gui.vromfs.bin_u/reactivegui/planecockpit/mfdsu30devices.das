require darg
require DagorStdGuiRender
require DagorMath
require math
require strings
require Plane
require FlightModelWrap
require HeroManager
require Unit
require %rGui.utils.constants_common
require DagorSystem

let red = E3DCOLOR(0xFFFF0700)
let yellow = E3DCOLOR(0xFFFFFF30)
let green = E3DCOLOR(0xFF37FF37)
let white = E3DCOLOR(0xFFFFFFFF)
let transparant = E3DCOLOR(0x00000000)
let skyColor = E3DCOLOR(0xFF00C8CC)
let groundColor = E3DCOLOR(0xFFAA2418)
let black = E3DCOLOR(0xFF000000)

struct CanvasParams
  fontId : int = -1
  fontSize : int = 20
  altDevImage : Picture?
  spdDevImage : Picture?
  varioDevImage : Picture?
  horMask : Picture?

[export]
def setup(props : Properties&; var storage : CanvasParams&)
  storage.fontId = props |> getFontId()
  storage.fontSize = props |> getInt("fontSize", 20)
  storage.altDevImage = props |> getPicture("altDevImage")
  storage.spdDevImage = props |> getPicture("spdDevImage")
  storage.varioDevImage = props |> getPicture("varioDevImage")
  storage.horMask = props |> getPicture("horMask")

[export, unused_argument(rstate)]
def draw(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed
    return
  var fmw = hero |> as_fmw()
  if fmw == null
    return
  let overloadPos = rdata.pos + float2(5., rdata.size.y * 0.1)
  let overloadSize = float2(rdata.size.x * 0.05, rdata.size.y * 0.5)
  draw_overload(ctx, overloadPos, overloadSize, data, fmw.fm.localAccel.length() / 9.81)
  let compass = (norm_ang(2. * PI + atan2(hero.unitTm[0].x, hero.unitTm[0].z))) * radToDeg
  draw_compass(ctx, rdata, data, compass)
  draw_avia_horizont(ctx, rdata.pos + float2(rdata.size.x * 0.25, rdata.size.y * 0.15), float2(rdata.size.x * 0.5, rdata.size.y * 0.5),
   data, fmw.tangage, fmw.roll)
  draw_climb(ctx, rdata.pos + float2(rdata.size.y * 0.58, rdata.size.y * 0.45), float2(rdata.size.y * 0.5), data, fmw.tangage)
  draw_vario(ctx, rdata, rdata.pos + float2(rdata.size.x * 0.78, rdata.size.y * 0.2), rdata.size * 0.35, data, fmw.fm.vertSpeed)
  draw_altitude(ctx, rdata.pos + float2(rdata.size.x * 0.62, rdata.size.y * 0.58), rdata.size * 0.35, data, hero.pos.y)
  draw_speed_device(ctx, rdata.pos + float2(rdata.size.x * 0.02, rdata.size.y * 0.58), rdata.size * 0.35, data, fmw.ias)
  draw_heights(ctx, rdata.pos, rdata.size, data, fmw.fm.currentAlt, hero.pos.y)
  draw_speeds(ctx, rdata.pos, rdata.size, data, fmw.ias, hero.speed, fmw.fm.Mach)
  //logerr("{fmw.fm.EI.numEngines > 0}")
  if fmw.fm.EI.numEngines > 0
    assume propulsion = *(fmw.fm.EI)
    propulsion_getEngine(propulsion, 0) <| $(mainEngine)
      let rpmRel = mainEngine.omegaRel
      draw_rep_rpm(ctx, rdata.pos + float2(rdata.size.x * 0.01, rdata.size.y * 0.57), rdata.size * 0.37, rpmRel)

def draw_plane_mark(var ctx : GuiContext&; pos : float2; size : float2)
  let plane <- to_array_move(fixed_array<float2>(pos,
   pos + float2(size.x * 0.75, -size.y * 0.5),
   pos + float2(size.x, -size.y),
   pos + float2(size.x, 0.)))
  ctx |> render_poly(plane, white)

def draw_overload(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; overload : float)
  let scalePos = pos + float2(size.x, 0.)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)

  ctx |> set_color(green)
  for i in range(12)
    let len = (i % 2 > 0 ? 0.1 : 0.2) * size.x
    let yPos = scalePos.y + size.y * (float(i) * 0.075 + 0.1)
    ctx |> draw_line(scalePos.x - len, yPos, scalePos.x + len, yPos, 2.)

    if i % 2 > 0 && i < 10
      let text = "{10 - i}"
      let strBox = get_str_bbox(text, text |> length(), fctx)

      ctx |> goto_xy(scalePos.x - len - strBox.width.x - 5., yPos - strBox.width.y * 0.6)
      ctx |> draw_str_scaled(1., text, text |> length())

  ctx |> draw_line(scalePos.x, scalePos.y + size.y * 0.625, scalePos.x, scalePos.y + size.y * 0.8, 3.)

  ctx |> set_color(red)
  ctx |> draw_line(scalePos.x, scalePos.y, scalePos.x, scalePos.y + size.y * 0.625, 3.)
  ctx |> draw_line(scalePos.x, scalePos.y + size.y * 0.8, scalePos.x, scalePos.y + size.y, 3.)

  let curPos = scalePos + float2(0, size.y * (0.7 - overload * 0.075))
  let triangle <- to_array_move(fixed_array<float2>(curPos,
    float2(curPos.x - size.x * 0.3, curPos.y - size.y * 0.02),
    float2(curPos.x - size.x * 0.3, curPos.y + size.y * 0.02)))
  ctx |> render_poly(triangle, white)

def draw_climb(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; tangage : float)
  ctx |> render_sector_aa(pos, size, float2(0.944 * PI, 1.222 * PI), 3., green, transparant)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)
  ctx |> set_color(green)

  for i in range(11)
    let angle = (40. - float(i) * 5.) * degToRad
    let outPos = pos + float2(-size.x * cos(angle), -size.y * sin(angle))
    let mul = i % 2 > 0 ? 0.985 : 0.97
    let inPos = pos + float2(-size.x * cos(angle), -size.y * sin(angle)) * mul
    let coord <- to_array_move(fixed_array<float2>(outPos, inPos))
    ctx |> render_line_aa(coord, false, 2., float2(0.), green)

    if i != 0 && i < 10 && i % 2 == 0
      let text = "{int(40. - float(i) * 5.)}"
      let strBox = get_str_bbox(text, text |> length(), fctx)
      ctx |> goto_xy(inPos.x + 5., inPos.y + strBox.width.y * 0.5)
      ctx |> draw_str_scaled(1., text, text |> length())

  ctx |> render_sector_aa(pos, float2(size.x + 1.), float2(1.111 * PI, 1.222 * PI), 3., red, transparant)
  ctx |> render_sector_aa(pos, float2(size.x + 1.), float2(0.944 * PI, 0.97 * PI), 3., red, transparant)

  ctx |> setRotViewTm(pos.x, pos.y, min(max(tangage, -10.), 40.) * degToRad, 0., false)

  draw_plane_mark(ctx, pos - float2(size.x, 0.), float2(size.x * 0.15, size.y * 0.05))
  ctx |> resetViewTm()

def draw_avia_horizont(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; tangage : float; roll : float)
  let horLevel = pos.y + size.y * cvt(tangage, -30., 30., 0., 1.)
  let tc = float2(0., 0.)
  let origin = pos + size * 0.5

  ctx |> set_viewport(pos.x, pos.y, pos.x + size.x, pos.y + size.y)

  ctx |> set_color(skyColor)
  ctx |> render_rect(pos.x, pos.y, pos.x + size.x, horLevel, tc, tc, tc)
  ctx |> set_color(groundColor)
  ctx |> render_rect(pos.x, horLevel, pos.x + size.x, pos.y + size.y, tc, tc, tc)

  ctx |> set_color(white)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)

  for i in range(-5, 7)
    let markVal = (int(tangage) / 5) * 5 + i * 5
    let posY = pos.y + size.y * 0.5 + (tangage - float(markVal)) * 0.01667 * size.y

    if markVal == 0
      ctx |> draw_line(pos.x, posY, pos.x + size.x, posY, 2.)
    elif abs(markVal % 10) > 0
      ctx |> draw_line(pos.x + size.x * 0.45, posY, pos.x + size.x * 0.55, posY, 2.)
    else
      ctx |> draw_line(pos.x + size.x * 0.35, posY, pos.x + size.x * 0.45, posY, 2.)
      ctx |> draw_line(pos.x + size.x * 0.55, posY, pos.x + size.x * 0.65, posY, 2.)
      ctx |> draw_line(pos.x + size.x * 0.35, posY, pos.x + size.x * 0.35, posY + size.y * 0.03 * sign(float(markVal)), 2.)
      ctx |> draw_line(pos.x + size.x * 0.65, posY, pos.x + size.x * 0.65, posY + size.y * 0.03 * sign(float(markVal)), 2.)

      let text = "{abs(markVal)}"
      let strBox = get_str_bbox(text, text |> length(), fctx)
      ctx |> goto_xy(pos.x + (size.x - strBox.width.x) * 0.5, posY + strBox.width.y * 0.5)
      ctx |> draw_str_scaled(1., text, text |> length())

  ctx |> setRotViewTm(origin.x, origin.y, roll * degToRad, 0., false)

  let leftWing <- to_array_move(fixed_array<float2>(origin - float2(size.x * 0.49, 0.),
   origin - float2(size.x * 0.15, 0.),
   origin - float2(size.x * 0.125, -size.y * 0.05),
   origin - float2(size.x * 0.1, 0.),
   origin - float2(size.x * 0.03, 0.)))
  ctx |> render_line_aa(leftWing, false, 5., float2(0.), black)
  let rightWing <- to_array_move(fixed_array<float2>(origin + float2(size.x * 0.49, 0.),
   origin + float2(size.x * 0.15, 0.),
   origin + float2(size.x * 0.125, size.y * 0.05),
   origin + float2(size.x * 0.1, 0.),
   origin + float2(size.x * 0.03, 0.)))
  ctx |> render_line_aa(rightWing, false, 5., float2(0.), black)
  let dot <- to_array_move(fixed_array<float2>(origin, origin))
  ctx |> render_line_aa(dot, false, 6., float2(0.), black)
  let tail <- to_array_move(fixed_array<float2>(origin - float2(0., size.y * 0.08),
   origin - float2(0., size.y * 0.16)))
  ctx |> render_line_aa(tail, false, 5., float2(0.), black)

  ctx |> resetViewTm()
  ctx |> set_color(black)
  for i in range(-18, 19)
    var angle = float(i) * 5.
    let angleM = abs(angle)
    if angleM < 30. || (angleM < 60. && angleM % 15. > 0.)
      continue
    let outL = angleM % 30. == 0. ? 0.41 : (angleM % 15. == 0. ? 0.4 : 0.38)
    angle += 90.
    let cosa = cos(angle * degToRad)
    let sina = sin(angle * degToRad)
    let mark <- to_array_move(fixed_array<float2>(origin + float2(cosa * size.y * 0.36, sina * size.y * 0.36),
     origin + float2(cosa * size.y * outL, sina * size.y * outL)))
    ctx |> render_line_aa(mark, false, 3., float2(0.), black)

    if angleM == 30. || angleM == 60.
      let text = "{90. - angleM}"
      let strBox = get_str_bbox(text, text |> length(), fctx)
      ctx |> goto_xy(origin.x + cosa * size.y * outL - strBox.width.y * 0.5, origin.y + sina * size.y * outL + strBox.width.y)
      ctx |> draw_str_scaled(1., text, text |> length())

  render_picture(ctx, data.horMask, pos - float2(1.), size + float2(2.), black)
  ctx |> restore_viewport

  ctx |> render_sector_aa(origin, float2(size.y * 0.5), float2(-PI * 0.847, -PI * 0.153), 3., white, transparant)
  ctx |> render_sector_aa(origin, float2(size.y * 0.5), float2(PI * 0.15, PI * 0.846), 3., white, transparant)
  ctx |> set_color(white)
  ctx |> draw_line(origin.x - size.x * 0.44, origin.y - size.y * 0.23, origin.x - size.x * 0.44, origin.y + size.y * 0.23, 3.)
  ctx |> draw_line(origin.x + size.x * 0.44, origin.y - size.y * 0.23, origin.x + size.x * 0.44, origin.y + size.y * 0.23, 3.)
  let lArrow <- to_array_move(fixed_array<float2>(origin - float2(size.x * 0.5, size.y * 0.03),
   origin - float2(size.x * 0.45, 0.),
   origin - float2(size.x * 0.5, -size.y * 0.03)))
  ctx |> render_line_aa(lArrow, false, 3., float2(0.), white)
  let rArrow <- to_array_move(fixed_array<float2>(origin + float2(size.x * 0.5, size.y * 0.03),
   origin + float2(size.x * 0.45, 0.),
   origin + float2(size.x * 0.5, -size.y * 0.03)))
  ctx |> render_line_aa(rArrow, false, 3., float2(0.), white)

def draw_compass(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&; compass : float)
  let pos = rdata.pos + float2(rdata.size.x * 0.5, rdata.size.y * 0.05)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_color(green)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)

  for i in range(-4, 5)
    let markVal = (int(compass) / 5) * 5 + i * 5
    let markPos = pos + float2((-compass + float(markVal)) * 0.008 * rdata.size.x, 0.)
    let markCoord <- to_array_move(fixed_array<float2>(markPos + float2(0., markVal % 10 == 0 ? 3. : 9.),
      markPos + float2(0., 15.)))
    ctx |> render_line_aa(markCoord, false, 2., float2(0., 0.), green)
    if markVal % 10 == 0
      let text = "{markVal / 10}"
      let markStrBox = get_str_bbox(text, text |> length(), fctx)
      ctx |> goto_xy(markPos.x - markStrBox.width.x * 0.5, markPos.y)
      ctx |> draw_str_scaled(1.0, text, text |> length())

  let lineCoord <- to_array_move(fixed_array<float2>(pos - float2(rdata.size.x * 0.2, -15.),
    pos + float2(rdata.size.x * 0.2, 15.)))
  ctx |> render_line_aa(lineCoord, false, 2., float2(0., 0.), green)

  let centerMark <- to_array_move(fixed_array<float2>(pos + float2(-10., 30.),
    pos + float2(0., 15.),
    pos + float2(10., 30.)))
  ctx |> render_line_aa(centerMark, false, 2., float2(0., 0.), white)

def draw_vario(var ctx : GuiContext&; rdata : ElemRenderData& const; pos : float2; size : float2; data : CanvasParams&; vspeed : float)
  ctx |> set_viewport(pos.x, pos.y, min(pos.x + size.x, rdata.pos.x + rdata.size.x), pos.y + size.y)
  render_picture(ctx, data.varioDevImage, pos, size, green)

  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_color(white)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)

  let text = "{roundi(vspeed)}"
  let strBox = get_str_bbox(text, text |> length(), fctx)
  ctx |> goto_xy(pos.x + size.x * 0.5 - strBox.width.x, pos.y + size.y * 0.5 + strBox.width.y)
  ctx |> draw_str_scaled(1., text, text |> length())

  let mea = "м/с"
  ctx |> goto_xy(pos.x + size.x * 0.25, pos.y + size.y * 0.4)
  ctx |> draw_str_scaled(1., mea, mea |> length())

  var rot = 0.
  let absS = abs(vspeed)
  if absS <= 10.
    rot = cvt(vspeed, -10., 10., -PI * 0.21, PI * 0.21)
  elif absS > 10. && absS <= 20.
    rot = cvt(absS, 10., 20., PI * 0.21, PI * 0.38) * sign(vspeed)
  else
    rot = cvt(absS, 20., 30., PI * 0.38, PI * 0.5) * sign(vspeed)
  ctx |> setRotViewTm(pos.x + size.x * 0.5, pos.y + size.y * 0.5, rot, 0., false)

  let lineCoord <- to_array_move(fixed_array<float2>(float2(pos.x + size.x * 0.05, pos.y + size.y * 0.5),
    float2(pos.x + size.x * 0.3, pos.y + size.y * 0.5)))
  ctx |> render_line_aa(lineCoord, false, 2., float2(0., 0.), white)
  let poly <- to_array_move(fixed_array<float2>(float2(pos.x + size.x * 0.05, pos.y + size.y * 0.5),
    float2(pos.x + size.x * 0.1, pos.y + size.y * 0.46),
    float2(pos.x + size.x * 0.1, pos.y + size.y * 0.54)))
  ctx |> render_poly(poly, white)

  ctx |> resetViewTm()
  ctx |> restore_viewport()

def draw_altitude(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; alt : float)
  render_picture(ctx, data.altDevImage, pos, size, green)

  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)

  let tc = float2(0.)
  ctx |> set_color(yellow)
  ctx |> render_rect(pos.x + size.x * 0.32, pos.y + size.y * 0.55, pos.x + size.x * 0.68, pos.y + size.y * 0.7, tc, tc, tc)

  ctx |> set_color(black)
  let mod = "{int(alt % 1000.)}"
  let modBox = get_str_bbox(mod, mod |> length(), fctx)
  ctx |> goto_xy(pos.x + size.x * 0.5 - modBox.width.x * 0.5, pos.y + size.y * 0.62 + modBox.width.y * 0.5)
  ctx |> draw_str_scaled(1., mod, mod |> length())

  let thousands = "{int(alt / 1000.)}"
  let strBox = get_str_bbox(thousands, thousands |> length(), fctx)
  let box = get_str_bbox("00", 2, fctx)
  ctx |> set_color(green)
  ctx |> render_frame(pos.x + size.x * 0.4 - box.width.x * 1.2, pos.y + size.y * 0.47 - box.width.y * 1.2, pos.x + size.x * 0.42, pos.y + size.y * 0.47, 2.)

  ctx |> set_color(white)
  ctx |> goto_xy(pos.x + size.x * 0.4 - strBox.width.x, pos.y + size.y * 0.45)
  ctx |> draw_str_scaled(1., thousands, thousands |> length())

  let rotKm = cvt(alt, 0., 10000., PI * 0.5, PI * 2.5)
  ctx |> setRotViewTm(pos.x + size.x * 0.5, pos.y + size.y * 0.5, rotKm, 0., false)

  let lineCoord <- to_array_move(fixed_array<float2>(float2(pos.x + size.x * 0.2, pos.y + size.y * 0.5),
    float2(pos.x + size.x * 0.5, pos.y + size.y * 0.5)))
  ctx |> render_line_aa(lineCoord, false, 5., float2(0., 0.), white)
  let poly <- to_array_move(fixed_array<float2>(float2(pos.x + size.x * 0.2, pos.y + size.y * 0.5),
    float2(pos.x + size.x * 0.27, pos.y + size.y * 0.45),
    float2(pos.x + size.x * 0.27, pos.y + size.y * 0.55)))
  ctx |> render_poly(poly, white)

  ctx |> resetViewTm()

  let rot = cvt(alt % 1000., 0., 1000., PI * 0.5, PI * 2.5)
  ctx |> setRotViewTm(pos.x + size.x * 0.5, pos.y + size.y * 0.5, rot, 0., false)

  let lineCoord2 <- to_array_move(fixed_array<float2>(float2(pos.x + size.x * 0.1, pos.y + size.y * 0.5),
    float2(pos.x + size.x * 0.5, pos.y + size.y * 0.5)))
  ctx |> render_line_aa(lineCoord2, false, 3., float2(0., 0.), white)
  let poly2 <- to_array_move(fixed_array<float2>(float2(pos.x + size.x * 0.05, pos.y + size.y * 0.5),
    float2(pos.x + size.x * 0.12, pos.y + size.y * 0.48),
    float2(pos.x + size.x * 0.12, pos.y + size.y * 0.52)))
  ctx |> render_poly(poly2, white)

  ctx |> resetViewTm()

def draw_speed_device(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; spd : float)
  render_picture(ctx, data.spdDevImage, pos, size, green)

  var rotSp = 0.
  if spd < 55.55
    rotSp = cvt(spd, 0., 55.55, PI * 0.5, PI * 0.69)
  elif spd < 111.11
    rotSp = cvt(spd, 55.55, 111.11, PI * 0.69, PI * 1.165)
  elif spd < 167.67
    rotSp = cvt(spd, 111.11, 166.67, PI * 1.165, PI * 1.5)
  elif spd < 277.78
    rotSp = cvt(spd, 166.67, 277.78, PI * 1.5, PI * 2.)
  else
    rotSp = cvt(spd, 277.78, 416.67, PI * 2., PI * 2.5)
  ctx |> setRotViewTm(pos.x + size.x * 0.5, pos.y + size.y * 0.5, rotSp, 0., false)

  let lineCoord <- to_array_move(fixed_array<float2>(float2(pos.x + size.x * 0.05, pos.y + size.y * 0.5),
    float2(pos.x + size.x * 0.5, pos.y + size.y * 0.5)))
  ctx |> render_line_aa(lineCoord, false, 3., float2(0., 0.), white)
  let poly <- to_array_move(fixed_array<float2>(float2(pos.x + size.x * 0.05, pos.y + size.y * 0.5),
    float2(pos.x + size.x * 0.12, pos.y + size.y * 0.48),
    float2(pos.x + size.x * 0.12, pos.y + size.y * 0.52)))
  ctx |> render_poly(poly, white)

  ctx |> resetViewTm()

def draw_heights(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; hei : float; barHei : float)
  var fctx : StdGuiFontContext
  let newFontSize = int(float(data.fontSize) * 1.5)
  get_font_context(fctx, data.fontId, 0, 0, newFontSize)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(newFontSize)
  ctx |> set_color(green)

  let text = "{roundi(barHei)}"
  let strBox = get_str_bbox(text, text |> length(), fctx)
  ctx |> goto_xy(pos.x + size.x - strBox.width.x - 10., pos.y + size.y * 0.09)
  ctx |> draw_str_scaled(1.f, text, text |> length())

  let altText = "{roundi(hei)}p"
  let altBox = get_str_bbox(altText, altText |> length(), fctx)
  ctx |> goto_xy(pos.x + size.x - altBox.width.x - 10., pos.y + size.y - 10.)
  ctx |> draw_str_scaled(1.f, altText, altText |> length())

def draw_speeds(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; ias : float; tas : float; mach : float)
  var fctx : StdGuiFontContext
  let newFontSize = int(float(data.fontSize) * 1.5)
  get_font_context(fctx, data.fontId, 0, 0, newFontSize)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(newFontSize)
  ctx |> set_color(green)

  let text = "{roundi(ias * mpsToKmh)}"
  ctx |> goto_xy(pos.x + 10., pos.y + size.y * 0.09)
  ctx |> draw_str_scaled(1.f, text, text |> length())

  let tasText = "{roundi(tas * mpsToKmh)}и"
  let tasBox = get_str_bbox(tasText, tasText |> length(), fctx)
  ctx |> goto_xy(pos.x + size.x * 0.2 - tasBox.width.x - 10., pos.y + size.y - 10.)
  ctx |> draw_str_scaled(1.f, tasText, tasText |> length())

  var fctxSmall : StdGuiFontContext
  get_font_context(fctxSmall, data.fontId, 0, 0, data.fontSize)

  let machText = "{int(mach)}"
  let machBox = get_str_bbox(machText, machText |> length(), fctx)
  var machPos = float2(pos.x + size.x * 0.15, pos.y + machBox.width.y + 5.)
  ctx |> goto_xy(machPos.x, machPos.y)
  ctx |> draw_str_scaled(1.f, machText, machText |> length())

  ctx |> set_font_ht(data.fontSize)
  let machSmText = ".{roundi((mach * 100.) % 100.)}"
  let machSmBox = get_str_bbox(machSmText, machSmText |> length(), fctxSmall)
  machPos.x += machBox.width.x
  ctx |> goto_xy(machPos.x, machPos.y)
  ctx |> draw_str_scaled(1.f, machSmText, machSmText |> length())

  ctx |> set_font_ht(newFontSize)
  machPos.x += machSmBox.width.x
  ctx |> goto_xy(machPos.x, machPos.y)
  ctx |> draw_char_u(uint16('M'))

def draw_rep_rpm(var ctx : GuiContext&; pos : float2; size : float2; rpm : float)
  let origin = pos + size * 0.5
  ctx |> set_color(green)
  ctx |> draw_line(origin.x - size.x * 0.52, origin.y, origin.x - size.x * 0.48, origin.y, 3.)
  if rpm > 0.25
    ctx |> draw_line(origin.x, origin.y - size.y * 0.53, origin.x, origin.y - size.y * 0.47, 3.)
  ctx |> render_sector_aa(origin, size * 0.5, float2(-PI, -PI + rpm * 1.9 * PI), 3.f, green, transparant)