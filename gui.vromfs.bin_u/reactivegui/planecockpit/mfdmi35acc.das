require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.helpers_common
require %rGui.utils.hsd_common
require %rGui.utils.weaponslots_common
require %rGui.utils.radar_common

require app
require DagorMath
require DagorStdGuiRender
require DagorSystem
require DagorTime
require darg
require FlightControl
require FlightModelWrap
require HeroManager
require math
require %dasGameLibs.math.base
require RadarHud
require Plane
require Sensors
require strings
require Unit
require Weapon
require hud
require WTCamera

enum ArrowType
  simple
  large
  small
  thin


struct Colors
  green  = E3DCOLOR(0xFF_00FF00)
  empty  = E3DCOLOR(0x00_000000)
  pink  = E3DCOLOR(0xFF_FF9ACC)
  lightBlue  = E3DCOLOR(0xFF_CCFFFF)


def rad_to_deg(rad : float)
  return rad * 180.0 / PI

def circle_value(var value : int) : string
  if value >= 360
    value -= 360
  if value < 0
    value += 360
  if value == 0
    return "N"
  if value == 90
    return "E"
  if value == 180
    return "S"
  if value == 270
    return "W"
  return "{value / 10}"


struct PropStorage
  fontId : int
  english : bool

struct Shapes
  simpleArrowPoints <- fixed_array(
    float2(-0.1, 0.8),
    float2(0.0, 1.0),
    float2(0.1, 0.8),
    float2(0.1000, -0.0000),
    float2(0.0951, -0.0309),
    float2(0.0809, -0.0588),
    float2(0.0588, -0.0809),
    float2(0.0309, -0.0951),
    float2(0.0000, -0.1000),
    float2(-0.0309, -0.0951),
    float2(-0.0588, -0.0809),
    float2(-0.0809, -0.0588),
    float2(-0.0951, -0.0309),
  )
  smallArrowPoints <- fixed_array(
    float2(-0.1, 0.3),
    float2(-0.1, 0.8),
    float2(-0.2, 0.8),
    float2(0.0, 1.0),
    float2(0.2, 0.8),
    float2(0.1, 0.8),
    float2(0.1, 0.3),
  )
  largeArrowPoints <- fixed_array(
    float2(0.05, 0.2),
    float2(0.1, 0.8),
    float2(0.0, 1.0),
    float2(-0.1, 0.8),
    float2(-0.05, 0.2),
  )
  slidingArrowPoints <- fixed_array(
    float2(0.0, 0.25),
    float2(0.5, 0.25),
    float2(0.5, 0.5),
    float2(1.0, 0.0),
    float2(0.5, -0.5),
    float2(0.5, -0.25),
    float2(0.0, -0.25),
  )
  rectanglePoints <- fixed_array(float2(-0.5, -0.5), float2(-0.5, 0.5), float2(0.5, 0.5), float2(0.5, -0.5))
  trianglePoints <- fixed_array(float2(-0.5, 0.0), float2(0.0, 0.4), float2(0.5, 0.0))
  rollIndicatorPoints <- fixed_array(
    float2(-1.8, 0.0),
    float2(-1.3, 0.0),
    float2(-1.4, 0.0),
    float2(-1.4, -0.2),
    float2(1.8, 0.0),
    float2(1.3, 0.0),
    float2(1.4, -0.0),
    float2(1.4, -0.2),
  )
  thinArrowPoints <- fixed_array(
    float2(0.0, 0.2),
    float2(0.0, 1.0),
    float2(0.03, 0.97),
    float2(-0.03, 0.97),
    float2(0.00, 0.97),
  )

class Component : Canvas
  isValid : bool = false
  isMetric : bool = true
  isEnglish : bool = false
  hero : Unit? = null
  fmw : FlightModelWrap? = null
  fm : FlightModel? = null
  fcm : FlightControlMode? = null
  wc : WeaponController? = null
  ws : WeaponSlots? = null
  app : AcesApp? = null
  colors : Colors = Colors()
  shapes : Shapes = Shapes()
  hasSelectedTarget : bool = false
  launchPermited : bool = false
  distanceToTarget : float = 0.0
  maxLaunchDistance : float = 0.0
  minLaunchDistance : float = 0.0
  isLaserDesignatorEnabled : bool = false



  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    hero = get_watched_not_delayed_hero()
    if hero == null
      return

    fmw = hero.as_fmw()
    if fmw == null
      return

    wc = hero.weap
    if wc == null
      return

    fm = fmw.fm
    if fm == null
      return

    app = get_app()
    if app == null
      return

    ws = new WeaponSlots(hero, app, fmw, wc)
    isEnglish = props.english
    isMetric = !isEnglish

    isValid = true
    setLineWidth(1.0)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(float2(canvasSize.y))
    setFont(props.fontId)
    setFontSize(18)

  // Utils
  def drawArrow(pos : float2; r : float; angle : float, arrow : ArrowType)
    var sina, cosa = 0.0
    sincos(deg_to_rad(angle), sina, cosa)
    var arrowPoints : array<float2>
    if arrow == ArrowType.simple
      arrowPoints = shapes.simpleArrowPoints.to_array()
    elif arrow == ArrowType.small
      arrowPoints = shapes.smallArrowPoints.to_array()
    elif arrow == ArrowType.thin
      arrowPoints = shapes.thinArrowPoints.to_array()
    else
      arrowPoints = shapes.largeArrowPoints.to_array()
    drawClosedPolyLine(arrowPoints.scale(float2(r)).rotate(-sina, -cosa).translate(pos))

  def drawTick(pos : float2; r : float; angle : float; len : float)
    var sina, cosa = 0.0
    sincos(deg_to_rad(angle), sina, cosa)
    let rv = float2(sina, -cosa)
    let start : float2 = pos + (r - len) * rv
    let finish : float2 = pos + r * rv
    drawLine(start, finish)

  def drawCircleTicks(pos : float2; angleStart : float; step : float; r : float; len : float; number : int)
    var angle = angleStart

    for _ in range(0, number)
      drawTick(pos, r, angle, len)
      angle += step
    return

  def drawCircleIndicatorValues(pos : float2; angleStart : float; step : float; r : float; values : array<string>)
    var angle = angleStart
    var sina, cosa = 0.0
    for i in range(0, values.length())
      sincos(deg_to_rad(angle), sina, cosa)
      let curPoint : float2 = pos + r * float2(sina, -cosa)
      drawStrAnchored(curPoint, values[i], AnchorHorz.Center, AnchorVert.Center)
      angle += step
    return

  def drawCircleSegment(pos : float2; angleStart : float; angleStop : float; r : float)
    drawSector(pos, float2(r), float2(deg_to_rad(angleStart - 90.0), deg_to_rad(angleStop - 90.0)))
    return

  // Flight general
  def drawSlidingClimb(value : float)
    let pos = float2(0.61, 0.09)
    let sizeUp = 0.15
    let sizeDown = 0.25
    let size = sizeDown + sizeUp
    let arrowVerPos = -clamp(value, -25.0, 15.0) / 100.0
    let arrowPos = float2(pos.x - 0.07, pos.y + arrowVerPos)
    let tickNum = 40
    setColor(colors.pink)

    drawLine(pos - float2(0.0, sizeUp), pos + float2(0.0, sizeDown))
    setLineWidth(2.0)
    drawLine(pos, pos - float2(0.03, 0.0))
    setLineWidth(1.0)
    let step = size / float(tickNum)
    for y in range(0, tickNum + 1)
      let posStart = float2(pos.x, pos.y - sizeUp + step * float(y))
      var posFin : float2
      if y % 5 == 0
        posFin = float2(pos.x - 0.02, posStart.y)
      else
        posFin = float2(pos.x - 0.01, posStart.y)
      drawLine(posStart, posFin)
    drawClosedPolyLine(shapes.slidingArrowPoints.to_array().scale(float2(0.03, 0.03)).translate(arrowPos))

    setColor(colors.green)


  def drawSpeed(value : float)
    let pos = float2(-0.45, -0.3)
    let size = 0.18
    let angle = 180.0 * value / 250.0
    drawCircle(pos, size)
    drawCircleIndicatorValues(pos, 0.0, 36.0, size - 0.045, ["", "5", "10", "15", "20", "25", "30", "35", "40", "45"])
    drawCircleTicks(pos, 0.0, 36.0, size, 0.02, 9)
    drawCircleTicks(pos, 0.0, 7.2, size, 0.01, 45)
    drawArrow(pos, size * 0.8, angle, ArrowType.simple)
    drawStrAnchored(pos + float2(0.0, 0.06), isEnglish ? "SPEED" : "СКОРОСТЬ", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(pos + float2(-0.03, -0.05), "{floori(value)}", AnchorHorz.Center, AnchorVert.Center)
    return

  def drawRadioAltitude(value : float)
    let pos = float2(-0.45, 0.1)
    let size = 0.18
    let angle = 180.0 * (value / 100.0)
    drawCircle(pos, size)
    drawCircleIndicatorValues(pos, 0.0, 36.0, size - 0.045, ["", "20", "40", "60", "80", "100", "", "300", "", "500"])
    drawCircleTicks(pos, 0.0, 36.0, size, 0.02, 9)
    drawCircleTicks(pos, 0.0, 7.2, size, 0.01, 45)
    drawArrow(pos, size * 0.8, angle, ArrowType.simple)
    let text = isMetric ? (isEnglish ? "METERS" : "МЕТРЫ") : (isEnglish ? "FEET" : "ФУТЫ")
    drawStrAnchored(pos + float2(0.0, 0.06), text, AnchorHorz.Center, AnchorVert.Center)
    return

  def drawBarometricAltitude(value : float)
    let pos = float2(0.45, -0.3)
    let size = 0.18
    let angleHour = 180.0 * value / 5.0 / 1000.0
    let angleMinute = 180.0 * value / 500.0
    drawCircle(pos, size)
    drawCircleIndicatorValues(pos, 0.0, 36.0, size - 0.045, ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"])
    drawCircleTicks(pos, 0.0, 36.0, size, 0.02, 10)
    drawCircleTicks(pos, 0.0, 7.2, size, 0.01, 50)
    drawArrow(pos, size, angleMinute, ArrowType.large)
    drawArrow(pos, 0.7 * size, angleHour, ArrowType.small)
    drawStrAnchored(pos + float2(0.0, 0.06), isEnglish ? "HEIGHT" : "ВЫСОТА", AnchorHorz.Center, AnchorVert.Center)
    return

  def drawClimb(value : float)
    let pos = float2(0.45, 0.1)
    let size = 0.18
    let start_a = 135.0
    let stop_a = 135.0 + 270.0
    let angle = -90.0 + 90.0 * clamp(value, -15.0, 15.0) / 10.0
    drawCircleSegment(pos, start_a, stop_a, size)
    drawCircleIndicatorValues(pos, start_a, 45.0, size - 0.045, ["15", "10", "5", "0", "5", "10", "15"])
    drawCircleTicks(pos, start_a, 45.0, size, 0.02, 7)
    drawCircleTicks(pos, start_a, 9.0, size, 0.01, 30)
    drawArrow(pos, size * 0.8, angle, ArrowType.simple)
    drawStrAnchored(pos - float2(0.0, 0.06), isEnglish ? "UP" : "ПОДЪЕМ", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(pos + float2(0.0, 0.06), isEnglish ? "DOWN" : "СПУСК", AnchorHorz.Center, AnchorVert.Center)
    return

  def drawCompass(value : float)
    let pos = float2(0.0, 1.0)
    let size = 0.7
    let angleSmallTickStart = 2.0 * floor(value / 2.0) - value - 44.0
    let angleBigTickStart = 30.0 * floor(value / 30.0) - value - 60.0

    let startValue = 30 * floori(value / 30.0) - 60
    var values = to_array_move(fixed_array<string>(
      "{circle_value(startValue)}",
      "{circle_value(startValue + 30)}",
      "{circle_value(startValue + 60)}",
      "{circle_value(startValue + 90)}",
      "{circle_value(startValue + 120)}",
    ))

    drawCircleSegment(pos, -45.0, 45.0, size)
    drawCircleIndicatorValues(pos, angleBigTickStart, 30.0, size - 0.07, values)
    drawCircleTicks(pos, angleSmallTickStart, 2.0, size, 0.02, 44)
    drawCircleTicks(pos, angleBigTickStart, 30.0, size, 0.05, 5)
    drawClosedPolyLine(shapes.trianglePoints.to_array().scale(float2(0.1)).translate(float2(0.0, 0.23)))
    return

  def drawHorizonLine(value : float)
    let shift = 0.01 * value
    drawLine(float2(-0.3, shift), float2(-0.25, shift))
    drawLine(float2(0.3, shift), float2(0.25, shift))
    return

  def drawBigCircle()
    drawCircle(float2(0.0, 0.02), 0.48)

  def drawZeroRoll()
    drawLine(float2(-0.3, 0.0), float2(-0.25, 0.0))
    drawLine(float2(0.3, 0.0), float2(0.25, 0.0))

  def drawSightCross()
    setLineWidth(3.0)
    drawLine(float2(-0.05, 0.0), float2(-0.015, 0.0))
    drawLine(float2(0.05, 0.0), float2(0.015, 0.0))
    drawLine(float2(0.0, 0.05), float2(0.0, 0.015))
    drawLine(float2(0.0, -0.05), float2(0.0, -0.015))

    drawLine(float2(0.0, 0.0), float2(0.0, 0.0))
    setLineWidth(1.0)
    drawLine(float2(-0.05, 0.0), float2(-0.08, 0.0))
    drawLine(float2(0.05, 0.0), float2(0.08, 0.0))
    drawLine(float2(0.0, 0.05), float2(0.0, 0.08))
    drawLine(float2(0.0, -0.05), float2(0.0, -0.08))


  def drawRoll(value : float)
    var sina, cosa = 0.0
    sincos(deg_to_rad(value), sina, cosa)
    let transformed = shapes.rollIndicatorPoints.to_array().rotate(-sina, -cosa).scale(float2(0.2))
    drawLine(transformed[0], transformed[1])
    drawLine(transformed[2], transformed[3])
    drawLine(transformed[4], transformed[5])
    drawLine(transformed[6], transformed[7])
    return

  // weapon

  def drawTargetDistance(distance : float; minDist : float; maxDist : float)
    let pos = float2(0.15, -0.3)
    let size = 0.05
    let distanceAll = 20.0 // km
    let angle = 360.0 / distanceAll * distance
    let angleMax = 360.0 / distanceAll * maxDist
    let angleMin = 360.0 / distanceAll * minDist


    drawCircle(pos, size)
    drawCircleSegment(pos, 0.0, angle, size + 0.01)
    drawTick(pos, size + 0.02, 0.0, 0.02)
    drawTick(pos, size + 0.02, angleMin, 0.02)
    drawTick(pos, size + 0.02, angleMax, 0.02)

  def drawLaunchAllowedText()
    let pos = float2(0.0, 0.37)
    drawStrAnchored(pos, isEnglish ? "LA" : "ПР", AnchorHorz.Center, AnchorVert.Center)

  def drawTargetDistanceText(distance : float)
    let pos = float2(0.0, 0.42)
    drawStrAnchored(pos, "{distance}", AnchorHorz.Center, AnchorVert.Center)
    return

  def drawWeaponType(weaponName : string)
    if weaponName.empty()
      return
    let pos = float2(-0.55, 0.4)
    drawStrAnchored(pos, loc("ils_mi35/{weaponName}"), AnchorHorz.Center, AnchorVert.Center)
    return

  def drawEffectiveModeText()
    let pos = float2(-0.55, -0.1)
    drawStrAnchored(pos, isEnglish ? "LRF READY" : "ЛД ГОТОВ", AnchorHorz.Center, AnchorVert.Center)

  def worldToMfdScreen(worldPos : float3& const) : float2
    let targetPosLocal = fast_normalize(inverse(hero.unitTm) * worldPos)
    let areaCoef = float2(3.0)
    let screenPos = float2(-targetPosLocal.z * areaCoef.x, -targetPosLocal.y * areaCoef.y)
    return screenPos

  def drawCanonCrosshair()
    var targetPos = float3(0.0)
    if !hud::get_valid_target_point(targetPos)
      return
    let screenPos = worldToMfdScreen(targetPos)
    drawCircle(screenPos, 0.02)
    return

  def drawNarrowFieldVision()
    drawClosedPolyLine(shapes.rectanglePoints.to_array().scale(float2(0.35, 0.25)))

  def drawShootingRing()
    drawCircle(float2(0.0), 0.1)

  def updateSelectedTarget()
    isLaserDesignatorEnabled = fcm.ctrlMap.isLaserDesignatorEnabled
    hasSelectedTarget = false
    Radar`foreach_targets() <| $(var target)
      if target.targetType == int(RadarTargetType.TYPE_TARGET)
        if target.isSelected
          hasSelectedTarget = true
          distanceToTarget = target.distanceRel
          launchPermited = true
          minLaunchDistance = get_radar_hud_aam_launch_zone_dist_min()
          maxLaunchDistance = get_radar_hud_aam_launch_zone_dist_max()

    return

  def drawWeapons()

    if hasSelectedTarget
      drawLaunchAllowedText()
      drawTargetDistance(distanceToTarget, minLaunchDistance, maxLaunchDistance)
      drawTargetDistanceText(distanceToTarget)
      drawNarrowFieldVision()
      drawShootingRing()
    if isLaserDesignatorEnabled
      drawEffectiveModeText()
    drawWeaponType(getCurWeaponName())
    drawCanonCrosshair()
    return

  def getCurWeaponName()
    for i in 0 .. ws.length()
      if hero.slotIdByWeaponId[i] <= 0
        continue
      let slot = ws.getWeaponSlot(i)
      return slot.locName
    return ""

  def drawStaticArrows()
    let pos = float2(0.5, 0.4)
    let size = 0.05
    setColor(colors.lightBlue)
    for i in range(0, 4)
      drawArrow(pos, size, 90.0 * float(i), ArrowType.thin)
    setColor(colors.green)


  def drawStatic()
    drawZeroRoll()
    drawBigCircle()
    drawSightCross()
    drawStaticArrows()
    return

  def drawGeneral()

    drawBarometricAltitude(isMetric ? float(fm.pos.y) : float(fm.pos.y) * metrToFeet)

    drawRadioAltitude(isMetric ? float(fm.currentAlt) : float(fm.currentAlt) * metrToFeet)

    drawSpeed(isMetric ? float(fm.speed) * mpsToKmh : float(fm.speed) * mpsToMh)

    drawClimb(isMetric ? float(fm.vel.y) : float(fm.vel.y) * metrToFeet)

    drawCompass((norm_ang(2. * PI + atan2(hero.unitTm[0].x, hero.unitTm[0].z))) * 180. / PI)

    drawRoll(-fmw.roll)
    drawHorizonLine(fmw.tangage)
    drawSlidingClimb(isMetric ? float(fm.vel.y) : float(fm.vel.y) * metrToFeet)
    return

  def draw()
    return if !isValid
    setColor(colors.green)
    drawGeneral()
    drawStatic()
    drawWeapons()
    return


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()


[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
  propStorage.english = getBool(props, "english", false)
