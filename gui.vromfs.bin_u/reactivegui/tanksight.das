require darg
require DagorStdGuiRender
require DagorMath
require math
require Unit
require HeroManager
require IGroundModel
require strings
require DagorSystem
require app
require Weapon
require WTCamera
require hud
require DagorTexture3D
require Mission

let black = E3DCOLOR(Color4(float4(0, 0, 0, 1)))
let transparentColor = E3DCOLOR(Color4(float4(0, 0, 0, 0)))

struct CanvasParams
  fontId : int = -1
  lineWidth : float = 1.
  isPreviewMode : bool = false
  highlightColor : E3DCOLOR = E3DCOLOR(Color4(float4(0.3, 1.0, 1.0, 2.)))

[export]
def setup_data(props : Properties&; var storage : CanvasParams&)
  storage.lineWidth = props |> getFloat("lineWidth", 1.)
  storage.isPreviewMode = props |> getBool("isPreviewMode", false)
  storage.highlightColor = props |> getColor("highlightColor", E3DCOLOR(0xFFFFFFFF))

[export, unused_argument(rstate)]
def draw_rangefinder_elem(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  if !is_custom_tank_sight_enabled()
    return
  let settings = get_tank_sight_settings()
  if settings == null || !settings.rangefinderVisible
    return
  if !data.isPreviewMode
    let hero = get_controlled_hero()
    if hero == null || hero.isDelayed
      return
    let gm = hero |> as_gm()
    if gm == null
      return
    let app = get_app()
    if app == null || app.flightControlMode == null
      return
    let camera = app.flightControlMode.cameraControl.cur
    if camera == null || camera.camtype != FlightCameraType.FLIGHT_CAMERA_TYPE_TURRET_VIRTUAL_FPS
      return
    let isNightVision = hero.curNightVisionRenderMode == 1
    let isThermal = hero.curNightVisionRenderMode == 2
    draw_rangefinder(ctx, rdata.pos, rdata.size, data, gm, isNightVision, isThermal)
  else
    let isNightVision = settings != null && settings.currentMode == TankSettingMode.TSM_NIGHT_VISION
    let isThermal = settings != null && settings.currentMode == TankSettingMode.TSM_THERMAL
    draw_rangefinder(ctx, rdata.pos, rdata.size, data, null, isNightVision, isThermal)

def draw_rangefinder(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; gm : IGroundModel?; is_night_vision : bool;
                     is_thermal : bool)
  var dist = data.isPreviewMode ? 1234. : -1.
  var progress = -1.
  var isOver = false
  var isCorrection = false
  if !data.isPreviewMode && gm == null
    return
  if !data.isPreviewMode
    if get_difficulty_config().hudShowTankDistance && get_targeting_gun_intersect()
      dist = get_targeting_dist()
      let corDist = get_current_dist_correction()
      if corDist > 0.
        dist = corDist
        isOver = get_current_dist_correction_over()
        isCorrection = true
    elif gm.rangefinder != null && get_difficulty_config().hudUseRangefinder
      if gm.rangefinder.ready || gm.rangefinder.progress < 0.
        dist = max(0., get_current_dist_correction())
        isOver = get_current_dist_correction_over()
        isCorrection = true
        if gm.rangefinder.hideTime > float(get_total_time()) || dist == gm.rangefinder.distance
          dist = gm.rangefinder.distance
          isOver = gm.rangefinder.isOverDistance
          isCorrection = false
      else
        progress = gm.rangefinder.progress

  var fctx : StdGuiFontContext
  let settings = get_tank_sight_settings()
  let fontId = settings.rangefinderFontId != -1 ? settings.rangefinderFontId : get_font_id("digital")
  get_font_context(fctx, fontId, 0, 0, settings.rangefinderTextSize)
  let textColor = (is_thermal ? settings.rangefinderThTextColor :
   (is_night_vision ? settings.rangefinderNvTextColor :
   (get_crosshair_light_on() ? settings.rangefinderLightTextColor : settings.rangefinderTextColor)))
  if dist >= 0.
    ctx |> set_font(fontId, 0, 0)
    ctx |> set_font_ht(settings.rangefinderTextSize)

    let backColor = (is_thermal ? settings.rangefinderThBackColor :
     (is_night_vision ? settings.rangefinderNvBackColor :
     (get_crosshair_light_on() ? settings.rangefinderLightBackColor : settings.rangefinderBackColor)))
    if Color4(backColor).a > 0.
      ctx |> reset_textures()
      ctx |> set_color(backColor)
      let tc = float2(0., 0.)
      let fullStrBox = get_str_bbox("8888", 4, fctx)
      let backPos = float2(pos.x + (size.x - fullStrBox.width.x) * 0.5 - ctx |> hdpx(10.), pos.y - ctx |> hdpx(5.))
      let backBR = float2(pos.x + (size.x + fullStrBox.width.x) * 0.5 + ctx |> hdpx(10.), pos.y + fullStrBox.width.y + ctx |> hdpx(5.))
      ctx |> render_rect(backPos.x, backPos.y, backBR.x, backBR.y, tc, tc, tc)

    ctx |> set_color(textColor)
    let distText = isOver ? ">{fmt(":.0f", dist)}" : fmt(":.0f", dist)
    let strBox = get_str_bbox(distText, distText |> length(), fctx)
    let textPos = float2(pos.x + size.x * 0.5 - strBox.width.x * 0.5, pos.y + strBox.width.y)
    ctx |> goto_xy(textPos.x, textPos.y)
    ctx |> draw_str_scaled(1.0, distText, distText |> length())

    if isCorrection
      ctx |> set_font(0, 0, 0)
      ctx |> set_font_ht(settings.rangefinderTextSize)
      let correctionSymbol = "*"
      let symBox = get_str_bbox(correctionSymbol, correctionSymbol |> length(), fctx)
      ctx |> goto_xy(textPos.x - symBox.width.x, textPos.y)
      ctx |> draw_str_scaled(1.0, correctionSymbol, correctionSymbol |> length())

    if data.isPreviewMode && settings.highlightedObject == TankSettingObj.TSO_RANGEFINDER
      ctx |> set_color(data.highlightColor)
      ctx |> render_frame(textPos.x - ctx |> hdpx(10.), textPos.y - strBox.width.y - ctx |> hdpx(5.),
      textPos.x + strBox.width.x + ctx |> hdpx(10.), textPos.y + ctx |> hdpx(5.), ctx |> hdpx(data.lineWidth))
  elif progress >= 0.
    let strBox = get_str_bbox("8888", 4, fctx)

    let leftX = pos.x + size.x * 0.5 - strBox.width.x * 0.7
    let progressX = pos.x + size.x * 0.5 + strBox.width.x * lerp(-0.7, 0.7, progress)
    let rightX = pos.x + size.x * 0.5 + strBox.width.x * 0.7

    let topY = pos.y + strBox.width.y * 1.1
    let botY = pos.y - strBox.width.y * 0.1

    let tc = float2(0., 0.)
    ctx |> set_color(settings.rangefinderProgressColor)
    ctx |> reset_textures()
    ctx |> render_rect(leftX, topY, progressX, botY, tc, tc, tc)

    var color = float4(Color4(settings.rangefinderProgressBackgroundColor))
    color *= 0.6
    let e3dColor = E3DCOLOR(Color4(color))
    ctx |> set_color(e3dColor)
    ctx |> render_rect(progressX, topY, rightX, botY, tc, tc, tc)


def deg_to_rad(rad : float)
  return rad * PI / 180.

[export, unused_argument(rstate)]
def draw_turret_orient_elem(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  if !is_custom_tank_sight_enabled()
    return
  let settings = get_tank_sight_settings()
  if settings == null || !settings.turretOriVisible
    return
  if !data.isPreviewMode
    let hero = get_controlled_hero()
    if hero == null || hero.isDelayed
      return
    let app = get_app()
    if app == null || app.flightControlMode == null
      return
    let camera = app.flightControlMode.cameraControl.cur
    if camera == null || camera.camtype != FlightCameraType.FLIGHT_CAMERA_TYPE_TURRET_VIRTUAL_FPS
      return
    let isNightVision = hero.curNightVisionRenderMode == 1
    let isThermal = hero.curNightVisionRenderMode == 2
    draw_turret_orientation(ctx, rdata.pos, rdata.size, data, hero, isNightVision, isThermal)
  else
    let isNightVision = settings != null && settings.currentMode == TankSettingMode.TSM_NIGHT_VISION
    let isThermal = settings != null && settings.currentMode == TankSettingMode.TSM_THERMAL
    draw_turret_orientation(ctx, rdata.pos, rdata.size, data, null, isNightVision, isThermal)

def draw_turret_orientation(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; unit : Unit?; is_night_vision : bool;
                            is_thermal : bool)
  var yaw = 0.
  if !data.isPreviewMode
    if unit == null || unit.weap == null
      return
    let weapon = unit.curWeapon
    if weapon == null
      return
    if weapon.turretNo >= 0 && weapon.turretNo < length(unit.weap.turret)
      yaw = unit.weap.turret[weapon.turretNo].yawVisual
    else
      return

  let settings = get_tank_sight_settings()
  let textColor = (is_thermal ? settings.turretOriThColor :
   (is_night_vision ? settings.turretOriNvColor :
   (get_crosshair_light_on() ? settings.turretOriLightColor : settings.turretOriColor)))
  ctx |> set_color(textColor)
  let position = pos + float2(size.x * 0.5, 0.)
  let tankCoord <- to_array_move(fixed_array<float2>(
   position,
   position + float2(ctx |> hdpx(20.), ctx |> hdpx(10.)),
   position + float2(ctx |> hdpx(20.), ctx |> hdpx(70.)),
   position + float2(ctx |> hdpx(-20.), ctx |> hdpx(70.)),
   position + float2(ctx |> hdpx(-20.), ctx |> hdpx(10.))
  ))
  ctx |> render_line_aa(tankCoord, true, data.lineWidth, float2(0, 0), textColor)

  let turretPos = position + float2(0., ctx |> hdpx(35.))
  ctx |> setRotViewTm(turretPos.x, turretPos.y, deg_to_rad(yaw), 0., false)
  let rad = ctx |> hdpx(19.)
  ctx |> render_ellipse_aa(turretPos, float2(rad), ctx |> hdpx(data.lineWidth), textColor, transparentColor)
  let coord <- to_array_move(fixed_array<float2>(float2(turretPos.x, turretPos.y - rad),
   float2(turretPos.x, turretPos.y - rad - ctx |> hdpx(40.))))
  ctx |> render_line_aa(coord, false, ctx |> hdpx(data.lineWidth), float2(0, 0), textColor)
  ctx |> resetViewTm()

  if data.isPreviewMode && settings.highlightedObject == TankSettingObj.TSO_TURRET
    ctx |> set_color(data.highlightColor)
    ctx |> render_frame(position.x - ctx |> hdpx(30.), position.y - ctx |> hdpx(40.),
     position.x + ctx |> hdpx(30.), position.y + ctx |> hdpx(85.), ctx |> hdpx(data.lineWidth))

[export, unused_argument(rstate)]
def draw_reload_progress_elem(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  if !is_custom_tank_sight_enabled()
    return
  let settings = get_tank_sight_settings()
  if settings == null || !settings.gunReadyVisible
    return
  if !data.isPreviewMode
    let hero = get_controlled_hero()
    if hero == null || hero.isDelayed
      return
    let app = get_app()
    if app == null || app.flightControlMode == null
      return
    let camera = app.flightControlMode.cameraControl.cur
    if camera == null || camera.camtype != FlightCameraType.FLIGHT_CAMERA_TYPE_TURRET_VIRTUAL_FPS
      return
    let isNightVision = hero.curNightVisionRenderMode == 1
    let isThermal = hero.curNightVisionRenderMode == 2
    draw_reload_progress(ctx, rdata.pos, rdata.size, data, hero, isNightVision, isThermal)
  else
    let isNightVision = settings != null && settings.currentMode == TankSettingMode.TSM_NIGHT_VISION
    let isThermal = settings != null && settings.currentMode == TankSettingMode.TSM_THERMAL
    draw_reload_progress(ctx, rdata.pos, rdata.size, data, null, isNightVision, isThermal)

def draw_reload_progress(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; unit : Unit?; is_night_vision : bool;
                         is_thermal : bool)
  var timeToShot = 1.2
  var isInoperable = false
  var isCartridge = false
  var isEmpty = false

  let settings = get_tank_sight_settings()
  if !data.isPreviewMode
    if unit == null || unit.weap == null
      return
    let weapon = unit.curWeapon
    if weapon == null
      return
    let gun = as_gun(weapon)
    if gun == null
      return
    timeToShot = gun.nextShotAtTime - float(get_app().usefulTotalTime)
    isInoperable = gun.isInoperable
    isCartridge = gun.currentBulletSet.bulletsCartridge > 1
    isEmpty = gun.currentBulletSet.bulletsCount == 0

  let isReloading = (!isCartridge && timeToShot > 0.) || (isCartridge && timeToShot > 0.5)
  let showRedMarker   = settings.gunReadyMarkVisible && (isInoperable || isEmpty)
  let showGreenMarker = settings.gunReadyMarkVisible && (data.isPreviewMode || (!isInoperable && !isEmpty && !isReloading))
  let showReloadTimer = settings.gunReadyReloadCountdownVisible && (data.isPreviewMode || (!isInoperable && !isEmpty && isReloading))

  if (showRedMarker || showGreenMarker)
    let sphCenter = pos + size * 0.3
    let color = showRedMarker ? E3DCOLOR(0xFFFF0000) : E3DCOLOR(0xFF00FF00)
    ctx |> render_ellipse_aa(sphCenter, float2(ctx |> hdpx(10.)), ctx |> hdpx(1.), black, color)

  if (showReloadTimer)
    var fctx : StdGuiFontContext
    let fontId = settings.gunReadyFontId != -1 ? settings.gunReadyFontId : get_font_id("digital")
    get_font_context(fctx, fontId, 0, 0, settings.gunReadyTextSize)

    ctx |> set_font(fontId, 0, 0)
    ctx |> set_font_ht(settings.gunReadyTextSize)
    let color = (is_thermal ? settings.gunReadyThColor :
    (is_night_vision ? settings.gunReadyNvColor :
    (get_crosshair_light_on() ? settings.gunReadyLightColor : settings.gunReadyColor)))
    ctx |> set_color(color)
    let timeText = fmt(":.1f", timeToShot)
    let strBox = get_str_bbox(timeText, timeText |> length(), fctx)
    ctx |> goto_xy(pos.x + ctx |> hdpx(10.), pos.y + strBox.width.y)
    ctx |> draw_str_scaled(1.0, timeText, timeText |> length())

    if data.isPreviewMode && settings.highlightedObject == TankSettingObj.TSO_GUN_READY
      ctx |> set_color(data.highlightColor)
      ctx |> render_frame(pos.x, pos.y - ctx |> hdpx(5.),
      pos.x + strBox.width.x + ctx |> hdpx(20.), pos.y + strBox.width.y + ctx |> hdpx(10.), ctx |> hdpx(data.lineWidth))

[export, unused_argument(rstate)]
def draw_inner_fov_elem(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  if !is_custom_tank_sight_enabled()
    return
  let settings = get_tank_sight_settings()
  if settings == null || !settings.fovVisible
    return
  if !data.isPreviewMode
    let hero = get_controlled_hero()
    if hero == null || hero.isDelayed
      return
    let app = get_app()
    if app == null || app.flightControlMode == null
      return
    let camera = app.flightControlMode.cameraControl.cur
    if camera == null || camera.camtype != FlightCameraType.FLIGHT_CAMERA_TYPE_TURRET_VIRTUAL_FPS
      return
    let isNightVision = hero.curNightVisionRenderMode == 1
    let isThermal = hero.curNightVisionRenderMode == 2
    draw_inner_fov(ctx, rdata.pos, rdata.size, data, isNightVision, isThermal)
  else
    let isNightVision = settings != null && settings.currentMode == TankSettingMode.TSM_NIGHT_VISION
    let isThermal = settings != null && settings.currentMode == TankSettingMode.TSM_THERMAL
    draw_inner_fov(ctx, rdata.pos, rdata.size, data, isNightVision, isThermal)

def draw_inner_fov(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; is_night_vision : bool;
                   is_thermal : bool)
  var minFov = 2.
  var curFov = 1.
  if !data.isPreviewMode
    let app = get_app()
    if app == null || app.flightControlMode == null
      return
    let camera = app.flightControlMode.cameraControl.cur
    if camera == null
      return
    minFov = camera.minMaxFov.y
    curFov = camera.viewData.fov
  let settings = get_tank_sight_settings()
  let newSize = size * (curFov / minFov)
  let newPos = pos + size * 0.5 - newSize * 0.5
  let color = (is_thermal ? settings.fovThColor : (is_night_vision ? settings.fovNvColor : (get_crosshair_light_on() ? settings.fovLightColor : settings.fovColor)))
  ctx |> set_color(color)

  let frameLen = ctx |> hdpx(40.)
  let fovFrameLT <- to_array_move(fixed_array<float2>(
     newPos + float2(frameLen, 0.),
     newPos,
     newPos + float2(0., frameLen)
    ))
  ctx |> render_line_aa(fovFrameLT, false, data.lineWidth, float2(0, 0), color)
  let fovFrameRT <- to_array_move(fixed_array<float2>(
     newPos + float2(newSize.x - frameLen, 0.),
     newPos + float2(newSize.x, 0.),
     newPos + float2(newSize.x, frameLen)
    ))
  ctx |> render_line_aa(fovFrameRT, false, data.lineWidth, float2(0, 0), color)
  let fovFrameLB <- to_array_move(fixed_array<float2>(
     newPos + float2(0., newSize.y - frameLen),
     newPos + float2(0., newSize.y),
     newPos + float2(frameLen, newSize.y)
    ))
  ctx |> render_line_aa(fovFrameLB, false, data.lineWidth, float2(0, 0), color)
  let fovFrameRB <- to_array_move(fixed_array<float2>(
     newPos + float2(newSize.x - frameLen, newSize.y),
     newPos + newSize,
     newPos + float2(newSize.x, newSize.y - frameLen)
    ))
  ctx |> render_line_aa(fovFrameRB, false, data.lineWidth, float2(0, 0), color)

  if data.isPreviewMode && settings.highlightedObject == TankSettingObj.TSO_FOV
    ctx |> set_color(data.highlightColor)
    ctx |> render_frame(newPos.x - ctx |> hdpx(20.), newPos.y - ctx |> hdpx(15.),
      newPos.x + newSize.x + ctx |> hdpx(20.), newPos.y + newSize.y + ctx |> hdpx(15.), ctx |> hdpx(data.lineWidth))

[export, unused_argument(rstate)]
def draw_bullet_type_elem(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  if !is_custom_tank_sight_enabled()
    return
  let settings = get_tank_sight_settings()
  if settings == null || !settings.bulletTypeVisible
    return
  if !data.isPreviewMode
    let hero = get_controlled_hero()
    if hero == null || hero.isDelayed
      return
    let app = get_app()
    if app == null || app.flightControlMode == null
      return
    let camera = app.flightControlMode.cameraControl.cur
    if camera == null || camera.camtype != FlightCameraType.FLIGHT_CAMERA_TYPE_TURRET_VIRTUAL_FPS
      return
    let isNightVision = hero.curNightVisionRenderMode == 1
    let isThermal = hero.curNightVisionRenderMode == 2
    draw_bullet_type(ctx, rdata.pos, rdata.size, data, hero, isNightVision, isThermal)
  else
    let isNightVision = settings != null && settings.currentMode == TankSettingMode.TSM_NIGHT_VISION
    let isThermal = settings != null && settings.currentMode == TankSettingMode.TSM_THERMAL
    draw_bullet_type(ctx, rdata.pos, rdata.size, data, null, isNightVision, isThermal)

def draw_bullet_type(var ctx : GuiContext&; pos : float2; size : float2; data : CanvasParams&; unit : Unit?; is_night_vision : bool;
                     is_thermal : bool)
  let settings = get_tank_sight_settings()
  var name = settings.bulletTypeIsShortName ? loc("tankSight/bulletName") : loc("tankSight/bulletType")
  if !data.isPreviewMode
    if unit == null || unit.weap == null
      return
    let weapon = unit.curWeapon
    if weapon == null
      return
    let gun = as_gun(weapon)
    if gun != null
      name = settings.bulletTypeIsShortName ? loc(gun.currentBulletSet.bullet[0].getName) : loc("{gun.currentBulletSet.bullet[0].getType}/name/short")
    else
      return

  let backColor = (is_thermal ? settings.bulletTypeThBackColor :
   (is_night_vision ? settings.bulletTypeNvBackColor :
   (get_crosshair_light_on() ? settings.bulletTypeLightBackColor : settings.bulletTypeBackColor)))
  if Color4(backColor).a > 0.
    ctx |> reset_textures()
    ctx |> set_color(backColor)
    let tc = float2(0., 0.)
    ctx |> render_rect(pos.x, pos.y, pos.x + size.x, pos.y + size.y, tc, tc, tc)

  var fctx : StdGuiFontContext
  let fontId = settings.bulletTypeFontId != -1 ? settings.bulletTypeFontId : get_font_id("hud")
  get_font_context(fctx, fontId, 0, 0, settings.bulletTypeTextSize)

  ctx |> set_font(fontId, 0, 0)
  ctx |> set_font_ht(settings.bulletTypeTextSize)
  let color = (is_thermal ? settings.bulletTypeThTextColor :
   (is_night_vision ? settings.bulletTypeNvTextColor :
   (get_crosshair_light_on() ? settings.bulletTypeLightTextColor : settings.bulletTypeTextColor)))
  ctx |> set_color(color)
  let strBox = get_str_bbox(name, name |> length(), fctx)
  ctx |> goto_xy(pos.x + size.x * 0.5 - strBox.width.x * 0.5, pos.y + (size.y + strBox.width.y) * 0.5)
  ctx |> draw_str_scaled(1.0, name, name |> length())

  if data.isPreviewMode && settings.highlightedObject == TankSettingObj.TSO_BULLET_TYPE
    ctx |> set_color(data.highlightColor)
    ctx |> render_frame(pos.x - ctx |> hdpx(5.), pos.y - ctx |> hdpx(5.),
     pos.x + size.x + ctx |> hdpx(5.), pos.y + size.y + ctx |> hdpx(5.), ctx |> hdpx(data.lineWidth))
