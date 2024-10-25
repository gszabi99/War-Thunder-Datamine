from "%rGui/globals/ui_library.nut" import *

let rwrSetting = require("%rGui/rwrSetting.nut")

let { rwrTargetsTriggers, rwrTargets, RwrSignalHoldTimeInv, RwrNewTargetHoldTimeInv, CurrentTime } = require("%rGui/twsState.nut")

let gridColor = Color(10, 202, 10, 250)
let targetColor = Color(250, 250, 10, 250)
let ownShipColor = Color(0, 250, 250, 250)

let styleText = {
  color = targetColor
  font = Fonts.hud
  fontFxColor = Color(0, 0, 0, 255)
  fontFxFactor = max(70, hdpx(90))
  fontFx = FFT_GLOW
  fontSize = getFontDefHt("hud") * 0.5
}

let gridCommands = [ [VECTOR_ELLIPSE, 0, 0, 100.0, 100.0] ]

function createGrid() {
  return {
    pos = [pw(50), ph(50)]
    size = flex()
    color = gridColor
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(3)
    fillColor = 0
    commands = gridCommands
  }
}

let ownShipCommands = [
  [VECTOR_ELLIPSE, 0, 0, 1.0, 1.0],
  [VECTOR_ELLIPSE, 0, 0, 5.0, 5.0]
]

function createOwnShip() {
  return {
    pos = [pw(50), ph(50)]
    size = flex()
    color = ownShipColor
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(2)
    fillColor = 0
    commands = ownShipCommands
  }
}

let ThreatType = {
  AD = 0
}

function calcRwrTargetRadius(target) {
  return 0.2 + 0.8 * target.rangeRel
}

function createRwrTarget(index, settings, fontSizeMult) {
  let target = rwrTargets[index]

  if (!target.valid || target.groupId == null)
    return @() { }

  let directionGroup = target.groupId >= 0 && target.groupId < settings.directionGroups.len() ? settings.directionGroups[target.groupId] : null
  let targetRadiusRel = calcRwrTargetRadius(target)

  let targetIconSizeRel = 0.04
  local targetType = null
  if (directionGroup == null || directionGroup?.text != null)
    targetType = @()
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [pw(target.x * 100.0 * targetRadiusRel), ph((target.y * targetRadiusRel - targetIconSizeRel) * 100.0)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = fontSizeMult * styleText.fontSize
        text = directionGroup != null ? directionGroup.text : "U"
      })

  let targetAttackIconSizeRel = targetIconSizeRel * 2.0
  let attackOpacityRwr = Computed(@() (target.launch && ((CurrentTime.value * 2.0).tointeger() % 2) == 0 ? 0.0 : 1.0))
  local attack = null
  if (target.track || target.launch) {
    attack = @() {
      watch = attackOpacityRwr
      color = targetColor
      opacity = attackOpacityRwr.get()
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(3)
      fillColor = 0
      size = flex()
      commands = [
        [ VECTOR_POLY,
          (target.x * targetRadiusRel - targetAttackIconSizeRel) * 100.0,
          (target.y * targetRadiusRel - targetAttackIconSizeRel) * 100.0,
          (target.x * targetRadiusRel + targetAttackIconSizeRel) * 100.0,
          (target.y * targetRadiusRel - targetAttackIconSizeRel) * 100.0,
          (target.x * targetRadiusRel + targetAttackIconSizeRel) * 100.0,
          (target.y * targetRadiusRel + targetAttackIconSizeRel) * 100.0,
          (target.x * targetRadiusRel - targetAttackIconSizeRel) * 100.0,
          (target.y * targetRadiusRel + targetAttackIconSizeRel) * 100.0 ],
        [ VECTOR_LINE_DASHED, 0.0, 0.0, target.x * targetRadiusRel * 100.0, target.y * targetRadiusRel * 100.0, 5, 10 ]
      ]
    }
  }

  let newTargetLineWidthMult = Computed(@() (target.age0 * RwrNewTargetHoldTimeInv.get() < 1.0 ? 3.0 : 1.0))
  let ageOpacity = Computed(@() (target.age * RwrSignalHoldTimeInv.get() < 0.25 ? 1.0 : 0.1))
  local icon = null
  if (directionGroup != null && directionGroup?.type != null) {
    local commands = null
    if (directionGroup.type == ThreatType.AD)
      commands = [
        [ VECTOR_POLY,
           target.x * targetRadiusRel * 100.0,
          (target.y * targetRadiusRel - targetIconSizeRel) * 100.0,
          (target.x * targetRadiusRel - targetIconSizeRel) * 100.0,
          (target.y * targetRadiusRel + targetIconSizeRel) * 100.0,
          (target.x * targetRadiusRel + targetIconSizeRel) * 100.0,
          (target.y * targetRadiusRel + targetIconSizeRel) * 100.0,
           target.x * targetRadiusRel * 100.0,
          (target.y * targetRadiusRel - targetIconSizeRel) * 100.0 ]
      ]
    if (commands != null) {
      icon = @() {
        watch = [newTargetLineWidthMult, ageOpacity]
        color = targetColor
        opacity = ageOpacity.get()
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = hdpx(3) * newTargetLineWidthMult.get()
        fillColor = 0
        size = flex()
        commands = commands
      }
    }
  }

  return @() {
    size = flex()
    children = [
      {
        pos = [pw(50), ph(50)]
        size = flex()
        children = [
          icon,
          attack
        ]
      },
      targetType
    ]
  }
}

let directionGroups = [
  {
    originalName = "hud/rwr_threat_ai"
  },
  //






  {
    text = "  3",
    originalName = "S125",
    type = ThreatType.AD
  },
  {
    text = "1 5",
    originalName = "9K3",
    type = ThreatType.AD
  },
  {
    text = "S 6",
    originalName = "2S6",
    type = ThreatType.AD
  },
  {
    text = "2 1",
    originalName = "S1",
    type = ThreatType.AD
  },
  {
    text = "R O",
    originalName = "RLD",
    type = ThreatType.AD
  },
  {
    text = "C T",
    originalName = "CRT",
    type = ThreatType.AD
  },
  {
    text = "S P",
    originalName = "hud/rwr_threat_sam",
    type = ThreatType.AD
  },
  {
    text = "G S",
    originalName = "hud/rwr_threat_aaa",
    type = ThreatType.AD
  },
  {
    text = "Z U",
    originalName = "Z23",
    type = ThreatType.AD
  },
  {
    text = "N V",
    originalName = "hud/rwr_threat_naval",
    type = ThreatType.AD
  },
  {
    text = "M M",
    originalName = "M"
  }
]

let settings = Computed(function() {
  let directionGroupOut = array(rwrSetting.get().direction.len())
  for (local i = 0; i < rwrSetting.value.direction.len(); ++i) {
    let direction = rwrSetting.value.direction[i]
    let directionGroupIndex = directionGroups.findindex(@(directionGroup) loc(directionGroup.originalName) == direction.text)
    if (directionGroupIndex != null) {
      let directionGroup = directionGroups[directionGroupIndex]
      directionGroupOut[i] = {
        text = directionGroup?.text
        type = directionGroup?.type
      }
    }
  }
  return { directionGroups = directionGroupOut }
})

let rwrTargetsComponent = function(fontSizeMult) {
  return @() {
    watch = [ rwrTargetsTriggers, settings ]
    size = flex()
    children = rwrTargets.map(@(_, i) createRwrTarget(i, settings.get(), fontSizeMult))
  }
}

function scope(scale, fontSizeMult) {
  return {
    size = [pw(scale), ph(scale)]
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = [
      createGrid(),
      createOwnShip(),
      rwrTargetsComponent(fontSizeMult)
    ]
  }
}

let function tws(posWatched, sizeWatched, scale, fontSizeMult) {
  return @() {
    watch = [posWatched, sizeWatched]
    size = sizeWatched.value
    pos = posWatched.value
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = scope(scale, fontSizeMult)
  }
}

return tws