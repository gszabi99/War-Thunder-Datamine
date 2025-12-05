require darg
require DagorStdGuiRender
require math
require DagorMath
require DagorSystem
require RadarHud
require strings
require Mission
require hud
require app
require WTInput

let transparentColor = E3DCOLOR(Color4(float4(0, 0, 0, 0)))

struct CanvasParams
  color : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  fontId : int = -1
  fontSize : int = 20
  handleClicks : bool = false

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
  storage.handleClicks = props |> getBool("handleClicks", false)

[export, unused_argument(rdata, rstate)]
def draw_radar_indication(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  if get_app().isSensorViewMode || !get_radar_hud_visible()
    return
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

  var needToHandleClick = data.handleClicks && is_mouse_btn_down(0)

  foreach_screen_targets() <| $(var target)
    if target.forIlsOnly
      return
    var color = float4(Color4(data.color))
    var opacity = 1.0
    if get_radar_hud_selected_target_blinking()
      opacity = 0.5 * (1.f - cos((time % 0.5) / 0.5 * PI)) //InOutSine easing
    opacity *= 1.0 - get_radar_hud_selected_target_fade()
    color *= lerp(0.2, 1., opacity)
    if target.isGhost
      color *= 0.25
    let e3dColor = E3DCOLOR(Color4(color))
    ctx |> set_color(e3dColor)

    let lt = target.pos - float2(0.5 * targetOnScreenWidth)
    let rb = target.pos + float2(0.5 * targetOnScreenWidth)
    if target.isTracked
      ctx |> render_frame(lt.x - ctx |> hdpx(2.), lt.y - ctx |> hdpx(2.), rb.x + ctx |> hdpx(2.), rb.y + ctx |> hdpx(2.), ctx |> hdpx(4.))
    elif target.isDetected
      ctx |> render_line_aa(to_array_move(fixed_array<float2>(lt, lt + float2(0.4 * targetOnScreenWidth, 0.))), false, ctx |> hdpx(4.), float2(0, 0), e3dColor)
      ctx |> render_line_aa(to_array_move(fixed_array<float2>(lt, lt + float2(0., 0.4 * targetOnScreenWidth))), false, ctx |> hdpx(4.), float2(0, 0), e3dColor)
      ctx |> render_line_aa(to_array_move(fixed_array<float2>(float2(rb.x, lt.y), lt + float2(0.6 * targetOnScreenWidth, 0.))), false, ctx |> hdpx(4.), float2(0, 0), e3dColor)
      ctx |> render_line_aa(to_array_move(fixed_array<float2>(float2(rb.x, lt.y), float2(rb.x, lt.y + 0.4 * targetOnScreenWidth))), false, ctx |> hdpx(4.), float2(0, 0), e3dColor)
      ctx |> render_line_aa(to_array_move(fixed_array<float2>(rb, float2(lt.x + 0.6 * targetOnScreenWidth, rb.y))), false, ctx |> hdpx(4.), float2(0, 0), e3dColor)
      ctx |> render_line_aa(to_array_move(fixed_array<float2>(rb, float2(rb.x, lt.y + 0.6 * targetOnScreenWidth))), false, ctx |> hdpx(4.), float2(0, 0), e3dColor)
      ctx |> render_line_aa(to_array_move(fixed_array<float2>(float2(lt.x, rb.y), float2(lt.x + 0.4 * targetOnScreenWidth, rb.y))), false, ctx |> hdpx(4.), float2(0, 0), e3dColor)
      ctx |> render_line_aa(to_array_move(fixed_array<float2>(float2(lt.x, rb.y), float2(lt.x, lt.y + 0.6 * targetOnScreenWidth))), false, ctx |> hdpx(4.), float2(0, 0), e3dColor)
    else
      ctx |> render_line_aa(to_array_move(fixed_array<float2>(lt, lt + float2(0.1 * targetOnScreenWidth, 0.))), false, ctx |> hdpx(4.), float2(0, 0), e3dColor)
      ctx |> render_line_aa(to_array_move(fixed_array<float2>(lt, lt + float2(0., 0.1 * targetOnScreenWidth))), false, ctx |> hdpx(4.), float2(0, 0), e3dColor)
      ctx |> render_line_aa(to_array_move(fixed_array<float2>(float2(rb.x, lt.y), lt + float2(0.9 * targetOnScreenWidth, 0.))), false, ctx |> hdpx(4.), float2(0, 0), e3dColor)
      ctx |> render_line_aa(to_array_move(fixed_array<float2>(float2(rb.x, lt.y), float2(rb.x, lt.y + 0.1 * targetOnScreenWidth))), false, ctx |> hdpx(4.), float2(0, 0), e3dColor)
      ctx |> render_line_aa(to_array_move(fixed_array<float2>(rb, float2(lt.x + 0.9 * targetOnScreenWidth, rb.y))), false, ctx |> hdpx(4.), float2(0, 0), e3dColor)
      ctx |> render_line_aa(to_array_move(fixed_array<float2>(rb, float2(rb.x, lt.y + 0.9 * targetOnScreenWidth))), false, ctx |> hdpx(4.), float2(0, 0), e3dColor)
      ctx |> render_line_aa(to_array_move(fixed_array<float2>(float2(lt.x, rb.y), float2(lt.x + 0.1 * targetOnScreenWidth, rb.y))), false, ctx |> hdpx(4.), float2(0, 0), e3dColor)
      ctx |> render_line_aa(to_array_move(fixed_array<float2>(float2(lt.x, rb.y), float2(lt.x, lt.y + 0.9 * targetOnScreenWidth))), false, ctx |> hdpx(4.), float2(0, 0), e3dColor)

    if /*targerAspectEnabled*/target.losSpeed < 3000.
      let pos = float2((lt.x + rb.x) * 0.5, rb.y + 0.75 * targetOnScreenWidth)
      let targetSpd = sqrt(target.losHorSpeed * target.losHorSpeed + target.losSpeed * target.losSpeed)
      let targetSpdInv = 1. / max(targetSpd, 1.)
      ctx |> render_ellipse_aa(pos, float2(targetOnScreenWidth * 0.15), ctx |> hdpx(4.), e3dColor, transparentColor)
      ctx |> draw_line(pos.x - target.losHorSpeed * targetSpdInv * 0.15 * targetOnScreenWidth,
        pos.y - target.losSpeed * targetSpdInv * 0.15 * targetOnScreenWidth,
        pos.x - target.losHorSpeed * targetSpdInv * min(0.15 * targetOnScreenWidth + targetSpd * 0.1, 0.75 * targetOnScreenWidth),
        pos.y - target.losSpeed * targetSpdInv * min(0.15 * targetOnScreenWidth + targetSpd * 0.1, 0.75 * targetOnScreenWidth), ctx |> hdpx(4.))

    if target.hasAimPos
      var screenPos = float2(0.)
      if world_to_screen(target.aimPos, screenPos)
        ctx |> render_ellipse_aa(screenPos, float2(targetOnScreenWidth * 0.25), ctx |> hdpx(4.), e3dColor, transparentColor)

    if needToHandleClick
      let bbox = BBox2(lt, rb)
      if bbox & get_mouse_pos()
        needToHandleClick = false
        radar_switch_to_target(target.sourceObjectId)

    if get_radar_hud_targeting_indicator_has_distance_scale()
      let distText = get_measure_units_text(MeasureUnitsTypes.MEASURE_UNIT_DIST, target.dist, true, 0.1)
      let distStrBox = get_str_bbox(distText, distText |> length(), fctx)
      ctx |> goto_xy(rb.x + ctx |> hdpx(5.), lt.y + distStrBox.width.y)
      ctx |> set_font(data.fontId, 0, 0)
      ctx |> set_font_ht(data.fontSize)
      ctx |> set_draw_str_attr(FontFxType.FFT_GLOW, 0, 0, get_font_fx_color(data.color), get_font_fx_factor(data.color, ctx))
      ctx |> draw_str_scaled(1.0, distText, distText |> length())

      let altText = get_measure_units_text(MeasureUnitsTypes.MEASURE_UNIT_DIST, target.altRel, true, 0.1)
      let altStrBox = get_str_bbox(altText, altText |> length(), fctx)
      ctx |> goto_xy(target.pos.x - 0.5 * altStrBox.width.x, target.pos.y + 0.5 * targetOnScreenWidth + ctx |> hdpx(5.) + altStrBox.width.y)
      ctx |> set_font(data.fontId, 0, 0)
      ctx |> set_font_ht(data.fontSize)
      ctx |> set_draw_str_attr(FontFxType.FFT_GLOW, 0, 0, get_font_fx_color(data.color), get_font_fx_factor(data.color, ctx))
      ctx |> draw_str_scaled(1.0, altText, altText |> length())

    let idText = loc(target.id)
    if idText != ""
      let idStrBox = get_str_bbox(idText, idText |> length(), fctx)
      ctx |> goto_xy(target.pos.x - 0.5 * idStrBox.width.x, target.pos.y - 0.5 * targetOnScreenWidth + ctx |> hdpx(5.) - idStrBox.width.y)
      ctx |> set_font(data.fontId, 0, 0)
      ctx |> set_font_ht(data.fontSize)
      ctx |> set_draw_str_attr(FontFxType.FFT_GLOW, 0, 0, get_font_fx_color(data.color), get_font_fx_factor(data.color, ctx))
      ctx |> draw_str_scaled(1.0, idText, idText |> length())

    if target.radSpeed > -3000.
      var colorSpd = float4(Color4(data.color))
      var speedOpacity = opacity
      if get_radar_hud_selected_target_speed_blinking()
        speedOpacity = 0.5 * (1.f - cos((time % 0.5) / 0.5 * PI))//InOutSine easing
      colorSpd *= lerp(0.42, 1., speedOpacity)
      let spdColor = E3DCOLOR(Color4(colorSpd))
      ctx |> set_color(spdColor)
      let spdText = get_measure_units_text(MeasureUnitsTypes.MEASURE_UNIT_RADIAL_SPEED, target.radSpeed, true, 1.)
      ctx |> goto_xy(rb.x + ctx |> hdpx(5.), rb.y)
      ctx |> draw_str_scaled(1.0, spdText, spdText |> length())