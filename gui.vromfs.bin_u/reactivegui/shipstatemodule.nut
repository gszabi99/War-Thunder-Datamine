from "%rGui/globals/ui_library.nut" import *

let { eventbus_send } = require("eventbus")
let { brokenEnginesCount, enginesInCooldown, enginesCount,
  transmissionCount, brokenTransmissionCount, transmissionsInCooldown, torpedosCount, brokenTorpedosCount, artilleryType,
  artilleryCount, brokenArtilleryCount, steeringGearsCount, brokenSteeringGearsCount, fire, aiGunnersState, buoyancy,
  steering, sightAngle, fwdAngle, hasAiGunners, fov, blockMoveControl, heroCoverPartsRelHp, isCoverDestroyed, burningParts
} = require("shipState.nut")
let { speedValue, speedUnits, machineSpeed } = require("%rGui/hud/shipStateView.nut")
let { bestMinCrewMembersCount, minCrewMembersCount, totalCrewMembersCount,
  aliveCrewMembersCount, driverAlive } = require("crewState.nut")
let { needShowDmgIndicator } = require("hudState.nut")
let dmModule = require("dmModule.nut")
let { damageModule, shipSteeringGauge, hudLogBgColor } = require("style/colors.nut").hud
let { lerp, sin, round } = require("%sqstd/math.nut")

const STATE_ICON_MARGIN = 1
const STATE_ICON_SIZE = 54
const TOP_PANEL_ICON_SIZE = 32
const FIRE_ICON_SIZE = 24

let iconSize = hdpxi(STATE_ICON_SIZE)
let topPanelIconSize = hdpxi(TOP_PANEL_ICON_SIZE)
let fireIconSize = hdpxi(FIRE_ICON_SIZE)

let allCoverPartsBarsWidth = hdpx(165)

enum CoverPartHpThreshold {
  MAX  = 0.995
  CRIT = 0.505
  MIN  = 0.005
}

enum CoverPartHpColor {
  GOOD     = 0xffFFC000
  HEALTHY  = 0xff9EE000
  CRITICAL = 0xffff4040
  KILLED   = 0xff000000
}

let images = {
  engine = Picture($"!ui/gameuiskin#engine_state_indicator.svg:{iconSize}:{iconSize}")
  transmission = Picture($"!ui/gameuiskin#ship_transmission_state_indicator.svg:{iconSize}:{iconSize}")
  steeringGear = Picture($"!ui/gameuiskin#ship_steering_gear_state_indicator.svg:{iconSize}:{iconSize}")
  artillery = Picture($"!ui/gameuiskin#artillery_weapon_state_indicator.svg:{iconSize}:{iconSize}")
  artillerySecondary = Picture($"!ui/gameuiskin#artillery_secondary_weapon_state_indicator.svg:{iconSize}:{iconSize}")
  machineGun = Picture($"!ui/gameuiskin#machine_gun_weapon_state_indicator.svg:{iconSize}:{iconSize}")
  torpedo = Picture($"!ui/gameuiskin#ship_torpedo_weapon_state_indicator.svg:{iconSize}:{iconSize}")
  buoyancy = Picture($"!ui/gameuiskin#buoyancy_icon.svg:{iconSize}:{iconSize}")
  fire = "!ui/gameuiskin#fire_indicator.svg:"
  fireOutline = Picture($"!ui/gameuiskin#fire_indicator_outline.avif:{fireIconSize}:{fireIconSize}")
  steeringMark = Picture($"!ui/gameuiskin#floatage_arrow_down.svg:{iconSize}:{iconSize}")
  sightCone = Picture("+ui/gameuiskin#map_camera")
  gunner = Picture($"!ui/gameuiskin#ship_crew_gunner.svg:{iconSize}:{iconSize}")
  driver = Picture($"!ui/gameuiskin#ship_crew_driver.svg:{iconSize}:{iconSize}")
  
  hull = Picture($"!ui/gameuiskin#ship_hull.svg:{topPanelIconSize}:{topPanelIconSize}")
  shipCrew = Picture($"!ui/gameuiskin#ship_crew.svg:{topPanelIconSize}:{topPanelIconSize}")

  bg = Picture("!ui/gameuiskin#debriefing_bg_grad@@ss")

  gunnerState = [ 
    Picture($"!ui/gameuiskin#ship_gunner_state_hold_fire.svg:{iconSize}:{iconSize}")
    Picture($"!ui/gameuiskin#ship_gunner_state_fire_at_will.svg:{iconSize}:{iconSize}")
    Picture($"!ui/gameuiskin#ship_gunner_state_air_targets.svg:{iconSize}:{iconSize}")
    Picture($"!ui/gameuiskin#ship_gunner_state_naval_targets.svg:{iconSize}:{iconSize}")
  ]
}

let fontFxColor = Color(80, 80, 80)
let fontFx = FFT_GLOW
let maxFontBoxHeight = hdpx(18.5)

let speedComp = {
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  hplace = ALIGN_CENTER
  halign = ALIGN_RIGHT
  valign = ALIGN_CENTER

  children = [
    {
      size = const [flex(4), SIZE_TO_CONTENT]
      children = machineSpeed({ box = [hdpx(200), maxFontBoxHeight], fontSize = maxFontBoxHeight })
      halign = ALIGN_RIGHT
    }
    {
      size = const [flex(1.8), SIZE_TO_CONTENT]
      flow = FLOW_HORIZONTAL
      valign = ALIGN_BOTTOM
      children = [
        speedValue()
        speedUnits({ box = [hdpx(50), maxFontBoxHeight], fontSize = hdpx(13) })
      ]
    }
  ]
}


let engine = dmModule({
  icon = images.engine
  iconSize = [STATE_ICON_SIZE, STATE_ICON_SIZE]
  totalCountState = enginesCount
  brokenCountState = brokenEnginesCount
  cooldownState = enginesInCooldown
})

let transmission = dmModule({
  icon = images.transmission
  iconSize = [STATE_ICON_SIZE, STATE_ICON_SIZE]
  totalCountState = transmissionCount
  brokenCountState = brokenTransmissionCount
  cooldownState = transmissionsInCooldown
})
let torpedo = dmModule({
  icon = images.torpedo
  iconSize = [STATE_ICON_SIZE, STATE_ICON_SIZE]
  totalCountState = torpedosCount
  brokenCountState = brokenTorpedosCount
})
let artillery = dmModule({
  icon = @(art_type) art_type == TRIGGER_GROUP_PRIMARY     ? images.artillery
                   : art_type == TRIGGER_GROUP_SECONDARY   ? images.artillerySecondary
                   : art_type == TRIGGER_GROUP_MACHINE_GUN ? images.machineGun
                   : images.artillery
  iconWatch = artilleryType
  iconSize = [STATE_ICON_SIZE, STATE_ICON_SIZE]
  totalCountState = artilleryCount
  brokenCountState = brokenArtilleryCount
})
let steeringGears = dmModule({
  icon = images.steeringGear
  iconSize = [30, 30]
  totalCountState = steeringGearsCount
  brokenCountState = brokenSteeringGearsCount
})


let damageModules = {
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  gap = sh(STATE_ICON_MARGIN)
  children = [
    engine
    transmission
    torpedo
    artillery
  ]
}

let buoyancyOpacity = Computed(@() buoyancy.get() < 1.0 ? 1.0 : 0.0)
let buoyancyPercent = Computed(@() (buoyancy.get() * 100).tointeger())
let buoyancyIndicator = @() {
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  watch = buoyancyOpacity
  opacity = buoyancyOpacity.get()
  children = [
    @() {
      watch = buoyancyPercent
      rendObj = ROBJ_TEXT
      text = $"{buoyancyPercent.get()}%"
      font = Fonts.small_text_hud
    }
    {
      size = [iconSize, hdpx(10)]
      rendObj = ROBJ_IMAGE
      image = images.buoyancy
    }
  ]
}

let picFire = Picture($"{images.fire}{iconSize}:{iconSize}:K")
let stateBlock = {
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  children = [
    @() {
      watch = fire
      size = [iconSize, iconSize]
      rendObj = ROBJ_IMAGE
      color =  fire.get() ? damageModule.alert : damageModule.inactive
      image = picFire
    }
    buoyancyIndicator
  ]
}


let playAiSwithAnimation = function (_ne_value) {
  anim_start(aiGunnersState)
}

let aiGunners = @() {
  watch = aiGunnersState
  vplace = ALIGN_BOTTOM
  size = [iconSize, iconSize]
  marigin = [hdpx(STATE_ICON_MARGIN), 0]

  rendObj = ROBJ_IMAGE
  image = images.gunnerState?[aiGunnersState.get()] ?? images.gunnerState[0]
  color = damageModule.active
  onAttach = @(_elem) aiGunnersState.subscribe(playAiSwithAnimation)
  onDetach = @(_elem) aiGunnersState.unsubscribe(playAiSwithAnimation)
  transform = {}
  animations = [
    {
      prop = AnimProp.color
      from = damageModule.aiSwitchHighlight
      easing = Linear
      duration = 0.15
      trigger = aiGunnersState
    }
    {
      prop = AnimProp.scale
      from = [1.5, 1.5]
      easing = InOutCubic
      duration = 0.2
      trigger = aiGunnersState
    }
  ]
}


let crewCountColor = Computed(function() {
  let minimum = minCrewMembersCount.get()
  let current = aliveCrewMembersCount.get()
  if (current < minimum) {
    return damageModule.dmModuleDestroyed
  }
  else if (current < minimum * 1.1) {
    return damageModule.dmModuleDamaged
  }
  return damageModule.active
})

let maxCrewLeftPercent = Computed(@() totalCrewMembersCount.get() > 0
  ? (100.0 * (1.0 + (bestMinCrewMembersCount.get().tofloat() - minCrewMembersCount.get())
      / totalCrewMembersCount.get())
    + 0.5).tointeger()
  : 0
)
let countCrewLeftPercent = Computed(@()
  clamp(lerp(minCrewMembersCount.get() - 1, totalCrewMembersCount.get(),
      0, maxCrewLeftPercent.get(), aliveCrewMembersCount.get()),
    0, 100)
)

let driverIndicator = @() {
  watch = [ driverAlive, blockMoveControl ]
  size = [iconSize, iconSize]
  marigin = [hdpx(STATE_ICON_MARGIN), 0]
  rendObj = ROBJ_IMAGE
  image = images.driver
  color = driverAlive.get() && !blockMoveControl.get()
    ? damageModule.inactive
    : damageModule.alert
}

let steeringLine = {
  size = const [hdpx(1), flex()]
  rendObj = ROBJ_SOLID
  color = shipSteeringGauge.serif
}

let steeringComp = {
  size = const [pw(50), hdpx(3)]
  hplace = ALIGN_CENTER

  children = [
    {
      size = flex()
      rendObj = ROBJ_SOLID
      color = shipSteeringGauge.background
      flow = FLOW_HORIZONTAL
      gap = {
        size = flex()
      }
      valign = ALIGN_BOTTOM
      children = [
        steeringLine
        steeringLine
        steeringLine
        steeringLine
        steeringLine
      ]
    }
    @() {
      watch = steering
      size = const [hdpx(12), hdpx(10)]
      pos = [pw(-steering.get() * 50), -hdpx(5)]
      hplace = ALIGN_CENTER
      rendObj = ROBJ_IMAGE
      image = images.steeringMark
      color = shipSteeringGauge.mark
    }
  ]
}

let dollSize = [sh(16), sh(32)]
let fovSize = [sh(30), sh(30)]
let fovTopOffset = sh(2)
let fovPos = [0.5 * dollSize[0] - 0.5 * fovSize[0],
  0.5 * dollSize[1] - 0.5 * fovSize[1] + fovTopOffset]

let dollFov = @() {
  watch = [ fwdAngle, sightAngle, fov ]
  pos = fovPos
  size = fovSize
  transform = {
    pivot = [0.5, 0.5]
    rotate = sightAngle.get() - fwdAngle.get()
    scale = [sin(fov.get()), 1.0]
  }
  children = [
    {
      size = flex()
      rendObj = ROBJ_IMAGE
      image = images.sightCone
      color = Color(155, 255, 0, 120)
    }
    {
      size = flex()
      rendObj = ROBJ_IMAGE
      image = images.sightCone
      color = Color(155, 255, 0)
    }
  ]
}


function makeFireIcons(burningPartsTable) {
  if (burningPartsTable.len() == 0)
    return []

  let blinkTime = 1.3
  let icons = []
  let scaleFactor = max(dollSize[0], dollSize[1])
  foreach (partId, pos in burningPartsTable) {
    let x = dollSize[0] * 0.5 - fireIconSize * 0.5 + pos.x * scaleFactor
    let y = dollSize[1] * 0.5 - fireIconSize * 0.5 + pos.y * scaleFactor
    icons.append({
      key = $"fireOutline_{partId}"
      pos = [x, y]
      size = [fireIconSize, fireIconSize]
      rendObj = ROBJ_IMAGE
      image = images.fireOutline
      color =  damageModule.fire
      opacity = 0
      transform = {}
      animations = [
        {
          prop = AnimProp.scale
          from = [1, 1]
          to = [1.6, 1.6]
          play = true
          loop = true
          easing = InCubic
          duration = blinkTime * 0.5
          delay = blinkTime * 0.5
          loopPause = blinkTime * 0.5
        }
        {
          prop = AnimProp.opacity
          from = 1
          to = 0
          play = true
          loop = true
          easing = InCubic
          duration = blinkTime * 0.5
          delay = blinkTime * 0.5
          loopPause = blinkTime * 0.5
        }
      ]
    })
    icons.append({
      key = $"fireIcon_{partId}"
      pos = [x, y]
      size = [fireIconSize, fireIconSize]
      rendObj = ROBJ_IMAGE
      image = picFire
      color =  damageModule.fire
      animations = [
        { prop = AnimProp.opacity, from = 0, to = 1, play = true, loop = true, duration = blinkTime, easing = CosineFull }
      ]
    })
  }
  return icons
}

let fireIconsOverlay = @() {
  watch = burningParts
  size = dollSize
  children = makeFireIcons(burningParts.get())
}

let doll = {
  color = Color(0, 255, 0)
  size = dollSize
  rendObj = ROBJ_XRAYDOLL
  rotateWithCamera = false
  children = [
    fireIconsOverlay
    dollFov
  ]
}

let leftBlock = damageModules

let rightBlock = @() {
  watch = hasAiGunners
  size = FLEX_V
  flow = FLOW_VERTICAL
  children = [
    stateBlock
    { size = FLEX_V }
    hasAiGunners.get() ? aiGunners : null
    driverIndicator
  ]
}

let shipStateDisplay = {
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  children = [
    {
      flow = FLOW_HORIZONTAL
      size = SIZE_TO_CONTENT
      children = [
        leftBlock
        doll
        rightBlock
      ]
    }
    steeringGears
    steeringComp
  ]
}

let xraydoll = {
  size = 1
  rendObj = ROBJ_XRAYDOLL     
}

function mkCoverPartsBars(heroCoverPartsRelHpV) {
  let partsCount = heroCoverPartsRelHpV.len()
  if (partsCount == 0)
    return null
  let barsMarginsCount = partsCount + 1
  let barsMarginX = hdpx(2)
  let width = round((allCoverPartsBarsWidth - barsMarginsCount * barsMarginX) / partsCount)
  return heroCoverPartsRelHpV.map(@(hp) {
    size = [width, hdpx(6)]
    margin = [0, barsMarginX]
    rendObj = ROBJ_SOLID
    color = hp < CoverPartHpThreshold.MIN ? CoverPartHpColor.KILLED
      : hp < CoverPartHpThreshold.CRIT ? CoverPartHpColor.CRITICAL
      : hp < CoverPartHpThreshold.MAX ? CoverPartHpColor.GOOD
      : CoverPartHpColor.HEALTHY
  })
}

let mkCoverPartsContainerBar = @(isCoverDestroyedV) @() {
  key = {}
  watch = heroCoverPartsRelHp
  vplace = ALIGN_BOTTOM
  padding = hdpx(4)
  flow = FLOW_HORIZONTAL
  rendObj = ROBJ_BOX
  borderColor = 0xff565656
  borderWidth = hdpx(2)

  children = mkCoverPartsBars(heroCoverPartsRelHp.get())

  animations = isCoverDestroyedV ? [{
    prop = AnimProp.borderColor,
    from = 0x00000000, to = damageModule.alert,
    duration = 1, easing = InSine,
    loop = true, play = true,
  }] : null
}

let coverPartsIndicator = {
  size = flex()
  padding = hdpx(4)
  rendObj = ROBJ_SOLID
  color = hudLogBgColor
  flow = FLOW_HORIZONTAL
  gap = hdpx(2)
  children = [
    {
      size = [topPanelIconSize, topPanelIconSize]
      rendObj = ROBJ_IMAGE
      image = images.hull
    }
    @() {
      watch = isCoverDestroyed
      vplace = ALIGN_CENTER
      flow = FLOW_VERTICAL
      children = [
        {
          rendObj = ROBJ_TEXT
          text = loc("HUD/SHIP_HULL_STRENGTH")
          font = Fonts.tiny_text_hud
        }
        mkCoverPartsContainerBar(isCoverDestroyed.get())
      ]
    }
  ]
}

let crewIndicator = {
  size = const [hdpx(82), SIZE_TO_CONTENT]
  padding = hdpx(4)
  rendObj = ROBJ_SOLID
  color = hudLogBgColor
  children = [
    @() {
      watch = crewCountColor
      size = [topPanelIconSize, topPanelIconSize]
      rendObj = ROBJ_IMAGE
      image = images.shipCrew
      color = crewCountColor.get()
    }
    @() {
      watch = countCrewLeftPercent
      size = flex()
      halign = ALIGN_RIGHT
      valign = ALIGN_CENTER
      rendObj = ROBJ_TEXT
      text = $"{countCrewLeftPercent.get()}%"
      font = Fonts.tiny_text_hud
      fontFx = fontFx
      fontFxColor = fontFxColor
    }
  ]
}

let topPanel = {
  size = FLEX_H
  gap = hdpx(4)
  flow = FLOW_HORIZONTAL
  children = [
    crewIndicator
    coverPartsIndicator
  ]
}

let mainPanel = {
  padding = hdpx(10)
  valign = ALIGN_CENTER
  rendObj = ROBJ_SOLID
  color = hudLogBgColor
  flow = FLOW_VERTICAL
  gap = { size = const [flex(), hdpx(5)] }
  children = [
    speedComp
    shipStateDisplay
  ]
}

return @() {
  watch = needShowDmgIndicator
  flow = FLOW_VERTICAL
  gap = hdpx(4)
  behavior = Behaviors.RecalcHandler
  function onRecalcLayout(_initial, elem) {
    if (elem.getWidth() > 1 && elem.getHeight() > 1) {
      eventbus_send("update_damage_panel_state", {
        pos = [elem.getScreenPosX(), elem.getScreenPosY()]
        size = [elem.getWidth(), elem.getHeight()]
        visible = needShowDmgIndicator.get()
      })
    }
    else
      eventbus_send("update_damage_panel_state", {})
  }

  children = needShowDmgIndicator.get()
    ? [
        topPanel
        mainPanel
      ]
    : xraydoll
}
