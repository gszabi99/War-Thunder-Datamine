require darg
require DagorStdGuiRender
require DagorMath
require FlightModelWrap
require HeroManager
require Unit
require math
require strings
require DagorTime
require FlightControl

// F-15EX top UFCD bar: button-style cells with gaps
let white = E3DCOLOR(0xFFFFFFFF)
let f15Green = E3DCOLOR(0xFF00DD00)
let f15Bg = E3DCOLOR(0xFF0A0A0A)
let btnBg = E3DCOLOR(0xFF151515)

struct CanvasParams
  fontId : int = -1
  fontSize : int = 20
  lineWidth : float = 1.

[export]
def setup(props : Properties&; var storage : CanvasParams&)
  storage.fontId = props |> getFontId()
  storage.fontSize = props |> getInt("fontSize", 21)
  storage.lineWidth = props |> getFloat("lineWidth", 1.)

[export, unused_argument(rstate)]
def render(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  let pos = rdata.pos
  let size = rdata.size

  ctx |> set_color(f15Bg)
  ctx |> render_box(pos.x, pos.y, pos.x + size.x, pos.y + size.y)

  let cellCount = 17
  let pad = size.x * 0.003
  let cellW = (size.x - pad * 2.0) / float(cellCount)
  let cellH = size.y - pad * 2.0
  let cellY = pos.y + pad

  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)

  let now = get_local_time()

  let frameX = pos.x + pad
  let frameY = cellY
  let frameR = frameX + cellW * float(cellCount)
  let frameB = cellY + cellH

  let timeStr = "{fmt(":02d", now.x)}:{fmt(":02d", now.y)}"
  draw_button(ctx, data, fctx, cell_x(pos.x, pad, cellW, 0), cellY, cellW, cellH, white, timeStr, "")

  draw_button(ctx, data, fctx, cell_x(pos.x, pad, cellW, 1), cellY, cellW, cellH, f15Green, "CAUTION", "")

  draw_button(ctx, data, fctx, cell_x(pos.x, pad, cellW, 2), cellY, cellW, cellH, white, "A/P", "OFF", true)

  draw_button(ctx, data, fctx, cell_x(pos.x, pad, cellW, 3), cellY, cellW, cellH, white, "R1", "251.000", true)

  draw_button(ctx, data, fctx, cell_x(pos.x, pad, cellW, 4), cellY, cellW, cellH, white, "R2", "124.000", true)

  draw_button(ctx, data, fctx, cell_x(pos.x, pad, cellW, 5), cellY, cellW, cellH, white, "HF", "OFF", true)

  draw_button(ctx, data, fctx, cell_x(pos.x, pad, cellW, 6), cellY, cellW, cellH, white, "IFF ON", "", true)

  draw_button(ctx, data, fctx, cell_x(pos.x, pad, cellW, 7), cellY, cellW, cellH, white, "PP-EGI1", "", true)

  draw_button(ctx, data, fctx, cell_x(pos.x, pad, cellW, 8), cellY, cellW, cellH, white, "LAW", "500", true)

  let hero = get_controlled_hero()

  var tgpZoomStr = "OFF"
  if hero != null && !hero.isDelayed
    let tgpFmw = hero |> as_fmw()
    if tgpFmw != null
      let tgpCockpit = tgpFmw.cockpit
      if tgpCockpit != null
        let zoomVal = tgpCockpit.mfdZoom
        if zoomVal > 0.5
          tgpZoomStr = "NAR"
        else
          tgpZoomStr = "WIDE"
  draw_button(ctx, data, fctx, cell_x(pos.x, pad, cellW, 9), cellY, cellW, cellH, white, "TGP", tgpZoomStr, true)

  draw_button(ctx, data, fctx, cell_x(pos.x, pad, cellW, 10), cellY, cellW, cellH, white, "ILS", "OFF", true)

  draw_button(ctx, data, fctx, cell_x(pos.x, pad, cellW, 11), cellY, cellW, cellH, white, "HUD", "", true)

  draw_button(ctx, data, fctx, cell_x(pos.x, pad, cellW, 12), cellY, cellW, cellH, f15Green, "GCWS", "ON", true)

  draw_button(ctx, data, fctx, cell_x(pos.x, pad, cellW, 13), cellY, cellW, cellH, white, "NF-OFF", "TF-OFF", true)

  var c14line1 = "POS"
  var c14line2 = "UPDATE"
  var c14color = white
  var spiPos : float3
  let hasSpi = get_point_of_interest(spiPos)
  if hasSpi && hero != null && !hero.isDelayed
    c14line1 = "TGT"
    c14color = f15Green
    let heroPos = hero.unitTm[3]
    let dir = float2(spiPos.x - heroPos.x, spiPos.z - heroPos.z)
    let dist = length(dir)
    if dist > 10.0
      let heroVel = hero.vel
      let vel2d = float2(heroVel.x, heroVel.z)
      let velAlongDir = dot(vel2d, normalize(dir))
      if velAlongDir > 1.0
        let toa = ceili(dist / velAlongDir)
        if toa < 3600
          c14line2 = "{fmt(":02d", toa / 60)}:{fmt(":02d", toa % 60)}"
        else
          c14line2 = "TOA"
      else
        c14line2 = "---"
    else
      c14line2 = "TOA"
  draw_button(ctx, data, fctx, cell_x(pos.x, pad, cellW, 14), cellY, cellW, cellH, c14color, c14line1, c14line2, true)

  draw_button(ctx, data, fctx, cell_x(pos.x, pad, cellW, 15), cellY, cellW, cellH, white, "KEY", "PAD", true)

  draw_button(ctx, data, fctx, cell_x(pos.x, pad, cellW, 16), cellY, cellW, cellH, white, "SSB", "2", true)

  let lw = data.lineWidth * 0.7
  let outerFrame <- to_array_move(fixed_array<float2>(
    float2(frameX, frameY), float2(frameR, frameY), float2(frameR, frameB), float2(frameX, frameB), float2(frameX, frameY)))
  ctx |> render_line_aa(outerFrame, false, lw, float2(0., 0.), white)

  for i in range(1, cellCount)
    let divX = frameX + cellW * float(i)
    let divLine <- to_array_move(fixed_array<float2>(float2(divX, frameY), float2(divX, frameB)))
    ctx |> render_line_aa(divLine, false, lw, float2(0., 0.), white)


def cell_x(baseX : float; pad : float; cellW : float; idx : int) : float
  return baseX + pad + float(idx) * cellW


def draw_button(var ctx : GuiContext&; data : CanvasParams&; fctx : StdGuiFontContext; bx : float; by : float; bw : float; bh : float; textColor : E3DCOLOR; line1 : string; line2 : string; cornerMark : bool = false)
  ctx |> set_color(btnBg)
  ctx |> render_box(bx, by, bx + bw, by + bh)

  if cornerMark
    let cs = bh * 0.15
    let lw = data.lineWidth * 0.7
    let sqLine <- to_array_move(fixed_array<float2>(
      float2(bx + bw - cs, by), float2(bx + bw - cs, by + cs)))
    ctx |> render_line_aa(sqLine, false, lw, float2(0., 0.), textColor)
    let sqLine2 <- to_array_move(fixed_array<float2>(
      float2(bx + bw - cs, by + cs), float2(bx + bw, by + cs)))
    ctx |> render_line_aa(sqLine2, false, lw, float2(0., 0.), textColor)
    let slashLine <- to_array_move(fixed_array<float2>(
      float2(bx + bw - cs, by + bh), float2(bx + bw, by + bh - cs)))
    ctx |> render_line_aa(slashLine, false, lw, float2(0., 0.), textColor)

  ctx |> set_color(textColor)

  let centerY = by + bh * 0.5
  if line2 |> length() > 0
    let box1 = get_str_bbox(line1, line1 |> length(), fctx)
    let box2 = get_str_bbox(line2, line2 |> length(), fctx)
    let lineH = box1.width.y
    let gap2 = lineH * 0.15
    let totalH = lineH * 2.0 + gap2
    let baseY1 = centerY - totalH * 0.5 + lineH
    ctx |> goto_xy(bx + (bw - box1.width.x) * 0.5, baseY1)
    ctx |> draw_str_scaled(1.0, line1, line1 |> length())
    ctx |> goto_xy(bx + (bw - box2.width.x) * 0.5, baseY1 + lineH + gap2)
    ctx |> draw_str_scaled(1.0, line2, line2 |> length())
  else
    let box1 = get_str_bbox(line1, line1 |> length(), fctx)
    ctx |> goto_xy(bx + (bw - box1.width.x) * 0.5, centerY + box1.width.y * 0.5)
    ctx |> draw_str_scaled(1.0, line1, line1 |> length())
