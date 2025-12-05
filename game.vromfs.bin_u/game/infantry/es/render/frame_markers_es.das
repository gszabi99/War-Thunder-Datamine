require ecs
require math.base
require DagorMath
require DagorStdGuiRender
require DagorDriver3D
require %appGame.infantry.es.render.screen_projection_common

[cpp_event(broadcast)]
struct RenderEventUI
  viewTm : float3x4
  viewItm : float3x4
  
  persp : Driver3dPerspective


def private draw_marker(targetTransform : float3x4;
                        box : BBox3;
                        wk : float;
                        hk : float;
                        minDistance : float;
                        maxDistance : float;
                        uiViewTm : float3x4;
                        drawCb : block<(leftTop : float2; rightBottom : float2; lineIndent : float2; lineSize : float) : void>)
  
  

  var cameraTransform : float3x4
  query() <| $ [es] (camera__active : bool; transform : float3x4)
    if camera__active
      cameraTransform = transform

  let dirToTarget = targetTransform[3] - cameraTransform[3]
  if length(dirToTarget) < minDistance || length(dirToTarget) > maxDistance
    return

  let dotProd = dot(cameraTransform[2], dirToTarget)

  if dotProd < 0.0
    return

  let min3d = box.boxMin
  let max3d = box.boxMax
  let delta = max3d - min3d

  var points3d = fixed_array<float3>(min3d,
                          max3d,
                          float3(min3d.x, min3d.y + delta.y, min3d.z),
                          float3(min3d.x + delta.x, min3d.y + delta.y, min3d.z),
                          float3(min3d.x + delta.x, min3d.y, min3d.z + delta.z),
                          float3(min3d.x, min3d.y + delta.y, min3d.z + delta.z),
                          float3(min3d.x, min3d.y, min3d.z + delta.z),
                          float3(min3d.x + delta.x, min3d.y, min3d.z))

  let screenHalfSize = StdGuiRender_screen_size() / 2.0

  var points2d : float2[8]
  for point2d, point3d in points2d, points3d
    point2d = from_world_coord_to_screen(uiViewTm * point3d, wk, hk, screenHalfSize)

  var mostTop = points2d[0].y
  var mostBottom = points2d[0].y
  var mostLeft = points2d[0].x
  var mostRight = points2d[0].x

  for i in range(1, length(points2d))
    if points2d[i].x < mostLeft
      mostLeft = points2d[i].x
    if points2d[i].x > mostRight
      mostRight = points2d[i].x
    if points2d[i].y < mostTop
      mostTop = points2d[i].y
    if points2d[i].y > mostBottom
      mostBottom = points2d[i].y
  let leftTop = float2(mostLeft, mostTop)
  let rightBottom = float2(mostRight, mostBottom)

  let fullScreenSize = screenHalfSize * 2.0
  if leftTop.x > fullScreenSize.x || rightBottom.x < 0.0 || leftTop.y > fullScreenSize.y || rightBottom.y < 0.0
    return

  if abs(leftTop.x) > 2.0 * fullScreenSize.x || abs(leftTop.y) > 2.0 * fullScreenSize.y || abs(rightBottom.x) > 2.0 * fullScreenSize.x || abs(rightBottom.y) > 2.0 * fullScreenSize.y
    return

  let lineIndent = float2(0.0, 0.0)
  let lineSize = 2.0
  let prevBlendMode = StdGuiRender_get_alpha_blend()

  StdGuiRender_set_alpha_blend(BlendMode.PREMULTIPLIED)
  invoke(drawCb, leftTop, rightBottom, lineIndent, lineSize)
  StdGuiRender_set_alpha_blend(prevBlendMode)

[es(tag=gameClient)] 
def human_context_command_menu_marker_es(evt : RenderEventUI;
                                         human_context_command_marker__canThrowGrenade : bool;
                                         human_context_command_marker__canThrowGrenadeToPos : float3)
  if !human_context_command_marker__canThrowGrenade
    return
  var tr = IDENT_TM
  tr[3] = human_context_command_marker__canThrowGrenadeToPos
  let scale = 0.25
  let pt = float3(scale, scale, scale)
  let box = tr * BBox3(-pt, pt)
  let minDist = 1.0
  let maxDist = 1000.0
  let color = E3DCOLOR(0xFFFFFFFF)
  let color2 = E3DCOLOR(0xFF000000)
  draw_marker(tr,
              box,
              evt.persp.wk,
              evt.persp.hk,
              minDist,
              maxDist,
              evt.viewTm) <| $(leftTop : float2; rightBottom : float2; lineIdent : float2; lineSize : float)
    let cx = (leftTop.x + rightBottom.x) * 0.5
    let cy = (leftTop.y + rightBottom.y) * 0.5
    let d = 0.5
    StdGuiRender_render_line_aa(float2(cx - d, leftTop.y), float2(cx - d, rightBottom.y), false, lineSize, lineIdent, color2)
    StdGuiRender_render_line_aa(float2(cx - d, leftTop.y), float2(cx + d, rightBottom.y), false, lineSize, lineIdent, color2)
    StdGuiRender_render_line_aa(float2(leftTop.x, cy - d), float2(rightBottom.x, cy - d), false, lineSize, lineIdent, color2)
    StdGuiRender_render_line_aa(float2(leftTop.x, cy + d), float2(rightBottom.x, cy + d), false, lineSize, lineIdent, color2)
    StdGuiRender_render_line_aa(float2(cx, leftTop.y), float2(cx, rightBottom.y), false, lineSize, lineIdent, color)
    StdGuiRender_render_line_aa(float2(leftTop.x, cy), float2(rightBottom.x, cy), false, lineSize, lineIdent, color)
