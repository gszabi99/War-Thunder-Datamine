require darg
require DagorStdGuiRender
require math
require DagorMath
require SonarHud
require strings
require Mission
require WTInput

let transparentColor = E3DCOLOR(Color4(float4(0, 0, 0, 0)))

struct CanvasParams
  fovColor : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  targetColor : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)

[export]
def setup_data(props : Properties&; var storage : CanvasParams&)
  storage.fovColor = props |> getColor("fovColor", E3DCOLOR(0xFFFFFFFF))
  storage.targetColor = props |> getColor("targetColor", E3DCOLOR(0xFFFFFFFF))

[export, unused_argument(rdata, rstate)]
def draw_sonar_indication(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  if !get_passive_sonar_hud_is_enabled()
    return
  let fovCenter = get_passive_sonar_hud_fov_center()
  let color = float4(Color4(data.fovColor))
  let e3dColor = E3DCOLOR(Color4(color))
  ctx |> render_ellipse_aa(float2(fovCenter.x, fovCenter.y), float2(get_passive_sonar_hud_fov_radius()), ctx |> hdpx(2.), e3dColor, transparentColor)

  let targetE3dColor = E3DCOLOR(Color4(float4(Color4(data.targetColor))))

  targets_on_screen(ctx, targetE3dColor)

  let selectedTargetId = get_passive_sonar_selected_target_of_interest_id()
  get_passive_sonar_hud_screen_targets() <| $(targets : array<PassiveSonarScreenIndicator> const#)
    let targetOfInterestOnScreenWidth = ctx |> hdpx(75.)
    for target in targets
      if target.sourceObjectId == selectedTargetId
        ctx |> render_ellipse_aa(float2(target.screenPos.x, target.screenPos.y), float2(0.5 * targetOfInterestOnScreenWidth), ctx |> hdpx(2.), targetE3dColor, transparentColor)
        break

def foreach_screen_targets(blk : block<(target : PassiveSonarScreenIndicator const const#) : void>)
  get_passive_sonar_hud_screen_targets() <| $(targets : array<PassiveSonarScreenIndicator> const#)
    for t in targets
      invoke(blk, t)

def targets_on_screen(var ctx : GuiContext&; target_color : E3DCOLOR&)
  let targetOnScreenWidth = ctx |> hdpx(50.)
  foreach_screen_targets() <| $(var target)
    ctx |> render_ellipse_aa(float2(target.screenPos.x, target.screenPos.y), float2(0.5 * targetOnScreenWidth), ctx |> hdpx(2.), target_color, transparentColor)
