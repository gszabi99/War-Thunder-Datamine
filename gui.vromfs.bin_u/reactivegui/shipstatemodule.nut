local { brokenEnginesCount, enginesInCooldown, enginesCount,
  transmissionCount, brokenTransmissionCount, transmissionsInCooldown, torpedosCount, brokenTorpedosCount, artilleryType,
  artilleryCount, brokenArtilleryCount, steeringGearsCount, brokenSteeringGearsCount, fire, aiGunnersState, buoyancy,
  steering, sightAngle, fwdAngle, hasAiGunners, fov
} = require("shipState.nut")
local { speedValue, speedUnits, machineSpeed } = require("reactiveGui/hud/shipStateView.nut")
local { bestMinCrewMembersCount, minCrewMembersCount, totalCrewMembersCount,
  aliveCrewMembersCount, driverAlive } = require("crewState.nut")
local { isVisibleDmgIndicator } = require("hudState.nut")
local dmModule = require("dmModule.nut")
local {damageModule, shipSteeringGauge} = require("style/colors.nut").hud
local setHudBg = require("style/hudBackground.nut")

local {lerp, sin} = require("std/math.nut")

const STATE_ICON_MARGIN = 1
const STATE_ICON_SIZE = 54

local images = {
  engine = Picture("!ui/gameuiskin#engine_state_indicator")
  transmission = Picture("!ui/gameuiskin#ship_transmission_state_indicator")
  steeringGear = Picture("!ui/gameuiskin#ship_steering_gear_state_indicator")
  artillery = Picture("!ui/gameuiskin#artillery_weapon_state_indicator")
  artillerySecondary = Picture("!ui/gameuiskin#artillery_secondary_weapon_state_indicator")
  machineGun = Picture("!ui/gameuiskin#machine_gun_weapon_state_indicator")
  torpedo = Picture("!ui/gameuiskin#ship_torpedo_weapon_state_indicator")
  buoyancy = Picture("!ui/gameuiskin#buoyancy_icon")
  fire = "!ui/gameuiskin#fire_indicator.svg:"
  steeringMark = Picture("!ui/gameuiskin#floatage_arrow_down")
  sightCone = Picture("+ui/gameuiskin#map_camera")
  shipCrew = Picture("!ui/gameuiskin#ship_crew")
  gunner = Picture("!ui/gameuiskin#ship_crew_gunner")
  driver = Picture("!ui/gameuiskin#ship_crew_driver")

  bg = Picture("!ui/gameuiskin#debriefing_bg_grad@@ss")

  gunnerState = [ //according to AI_GUNNERS_ enum
    Picture("!ui/gameuiskin#ship_gunner_state_hold_fire")
    Picture("!ui/gameuiskin#ship_gunner_state_fire_at_will")
    Picture("!ui/gameuiskin#ship_gunner_state_air_targets")
    Picture("!ui/gameuiskin#ship_gunner_state_naval_targets")
  ]
}

local fontFxColor = Color(80, 80, 80)
local fontFx = FFT_GLOW

local function speedComp() {
  return {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    hplace = ALIGN_CENTER
    halign = ALIGN_RIGHT
    valign = ALIGN_CENTER

    children = [
      {
        size = [flex(4), SIZE_TO_CONTENT]
        children = machineSpeed({ box = [hdpx(200), hdpx(18.5)], fontSize = hdpx(18.5) })
        halign = ALIGN_RIGHT
      }
      {
        size = [flex(1.8), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        valign = ALIGN_BOTTOM
        children = [
          speedValue()
          speedUnits({ box = [hdpx(50), hdpx(18.5)], fontSize = hdpx(13) })
        ]
      }
    ]
  }
}


local engine = dmModule({
  icon = images.engine
  iconSize = [STATE_ICON_SIZE, STATE_ICON_SIZE]
  totalCountState = enginesCount
  brokenCountState = brokenEnginesCount
  cooldownState = enginesInCooldown
})

local transmission = dmModule({
  icon = images.transmission
  iconSize = [STATE_ICON_SIZE, STATE_ICON_SIZE]
  totalCountState = transmissionCount
  brokenCountState = brokenTransmissionCount
  cooldownState = transmissionsInCooldown
})
local torpedo = dmModule({
  icon = images.torpedo
  iconSize = [STATE_ICON_SIZE, STATE_ICON_SIZE]
  totalCountState = torpedosCount
  brokenCountState = brokenTorpedosCount
})
local artillery = dmModule({
  icon = @(art_type) art_type == TRIGGER_GROUP_PRIMARY     ? images.artillery
                   : art_type == TRIGGER_GROUP_SECONDARY   ? images.artillerySecondary
                   : art_type == TRIGGER_GROUP_MACHINE_GUN ? images.machineGun
                   : images.artillery
  iconWatch = artilleryType
  iconSize = [STATE_ICON_SIZE, STATE_ICON_SIZE]
  totalCountState = artilleryCount
  brokenCountState = brokenArtilleryCount
})
local steeringGears = dmModule({
  icon = images.steeringGear
  iconSize = [30, 30]
  totalCountState = steeringGearsCount
  brokenCountState = brokenSteeringGearsCount
})


local damageModules = @() {
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

local buoyancyOpacity = Computed(@() buoyancy.value < 1.0 ? 1.0 : 0.0)
local buoyancyPercent = Computed(@() (buoyancy.value * 100).tointeger())
local buoyancyIndicator = @() {
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  watch = buoyancyOpacity
  opacity = buoyancyOpacity.value
  children = [
    @() {
      rendObj = ROBJ_DTEXT
      text = $"{buoyancyPercent.value}%"
      font = Fonts.small_text_hud
      watch = buoyancyPercent
    }
    {
      rendObj = ROBJ_IMAGE
      image = images.buoyancy
      size = [hdpx(STATE_ICON_SIZE), hdpx(10)]
    }
  ]
}

local picFire = ::Picture($"{images.fire}{hdpx(STATE_ICON_SIZE)}:{hdpx(STATE_ICON_SIZE)}:K")
local stateBlock = @() {
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  children = [
    @() {
      rendObj = ROBJ_IMAGE
      color =  fire.value ? damageModule.alert : damageModule.inactive
      watch = fire
      image = picFire
      size = [hdpx(STATE_ICON_SIZE), hdpx(STATE_ICON_SIZE)]
    }
    buoyancyIndicator
  ]
}


local playAiSwithAnimation = function (ne_value) {
  ::anim_start(aiGunnersState)
}

local aiGunners = @() {
  vplace = ALIGN_BOTTOM
  size = [hdpx(STATE_ICON_SIZE), hdpx(STATE_ICON_SIZE)]
  marigin = [hdpx(STATE_ICON_MARGIN), 0]

  rendObj = ROBJ_IMAGE
  image = images.gunnerState?[aiGunnersState.value] ?? images.gunnerState[0]
  color = damageModule.active
  watch = aiGunnersState
  onAttach = @(elem) aiGunnersState.subscribe(playAiSwithAnimation)
  onDetach = @(elem) aiGunnersState.unsubscribe(playAiSwithAnimation)
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


local crewCountColor = Computed(function() {
  local minimum = minCrewMembersCount.value
  local current = aliveCrewMembersCount.value
  if (current < minimum) {
    return damageModule.dmModuleDestroyed
  } else if (current < minimum * 1.1) {
    return damageModule.dmModuleDamaged
  }
  return damageModule.active
})

local maxCrewLeftPercent = Computed(@() totalCrewMembersCount.value > 0
  ? (100.0 * (1.0 + (bestMinCrewMembersCount.value.tofloat() - minCrewMembersCount.value)
      / totalCrewMembersCount.value)
    + 0.5).tointeger()
  : 0
)
local countCrewLeftPercent = Computed(@()
  ::clamp(lerp(minCrewMembersCount.value - 1, totalCrewMembersCount.value,
      0, maxCrewLeftPercent.value, aliveCrewMembersCount.value),
    0, 100)
)

local crewBlock = @() {
  vplace = ALIGN_BOTTOM
  flow = FLOW_VERTICAL
  size = [hdpx(STATE_ICON_SIZE), SIZE_TO_CONTENT]

  children = [
    @() {
      size = [hdpx(STATE_ICON_SIZE), hdpx(STATE_ICON_SIZE)]
      marigin = [hdpx(STATE_ICON_MARGIN), 0]
      rendObj = ROBJ_IMAGE
      image = images.driver
      color = driverAlive.value ? damageModule.inactive : damageModule.alert
      watch = driverAlive
    }
    @() {
      size = [hdpx(STATE_ICON_SIZE), hdpx(STATE_ICON_SIZE)]
      marigin = [hdpx(STATE_ICON_MARGIN), 0]
      rendObj = ROBJ_IMAGE
      image = images.shipCrew
      color = crewCountColor.value
      watch = crewCountColor
    }
    @() {
      vplace = ALIGN_BOTTOM
      hplace = ALIGN_CENTER
      rendObj = ROBJ_DTEXT
      watch = countCrewLeftPercent
      text = $"{countCrewLeftPercent.value}%"
      font = Fonts.tiny_text_hud
      fontFx = fontFx
      fontFxColor = fontFxColor
    }
  ]
}

local steeringLine = {
  size = [hdpx(1), flex()]
  rendObj = ROBJ_SOLID
  color = shipSteeringGauge.serif
}

local steeringComp = {
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
      pos = [pw(-steering.value*50), -hdpx(5)]
    }
  ]
}


local function mkFov(pivot) {
  return @() {
    watch = [
      fwdAngle
      sightAngle
      fov
    ]
    pos = [pivot[0] - sh(15), pivot[1] - sh(15)]
    size = [sh(30), sh(30)]
    transform = {
      pivot = [0.5, 0.5]
      rotate = sightAngle.value - fwdAngle.value
      scale = [sin(fov.value), 1.0]
    }
    children = [
      {
        size = [flex(),flex()]
        rendObj = ROBJ_IMAGE
        image = images.sightCone
        color = Color(155, 255, 0, 120)
      }
      {
        size = [flex(),flex()]
        rendObj = ROBJ_IMAGE
        image = images.sightCone
        color = Color(155, 255, 0)
      }
    ]
  }
}

local function doll() {
  local dollSize = [sh(16), sh(32)]
  return {
    color = Color(0, 255, 0)
    size = dollSize
    rendObj = ROBJ_XRAYDOLL
    rotateWithCamera = false

    children = mkFov([dollSize[0]/2, (dollSize[1] + sh(4))/2])
  }
}


local leftBlock = damageModules

local rightBlock = @() {
  size = [SIZE_TO_CONTENT, flex()]
  flow = FLOW_VERTICAL
  children = [
    stateBlock
    { size = [SIZE_TO_CONTENT, flex()] }
    hasAiGunners.value ? aiGunners : null
    crewBlock
  ]
  watch = hasAiGunners
}


local shipStateDisplay = @() {
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


local xraydoll = {
  rendObj = ROBJ_XRAYDOLL     ///Need add ROBJ_XRAYDOLL in scene for correct update isVisibleDmgIndicator state
  size = [1, 1]
}

return @() setHudBg({
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  padding = isVisibleDmgIndicator.value ? hdpx(10) : 0
  gap = isVisibleDmgIndicator.value ? {size=[flex(),hdpx(5)]} : 0
  watch = isVisibleDmgIndicator
  behavior = Behaviors.RecalcHandler
  function onRecalcLayout(initial, elem) {
    if (elem.getWidth() > 1 && elem.getHeight() > 1) {
      ::cross_call.update_damage_panel_state({
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
})
