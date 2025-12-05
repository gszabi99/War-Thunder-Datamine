require ecs
require DagorStdGuiRender
require DagorDriver3D
require DagorMath
require %appGame.infantry.es.render.screen_projection_common


[cpp_event(broadcast)]
struct RenderEventUI
  viewTm : float3x4
  viewItm : float3x4
  
  persp : Driver3dPerspective

[es(tag=render, REQUIRE=hero)]
def bipod_draw_placeable_marker(evt : RenderEventUI;
                                bipod__placeableMarker : EntityId)
  if !!bipod__placeableMarker
    query(bipod__placeableMarker) <| $ [es] (bipod_marker__lineColor : E3DCOLOR;
                                             bipod_marker__lineLength : float = 32f;
                                             bipod_marker__lineWidth : float = 3f;
                                             bipod_marker__lineSpacing : float = 8f;
                                             bipod_marker__placePos : float3)
      var uiViewTm : float3x4 = evt.viewTm
      
      let screenHalfSize = StdGuiRender_screen_size() / 2.0
      let screenPos = from_world_coord_to_screen(uiViewTm * bipod_marker__placePos, evt.persp.wk, evt.persp.hk, screenHalfSize)
      let lineIndent = float2(0, 0)
      let halfLength = bipod_marker__lineLength / 2f
      let quarterLength = halfLength / 2f
      let lineDir = float2(1f, 0f)
      StdGuiRender_render_line_aa(screenPos - lineDir * halfLength, screenPos + lineDir * halfLength, false, bipod_marker__lineWidth, lineIndent, bipod_marker__lineColor)
      let underLinePos = screenPos + float2(0f, bipod_marker__lineSpacing)
      StdGuiRender_render_line_aa(underLinePos - lineDir * quarterLength, underLinePos + lineDir * quarterLength, false, bipod_marker__lineWidth, lineIndent, bipod_marker__lineColor)
