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

let transparentColor = E3DCOLOR(Color4(float4(0, 0, 0, 0)))

struct CanvasParams
  color : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  fontId : int = -1
  fontSize : int = 20
  lineWidth : float = 2.

[export]
def setup_data(props : Properties&; var storage : CanvasParams&)
  storage.color = props |> getColor("color", E3DCOLOR(0xFFFFFFFF))
  storage.fontId = props |> getFontId()
  storage.fontSize = props |> getInt("fontSize", 20)
  storage.lineWidth = props |> getFloat("lineWidth", 2.)

def foreach_screen_targets(blk : block<(target : RadarScreenTarget const const#) : void>)
  get_radar_hud_screen_targets() <| $(targets : array<RadarScreenTarget> const#)
    for t in targets
      invoke(blk, t)

[export]
def draw_radar_mark(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed
    return
  let fmw = hero |> as_fmw()
  if fmw == null
    return
  ctx |> set_color(data.color)
  let markSize = 25.
  foreach_screen_targets() <| $(var target)
    var ilsPos = float2(0.)
    if screen_to_ils_pos(target.pos, ilsPos)
      let lt = ilsPos - float2(markSize)
      let rb = ilsPos + float2(markSize)
      if target.isTracked
        ctx |> render_frame(lt.x, lt.y, rb.x, rb.y, data.lineWidth)
        let l1 <- to_array_move([[float2[]
          ilsPos + float2(-markSize * 1.2, -markSize * 1.2);
          ilsPos + float2(-markSize * 1.5, -markSize * 1.5);
        ]])
        let l2 <- to_array_move([[float2[]
          ilsPos + float2(markSize * 1.2, markSize * 1.2);
          ilsPos + float2(markSize * 1.5, markSize * 1.5);
        ]])
        let l3 <- to_array_move([[float2[]
          ilsPos + float2(-markSize * 1.2, markSize * 1.2);
          ilsPos + float2(-markSize * 1.5, markSize * 1.5);
        ]])
        let l4 <- to_array_move([[float2[]
          ilsPos + float2(markSize * 1.2, -markSize * 1.2);
          ilsPos + float2(markSize * 1.5, -markSize * 1.5);
        ]])
        ctx |> render_line_aa(l1, true, data.lineWidth, float2(0.), data.color)
        ctx |> render_line_aa(l2, true, data.lineWidth, float2(0.), data.color)
        ctx |> render_line_aa(l3, true, data.lineWidth, float2(0.), data.color)
        ctx |> render_line_aa(l4, true, data.lineWidth, float2(0.), data.color)
      elif target.isEnemy
        let diamond <- to_array_move([[float2[]
          ilsPos + float2(markSize, 0.);
          ilsPos + float2(0., markSize);
          ilsPos + float2(-markSize, 0.);
          ilsPos + float2(0., -markSize);
        ]])
        ctx |> render_line_aa(diamond, true, data.lineWidth, float2(0.), data.color)
        if target.isDetected
          let diamond2 <- to_array_move([[float2[]
            ilsPos + float2(markSize * 1.3, 0.);
            ilsPos + float2(0., markSize * 1.3);
            ilsPos + float2(-markSize * 1.3, 0.);
            ilsPos + float2(0., -markSize * 1.3);
          ]])
          ctx |> render_line_aa(diamond2, true, data.lineWidth, float2(0.), data.color)
      else
        ctx |> render_ellipse_aa(ilsPos, float2(markSize), data.lineWidth, data.color, transparentColor)
      if target.losSpeed < 3000.
        let targetSpd = sqrt(target.losHorSpeed * target.losHorSpeed + target.losSpeed * target.losSpeed)
        let targetSpdInv = 1. / max(targetSpd, 1.)
        ctx |> draw_line(ilsPos.x - target.losHorSpeed * targetSpdInv * markSize,
          ilsPos.y - target.losSpeed * targetSpdInv * markSize,
          ilsPos.x - target.losHorSpeed * targetSpdInv * min(markSize + targetSpd * 0.5, 3. * markSize),
          ilsPos.y - target.losSpeed * targetSpdInv * min(markSize + targetSpd * 0.5, 3. * markSize), ctx |> hdpx(4.))
      if target.isAttacked
        let l1 <- to_array_move([[float2[]
          ilsPos + float2(markSize, 0.);
          ilsPos + float2(-markSize, 0.);
        ]])
        let l2 <- to_array_move([[float2[]
          ilsPos + float2(0., markSize);
          ilsPos + float2(0., -markSize);
        ]])
        ctx |> render_line_aa(l1, false, data.lineWidth, float2(0.), data.color)
        ctx |> render_line_aa(l2, false, data.lineWidth, float2(0.), data.color)