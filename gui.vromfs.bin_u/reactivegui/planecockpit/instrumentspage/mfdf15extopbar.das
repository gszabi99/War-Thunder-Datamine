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
  storage.fontSize = props |> getInt("fontSize", 20)
  storage.lineWidth = props |> getFloat("lineWidth", 1.)

[export, unused_argument(rstate)]
def render(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  let pos = rdata.pos
  let size = rdata.size

  ctx |> set_color(f15Bg)
  ctx |> render_box(pos.x, pos.y, pos.x + size.x, pos.y + size.y)

  let cellCount = 17
  let gap = size.x * 0.003
  let totalGaps = gap * float(cellCount + 1)
  let cellW = (size.x - totalGaps) / float(cellCount)
  let cellH = size.y - gap * 2.0
  let cellY = pos.y + gap

  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)

  let now = get_local_time()

  let timeStr = "{fmt(":02d", now.x)}:{fmt(":02d", now.y)}"
  draw_button(ctx, data, fctx, cell_x(pos.x, gap, cellW, 0), cellY, cellW, cellH, white, white, timeStr, "")

  draw_button(ctx, data, fctx, cell_x(pos.x, gap, cellW, 1), cellY, cellW, cellH, f15Green, f15Green, "CAUTION", "")

  draw_button(ctx, data, fctx, cell_x(pos.x, gap, cellW, 2), cellY, cellW, cellH, white, white, "A/P", "OFF")

  draw_button(ctx, data, fctx, cell_x(pos.x, gap, cellW, 3), cellY, cellW, cellH, white, white, "R1", "251.000")

  draw_button(ctx, data, fctx, cell_x(pos.x, gap, cellW, 4), cellY, cellW, cellH, white, white, "R2", "124.000")

  draw_button(ctx, data, fctx, cell_x(pos.x, gap, cellW, 5), cellY, cellW, cellH, white, white, "HF", "OFF")

  draw_button(ctx, data, fctx, cell_x(pos.x, gap, cellW, 6), cellY, cellW, cellH, white, white, "IFF ON", "")

  draw_button(ctx, data, fctx, cell_x(pos.x, gap, cellW, 7), cellY, cellW, cellH, white, white, "PP-EGI1", "")

  draw_button(ctx, data, fctx, cell_x(pos.x, gap, cellW, 8), cellY, cellW, cellH, white, white, "LAW", "500")

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
  draw_button(ctx, data, fctx, cell_x(pos.x, gap, cellW, 9), cellY, cellW, cellH, white, white, "TGP", tgpZoomStr)

  draw_button(ctx, data, fctx, cell_x(pos.x, gap, cellW, 10), cellY, cellW, cellH, white, white, "ILS", "OFF")

  draw_button(ctx, data, fctx, cell_x(pos.x, gap, cellW, 11), cellY, cellW, cellH, white, white, "HUD", "")

  draw_button(ctx, data, fctx, cell_x(pos.x, gap, cellW, 12), cellY, cellW, cellH, f15Green, f15Green, "GCWS", "ON")

  draw_button(ctx, data, fctx, cell_x(pos.x, gap, cellW, 13), cellY, cellW, cellH, white, white, "NF-OFF", "TF-OFF")

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
  draw_button(ctx, data, fctx, cell_x(pos.x, gap, cellW, 14), cellY, cellW, cellH, c14color, c14color, c14line1, c14line2)

  draw_button(ctx, data, fctx, cell_x(pos.x, gap, cellW, 15), cellY, cellW, cellH, white, white, "KEY", "PAD")

  draw_button(ctx, data, fctx, cell_x(pos.x, gap, cellW, 16), cellY, cellW, cellH, white, white, "SSB", "2")


def cell_x(baseX : float; gap : float; cellW : float; idx : int) : float
  return baseX + gap + float(idx) * (cellW + gap)


def draw_button(var ctx : GuiContext&; data : CanvasParams&; fctx : StdGuiFontContext; bx : float; by : float; bw : float; bh : float; borderColor : E3DCOLOR; textColor : E3DCOLOR; line1 : string; line2 : string)
  ctx |> set_color(btnBg)
  ctx |> render_box(bx, by, bx + bw, by + bh)

  let border <- to_array_move(fixed_array<float2>(
    float2(bx, by), float2(bx + bw, by), float2(bx + bw, by + bh), float2(bx, by + bh), float2(bx, by)))
  ctx |> render_line_aa(border, false, data.lineWidth * 0.7, float2(0., 0.), borderColor)

  ctx |> set_color(textColor)

  if line2 |> length() > 0
    let box1 = get_str_bbox(line1, line1 |> length(), fctx)
    let lineH = box1.width.y
    let gap2 = lineH * 0.1
    let totalH = lineH * 2.0 + gap2
    let startY = by + (bh - totalH) * 0.5
    ctx |> goto_xy(bx + (bw - box1.width.x) * 0.5, startY)
    ctx |> draw_str_scaled(1.0, line1, line1 |> length())
    let box2 = get_str_bbox(line2, line2 |> length(), fctx)
    ctx |> goto_xy(bx + (bw - box2.width.x) * 0.5, startY + lineH + gap2)
    ctx |> draw_str_scaled(1.0, line2, line2 |> length())
  else
    let box1 = get_str_bbox(line1, line1 |> length(), fctx)
    let textY = by + (bh - box1.width.y) * 0.5
    ctx |> goto_xy(bx + (bw - box1.width.x) * 0.5, textY)
    ctx |> draw_str_scaled(1.0, line1, line1 |> length())
