require darg
require math
require DagorMath
require DagorStdGuiRender
require hud
require WTCamera
require FlightControl

struct CanvasParams
  color : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  lineWidth : float = 2.

[export]
def setup_hmd_data(props : Properties&; var storage : CanvasParams&)
  storage.color = getColor(props, "color", E3DCOLOR(0xFFFFFFFF))
  storage.lineWidth = getFloat(props, "lineWidth", 2.)

[export, unused_argument(rstate)]
def draw_hmd(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; params : CanvasParams&)
  set_color(ctx, params.color)
  let lineWidth = hdpx(ctx, params.lineWidth)
  let sightSize = 0.05 * rdata.size.y
  let aimMarkSize = 0.9 * sightSize
  let poiMarkSize = 0.65 * sightSize

  if get_aam_sight_activated()
    let hmdCenterPos = rdata.pos + 0.5 * rdata.size
    draw_aim_mark(ctx, lineWidth, hmdCenterPos, aimMarkSize, params.color)

    if get_aam_hmd_designation()
      draw_aam_tracking_mark(ctx, lineWidth, hmdCenterPos, sightSize, params.color)
  else
    let hmdCenterPos = rdata.pos + 0.5 * rdata.size
    var poiWorldPos = float3(0.0, 0.0, 0.0)
    var poiHmdPos = float2(0.0, 0.0)

    if get_point_of_interest(poiWorldPos)
      let isPoiMarkVisible = world_to_hmd_screen(poiWorldPos, poiHmdPos) && poiHmdPos.y < rdata.size.y * 0.75 && poiHmdPos.x < rdata.size.x * 0.75 && poiHmdPos.y > rdata.size.y * 0.25 && poiHmdPos.x > rdata.size.x * 0.25
      if isPoiMarkVisible
        draw_aim_mark(ctx, lineWidth, hmdCenterPos, aimMarkSize, params.color)
        draw_poi_mark(ctx, lineWidth, poiHmdPos, poiMarkSize, params.color)
      else
        let arrowSize = 0.9 * sightSize
        let camPos = get_camera_orig_pos()
        let camDir = get_camera_orig_dir()
        let poiDir = normalize(poiWorldPos - camPos)
        var angle = atan2_est(poiHmdPos.y - hmdCenterPos.y, poiHmdPos.x - hmdCenterPos.x)
        angle = round(angle / PI * 4.0) * PI / 4.0
        angle += dot(camDir, poiDir) < 0.0 ? PI : 0.0
        draw_arrow(ctx, lineWidth, hmdCenterPos, arrowSize, angle, params.color)
    else
      draw_aim_mark(ctx, lineWidth, hmdCenterPos, aimMarkSize, params.color)
      draw_poi_mark(ctx, lineWidth, hmdCenterPos, poiMarkSize, params.color)

def apply_rotation(vec : float2; sin_angle : float; cos_angle : float) : float2
  return float2(
    vec.x * cos_angle - vec.y * sin_angle,
    vec.x * sin_angle + vec.y * cos_angle
  )

def draw_arrow(var ctx : GuiContext&; lineWidth : float; pos : float2; size : float; angle : float; color : E3DCOLOR)
  set_color(ctx, color)

  var cos_angle : float
  var sin_angle : float
  sincos(angle, sin_angle, cos_angle)

  let arrowheadFix = 0.5 * lineWidth / size
  var lineStart = round(pos + size * apply_rotation(float2(0.25, 0.00), sin_angle, cos_angle))
  var lineEnd = round(pos + size * apply_rotation(float2(1.0 + arrowheadFix, 0.0), sin_angle, cos_angle))
  draw_line(ctx, lineStart, lineEnd, lineWidth)
  lineStart = round(pos + size * apply_rotation(float2(0.75, 0.25), sin_angle, cos_angle))
  lineEnd = round(pos + size * apply_rotation(float2(1.0, 0.0), sin_angle, cos_angle))
  draw_line(ctx, lineStart, lineEnd, lineWidth)
  lineStart = round(pos + size * apply_rotation(float2(0.75, -0.25), sin_angle, cos_angle))
  draw_line(ctx, lineStart, lineEnd, lineWidth)

def draw_aim_mark(var ctx : GuiContext&; lineWidth : float; pos : float2; size : float; color : E3DCOLOR)
  draw_arrow(ctx, lineWidth, pos, size, 0.0, color)
  draw_arrow(ctx, lineWidth, pos, size, 0.5 * PI, color)
  draw_arrow(ctx, lineWidth, pos, size, PI, color)
  draw_arrow(ctx, lineWidth, pos, size, 1.5 * PI, color)

def draw_poi_mark(var ctx : GuiContext&; lineWidth : float; pos : float2; size : float; color : E3DCOLOR)
  set_color(ctx, color)

  for i in 0..4
    let dx = float(2 * (i & 1) - 1)
    let dy = float(2 * ((i >> 1) & 1) - 1)
    let lineStart = round(pos + size * float2(dx, dy))
    var lineEnd = round(pos + size * float2(0.5 * dx, dy))
    draw_line(ctx, lineStart, lineEnd, lineWidth)
    lineEnd = round(pos + size * float2(dx, 0.5 * dy))
    draw_line(ctx, lineStart, lineEnd, lineWidth)

def draw_aam_tracking_mark(var ctx : GuiContext&; lineWidth : float; pos : float2; size : float; color : E3DCOLOR)
  let gapAngle = 0.08 * PI
  let transparentColor = E3DCOLOR(Color4(float4(0, 0, 0, 0)))

  for angle in [0.0, 0.5 * PI, PI, 1.5 * PI]
    render_sector_aa(ctx, pos, float2(size, size), float2(angle + gapAngle, angle + 0.5 * PI - gapAngle), lineWidth, color, transparentColor)
