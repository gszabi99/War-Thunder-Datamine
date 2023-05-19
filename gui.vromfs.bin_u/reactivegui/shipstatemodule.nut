from "%rGui/globals/ui_library.nut" import *
let cross_call = require("%rGui/globals/cross_call.nut")

let { brokenEnginesCount, enginesInCooldown, enginesCount,
  transmissionCount, brokenTransmissionCount, transmissionsInCooldown, torpedosCount, brokenTorpedosCount, artilleryType,
  artilleryCount, brokenArtilleryCount, steeringGearsCount, brokenSteeringGearsCount, fire, aiGunnersState, buoyancy,
  steering, sightAngle, fwdAngle, hasAiGunners, fov, blockMoveControl
} = require("shipState.nut")
let { speedValue, speedUnits, machineSpeed } = require("%rGui/hud/shipStateView.nut")
let { bestMinCrewMembersCount, minCrewMembersCount, totalCrewMembersCount,
  aliveCrewMembersCount, driverAlive } = require("crewState.nut")
let { isVisibleDmgIndicator } = require("hudState.nut")
let dmModule = require("dmModule.nut")
let { damageModule, shipSteeringGauge, hudLogBgColor } = require("style/colors.nut").hud

let { lerp, sin } = require("%sqstd/math.nut")

const STATE_ICON_MARGIN = 1
const STATE_ICON_SIZE = 54

let iconSize = hdpx(STATE_ICON_SIZE)

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
  steeringMark = Picture($"!ui/gameuiskin#floatage_arrow_down.svg:{iconSize}:{iconSize}")
  sightCone = Picture("+ui/gameuiskin#map_camera")
  shipCrew = Picture($"!ui/gameuiskin#ship_crew.svg:{iconSize}:{iconSize}")
  gunner = Picture($"!ui/gameuiskin#ship_crew_gunner.svg:{iconSize}:{iconSize}")
  driver = Picture($"!ui/gameuiskin#ship_crew_driver.svg:{iconSize}:{iconSize}")

  bg = Picture("!ui/gameuiskin#debriefing_bg_grad@@ss")

  gunnerState = [ //according to AI_GUNNERS_ enum
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
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_HORIZONTAL
  hplace = ALIGN_CENTER
  halign = ALIGN_RIGHT
  valign = ALIGN_CENTER

  children = [
    {
      size = [flex(4), SIZE_TO_CONTENT]
      children = machineSpeed({ box = [hdpx(200), maxFontBoxHeight], fontSize = maxFontBoxHeight })
      halign = ALIGN_RIGHT
    }
    {
      size = [flex(1.8), SIZE_TO_CONTENT]
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

let buoyancyOpacity = Computed(@() buoyancy.value < 1.0 ? 1.0 : 0.0)
let buoyancyPercent = Computed(@() (buoyancy.value * 100).tointeger())
let buoyancyIndicator = @() {
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  watch = buoyancyOpacity
  opacity = buoyancyOpacity.value
  children = [
    @() {
      rendObj = ROBJ_TEXT
      text = $"{buoyancyPercent.value}%"
      font = Fonts.small_text_hud
      watch = buoyancyPercent
    }
    {
      rendObj = ROBJ_IMAGE
      image = images.buoyancy
      size = [iconSize, hdpx(10)]
    }
  ]
}

let picFire = Picture($"{images.fire}{iconSize}:{iconSize}:K")
let stateBlock = {
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  children = [
    @() {
      rendObj = ROBJ_IMAGE
      color =  fire.value ? damageModule.alert : damageModule.inactive
      watch = fire
      image = picFire
      size = [iconSize, iconSize]
    }
    buoyancyIndicator
  ]
}


let playAiSwithAnimation = function (_ne_value) {
  anim_start(aiGunnersState)
}

let aiGunners = @() {
  vplace = ALIGN_BOTTOM
  size = [iconSize, iconSize]
  marigin = [hdpx(STATE_ICON_MARGIN), 0]

  rendObj = ROBJ_IMAGE
  image = images.gunnerState?[aiGunnersState.value] ?? images.gunnerState[0]
  color = damageModule.active
  watch = aiGunnersState
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
  let minimum = minCrewMembersCount.value
  let current = aliveCrewMembersCount.value
  if (current < minimum) {
    return damageModule.dmModuleDestroyed
  }
  else if (current < minimum * 1.1) {
    return damageModule.dmModuleDamaged
  }
  return damageModule.active
})

let maxCrewLeftPercent = Computed(@() totalCrewMembersCount.value > 0
  ? (100.0 * (1.0 + (bestMinCrewMembersCount.value.tofloat() - minCrewMembersCount.value)
      / totalCrewMembersCount.value)
    + 0.5).tointeger()
  : 0
)
let countCrewLeftPercent = Computed(@()
  clamp(lerp(minCrewMembersCount.value - 1, totalCrewMembersCount.value,
      0, maxCrewLeftPercent.value, aliveCrewMembersCount.value),
    0, 100)
)

let crewBlock = {
  vplace = ALIGN_BOTTOM
  flow = FLOW_VERTICAL
  size = [iconSize, SIZE_TO_CONTENT]

  children = [
    @() {
      size = [iconSize, iconSize]
      marigin = [hdpx(STATE_ICON_MARGIN), 0]
      rendObj = ROBJ_IMAGE
      image = images.driver
      watch = [ driverAlive, blockMoveControl ]
      color = driverAlive.value && !blockMoveControl.value
        ? damageModule.inactive
        : damageModule.alert
    }
    @() {
      size = [iconSize, iconSize]
      marigin = [hdpx(STATE_ICON_MARGIN), 0]
      rendObj = ROBJ_IMAGE
      image = images.shipCrew
      color = crewCountColor.value
      watch = crewCountColor
    }
    @() {
      vplace = ALIGN_BOTTOM
      hplace = ALIGN_CENTER
      rendObj = ROBJ_TEXT
      watch = countCrewLeftPercent
      text = $"{countCrewLeftPercent.value}%"
      font = Fonts.tiny_text_hud
      fontFx = fontFx
      fontFxColor = fontFxColor
    }
  ]
}

let steeringLine = {
  size = [hdpx(1), flex()]
  rendObj = ROBJ_SOLID
  color = shipSteeringGauge.serif
}

let steeringComp = {
  size = [pw(50), hdpx(3)]
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
      rendObj = ROBJ_IMAGE
      watch = steering
      image = images.steeringMark
      color = shipSteeringGauge.mark
      size = [hdpx(12), hdpx(10)]
      hplace = ALIGN_CENTER
      pos = [pw(-steering.value * 50), -hdpx(5)]
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
    rotate = sightAngle.value - fwdAngle.value
    scale = [sin(fov.value), 1.0]
  }
  children = [
    {
      size = [flex(), flex()]
      rendObj = ROBJ_IMAGE
      image = images.sightCone
      color = Color(155, 255, 0, 120)
    }
    {
      size = [flex(), flex()]
      rendObj = ROBJ_IMAGE
      image = images.sightCone
      color = Color(155, 255, 0)
    }
  ]
}

let doll = {
  color = Color(0, 255, 0)
  size = dollSize
  rendObj = ROBJ_XRAYDOLL
  rotateWithCamera = false
  children = dollFov
}


let leftBlock = damageModules

let rightBlock = @() {
  watch = hasAiGunners
  size = [SIZE_TO_CONTENT, flex()]
  flow = FLOW_VERTICAL
  children = [
    stateBlock
    { size = [SIZE_TO_CONTENT, flex()] }
    hasAiGunners.value ? aiGunners : null
    crewBlock
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
  rendObj = ROBJ_XRAYDOLL     ///Need add ROBJ_XRAYDOLL in scene for correct update isVisibleDmgIndicator state
  size = [1, 1]
}

return @() {
  watch = isVisibleDmgIndicator
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  rendObj = ROBJ_SOLID
  color = hudLogBgColor
  padding = isVisibleDmgIndicator.value ? hdpx(10) : 0
  gap = isVisibleDmgIndicator.value ? { size = [flex(), hdpx(5)] } : 0
  behavior = Behaviors.RecalcHandler
  function onRecalcLayout(_initial, elem) {
    if (elem.getWidth() > 1 && elem.getHeight() > 1) {
      cross_call.update_damage_panel_state({
        pos = [elem.getScreenPosX(), elem.getScreenPosY()]
        size = [elem.getWidth(), elem.getHeight()]
        visible = true
      })
    }
  }

  children = isVisibleDmgIndicator.value
    ? [
        speedComp
        shipStateDisplay
      ]
    : xraydoll
}
