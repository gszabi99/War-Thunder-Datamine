require darg
require DagorStdGuiRender
require hud
require RadarHud
require HeroManager
require Unit
require math
require DagorMath
require FlightModelWrap
require DagorSystem
require Mission

let transparentColor = E3DCOLOR(Color4(float4(0, 0, 0, 0)))

struct CanvasParams
  color : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  lineWidth : float = 2.
  markSize : float = 25.

[export]
def setup_data(props : Properties&; var storage : CanvasParams&)
  storage.color = props |> getColor("color", E3DCOLOR(0xFFFFFFFF))
  storage.lineWidth = props |> getFloat("lineWidth", 2.)
  storage.markSize = props |> getFloat("markSize", 25.)

def foreach_screen_targets(blk : block<(target : RadarScreenTarget const const#) : void>)
  get_radar_hud_screen_targets() <| $(targets : array<RadarScreenTarget> const#)
    for t in targets
      invoke(blk, t)

def draw_radar_mark(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&; is_ils : bool)
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed
    return
  let fmw = hero |> as_fmw()
  if fmw == null
    return
  ctx |> set_color(data.color)
  let markSize = data.markSize
  foreach_screen_targets() <| $(var target)
    var screenPos = float2(0.)
    let visible = is_ils ? screen_to_ils_pos(target.pos, screenPos) : world_to_hmd_screen(target.worldPos, screenPos)
    if visible
      let limited = (screenPos.x < rdata.pos.x + markSize * 1.5 || screenPos.y < rdata.pos.y + markSize * 1.5 ||
       screenPos.x > rdata.pos.x + rdata.size.x - markSize * 1.5 || screenPos.y > rdata.pos.y + rdata.size.y - markSize * 1.5)
      if target.isTracked
        if limited
          if fract(float(get_total_time()) * 2.) < 0.5
            return
        screenPos.x = clamp(screenPos.x, rdata.pos.x + markSize * 1.5, rdata.pos.x + rdata.size.x - markSize * 1.5)
        screenPos.y = clamp(screenPos.y, rdata.pos.y + markSize * 1.5, rdata.pos.y + rdata.size.y - markSize * 1.5)
        let lt = screenPos - float2(markSize)
        let rb = screenPos + float2(markSize)
        ctx |> render_frame(lt.x, lt.y, rb.x, rb.y, data.lineWidth)
        let l1 <- to_array_move([[float2[]
          screenPos + float2(-markSize * 1.2, -markSize * 1.2);
          screenPos + float2(-markSize * 1.5, -markSize * 1.5);
        ]])
        let l2 <- to_array_move([[float2[]
          screenPos + float2(markSize * 1.2, markSize * 1.2);
          screenPos + float2(markSize * 1.5, markSize * 1.5);
        ]])
        let l3 <- to_array_move([[float2[]
          screenPos + float2(-markSize * 1.2, markSize * 1.2);
          screenPos + float2(-markSize * 1.5, markSize * 1.5);
        ]])
        let l4 <- to_array_move([[float2[]
          screenPos + float2(markSize * 1.2, -markSize * 1.2);
          screenPos + float2(markSize * 1.5, -markSize * 1.5);
        ]])
        ctx |> render_line_aa(l1, true, data.lineWidth, float2(0.), data.color)
        ctx |> render_line_aa(l2, true, data.lineWidth, float2(0.), data.color)
        ctx |> render_line_aa(l3, true, data.lineWidth, float2(0.), data.color)
        ctx |> render_line_aa(l4, true, data.lineWidth, float2(0.), data.color)
      elif target.isEnemy
        if limited && fract(float(get_total_time()) * 2.) < 0.5
          return
        if target.isDetected
          screenPos.x = clamp(screenPos.x, rdata.pos.x + markSize * 1.5, rdata.pos.x + rdata.size.x - markSize * 1.5)
          screenPos.y = clamp(screenPos.y, rdata.pos.y + markSize * 1.5, rdata.pos.y + rdata.size.y - markSize * 1.5)
        let diamond <- to_array_move([[float2[]
          screenPos + float2(markSize, 0.);
          screenPos + float2(0., markSize);
          screenPos + float2(-markSize, 0.);
          screenPos + float2(0., -markSize);
        ]])
        ctx |> render_line_aa(diamond, true, data.lineWidth, float2(0.), data.color)
        if target.isDetected
          let diamond2 <- to_array_move([[float2[]
            screenPos + float2(markSize * 1.3, 0.);
            screenPos + float2(0., markSize * 1.3);
            screenPos + float2(-markSize * 1.3, 0.);
            screenPos + float2(0., -markSize * 1.3);
          ]])
          ctx |> render_line_aa(diamond2, true, data.lineWidth, float2(0.), data.color)
      else
        ctx |> render_ellipse_aa(screenPos, float2(markSize), data.lineWidth, data.color, transparentColor)
      if target.losSpeed < 3000.
        let targetSpd = sqrt(target.losHorSpeed * target.losHorSpeed + target.losSpeed * target.losSpeed)
        let targetSpdInv = 1. / max(targetSpd, 1.)
        ctx |> draw_line(screenPos.x - target.losHorSpeed * targetSpdInv * markSize,
          screenPos.y - target.losSpeed * targetSpdInv * markSize,
          screenPos.x - target.losHorSpeed * targetSpdInv * min(markSize + targetSpd * 0.5, 3. * markSize),
          screenPos.y - target.losSpeed * targetSpdInv * min(markSize + targetSpd * 0.5, 3. * markSize), ctx |> hdpx(4.))
      if target.isAttacked
        let l1 <- to_array_move([[float2[]
          screenPos + float2(markSize, 0.);
          screenPos + float2(-markSize, 0.);
        ]])
        let l2 <- to_array_move([[float2[]
          screenPos + float2(0., markSize);
          screenPos + float2(0., -markSize);
        ]])
        ctx |> render_line_aa(l1, false, data.lineWidth, float2(0.), data.color)
        ctx |> render_line_aa(l2, false, data.lineWidth, float2(0.), data.color)


[export, unused_argument(rstate)]
def draw_hmd_radar_mark(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  draw_radar_mark(ctx, rdata, data, false)

[export, unused_argument(rstate)]
def draw_ils_radar_mark(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  draw_radar_mark(ctx, rdata, data, true)
