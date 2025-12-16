require darg
require DagorStdGuiRender
require math
require DagorMath
require DagorMathUtils
require DagorSystem
require RadarHud
require strings
require app
require hud
require FlightModelWrap
require HeroManager
require Unit
require WTInput
require WTCamera
require %rGui.utils.radar_common
require %rGui.utils.constants_common
require %rGui.utils.canvas_common
require %rGui.utils.canvas_interactables_common
require %rGui.utils.input_common

let areaBackgroundColor = E3DCOLOR(Color4(float4(0., 0., 0., 0.5)))
let transparentColor = E3DCOLOR(Color4(float4(0, 0, 0, 0)))
let elevMaxScreenRelSize = 0.25
let elevMaxInv = 1.0 / 1.2

let angularGateWidthMultMinPolar = 4.
let angularGateWidthMultMaxPolar = 6.
let angularGateWidthMultMinDistanceRelPolar = 0.06
let angularGateWidthMultMaxDistanceRelPolar = 0.33
let angularGateBeamWidthMin = 0.0348
let distanceGateWidthRelMin = 0.05
let distanceGateWidthMult = 1.
let iffDistRelMult = 0.5
let attackDistRelMult = 1.0
let attackHeightRel = 0.02
let angularGateWidthMultSquare = 4.

let metrToThsFeet = 0.00328084

struct CanvasParams
  screenHeight : float = 1080.0
  color : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  fontId : int = -1
  fontSize : int = 20
  hasTxtBlock : bool = false
  hideBack : bool = false
  overrideMode : int = -1
  enableByMfd : bool = false
  lineWidth : float = 1.
  lineColor : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  modeColor : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  verAngleColor : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  horAngleColor : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  scaleColor : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  targetColor : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  hideBeam : bool = false
  hideLaunchZone : bool = false
  hideScale : bool = false
  hideHorAngle : bool = false
  hideVerAngle : bool = false
  targetFormType : int = 0
  hasAviaHorizont : bool = false
  backgroundColor : E3DCOLOR = E3DCOLOR(0xFF000000)
  beamShape : int = 0
  netRowCnt : int = 0
  netColor : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  hideWeaponIndication : bool = false
  showScanAzimuth : bool = false
  cueHeights : bool = false
  centerRadar : bool = false
  cueTopHeiColor : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  cueLowHeiColor : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  cueUndergroundColor : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  radarModeNameLangId : int = -1
  annotateTargets : bool = false
  planeTargetPicture : Picture?
  helicopterTargetPicture : Picture?
  rocketTargetPicture : Picture?
  handleClicks : bool = false
  isAAComplexMenuLayout : bool = false
  vignetteColor : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)

def hdpx(params : CanvasParams&; value : float)
  // identical to StdGuiRender::GuiContext that was used here
  let targetResolution = 1080.0f
  return floor(value * params.screenHeight * (1.0f / targetResolution) + 0.5f)

def make_transparent_color(col : E3DCOLOR; transparency : float)
  let col4 = float4(Color4(col)) * transparency
  return E3DCOLOR(Color4(col4))

def rad_to_deg(rad : float)
  return rad * 180. / PI

def deg_to_rad(rad : float)
  return rad * PI / 180.

let angularWidthMin = deg_to_rad(5.0)

def calc_angular_gate_width_polar(distance_rel : float; azimuth_half_width)
  if azimuth_half_width > 0.17
    return 2.
  let blend = min((distance_rel - angularGateWidthMultMinDistanceRelPolar) / (angularGateWidthMultMaxDistanceRelPolar - angularGateWidthMultMinDistanceRelPolar), 1.)
  return angularGateWidthMultMinPolar * blend + angularGateWidthMultMaxPolar * (1. - blend)

def get_font_fx_color(color : E3DCOLOR)
  return is_dark_color(color) ? E3DCOLOR(0x78FFFFFF) : E3DCOLOR(0x78000000)

def get_font_fx_factor(color : E3DCOLOR; data : CanvasParams&)
  let fontOutlineFxFactor = max(70., data |> hdpx(90.))
  return int(is_dark_color(color) ? fontOutlineFxFactor * 0.15 : fontOutlineFxFactor)

def has_a_detected_target()
  var result = false
  Radar`foreach_targets() <| $(var target)
    if target.isDetected
      result = true
      return
  return result

[export]
def setup_radar_data(props : Properties&; var storage : CanvasParams&)
  storage.screenHeight = props |> getFloat("screenHeight", 1080.0)
  storage.color = fade_color(props |> getColor("color", E3DCOLOR(0xFFFFFFFF)), 255)
  storage.fontId = props |> getFontId()
  storage.fontSize = props |> getInt("fontSize", 20)
  storage.hasTxtBlock = props |> getBool("hasTxtBlock", false)
  storage.hideBack = props |> getBool("hideBackground", false)
  storage.enableByMfd = props |> getBool("enableByMfd", false)
  storage.overrideMode = props |> getInt("mode", -1)
  storage.lineWidth = props |> getFloat("lineWidth", 1.)
  storage.lineColor = props |> getColor("lineColor", storage.color)
  storage.modeColor = props |> getColor("modeColor", storage.color)
  storage.verAngleColor = props |> getColor("verAngleColor", storage.color)
  storage.horAngleColor = props |> getColor("horAngleColor", storage.color)
  storage.scaleColor = props |> getColor("scaleColor", storage.color)
  storage.targetColor = props |> getColor("targetColor", storage.color)
  storage.hideBeam = props |> getBool("hideBeam", false)
  storage.hideLaunchZone = props |> getBool("hideLaunchZone", false)
  storage.hideScale = props |> getBool("hideScale", false)
  storage.hideHorAngle = props |> getBool("hideHorAngle", false)
  storage.hideVerAngle = props |> getBool("hideVerAngle", false)
  storage.targetFormType = props |> getInt("targetFormType", 0)
  storage.hasAviaHorizont = props |> getBool("hasAviaHorizont", false)
  storage.backgroundColor = props |> getColor("backgroundColor", E3DCOLOR(0xFF000000))
  storage.beamShape = props |> getInt("beamShape", 0)
  storage.netRowCnt = props |> getInt("netRowCnt", 0)
  storage.netColor = props |> getColor("netColor", storage.color)
  storage.hideWeaponIndication = props |> getBool("hideWeaponIndication", false)
  storage.showScanAzimuth = props |> getBool("showScanAzimuth", false)
  storage.cueHeights = props |> getBool("cueHeights", false)
  storage.centerRadar = props |> getBool("centerRadar", false)
  storage.cueTopHeiColor = props |> getColor("cueTopHeiColor", storage.color)
  storage.cueLowHeiColor = props |> getColor("cueLowHeiColor", storage.color)
  storage.cueUndergroundColor = props |> getColor("cueUndergroundColor", storage.color)
  storage.radarModeNameLangId = props |> getInt("radarModeNameLangId", -1)
  storage.annotateTargets = props |> getBool("annotateTargets", false)
  storage.planeTargetPicture = props |> getPicture("planeTargetPicture")
  storage.helicopterTargetPicture = props |> getPicture("helicopterTargetPicture")
  storage.rocketTargetPicture = props |> getPicture("rocketTargetPicture")
  storage.handleClicks = props |> getBool("handleClicks", false)
  storage.isAAComplexMenuLayout = props |> getBool("isAAComplexMenuLayout", false)
  storage.vignetteColor = props |> getColor("vignetteColor", storage.color)

[export]
def handle_click(var elem : Element&; elemPosX, elemPosY : float; elemSizeX, elemSizeY : float; clickPosX, clickPosY : float)
  let clickPos = float2(clickPosX, clickPosY)
  var storage = CanvasParams()
  setup_radar_data(elem.props, storage)

  var mainEll = RadarMain(float2(elemPosX, elemPosY), float2(elemSizeX, elemSizeY), storage)
  var clickVisisitor = ClickVisitor(clickPos)
  mainEll.walkLayout(clickVisisitor)

[export]
def handle_double_click(var elem : Element&; elemPosX, elemPosY : float; elemSizeX, elemSizeY : float; clickPosX, clickPosY : float)
  let clickPos = float2(clickPosX, clickPosY)
  var storage = CanvasParams()
  setup_radar_data(elem.props, storage)

  var mainEll = RadarMain(float2(elemPosX, elemPosY), float2(elemSizeX, elemSizeY), storage)
  var doubleClickVisitor = DoubleClickVisitor(clickPos)
  mainEll.walkLayout(doubleClickVisitor)

[export]
def handle_press(var elem : Element&; elemPosX, elemPosY : float; elemSizeX, elemSizeY : float; startPosX, startPosY : float)
  let startPos = float2(startPosX, startPosY)
  let currPos = get_mouse_pos()
  var storage = CanvasParams()
  setup_radar_data(elem.props, storage)

  var mainEll = RadarMain(float2(elemPosX, elemPosY), float2(elemSizeX, elemSizeY), storage)
  var pressVisitor = PressVisitor(startPos, currPos)
  mainEll.walkLayout(pressVisitor)

[export]
def draw_radar_hud(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  var mainEll = RadarMain(rdata.pos, rdata.size, data)
  var drawVisitor = DrawVisitor(ctx, rdata, rstate)
  mainEll.walkLayout(drawVisitor)


struct RadarInteractableEll : InteractableCanvasEll
  data : CanvasParams const? = null

  def RadarInteractableEll(pos, size : float2; in_params : CanvasParams&)
    InteractableCanvasEll`InteractableCanvasEll(self, pos, size)
    self.data = unsafe(addr(in_params))

struct RadarMain : RadarInteractableEll
  def RadarMain(pos, size : float2; in_params : CanvasParams&)
    RadarInteractableEll`RadarInteractableEll(self, pos, size, in_params)

  def override walkLayout(var visitor : InteractableVisitor&)
    InteractableCanvasEll`walkLayout(self, visitor)
    if self.data.enableByMfd ? !get_radar_hud_mfd_radar_enabled() : !get_radar_hud_visible()
      return
    let radarVisible = get_radar_hud_is_visible() || get_radar_hud_is_visible2()
    if !radarVisible && get_game_params().collapsedIconForRadarTws
      return

    if get_radar_hud_is_b_scope_visible()
      let mode = data.overrideMode >= 0 ? data.overrideMode : int(get_radar_hud_view_mode())

      let watchedHero = get_watched_hero()
      let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
      let circleOverride = azimuthRange > PI * 1.5

      var elemPos = get_radar_hud_is_c_scope_visible() ? self.pos - float2(0., self.size.y * 0.42) : self.pos
      if data.enableByMfd
        elemPos += get_radar_hud_mfd_radar_offset()
      if mode == int(RadarViewMode.B_SCOPE_ROUND)
        if circleOverride
          var bScope = BScopeMain(self.pos, self.size, *self.data)
          bScope.walkLayout(visitor)
        else
          var bScopeHalfEl = BScopeHalfMain(elemPos, self.size, *self.data)
          bScopeHalfEl.walkLayout(visitor)
      if mode == int(RadarViewMode.B_SCOPE_SQUARE)
        if circleOverride
          var bScope = BScopeMain(self.pos, self.size, *self.data)
          bScope.walkLayout(visitor)
        else
          var bScopeSquare = BScopeSquareMain(elemPos, self.size, *self.data)
          bScopeSquare.walkLayout(visitor)

    if get_radar_hud_is_c_scope_visible()
      let elemSize = float2(self.size.x, self.size.y * 0.42)
      var elemPos = self.pos + float2(0., self.size.y * 0.58)
      if data.enableByMfd
        elemPos += get_radar_hud_mfd_radar_offset()
      var cScopeMain = CScopeMain(elemPos, elemSize, *self.data)
      cScopeMain.walkLayout(visitor)

def mfd_radar_background(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&)
  let scale = get_radar_hud_mfd_radar_scale() > 0. ? get_radar_hud_mfd_radar_scale() : 1.
  let size = rdata.size / scale
  let pos = float2(rdata.pos.x - (1. - scale) * 0.5 * size.x, rdata.pos.y - (1. - scale) * 0.5 * size.y)
  ctx |> set_color(data.backgroundColor)
  ctx |> render_box(pos.x, pos.y, pos.x + size.x, pos.y + size.y)

struct BScopeHalfMain : RadarInteractableEll
  def BScopeHalfMain(pos, size : float2; in_params : CanvasParams&)
    RadarInteractableEll`RadarInteractableEll(self, pos, size, in_params)

  def override walkLayout(var visitor : InteractableVisitor&)
    InteractableCanvasEll`walkLayout(self, visitor)

    var bottomOffset = b_scope_half_circle_markers(visitor, *self.data, self.pos, self.size)
    if get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min() > 80.0 * degToRad
      bottomOffset += *self.data |> hdpx(15.0)
    let gridPos = pos - float2(0., bottomOffset)

    var centerEl = BScopeHalfCenter(gridPos, size, *self.data)
    centerEl.walkLayout(visitor)

struct BScopeHalfCenter : RadarInteractableEll
  origin : float2 = float2(0.0)

  def BScopeHalfCenter(grid_pos, size : float2; in_params : CanvasParams&)
    RadarInteractableEll`RadarInteractableEll(self, grid_pos, size, in_params)

  def override walkLayout(var visitor : InteractableVisitor&)
    var targets = PolarTargetsElement(pos, size, data, false)
    self.origin = targets.origin
    targets.walkLayout(visitor)

    let topMarkersPos = self.origin + float2(0.0, -targets.radius.y - *self.data |> hdpx(5.0))
    b_scope_half_top_markers(visitor, *data, topMarkersPos, size)

    InteractableCanvasEll`walkLayout(self, visitor)

  [unused_argument(rdata, rstate)] def override const draw(var ctx : GuiContext &; rdata : ElemRenderData & const; rstate : RenderState & const)
    b_scope_half(ctx, *self.data, self.pos, self.origin, self.size)

struct PolarTargetsElement : InteractableButton
  data : CanvasParams const? = null
  origin : float2 = float2(0.0)

  radius : float2 = float2(0.0)
  azimuthRange : float = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  fullCircle : bool = false

  def PolarTargetsElement(pos, size : float2; params : CanvasParams const?; inFullCircle : bool)
    InteractableButton`InteractableButton(self, pos, size)
    self.data = params
    radius = size * 0.5
    fullCircle = inFullCircle

    if fullCircle
      self.origin = pos + size * 0.5
    else
      let bottomAngle = max(0.0, azimuthRange * 0.5 - PI_2)
      let bottomOffset = sin(bottomAngle) * radius.y
      self.origin = pos + float2(size.x * 0.5, size.y - bottomOffset)

  def override walkLayout(var visitor : InteractableVisitor&)
    InteractableButton`walkLayout(self, visitor)

    if !fullCircle
      var elevationCurret = BScopeHalfElevationCurret(pos, self.origin, size, self.data)
      if azimuthRange >= PI
        elevationCurret.topTextMarkHorAlign = AnchorHorz.Left
      if azimuthRange > PI - 0.035
        elevationCurret.flipMinMax = true
      elevationCurret.walkLayout(visitor)

  [unused_argument(rdata, rstate)] def override const drawDebug(var ctx : GuiContext &; rdata : ElemRenderData & const; rstate : RenderState & const)
    return if !is_interactable_canvas_debug_enabled()
    let anglesExternal = float2(get_radar_hud_azimuth_min() - PI * 0.5, get_radar_hud_azimuth_max() - PI * 0.5)
    ctx |> render_sector_aa(origin, radius, anglesExternal, ctx |> hdpx(2.0), getDebugColor(), E3DCOLOR(0x0))
    let lcoord <- to_array_move(fixed_array<float2>(origin, origin + float2(cos(anglesExternal.x), sin(anglesExternal.x)) * radius))
    ctx |> render_line_aa(lcoord, false, ctx |> hdpx(2.0), float2(0, 0), getDebugColor())
    let rcoord <- to_array_move(fixed_array<float2>(origin, origin + float2(cos(anglesExternal.y), sin(anglesExternal.y)) * radius))
    ctx |> render_line_aa(rcoord, false, ctx |> hdpx(2.0), float2(0, 0), getDebugColor())

  def override const toRelativePos(abs_pos : float2)
    let dir =  abs_pos - origin

    let p = float2(
      cvt(dir.x, -radius.x, radius.x, -1.0, 1.0),
      cvt(dir.y, -radius.y, radius.y, -1.0, 1.0)
    )

    let distRel = sqrt(p.x * p.x + p.y * p.y)
    let azimuthCorrection = fullCircle ? -PI * 0.5 : 0.0
    let azimuth = norm_s_ang(atan2(p.x, -p.y) + azimuthCorrection)
    return float2(distRel, azimuth)

  def override const isPointInside(rel_pos : float2)
    return rel_pos.x <= 1.0 && get_radar_hud_azimuth_min() <= rel_pos.y && rel_pos.y <= get_radar_hud_azimuth_max()

  [unused_argument(start_pos)] def override onPress(start_pos, curr_pos : float2)
    let pressAzimuth = curr_pos.y
    let pressDistRel = curr_pos.x
    let pressDist = pressDistRel * get_radar_hud_distance_max() * 1000.0

    let azimuthCorrection = fullCircle ? -PI * 0.5 : 0.0
    var foundTarget = false
    Radar`foreach_visible_target() <| $(var target)
      var distanceRel = 0.9
      var radialWidthRel = 0.05
      if get_radar_hud_has_distance_scale() && target.distanceRel >= 0.
        distanceRel = target.distanceRel
        radialWidthRel = max(target.distanceWidthRel, 0.05)

      var angle = -PI * 0.5
      var angularWidth = azimuthRange
      if get_radar_hud_has_azimuth_scale()
        angle = get_radar_hud_azimuth_min() + azimuthRange * target.azimuthRel + azimuthCorrection
        angularWidth = max(azimuthRange * target.azimuthWidthRel, angularWidthMin)

      let distCheck = abs(distanceRel - pressDistRel) <= radialWidthRel
      let azCheck = abs(angle - pressAzimuth) <= angularWidth
      if distCheck && azCheck
        radar_switch_to_target(target.sourceObjectId)
        foundTarget = true
        return
    return if foundTarget

    let azimuthClamped = clamp(pressAzimuth, get_radar_hud_azimuth_min(), get_radar_hud_azimuth_max())
    set_radar_cue_pos(azimuthClamped, pressDist)

  [unused_argument(pos)] def override onDoubleClick(pos : float2)
    var fcm = get_flight_control_mode()
    fcm.ctrlMap |> onSensorTargetLock()

  [unused_argument(rdata, rstate)] def override const draw(var ctx : GuiContext &; rdata : ElemRenderData & const; rstate : RenderState & const)
    polar_radar_targets(ctx, *self.data, origin)

  def const polar_radar_targets(var ctx : GuiContext&; data : CanvasParams&; origin : float2)
    var fctx : StdGuiFontContext
    get_font_context(fctx, data.fontId, 0, 0, data.fontSize)

    Radar`foreach_visible_target() <| $(var target)
      var distanceRel = 0.9
      var radialWidthRel = 0.05
      if get_radar_hud_has_distance_scale() && target.distanceRel >= 0.
        distanceRel = target.distanceRel
        radialWidthRel = max(target.distanceWidthRel, 0.05)

      if distanceRel > 1.0 || target.azimuthRel < 0.0 || 1.0 < target.azimuthRel
        return

      var angle = -PI * 0.5
      var angularWidth = azimuthRange
      if get_radar_hud_has_azimuth_scale()
        angle = get_radar_hud_azimuth_min() + azimuthRange * target.azimuthRel - PI * 0.5
        angularWidth = max(azimuthRange * target.azimuthWidthRel, angularWidthMin)

      var sina, cosa : float
      sincos(angle, sina, cosa)
      let targetDirection = float2(cosa, sina)
      let targetRadiusVector = targetDirection * float2(distanceRel * radius.x, distanceRel * radius.y)
      let targetPos = origin + targetRadiusVector

      var color = float4(Color4(is_color_or_white(data.targetColor)))
      let signalRel = target.signalRel < 0.01 ? 0. : cvt(target.signalRel, 0.05, 1., 0.3, 1.)
      color *= (1. - target.ageRel) * signalRel
      let e3dColor = E3DCOLOR(Color4(color))

      let targetCircleRadius = radius * 0.04

      var needToAnnotateTarget = data.annotateTargets
      var targetAnnotationRadialOffset = float2(0.0)

      if target.targetType == int(RadarTargetType.TYPE_TARGET)
        let angleLeft = fullCircle ? (angle - 0.5 * angularWidth) : max(angle - 0.5 * angularWidth, get_radar_hud_azimuth_min() - PI * 0.5)
        let angleRight = fullCircle ? (angle + 0.5 * angularWidth) : min(angle + 0.5 * angularWidth, get_radar_hud_azimuth_max() - PI * 0.5)

        if target.isSelected && get_radar_hud_has_azimuth_scale()
          let replaceTargetWithFullAnnotation = data.annotateTargets && data.isAAComplexMenuLayout && target.iconType != int(RadarTargetIconType.NONE)
          if replaceTargetWithFullAnnotation
            let pictureSize = targetCircleRadius * 1.5

            var hasValidLos = false
            var losSpeedAngle = PI
            var losDirection = float2(0.0)
            if target.losSpeed < 30000.
              losSpeedAngle = atan2(target.losHorSpeed, target.losSpeed)
              let losMult = 0.0002
              let losDelta = float2(
                (cosa * target.losSpeed + sina * target.losHorSpeed),
                (sina * target.losSpeed - cosa * target.losHorSpeed)) * losMult * radius
              let losLengthSq = length_sq(losDelta)
              if losLengthSq > 1e-6
                losDirection = losDelta / sqrt(losLengthSq)
                let losOffset = pictureSize * 0.5 * losDirection
                ctx |> set_color(e3dColor)
                ctx |> draw_line(targetPos + losOffset, targetPos + losOffset + losDelta, data |> hdpx(2. * data.lineWidth))
                hasValidLos = true

            let targetPicture = Radar`getImageForTarget(target, data.planeTargetPicture, data.helicopterTargetPicture, data.rocketTargetPicture)
            let angleNorthCorrection = angle - losSpeedAngle + PI * 0.5
            let picturePos = targetPos - pictureSize * 0.5
            setRotViewTm(ctx, targetPos.x, targetPos.y, angleNorthCorrection, 0.0, false)
            render_picture(ctx, targetPicture, picturePos, pictureSize, data.targetColor)
            resetViewTm(ctx)

            let targetIndex = "{int(target.persistentIndex)}"
            let annotationBox = get_str_bbox(targetIndex, targetIndex |> length(), fctx)

            var radialOffsetSign = 1.0
            if hasValidLos
              let dotProd = dot(losDirection, targetDirection)
              if dotProd < -0.7
                radialOffsetSign = 1.0
              elif dotProd < 0.7
                radialOffsetSign = distanceRel < 0.5 ? 1.0 : -1.0
              else
                radialOffsetSign = -1.0
            let radialOffset = (pictureSize * 0.5 + float2(data |> hdpx(4.0)) + annotationBox.width * 0.5) * radialOffsetSign
            let annotationPos = origin + float2(distanceRel * radius.x + radialOffset.x, distanceRel * radius.y + radialOffset.y) * float2(cosa, sina)

            let offsetX = -annotationBox.width.x * 0.5
            let offsetY = annotationBox.width.y * 0.5

            ctx |> goto_xy(annotationPos.x + offsetX, annotationPos.y + offsetY)
            ctx |> draw_str_scaled(1.0, targetIndex, targetIndex |> length())
            needToAnnotateTarget = false
          else
            ctx |> render_ellipse_aa(targetPos, targetCircleRadius, data |> hdpx(2. * data.lineWidth), e3dColor, transparentColor)
            targetAnnotationRadialOffset = targetCircleRadius
            if target.losSpeed < 30000.
              let losPos = origin + float2((cosa * distanceRel + (cosa * target.losSpeed + sina * target.losHorSpeed) * 0.0002) * radius.x,
              (sina * distanceRel + (sina * target.losSpeed - cosa * target.losHorSpeed) * 0.0002) * radius.y)
              ctx |> set_color(e3dColor)
              ctx |> draw_line(targetPos, losPos, data |> hdpx(2. * data.lineWidth))
        else
          ctx |> render_sector_aa(origin, radius * distanceRel, float2(angleLeft, angleRight), 100. * radialWidthRel, e3dColor, transparentColor)

        if needToAnnotateTarget
          let targetIndex = "{int(target.persistentIndex)}"
          let annotationBox = get_str_bbox(targetIndex, targetIndex |> length(), fctx)
          let radialOffsetSign = distanceRel < 0.5 ? 1.0 : -1.0
          let radialOffset = (float2(data |> hdpx(4.0)) + annotationBox.width * 0.5 + targetAnnotationRadialOffset) * radialOffsetSign
          let annotationPos = origin + float2(distanceRel * radius.x + radialOffset.x, distanceRel * radius.y + radialOffset.y) * float2(cosa, sina)
          let offsetX = -annotationBox.width.x * 0.5
          let offsetY = annotationBox.width.y * 0.5
          ctx |> goto_xy(annotationPos.x + offsetX, annotationPos.y + offsetY)
          ctx |> draw_str_scaled(1.0, targetIndex, targetIndex |> length())

        if target.isDetected
          let azimuthHalfWidth = get_radar_hud_is_visible2() ? get_radar_hud_azimuth_half_width2() : get_radar_hud_azimuth_half_width()
          let angularGateWidthMult = calc_angular_gate_width_polar(distanceRel, azimuthHalfWidth)
          let angularGateWidth = angularGateWidthMult * 2. * max(azimuthHalfWidth, angularGateBeamWidthMin)
          var angleGateLeft = angle - 0.5 * angularGateWidth
          var angleGateRight = angle + 0.5 * angularGateWidth
          if azimuthRange < PI
            angleGateLeft = max(angleGateLeft, get_radar_hud_azimuth_min() - PI * 0.5)
            angleGateRight = min(angleGateRight, get_radar_hud_azimuth_max() - PI * 0.5)
          let distanceGateHalfWidthRel = 0.5 * max(get_radar_hud_distance_gate_width_rel(), distanceGateWidthRelMin) * distanceGateWidthMult
          let radiusInner = distanceRel - distanceGateHalfWidthRel
          let radiusOuter = distanceRel + distanceGateHalfWidthRel
          let lcoord <- to_array_move(fixed_array<float2>(origin + float2(cos(angleGateLeft) * radiusInner * radius.x, sin(angleGateLeft) * radiusInner * radius.y),
            origin + float2(cos(angleGateLeft) * radiusOuter * radius.x, sin(angleGateLeft) * radiusOuter * radius.y)))
          ctx |> render_line_aa(lcoord, false, data |> hdpx(3. * data.lineWidth), float2(0, 0), e3dColor)
          let rcoord <- to_array_move(fixed_array<float2>(origin + float2(cos(angleGateRight) * radiusInner * radius.x, sin(angleGateRight) * radiusInner * radius.y),
            origin + float2(cos(angleGateRight) * radiusOuter * radius.x, sin(angleGateRight) * radiusOuter * radius.y)))
          ctx |> render_line_aa(rcoord, false, data |> hdpx(3. * data.lineWidth), float2(0, 0), e3dColor)

        if !target.isEnemy
          let iffDistReal = get_radar_hud_velocity_search() ? 0.9 : distanceRel + (0.5 + iffDistRelMult) * radialWidthRel
          ctx |> render_sector_aa(origin, radius * iffDistReal, float2(angleLeft, angleRight), data |> hdpx(3. * data.lineWidth), e3dColor, transparentColor)
          //animation targetSelectedAnim ???

        if target.isAttacked
          let attackMarkDistRel = get_radar_hud_velocity_search() ? 0.9 : distanceRel + (0.5 + attackDistRelMult) * radialWidthRel
          let coord <- to_array_move(fixed_array<float2>(origin + radius * attackMarkDistRel * float2(cos(angle), sin(angle)),
          origin + (radius * (attackMarkDistRel + attackHeightRel)) * float2(cos(angle), sin(angle))))
          ctx |> render_line_aa(coord, false, data |> hdpx(3. * data.lineWidth), float2(0, 0), e3dColor)

      elif target.targetType == int(RadarTargetType.TYPE_OWN_WEAPON) && !data.hideWeaponIndication
        if get_radar_hud_has_azimuth_scale()
          ctx |> render_ellipse_aa(targetPos, radius * 0.01, data |> hdpx(2.), e3dColor, transparentColor)

      elif target.targetType == int(RadarTargetType.TYPE_OWN_WEAPON_TARGET) && !data.hideWeaponIndication
        if get_radar_hud_has_azimuth_scale() && !target.isAttacked
          ctx |> render_ellipse_aa(targetPos, radius * 0.06, data |> hdpx(2.), e3dColor, transparentColor)

      if get_radar_hud_has_azimuth_scale() && get_radar_hud_has_distance_scale() && !data.hideWeaponIndication
        Radar`foreach_own_weapon_links() <| $(var ownWeaponLink)
          Radar`foreach_own_weapon_with_target(ownWeaponLink.ownWeaponIndex, ownWeaponLink.ownWeaponTargetIndex) <| $(var ownWeapon; ownWeaponTarget)
            let ownWeaponAngle = get_radar_hud_azimuth_min() + azimuthRange * ownWeapon.azimuthRel - PI * 0.5
            let ownWeaponSina = sin(ownWeaponAngle)
            let ownWeaponCosa = cos(ownWeaponAngle)
            let ownWeaponPos = origin + float2(ownWeaponCosa * ownWeapon.distanceRel * radius.x, ownWeaponSina * ownWeapon.distanceRel * radius.y)

            let ownWeaponTargetAngle = get_radar_hud_azimuth_min() + azimuthRange * ownWeaponTarget.azimuthRel - PI * 0.5
            let ownWeaponTargetSina = sin(ownWeaponTargetAngle)
            let ownWeaponTargetCosa = cos(ownWeaponTargetAngle)
            let ownWeaponTargetPos = origin + float2(ownWeaponTargetCosa * ownWeaponTarget.distanceRel * radius.x, ownWeaponTargetSina * ownWeaponTarget.distanceRel * radius.y)

            ctx |> set_color(e3dColor)
            if ownWeaponLink.lockDistanceToDistance < 1.0
              let direction = float2(ownWeaponTargetPos[0] - ownWeaponPos[0], ownWeaponTargetPos[1] - ownWeaponPos[1])
              let lockPos = float2(ownWeaponPos[0] + direction[0] * ownWeaponLink.lockDistanceToDistance, ownWeaponPos[1] + direction[1] * ownWeaponLink.lockDistanceToDistance)
              ctx |> draw_line(ownWeaponPos, lockPos, data |> hdpx(2.))
              ctx |> render_line_dashed(lockPos, ownWeaponTargetPos, data |> hdpx(10.), data |> hdpx(5.), data |> hdpx(2.), e3dColor)
            else
              ctx |> draw_line(ownWeaponPos, ownWeaponTargetPos, data |> hdpx(2.))

struct BScopeHalfElevationCurret : InteractableButton
  data : CanvasParams const? = null
  origin : float2 = float2(0.0)
  sz : float2 = float2(0.0)

  elevationMin : float = get_radar_hud_elevation_min() * elevMaxInv * elevMaxScreenRelSize + 0.5
  elevationMax : float = get_radar_hud_elevation_max() * elevMaxInv * elevMaxScreenRelSize + 0.5

  sina, cosa : float = 0.0

  markLen : float = 0.06
  markLenShort : float = 0.04
  markLenLong : float = 0.10

  minMarkLeft, minMarkRight, maxMarkLeft, maxMarkRight : float2 = float2(0.0)

  topTextMarkHorAlign : AnchorHorz = AnchorHorz.Right

  flipMinMax : bool = false

  def BScopeHalfElevationCurret(pos, origin, size : float2; params : CanvasParams const?)
    InteractableButton`InteractableButton(self, pos, size)
    self.origin = origin
    self.data = params
    sz = size * 0.5

    sincos(get_radar_hud_azimuth_min(), sina, cosa)

    minMarkLeft = float2(origin.x + elevationMin * sina * sz.x, origin.y - elevationMin * cosa * sz.y)
    minMarkRight = float2(origin.x + (elevationMin * sina - markLen * cosa) * sz.x, origin.y - (elevationMin * cosa + markLen * sina) * sz.y)

    maxMarkLeft = float2(origin.x + elevationMax * sina * sz.x, origin.y - elevationMax * cosa * sz.y)
    maxMarkRight = float2(origin.x + (elevationMax * sina - markLen * cosa) * sz.x, origin.y - (elevationMax * cosa + markLen * sina) * sz.y)

  [unused_argument(rdata, rstate)] def override const drawDebug(var ctx : GuiContext &; rdata : ElemRenderData & const; rstate : RenderState & const)
    let bounds <- to_array_move(fixed_array<float2>(minMarkLeft, maxMarkLeft, maxMarkRight, minMarkRight))
    ctx |> render_line_aa(bounds, true, ctx |> hdpx(2.0), float2(0, 0), getDebugColor())

  def override const toRelativePos(event_pos : float2)
    let minMarkCenter = (minMarkLeft + minMarkRight) * 0.5
    let maxMarkCenter = (maxMarkLeft + maxMarkRight) * 0.5

    let elementDirVector = maxMarkCenter - minMarkCenter
    let toEvent = event_pos - minMarkCenter

    let toEventOverElementDir = dot(elementDirVector, toEvent) / length_sq(elementDirVector)

    let elemDirRotated = normalize(float2(elementDirVector.y, -elementDirVector.x))
    let d = dot(elemDirRotated, toEvent)

    return float2(d, toEventOverElementDir)

  def override const isPointInside(p : float2)
    let projectionCheck = 0.0 <= p.y && p.y <= 1.0
    let dCheck = abs(p.x) <= markLen * sz.x * 0.5
    return projectionCheck && dCheck

  [unused_argument(start_pos)] def override onPress(start_pos, curr_pos : float2)
    let t = flipMinMax ? 1.0 - curr_pos.y : curr_pos.y
    let el = lerp(get_radar_hud_elevation_min(), get_radar_hud_elevation_max(), t)
    set_radar_elevation(el)

  def const elevationToT(elevation : float)
    let t = elevation * elevMaxInv * elevMaxScreenRelSize + 0.5
    return flipMinMax ? 1.0 - t : t

  [unused_argument(rdata, rstate)] def override const draw(var ctx : GuiContext &; rdata : ElemRenderData & const; rstate : RenderState & const)
    var color = float4(Color4(is_color_or_white(data.lineColor)))
    color *= 0.42
    let e3dColor = E3DCOLOR(Color4(color))
    ctx |> set_color(e3dColor)

    if get_radar_hud_is_visible() && !data.hideBeam
      if get_radar_hud_is_emitting()
        b_scope_elevation(ctx, *data, get_radar_hud_elevation())
        foreach_additional_beams() <| $(var additionalBeam)
          b_scope_elevation(ctx, *data, additionalBeam.elevation)

    if get_radar_hud_is_visible2() && !data.hideBeam
      if get_radar_hud_is_emitting2()
        b_scope_elevation(ctx, *data, get_radar_hud_elevation2())

    b_scope_elevation_scan(ctx, *data)
    b_scope_elevation_stab(ctx, *data)
    b_scope_elevation_limits(ctx, *data)

  def const b_scope_elevation_limits(var ctx : GuiContext&; data : CanvasParams&)
    ctx |> draw_line(minMarkLeft.x, minMarkLeft.y, minMarkRight.x, minMarkRight.y, data |> hdpx(4. * data.lineWidth))
    ctx |> draw_line(maxMarkLeft.x, maxMarkLeft.y, maxMarkRight.x, maxMarkRight.y, data |> hdpx(4. * data.lineWidth))
    ctx |> draw_line(origin.x + 0.5 * sina * sz.x, origin.y - 0.5 * cosa * sz.y,
    origin.x + (0.5 * sina - markLenShort * cosa) * sz.x, origin.y - (0.5 * cosa + markLenShort * sina) * sz.y, data |> hdpx(4. * data.lineWidth))

    if get_radar_hud_has_azimuth_scale() && !data.hideVerAngle
      var fctx : StdGuiFontContext
      get_font_context(fctx, data.fontId, 0, 0, data.fontSize)

      let textMin = fmt(":.0f", rad_to_deg(get_radar_hud_elevation_min())) + loc("measureUnits/deg")
      let strBoxMin = get_str_bbox(textMin, textMin |> length(), fctx)
      let azimuthMin = get_radar_hud_azimuth_min()
      let elevationScanMin = elevationToT(get_radar_hud_elevation_min())
      var posX = origin.x + elevationScanMin * sin(azimuthMin) * size.x * 0.5 - strBoxMin.width.x
      let posY = origin.y - (elevationScanMin * cos(azimuthMin) - 0.06) * size.y * 0.5 + strBoxMin.width.y
      if flipMinMax
        posX += strBoxMin.width.x

      ctx |> set_color(data.verAngleColor)
      ctx |> set_draw_str_attr(FontFxType.FFT_GLOW, 0, 0, get_font_fx_color(data.scaleColor), get_font_fx_factor(data.scaleColor, data))
      ctx |> goto_xy(posX, posY)
      ctx |> draw_str_scaled(1.0, textMin, textMin |> length())

      let textMax = fmt(":.0f", rad_to_deg(get_radar_hud_elevation_max())) + loc("measureUnits/deg")
      let strBoxMax = get_str_bbox(textMax, textMax |> length(), fctx)
      let elevationScanMax = elevationToT(get_radar_hud_elevation_max())
      var posX2 = origin.x + elevationScanMax * sin(azimuthMin) * size.x * 0.5 - strBoxMax.width.x
      let posY2 = origin.y - (elevationScanMax * cos(azimuthMin) - 0.06) * size.y * 0.5 + strBoxMax.width.y
      if flipMinMax
        posX2 += strBoxMax.width.x

      ctx |> goto_xy(posX2, posY2)
      ctx |> draw_str_scaled(1.0, textMax, textMax |> length())

  def const b_scope_elevation_scan(var ctx : GuiContext&; data : CanvasParams&)
    if get_radar_hud_scan_elevation_max() > get_radar_hud_scan_elevation_min()
      let elevationScanMin = elevationToT(get_radar_hud_scan_elevation_min())
      let elevationScanMax = elevationToT(get_radar_hud_scan_elevation_max())
      ctx |> draw_line(origin.x + elevationScanMin * sina * sz.x, origin.y - elevationScanMin * cosa * sz.y,
      origin.x + (elevationScanMin * sina - markLen * cosa) * sz.x, origin.y - (elevationScanMin * cosa + markLen * sina) * sz.y, data |> hdpx(4. * data.lineWidth))
      ctx |> draw_line(origin.x + elevationScanMax * sina * sz.x, origin.y - elevationScanMax * cosa * sz.y,
      origin.x + (elevationScanMax * sina - markLen * cosa) * sz.x, origin.y - (elevationScanMax * cosa + markLen * sina) * sz.y, data |> hdpx(4. * data.lineWidth))

  def const b_scope_elevation_stab(var ctx : GuiContext&; data : CanvasParams&)
    return if !get_radar_hud_elevation_stabilize()
    let hero = get_controlled_hero()
    if hero != null && !hero.isDelayed
      let fmw = hero |> as_fmw()
      if fmw != null
        let tangage = deg_to_rad(fmw.tangage)
        let elevationHorizon = elevationToT(-tangage)
        ctx |> draw_line(origin.x + elevationHorizon * sina * sz.x, origin.y - elevationHorizon * cosa * sz.y,
        origin.x + (elevationHorizon * sina - markLenLong * cosa) * sz.x, origin.y - (elevationHorizon * cosa + markLenLong * sina) * sz.y, data |> hdpx(4. * data.lineWidth))

  def const b_scope_elevation(var ctx : GuiContext&; data : CanvasParams&; elev_rel : float)
    var elevation = elevationMin * (1.0 - elev_rel) + elevationMax * elev_rel
    if flipMinMax
      elevation = 1.0 - elevation
    ctx |> draw_line(origin.x + elevation * sina * sz.x, origin.y - elevation * cosa * sz.y,
    origin.x + (elevation * sina - markLenShort * cosa) * sz.x, origin.y - (elevation * cosa + markLenShort * sina) * sz.y, data |> hdpx(4. * data.lineWidth))

def b_scope_half(var ctx : GuiContext&; data : CanvasParams&; grid_pos, origin, size : float2)
  if !data.hideBack
    b_scope_half_background(ctx, data, origin, size)

  let half_width = get_radar_hud_target_azimuth_width()
  if half_width > 0. && !data.hideBack
    b_scope_sector(ctx, data, origin, size, half_width, 0.5)

  let reflectionPos = grid_pos + float2(0., size.y * 0.5)
  render_ground_reflection(ctx, size, reflectionPos, is_color_or_white(data.lineColor), int2(16, 8), false)
  if get_radar_hud_is_visible() && !data.hideBeam
    if get_radar_hud_is_emitting()
      let dist = get_radar_hud_distance()
      let halfVal = get_radar_hud_azimuth_half_width()
      let isSectorView = dist == 1. && halfVal > 0.
      b_scope_azimuth(ctx, data, origin, size, isSectorView, get_radar_hud_azimuth(), halfVal, dist, 1.2 * data.lineWidth)
      foreach_additional_beams() <| $(var additionalBeam)
        b_scope_azimuth(ctx, data, origin, size, isSectorView, additionalBeam.azimuth, halfVal, dist, 1.2 * data.lineWidth)

  if get_radar_hud_is_visible2() && !data.hideBeam
    if get_radar_hud_is_emitting2()
      let dist = get_radar_hud_distance2()
      let halfVal = get_radar_hud_azimuth_half_width2()
      let isSectorView = dist == 1. && halfVal > 0.
      b_scope_azimuth(ctx, data, origin, size, isSectorView, get_radar_hud_azimuth2(), halfVal, dist, 1.2 * data.lineWidth)

  if !data.hideLaunchZone
    b_scope_half_launch_range(ctx, data, origin, size)
  b_scope_half_cue(ctx, data, origin, size)

def b_scope_half_background(var ctx : GuiContext&; data : CanvasParams&; origin : float2; size : float2)
  let radius = size * 0.5
  let anglesExternal = float2(get_radar_hud_azimuth_min() - PI * 0.5, get_radar_hud_azimuth_max() - PI * 0.5)
  let anglesInternal = float2(get_radar_hud_scan_azimuth_min() - PI * 0.5, get_radar_hud_scan_azimuth_max() - PI * 0.5)

  let color = is_color_or_white(data.lineColor)

  ctx |> render_sector_aa(origin, radius, anglesExternal, data.lineWidth, data.lineColor, areaBackgroundColor)
  let lcoord <- to_array_move(fixed_array<float2>(origin, origin + float2(cos(anglesExternal.x), sin(anglesExternal.x)) * radius))
  ctx |> render_line_aa(lcoord, false, data.lineWidth, float2(0, 0), data.lineColor)
  let rcoord <- to_array_move(fixed_array<float2>(origin, origin + float2(cos(anglesExternal.y), sin(anglesExternal.y)) * radius))
  ctx |> render_line_aa(rcoord, false, data.lineWidth, float2(0, 0), data.lineColor)

  let anglesInternalGrid = anglesInternal.y > anglesInternal.x ? anglesInternal : anglesExternal
  let distMinRel = max(0., get_radar_hud_distance_min() / max(get_radar_hud_distance_max(), 1.0))
  if get_radar_hud_has_distance_scale()
    let distanceMinR = 50.0 * distMinRel
    var dist = 12.5
    while dist < 37.5 + 1.0
      if dist > distanceMinR
        ctx |> render_sector_aa(origin, dist * 0.01 * size, anglesInternalGrid, data.lineWidth, color, E3DCOLOR(0u))
      dist += 12.5
    ctx |> render_sector_aa(origin, size * distMinRel * 0.5, anglesInternalGrid, data.lineWidth, color, E3DCOLOR(0u))

  let angleStep = PI * 15.0 / 180.0
  for i in range(int(anglesInternalGrid.x / angleStep), int(anglesInternalGrid.y / angleStep))
    let angle = float(i) * angleStep
    let coord <- to_array_move(fixed_array<float2>(origin + float2(cos(angle) * size.x, sin(angle) * size.y) * 0.5 * distMinRel,
     origin + float2(cos(angle) * size.x, sin(angle) * size.y) * 0.5))
    ctx |> render_line_aa(coord, false, 1.2 * data.lineWidth, float2(0, 0), color)

  let rscoord <- to_array_move(fixed_array<float2>(origin, origin + float2(cos(anglesInternal.y) * size.x, sin(anglesInternal.y) * size.y) * 0.5))
  ctx |> render_line_aa(rscoord, false, 2.4 * data.lineWidth, float2(0, 0), color)
  let lscoord <- to_array_move(fixed_array<float2>(origin, origin + float2(cos(anglesInternal.x) * size.x, sin(anglesInternal.x) * size.y) * 0.5))
  ctx |> render_line_aa(lscoord, false, 2.4 * data.lineWidth, float2(0, 0), color)

def b_scope_sector(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2; half_width : float; value : float)
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  let angle = get_radar_hud_azimuth_min() + azimuthRange * value - PI * 0.5

  var color = float4(Color4(data.color))//isColorOrWhite(color) ??
  color *= 0.2
  ctx |> render_sector_aa(pos, size * 0.5 * get_radar_hud_target_distance(), float2(angle - half_width, angle + half_width), 1.2,
   E3DCOLOR(Color4(color)), E3DCOLOR(Color4(color)))

def b_scope_azimuth(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2; is_sector_view : bool;
                    value : float; half_width : float; dist : float; line_width : float)
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  let angle = get_radar_hud_azimuth_min() + azimuthRange * value - PI * 0.5

  if is_sector_view
    var color = float4(Color4(is_color_or_white(data.lineColor)))
    color *= 0.4
    let radius = float2(size.x * 0.5, size.y * 0.5)
    ctx |> render_sector_aa(pos, radius, float2(angle - half_width, angle + half_width), 1., E3DCOLOR(Color4(color)), E3DCOLOR(Color4(color)))
  else
    let len = min(dist >= 0. ? dist : 1., 1.)
    let coord <- to_array_move(fixed_array<float2>(pos, pos + float2(cos(angle), sin(angle)) * size.x * 0.5 * len))
    let color = is_color_or_white(data.targetColor)
    if dist >= 0.
      ctx |> render_line_dashed(pos, coord[1], data |> hdpx(10.), data |> hdpx(5.), data |> hdpx(line_width), color)
    else
      ctx |> render_line_aa(coord, false, data |> hdpx(line_width), float2(0, 0), color)

def b_scope_half_top_markers(var visitor : InteractableVisitor&; data : CanvasParams&; center : float2; size : float2)
  if !get_radar_hud_is_visible() && !get_radar_hud_is_visible2()
    return

  let modeName = Radar`getModeNameLoc(data.radarModeNameLangId)

  var style = TextButtonStyle()
  style.fontId = data.fontId
  style.fontSize = data.fontSize
  style.color = data.modeColor
  style.glowColor = get_font_fx_color(data.modeColor)
  style.glowFxFactor = get_font_fx_factor(data.modeColor, data)
  style.anchorHorz = AnchorHorz.Right
  style.anchorVert = AnchorVert.Bottom

  let modePos = float2(center.x, center.y - 5.)
  var modeEl = TextButton(modePos, modeName, style)
  modeEl.onClickCallback <- @ <| ()
    Radar`changeMode()
  modeEl.walkLayout(visitor)

  let strBox = modeEl.textBox

  style.anchorHorz = AnchorHorz.Left
  let name2Id = get_radar_hud_mode_name2_id()
  let default2Str = get_radar_hud_is_visible2() ? ("hud/radarEmitting") : ""
  let modeName2 = loc(name2Id >= 0 && name2Id < radarModeNames |> length() ? radarModeNames[name2Id] : default2Str)
  let mode2Pos = float2(center.x + 5., center.y - 5.)
  var mode2El = TextButton(mode2Pos, modeName2, style)
  mode2El.walkLayout(visitor)

  if get_radar_hud_noise_signal_visible() && get_radar_hud_is_visible() && get_radar_hud_noise_signal() > 0.5
    let noisePos = center - float2(strBox.width.x + size.x * 0.06, size.y * 0.07)
    let noiseSize = float2(size.x * 0.06, size.y * 0.07)
    var noiseEl = NoiseSignalElement(noisePos, noiseSize, data, get_radar_hud_noise_signal())
    noiseEl.walkLayout(visitor)
  if get_radar_hud_noise_signal_visible() && get_radar_hud_is_visible2() && get_radar_hud_noise_signal2() > 0.5
    let noisePos = center
    let noiseSize = float2(size.x * 0.06, size.y * 0.07)
    var noiseEl = NoiseSignalElement(noisePos, noiseSize, data, get_radar_hud_noise_signal2())
    noiseEl.walkLayout(visitor)

def for_own_weapon_with_target(own_weapon_index : int; own_weapon_target_index : int; blk : block<(ownWeapon : RadarTarget const const#; ownWeaponTarget : RadarTarget const const#) : void>)
  get_radar_hud_targets() <| $(targets : array<RadarTarget> const#)
    if (own_weapon_index < targets |> length() && own_weapon_target_index < targets |> length())
      let weapon = targets[own_weapon_index]
      let target = targets[own_weapon_target_index]
      if weapon.isVisible && target.isVisible
        invoke(blk, targets[own_weapon_index], targets[own_weapon_target_index])

def foreach_own_weapon_links(blk : block<(ownWeaponLink : OwnWeaponLink const const#) : void>)
  get_radar_hud_own_weapon_links() <| $(ownWeaponLinks : array<OwnWeaponLink> const#)
    for l in ownWeaponLinks
      invoke(blk, l)

def b_scope_half_circle_markers(var visitor : InteractableVisitor&; data : CanvasParams&; pos : float2; size : float2)
  if !get_radar_hud_is_visible() && !get_radar_hud_is_visible2()
    return 0.

  var offset = 0.
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  let lt = pos
  let rb = pos + size

  var style = TextButtonStyle()
  style.fontId = data.fontId
  style.fontSize = data.fontSize

  if get_radar_hud_has_azimuth_scale() && get_radar_hud_scan_azimuth_max() > get_radar_hud_scan_azimuth_min() && !data.hideHorAngle
    let azText = fmt(":.0f", floor(rad_to_deg(get_radar_hud_scan_azimuth_max() - get_radar_hud_scan_azimuth_min()) + 0.5))
    let elText = fmt(":.0f", floor(rad_to_deg(get_radar_hud_scan_elevation_max() - get_radar_hud_scan_elevation_min()) + 0.5))
    let deg = loc("measureUnits/deg")
    let text = "{azText}{deg}x{elText}{deg}" + (get_radar_hud_scan_patterns_max() > 1 ? "*" : " ")

    style.color = data.horAngleColor
    style.glowColor =  get_font_fx_color(data.horAngleColor)
    style.glowFxFactor = get_font_fx_factor(data.horAngleColor, data)
    style.anchorHorz = AnchorHorz.Center

    let p = float2((rb.x + lt.x) * 0.5, rb.y)
    var scanPatternEl = TextButton(p, text, style)
    scanPatternEl.onClickCallback <- @ <| ()
      Radar`changeScanPattern()
    scanPatternEl.walkLayout(visitor)
    let strBox = scanPatternEl.textBox

    offset = rb.y * 0.02 + strBox.width.y
  else
    offset = rb.y * 0.02 + fctx.get_font_cell_size().y

  if get_radar_hud_has_distance_scale() && !data.hideScale
    let valText = (get_radar_hud_velocity_search() ? get_measure_units_text(MeasureUnitsTypes.MEASURE_UNIT_SPEED, get_radar_hud_distance_max(), true, 1.) :
     get_measure_units_text(MeasureUnitsTypes.MEASURE_UNIT_DIST, get_radar_hud_distance_max() * 1000., true, 1.))
    let text = valText + (get_radar_hud_distance_scale_max() > 1 ? "*" : " ")

    style.color = data.scaleColor
    style.glowColor =  get_font_fx_color(data.scaleColor)
    style.glowFxFactor = get_font_fx_factor(data.scaleColor, data)
    style.anchorHorz = AnchorHorz.Right
    style.anchorVert = AnchorVert.Top

    let p = float2(rb.x, rb.y - offset)
    var scanRangeEl = TextButton(p, text, style)
    scanRangeEl.onClickCallback <- @ <| ()
      Radar`changeRange()
    scanRangeEl.walkLayout(visitor)

  let iffFilterSize = float2(data |> hdpx(15.0), data |> hdpx(20.0))
  let iffOffset = float2(data |> hdpx(3.0), -data |> hdpx(3.0))
  let iffPos = float2(lt.x, rb.y - iffFilterSize.y) + iffOffset
  var iffFilter = IFFFilterButton(iffPos, iffFilterSize, data)
  iffFilter.walkLayout(visitor)

  return offset

def b_scope_half_launch_range(var ctx : GuiContext&; data : CanvasParams&; origin : float2; size : float2)
  if !get_radar_hud_aam_launch_zone_visible() || !get_radar_hud_has_distance_scale()
    return

  let angles = float2(get_radar_hud_azimuth_min() - PI * 0.5, get_radar_hud_azimuth_max() - PI * 0.5)
  var color = float4(Color4(is_color_or_white(data.lineColor)))
  color *= 0.42
  let e3dColor = E3DCOLOR(Color4(color))
  let distMin = get_radar_hud_aam_launch_zone_dist_min()
  if distMin <= 1.
    ctx |> render_sector_aa(origin, size * 0.5 * distMin, angles, data |> hdpx(4. * data.lineWidth), e3dColor, transparentColor)
  let distMax = get_radar_hud_aam_launch_zone_dist_max()
  if distMax <= 1.
    ctx |> render_sector_aa(origin, size * 0.5 * distMax, angles, data |> hdpx(4. * data.lineWidth), e3dColor, transparentColor)
  let dgftMax = get_radar_hud_aam_launch_zone_dist_dgft_max()
  if dgftMax > 0. && dgftMax <= 1.
    ctx |> render_sector_aa(origin, size * 0.5 * dgftMax, angles, data |> hdpx(4. * data.lineWidth), e3dColor, transparentColor)

def noise_signal(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2; val : float)
  let quadSize = float2(size.x, size.y * 0.16)
  for i in range(0, 4)
    let p = pos + float2(0., float(i) * size.y * 0.25)
    let rb = p + quadSize
    let tc = float2(0., 0.)
    var color = float4(Color4(data.color))//isColorOrWhite(color) ??
    color *= val > float(3 - i) ? 1. : 0.21
    let e3dColor = E3DCOLOR(Color4(color))
    ctx |> set_color(e3dColor)
    ctx |> render_rect(p.x, p.y, rb.x, rb.y, tc, tc, tc)
  let p = pos - float2(size.x * 1.2, -size.y * 0.75)
  let rb = p + float2(size.x, size.y * 0.32)
  let tc = float2(0., 0.)
  ctx |> render_rect(p.x, p.y, rb.x, rb.y, tc, tc, tc)

  let aSz = float2(size.x * 0.25, size.y * 0.75)
  let aPl1 = pos - float2(size.x * 0.55, 0.)
  let arrowLines1 <- to_array_move(fixed_array(
    aPl1 + float2(0.5 * aSz.x, 0.),
    aPl1 + float2(0., 0.5 * aSz.y),
    aPl1 + float2(0.35 * aSz.x, 0.5 * aSz.y),
    aPl1 + float2(0.35 * aSz.x, aSz.y),
    aPl1 + float2(0.65 * aSz.x, aSz.y),
    aPl1 + float2(0.65 * aSz.x, 0.5 * aSz.y),
    aPl1 + float2(aSz.x, 0.5 * aSz.y)))
  ctx |> render_poly(arrowLines1, data.color)
  ctx |> render_line_aa(arrowLines1, true, data |> hdpx(1.2), float2(0., 0.), data.color)

  let aPl2 = pos - float2(size.x * 1.05, 0.)
  let arrowLines2 <- to_array_move(fixed_array(
    aPl2 + float2(0.5 * aSz.x, aSz.y),
    aPl2 + float2(0., 0.5 * aSz.y),
    aPl2 + float2(0.35 * aSz.x, 0.5 * aSz.y),
    aPl2 + float2(0.35 * aSz.x, 0.),
    aPl2 + float2(0.65 * aSz.x, 0.),
    aPl2 + float2(0.65 * aSz.x, 0.5 * aSz.y),
    aPl2 + float2(aSz.x, 0.5 * aSz.y)))
  ctx |> render_poly(arrowLines2, data.color)
  ctx |> render_line_aa(arrowLines2, true, data |> hdpx(1.2), float2(0., 0.), data.color)

def b_scope_half_cue(var ctx : GuiContext&; data : CanvasParams&; origin : float2; size : float2)
  if !get_radar_hud_cue_visible()
    return

  return if has_a_detected_target()

  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  let cueAzimuth = get_radar_hud_cue_azimuth() * max(get_radar_hud_target_azimuth_width() - get_radar_hud_cue_azimuth_half_width_rel() * azimuthRange, 0.)
  let halfDistGateWidthRel = 0.5 * get_radar_hud_cue_dist_width_rel()
  let distRel = halfDistGateWidthRel + get_radar_hud_cue_distance() * get_radar_hud_target_distance() * (1. - 2. * halfDistGateWidthRel)
  let cueAzimuthMin = cueAzimuth - get_radar_hud_cue_azimuth_half_width_rel() * azimuthRange
  let cueAzimuthMax = cueAzimuth + get_radar_hud_cue_azimuth_half_width_rel() * azimuthRange
  let radiusMin = (distRel - halfDistGateWidthRel) * 0.5
  let radiusMax = (distRel + halfDistGateWidthRel) * 0.5

  let color = is_color_or_white(data.lineColor) //remove color_is_white if use is_color on scope_sector
  let lcoord <- to_array_move(fixed_array<float2>(origin + float2(radiusMin * sin(cueAzimuthMin) * size.x, -radiusMin * cos(cueAzimuthMin) * size.y),
   origin + float2(radiusMax * sin(cueAzimuthMin) * size.x, -radiusMax * cos(cueAzimuthMin) * size.y)))
  ctx |> render_line_aa(lcoord, false, 2. * data.lineWidth, float2(0, 0), color)
  let rcoord <- to_array_move(fixed_array<float2>(origin + float2(radiusMin * sin(cueAzimuthMax) * size.x, -radiusMin * cos(cueAzimuthMax) * size.y),
   origin + float2(radiusMax * sin(cueAzimuthMax) * size.x, -radiusMax * cos(cueAzimuthMax) * size.y)))
  ctx |> render_line_aa(rcoord, false, 2. * data.lineWidth, float2(0, 0), color)


struct NoiseSignalElement : RadarInteractableEll
  noiseValue : float = 0.0

  def NoiseSignalElement(pos, size : float2; in_params : CanvasParams&; noise_value : float)
    RadarInteractableEll`RadarInteractableEll(self, pos, size, in_params)
    noiseValue = noise_value

  [unused_argument(rdata, rstate)] def override const draw(var ctx : GuiContext &; rdata : ElemRenderData & const; rstate : RenderState & const)
    noise_signal(ctx, *data, pos, size, noiseValue)

struct BScopeSquareMain : RadarInteractableEll
  def BScopeSquareMain(pos, size : float2; in_params : CanvasParams&)
    RadarInteractableEll`RadarInteractableEll(self, pos, size, in_params)

  def override walkLayout(var visitor : InteractableVisitor&)
    let frameSize = get_radar_hud_has_azimuth_scale() ? self.size : float2(self.size.x * 0.2, self.size.y)
    let offsets = b_scope_square_labels(*self.data, self.pos, frameSize, visitor)

    let sz = frameSize - float2(offsets.x, offsets.y + offsets.z)
    let elemPos = data.centerRadar ? (self.pos + frameSize * 0.5 - sz * 0.5) : (self.pos + float2(offsets.x, offsets.y))

    var centerEl = BScopeSquareCenter(elemPos, sz, *self.data)
    centerEl.walkLayout(visitor)

    let iffFilterSize = float2(*self.data |> hdpx(15.0), *self.data |> hdpx(20.0))
    let offset = -float2(*self.data |> hdpx(3.0))
    var iffFilter = IFFFilterButton(elemPos + float2(0.0, sz.y) + offset - iffFilterSize, iffFilterSize, *self.data)
    iffFilter.walkLayout(visitor)

    InteractableCanvasEll`walkLayout(self, visitor)


struct BScopeSquareCenter : RadarInteractableEll
  def BScopeSquareCenter(pos, size : float2; in_params : CanvasParams&)
    RadarInteractableEll`RadarInteractableEll(self, pos, size, in_params)

  def override walkLayout(var visitor : InteractableVisitor&)
    InteractableCanvasEll`walkLayout(self, visitor)

    let elevationCurretWidth = self.size.x * 0.05
    let elevationCurretSize = float2(elevationCurretWidth, self.size.y)
    var elevationCurret = BScopeSquareElevationCurret(self.pos - float2(elevationCurretWidth, 0.0), elevationCurretSize, *self.data)
    elevationCurret.walkLayout(visitor)

    var targetsEl = BScopeSquareTargets(self.pos, self.size, *self.data)
    targetsEl.walkLayout(visitor)

  [unused_argument(rdata, rstate)] def override const draw(var ctx : GuiContext &; rdata : ElemRenderData & const; rstate : RenderState & const)
    b_scope_square(ctx, self.pos, self.size, *self.data)
    draw_additional_net(ctx, *self.data, rdata.pos, rdata.size)


struct BScopeSquareTargets : InteractableButton
  data : CanvasParams const? = null

  def BScopeSquareTargets(pos, size : float2; in_params : CanvasParams&)
    InteractableButton`InteractableButton(self, pos, size)
    data = unsafe(addr(in_params))

  [unused_argument(start_pos_rel)] def override onPress(start_pos_rel, curr_pos_rel : float2)
    let hasDistanceScale = get_radar_hud_has_distance_scale()
    let hasAzimuthScale = get_radar_hud_has_azimuth_scale()

    var foundTarget = false
    Radar`foreach_visible_target() <| $(var target)
      var angleRel = 0.5
      var angularWidthRel = 1.
      if hasAzimuthScale
        angleRel = target.azimuthRel
        angularWidthRel = target.azimuthWidthRel

      var distanceRel = 0.9
      var radialWidthRel = 0.02
      if hasDistanceScale && target.distanceRel >= 0.
        distanceRel = target.distanceRel
        radialWidthRel = max(radialWidthRel, target.distanceWidthRel)

      let targetSize = float2(angularWidthRel, radialWidthRel) * 0.5
      let mouseToTarget = float2(angleRel, 1.0 - distanceRel) - curr_pos_rel
      let isInXBounds = abs(mouseToTarget.x) <= targetSize.x
      let isInYBounds = abs(mouseToTarget.y) <= targetSize.y
      if isInXBounds && isInYBounds
        radar_switch_to_target(target.sourceObjectId)
        foundTarget = true
        return
    return if foundTarget

    let dist = (1.0 - curr_pos_rel.y) * get_radar_hud_distance_max() * 1000.0
    let azimuth = cvt(curr_pos_rel.x, 0.0, 1.0, get_radar_hud_azimuth_min(), get_radar_hud_azimuth_max())
    set_radar_cue_pos(azimuth, dist)

  [unused_argument(pos)] def override onDoubleClick(pos : float2)
    var fcm = get_flight_control_mode()
    fcm.ctrlMap |> onSensorTargetLock()

  [unused_argument(rdata, rstate)] def override const draw(var ctx : GuiContext &; rdata : ElemRenderData & const; rstate : RenderState & const)
    square_radar_targets(ctx, *self.data)

  def const convertDistToY(dist_rel : float)
    return pos.y + (1. - dist_rel) * size.y

  def const convertAngleToX(angle_rel : float)
    return pos.x + angle_rel * size.x

  def const square_radar_targets(var ctx : GuiContext&; data : CanvasParams&)
    ctx |> set_viewport(pos.x, pos.y, pos.x + size.x, pos.y + size.y)

    let hasAzimuthScale = get_radar_hud_has_azimuth_scale()
    let hasDistanceScale = get_radar_hud_has_distance_scale()
    let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
    Radar`foreach_visible_target() <| $(var target)
      var angleRel = 0.5
      var angularWidthRel = 1.
      if hasAzimuthScale
        angleRel = target.azimuthRel
        angularWidthRel = target.azimuthWidthRel
      angleRel = clamp(angleRel, 0.0, 1.0)
      let angleLeft = max(0., angleRel - 0.5 * angularWidthRel)
      let angleRight = min(angleRel + 0.5 * angularWidthRel, 1.)

      var distanceRel = 0.9
      var radialWidthRel = 0.02
      if hasDistanceScale && target.distanceRel >= 0.
        distanceRel = target.distanceRel
        radialWidthRel = max(radialWidthRel, target.distanceWidthRel)

      let p = float2(convertAngleToX(angleRel), convertDistToY(distanceRel))

      var color = float4(Color4(is_color_or_white(data.targetColor)))
      let signalRel = target.signalRel < 0.01 ? 0. : cvt(target.signalRel, 0.05, 1., 0.3, 1.)
      color *= (1. - target.ageRel) * signalRel
      let e3dColor = E3DCOLOR(Color4(color))

      if target.targetType == int(RadarTargetType.TYPE_TARGET)
        let azimuthHalfWidth = get_radar_hud_is_visible2() ? get_radar_hud_azimuth_half_width2() : get_radar_hud_azimuth_half_width()
        let angularGateHalfWidthRel = angularGateWidthMultSquare * azimuthHalfWidth / azimuthRange
        let angleGateLeftRel = angleRel - angularGateHalfWidthRel
        let angleGateRightRel = angleRel + angularGateHalfWidthRel

        let distanceGateHalfWidthRel = 0.5 * max(get_radar_hud_distance_gate_width_rel(), distanceGateWidthRelMin) * distanceGateWidthMult
        let distanceInner = distanceRel - distanceGateHalfWidthRel
        let distanceOuter = distanceRel + distanceGateHalfWidthRel
        if target.isDetected
          let lcoord <- to_array_move(fixed_array<float2>(float2(convertAngleToX(angleGateLeftRel), pos.y + (1. - distanceInner) * size.y),
          float2(convertAngleToX(angleGateLeftRel), pos.y + (1. - distanceOuter) * size.y)))
          ctx |> render_line_aa(lcoord, false, data |> hdpx(3. * data.lineWidth), float2(0, 0), e3dColor)
          let rcoord <- to_array_move(fixed_array<float2>(float2(convertAngleToX(angleGateRightRel), pos.y + (1. - distanceInner) * size.y),
          float2(convertAngleToX(angleGateRightRel), pos.y + (1. - distanceOuter) * size.y)))
          ctx |> render_line_aa(rcoord, false, data |> hdpx(3. * data.lineWidth), float2(0, 0), e3dColor)
        if !target.isEnemy
          let iffMarkDistRel = get_radar_hud_velocity_search() ? 0.9 : distanceRel + (0.5 + iffDistRelMult) * radialWidthRel
          let coord <- to_array_move(fixed_array<float2>(float2(convertAngleToX(angleLeft), pos.y + (1. - iffMarkDistRel) * size.y),
          float2(convertAngleToX(angleRight), pos.y + (1. - iffMarkDistRel) * size.y)))
          ctx |> render_line_aa(coord, false, data |> hdpx(3. * data.lineWidth), float2(0, 0), e3dColor)
        if target.isAttacked
          let attackMarkDistRel = get_radar_hud_velocity_search() ? 0.9 : distanceRel + (0.5 + attackDistRelMult) * radialWidthRel
          let coord <- to_array_move(fixed_array<float2>(float2(convertAngleToX(angleRel), pos.y + (1. - attackMarkDistRel) * size.y),
          float2(convertAngleToX(angleRel), pos.y + (1. - attackMarkDistRel + attackHeightRel) * size.y)))
          ctx |> render_line_aa(coord, false, data |> hdpx(3. * data.lineWidth), float2(0, 0), e3dColor)
        //animation

        if target.isSelected && hasAzimuthScale
          if data.targetFormType == 0
            ctx |> render_ellipse_aa(p, size * 0.02, data |> hdpx(2.), e3dColor, e3dColor)
          elif data.targetFormType == 1 || data.targetFormType == 2
            ctx |> render_ellipse_aa(p, size * 0.03, data |> hdpx(2.), e3dColor, transparentColor)
            let sign = data.targetFormType == 1 ? 1. : -1.
            let coord <- to_array_move(fixed_array<float2>(
            float2(p.x - size.x * 0.02, p.y + size.y * 0.015 * sign),
            float2(p.x, p.y - size.y * 0.03 * sign),
            float2(p.x + size.x * 0.02, p.y + size.y * 0.015 * sign)))
            ctx |> render_line_aa(coord, true, 1., float2(0, 0), e3dColor)
          if target.losSpeed < 3000.
            let coord <- to_array_move(fixed_array<float2>(float2(pos.x + angleRel * size.x, pos.y + (1. - distanceRel) * size.y),
            float2(pos.x + (angleRel - target.losHorSpeed * 0.0002) * size.x, pos.y + (1. - (distanceRel + target.losSpeed * 0.0002)) * size.y)))
            ctx |> render_line_aa(coord, false, data |> hdpx(2. * data.lineWidth), float2(0, 0), e3dColor)
        else
          let angleCenter = (angleRight + angleLeft) * 0.5
          if data.targetFormType == 0
            let tc = float2(0., 0.)
            ctx |> render_rect(
              pos.x + angleLeft  * size.x, pos.y + (1. - distanceRel - 0.5 * radialWidthRel) * size.y,
              pos.x + angleRight * size.x, pos.y + (1. - distanceRel + 0.5 * radialWidthRel) * size.y, tc, tc, tc)
          elif data.targetFormType == 1
            let coord <- to_array_move(fixed_array<float2>(
            float2(pos.x + angleLeft * size.x, pos.y + (1. - distanceRel + 0.02) * size.y),
            float2(pos.x + angleCenter * size.x, pos.y + (1. - distanceRel - 0.02) * size.y),
            float2(pos.x + angleRight * size.x, pos.y + (1. - distanceRel + 0.02) * size.y)))
            ctx |> render_line_aa(coord, true, data |> hdpx(100. * radialWidthRel), float2(0, 0), e3dColor)
          elif data.targetFormType == 2
            let tc = float2(0., 0.)
            let boxSize = 0.02 * size.x
            ctx |> render_rect(pos.x + angleCenter * size.x - boxSize, pos.y + (1. - distanceRel) * size.y - boxSize,
            pos.x + angleCenter * size.x + boxSize, pos.y + (1. - distanceRel) * size.y + boxSize, tc, tc, tc)

      elif (target.targetType == int(RadarTargetType.TYPE_OWN_WEAPON) && !data.hideWeaponIndication)
        if hasAzimuthScale
          ctx |> render_ellipse_aa(p, size * 0.005, data |> hdpx(2.), e3dColor, e3dColor)

      elif (target.targetType == int(RadarTargetType.TYPE_OWN_WEAPON_TARGET) && !data.hideWeaponIndication)
        if hasAzimuthScale && !target.isAttacked
          ctx |> render_ellipse_aa(p, size * 0.04, data |> hdpx(2.), e3dColor, transparentColor)

    if hasAzimuthScale && hasDistanceScale && !data.hideWeaponIndication
      let color = float4(Color4(is_color_or_white(data.targetColor)))
      let e3dColor = E3DCOLOR(Color4(color))
      Radar`foreach_own_weapon_links() <| $(var ownWeaponLink)
        Radar`foreach_own_weapon_with_target(ownWeaponLink.ownWeaponIndex, ownWeaponLink.ownWeaponTargetIndex) <| $(var ownWeapon; ownWeaponTarget)
          let ownWeaponPos = float2(pos.x + ownWeapon.azimuthRel * size.x, pos.y + (1. - ownWeapon.distanceRel) * size.y)
          let ownWeaponTargetPos = float2(pos.x + ownWeaponTarget.azimuthRel * size.x, pos.y + (1. - ownWeaponTarget.distanceRel) * size.y)
          if ownWeaponLink.lockDistanceToDistance < 1.0
            let direction = float2(ownWeaponTargetPos[0] - ownWeaponPos[0], ownWeaponTargetPos[1] - ownWeaponPos[1])
            let lockPos = float2(ownWeaponPos[0] + direction[0] * ownWeaponLink.lockDistanceToDistance, ownWeaponPos[1] + direction[1] * ownWeaponLink.lockDistanceToDistance)
            let coord <- to_array_move(fixed_array<float2>(ownWeaponPos, lockPos))
            ctx |> render_line_aa(coord, false, data |> hdpx(2.), float2(0, 0), e3dColor)
            ctx |> render_line_dashed(lockPos, ownWeaponTargetPos, data |> hdpx(10.), data |> hdpx(5.), data |> hdpx(2.), e3dColor)
          else
            let coord <- to_array_move(fixed_array<float2>(ownWeaponPos, ownWeaponTargetPos))
            ctx |> render_line_aa(coord, false, data |> hdpx(2.), float2(0, 0), e3dColor)

    ctx |> restore_viewport()

struct BScopeSquareElevationCurret : InteractableButton
  data : CanvasParams const? = null

  markLen : float = 1.0
  markLenShort : float = 0.6
  markLenLong : float = 2.0

  def BScopeSquareElevationCurret(pos, size : float2; in_params : CanvasParams&)
    InteractableButton`InteractableButton(self, pos, size)
    data = unsafe(addr(in_params))

  [unused_argument(rdata, rstate)] def override const draw(var ctx : GuiContext &; rdata : ElemRenderData & const; rstate : RenderState & const)
    if get_radar_hud_is_visible()
      draw_elevation(ctx, get_radar_hud_elevation())
      foreach_additional_beams() <| $(var additionalBeam)
        draw_elevation(ctx, additionalBeam.elevation)

    if get_radar_hud_is_visible2()
      draw_elevation(ctx, get_radar_hud_elevation2())

  def const elevationToLocal(elev_rel : float)
    let elevationMin = -get_radar_hud_elevation_min() * elevMaxInv * elevMaxScreenRelSize + 0.5
    let elevationMax = -get_radar_hud_elevation_max() * elevMaxInv * elevMaxScreenRelSize + 0.5
    return elevationMin * (1. - elev_rel) + elevationMax * elev_rel

  def const elevationLocalToY(elevation_loc : float)
    return self.pos.y + elevation_loc * size.y

  def override const toRelativePos(abs_pos : float2)
    let minY = elevationLocalToY(elevationToLocal(0.0))
    let maxY = elevationLocalToY(elevationToLocal(1.0))
    let lt = self.pos
    let rb = self.pos + self.size
    let relPos = float2(
      cvt_ex(abs_pos.x, lt.x, rb.x, self.minValueBounds.x, self.maxValueBounds.y),
      cvt_ex(abs_pos.y, minY, maxY, self.minValueBounds.x, self.maxValueBounds.y)
    )
    return relPos

  [unused_argument(start_pos_rel)] def override onPress(start_pos_rel, curr_pos_rel : float2)
    let el = lerp(get_radar_hud_elevation_min(), get_radar_hud_elevation_max(), curr_pos_rel.y)
    set_radar_elevation(el)

  def const draw_elevation(var ctx : GuiContext&; elev_rel : float)
    let elevationMin = elevationToLocal(0.0)
    let elevationMax = elevationToLocal(1.0)
    let elevation = elevationToLocal(elev_rel)

    var color = float4(Color4(is_color_or_white(data.lineColor)))
    color *= 0.42
    let e3dColor = E3DCOLOR(Color4(color))

    let minY = elevationLocalToY(elevationMin)
    let maxY = elevationLocalToY(elevationMax)

    let rx = self.pos.x + self.size.x

    let minCoord <- to_array_move(fixed_array<float2>(float2(rx, minY), float2(rx + markLen * self.size.x, minY)))
    ctx |> render_line_aa(minCoord, false, *data |> hdpx(4.), float2(0, 0), e3dColor)
    let zeroCoord <- to_array_move(fixed_array<float2>(float2(rx, pos.y + 0.5 * self.size.y), float2(rx + markLenShort * self.size.x, pos.y + 0.5 * self.size.y)))
    ctx |> render_line_aa(zeroCoord, false, *data |> hdpx(4.), float2(0, 0), e3dColor)
    let maxCoord <- to_array_move(fixed_array<float2>(float2(rx, maxY), float2(rx + markLen * self.size.x, maxY)))
    ctx |> render_line_aa(maxCoord, false, *data |> hdpx(4.), float2(0, 0), e3dColor)
    let elevCoord <- to_array_move(fixed_array<float2>(float2(rx, pos.y + elevation * self.size.y), float2(rx + markLenShort * self.size.x, pos.y + elevation * self.size.y)))
    ctx |> render_line_aa(elevCoord, false, *data |> hdpx(4.), float2(0, 0), e3dColor)

    if get_radar_hud_elevation_stabilize()
      let hero = get_controlled_hero()
      if hero != null && !hero.isDelayed
        let fmw = hero |> as_fmw()
        if fmw != null
          let tangage = deg_to_rad(fmw.tangage)
          let elevationHorizon = tangage * elevMaxInv * elevMaxScreenRelSize + 0.5
          let horizonCoord <- to_array_move(fixed_array<float2>(float2(rx, pos.y + elevationHorizon * self.size.y), float2(rx + markLenLong * self.size.x, pos.y + elevationHorizon * self.size.y)))
          ctx |> render_line_aa(horizonCoord, false, *data |> hdpx(4.), float2(0, 0), e3dColor)

    if get_radar_hud_scan_elevation_max() > get_radar_hud_scan_elevation_min()
      let elevationScanMin = -get_radar_hud_scan_elevation_min() * elevMaxInv * elevMaxScreenRelSize + 0.5
      let elevationScanMax = -get_radar_hud_scan_elevation_max() * elevMaxInv * elevMaxScreenRelSize + 0.5

      let scanCoord <- to_array_move(fixed_array<float2>(float2(rx, pos.y + elevationScanMin * self.size.y), float2(rx - markLen * self.size.x, pos.y + elevationScanMin * self.size.y),
      float2(rx - markLen * self.size.x, pos.y + elevationScanMax * self.size.y), float2(rx, pos.y + elevationScanMax * self.size.y)))
      ctx |> render_line_aa(scanCoord, false, *data |> hdpx(4.), float2(0, 0), e3dColor)

def b_scope_square(var ctx : GuiContext&; pos, sz : float2; data : CanvasParams&)
  if !data.hideBack || data.showScanAzimuth
    b_scope_square_bkg(ctx, data, pos, sz)
  if !data.hideBack
    b_scope_square_target_sector(ctx, data, pos, sz)
  b_scope_square_azimuth(ctx, data, pos, sz, true, get_radar_hud_turret_azimuth(), -1., -1.)
  render_ground_reflection(ctx, sz, pos, is_color_or_white(data.lineColor), int2(20, 10), true)
  if get_radar_hud_is_visible()
    if get_radar_hud_is_emitting() && !data.hideBeam
      b_scope_square_azimuth(ctx, data, pos, sz, false, get_radar_hud_azimuth(), get_radar_hud_distance(), get_radar_hud_azimuth_half_width())
      foreach_additional_beams() <| $(var additionalBeam)
        b_scope_square_azimuth(ctx, data, pos, sz, false, additionalBeam.azimuth, get_radar_hud_distance(), get_radar_hud_azimuth_half_width())

  ctx |> set_viewport(pos.x, pos.y, pos.x + sz.x, pos.y + sz.y)

  if get_radar_hud_is_visible2()
    if get_radar_hud_is_emitting2() && !data.hideBeam
      b_scope_square_azimuth(ctx, data, pos, sz, false, get_radar_hud_azimuth2(), get_radar_hud_distance2(), get_radar_hud_azimuth_half_width2())

  if get_radar_hud_aam_launch_zone_visible() && get_radar_hud_has_azimuth_scale() && !data.hideLaunchZone
    b_scope_square_launch_range(ctx, data, pos, sz)
  b_scope_square_cue(ctx, data, pos, sz)

  ctx |> restore_viewport()

  if !data.hideHorAngle
    b_scope_square_inner_labels(ctx, data, pos, sz, data.fontSize)
  if data.hasAviaHorizont
    b_scope_square_aviahorizont(ctx, data, pos, sz)

def b_scope_square_labels(data : CanvasParams&; pos : float2; size : float2; var visitor : InteractableVisitor&)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  var vertOffset = 0.
  var horOffset = 0.
  var vertOffset2 = 0.
  var bottomOffset = 0.

  let azRanText = !data.hideHorAngle ? fmt(":.0f", floor(rad_to_deg(get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min()) + 0.5)) + loc("measureUnits/deg") : ""
  let strBoxAz = get_str_bbox(azRanText, azRanText |> length(), fctx)
  if get_radar_hud_has_azimuth_scale() && !data.hideHorAngle
    horOffset += strBoxAz.width.x

  var textButtonStyle = TextButtonStyle()
  textButtonStyle.color = data.modeColor
  textButtonStyle.fontId = data.fontId
  textButtonStyle.fontSize = data.fontSize
  textButtonStyle.glowColor =  get_font_fx_color(data.modeColor)
  textButtonStyle.glowFxFactor =  get_font_fx_factor(data.modeColor, data)

  let modeName = Radar`getModeNameLoc(data.radarModeNameLangId)
  let modeNamePos = pos + size * float2(0.5, 0.0)

  var modeStyle := textButtonStyle
  modeStyle.anchorVert = AnchorVert.Top
  modeStyle.anchorHorz = AnchorHorz.Center
  var modeNameEl = TextButton(modeNamePos, modeName, modeStyle)
  modeNameEl.onClickCallback <- @ <| ()
    Radar`changeMode()
  modeNameEl.walkLayout(visitor)

  let strBoxMode = modeNameEl.textBox
  vertOffset += strBoxMode.width.y + data |> hdpx(4.)

  if get_radar_hud_noise_signal_visible() && get_radar_hud_is_visible() && get_radar_hud_noise_signal() > 0.5 && !data.enableByMfd
    let noisePos = float2(pos.x + size.x * 0.44 - strBoxMode.width.x * 0.5, pos.y - data |> hdpx(2.))
    let noiseSize = size * 0.06
    var noiseEl = NoiseSignalElement(noisePos, noiseSize, data, get_radar_hud_noise_signal())
    noiseEl.walkLayout(visitor)

  if get_radar_hud_is_visible2()
    let nameId2 = get_radar_hud_mode_name2_id()
    let defaultStr2 = get_radar_hud_is_visible2() ? (get_radar_hud_is_irst() ? "hud/irst" : "hud/radarEmitting") : ""
    let modeName2 = loc(nameId2 >= 0 && nameId2 < radarModeNames |> length() ? radarModeNames[nameId2] : defaultStr2)

    var mode2Style := modeStyle
    mode2Style.anchorHorz = AnchorHorz.Left

    let mode2Pos = float2(pos.x + size.x * 0.57 + strBoxMode.width.x * 0.5, pos.y)
    var modeName2El = TextButton(mode2Pos, modeName2, mode2Style)
    modeName2El.walkLayout(visitor)

    if get_radar_hud_noise_signal_visible() && get_radar_hud_noise_signal2() > 0.5 && !data.enableByMfd
      let noisePos = float2(pos.x + size.x * 0.51 + strBoxMode.width.x * 0.5, pos.y)
      let noiseSize = size * 0.06
      var noiseEl = NoiseSignalElement(noisePos, noiseSize, data, get_radar_hud_noise_signal2())
      noiseEl.walkLayout(visitor)

  if get_radar_hud_has_azimuth_scale() && get_radar_hud_scan_azimuth_max() > get_radar_hud_scan_azimuth_min()
    var azimuthScaleStyle := textButtonStyle
    azimuthScaleStyle.color = data.horAngleColor
    azimuthScaleStyle.glowColor = get_font_fx_color(data.horAngleColor)
    azimuthScaleStyle.glowFxFactor = get_font_fx_factor(data.horAngleColor, data)
    if data.centerRadar
      azimuthScaleStyle.anchorVert = AnchorVert.Center
    else
      azimuthScaleStyle.anchorVert = AnchorVert.Top

    let azText = fmt(":.0f", floor(rad_to_deg(get_radar_hud_scan_azimuth_max() - get_radar_hud_scan_azimuth_min()) + 0.5))
    let elText = fmt(":.0f", floor(rad_to_deg(get_radar_hud_scan_elevation_max() - get_radar_hud_scan_elevation_min()) + 0.5))
    let deg = loc("measureUnits/deg")
    let text = "{azText}{deg}x{elText}{deg}" + (get_radar_hud_scan_patterns_max() > 1 ? "*" : " ")

    let azimuthScalePos = float2(pos.x + horOffset, pos.y + vertOffset)
    var azScaleEl = TextButton(azimuthScalePos, text, azimuthScaleStyle)
    azScaleEl.onClickCallback <- @ <| ()
      Radar`changeScanPattern()
    azScaleEl.walkLayout(visitor)
    let strBoxScan = azScaleEl.textBox
    vertOffset2 += strBoxScan.width.y

  if get_radar_hud_has_distance_scale() && !data.hideScale
    var style := textButtonStyle
    style.color = data.scaleColor
    style.glowColor = get_font_fx_color(data.scaleColor)
    style.glowFxFactor = get_font_fx_factor(data.scaleColor, data)
    style.anchorVert = AnchorVert.Bottom
    style.anchorHorz = AnchorHorz.Right

    let textMin = (get_radar_hud_velocity_search() ? get_measure_units_text(MeasureUnitsTypes.MEASURE_UNIT_SPEED, get_radar_hud_distance_min(), true, 1.) :
      get_measure_units_text(MeasureUnitsTypes.MEASURE_UNIT_DIST, get_radar_hud_distance_min() * 1000., true, 1.))

    let minPos = float2(pos.x + size.x, pos.y + size.y)
    var rangeScaleEl = TextButton(minPos, textMin, style)
    rangeScaleEl.onClickCallback <- @ <| ()
      Radar`changeRange()
    rangeScaleEl.walkLayout(visitor)

    let strBoxMin = rangeScaleEl.textBox
    bottomOffset = strBoxMin.width.y

    let textMax = (get_radar_hud_velocity_search() ? get_measure_units_text(MeasureUnitsTypes.MEASURE_UNIT_SPEED, get_radar_hud_distance_max(), true, 1.) :
      get_measure_units_text(MeasureUnitsTypes.MEASURE_UNIT_DIST, get_radar_hud_distance_max() * 1000., true, 1.))
    let text = textMax + (get_radar_hud_distance_scale_max() > 1 ? "*" : " ")

    var maxTextPos = float2(0.0)
    if data.centerRadar
      let newPos = pos.y + (vertOffset + vertOffset2 + bottomOffset) * 0.5
      maxTextPos = float2(pos.x + size.x, newPos)
      style.anchorVert = AnchorVert.Bottom
    else
      maxTextPos = float2(pos.x + size.x, pos.y + vertOffset)
      style.anchorVert = AnchorVert.Top

    var maxRangeEl = TextButton(maxTextPos, text, style)
    maxRangeEl.onClickCallback <- @ <| ()
      Radar`changeRange()
    maxRangeEl.walkLayout(visitor)

    let strBox = maxRangeEl.textBox
    if vertOffset2 == 0.
      vertOffset2 += strBox.width.y

  vertOffset += vertOffset2 + data |> hdpx(4.)
  let sz = float2(size.x - horOffset, size.y - vertOffset - bottomOffset)

  if get_radar_hud_has_azimuth_scale()
    if !data.hideHorAngle
      var style := textButtonStyle
      style.color = data.horAngleColor
      style.glowColor = get_font_fx_color(data.horAngleColor)
      style.glowFxFactor = get_font_fx_factor(data.horAngleColor, data)
      style.anchorVert = AnchorVert.Top
      let p = float2(pos.x, pos.y + vertOffset + data |> hdpx(4.))
      var azRangeEl = TextButton(p, azRanText, style)
      azRangeEl.walkLayout(visitor)

    if !data.hideVerAngle
      var style := textButtonStyle
      style.color = data.verAngleColor
      style.glowColor = get_font_fx_color(data.verAngleColor)
      style.glowFxFactor = get_font_fx_factor(data.verAngleColor, data)
      style.anchorHorz = AnchorHorz.Right
      style.anchorVert = AnchorVert.Bottom

      let elvMaxText = fmt(":.0f", floor(rad_to_deg(get_radar_hud_elevation_max()) + 0.5)) + loc("measureUnits/deg")
      let elvMaxPos = float2(pos.x + horOffset,
        pos.y + vertOffset + (-get_radar_hud_elevation_max() * elevMaxInv * elevMaxScreenRelSize + 0.5) * sz.y)

      var elvMaxEl = TextButton(elvMaxPos, elvMaxText, style)
      elvMaxEl.walkLayout(visitor)
      let strBoxElMax = elvMaxEl.textBox

      let elvMinText = fmt(":.0f", floor(rad_to_deg(get_radar_hud_elevation_min()) + 0.5)) + loc("measureUnits/deg")
      let elvMinPos = float2(pos.x + horOffset,
        pos.y + vertOffset + (-get_radar_hud_elevation_min() * elevMaxInv * elevMaxScreenRelSize + 0.5) * sz.y)

      style.anchorVert = AnchorVert.Top
      var elvMinEl = TextButton(elvMinPos, elvMinText, style)
      elvMinEl.walkLayout(visitor)

      let strBoxElMin = elvMinEl.textBox

      horOffset = max(horOffset, max(strBoxElMax.width.x, strBoxElMin.width.x))
  return float3(horOffset, vertOffset, bottomOffset)

def b_scope_square_inner_labels(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2; font_size : int)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, font_size)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(font_size)
  let color = is_color_or_white(data.horAngleColor)
  ctx |> set_color(color)
  ctx |> set_draw_str_attr(FontFxType.FFT_GLOW, 0, 0, get_font_fx_color(color), get_font_fx_factor(color, data))

  let azMinText = fmt(":.0f", floor(rad_to_deg(get_radar_hud_azimuth_min()) + 0.5)) + loc("measureUnits/deg")
  let strBoxAzMin = get_str_bbox(azMinText, azMinText |> length(), fctx)
  ctx |> goto_xy(pos.x + data |> hdpx(4.), pos.y + strBoxAzMin.width.y + data |> hdpx(4.))
  ctx |> draw_str_scaled(1.0, azMinText, azMinText |> length())

  let azMaxText = fmt(":.0f", floor(rad_to_deg(get_radar_hud_azimuth_max()) + 0.5)) + loc("measureUnits/deg")
  let strBoxAzMax = get_str_bbox(azMaxText, azMaxText |> length(), fctx)
  ctx |> goto_xy(pos.x + size.x - strBoxAzMax.width.x - data |> hdpx(4.), pos.y + strBoxAzMax.width.y + data |> hdpx(4.))
  ctx |> draw_str_scaled(1.0, azMaxText, azMaxText |> length())

def b_scope_square_bkg(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  let azimuthRangeInv = azimuthRange != 0. ? 1. / azimuthRange : 1.
  let scanAzimuthMinRelW = 0.5 + get_radar_hud_scan_azimuth_min() * azimuthRangeInv
  let scanAzimuthMaxRelW = 0.5 + get_radar_hud_scan_azimuth_max() * azimuthRangeInv
  ctx |> set_color(areaBackgroundColor)
  let rb = pos + size
  let tc = float2(0., 0.)
  ctx |> render_rect(pos.x, pos.y, rb.x, rb.y, tc, tc, tc)
  //not repeat component 'frame' from darg, i am cant see him in game (useless)

  var color = float4(Color4(is_color_or_white(data.lineColor)))
  color *= 0.7
  let e3dColor = E3DCOLOR(Color4(color))
  ctx |> set_color(e3dColor)
  if scanAzimuthMinRelW <= 1. && scanAzimuthMinRelW >= 0.
    ctx |> draw_line(pos.x + scanAzimuthMinRelW * size.x, pos.y, pos.x + scanAzimuthMinRelW * size.x, pos.y + size.y, data |> hdpx(1.6 * data.lineWidth))
  if scanAzimuthMaxRelW <= 1. && scanAzimuthMaxRelW >= 0.
    ctx |> draw_line(pos.x + scanAzimuthMaxRelW * size.x, pos.y, pos.x + scanAzimuthMaxRelW * size.x, pos.y + size.y, data |> hdpx(1.6 * data.lineWidth))

  if data.hideBack
    return

  var scanAzimuthMinRel = 0.
  var scanAzimuthMaxRel = 1.
  if scanAzimuthMinRelW - 0.5 <= scanAzimuthMaxRelW - 0.5
    scanAzimuthMinRel = scanAzimuthMinRelW
    scanAzimuthMaxRel = scanAzimuthMaxRelW

  let distMinRel = max(0., get_radar_hud_distance_min() / max(get_radar_hud_distance_max(), 1.))
  let distanceMinY = (1. - distMinRel)
  if get_radar_hud_has_distance_scale()
    var rang = 0.25
    while rang < distanceMinY + 0.01
      ctx |> draw_line(pos.x + scanAzimuthMinRel * size.x, pos.y + rang * size.y, pos.x + scanAzimuthMaxRel * size.x, pos.y + rang * size.y, data |> hdpx(1.2 * data.lineWidth))
      rang = rang + 0.25
    if distanceMinY % 0.25 != 0.0
      ctx |> draw_line(pos.x + scanAzimuthMinRel * size.x, pos.y + distanceMinY * size.y, pos.x + scanAzimuthMaxRel * size.x, pos.y + distanceMinY * size.y, data |> hdpx(1.2 * data.lineWidth))

  if get_radar_hud_has_azimuth_scale()
    let azimuthRelStep = PI / 12. * azimuthRangeInv
    var azRel = scanAzimuthMaxRel
    while azRel > scanAzimuthMinRel
      ctx |> draw_line(pos.x + azRel * size.x, pos.y, pos.x + azRel * size.x, pos.y + distanceMinY * size.y, data |> hdpx(1.2 * data.lineWidth))
      azRel -= azimuthRelStep

def b_scope_square_target_sector(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())

  let halfAzimuthWidth = min(azimuthRange > 0. ? get_radar_hud_target_azimuth_width() / azimuthRange : 0., 0.5)
  let tc = float2(0., 0.)
  var color = float4(Color4(data.color))//isColorOrWhite ???
  color *= 0.2
  let e3dColor = E3DCOLOR(Color4(color))
  ctx |> set_color(e3dColor)
  ctx |> render_rect(pos.x + (0.5 - halfAzimuthWidth) * size.x, pos.y + (1. - get_radar_hud_target_distance()) * size.y,
    pos.x + (0.5 + halfAzimuthWidth) * size.x, pos.y + size.y, tc, tc, tc)

def b_scope_square_azimuth(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2; for_tank_only : bool;
                           val : float; dist : float; half_width : float)
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  let hero = get_watched_hero()
  let isTank = hero != null && hero.unitType == UnitType.UT_HeavyVehicle
  if for_tank_only && (!isTank || azimuthRange <= PI + 0.035)
    return
  let var1 = for_tank_only || (dist == 1. && half_width > 0.)
  if var1
    let halfAzimuthWidth = min(azimuthRange > 0. ? half_width / azimuthRange : 0., 0.5)
    var color = float4(Color4(is_color_or_white(data.color)))
    color *= 0.4
    let e3dColor = E3DCOLOR(Color4(color))
    ctx |> set_color(e3dColor)
    let tc = float2(0., 0.)
    if data.beamShape == 1
      ctx |> set_color(data.lineColor)
      ctx |> draw_line(pos.x + (val - 0.02) * size.x, pos.y + size.y * 0.97, pos.x + (val + 0.02) * size.x, pos.y + size.y * 0.97, data |> hdpx(data.lineWidth * 5.))
      ctx |> draw_line(pos.x + val * size.x, pos.y + size.y * 0.97, pos.x + val * size.x, pos.y + size.y, data |> hdpx(data.lineWidth * 5.))
    else
      ctx |> render_rect(pos.x + (val - halfAzimuthWidth) * size.x, pos.y,
       pos.x + (val + halfAzimuthWidth) * size.x, pos.y + size.y, tc, tc, tc)
  else
    let color = is_color_or_white(data.lineColor)
    ctx |> set_color(color)
    if for_tank_only
      ctx |> draw_line(pos.x + val * size.x, pos.y, pos.x + val * size.x, pos.y + size.y, data |> hdpx(1.6))
    else
      let p1 = float2(pos.x + val * size.x, pos.y + max(1. - dist, 0.) * size.y)
      let p2 = float2(pos.x + val * size.x, pos.y + size.y)
      ctx |> render_line_dashed(p1, p2, data |> hdpx(10.), data |> hdpx(5.), data |> hdpx(1.6 * data.lineWidth), color)

def b_scope_square_launch_range(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  var color = float4(Color4(is_color_or_white(data.lineColor)))
  color *= 0.42
  let e3dColor = E3DCOLOR(Color4(color))
  ctx |> set_color(e3dColor)

  let dist = get_radar_hud_aam_launch_zone_dist()
  if dist <= 1.
    ctx |> draw_line(pos.x + 0.8 * size.x, pos.y + (1. - dist) * size.y,
     pos.x + size.x, pos.y + (1. - dist) * size.y, data |> hdpx(4. * data.lineWidth))
  let distMin = get_radar_hud_aam_launch_zone_dist_min()
  if distMin <= 1.
    ctx |> draw_line(pos.x + 0.9 * size.x, pos.y + (1. - distMin) * size.y,
     pos.x + size.x, pos.y + (1. - distMin) * size.y, data |> hdpx(4. * data.lineWidth))
  let distMax = get_radar_hud_aam_launch_zone_dist_max()
  if distMax <= 1.
    ctx |> draw_line(pos.x + 0.9 * size.x, pos.y + (1. - get_radar_hud_aam_launch_zone_dist_max()) * size.y,
     pos.x + size.x, pos.y + (1. - get_radar_hud_aam_launch_zone_dist_max()) * size.y, data |> hdpx(4. * data.lineWidth))
  let dgftDistMax = get_radar_hud_aam_launch_zone_dist_dgft_max()
  let dgftDistMin = get_radar_hud_aam_launch_zone_dist_dgft_min()
  if dgftDistMax <= 1.
    ctx |> draw_line(pos.x + 0.92 * size.x, pos.y + (1. - dgftDistMax) * size.y,
     pos.x + 0.98 * size.x, pos.y + (1. - dgftDistMax) * size.y, data |> hdpx(4. * data.lineWidth))
  if dgftDistMin <= 1.
    ctx |> draw_line(pos.x + 0.92 * size.x, pos.y + (1. - dgftDistMin) * size.y,
     pos.x + 0.98 * size.x, pos.y + (1. - dgftDistMin) * size.y, data |> hdpx(4. * data.lineWidth))
  if dgftDistMax <= 1. || dgftDistMin <= 1.
    ctx |> draw_line(pos.x + 0.92 * size.x, pos.y + (1. - dgftDistMin) * size.y,
     pos.x + 0.92 * size.x, pos.y + (1. - min(dgftDistMax, 1.)) * size.y, data |> hdpx(4. * data.lineWidth))

def b_scope_square_cue(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  if !get_radar_hud_cue_visible()
    return

  return if has_a_detected_target()

  let color = is_color_or_white(data.lineColor)//remove is_color_or_white if use is_color on target sector
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  let cueAzimuthHwr = get_radar_hud_cue_azimuth_half_width_rel()
  let cueDistWidthRel =  get_radar_hud_cue_dist_width_rel()
  let cuePos = pos + float2((get_radar_hud_cue_azimuth() * (get_radar_hud_target_azimuth_width() / azimuthRange - cueAzimuthHwr) + 0.5) * size.x,
          (1. - (0.5 * cueDistWidthRel + get_radar_hud_cue_distance() * get_radar_hud_target_distance() * (1. - cueDistWidthRel))) * size.y)
  let lcoord <- to_array_move(fixed_array<float2>(float2(cuePos.x - cueAzimuthHwr * size.x, cuePos.y - cueDistWidthRel * size.y * 0.5),
   float2(cuePos.x - cueAzimuthHwr * size.x, cuePos.y + cueDistWidthRel * size.y * 0.5)))
  ctx |> render_line_aa(lcoord, false, data |> hdpx(2. * data.lineWidth), float2(0, 0), color)
  let rcoord <- to_array_move(fixed_array<float2>(float2(cuePos.x + cueAzimuthHwr * size.x, cuePos.y - cueDistWidthRel * size.y * 0.5),
   float2(cuePos.x + cueAzimuthHwr * size.x, cuePos.y + cueDistWidthRel * size.y * 0.5)))
  ctx |> render_line_aa(rcoord, false, data |> hdpx(2. * data.lineWidth), float2(0, 0), color)

  var hmin = 0.0
  var hmax = 0.0
  if data.cueHeights && Radar`getCueHeights(hmin, hmax)
    hmin *= metrToThsFeet
    hmax *= metrToThsFeet
    let hmaxText = fmt(":d", roundi(hmax))
    let hminText = fmt(":d", roundi(hmin))
    var fctx : StdGuiFontContext
    get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
    ctx |> set_color(data.cueTopHeiColor)
    ctx |> set_font(data.fontId, 0, 0)
    ctx |> set_font_ht(data.fontSize)

    ctx |> goto_xy(cuePos.x + cueAzimuthHwr * size.x + 3., cuePos.y - cueDistWidthRel * size.y * 0.5)
    ctx |> draw_str_scaled(1., hmaxText, hmaxText |> length())

    ctx |> set_color(hmin < 0. ? data.cueUndergroundColor : data.cueLowHeiColor)
    ctx |> goto_xy(cuePos.x + cueAzimuthHwr * size.x + 3., cuePos.y + cueDistWidthRel * size.y * 0.5)
    ctx |> draw_str_scaled(1., hminText, hminText |> length())

def foreach_additional_beams(blk : block<(additionalBeam : RadarAdditionalBeam const const#) : void>)
  get_radar_hud_additional_beams() <| $(additionalBeams : array<RadarAdditionalBeam> const#)
    for t in additionalBeams
      invoke(blk, t)

struct BScopeMain : RadarInteractableEll
  def BScopeMain(pos, size : float2; in_params : CanvasParams&)
    RadarInteractableEll`RadarInteractableEll(self, pos, size, in_params)

  def override walkLayout(var visitor : InteractableVisitor&)
    InteractableCanvasEll`walkLayout(self, visitor)

    var offsets = float4(0.0)
    if !data.isAAComplexMenuLayout
      offsets = b_scope_labels(visitor, *self.data, pos, size)
    else
      offsets = b_scope_labels_aa_complex(visitor, *self.data, pos, size)
    let totalOffset = float2(offsets.x + offsets.z, offsets.y + offsets.w)
    let sz = float2(min(size.x - totalOffset.x, size.y - totalOffset.y))
    let p = pos + (totalOffset.x > totalOffset.y ? float2(offsets.x, (size.y - sz.y) * 0.5) : float2((size.x - sz.x) * 0.5, offsets.y))

    var centerEl = BScopeCenter(p, sz, *self.data)
    centerEl.walkLayout(visitor)

    let iffFilterSize = float2(*self.data |> hdpx(15.0), *self.data |> hdpx(20.0))
    let offset = float2(*self.data |> hdpx(3.0), -*self.data |> hdpx(3.0))
    var iffFilter = IFFFilterButton(float2(pos.x, p.y) + offset, iffFilterSize, *self.data)
    iffFilter.walkLayout(visitor)

  [unused_argument(rdata, rstate)] def override const draw(var ctx : GuiContext &; rdata : ElemRenderData & const; rstate : RenderState & const)
    if data.isAAComplexMenuLayout
      b_scope_background_tactical_map_aa_complex(ctx, rdata, *self.data, size)

struct BScopeCenter : RadarInteractableEll
  def BScopeCenter(pos, size : float2; in_params : CanvasParams&)
    RadarInteractableEll`RadarInteractableEll(self, pos, size, in_params)

  def override walkLayout(var visitor : InteractableVisitor&)
    InteractableCanvasEll`walkLayout(self, visitor)

    var targets = PolarTargetsElement(pos, size, data, true)
    targets.walkLayout(visitor)

  [unused_argument(rdata, rstate)] def override const draw(var ctx : GuiContext &; rdata : ElemRenderData & const; rstate : RenderState & const)
    b_scope(ctx, *self.data, self.pos, self.size)

def b_scope(var ctx : GuiContext&; data : CanvasParams&; pos, size : float2)
  b_scope_background(ctx, data, pos, size)
  b_scope_azimuth(ctx, data, pos + size * 0.5, size, false, get_radar_hud_aim_azimuth(), 0., -1., 2.)
  b_scope_azimuth(ctx, data, pos + size * 0.5, size, false, get_radar_hud_turret_azimuth(), 0., -1., 1.)
  let half_width = get_radar_hud_target_azimuth_width()
  if half_width > 0.
    b_scope_sector(ctx, data, pos + size * 0.5, size, half_width, get_radar_hud_turret_azimuth())
  if get_radar_hud_is_visible() && get_radar_hud_is_emitting()
    let dist = get_radar_hud_distance()
    let halfVal = get_radar_hud_azimuth_half_width()
    let isSectorView = dist == 1. && halfVal > 0.
    b_scope_azimuth(ctx, data, pos + size * 0.5, size, isSectorView, get_radar_hud_azimuth(), halfVal, dist, 1.2)
    foreach_additional_beams() <| $(var additionalBeam)
      b_scope_azimuth(ctx, data, pos + size * 0.5, size, isSectorView, additionalBeam.azimuth, halfVal, dist, 1.2)
  if get_radar_hud_is_visible2() && get_radar_hud_is_emitting2()
    let dist = get_radar_hud_distance2()
    let halfVal = get_radar_hud_azimuth_half_width2()
    let isSectorView = dist == 1. && halfVal > 0.
    b_scope_azimuth(ctx, data, pos + size * 0.5, size, isSectorView, get_radar_hud_azimuth2(), halfVal, dist, 1.2)
  b_scope_cue(ctx, data, pos + size * 0.5, size)

def b_scope_labels_aa_complex(var visitor : InteractableVisitor&; data : CanvasParams&; pos, elem_size : float2)
  let offsets = float4(5.0)

  var style = TextButtonStyle()
  style.fontId = data.fontId
  style.fontSize = data.fontSize
  style.color = data.color
  style.glowColor = get_font_fx_color(data.color)
  style.glowFxFactor = get_font_fx_factor(data.color, data)
  style.anchorHorz = AnchorHorz.Right
  style.anchorVert = AnchorVert.Bottom

  let size = float2(min(elem_size.x, elem_size.y)) - float2(offsets.z, offsets.w)

  let deg = loc("measureUnits/deg")

  let hideMeasures = !get_radar_hud_has_azimuth_scale() || get_radar_hud_scan_azimuth_max() <= get_radar_hud_scan_azimuth_min()
  let azText = fmt(":.0f", floor(rad_to_deg(get_radar_hud_scan_azimuth_max() - get_radar_hud_scan_azimuth_min()) + 0.5))
  let elText = fmt(":.0f", floor(rad_to_deg(get_radar_hud_scan_elevation_max() - get_radar_hud_scan_elevation_min()) + 0.5))
  let textMeasures = !hideMeasures ? "{azText}{deg}x{elText}{deg}" + (get_radar_hud_scan_patterns_max() > 1 ? "*" : "") : ""

  let scanPatternPos = float2(pos.x + size.x, pos.y + size.y)
  var scanPatternEl = TextButton(scanPatternPos, textMeasures, style)
  scanPatternEl.onClickCallback <- @ <| ()
    Radar`changeScanPattern()
  scanPatternEl.walkLayout(visitor)

  let textDist = (get_radar_hud_velocity_search() ? get_measure_units_text(MeasureUnitsTypes.MEASURE_UNIT_SPEED, get_radar_hud_distance_max(), true, 1.) :
     get_measure_units_text(MeasureUnitsTypes.MEASURE_UNIT_DIST, get_radar_hud_distance_max() * 1000., true, 1.))
  let distPos = float2(pos.x + size.x * 0.8, pos.y + size.y)
  var distEl = TextButton(distPos, textDist, style)
  distEl.onClickCallback <- @ <| ()
    Radar`changeRange()
  distEl.walkLayout(visitor)

  return offsets

def b_scope_labels(var visitor : InteractableVisitor&; data : CanvasParams&; elem_pos, elem_size : float2)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize/*hudFontHgt*/)
  var topOffset = 0.
  var leftOffset = 0.
  var rightOffset = 0.
  var bottomOffset = 0.

  var style = TextButtonStyle()
  style.color = data.color
  style.fontId = data.fontId
  style.fontSize = data.fontSize
  style.glowColor =  get_font_fx_color(data.color)
  style.glowFxFactor =  get_font_fx_factor(data.color, data)
  style.anchorHorz = AnchorHorz.Left
  style.anchorVert = AnchorVert.Bottom

  let hideMeasures = !get_radar_hud_has_azimuth_scale() || get_radar_hud_scan_azimuth_max() <= get_radar_hud_scan_azimuth_min()
  let deg = loc("measureUnits/deg")
  let text270 = "270{deg}"
  let strBox270 = get_str_bbox(text270, text270 |> length(), fctx)
  let azText = fmt(":.0f", floor(rad_to_deg(get_radar_hud_scan_azimuth_max() - get_radar_hud_scan_azimuth_min()) + 0.5))
  let elText = fmt(":.0f", floor(rad_to_deg(get_radar_hud_scan_elevation_max() - get_radar_hud_scan_elevation_min()) + 0.5))
  let textMeasures = !hideMeasures ? "{azText}{deg}x{elText}{deg}" + (get_radar_hud_scan_patterns_max() > 1 ? "*" : "") : ""
  let strBoxMeas = get_str_bbox(textMeasures, textMeasures |> length(), fctx)
  leftOffset = data.hasTxtBlock ? strBox270.width.x : max(strBox270.width.x, strBoxMeas.width.x)

  let text180 = "180{deg}"
  let strBox180 = get_str_bbox(text180, text180 |> length(), fctx)
  bottomOffset = strBox180.width.y + data |> hdpx(4.)

  let text90 = "90{deg}"
  let strBox90 = get_str_bbox(text90, text90 |> length(), fctx)
  let textDist = (get_radar_hud_velocity_search() ? get_measure_units_text(MeasureUnitsTypes.MEASURE_UNIT_SPEED, get_radar_hud_distance_max(), true, 1.) :
     get_measure_units_text(MeasureUnitsTypes.MEASURE_UNIT_DIST, get_radar_hud_distance_max() * 1000., true, 1.))
  let textVel = get_radar_hud_has_distance_scale() ? textDist + (get_radar_hud_distance_scale_max() > 1 ? "*" : "") : ""
  let strBoxVel = get_str_bbox(textVel, textVel |> length(), fctx)
  rightOffset = max(strBoxVel.width.x, strBox90.width.x)

  let modeName = Radar`getModeNameLoc(data.radarModeNameLangId)
  let strBoxMode = get_str_bbox(modeName, modeName |> length(), fctx)
  topOffset = strBoxMode.width.y + data |> hdpx(4.)

  let name2Id = get_radar_hud_mode_name2_id()
  let defaultStr2 = get_radar_hud_is_visible2() ? (get_radar_hud_is_irst() ? "hud/irst" : "hud/radarEmitting") : ""
  let modeName2 = loc(name2Id >= 0 && name2Id < radarModeNames |> length() ? radarModeNames[name2Id] : defaultStr2)
  let strBoxMode2 = get_str_bbox(modeName2, modeName2 |> length(), fctx)

  let text0 = "0{deg}"
  let strBox0 = get_str_bbox(text0, text0 |> length(), fctx)

  let totalOffset = float2(leftOffset + rightOffset, topOffset + bottomOffset)
  let size = float2(min(elem_size.x - totalOffset.x, elem_size.y - totalOffset.y))
  let pos = elem_pos + (totalOffset.x > totalOffset.y ? float2(leftOffset, (elem_size.y - size.y) * 0.5) : float2((elem_size.x - size.x) * 0.5, topOffset))

  var modePos = float2(pos.x + size.x * 0.5 - strBoxMode.width.x - strBox0.width.x, pos.y - topOffset + strBoxMode.width.y)
  if data.hasTxtBlock
    modePos = float2(pos.x - strBoxMode.width.x, pos.y + size.y + bottomOffset + strBoxMode.width.y - data |> hdpx(8.))
  var modeEl = TextButton(modePos, modeName, style)
  modeEl.onClickCallback <- @ <| ()
    Radar`changeMode()
  modeEl.walkLayout(visitor)

  let mode2Pos = float2(pos.x + size.x * 0.5 + strBox0.width.x, pos.y - topOffset + strBoxMode2.width.y)
  var mode2El = TextButton(mode2Pos, modeName2, style)
  mode2El.walkLayout(visitor)

  let text0Pos = float2(pos.x + size.x * 0.5 - strBox0.width.x * 0.5, pos.y - topOffset + strBox0.width.y)
  var text0El = TextButton(text0Pos, text0, style)
  text0El.walkLayout(visitor)

  if !hideMeasures
    var p = float2(pos.x - strBoxMeas.width.x, pos.y + size.y * 0.5 + strBoxMeas.width.y)
    if data.hasTxtBlock
      p = float2(pos.x - strBoxMode.width.x, pos.y + size.y + bottomOffset + strBoxMode.width.y + strBoxMeas.width.y - data |> hdpx(4.))
    var scanPatternEl = TextButton(p, textMeasures, style)
    scanPatternEl.onClickCallback <- @ <| ()
      Radar`changeScanPattern()
    scanPatternEl.walkLayout(visitor)

  let text270Pos = float2(pos.x - strBox270.width.x, pos.y + size.y * 0.5 - data |> hdpx(4.))
  TextButton(text270Pos, text270, style).walkLayout(visitor)

  let text180pos = float2(pos.x + size.x * 0.5 - strBox180.width.x * 0.5, pos.y + size.y + bottomOffset)
  TextButton(text180pos, text180, style).walkLayout(visitor)

  let text90pos = float2(pos.x + size.x, pos.y + size.y * 0.5 - data |> hdpx(4.))
  TextButton(text90pos, text90, style).walkLayout(visitor)

  var velPos = float2(pos.x + size.x, pos.y + size.y * 0.5 + strBoxVel.width.y)
  if data.hasTxtBlock
    velPos = float2(pos.x - strBoxMode.width.x, pos.y + size.y + bottomOffset + strBoxMode.width.y + strBoxMeas.width.y + strBoxVel.width.y)
  var rangeEl = TextButton(velPos, textVel, style)
  rangeEl.onClickCallback <- @ <| ()
    Radar`changeRange()
  rangeEl.walkLayout(visitor)

  return float4(leftOffset, topOffset, rightOffset, bottomOffset)

def b_scope_background_tactical_map_aa_complex(var ctx : GuiContext&; rdata : ElemRenderData& const; data : CanvasParams&; scope_size : float2)
  let size = float2(min(rdata.size.x, rdata.size.y))
  let pos = rdata.pos
  let center = pos + size * 0.5
  let scopeToExtent =  rdata.size / scope_size
  let gradientSize = data |> hdpx(100.0)
  let delta = center - pos
  let maskSize = sqrt(delta.x * delta.x + delta.y * delta.y) - size.x * 0.5

  ctx |> set_viewport(pos.x, pos.y, pos.x + size.x, pos.y + size.y)
  render_tactical_map_background(ctx, center, size, get_radar_hud_has_distance_scale() ?  get_radar_hud_distance_max() * 1e3 * max(scopeToExtent.x, scopeToExtent.y) : 15000.0)
  let transparentVignetteColor = make_transparent_color(data.vignetteColor, 0.8)
  ctx |> render_ellipse_aa(center, size * 0.5 - float2(gradientSize * 0.5), gradientSize,
    transparentVignetteColor,
    transparentColor,
    transparentColor)
  ctx |> render_ellipse_aa(center, size * 0.5 + float2(maskSize * 0.5), maskSize,
    transparentVignetteColor,
    transparentColor)
  ctx |> render_rectangle_aa(pos, pos + size, 0.0, transparentColor, areaBackgroundColor)
  ctx |> restore_viewport()

def b_scope_background_aa_complex(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  let center = pos + size * 0.5
  ctx |> render_ellipse_aa(center, size * 0.5, data |> hdpx(1.6), data.color, transparentColor)
  let color = make_transparent_color(data.color, 0.3)
  if get_radar_hud_has_distance_scale()
    let n = 4
    for i in range(n)
      let r = 0.5 * float(i) / float(n)
      ctx |> render_ellipse_aa(center, size * r, data |> hdpx(1.2), color, transparentColor)

  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize/*hudFontHgt*/)

  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)
  ctx |> set_color(data.color)
  ctx |> set_draw_str_attr(FontFxType.FFT_GLOW, 0, 0, get_font_fx_color(data.color), get_font_fx_factor(data.color, data))

  let deg = loc("measureUnits/deg")

  let textOffset = data |> hdpx(3.0)

  let text0 = "0{deg}"
  let strBox0 = get_str_bbox(text0, text0 |> length(), fctx)
  ctx |> goto_xy(pos.x + size.x * 0.5 - strBox0.width.x * 0.5, pos.y + strBox0.width.y + textOffset)
  ctx |> draw_str_scaled(1.0, text0, text0 |> length())

  let text90 = "90{deg}"
  let strBox90 = get_str_bbox(text90, text90 |> length(), fctx)
  ctx |> goto_xy(pos.x + size.x - strBox90.width.x - textOffset, pos.y + size.y * 0.5 + strBox90.width.y * 0.5)
  ctx |> draw_str_scaled(1.0, text90, text90 |> length())

  let text180 = "180{deg}"
  let strBox180 = get_str_bbox(text180, text180 |> length(), fctx)
  ctx |> goto_xy(pos.x + size.x * 0.5 - strBox180.width.x * 0.5, pos.y + size.y - textOffset)
  ctx |> draw_str_scaled(1.0, text180, text180 |> length())

  let text270 = "270{deg}"
  let strBox270 = get_str_bbox(text270, text270 |> length(), fctx)
  ctx |> goto_xy(pos.x + textOffset, pos.y + size.y * 0.5 + strBox270.width.y * 0.5)
  ctx |> draw_str_scaled(1.0, text270, text270 |> length())

  let left = float2(pos.x + textOffset * 2.0 + strBox270.width.x, pos.y + size.y * 0.5)
  let right = float2(pos.x + size.x - textOffset * 2.0 - strBox90.width.x, pos.y + size.y * 0.5)
  let coordsHor <- to_array_move(fixed_array<float2>(left, right))
  ctx |> render_line_aa(coordsHor, false, data |> hdpx(1.2), float2(0, 0), color)

  let top = float2(pos.x + size.x * 0.5, pos.y + strBox0.width.y + textOffset * 2.0)
  let bottom = float2(pos.x + size.x * 0.5, pos.y + size.y - strBox180.width.y - textOffset * 2.0)
  let coordVert <- to_array_move(fixed_array<float2>(top, bottom))
  ctx |> render_line_aa(coordVert, false, data |> hdpx(1.2), float2(0, 0), color)

def b_scope_background(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  if data.isAAComplexMenuLayout
    b_scope_background_aa_complex(ctx, data, pos, size)
    return

  let center = pos + size * 0.5
  ctx |> render_ellipse_aa(center, size * 0.5, data |> hdpx(1.6), data.color, areaBackgroundColor)
  let color = is_color_or_white(data.color)
  if get_radar_hud_has_distance_scale()
    ctx |> render_ellipse_aa(center, size * 0.125, data |> hdpx(1.2), color, transparentColor)
    ctx |> render_ellipse_aa(center, size * 0.25, data |> hdpx(1.2), color, transparentColor)
    ctx |> render_ellipse_aa(center, size * 0.375, data |> hdpx(1.2), color, transparentColor)
  else
    ctx |> render_ellipse_aa(center, size * 0.45, data |> hdpx(1.2), color, transparentColor)

  let angle = PI / 6.
  for i in range(0, 12)
    let edge = center + float2(size.x * 0.5 * cos(float(i) * angle), size.x * 0.5 * sin(float(i) * angle))
    let coord <- to_array_move(fixed_array<float2>(center, edge))
    ctx |> render_line_aa(coord, false, data |> hdpx(1.2), float2(0, 0), color)

def b_scope_cue(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  if !get_radar_hud_cue_visible()
    return

  return if has_a_detected_target()

  let cueAzimuthHalfWidthRel = get_radar_hud_cue_azimuth_half_width_rel()
  let cueWidthRel = get_radar_hud_cue_dist_width_rel()
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  let cueAzimuth = get_radar_hud_cue_azimuth() * max(get_radar_hud_cue_reference_target_azimuth_width() - cueAzimuthHalfWidthRel * azimuthRange, 0.)
  let distRel = 0.5 * cueWidthRel + get_radar_hud_cue_distance() * get_radar_hud_target_distance() * (1. - cueWidthRel)
  let turretAzimuth = get_radar_hud_azimuth_min() + azimuthRange * get_radar_hud_cue_reference_turret_azimuth()
  let radiusMin = (distRel - cueWidthRel * 0.5) * 0.5
  let radiusMax = (distRel + cueWidthRel * 0.5) * 0.5
  let cueAzimuthMin = turretAzimuth + cueAzimuth - cueAzimuthHalfWidthRel * azimuthRange
  let cueAzimuthMax = turretAzimuth + cueAzimuth + cueAzimuthHalfWidthRel * azimuthRange

  let lcoord <- to_array_move(fixed_array<float2>(pos + float2(radiusMin * sin(cueAzimuthMin) * size.x, -radiusMin * cos(cueAzimuthMin) * size.y),
   pos + float2(radiusMax * sin(cueAzimuthMin) * size.x, -radiusMax * cos(cueAzimuthMin) * size.y)))
  ctx |> render_line_aa(lcoord, false, data |> hdpx(2.), float2(0, 0), data.color)
  let rcoord <- to_array_move(fixed_array<float2>(pos + float2(radiusMin * sin(cueAzimuthMax) * size.x, -radiusMin * cos(cueAzimuthMax) * size.y),
   pos + float2(radiusMax * sin(cueAzimuthMax) * size.x, -radiusMax * cos(cueAzimuthMax) * size.y)))
  ctx |> render_line_aa(rcoord, false, data |> hdpx(2.), float2(0, 0), data.color)


struct CScopeMain : RadarInteractableEll
  def CScopeMain(pos, size : float2; in_params : CanvasParams&)
    RadarInteractableEll`RadarInteractableEll(self, pos, size, in_params)

  def override walkLayout(var visitor : InteractableVisitor&)
    InteractableCanvasEll`walkLayout(self, visitor)

    let curretOffset = self.size.x * 0.01
    let curretWidth = *self.data |> hdpx(20.0)

    let offsets = c_scope_markers(visitor, *self.data, self.pos, self.size - float2(0.0, curretWidth + curretOffset))

    let centerElemPos = self.pos + offsets
    let centerElemSize = self.size - offsets

    let targetElSize = centerElemSize - float2(curretOffset + curretWidth)
    var targetsEl = CScopeCenterFrame(centerElemPos, targetElSize, *self.data)
    targetsEl.walkLayout(visitor)

    let elevationCurretSize = float2(curretWidth, targetElSize.y)
    let elevationCurretPos = float2(pos.x + size.x - curretWidth, centerElemPos.y)
    var elevationCurret = CScopeElevationCurret(elevationCurretPos, elevationCurretSize, *self.data)
    elevationCurret.walkLayout(visitor)

    let azimuthCurretSize = float2(targetElSize.x, curretWidth)
    let azimuthCurretPos = float2(centerElemPos.x, centerElemPos.y + targetElSize.y + curretOffset)
    var azimuthCurret = CScopeAzimuthCurret(azimuthCurretPos, azimuthCurretSize, *self.data)
    azimuthCurret.walkLayout(visitor)

struct CScopeCenterFrame : InteractableButton
  data : CanvasParams const? = null

  def CScopeCenterFrame(pos, size : float2; in_params : CanvasParams&)
    InteractableButton`InteractableButton(self, pos, size)
    data = unsafe(addr(in_params))

  [unused_argument(rdata, rstate)] def override draw(var ctx : GuiContext &; rdata : ElemRenderData & const; rstate : RenderState & const)
    c_scope(ctx, *self.data, self.pos, self.size)

  def override onClick(rel_pos : float2)
    let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
    let azimuthRangeInv = azimuthRange != 0. ? 1. / azimuthRange : 1.
    var scanAzimuthMaxRel = get_radar_hud_scan_azimuth_max() * azimuthRangeInv
    var scanAzimuthMinRel = get_radar_hud_scan_azimuth_min() * azimuthRangeInv
    if scanAzimuthMaxRel < scanAzimuthMinRel
      scanAzimuthMinRel = -0.5
      scanAzimuthMaxRel =  0.5

    let scanAzimuthMinRel0 = scanAzimuthMinRel
    let scanAzimuthRange0 = scanAzimuthMaxRel - scanAzimuthMinRel

    let scanZoneAzimuthSizeMult = min((1.0 - scanZoneSizeRelReq) / (1.0 - scanAzimuthMaxRel + scanAzimuthMinRel), 1.0)
    scanAzimuthMinRel = -0.5 + (scanAzimuthMinRel + 0.5) * scanZoneAzimuthSizeMult
    scanAzimuthMaxRel =  0.5 - (0.5 - scanAzimuthMaxRel) * scanZoneAzimuthSizeMult

    let azimuthConvMult = (scanAzimuthMaxRel - scanAzimuthMinRel) / scanAzimuthRange0
    let azimuthConvAdd = (-0.5 - scanAzimuthMinRel0) * azimuthConvMult + scanAzimuthMinRel + 0.5

    let dist = -1.0
    let azimuthRel = (rel_pos.x - azimuthConvAdd) / azimuthConvMult
    let azimuth = lerp(get_radar_hud_azimuth_min(), get_radar_hud_azimuth_max(), azimuthRel)
    set_radar_cue_pos(azimuth, dist)

  [unused_argument(pos)] def override onDoubleClick(pos : float2)
    var fcm = get_flight_control_mode()
    fcm.ctrlMap |> onSensorTargetLock()


struct CScopeElevationCurret : InteractableButton
  data : CanvasParams const? = null

  def CScopeElevationCurret(pos, size : float2; in_params : CanvasParams&)
    InteractableButton`InteractableButton(self, pos, size)
    data = unsafe(addr(in_params))

  [unused_argument(rdata, rstate)] def override draw(var ctx : GuiContext &; rdata : ElemRenderData & const; rstate : RenderState & const)
    InteractableCanvasEll`draw(self, ctx, rdata, rstate)

    var color = float4(Color4(is_color_or_white(data.color)))
    color *= 0.42
    let e3dColorGrid = E3DCOLOR(Color4(color))
    ctx |> set_color(e3dColorGrid)

    let scanElevationMaxRel = cvt(get_radar_hud_scan_elevation_max() + get_radar_hud_elevation_half_width(), get_radar_hud_elevation_min(), get_radar_hud_elevation_max(), 0.0, 1.0)
    let scanElevationMinRel = cvt(get_radar_hud_scan_elevation_min() - get_radar_hud_elevation_half_width(), get_radar_hud_elevation_min(), get_radar_hud_elevation_max(), 0.0, 1.0)

    let elevationLineX = self.pos.x + self.size.x * 0.5
    let elTEdge = float2(elevationLineX, self.pos.y)
    let elBEdge = float2(elevationLineX, self.pos.y + self.size.y)

    ctx |> draw_line(elevationLineX, lerp(elBEdge.y, elTEdge.y, scanElevationMaxRel),
      elevationLineX, lerp(elBEdge.y, elTEdge.y, scanElevationMinRel), *self.data |> hdpx(4.0))

  [unused_argument(start_pos_rel)] def override onPress(start_pos_rel, cur_pos_rel : float2)
    let targetElevation = lerp(get_radar_hud_elevation_max(), get_radar_hud_elevation_min(), cur_pos_rel.y)
    set_radar_elevation(targetElevation)


struct CScopeAzimuthCurret : InteractableButton
  data : CanvasParams const? = null

  def CScopeAzimuthCurret(pos, size : float2; in_params : CanvasParams&)
    InteractableButton`InteractableButton(self, pos, size)
    data = unsafe(addr(in_params))

  [unused_argument(rdata, rstate)] def override draw(var ctx : GuiContext &; rdata : ElemRenderData & const; rstate : RenderState & const)
    InteractableCanvasEll`draw(self, ctx, rdata, rstate)

    var color = float4(Color4(is_color_or_white(data.color)))
    color *= 0.42
    let e3dColorGrid = E3DCOLOR(Color4(color))
    ctx |> set_color(e3dColorGrid)

    let scanAzimuthMaxRel = cvt(get_radar_hud_scan_azimuth_max() + get_radar_hud_azimuth_half_width(), get_radar_hud_azimuth_min(), get_radar_hud_azimuth_max(), 0.0, 1.0)
    let scanAzimuthMinRel = cvt(get_radar_hud_scan_azimuth_min() - get_radar_hud_azimuth_half_width(), get_radar_hud_azimuth_min(), get_radar_hud_azimuth_max(), 0.0, 1.0)

    let azimuthLineY = self.pos.y + self.size.y * 0.5

    let azLEdge = float2(self.pos.x, azimuthLineY)
    let azREdge = float2(self.pos.x + self.size.x, azimuthLineY)

    ctx |> draw_line(lerp(azLEdge.x, azREdge.x, scanAzimuthMinRel), azimuthLineY,
      lerp(azLEdge.x, azREdge.x, scanAzimuthMaxRel), azimuthLineY, *data |> hdpx(4.0))

    if get_radar_hud_cue_visible() && !has_a_detected_target()
      let azimuthHalfWidth = get_radar_hud_cue_azimuth_half_width_rel()
      let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
      let cueAzimuth = get_radar_hud_cue_azimuth() * max(get_radar_hud_target_azimuth_width() / azimuthRange - get_radar_hud_cue_azimuth_half_width_rel(), 0.0)
      let cueAzimuthLeft = cueAzimuth - azimuthHalfWidth
      let cueAzimuthRight = cueAzimuth + azimuthHalfWidth
      ctx |> draw_line(self.pos.x + (0.5 + cueAzimuthLeft) * self.size.x, azimuthLineY,
        self.pos.x + (0.5 + cueAzimuthRight) * self.size.x, azimuthLineY, *self.data |> hdpx(8.0))

  [unused_argument(start_pos_rel)] def override onPress(start_pos_rel, cur_pos_rel : float2)
    let dist = -1.0
    let azimuth = lerp(get_radar_hud_azimuth_min(), get_radar_hud_azimuth_max(), clamp(cur_pos_rel.x, 0.0, 1.0))
    set_radar_cue_pos(azimuth, dist)

def c_scope(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  c_scope_background(ctx, data, pos, size)
  if get_radar_hud_is_visible() && get_radar_hud_is_emitting()
    c_scope_azimuth(ctx, data, pos, size, get_radar_hud_azimuth(), get_radar_hud_elevation(), get_radar_hud_azimuth_half_width(), get_radar_hud_elevation_half_width())
    foreach_additional_beams() <| $(var additionalBeam)
      c_scope_azimuth(ctx, data, pos, size, additionalBeam.azimuth, additionalBeam.elevation, get_radar_hud_azimuth_half_width(), get_radar_hud_elevation_half_width())
  if get_radar_hud_is_visible2() && get_radar_hud_is_emitting2()
    c_scope_azimuth(ctx, data, pos, size, get_radar_hud_azimuth2(), get_radar_hud_elevation2(), get_radar_hud_azimuth_half_width2(), get_radar_hud_elevation_half_width2())
  c_scope_targets(ctx, data, pos, size)
  c_scope_cue(ctx, data, pos, size)
  c_scope_inner_labels(ctx, data, pos, size)

def c_scope_markers(var visitor : InteractableVisitor&; data : CanvasParams&; pos : float2; size : float2)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize/*hudFontHgt*/)
  var topOffset = 0.

  var style = TextButtonStyle()
  style.color = data.color
  style.fontId = data.fontId
  style.fontSize = data.fontSize
  style.glowColor =  get_font_fx_color(data.color)
  style.glowFxFactor =  get_font_fx_factor(data.color, data)
  style.anchorHorz = AnchorHorz.Left
  style.anchorVert = AnchorVert.Bottom

  let deg = loc("measureUnits/deg")

  let textElevMax = fmt(":.0f", floor(rad_to_deg(get_radar_hud_elevation_max()) + 0.5)) + deg
  let strBoxElMax = get_str_bbox(textElevMax, textElevMax |> length(), fctx)
  let textElevMin = fmt(":.0f", floor(rad_to_deg(get_radar_hud_elevation_min()) + 0.5)) + deg
  let strBoxElMin = get_str_bbox(textElevMin, textElevMin |> length(), fctx)
  let textElev0 = "0{deg}"
  let strBoxEl0 = get_str_bbox(textElev0, textElev0 |> length(), fctx)
  let leftOffset = max(strBoxElMax.width.x, max(strBoxElMin.width.x, strBoxEl0.width.x))

  if !get_radar_hud_is_b_scope_visible()
    var textScanRange = ""
    var textVel = ""
    if get_radar_hud_has_azimuth_scale() && get_radar_hud_scan_azimuth_max() > get_radar_hud_scan_azimuth_min()
      let azText = fmt(":.0f", floor(rad_to_deg(get_radar_hud_scan_azimuth_max() - get_radar_hud_scan_azimuth_min()) + 0.5))
      let elText = fmt(":.0f", floor(rad_to_deg(get_radar_hud_scan_elevation_max() - get_radar_hud_scan_elevation_min()) + 0.5))
      textScanRange = "{azText}{deg}x{elText}{deg}" + (get_radar_hud_scan_patterns_max() > 1 ? "*" : "")
      let strBoxScan = get_str_bbox(textScanRange, textScanRange |> length(), fctx)
      topOffset = strBoxScan.width.y

    if get_radar_hud_has_distance_scale()
      let distText = (get_radar_hud_velocity_search() ? get_measure_units_text(MeasureUnitsTypes.MEASURE_UNIT_SPEED, get_radar_hud_distance_max(), true, 1.) :
       get_measure_units_text(MeasureUnitsTypes.MEASURE_UNIT_DIST, get_radar_hud_distance_max() * 1000., true, 1.))
      textVel = distText + (get_radar_hud_distance_scale_max() > 1 ? "*" : "")
      let strBoxVel = get_str_bbox(textVel, textVel |> length(), fctx)
      topOffset = max(topOffset, strBoxVel.width.y)

    let modeName = Radar`getModeNameLoc(data.radarModeNameLangId)
    let strBoxMode = get_str_bbox(modeName, modeName |> length(), fctx)
    topOffset = max(strBoxMode.width.y, topOffset)

    let name2Id = get_radar_hud_mode_name2_id()
    let defaultStr2 = get_radar_hud_is_visible2() ? (get_radar_hud_is_irst() ? "hud/irst" : "hud/radarEmitting") : ""
    let modeName2 = loc(name2Id >= 0 && name2Id < radarModeNames |> length() ? radarModeNames[name2Id] : defaultStr2)
    let strBoxMode2 = get_str_bbox(modeName2, modeName2 |> length(), fctx)
    topOffset += strBoxMode2.width.y

    if textScanRange |> length() > 0
      let p = float2(pos.x + leftOffset, pos.y + topOffset)
      var scanRangeEl = TextButton(p, textScanRange, style)
      scanRangeEl.onClickCallback <- @ <| ()
        Radar`changeScanPattern()
      scanRangeEl.walkLayout(visitor)

    if textVel |> length() > 0
      var s := style
      s.anchorHorz = AnchorHorz.Right
      let p = float2(pos.x + size.x, pos.y + topOffset)
      var velEl = TextButton(p, textVel, s)
      velEl.walkLayout(visitor)

    let modePos = float2(pos.x + (size.x - leftOffset) * 0.5, pos.y + topOffset)
    var modeNameEl = TextButton(modePos, modeName, style)
    modeNameEl.onClickCallback <- @ <| ()
      Radar`changeMode()
    modeNameEl.walkLayout(visitor)

    var s := style
    s.anchorVert = AnchorVert.Top
    let modeName2Pos = float2(pos.x + (size.x - leftOffset) * 0.5, pos.y + topOffset)
    var modeName2El = TextButton(modeName2Pos, modeName2, s)
    modeName2El.walkLayout(visitor)

  topOffset += data |> hdpx(4.)

  var s := style
  s.anchorHorz = AnchorHorz.Right
  s.anchorVert = AnchorVert.Bottom
  let elevationMaxPos = float2(pos.x + leftOffset, pos.y + topOffset)
  var elevationMaxEl = TextButton(elevationMaxPos, textElevMax, s)
  elevationMaxEl.walkLayout(visitor)

  s.anchorVert = AnchorVert.Bottom
  let elevationMinPos = float2(pos.x + leftOffset, pos.y + size.y)
  var elevationMinEl = TextButton(elevationMinPos, textElevMin, s)
  elevationMinEl.walkLayout(visitor)

  s.anchorVert = AnchorVert.Center
  let elY = cvt(0.0, get_radar_hud_elevation_min(), get_radar_hud_elevation_max(), elevationMinPos.y, elevationMaxPos.y)
  let zeroElevationPos = float2(pos.x + leftOffset, elY)
  var zeroElevationEl = TextButton(zeroElevationPos, textElev0, s)
  zeroElevationEl.walkLayout(visitor)

  return float2(leftOffset + data |> hdpx(4.), topOffset)

let scanZoneSizeRelReq = 0.8
def c_scope_convert_azimuth(size : float2; pos : float2; azimuth_rel : float)
  let scanAzimuthMaxRel =  cvt(get_radar_hud_scan_azimuth_max() + get_radar_hud_azimuth_half_width(), get_radar_hud_azimuth_min(), get_radar_hud_azimuth_max(), 0.0, 1.0)
  let scanAzimuthMinRel =  cvt(get_radar_hud_scan_azimuth_min() - get_radar_hud_azimuth_half_width(), get_radar_hud_azimuth_min(), get_radar_hud_azimuth_max(), 0.0, 1.0)

  let scanAzimuthMidRel = (scanAzimuthMaxRel + scanAzimuthMinRel) * 0.5
  let scanAzRangeRel = scanAzimuthMaxRel - scanAzimuthMinRel
  let scanAzHalfRangeRel = scanAzRangeRel * 0.5


  let screenAzimuthT = cvt(scanAzimuthMidRel, scanAzHalfRangeRel, 1.0 - scanAzHalfRangeRel, 0.0, 1.0)
  let screenAzimuthBotRel = lerp(0.0, clamp(1.0 - scanAzRangeRel / scanZoneSizeRelReq, 0.0, 1.0), screenAzimuthT)
  let screenAzimuthTopRel = lerp(clamp(scanAzRangeRel / scanZoneSizeRelReq, 0.0, 1.0), 1.0, screenAzimuthT)

  let resultAzimuth = cvt(azimuth_rel, screenAzimuthBotRel, screenAzimuthTopRel, pos.x, pos.x + size.x)
  return resultAzimuth

def c_scope_convert_pos(size : float2; pos : float2; azimuth_rel : float; elevation_rel : float)
  let scanElevationMaxRel =  cvt(get_radar_hud_scan_elevation_max() + get_radar_hud_elevation_half_width(), get_radar_hud_elevation_min(), get_radar_hud_elevation_max(), 0.0, 1.0)
  let scanElevationMinRel =  cvt(get_radar_hud_scan_elevation_min() - get_radar_hud_elevation_half_width(), get_radar_hud_elevation_min(), get_radar_hud_elevation_max(), 0.0, 1.0)

  let scanElevationMidRel = (scanElevationMaxRel + scanElevationMinRel) * 0.5
  let scanElRangeRel = scanElevationMaxRel - scanElevationMinRel
  let scanElHalfRangeRel = scanElRangeRel * 0.5

  let screenElevationT = cvt(scanElevationMidRel, scanElHalfRangeRel, 1.0 - scanElHalfRangeRel, 0.0, 1.0)
  let screenElevationBotRel = lerp(0.0, clamp(1.0 - scanElRangeRel / scanZoneSizeRelReq, 0.0, 1.0), screenElevationT)
  let screenElevationTopRel = lerp(clamp(scanElRangeRel / scanZoneSizeRelReq, 0.0, 1.0), 1.0, screenElevationT)

  let resultElevation = cvt(elevation_rel, screenElevationBotRel, screenElevationTopRel, pos.y + size.y, pos.y)

  let resultAzimuth = c_scope_convert_azimuth(size, pos, azimuth_rel)
  return float2(resultAzimuth, resultElevation)

def c_scope_background(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  ctx |> set_viewport(pos.x, pos.y, pos.x + size.x, pos.y + size.y)

  ctx |> set_color(areaBackgroundColor)
  let tc = float2(0., 0.)
  let rb = pos + size
  ctx |> render_rect(pos.x, pos.y, rb.x, rb.y, tc, tc, tc)
  ctx |> set_color(data.color)
  ctx |> render_frame(pos.x, pos.y, pos.x + size.x, pos.y + size.y, data |> hdpx(1.8))

  var color = float4(Color4(is_color_or_white(data.color)))
  color *= 0.62
  let e3dColor = E3DCOLOR(Color4(color))
  ctx |> set_color(e3dColor)
  ctx |> draw_line(pos.x + size.x * 0.5, pos.y, pos.x + size.x * 0.5, pos.y + size.y, data |> hdpx(1.0))
  let elevationRange = max(0., get_radar_hud_elevation_max() - get_radar_hud_elevation_min())
  let elevationRangeInv = elevationRange != 0. ? 1. / elevationRange : 1.
  let elRange = (1. + get_radar_hud_elevation_min() * elevationRangeInv) * size.y
  ctx |> draw_line(pos.x, pos.y + elRange, pos.x + size.x, pos.y + elRange, data |> hdpx(1.0))

  color = float4(Color4(is_color_or_white(data.color)))
  color *= 0.42
  let e3dColorGrid = E3DCOLOR(Color4(color))
  ctx |> set_color(e3dColorGrid)

  let scanAzimuthMaxRel = cvt(get_radar_hud_scan_azimuth_max() + get_radar_hud_azimuth_half_width(), get_radar_hud_azimuth_min(), get_radar_hud_azimuth_max(), 0.0, 1.0)
  let scanAzimuthMinRel = cvt(get_radar_hud_scan_azimuth_min() - get_radar_hud_azimuth_half_width(), get_radar_hud_azimuth_min(), get_radar_hud_azimuth_max(), 0.0, 1.0)
  let scanElevationMaxRel = cvt(get_radar_hud_scan_elevation_max() + get_radar_hud_elevation_half_width(), get_radar_hud_elevation_min(), get_radar_hud_elevation_max(), 0.0, 1.0)
  let scanElevationMinRel = cvt(get_radar_hud_scan_elevation_min() - get_radar_hud_elevation_half_width(), get_radar_hud_elevation_min(), get_radar_hud_elevation_max(), 0.0, 1.0)

  let scanLT = c_scope_convert_pos(size, pos, scanAzimuthMinRel, scanElevationMinRel)
  let scanRB = c_scope_convert_pos(size, pos, scanAzimuthMaxRel, scanElevationMaxRel)

  let markSizeRadians = PI / 12.0

  let azimuthScanRange = max(0.0, get_radar_hud_scan_azimuth_max() - get_radar_hud_scan_azimuth_min())
  let azimuthScanRangeInv = azimuthScanRange != 0. ? 1. / azimuthScanRange : 1.
  if azimuthScanRange != 0.
    let markSizeRel = markSizeRadians * azimuthScanRangeInv
    let N = floori(safediv(1.0, markSizeRel))
    for i in range(1, N + 1)
      let t = markSizeRel * float(i)
      if t > 0.99
        break
      let x = lerp(scanLT.x, scanRB.x, t)
      let p1 = float2(x, scanLT.y)
      let p2 = float2(x, scanRB.Y)
      ctx |> render_line_dashed(p1, p2, data |> hdpx(2.0),  data |> hdpx(2.0),  data |> hdpx(1.0), data.color)

  let elevationScanRange = max(0.0, get_radar_hud_scan_elevation_max() - get_radar_hud_scan_elevation_min())
  let elevationScanRangeInv = elevationScanRange != 0. ? 1. / elevationScanRange : 1.
  if elevationScanRange != 0.
    let markSizeRel = markSizeRadians * elevationScanRangeInv
    let N = floori(safediv(1.0, markSizeRel))
    for i in range(1, N + 1)
      let t = markSizeRel * float(i)
      if t > 0.99
        break
      let y = lerp(scanLT.y, scanRB.y, t)
      let p1 = float2(scanLT.x, y)
      let p2 = float2(scanRB.x, y)
      ctx |> render_line_dashed(p1, p2, data |> hdpx(2.0),  data |> hdpx(2.0),  data |> hdpx(1.0), data.color)

  ctx |> set_color(e3dColor)
  ctx |> render_frame(scanLT.x, scanLT.y, scanRB.x, scanRB.y, data |> hdpx(3.2))

  ctx |> restore_viewport()

def c_scope_azimuth(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2; azimuth : float; elevation : float;
                    half_azimuth : float; half_elevation : float)
  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  let elevationRange = max(0., get_radar_hud_elevation_max() - get_radar_hud_elevation_min())

  let halfAzimuthWidthRel = azimuthRange > 0. ? half_azimuth / azimuthRange : 0.
  let halfElevationWidthRel = elevationRange > 0. ? half_elevation / elevationRange : 0.

  let lt = c_scope_convert_pos(size, pos, azimuth - halfAzimuthWidthRel, elevation - halfElevationWidthRel)
  let rb = c_scope_convert_pos(size, pos, azimuth + halfAzimuthWidthRel, elevation + halfElevationWidthRel)

  var color = float4(Color4(is_color_or_white(data.color)))
  color *= 0.6
  let e3dColor = E3DCOLOR(Color4(color))
  ctx |> set_color(e3dColor)
  let azimuthMark <- to_array_move(fixed_array(
    float2(lt.x, lt.y),
    float2(rb.x, lt.y),
    float2(rb.x, rb.y),
    float2(lt.x, rb.y)))
  ctx |> render_poly(azimuthMark, e3dColor)
  ctx |> render_line_aa(azimuthMark, true, data |> hdpx(1.2), float2(0., 0.), data.color)

def c_scope_targets(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  ctx |> set_viewport(pos.x, pos.y, pos.x + size.x, pos.y + size.y)

  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  let azimuthRangeInv = azimuthRange != 0. ? 1. / azimuthRange : 1.
  let elevationRange = max(0., get_radar_hud_elevation_max() - get_radar_hud_elevation_min())
  let elevationRangeInv = elevationRange != 0. ? 1. / elevationRange : 1.

  Radar`foreach_targets() <| $(var target; i)
    return if !target.isVisible

    let azimuthRel = clamp(target.azimuthRel, 0.0, 1.0)
    let azimuth = get_radar_hud_has_azimuth_scale() ? azimuthRel : 0.
    let azimuthLeft = azimuth - target.azimuthWidthRel * 0.5
    let azimuthRight = azimuth + target.azimuthWidthRel * 0.5

    let elevationRel = clamp(target.elevationRel, 0.0, 1.0)
    let elevationLowerRel = elevationRel - target.elevationWidthRel * 0.5
    let elevationUpperRel = elevationRel + target.elevationWidthRel * 0.5

    var inSelectedTargetRangeGate = false
    if get_radar_hud_has_distance_scale()
      if !get_radar_hud_cue_visible()
        if !target.isDetected
          Radar`foreach_targets() <| $(var second_target; j)
            if i != j && second_target.isDetected && abs(target.distanceRel - second_target.distanceRel) < 0.05
              inSelectedTargetRangeGate = true
              return
      else
        inSelectedTargetRangeGate = abs(target.distanceRel - get_radar_hud_cue_distance() * get_radar_hud_target_distance()) < 0.5 * get_radar_hud_cue_dist_width_rel()
    else
      inSelectedTargetRangeGate = true

    if !inSelectedTargetRangeGate
      return

    let signalRel = target.signalRel < 0.01 ? 0. : cvt(target.signalRel, 0.05, 1., 0.3, 1.)
    var color = float4(Color4(is_color_or_white(data.color)))
    color *= (1. - target.ageRel) * signalRel
    let e3dColor = E3DCOLOR(Color4(color))
    ctx |> set_color(e3dColor)

    let tc = float2(0., 0.)
    let lt = c_scope_convert_pos(size, pos, azimuthLeft, elevationLowerRel)
    let rt = c_scope_convert_pos(size, pos, azimuthRight, elevationUpperRel)
    ctx |> render_rect(lt.x, lt.y, rt.x, rt.y, tc, tc, tc)

    let azimuthGateWidthRel = angularGateWidthMultSquare * 2. * max(get_radar_hud_azimuth_half_width(), angularGateBeamWidthMin) * azimuthRangeInv
    let elevationGateWidthRel = angularGateWidthMultSquare * 2. * max(get_radar_hud_elevation_half_width(), angularGateBeamWidthMin) * elevationRangeInv

    let gateLT = c_scope_convert_pos(size, pos, azimuth - 0.5 * azimuthGateWidthRel, elevationRel - 0.5 * elevationGateWidthRel)
    let gateRB = c_scope_convert_pos(size, pos, azimuth + 0.5 * azimuthGateWidthRel, elevationRel + 0.5 * elevationGateWidthRel)

    if target.isDetected || target.isSelected
      let lcoord <- to_array_move(fixed_array<float2>(float2(gateLT.x, gateRB.y),
        float2(gateLT.x, gateLT.y)))
      ctx |> render_line_aa(lcoord, false, data |> hdpx(3.), float2(0, 0), e3dColor)
      let rcoord <- to_array_move(fixed_array<float2>(float2(gateRB.x, gateRB.y),
        float2(gateRB.x, gateLT.y)))
      ctx |> render_line_aa(rcoord, false, data |> hdpx(3.), float2(0, 0), e3dColor)
    if target.isSelected //animation ?
      let bcoord <- to_array_move(fixed_array<float2>(float2(gateLT.x, gateRB.y),
        float2(gateRB.x, gateRB.y)))
      ctx |> render_line_aa(bcoord, false, data |> hdpx(3.), float2(0, 0), e3dColor)
      let tcoord <- to_array_move(fixed_array<float2>(float2(gateLT.x, gateLT.y),
        float2(gateRB.x, gateLT.y)))
      ctx |> render_line_aa(tcoord, false, data |> hdpx(3.), float2(0, 0), e3dColor)

  ctx |> restore_viewport()

def c_scope_cue(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  if !get_radar_hud_cue_visible()
    return

  return if has_a_detected_target()

  let azimuthRange = max(0., get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
  let azimuthHalfWidth = get_radar_hud_cue_azimuth_half_width_rel()
  let cueAzimuth = get_radar_hud_cue_azimuth() * max(get_radar_hud_target_azimuth_width() / azimuthRange - get_radar_hud_cue_azimuth_half_width_rel(), 0.0)
  let cueAzimuthLeft = cueAzimuth - azimuthHalfWidth
  let cueAzimuthRight = cueAzimuth + azimuthHalfWidth

  let cueAzLeftRel = cvt(cueAzimuthLeft, -0.5, 0.5, 0.0, 1.0)
  let cueAzRightRel = cvt(cueAzimuthRight, -0.5, 0.5, 0.0, 1.0)

  let lt = float2(c_scope_convert_azimuth(size, pos, cueAzLeftRel), pos.y)
  let rb = float2(c_scope_convert_azimuth(size, pos, cueAzRightRel), pos.y + size.y)
  ctx |> set_color(data.color)
  ctx |> draw_line(lt.x, lt.y, lt.x, rb.y, 2.)
  ctx |> draw_line(rb.x, lt.y, rb.x, rb.y, 2.)

def c_scope_inner_labels(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize/*hudFontHgt*/)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)
  ctx |> set_color(data.color)
  ctx |> set_draw_str_attr(FontFxType.FFT_GLOW, 0, 0, get_font_fx_color(data.color), get_font_fx_factor(data.color, data))

  let azMinText = fmt(":.0f", floor(rad_to_deg(get_radar_hud_azimuth_min()) + 0.5)) + loc("measureUnits/deg")
  let strBoxAzMin = get_str_bbox(azMinText, azMinText |> length(), fctx)
  ctx |> goto_xy(pos.x + data |> hdpx(4.), pos.y + strBoxAzMin.width.y + data |> hdpx(4.))
  ctx |> draw_str_scaled(1.0, azMinText, azMinText |> length())

  let azMaxText = fmt(":.0f", floor(rad_to_deg(get_radar_hud_azimuth_max()) + 0.5)) + loc("measureUnits/deg")
  let strBoxAzMax = get_str_bbox(azMaxText, azMaxText |> length(), fctx)
  ctx |> goto_xy(pos.x + size.x - strBoxAzMax.width.x - data |> hdpx(4.), pos.y + strBoxAzMax.width.y + data |> hdpx(4.))
  ctx |> draw_str_scaled(1.0, azMaxText, azMaxText |> length())

def b_scope_square_aviahorizont(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed
    return
  let fmw = hero |> as_fmw()
  if fmw == null
    return

  ctx |> setRotViewTm(pos.x + size.x * 0.5, pos.y + size.y * 0.5, deg_to_rad(fmw.roll), 0., false)

  let linePtsLeft <- to_array_move(fixed_array(
    float2(pos.x + size.x * 0.2, pos.y + size.y * 0.52),
    float2(pos.x + size.x * 0.2, pos.y + size.y * 0.5),
    float2(pos.x + size.x * 0.45, pos.y + size.y * 0.5)))

  let linePtsRight <- to_array_move(fixed_array(
    float2(pos.x + size.x * 0.8, pos.y + size.y * 0.52),
    float2(pos.x + size.x * 0.8, pos.y + size.y * 0.5),
    float2(pos.x + size.x * 0.55, pos.y + size.y * 0.5)))

  ctx |> render_line_aa(linePtsLeft, false, 2.0 * data.lineWidth, float2(0., 0.), data.lineColor)
  ctx |> render_line_aa(linePtsRight, false, 2.0 * data.lineWidth, float2(0., 0.), data.lineColor)

  ctx |> resetViewTm()

def draw_additional_net(var ctx : GuiContext&; data : CanvasParams&; pos : float2; size : float2)
  if data.netRowCnt <= 0
    return
  ctx |> set_color(data.netColor)
  ctx |> render_frame(pos.x, pos.y, pos.x + size.x, pos.y + size.y, data |> hdpx(1.8 * data.lineWidth))

  for i in range(1, data.netRowCnt)
    if data.netRowCnt % 2 == 0 && i == data.netRowCnt / 2
      ctx |> draw_line(pos.x + float(i) / float(data.netRowCnt) * size.x, pos.y, pos.x + float(i) / float(data.netRowCnt) * size.x, pos.y + size.y * 0.4, 3. * data.lineWidth)
      ctx |> draw_line(pos.x + float(i) / float(data.netRowCnt) * size.x, pos.y + size.y * 0.6, pos.x + float(i) / float(data.netRowCnt) * size.x, pos.y + size.y, 3. * data.lineWidth)
    else
      ctx |> draw_line(pos.x + float(i) / float(data.netRowCnt) * size.x, pos.y, pos.x + float(i) / float(data.netRowCnt) * size.x, pos.y + size.y, 3. * data.lineWidth)
    if data.netRowCnt % 2 == 0 && i == data.netRowCnt / 2
      ctx |> draw_line(pos.x, pos.y + float(i) / float(data.netRowCnt) * size.y, pos.x + size.x * 0.4, pos.y + float(i) / float(data.netRowCnt) * size.y, 3. * data.lineWidth)
      ctx |> draw_line(pos.x + size.x * 0.6, pos.y + float(i) / float(data.netRowCnt) * size.y, pos.x + size.x, pos.y + float(i) / float(data.netRowCnt) * size.y, 3. * data.lineWidth)
    else
      ctx |> draw_line(pos.x, pos.y + float(i) / float(data.netRowCnt) * size.y, pos.x + size.x, pos.y + float(i) / float(data.netRowCnt) * size.y, 3. * data.lineWidth)

struct IFFFilterButton : InteractableButton
  data : CanvasParams const? = null

  def IFFFilterButton(pos, size : float2; in_params : CanvasParams&)
    InteractableButton`InteractableButton(self, pos, size)
    data = unsafe(addr(in_params))

    setActive(get_air_radar_control_mode() == AirRadarControlMode.HIDDEN)

  [unused_argument(rdata, rstate)] def override draw(var ctx : GuiContext &; rdata : ElemRenderData & const; rstate : RenderState & const)
    let targetHalfSize = size * float2(0.9, 0.3) * 0.5

    let currFilter = get_radar_iff_filter()
    if currFilter == int(RadarTargetsIffFilterMask.ALLY)
      let c = pos + size * 0.5
      drawTarget(c, targetHalfSize, true, ctx)
    elif currFilter == int(RadarTargetsIffFilterMask.ENEMY)
      let c = pos + size * 0.5
      drawTarget(c, targetHalfSize, false, ctx)
    else
      let c1 = pos + float2(size.x * 0.5, size.y * 0.3)
      drawTarget(c1, targetHalfSize, true, ctx)

      let c2 = pos + float2(size.x * 0.5, size.y * 0.8)
      drawTarget(c2, targetHalfSize, false, ctx)

  [unused_argument(rel_pos)] def override onClick(rel_pos : float2)
    set_next_radar_iff_filter()

  def override onDoubleClick(rel_pos : float2)
    onClick(rel_pos)

  def drawTarget(pos, targetHalfSize : float2; friendly : bool; var ctx : GuiContext&)
    let tc = float2(0., 0.)
    let friendlyOffset = size.y * 0.07
    let friendlyHeight = size.y * 0.1

    let lt = pos - targetHalfSize
    let rb = pos + targetHalfSize
    ctx |> render_rect(lt.x, lt.y, rb.x, rb.y, tc, tc, tc)

    if (friendly)
      ctx |> render_rect(lt.x, lt.y - friendlyOffset - friendlyHeight, rb.x, lt.y - friendlyOffset, tc, tc, tc)
