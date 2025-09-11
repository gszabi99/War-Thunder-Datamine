require darg
require DagorStdGuiRender
require %rGui.utils.canvas_common
require FlightModelWrap
require HeroManager
require Unit
require math
require DagorMath
require strings
require %rGui.utils.constants_common
require app
require Plane

struct CanvasParams
  fontId : int = -1
  fontSize : int = 20
  lineWidth : float = 2.
  rpmImg : Picture?
  tempImg : Picture?

let green = E3DCOLOR(0xFF10FF10)
let yellow = E3DCOLOR(0xFFFFFF10)
let red = E3DCOLOR(0xFFFF1010)
let arrowRed = E3DCOLOR(0xFFFF0000)
let blue = E3DCOLOR(0xFF10FFF0)
let white = E3DCOLOR(0xFFFFFFFF)
let transparent = E3DCOLOR(0x00000000)
let black = E3DCOLOR(0xFF000000)
let lineColor = E3DCOLOR(0xFFFFFF0F)

[export]
def setup(props : Properties&; var storage : CanvasParams&)
  storage.fontId = props |> getFontId()
  storage.fontSize = props |> getInt("fontSize", 16)
  storage.lineWidth = props |> getFloat("lineWidth", 2.)
  storage.rpmImg = props |> getPicture("rpmTex")
  storage.tempImg = props |> getPicture("temperatureTex")

[export, unused_argument(rstate)]
def draw(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed
    return
  var fmw = hero |> as_fmw()
  if fmw == null
    return

  if fmw.fm.EI.numEngines > 0
    assume propulsion = *(fmw.fm.EI)
    propulsion_getEngine(propulsion, 0) <| $(mainEngine)
      let rpm1 = mainEngine.omegaRel
      let egt1 = mainEngine.waterTemp + zeroKelvinInCelsium
      let oilPress = mainEngine.oilPressure
      let hydPress = clamp(3. * rpm1, 0., 1.) * 3000.
      let fuelCons = mainEngine.fuelConsumption * kgToPound * 3600.
      draw_rpm_indicator(ctx, rdata.pos + float2(10., rdata.size.y * 0.02), float2(rdata.size.y * 0.4, rdata.size.y * 0.35), data, rpm1)
      draw_egt_indicator(ctx, rdata.pos + float2(10., rdata.size.y * 0.39), float2(rdata.size.y * 0.4, rdata.size.y * 0.35), data, egt1)
      draw_oil_press_ind(ctx, rdata.pos + float2(rdata.size.x * 0.74, rdata.size.y * 0.1), float2(rdata.size.x * 0.1, rdata.size.y * 0.3), data, oilPress, true)
      draw_hydr_press_ind(ctx, rdata.pos + float2(rdata.size.x * 0.74, rdata.size.y * 0.52), float2(rdata.size.x * 0.1, rdata.size.y * 0.3), data, hydPress, true)
      draw_fuel_cons(ctx, rdata.pos + float2(rdata.size.y * 0.1, rdata.size.y * 0.85), float2(rdata.size.y * 0.2), data, fuelCons)
    draw_nozzle(ctx, rdata.pos + float2(10., rdata.size.y * 0.77), float2(rdata.size.y * 0.4), data, get_nozzle_angle(fmw, 0))
    if fmw.fm.EI.numEngines > 1
      propulsion_getEngine(propulsion, 1) <| $(mainEngine)
        let rpm2 = mainEngine.omegaRel
        let egt2 = mainEngine.waterTemp + zeroKelvinInCelsium
        let oilPress = mainEngine.oilPressure
        let hydPress = clamp(3. * rpm2, 0., 1.) * 3000.
        let fuelCons = mainEngine.fuelConsumption * kgToPound * 3600.
        draw_rpm_indicator(ctx, rdata.pos + float2(rdata.size.y * 0.5, rdata.size.y * 0.02), float2(rdata.size.y * 0.4, rdata.size.y * 0.35), data, rpm2)
        draw_egt_indicator(ctx, rdata.pos + float2(rdata.size.y * 0.5, rdata.size.y * 0.39), float2(rdata.size.y * 0.4, rdata.size.y * 0.35), data, egt2)
        draw_oil_press_ind(ctx, rdata.pos + float2(rdata.size.x * 0.87, rdata.size.y * 0.1), float2(rdata.size.x * 0.1, rdata.size.y * 0.3), data, oilPress, false)
        draw_hydr_press_ind(ctx, rdata.pos + float2(rdata.size.x * 0.87, rdata.size.y * 0.52), float2(rdata.size.x * 0.1, rdata.size.y * 0.3), data, hydPress, true)
        draw_fuel_cons(ctx, rdata.pos + float2(rdata.size.y * 0.6, rdata.size.y * 0.85), float2(rdata.size.y * 0.2), data, fuelCons)
      draw_nozzle(ctx, rdata.pos + float2(rdata.size.y * 0.5, rdata.size.y * 0.77), float2(rdata.size.y * 0.4), data, get_nozzle_angle(fmw, 1))
    draw_rpm_label(ctx, rdata.pos, rdata.size, data)
    draw_egt_label(ctx, rdata.pos, rdata.size, data)
    draw_oil_press_label(ctx, rdata.pos, rdata.size, data)
    draw_hyd_press_label(ctx, rdata.pos, rdata.size, data)
    draw_nozzle_label(ctx, rdata.pos + float2(10., rdata.size.y * 0.77), float2(rdata.size.y * 0.84), data)
    draw_fuel_cons_label(ctx, rdata.pos + float2(10., rdata.size.y * 0.85), float2(rdata.size.y * 0.84), data)

  ctx |> set_color(green)
  ctx |> draw_line(rdata.pos.x + rdata.size.x, rdata.pos.y, rdata.pos.x + rdata.size.x, rdata.pos.y + rdata.size.y, data.lineWidth)

def draw_rpm_indicator(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; rpm : float)
  var rot = 0.
  if rpm < 0.6
    rot = cvt(rpm, 0., 0.6, -PI * 0.67, -PI * 0.18)
  else
    rot = cvt(rpm, 0.6, 1.1, -PI * 0.18, PI * 0.67)

  var sina, cosa : float
  sincos(rot, sina, cosa)
  let lineCoord <- to_array_move(fixed_array<float2>(float2(pos.x + size.x * (0.5 - cosa * 0.45), pos.y + size.y * (0.5 - sina * 0.45)),
    float2(pos.x + size.x * 0.5, pos.y + size.y * 0.5)))
  ctx |> render_line_aa(lineCoord, false, 3., float2(0., 0.), rpm < 0.5 ? arrowRed : white)

  render_picture(ctx, data.rpmImg, pos, size, white)

  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)

  let text = "{roundi(rpm * 100.)}"
  let strBox = get_str_bbox(text, text |> length(), fctx)
  if rpm < 0.5
    let tc = float2(0., 0.)
    ctx |> set_color(red)
    ctx |> render_rect(pos.x + size.x * 0.6, pos.y + size.y * 0.5 - strBox.width.y * 0.7,
     pos.x + size.x, pos.y + size.y * 0.5 + strBox.width.y * 0.7,
     tc, tc, tc)

  ctx |> set_color(rpm > 0.5 ? green : black)
  ctx |> goto_xy(pos.x + size.x - strBox.width.x - 5., pos.y + size.y * 0.5 + strBox.width.y * 0.5)
  ctx |> draw_str_scaled(1., text, text |> length())

def draw_rpm_label(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&)
  ctx |> set_color(white)
  let labelPos = float2(pos.x + size.y * 0.45, pos.y + size.y * 0.12)
  draw_vertical_label(ctx, labelPos, "RPM", float(data.fontSize) * 1.5)

def draw_egt_indicator(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; egt : float)
  var rot = 0.
  if egt < 500.
    rot = cvt(egt, 0., 500., -PI * 0.84, -PI * 0.35)
  elif egt < 700.
    rot = cvt(egt, 500., 700., -PI * 0.35, PI * 0.5)
  else
    rot = cvt(egt, 700., 1200., PI * 0.5, PI * 0.8)


  var color = white
  if egt > 325. && egt <= 675.
    color = green
  elif egt >= 675. && egt <= 685.
    color = yellow
  elif egt <= 325.
    color = white
  else
    color = arrowRed
  var sina, cosa : float
  sincos(rot, sina, cosa)
  let lineCoord <- to_array_move(fixed_array<float2>(float2(pos.x + size.x * (0.5 - cosa * 0.45), pos.y + size.y * (0.5 - sina * 0.45)),
    float2(pos.x + size.x * 0.5, pos.y + size.y * 0.5)))
  ctx |> render_line_aa(lineCoord, false, 3., float2(0., 0.), color)

  render_picture(ctx, data.tempImg, pos, size, white)

  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)

  let text = "{roundi(egt)}"
  let strBox = get_str_bbox(text, text |> length(), fctx)

  ctx |> set_color(color)
  ctx |> goto_xy(pos.x + size.x - strBox.width.x, pos.y + size.y * 0.5 + strBox.width.y * 0.5)
  ctx |> draw_str_scaled(1., text, text |> length())

def draw_egt_label(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&)
  ctx |> set_color(white)
  let labelPos = float2(pos.x + size.y * 0.45, pos.y + size.y * 0.47)
  draw_vertical_label(ctx, labelPos, "EGTC", float(data.fontSize) * 1.3)

def draw_oil_press_ind(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; press : float; is_left : bool)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)

  let sideText = is_left ? "L" : "R"
  let sideStrBox = get_str_bbox(sideText, sideText |> length(), fctx)

  ctx |> set_color(white)
  ctx |> goto_xy(pos.x + size.x * 0.5 - sideStrBox.width.x * 0.5, pos.y + sideStrBox.width.y)
  ctx |> draw_str_scaled(1., sideText, sideText |> length())

  let pressText = fmt(":.1f", press * 30.)
  let strBox = get_str_bbox(pressText, pressText |> length(), fctx)
  if press < 0.2
    let tc = float2(0., 0.)
    ctx |> set_color(red)
    ctx |> render_rect(pos.x + size.x * 0.5 - strBox.width.x * 0.7, pos.y + size.y - strBox.width.y * 1.2,
     pos.x + size.x * 0.5 + strBox.width.x * 0.7, pos.y + size.y, tc, tc, tc)
  ctx |> set_color(press < 0.2 ? black : green)
  ctx |> goto_xy(pos.x + size.x * 0.5 - strBox.width.x * 0.5, pos.y + size.y - strBox.width.y * 0.1)
  ctx |> draw_str_scaled(1., pressText, pressText |> length())

  ctx |> set_color(white)
  let len = size.y - strBox.width.y * 1.4 - sideStrBox.width.y * 1.2
  ctx |> draw_line(pos.x + size.x * 0.5, pos.y + sideStrBox.width.y * 1.2, pos.x + size.x * 0.5, pos.y + sideStrBox.width.y + len, 10.)

  ctx |> set_color(press < 0.2 ? red : green)
  let posY = cvt(press, 0., 1., pos.y + sideStrBox.width.y * 1.2 + len, pos.y + sideStrBox.width.y + len * 0.7)
  ctx |> draw_line(pos.x + size.x * 0.2, posY, pos.x + size.x * 0.8, posY, data.lineWidth * 2.)

def draw_oil_press_label(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)
  ctx |> set_color(white)

  let text = "OIL PRESS"
  let strBox = get_str_bbox(text, text |> length(), fctx)
  let labelPos = float2(pos.x + size.x * 0.75, pos.y + strBox.width.y + size.y * 0.03)
  ctx |> goto_xy(labelPos.x, labelPos.y)
  ctx |> draw_str_scaled(1., text, text |> length())

def draw_hydr_press_ind(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; press : float; is_left : bool)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)

  let sideText = is_left ? "UTIL" : "FLT"
  let sideStrBox = get_str_bbox(sideText, sideText |> length(), fctx)

  ctx |> set_color(white)
  ctx |> goto_xy(pos.x + size.x * 0.5 - sideStrBox.width.x * 0.5, pos.y + sideStrBox.width.y)
  ctx |> draw_str_scaled(1., sideText, sideText |> length())

  let textColor = press < 1500. ? black : (press < 2800. ? white : green)
  let pressText = "{roundi(press)}"
  let strBox = get_str_bbox(pressText, pressText |> length(), fctx)
  let maxText = "1500"
  let maxStrBox = get_str_bbox(maxText, maxText |> length(), fctx)
  if press < 1500.
    let tc = float2(0., 0.)
    ctx |> set_color(red)
    ctx |> render_rect(pos.x + size.x * 0.5 - maxStrBox.width.x * 0.6, pos.y + size.y - maxStrBox.width.y * 1.2,
     pos.x + size.x * 0.5 + maxStrBox.width.x * 0.6, pos.y + size.y, tc, tc, tc)
  ctx |> set_color(textColor)
  ctx |> goto_xy(pos.x + size.x * 0.5 - strBox.width.x * 0.5, pos.y + size.y - strBox.width.y * 0.1)
  ctx |> draw_str_scaled(1., pressText, pressText |> length())

  ctx |> set_color(white)
  let len = size.y - strBox.width.y * 1.4 - sideStrBox.width.y * 1.2
  ctx |> draw_line(pos.x + size.x * 0.5, pos.y + sideStrBox.width.y * 1.2, pos.x + size.x * 0.5, pos.y + sideStrBox.width.y + len, 10.)

  ctx |> set_color(press < 1500. ? red : green)
  let posY = cvt(press, 0., 3000., pos.y + sideStrBox.width.y * 1.2 + len, pos.y + sideStrBox.width.y + len * 0.25)
  ctx |> draw_line(pos.x + size.x * 0.2, posY, pos.x + size.x * 0.8, posY, data.lineWidth * 2.)

def draw_hyd_press_label(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)
  ctx |> set_color(white)

  let text = "HYD PRESS"
  let strBox = get_str_bbox(text, text |> length(), fctx)
  let labelPos = float2(pos.x + size.x * 0.75, pos.y + strBox.width.y + size.y * 0.44)
  ctx |> goto_xy(labelPos.x, labelPos.y)
  ctx |> draw_str_scaled(1., text, text |> length())

def draw_nozzle_label(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)
  ctx |> set_color(white)

  let name = "NZ%"
  let strBox = get_str_bbox(name, name |> length(), fctx)
  let labelPos = float2(pos.x + (size.x - strBox.width.x) * 0.5, pos.y + strBox.width.y)
  ctx |> goto_xy(labelPos.x, labelPos.y)
  ctx |> draw_str_scaled(1., name, name |> length())

def draw_nozzle(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; value : float)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)
  ctx |> set_color(green)

  let text = "{roundi(value * 100.)}"
  let strBox = get_str_bbox(text, text |> length(), fctx)
  let labelPos = float2(pos.x + (size.x - strBox.width.x) * 0.5, pos.y + strBox.width.y)
  ctx |> goto_xy(labelPos.x, labelPos.y)
  ctx |> draw_str_scaled(1., text, text |> length())

def draw_fuel_cons(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; value : float)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)
  ctx |> set_color(blue)

  let text = "{roundi(value)}"
  let strBox = get_str_bbox(text, text |> length(), fctx)
  let labelPos = float2(pos.x + size.x - strBox.width.x, pos.y + strBox.width.y)
  ctx |> goto_xy(labelPos.x, labelPos.y)
  ctx |> draw_str_scaled(1., text, text |> length())

  let maxText = "999"
  let maxStrBox = get_str_bbox(maxText, maxText |> length(), fctx)

  ctx |> render_frame(pos.x, pos.y - maxStrBox.width.y * 0.3,
   pos.x + size.x + maxStrBox.width.x * 0.2, pos.y + maxStrBox.width.y * 1.3, data.lineWidth)

def draw_fuel_cons_label(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)
  ctx |> set_color(white)

  let name = "FF(PPH)"
  let strBox = get_str_bbox(name, name |> length(), fctx)
  let labelPos = float2(pos.x + (size.x - strBox.width.x) * 0.5, pos.y + strBox.width.y)
  ctx |> goto_xy(labelPos.x, labelPos.y)
  ctx |> draw_str_scaled(1., name, name |> length())