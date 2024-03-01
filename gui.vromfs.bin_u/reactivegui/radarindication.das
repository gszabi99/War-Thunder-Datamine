require darg
require DagorStdGuiRender
require math
require DagorMath
require DagorSystem
require RadarHud
require strings
require Mission
require hud

let transparentColor = E3DCOLOR(Color4(float4(0, 0, 0, 0)))

struct CanvasParams
  color : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  fontId : int = -1
  fontSize : int = 20

def get_font_fx_color(color : E3DCOLOR)
  return is_dark_color(color) ? E3DCOLOR(0x78FFFFFF) : E3DCOLOR(0x78000000)

def get_font_fx_factor(color : E3DCOLOR; var ctx : GuiContext&)
  let fontOutlineFxFactor = max(70., ctx |> hdpx(90.))
  return int(is_dark_color(color) ? fontOutlineFxFactor * 0.15 : fontOutlineFxFactor)

[export]
def setup_data(props : Properties&; var storage : CanvasParams&)
  storage.color = fade_color(props |> getColor("color", E3DCOLOR(0xFFFFFFFF)), 255)
  storage.fontId = props |> getFontId()
  storage.fontSize = props |> getInt("fontSize", 20)

[export]
def draw_radar_indication(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  targets_on_screen(ctx, data)

def foreach_screen_targets(blk : block<(target : RadarScreenTarget const const#) : void>)
  get_radar_hud_screen_targets() <| $(targets : array<RadarScreenTarget> const#)
    for t in targets
      invoke(blk, t)

def targets_on_screen(var ctx : GuiContext&; data : CanvasParams&)
  if !get_radar_hud_has_azimuth_scale()
    return
  let targetOnScreenWidth = ctx |> hdpx(50.)
  var fctx : StdGuiFontContext
  let time = float(get_total_time())
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  foreach_screen_targets() <| $(var target)
    var color = float4(Color4(data.color))
    if get_radar_hud_selected_target_blinking()
      let mult = 0.5 * (1.f - cos((time % 0.5) / 0.5 * PI));//InOutSine easing
      color *= lerp(0.2, 1., mult)
    if target.isGhost
      color *= 0.25
    let e3dColor = E3DCOLOR(Color4(color))
    ctx |> set_color(e3dColor)

    let lt = target.pos - float2(0.5 * targetOnScreenWidth)
    let rb = target.pos + float2(0.5 * targetOnScreenWidth)
    if target.isTracked
      ctx |> render_frame(lt.x - ctx |> hdpx(2.), lt.y - ctx |> hdpx(2.), rb.x + ctx |> hdpx(2.), rb.y + ctx |> hdpx(2.), ctx |> hdpx(4.))
    elif target.isDetected
      ctx |> render_line_aa(to_array_move([[float2[2] lt; lt + float2(0.4 * targetOnScreenWidth, 0.)]]), false, ctx |> hdpx(4.), float2(0, 0), data.color)
      ctx |> render_line_aa(to_array_move([[float2[2] lt; lt + float2(0., 0.4 * targetOnScreenWidth)]]), false, ctx |> hdpx(4.), float2(0, 0), data.color)
      ctx |> render_line_aa(to_array_move([[float2[2] float2(rb.x, lt.y); lt + float2(0.6 * targetOnScreenWidth, 0.)]]), false, ctx |> hdpx(4.), float2(0, 0), data.color)
      ctx |> render_line_aa(to_array_move([[float2[2] float2(rb.x, lt.y); float2(rb.x, lt.y + 0.4 * targetOnScreenWidth)]]), false, ctx |> hdpx(4.), float2(0, 0), data.color)
      ctx |> render_line_aa(to_array_move([[float2[2] rb; float2(lt.x + 0.6 * targetOnScreenWidth, rb.y)]]), false, ctx |> hdpx(4.), float2(0, 0), data.color)
      ctx |> render_line_aa(to_array_move([[float2[2] rb; float2(rb.x, lt.y + 0.6 * targetOnScreenWidth)]]), false, ctx |> hdpx(4.), float2(0, 0), data.color)
      ctx |> render_line_aa(to_array_move([[float2[2] float2(lt.x, rb.y); float2(lt.x + 0.4 * targetOnScreenWidth, rb.y)]]), false, ctx |> hdpx(4.), float2(0, 0), data.color)
      ctx |> render_line_aa(to_array_move([[float2[2] float2(lt.x, rb.y); float2(lt.x, lt.y + 0.6 * targetOnScreenWidth)]]), false, ctx |> hdpx(4.), float2(0, 0), data.color)
    else
      ctx |> render_line_aa(to_array_move([[float2[2] lt; lt + float2(0.1 * targetOnScreenWidth, 0.)]]), false, ctx |> hdpx(4.), float2(0, 0), data.color)
      ctx |> render_line_aa(to_array_move([[float2[2] lt; lt + float2(0., 0.1 * targetOnScreenWidth)]]), false, ctx |> hdpx(4.), float2(0, 0), data.color)
      ctx |> render_line_aa(to_array_move([[float2[2] float2(rb.x, lt.y); lt + float2(0.9 * targetOnScreenWidth, 0.)]]), false, ctx |> hdpx(4.), float2(0, 0), data.color)
      ctx |> render_line_aa(to_array_move([[float2[2] float2(rb.x, lt.y); float2(rb.x, lt.y + 0.1 * targetOnScreenWidth)]]), false, ctx |> hdpx(4.), float2(0, 0), data.color)
      ctx |> render_line_aa(to_array_move([[float2[2] rb; float2(lt.x + 0.9 * targetOnScreenWidth, rb.y)]]), false, ctx |> hdpx(4.), float2(0, 0), data.color)
      ctx |> render_line_aa(to_array_move([[float2[2] rb; float2(rb.x, lt.y + 0.9 * targetOnScreenWidth)]]), false, ctx |> hdpx(4.), float2(0, 0), data.color)
      ctx |> render_line_aa(to_array_move([[float2[2] float2(lt.x, rb.y); float2(lt.x + 0.1 * targetOnScreenWidth, rb.y)]]), false, ctx |> hdpx(4.), float2(0, 0), data.color)
      ctx |> render_line_aa(to_array_move([[float2[2] float2(lt.x, rb.y); float2(lt.x, lt.y + 0.9 * targetOnScreenWidth)]]), false, ctx |> hdpx(4.), float2(0, 0), data.color)

    let distText = get_measure_units_text(MeasureUnitsTypes MEASURE_UNIT_DIST, target.dist, true, 0.1)
    let strBox = get_str_bbox(distText, distText |> length(), fctx)
    ctx |> goto_xy(rb.x + ctx |> hdpx(5.), lt.y + strBox.width.y)
    ctx |> set_font(data.fontId, 0, 0)
    ctx |> set_font_ht(data.fontSize);
    ctx |> set_draw_str_attr(FontFxType FFT_GLOW, 0, 0, get_font_fx_color(data.color), get_font_fx_factor(data.color, ctx))
    ctx |> draw_str_scaled(1.0, distText, distText |> length())

    if /*targerAspectEnabled*/target.losSpeed < 3000.
      let pos = float2((lt.x + rb.x) * 0.5, rb.y + 0.75 * targetOnScreenWidth)
      let targetSpd = sqrt(target.losHorSpeed * target.losHorSpeed + target.losSpeed * target.losSpeed)
      let targetSpdInv = 1. / max(targetSpd, 1.)
      ctx |> render_ellipse_aa(pos, float2(targetOnScreenWidth * 0.15), ctx |> hdpx(4.), e3dColor, transparentColor)
      ctx |> draw_line(pos.x - target.losHorSpeed * targetSpdInv * 0.15 * targetOnScreenWidth,
        pos.y - target.losSpeed * targetSpdInv * 0.15 * targetOnScreenWidth,
        pos.x - target.losHorSpeed * targetSpdInv * min(0.15 * targetOnScreenWidth + targetSpd * 0.1, 0.75 * targetOnScreenWidth),
        pos.y - target.losSpeed * targetSpdInv * min(0.15 * targetOnScreenWidth + targetSpd * 0.1, 0.75 * targetOnScreenWidth), ctx |> hdpx(4.))

    if target.radSpeed > -3000.
      if get_radar_hud_selected_target_speed_blinking()
        var colorSpd = float4(Color4(data.color))
        let mult = 0.5 * (1.f - cos((time % 0.5) / 0.5 * PI));//InOutSine easing
        colorSpd *= lerp(0.42, 1., mult)
        let spdColor = E3DCOLOR(Color4(colorSpd))
        ctx |> set_color(spdColor)
      let spdText = get_measure_units_text(MeasureUnitsTypes MEASURE_UNIT_RADIAL_SPEED, target.radSpeed, true, 1.)
      ctx |> goto_xy(rb.x + ctx |> hdpx(5.), rb.y)
      ctx |> draw_str_scaled(1.0, spdText, spdText |> length())