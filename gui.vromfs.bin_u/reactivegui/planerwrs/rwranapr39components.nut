from "%rGui/globals/ui_library.nut" import *

let rwrSetting = require("%rGui/rwrSetting.nut")

let { rwrTargetsTriggers, rwrTargets, rwrTargetsOrder, RwrSignalHoldTimeInv, CurrentTime } = require("%rGui/twsState.nut")

let color = Color(10, 202, 10, 250)
let backgroundColor = Color(0, 0, 0, 255)

let baseLineWidth = LINE_WIDTH * 0.5

let styleText = {
  color = color
  font = Fonts.hud
  fontFxColor = Color(0, 0, 0, 255)
  fontFxFactor = max(70, baseLineWidth * 90)
  fontFx = FFT_GLOW
  fontSize = getFontDefHt("hud") * 2.5
}

let ThreatType = {
  AI = 0,
  AAA = 1,
  ZSU23 = 2,
  WEAPON = 4
}

function calcRwrTargetRadius(target) {
  return 0.2 + 0.8 * target.rangeRel
}

function createRwrTarget(index, settings, objectStyle) {
  let target = rwrTargets[rwrTargetsOrder[index]]

  if (!target.valid || target.groupId == null)
    return @() { }

  let directionGroup = target.groupId >= 0 && target.groupId < settings.directionGroups.len() ? settings.directionGroups[target.groupId] : null
  let targetRadiusRel = calcRwrTargetRadius(target)

  local targetType = null
  if (directionGroup == null || directionGroup?.text != null)
    targetType = @()
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [pw(target.x * 100.0 * targetRadiusRel), ph(target.y * 100.0 * targetRadiusRel)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = objectStyle.fontScale * styleText.fontSize
        text = directionGroup != null ? directionGroup.text : settings.unknownText
      })

  let targetIconSizeRel = 0.07 * objectStyle.scale
  let targetAttackIconSizeRel = targetIconSizeRel * 1.3
  let attackOpacityRwr = Computed(@() (target.launch && ((CurrentTime.get() * 2.0).tointeger() % 2) == 0 ? 0.0 : 1.0))
  local attack = null
  if (target.track || target.launch) {
    attack = @() {
      watch = attackOpacityRwr
      color = color
      opacity = attackOpacityRwr.get()
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = baseLineWidth * 2 * objectStyle.lineWidthScale
      fillColor = 0
      size = [pw(100), ph(100)]
      commands = [
        [ VECTOR_POLY,
          (target.x * targetRadiusRel - targetAttackIconSizeRel) * 100.0,
          (target.y * targetRadiusRel - targetAttackIconSizeRel) * 100.0,
          (target.x * targetRadiusRel + targetAttackIconSizeRel) * 100.0,
          (target.y * targetRadiusRel - targetAttackIconSizeRel) * 100.0,
          (target.x * targetRadiusRel + targetAttackIconSizeRel) * 100.0,
          (target.y * targetRadiusRel + targetAttackIconSizeRel) * 100.0,
          (target.x * targetRadiusRel - targetAttackIconSizeRel) * 100.0,
          (target.y * targetRadiusRel + targetAttackIconSizeRel) * 100.0 ]
       ]
    }
  }

  local iconColor = backgroundColor
  local commands = [
    [ VECTOR_RECTANGLE,
      (target.x * targetRadiusRel - targetAttackIconSizeRel) * 100.0,
      (target.y * targetRadiusRel - targetAttackIconSizeRel) * 100.0,
      targetAttackIconSizeRel * 2.0 * 100.0,
      targetAttackIconSizeRel * 2.0 * 100.0 ]
    ]

  if (directionGroup != null && directionGroup?.type != null) {
    iconColor = color
    if (directionGroup.type == ThreatType.AI)
      commands = [
        [ VECTOR_POLY,
          target.x * targetRadiusRel * 100.0,
          (target.y * targetRadiusRel - 0.5 * targetIconSizeRel) * 100.0,
          (target.x * targetRadiusRel - targetIconSizeRel) * 100.0,
          (target.y * targetRadiusRel + 0.5 * targetIconSizeRel) * 100.0,
           target.x * targetRadiusRel * 100.0,
           target.y * targetRadiusRel * 100.0,
          (target.x * targetRadiusRel + targetIconSizeRel) * 100.0,
          (target.y * targetRadiusRel + 0.5 * targetIconSizeRel) * 100.0 ]
      ]
    else if (directionGroup.type == ThreatType.AAA)
      commands = [
        [ VECTOR_POLY,
           target.x * targetRadiusRel * 100.0,
          (target.y * targetRadiusRel - targetIconSizeRel) * 100.0,
          (target.x * targetRadiusRel - targetIconSizeRel) * 100.0,
          (target.y * targetRadiusRel + targetIconSizeRel) * 100.0,
          (target.x * targetRadiusRel + targetIconSizeRel) * 100.0,
          (target.y * targetRadiusRel + targetIconSizeRel) * 100.0 ]
      ]
    else if (directionGroup.type == ThreatType.ZSU23)
      commands = [
        [ VECTOR_POLY,
           target.x * targetRadiusRel * 100.0,
          (target.y * targetRadiusRel - targetIconSizeRel) * 100.0,
          (target.x * targetRadiusRel - targetIconSizeRel) * 100.0,
          (target.y * targetRadiusRel + targetIconSizeRel) * 100.0,
          (target.x * targetRadiusRel + targetIconSizeRel) * 100.0,
          (target.y * targetRadiusRel + targetIconSizeRel) * 100.0,
           target.x * targetRadiusRel * 100.0 ],
        [ VECTOR_LINE,
           target.x * targetRadiusRel * 100.0,
           target.y * targetRadiusRel * 100.0,
          (target.x * targetRadiusRel + targetIconSizeRel) * 100.0,
          (target.y * targetRadiusRel - targetIconSizeRel) * 100.0 ]
      ]
    else if (directionGroup.type == ThreatType.WEAPON)
      commands = [
        [ VECTOR_POLY,
           target.x * targetRadiusRel * 100.0,
          (target.y * targetRadiusRel - 0.25 * targetIconSizeRel - 0.5 * targetIconSizeRel) * 100.0,
          (target.x * targetRadiusRel - 0.5 * targetIconSizeRel) * 100.0,
          (target.y * targetRadiusRel - 0.25 * targetIconSizeRel + 0.5 * targetIconSizeRel) * 100.0,
          (target.x * targetRadiusRel + 0.5 * targetIconSizeRel) * 100.0,
          (target.y * targetRadiusRel - 0.25 * targetIconSizeRel + 0.5 * targetIconSizeRel) * 100.0,
           target.x * targetRadiusRel * 100.0,
          (target.y * targetRadiusRel - 0.25 * targetIconSizeRel - 0.5 * targetIconSizeRel) * 100.0 ],
        [ VECTOR_POLY,
           target.x * targetRadiusRel * 100.0,
          (target.y * targetRadiusRel + 0.25 * targetIconSizeRel - 0.5 * targetIconSizeRel) * 100.0,
          (target.x * targetRadiusRel - 0.5 * targetIconSizeRel) * 100.0,
          (target.y * targetRadiusRel + 0.25 * targetIconSizeRel + 0.5 * targetIconSizeRel) * 100.0,
          (target.x * targetRadiusRel + 0.5 * targetIconSizeRel) * 100.0,
          (target.y * targetRadiusRel + 0.25 * targetIconSizeRel + 0.5 * targetIconSizeRel) * 100.0,
           target.x * targetRadiusRel * 100.0,
          (target.y * targetRadiusRel + 0.25 * targetIconSizeRel - 0.5 * targetIconSizeRel) * 100.0 ]
        ]
  }

  let icon = @() {
    color = iconColor
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 2 * objectStyle.lineWidthScale
    fillColor = backgroundColor
    size = [pw(100), ph(100)]
    commands = commands
  }

  let ageOpacity = Computed(@() 1.0 - min(target.age * RwrSignalHoldTimeInv.get(), 1.0))

  return @() {
    size = flex()
    watch = ageOpacity
    opacity = ageOpacity.get()
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
    originalName = "hud/rwr_threat_ai",
    type = ThreatType.AI
  },
  





  {
    text = "3",
    originalName = "S125"
  },
  {
    text = "8",
    originalName = "93"
  },
  {
    text = "15",
    originalName = "9K3"
  },
  {
    originalName = "hud/rwr_threat_aaa",
    type = ThreatType.AAA
  },
  {
    originalName = "Z23",
    type = ThreatType.ZSU23
  },
  {
    originalName = "MSL",
    type = ThreatType.WEAPON
  }
]

let settings = Computed(function() {
  let directionGroupOut = array(rwrSetting.get().direction.len())
  for (local i = 0; i < rwrSetting.get().direction.len(); ++i) {
    let direction = rwrSetting.get().direction[i]
    let directionGroupIndex = directionGroups.findindex(@(directionGroup) loc(directionGroup.originalName) == direction.text)
    if (directionGroupIndex != null) {
      let directionGroup = directionGroups[directionGroupIndex]
      directionGroupOut[i] = {
        text = directionGroup?.text
        type = directionGroup?.type
      }
    }
  }
  return { directionGroups = directionGroupOut, unknownText = "U" }
})

let rwrTargetsComponent = function(style) {
  return @() {
    watch = [ rwrTargetsTriggers, settings ]
    size = flex()
    children = rwrTargets.map(@(_, i) createRwrTarget(i, settings.get(), style))
  }
}

return {
  color,
  baseLineWidth,
  rwrTargetsComponent
}