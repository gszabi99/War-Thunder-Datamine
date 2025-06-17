require darg
require DagorStdGuiRender
require math
require DagorMath
require DagorSystem
require RadarHud
require strings
require app
require Unit
require Weapon
require hud
require HeroManager
require WTCamera

struct CanvasParams
  textColor : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  backColor : E3DCOLOR = E3DCOLOR(0x00FFFFFF)
  fontId : int = -1
  fontSize : int = 20

let lod0DistSq = 30000. * 30000.
let lod1DistSq = 70000. * 70000.
let maxDistSq = 100000. * 100000.

[export]
def setup_data(props : Properties&; var storage : CanvasParams&)
  storage.textColor = fade_color(props |> getColor("textColor", E3DCOLOR(0xFFFFFFFF)), 255)
  storage.backColor = fade_color(props |> getColor("backColor", E3DCOLOR(0xFF000000)), 255)
  storage.fontId = props |> getFontId()
  storage.fontSize = props |> getInt("fontSize", 20)

def foreach_targets(blk : block<(unit : Unit? const const#) : void>)
  get_all_units() <| $(units : array<Unit?> const#)
    for u in units
      invoke(blk, u)

def foreach_shells(blk : block<(shell : ShellSensorViewData const const#) : void>)
  get_shell_sensor_view_data() <| $(shells : array<ShellSensorViewData const> const#)
    for shell in shells
      invoke(blk, shell)

let guidanceStateNames = fixed_array("", "hud/search", "hud/iog", "hud/iog_dl", "hud/track")

[export, unused_argument(rdata, rstate)]
def draw(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  if !get_app().isSensorViewMode
    return

  let hero = get_watched_hero()
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, data.fontSize)
  ctx |> set_font(data.fontId, 0, 0)
  ctx |> set_font_ht(data.fontSize)
  let padding = 5.
  let camera = get_camera_pos()

  foreach_targets() <| $(var unit)
    if unit != null && !unit.isDelayed && unit.needRenderInSensorView && (!unit.isFarAway || !unit.isFarAwayForSensors)
      let distSq = length_sq(camera - unit.pos)
      if distSq > maxDistSq
        return
      var screenPos = float2(0.)
      if world_to_screen(unit.pos, screenPos)
        var width = 0.
        var height = 0.
        let unitName = unit.fullName
        let unitNameBox = get_str_bbox(unitName, unitName |> length(), fctx)
        width = max(width, unitNameBox.width.x + padding * 2.)
        height += unitNameBox.width.y + padding * 2.

        var speed = ""
        var speedBox = BBox2()
        if distSq <= lod0DistSq && (unit.speed > 1. || unit.isFlightModelWrap)
          speed = get_measure_units_text(MeasureUnitsTypes.MEASURE_UNIT_SPEED, unit.speed, true, 1.)
          speedBox = get_str_bbox(speed, speed |> length(), fctx)
          width = max(width, speedBox.width.x + padding * 2.)
          height += speedBox.width.y + padding

        var distStr = ""
        var distBox = BBox2()
        if distSq <= lod1DistSq
          let dist = length(camera - unit.pos)
          distStr = get_measure_units_text(MeasureUnitsTypes.MEASURE_UNIT_DIST, dist, true, 0.1)
          distBox = get_str_bbox(distStr, distStr |> length(), fctx)
          width = max(width, distBox.width.x + padding * 2.)
          height += distBox.width.y + padding

        let dir = normalize((hero != null ? hero.pos : camera) - unit.pos)
        let relVel = unit.vel - (hero != null ? hero.vel : float3())
        let radSpd = dot(dir, relVel)

        var radSpeed = ""
        var radSpeedBox = BBox2()
        if distSq <= lod0DistSq && unit.isFlightModelWrap
          radSpeed = get_measure_units_text(MeasureUnitsTypes.MEASURE_UNIT_RADIAL_SPEED, radSpd, true, 1.)
          radSpeedBox = get_str_bbox(radSpeed, radSpeed |> length(), fctx)
          width = max(width, radSpeedBox.width.x + padding * 2.)
          height += radSpeedBox.width.y + padding

        screenPos -= float2(width * 0.5, height + ctx |> hdpx(30.))
        let color = get_sensor_view_unit_color(unit, true)
        let baseColor = E3DCOLOR(Color4(color))
        ctx |> set_color(data.backColor)
        ctx |> render_box(screenPos.x, screenPos.y, screenPos.x + width, screenPos.y + height)
        ctx |> set_color(baseColor)
        ctx |> render_frame(screenPos.x, screenPos.y, screenPos.x + width, screenPos.y + height, ctx |> hdpx(1.8))

        ctx |> set_color(data.textColor)
        screenPos.y += unitNameBox.width.y + padding * 0.5
        ctx |> goto_xy(screenPos.x + (width - unitNameBox.width.x) * 0.5, screenPos.y)
        ctx |> draw_str_scaled(1.0, unitName, unitName |> length())

        if distSq <= lod0DistSq && (unit.speed > 1. || unit.isFlightModelWrap)
          screenPos.y += speedBox.width.y + padding
          ctx |> goto_xy(screenPos.x + (width - speedBox.width.x) * 0.5, screenPos.y)
          ctx |> draw_str_scaled(1.0, speed, speed |> length())

        if distSq <= lod0DistSq && unit.isFlightModelWrap
          screenPos.y += radSpeedBox.width.y + padding
          ctx |> goto_xy(screenPos.x + (width - radSpeedBox.width.x) * 0.5, screenPos.y)
          ctx |> draw_str_scaled(1.0, radSpeed, radSpeed |> length())

        if distSq <= lod1DistSq
          screenPos.y += distBox.width.y + padding
          ctx |> goto_xy(screenPos.x + (width - distBox.width.x) * 0.5, screenPos.y)
          ctx |> draw_str_scaled(1.0, distStr, distStr |> length())

  foreach_shells() <| $(var shell)
    if hero != null && shell.ownerId == hero.id
      if !get_sensor_view_filter(SensorViewFilterType.SVF_WEAPON_HERO)
        return
    elif hero != null && shell.targetId == hero.id
      if !get_sensor_view_filter(SensorViewFilterType.SVF_WEAPON_ATTACK_HERO)
        return
    elif !get_sensor_view_filter(SensorViewFilterType.SVF_WEAPON_OTHER)
      return

    let distSq = length_sq(camera - shell.pos)
    var screenPos = float2(0.)
    if distSq > maxDistSq
      return
    if world_to_screen(shell.pos, screenPos)
      var width = 0.
      var height = 0.

      let rktName = does_loc_text_exist(shell.name) ? loc(shell.name) : loc("weapons/{shell.name}/short")
      let rktNameBox = get_str_bbox(rktName, rktName |> length(), fctx)
      width = max(width, rktNameBox.width.x + padding * 2.)
      height += rktNameBox.width.y + padding * 2.

      var speed = ""
      var speedBox = BBox2()
      if get_sensor_view_filter(SensorViewFilterType.SVF_RKT_SPEED) && distSq <= lod0DistSq
        speed = get_measure_units_text(MeasureUnitsTypes.MEASURE_UNIT_SPEED, shell.speed, true, 1.)
        speedBox = get_str_bbox(speed, speed |> length(), fctx)
        width = max(width, speedBox.width.x + padding * 2.)
        height += speedBox.width.y + padding

      var mach = ""
      var machBox = BBox2()
      if get_sensor_view_filter(SensorViewFilterType.SVF_RKT_MACH) && distSq <= lod1DistSq
        mach = "M: {fmt(":.2f", shell.mach)}"
        machBox = get_str_bbox(mach, mach |> length(), fctx)
        width = max(width, machBox.width.x + padding * 2.)
        height += machBox.width.y + padding

      var distStr = ""
      var distBox = BBox2()
      if get_sensor_view_filter(SensorViewFilterType.SVF_RKT_DIST) && distSq <= lod1DistSq
        distStr = "{loc("distance")}: {get_measure_units_text(MeasureUnitsTypes.MEASURE_UNIT_DIST, shell.dist, true, 0.1)}"
        distBox = get_str_bbox(distStr, distStr |> length(), fctx)
        width = max(width, distBox.width.x + padding * 2.)
        height += distBox.width.y + padding

      var traveledStr = ""
      var traveledBox = BBox2()
      if get_sensor_view_filter(SensorViewFilterType.SVF_RKT_TRAVELED) && distSq <= lod0DistSq
        traveledStr = "{loc("hud/traveled")}: {get_measure_units_text(MeasureUnitsTypes.MEASURE_UNIT_DIST, shell.distTraveled, true, 0.1)}"
        traveledBox = get_str_bbox(traveledStr, traveledStr |> length(), fctx)
        width = max(width, traveledBox.width.x + padding * 2.)
        height += traveledBox.width.y + padding

      var timeStr = ""
      var timeBox = BBox2()
      if get_sensor_view_filter(SensorViewFilterType.SVF_RKT_LIFETIME) && distSq <= lod0DistSq
        timeStr = "{loc("hud/lifeTime")}: {fmt(":.1f", shell.lifeTime)} {loc("measureUnits/seconds")}"
        timeBox = get_str_bbox(timeStr, timeStr |> length(), fctx)
        width = max(width, timeBox.width.x + padding * 2.)
        height += timeBox.width.y + padding

      var overloadStr = ""
      var overloadBox = BBox2()
      if get_sensor_view_filter(SensorViewFilterType.SVF_RKT_OVERLOAD) && distSq <= lod0DistSq
        overloadStr = "{loc("hud/overload")}: {fmt(":.1f", shell.overload)} {loc("measureUnits/gForce")}"
        overloadBox = get_str_bbox(overloadStr, overloadStr |> length(), fctx)
        width = max(width, overloadBox.width.x + padding * 2.)
        height += overloadBox.width.y + padding

      var aoaStr = ""
      var aoaBox = BBox2()
      if get_sensor_view_filter(SensorViewFilterType.SVF_RKT_AOA) && distSq <= lod0DistSq
        aoaStr = "{loc("hud/aoa")}: {fmt(":.1f", shell.aoa)} {loc("measureUnits/deg")}"
        aoaBox = get_str_bbox(aoaStr, aoaStr |> length(), fctx)
        width = max(width, aoaBox.width.x + padding * 2.)
        height += aoaBox.width.y + padding

      var stateStr = ""
      var stateBox = BBox2()
      if get_sensor_view_filter(SensorViewFilterType.SVF_RKT_STATE) && shell.guidanceState > int(SensorViewGuidanceState.SVGS_NO_GUID) && shell.guidanceState < int(SensorViewGuidanceState.SVGS_MAX)
        stateStr = "{loc("hud/guidanceState")}: {loc(guidanceStateNames[shell.guidanceState])}"
        stateBox = get_str_bbox(stateStr, stateStr |> length(), fctx)
        width = max(width, stateBox.width.x + padding * 2.)
        height += stateBox.width.y + padding

      let owner = get_unit(shell.ownerId)
      let color = get_sensor_view_unit_color(owner, false)
      let baseColor = E3DCOLOR(Color4(color))
      screenPos -= float2(width * 0.5, height + ctx |> hdpx(20.))
      ctx |> set_color(data.backColor)
      ctx |> render_box(screenPos.x, screenPos.y, screenPos.x + width, screenPos.y + height)
      ctx |> set_color(baseColor)
      ctx |> render_frame(screenPos.x, screenPos.y, screenPos.x + width, screenPos.y + height, ctx |> hdpx(1.8))

      ctx |> set_color(data.textColor)
      screenPos.y += rktNameBox.width.y + padding * 0.5
      ctx |> goto_xy(screenPos.x + (width - rktNameBox.width.x) * 0.5, screenPos.y)
      ctx |> draw_str_scaled(1.0, rktName, rktName |> length())

      if get_sensor_view_filter(SensorViewFilterType.SVF_RKT_SPEED) && distSq <= lod0DistSq
        screenPos.y += speedBox.width.y + padding
        ctx |> goto_xy(screenPos.x + (width - speedBox.width.x) * 0.5, screenPos.y)
        ctx |> draw_str_scaled(1.0, speed, speed |> length())

      if get_sensor_view_filter(SensorViewFilterType.SVF_RKT_MACH) && distSq <= lod1DistSq
        screenPos.y += machBox.width.y + padding
        ctx |> goto_xy(screenPos.x + (width - machBox.width.x) * 0.5, screenPos.y)
        ctx |> draw_str_scaled(1.0, mach, mach |> length())

      if get_sensor_view_filter(SensorViewFilterType.SVF_RKT_DIST) && distSq <= lod1DistSq
        screenPos.y += distBox.width.y + padding
        ctx |> goto_xy(screenPos.x + (width - distBox.width.x) * 0.5, screenPos.y)
        ctx |> draw_str_scaled(1.0, distStr, distStr |> length())

      if get_sensor_view_filter(SensorViewFilterType.SVF_RKT_TRAVELED) && distSq <= lod0DistSq
        screenPos.y += traveledBox.width.y + padding
        ctx |> goto_xy(screenPos.x + (width - traveledBox.width.x) * 0.5, screenPos.y)
        ctx |> draw_str_scaled(1.0, traveledStr, traveledStr |> length())

      if get_sensor_view_filter(SensorViewFilterType.SVF_RKT_LIFETIME) && distSq <= lod0DistSq
        screenPos.y += timeBox.width.y + padding
        ctx |> goto_xy(screenPos.x + (width - timeBox.width.x) * 0.5, screenPos.y)
        ctx |> draw_str_scaled(1.0, timeStr, timeStr |> length())

      if get_sensor_view_filter(SensorViewFilterType.SVF_RKT_OVERLOAD) && distSq <= lod0DistSq
        screenPos.y += overloadBox.width.y + padding
        ctx |> goto_xy(screenPos.x + (width - overloadBox.width.x) * 0.5, screenPos.y)
        ctx |> draw_str_scaled(1.0, overloadStr, overloadStr |> length())

      if get_sensor_view_filter(SensorViewFilterType.SVF_RKT_AOA) && distSq <= lod0DistSq
        screenPos.y += aoaBox.width.y + padding
        ctx |> goto_xy(screenPos.x + (width - aoaBox.width.x) * 0.5, screenPos.y)
        ctx |> draw_str_scaled(1.0, aoaStr, aoaStr |> length())

      if get_sensor_view_filter(SensorViewFilterType.SVF_RKT_STATE) && shell.guidanceState != int(SensorViewGuidanceState.SVGS_NO_GUID)
        screenPos.y += stateBox.width.y + padding
        ctx |> goto_xy(screenPos.x + (width - stateBox.width.x) * 0.5, screenPos.y)
        ctx |> draw_str_scaled(1.0, stateStr, stateStr |> length())