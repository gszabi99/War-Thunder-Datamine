local {round} = require("std/math.nut")
local {safeAreaSizeHud} = require("style/screenState.nut")
local tws = require("tws.nut")
local {IsMlwsLwsHudVisible, IsRwrHudVisible, IsTwsActivated, CollapsedIcon} = require("twsState.nut")
local radarComponent = require("radarComponent.nut")
local {GunOverheatState, IsCannonEmpty, IndicatorsVisible,
      FixedGunSightMode, FixedGunDirectionVisible, FixedGunDirectionX, FixedGunDirectionY,
      CurrentTime, TATargetX, TATargetY, MainMask, SightMask,
      IsAgmEmpty, AtgmTrackerRadius, IsATGMOutOfTrackerSector, NoLosToATGM,
      GunDirectionX, GunDirectionY, GunDirectionVisible, GunInDeadZone, GunSightMode, IsPilotHudVisible,
      IsLaserDesignatorEnabled, Agm, IsMainHudVisible, IsSightHudVisible, IsGunnerHudVisible,
      HudColor, AlertColor, IsMfdEnabled, IsMachineGunEmpty} = require("helicopterState.nut")
local aamAim = require("rocketAamAim.nut")
local agmAim = require("agmAim.nut")
local hudElems = require("helicopterHudElems.nut")
local {hudFontHgt, backgroundColor, fontOutlineColor, fontOutlineFxFactor} = require("style/airHudStyle.nut")

local compassWidth = hdpx(420)
local compassHeight = hdpx(40)


local getColor = @(isBackground) isBackground ? backgroundColor : HudColor.value

local styleLineBackground = {
  fillColor = Color(0, 0, 0, 0)
  lineWidth = max(1.5, hdpx(1) * (LINE_WIDTH + 1.5))
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = fontOutlineFxFactor
  fontFx = FFT_GLOW
  fontSize = hudFontHgt
}


local styleLineForeground = {
  fillColor = Color(0, 0, 0, 0)
  lineWidth = max(1.4, hdpx(1) * LINE_WIDTH)
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = fontOutlineFxFactor
  fontFx = FFT_GLOW
  fontSize = hudFontHgt
}

local helicopterGunDirection = function(line_style, isBackground, isSightHud) {
  local sqL = 80
  local l = 20
  local offset = (100 - sqL) * 0.5

  local function getCommands() {
    local commands

    if (GunSightMode.value == 0) {
      commands = [
        [VECTOR_LINE, -50 + offset, -50 + offset, 50 - offset, -50 + offset],
        [VECTOR_LINE, 50 - offset, 50 - offset, 50 - offset, -50 + offset],
        [VECTOR_LINE, -50 + offset, 50 - offset, 50 - offset, 50 - offset],
        [VECTOR_LINE, -50 + offset, -50 + offset, -50 + offset, 50 - offset],
      ]
    }
    else {

      commands = [
        [VECTOR_LINE, -50 + offset, -50 + offset, 50 - offset, -50 + offset],
        [VECTOR_LINE, 50 - offset, 50 - offset, 50 - offset, -50 + offset],
        [VECTOR_LINE, -50 + offset, 50 - offset, 50 - offset, 50 - offset],
        [VECTOR_LINE, -50 + offset, -50 + offset, -50 + offset, 50 - offset],
        [VECTOR_LINE, 40, 40, 55, 55],
        [VECTOR_LINE, -40, 40, -55, 55],
        [VECTOR_LINE, 40, -40, 55, -55],
        [VECTOR_LINE, -40, -40, -55, -55],
      ]
    }

    local commandsDash
    if (GunSightMode.value == 0) {

      commandsDash = [
        [VECTOR_LINE, 0, -50, 0, -50 + l],
        [VECTOR_LINE, 50 - l, 0, 50, 0],
        [VECTOR_LINE, 0, 50 - l, 0, 50],
        [VECTOR_LINE, -50, 0, -50 + l, 0]
      ]
    }
    else {

      commandsDash = [
        [VECTOR_LINE, 0, -50, 0, -50 + l],
        [VECTOR_LINE, 50 - l, 0, 50, 0],
        [VECTOR_LINE, 0, 50 - l, 0, 50],
        [VECTOR_LINE, -50, 0, -50 + l, 0],
        [VECTOR_LINE, 40, 40, 55, 55],
        [VECTOR_LINE, -40, 40, -55, 55],
        [VECTOR_LINE, 40, -40, 55, -55],
        [VECTOR_LINE, -40, -40, -55, -55]
      ]
    }

    local mainCommands = []
    local overheatCommands = []

    local allCannonsEmpty = IsCannonEmpty.reduce(@(res, val) res && val.value, true)

    for (local i = 0; i < commands.len(); ++i) {

      if (i >= GunOverheatState.value) {

        mainCommands.append(commands[i])
        if (!allCannonsEmpty || !IsMachineGunEmpty.value)
          mainCommands.append(commandsDash[i])
      }
      else {

        overheatCommands.append(commands[i])
        if (!allCannonsEmpty || !IsMachineGunEmpty.value)
          overheatCommands.append(commandsDash[i])
      }
    }

    return {
      mainCommands = mainCommands
      overheatCommands = overheatCommands
    }
  }


  local lines = @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [sh(2), sh(2)]
    color = getColor(isBackground)
    commands = getCommands().mainCommands
  })

  local linesOverheat = @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [sh(2), sh(2)]
    color = isBackground ? backgroundColor : AlertColor.value
    commands = getCommands().overheatCommands
  })

  local watchList = [
    IsMachineGunEmpty,
    GunOverheatState,
    GunDirectionX,
    GunDirectionY,
    GunDirectionVisible,
    GunInDeadZone,
    GunSightMode
  ]
  watchList.extend(IsCannonEmpty)

  return @() {
    size = SIZE_TO_CONTENT
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    watch = watchList
    opacity = (GunSightMode.value == 0 && isSightHud) ? 0 :
      (GunDirectionVisible.value &&
      (!GunInDeadZone.value || round(CurrentTime.value * 4) % 2 == 0)) ? 100 : 0
    transform = {
      translate = [GunDirectionX.value, GunDirectionY.value]
    }
    children = [
      lines,
      linesOverheat
    ]
  }
}

local function helicopterFixedGunsSight(sightId){
  if (sightId == 0) {

    return [
          [VECTOR_LINE, 0, 50, 0, 150],
          [VECTOR_LINE, 0, -50, 0, -150],
          [VECTOR_LINE, 50, 0, 150, 0],
          [VECTOR_LINE, -50, 0, -150, 0],
        ]
  }
  else if (sightId == 1) {

      return [
          [VECTOR_LINE, 0, 50, 0, 150],
          [VECTOR_LINE, 0, -50, 0, -150],
          [VECTOR_LINE, 50, 0, 150, 0],
          [VECTOR_LINE, -50, 0, -150, 0],
          [VECTOR_LINE, 80, 80, 100, 100],
          [VECTOR_LINE, -80, 80, -100, 100],
          [VECTOR_LINE, 80, -80, 100, -100],
          [VECTOR_LINE, -80, -80, -100, -100],
        ]
  }

  return [
          [VECTOR_LINE, 0, 50, 0, 150],
          [VECTOR_LINE, 0, -50, 0, -150],
          [VECTOR_LINE, 50, 0, 150, 0],
          [VECTOR_LINE, -50, 0, -150, 0],
          [VECTOR_LINE, 60, 60, -60, 60],
          [VECTOR_LINE, 60, -60, -60, -60],
          [VECTOR_LINE, 60, 60, 60, -60],
          [VECTOR_LINE, -60, 60, -60, -60],
        ]
}

local function helicopterFixedGunsDirection(line_style, isBackground) {

  local lines = @() line_style.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      size = [sh(0.625), sh(0.625)]
      color = getColor(isBackground)
      commands = helicopterFixedGunsSight(FixedGunSightMode.value)
    })

  return @() {
    size = SIZE_TO_CONTENT
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    watch = [FixedGunDirectionVisible,
             FixedGunDirectionX,
             FixedGunDirectionY,
             FixedGunSightMode]
    opacity = FixedGunDirectionVisible.value ? 100 : 0
    transform = {
      translate = [FixedGunDirectionX.value, FixedGunDirectionY.value]
    }
    children = [lines]
  }
}

local function helicopterCCRP(line_style, isBackground){
  local lines = @() line_style.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      size = [sh(0.625), sh(0.625)]
      color = getColor(isBackground)
      commands = [[VECTOR_LINE, 0,0, TATargetX.value, TATargetY.value]]
    })

    return @() {
    size = SIZE_TO_CONTENT
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    opacity = FixedGunDirectionVisible.value ? FixedGunSightMode == 2 ? 100 : 0 : 0
    transform = {
      translate = [FixedGunDirectionX.value, FixedGunDirectionY.value]
    }
    children = [lines]
  }
}

local paramsTableWidth = hdpx(450)
local paramsSightTableWidth = hdpx(270)

local helicopterParamsTable = hudElems.paramsTable(MainMask,
  paramsTableWidth,
  [max(safeAreaSizeHud.value.borders[1], sw(50) - hdpx(660)), sh(50) - hdpx(100)],
  hdpx(5))

local helicopterSightParamsTable = hudElems.paramsTable(SightMask,
  paramsSightTableWidth,
  [sw(50) - hdpx(250) - hdpx(200), hdpx(480)],
  hdpx(3))

local agmTrackZone = function(line_style, width, height, isBackground) {
  return @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    opacity = AtgmTrackerRadius.value > 0.0 ? 100 : 0
    color = getColor(isBackground)
    lineWidth = max(LINE_WIDTH, hdpx(LINE_WIDTH))
    watch = [IsAgmEmpty, IsATGMOutOfTrackerSector, AtgmTrackerRadius]
    commands = !IsAgmEmpty.value && IsATGMOutOfTrackerSector.value ?
    [
      [ VECTOR_ELLIPSE, 50, 50,
        AtgmTrackerRadius.value / width * 100,
        AtgmTrackerRadius.value / height * 100 ]
    ] : []
  })
}

local function agmTrackZoneComponent(elemStyle, isBackground) {
  local width = sw(100)
  local height = sh(100)
  local pos = [sw(50) - width * 0.5, sh(50) - height * 0.5]
  return @() {
    pos = pos
    size = SIZE_TO_CONTENT
    behavior = Behaviors.RtPropUpdate
    watch = CurrentTime
    opacity = round(CurrentTime.value * 4) % 2 == 0 ? 100 : 0
    children = agmTrackZone(elemStyle, width, height, isBackground)
  }
}

local function laserDesignator(line_style, width, height, isBackground) {
  local lhl = 5
  local lvl = 7

  return @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    watch = IsAgmEmpty
    color = !isBackground && IsAgmEmpty.value ? AlertColor.value : getColor(isBackground)
    commands = [
      [VECTOR_LINE, 50 - lhl, 50 - lvl, 50 + lhl, 50 - lvl],
      [VECTOR_LINE, 50 - lhl, 50 + lvl, 50 + lhl, 50 + lvl],
      [VECTOR_LINE, 50 - lhl, 50 - lvl, 50 - lhl, 50 + lvl],
      [VECTOR_LINE, 50 + lhl, 50 - lvl, 50 + lhl, 50 + lvl],
    ]
  })
}

local function laserDesignatorComponent(elemStyle, isBackground) {
  local width = hdpx(150)
  local height = hdpx(100)

  return @() {
    pos = [sw(50) - width * 0.5, sh(50) - height * 0.5]
    watch = IsLaserDesignatorEnabled
    opacity = IsLaserDesignatorEnabled.value ? 100 : 0
    size = SIZE_TO_CONTENT
    children = laserDesignator(elemStyle, width, height, isBackground)
  }
}

local function laserDesignatorStatusComponent(elemStyle, isBackground) {

  local function getText() {
    if (IsLaserDesignatorEnabled.value)
      return ::loc("HUD/TXT_LASER_DESIGNATOR")
    else {

      if (Agm.timeToHit.value > 0 && Agm.timeToWarning.value <= 0)
        return ::loc("HUD/TXT_ENABLE_LASER_NOW")
      else
        return ""
    }
  }

  local laserDesignatorStatus = @() elemStyle.__merge({
    rendObj = ROBJ_DTEXT
    halign = ALIGN_CENTER
    text = getText()
    watch = [ IsLaserDesignatorEnabled, Agm.timeToHit, Agm.timeToWarning, CurrentTime]
    color = getColor(isBackground)
    opacity = !IsLaserDesignatorEnabled.value &&
                  Agm.timeToHit.value > 0 &&
                  Agm.timeToWarning.value <= 0 ?
                    ((round(CurrentTime.value * 4) % 2 == 0) ? 100 : 0) :
                  100
  })

  local resCompoment = @() {
    pos = [sw(50), sh(38)]
    halign = ALIGN_CENTER
    size = [0, 0]
    children = laserDesignatorStatus
  }

  return resCompoment
}

local function atgmTrackerStatusComponent(elemStyle, isBackground) {

  local atgmTrackerStatus = @() elemStyle.__merge({
    rendObj = ROBJ_DTEXT
    halign = ALIGN_CENTER
    color = getColor(isBackground)
    watch = [IsATGMOutOfTrackerSector, CurrentTime, NoLosToATGM]
    text = IsATGMOutOfTrackerSector.value ? ::loc("HUD/TXT_ATGM_OUT_OF_TRACKER_SECTOR") : ::loc("HUD/TXT_NO_LOS_ATGM")
    opacity = (IsATGMOutOfTrackerSector.value || NoLosToATGM.value) &&
                  (round(CurrentTime.value * 4) % 2 == 0) ? 100 : 0
  })

  local resCompoment = @() {
    pos = [sw(50), sh(41)]
    halign = ALIGN_CENTER
    size = [0, 0]
    children = atgmTrackerStatus
  }

  return resCompoment
}


local function helicopterMainHud(elemStyle, isBackground) {
  local azimuth = !radarComponent.state.IsRadarHudVisible.value ?
   hudElems.compassElem(elemStyle, isBackground, compassWidth, compassHeight, sw(50) - 0.5*compassWidth, sh(15)) : null
  return @(){
    watch = IsMainHudVisible
    children = IsMainHudVisible.value
    ? [
      hudElems.rocketAim(elemStyle, sh(0.8), sh(1.8), isBackground)
      aamAim(elemStyle, @() getColor(isBackground))
      agmAim(elemStyle, @() getColor(isBackground))
      helicopterGunDirection(elemStyle, isBackground, false)
      helicopterFixedGunsDirection(elemStyle, isBackground)
      helicopterCCRP(elemStyle, isBackground)
      hudElems.vertSpeed(elemStyle, sh(4.0), sh(15), sw(50) + hdpx(384), sh(42.5), isBackground)
      hudElems.horSpeed(elemStyle, isBackground)
      helicopterParamsTable(elemStyle, isBackground)
      azimuth
      hudElems.taTarget(elemStyle, sw(25), sh(25), isBackground)
    ]
    : null
  }
}

local function helicopterSightHud(elemStyle, isBackground) {
  local azimuth = !radarComponent.state.IsRadarHudVisible.value ?
   hudElems.compassElem(elemStyle, isBackground, compassWidth, compassHeight, sw(50) - 0.5*compassWidth, sh(15)) : null
  return @(){
    watch = IsSightHudVisible
    pos = [0, 0]
    children = IsSightHudVisible.value ?
    [
      hudElems.vertSpeed(elemStyle, sh(4.0), sh(30), sw(50) + hdpx(384), sh(35), isBackground)
      hudElems.turretAngles(elemStyle, hdpx(150), hdpx(150), sw(50), sh(90), isBackground)
      hudElems.agmLaunchZone(elemStyle, sw(100), sh(100), isBackground)
      hudElems.launchDistanceMax(elemStyle, hdpx(150), hdpx(150), sw(50), sh(90), isBackground)
      helicopterSightParamsTable(elemStyle, isBackground)
      hudElems.lockSight(elemStyle, hdpx(150), hdpx(100), sw(50), sh(50), isBackground)
      hudElems.targetSize(elemStyle, sw(100), sh(100), isBackground)
      agmTrackZoneComponent(elemStyle, isBackground)
      laserDesignatorComponent(elemStyle, isBackground)
      hudElems.sight(elemStyle, sw(50), sh(50), hdpx(500), isBackground)
      hudElems.rangeFinder(elemStyle, sw(50), sh(59), isBackground)
      laserDesignatorStatusComponent(elemStyle, isBackground)
      atgmTrackerStatusComponent(elemStyle, isBackground)
      azimuth
      hudElems.detectAlly(elemStyle, sw(51), sh(35), isBackground)
      agmAim(elemStyle, @() getColor(isBackground))
      helicopterGunDirection(elemStyle, isBackground, true)
    ]
    : null
  }
}


local function gunnerHud(elemStyle, isBackground) {
  return @(){
    watch = IsGunnerHudVisible
    children = IsGunnerHudVisible.value
    ? [
      hudElems.rocketAim(elemStyle, sh(0.8), sh(1.8), isBackground)
      aamAim(elemStyle, @() getColor(isBackground))
      agmAim(elemStyle, @() getColor(isBackground))
      helicopterGunDirection(elemStyle, isBackground, false)
      helicopterFixedGunsDirection(elemStyle, isBackground)
      helicopterCCRP(elemStyle, isBackground)
      hudElems.vertSpeed(elemStyle, sh(4.0), sh(15), sw(50) + hdpx(384), sh(42.5), isBackground)
      helicopterParamsTable(elemStyle, isBackground)
    ]
    : null
  }
}


local function pilotHud(elemStyle, isBackground) {
  return @(){
    watch = IsPilotHudVisible
    pos = [0, 0]
    children = IsPilotHudVisible.value ?
    [
      hudElems.vertSpeed(elemStyle, sh(4.0), sh(15), sw(50) + hdpx(384), sh(42.5), isBackground)
      helicopterParamsTable(elemStyle, isBackground)
    ]
    : null
  }
}

local rwrPic = Picture("!ui/gameuiskin#rwr_stby_icon")
local function mkTws(colorStyle){
  local twsPosX = IsTwsActivated.value ? sw(6) : sw(81)
  local twsPosY = IsTwsActivated.value ? sh(6) : sh(35)
  local twsSize = IsTwsActivated.value ? sh(20) : sh(5)
  if (IsTwsActivated.value || !CollapsedIcon.value){
    return @(){
    children = (!IsMlwsLwsHudVisible.value && !IsRwrHudVisible.value) ? null :
      tws({
          colorStyle = colorStyle,
          pos = [twsPosX, twsPosY],
          size = [twsSize, twsSize],
          relativCircleSize = 43
        })
    }
  }
  else if (IsMlwsLwsHudVisible.value || IsRwrHudVisible.value){
    return @() colorStyle.__merge({
      pos = [sw(90), sh(33)]
      size = [sh(5), sh(5)]
      rendObj = ROBJ_IMAGE
      image = rwrPic
      color = colorStyle.color
    })
  }
  return null
}

local radarPic = Picture("!ui/gameuiskin#radar_stby_icon")
local function mkRadar(colorStyle) {
  local radarPosX = radarComponent.state.IsRadarVisible.value ? sw(78) : sw(91)
  local radarPosY = radarComponent.state.IsRadarVisible.value ? sh(70) : sh(35)
  local radarSize = radarComponent.state.IsRadarVisible.value ? sh(28) : sh(8)
  if (radarComponent.state.IsRadarVisible.value || !CollapsedIcon.value){
    return @() {
      children = radarComponent.radar(false, radarPosX, radarPosY, radarSize, true, colorStyle.color)
    }
  }
  else if (radarComponent.state.IsRadarHudVisible.value){
    return @() colorStyle.__merge({
      pos = [sw(95), sh(33)]
      size = [sh(5), sh(5)]
      rendObj = ROBJ_IMAGE
      image = radarPic
      color = colorStyle.color
    })
  }
  return null
}

local function helicopterHUDs(colorStyle, isBackground) {
  local rwrStyle = colorStyle.__merge({
    color = getColor(isBackground)
  })
  local hudStyle = colorStyle.__merge({
    fillColor = getColor(isBackground)
    color = getColor(isBackground)
  })

  local radar = !IsMfdEnabled.value ? mkRadar(rwrStyle) : null
  return [
    helicopterMainHud(hudStyle, isBackground)
    helicopterSightHud(hudStyle, isBackground)
    gunnerHud(hudStyle, isBackground)
    pilotHud(hudStyle, isBackground)
    mkTws(rwrStyle)
    radar
  ]
}


local function Root() {
  local children = helicopterHUDs(styleLineBackground, true)
  children.extend(helicopterHUDs(styleLineForeground, false))

  return {
    watch = [
      IndicatorsVisible
      HudColor
      IsMfdEnabled
      IsMlwsLwsHudVisible
      IsRwrHudVisible
      IsTwsActivated
      radarComponent.state.IsRadarVisible
    ]
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = [sw(100), sh(100)]
    children = (IndicatorsVisible.value || IsMfdEnabled) ? children : null
  }
}


return Root
