from "%rGui/globals/ui_library.nut" import *

let { eventbus_send } = require("eventbus")
let { brokenEnginesCount, enginesInCooldown, enginesCount,
  transmissionCount, brokenTransmissionCount, transmissionsInCooldown, torpedosCount, brokenTorpedosCount, artilleryType,
  artilleryCount, brokenArtilleryCount, steeringGearsCount, brokenSteeringGearsCount, fire, aiGunnersState, buoyancy,
  steering, sightAngle, fwdAngle, hasAiGunners, fov, blockMoveControl, burningParts
} = require("%rGui/shipState.nut")
let { speedValue, speedUnits, machineSpeed } = require("%rGui/hud/shipStateView.nut")
let { driverAlive } = require("%rGui/crewState.nut")
let { needShowDmgIndicator, isUnitAlive } = require("%rGui/hudState.nut")
let dmModule = require("%rGui/dmModule.nut")
let { crewLifebar } = require("%rGui/crewLifebar.nut")
let { sin } = require("%sqstd/math.nut")
let { hud } = require("%rGui/style/colors.nut")
let { damageIndicatorScale } = require("%rGui/options/options.nut")

const STATE_ICON_SIZE = 54
const FIRE_ICON_SIZE = 24
const STEERING_GEAR_SIZE = 30

let iconSize = Computed(@() hdpxi(damageIndicatorScale.get() * STATE_ICON_SIZE))
let iconFireSize = Computed(@() hdpxi(damageIndicatorScale.get() * FIRE_ICON_SIZE))
let iconGearSize = Computed(@() hdpxi(damageIndicatorScale.get() * STEERING_GEAR_SIZE))

let { damageModule, shipSteeringGauge, hudLogBgColor } = hud
let boxWidth = Computed(@() hdpx(damageIndicatorScale.get() < 1 ? 150 * damageIndicatorScale.get() : 200))

let maxFontBoxHeight = hdpx(18.5)

let speedComp = {
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  hplace = ALIGN_CENTER
  halign = ALIGN_RIGHT
  valign = ALIGN_CENTER

  children = [
    { size = flex() }
    @() {
      watch = boxWidth
      size = const [flex(2.9), SIZE_TO_CONTENT]
      children = machineSpeed({ box = [boxWidth.get(), maxFontBoxHeight], fontSize = maxFontBoxHeight })
      halign = ALIGN_RIGHT
    }
    {
      size = const [flex(2.1), SIZE_TO_CONTENT]
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
  icon = "!ui/gameuiskin#engine_state_indicator.svg"
  totalCountState = enginesCount
  brokenCountState = brokenEnginesCount
  cooldownState = enginesInCooldown
  iconSizeWatch = iconSize
})

let transmission = dmModule({
  icon = "!ui/gameuiskin#ship_transmission_state_indicator.svg"
  totalCountState = transmissionCount
  brokenCountState = brokenTransmissionCount
  cooldownState = transmissionsInCooldown
  iconSizeWatch = iconSize
})
let torpedo = dmModule({
  icon = "!ui/gameuiskin#ship_torpedo_weapon_state_indicator.svg"
  totalCountState = torpedosCount
  brokenCountState = brokenTorpedosCount
  iconSizeWatch = iconSize
})

let artIcons = {
  [TRIGGER_GROUP_PRIMARY]         = "!ui/gameuiskin#artillery_weapon_state_indicator.svg",
  [TRIGGER_GROUP_SECONDARY]       = "!ui/gameuiskin#artillery_secondary_weapon_state_indicator.svg",
  [TRIGGER_GROUP_MACHINE_GUN]     = "!ui/gameuiskin#machine_gun_weapon_state_indicator.svg",
}
let artillery = dmModule({
  icon = @(art_type) artIcons?[art_type] ?? artIcons[TRIGGER_GROUP_PRIMARY]
  iconWatch = artilleryType
  totalCountState = artilleryCount
  brokenCountState = brokenArtilleryCount
  iconSizeWatch = iconSize
})
let steeringGears = dmModule({
  icon = "!ui/gameuiskin#ship_steering_gear_state_indicator.svg"
  totalCountState = steeringGearsCount
  brokenCountState = brokenSteeringGearsCount
  iconSizeWatch = iconGearSize
})

let damageModules = {
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  gap = hdpx(10)
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
  size = FLEX_H
  maxWidth = iconSize.get()
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  watch = [buoyancyOpacity, iconSize]
  opacity = buoyancyOpacity.get()
  children = [
    @() {
      watch = buoyancyPercent
      rendObj = ROBJ_TEXT
      text = $"{buoyancyPercent.get()}%"
      font = Fonts.small_text_hud
    }
    {
      size = [iconSize.get(), hdpx(10)]
      rendObj = ROBJ_IMAGE
      image = Picture($"!ui/gameuiskin#buoyancy_icon.svg:{iconSize.get()}:{iconSize.get()}")
    }
  ]
}

let stateBlock = {
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  children = [
    @() {
      watch = [fire, iconSize]
      size = [iconSize.get(), iconSize.get()]
      rendObj = ROBJ_IMAGE
      color =  fire.get() ? damageModule.alert : damageModule.inactive
      image = Picture($"!ui/gameuiskin#fire_indicator.svg:{iconSize.get()}:{iconSize.get()}:K")
    }
    buoyancyIndicator
  ]
}

let playAiSwithAnimation = @(_ne_value) anim_start(aiGunnersState)

const gunnerStateImages = [ 
  $"!ui/gameuiskin#ship_gunner_state_hold_fire.svg"
  $"!ui/gameuiskin#ship_gunner_state_fire_at_will.svg"
  $"!ui/gameuiskin#ship_gunner_state_air_targets.svg"
  $"!ui/gameuiskin#ship_gunner_state_naval_targets.svg"
]
function aiGunners() {
  let gunnerImage = gunnerStateImages?[aiGunnersState.get()] ?? gunnerStateImages[0]
  return {
    watch = [aiGunnersState, iconSize]
    vplace = ALIGN_BOTTOM
    size = [iconSize.get(), iconSize.get()]
    rendObj = ROBJ_IMAGE
    image = Picture($"{gunnerImage}:{iconSize.get()}:{iconSize.get()}")
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
}

let driverIndicator = @() {
  watch = [driverAlive, blockMoveControl, iconSize]
  size = [iconSize.get(), iconSize.get()]
  rendObj = ROBJ_IMAGE
  image = Picture($"!ui/gameuiskin#ship_crew_driver.svg:{iconSize.get()}:{iconSize.get()}")
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
      watch = [steering, iconSize]
      size = const [hdpx(12), hdpx(10)]
      pos = [pw(-steering.get() * 50), -hdpx(5)]
      hplace = ALIGN_CENTER
      rendObj = ROBJ_IMAGE
      image = Picture($"!ui/gameuiskin#floatage_arrow_down.svg:{iconSize.get()}:{iconSize.get()}")
      color = shipSteeringGauge.mark
    }
  ]
}

let dollSize = Computed(@() [
  sh(16 * damageIndicatorScale.get()),
  sh(32 * damageIndicatorScale.get())
])
let fovSize = Computed(@() [
  sh(30 * damageIndicatorScale.get()),
  sh(30 * damageIndicatorScale.get())
])
let fovTopOffset = Computed(@() sh(2 * damageIndicatorScale.get()))

let fovPos = Computed(@() [0.5 * dollSize.get()[0] - 0.5 * fovSize.get()[0],
  0.5 * dollSize.get()[1] - 0.5 * fovSize.get()[1] + fovTopOffset.get()])

let dollFov = @() {
  watch = [fwdAngle, sightAngle, fov, fovSize, fovPos]
  pos = fovPos.get()
  size = fovSize.get()
  transform = {
    pivot = [0.5, 0.5]
    rotate = sightAngle.get() - fwdAngle.get()
    scale = [sin(fov.get()), 1.0]
  }
  children = [
    {
      size = flex()
      rendObj = ROBJ_IMAGE
      image = Picture("+ui/gameuiskin#map_camera")
      color = Color(155, 255, 0, 120)
    }
    {
      size = flex()
      rendObj = ROBJ_IMAGE
      image = Picture("+ui/gameuiskin#map_camera")
      color = Color(155, 255, 0)
    }
  ]
}


function makeFireIcons(burningPartsTable, dollSizeVals, iconFireSizeVal) {
  if (burningPartsTable.len() == 0)
    return []

  let blinkTime = 1.3
  let icons = []
  let scaleFactor = max(dollSizeVals[0], dollSizeVals[1])
  foreach (partId, pos in burningPartsTable) {
    let x = dollSizeVals[0] * 0.5 - iconFireSizeVal * 0.5 + pos.x * scaleFactor
    let y = dollSizeVals[1] * 0.5 - iconFireSizeVal * 0.5 + pos.y * scaleFactor
    icons.append({
      key = $"fireOutline_{partId}"
      pos = [x, y]
      size = [iconFireSizeVal, iconFireSizeVal]
      rendObj = ROBJ_IMAGE
      image = Picture($"!ui/gameuiskin#fire_indicator_outline.avif:{iconFireSizeVal}:{iconFireSizeVal}")
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
      size = [iconFireSizeVal, iconFireSizeVal]
      rendObj = ROBJ_IMAGE
      image = Picture($"!ui/gameuiskin#fire_indicator.svg:{iconFireSizeVal}:{iconFireSizeVal}:K")
      color =  damageModule.fire
      animations = [
        { prop = AnimProp.opacity, from = 0, to = 1, play = true, loop = true, duration = blinkTime, easing = CosineFull }
      ]
    })
  }
  return icons
}

let fireIconsOverlay = @() {
  watch = [burningParts, dollSize, iconFireSize]

  size = dollSize.get()
  children = makeFireIcons(burningParts.get(), dollSize.get(), iconFireSize.get())
}

let doll = @() {
  watch = dollSize
  color = Color(0, 255, 0)
  size = dollSize.get()
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
    { size = [flex(), hdpx(7)] }
    steeringGears
    steeringComp
  ]
}

let xraydoll = {
  size = 1
  rendObj = ROBJ_XRAYDOLL     
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
  watch = [needShowDmgIndicator, isUnitAlive]
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

  children = [
    isUnitAlive.get() ? crewLifebar : null
    needShowDmgIndicator.get() ? mainPanel : xraydoll
  ]
}
