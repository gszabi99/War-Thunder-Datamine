from "%rGui/globals/ui_library.nut" import *

let rwrSetting = require("%rGui/rwrSetting.nut")

let string = require("string")
let math = require("math")
let { degToRad, radToDeg } = require("%sqstd/math_ex.nut")

let u = require("%sqStdLibs/helpers/u.nut")

let { rwrTargetsTriggers, rwrTargets, CurrentTime } = require("%rGui/twsState.nut")

let color = Color(10, 202, 10, 250)

let styleText = {
  color = color
  font = Fonts.hud
  fontFxColor = Color(0, 0, 0, 255)
  fontFxFactor = max(70, hdpx(90))
  fontFx = FFT_GLOW
  fontSize = getFontDefHt("hud")
}

let gridRadius = 1.00

function makePolarGridCommands() {
  let commands = [
    [VECTOR_ELLIPSE, 0, 0, gridRadius * 100.0, gridRadius * 100.0]
  ]
  for (local az = 0.0; az < 360.0; az += 30)
    commands.append([ VECTOR_LINE,
                      math.sin(degToRad(az)) * (gridRadius - 0.05) * 100.0, math.cos(degToRad(az)) * (gridRadius - 0.05) * 100.0,
                      math.sin(degToRad(az)) * gridRadius          * 100.0, math.cos(degToRad(az)) * gridRadius          * 100.0])
  return commands
}

let polarGridCommands = makePolarGridCommands()

function createPolarGrid() {
  return {
    pos = [pw(50), ph(50)]
    size = flex()
    color = color
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(2)
    fillColor = 0
    commands = polarGridCommands
  }
}

let tabularGridCommands = [
  [VECTOR_RECTANGLE, -50.0, -80.0, 50.0, 80.0]
]

function createTabularGrid() {
  return {
    size = flex()
    color = color
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(2)
    fillColor = 0
    commands = tabularGridCommands
  }
}

function compareRwrTarget(left, right) {
  return left.rangeRel <=> right.rangeRel
}

function makeTargetsText(settings) {
  local text = ""
  local rwrTargetsSorted = u.copy(rwrTargets)
  rwrTargetsSorted.sort(compareRwrTarget)
  for (local i = 0; i < rwrTargetsSorted.len(); ++i) {
    let target = rwrTargetsSorted[i]
    if (!target.valid || target.groupId == null)
      continue
    let azDeg = math.floor(radToDeg(math.atan2(target.x, -target.y)) + 0.5)
    let directionGroup = target.groupId >= 0 && target.groupId < settings.directionGroups.len() ? settings.directionGroups[target.groupId] : null
    text = "".concat(text, directionGroup != null ? directionGroup.text : settings.unknownText)
    text = "".concat(text, string.format("  %03d\r\n", azDeg))
    text = "".concat(text, directionGroup != null ? directionGroup.desc : settings.unknownText)
    text = "".concat(text, "\r\n")
  }
  return text
}

function calcRwrTargetRadius(target) {
  return 0.2 + target.rangeRel * 0.8
}

function createRwrTarget(index, settings, fontSizeMult) {
  let target = rwrTargets[index]

  if (!target.valid || target.groupId == null)
    return @() { }

  let directionGroup = target.groupId >= 0 && target.groupId < settings.directionGroups.len() ? settings.directionGroups[target.groupId] : null

  local targetText = @()
    styleText.__merge({
      rendObj = ROBJ_TEXT
      pos = [pw(target.x * 110.0), ph(target.y * 110.0)]
      size = flex()
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      fontSize = fontSizeMult * styleText.fontSize * 0.75
      text = directionGroup != null ? directionGroup.text : settings.unknownText
    })

  let attackOpacityRwr = Computed(@() ((target.launch || target.track) && ((CurrentTime.get() * (target.launch ? 4.0 : 2.0)).tointeger() % 2) == 0 ? 0.0 : 1.0))
  let targetRadiusRel = calcRwrTargetRadius(target)
  let azimuth = @() {
    watch = attackOpacityRwr
    color = color
    opacity = attackOpacityRwr.get()
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(5)
    fillColor = 0
    size = flex()
    commands = [
      [ VECTOR_LINE, target.x * targetRadiusRel * 100.0, target.y * targetRadiusRel * 100.0, target.x * 100.0, target.y * 100.0]
    ]
  }

  return @() {
    size = flex()
    children = [
      {
        pos = [pw(50), ph(50)]
        size = flex()
        children = [
          azimuth
        ]
      },
      targetText
    ]
  }
}

function createTargetsList(settings, fontSizeMult) {
  let targetsText = makeTargetsText(settings)
  return targetsText.len() > 0 ? @()
    styleText.__merge({
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      pos = [pw(-75), ph(-80)]
      size = flex()
      halign = ALIGN_CENTER
      valign = ALIGN_TOP
      fontSize = fontSizeMult * styleText.fontSize
      text = targetsText
    }) : @() {}
}

let directionGroups = [
  {
    text = "A"
    desc = "A"

    originalName = "F"
  },
  {
    text = "A"
    desc = "A"

    originalName = "A"
  },
  {
    text = "Y"
    desc = "FISHBED"

    originalName = "M21"
  },
  {
    text = "Y"
    desc = "FLOGGER"

    originalName = "M23"
  },
  {
    text = "Y"
    desc = "SLOTBACK"

    originalName = "M29"
  },
  {
    text = "V"
    desc = "FENCER"

    originalName = "S24"
  },
  {
    text = "F"
    desc = "F-4 AI"

    originalName = "F4"
  },
  {
    text = "F"
    desc = "F-4E AI"

    originalName = "F4E"
  },
  {
    text = "F"
    desc = "F-4J AI"

    originalName = "F4J"
  },
  {
    text = "F"
    desc = "F-5 AI"

    originalName = "F5"
  },
  {
    text = "F"
    desc = "F-14 AI"

    originalName = "F14"
  },
  {
    text = "F"
    desc = "F-16 AI"

    originalName = "F16"
  },
  {
    text = "F"
    desc = "F-15 AI"

    originalName = "F15"
  },
  {
    text = "F"
    desc = "F-18 AI"

    originalName = "F18"
  },
  {
    text = "F"
    desc = "F3 AI"

    originalName = "TRF"
  },
  {
    text = "F"
    desc = "BLUE FOX"

    originalName = "HRR"
  },
  {
    text = "W"
    desc = "BUCANER"

    originalName = "BCR"
  },
  {
    text = "F"
    desc = "MIRAG3AI"

    originalName = "M3"
  },
  {
    text = "F"
    desc = "MIRAF5AI"

    originalName = "M5"
  },
  {
    text = "F"
    desc = "MIRAG F1"

    originalName = "MF1"
  },
  {
    text = "F"
    desc = "MIRAG 20"

    originalName = "M2K"
  },
  {
    text = "F"
    desc = "LANSN AI"

    originalName = "A32"
  },
  {
    text = "F"
    desc = "DRAKN AI"

    originalName = "J35"
  },
  {
    text = "F"
    desc = "VIGEN AI"

    originalName = "J37"
  },
  {
    text = "F"
    desc = "GRIPN AI"

    originalName = "J39"
  },
  {
    text = "Y"
    desc = "THUNDER"

    originalName = "J17"
  },
  {
    text = "L"
    desc = "L"

    originalName = "hud/rwr_threat_aaa"
  },
  {
    text = "Z"
    desc = "Z"

    originalName = "Z23"
  },
  {
    text = "Z"
    desc = "Z"

    originalName = "Z37"
  },
  {
    text = "L"
    desc = "L"

    originalName = "MSM"
  },
  //







  {
    text = "3"
    desc = "SA-3"

    originalName = "S125"
  },
  {
    text = "15"
    desc = "SA-15"

    originalName = "9K3"
  },
  {
    text = "19"
    desc = "SA-19"

    originalName = "2S6"
  },
  {
    text = "L"
    desc = "CROTL"

    originalName = "RLD"
  },
  {
    text = "L"
    desc = "CROTL"

    originalName = "CRT"
  },
  {
    text = "N"
    desc = "N"

    originalName = "hud/rwr_threat_naval"
  },
  {
    text = "P"
    desc = "P"

    originalName = "MSL"
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
        text = directionGroup.text
        desc = directionGroup.desc
      }
    }
  }
  return { directionGroups = directionGroupOut, unknownText = "?" }
})

function rwrTargetsListComponent(fontSizeMult) {
  return @() {
    watch = [ rwrTargetsTriggers, settings ]
    size = flex()
    children = createTargetsList(settings.get(), fontSizeMult)
  }
}

function rwrTargetsComponent(fontSizeMult) {
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
      {
        pos = [pw(140), ph(130)]
        size = [pw(100), ph(180)]
        children = [
          createTabularGrid(),
          rwrTargetsListComponent(fontSizeMult)
        ]
      }
      {
        pos = [pw(-30), ph(20)]
        size = [pw(70), ph(70)]
        children = [
          createPolarGrid(),
          rwrTargetsComponent(fontSizeMult)
        ]
      }
    ]
  }
}

let function tws(posWatched, sizeWatched, scale, fontSizeMult) {
  return @() {
    watch = [posWatched, sizeWatched]
    size = sizeWatched.get()
    pos = posWatched.get()
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = scope(scale, fontSizeMult)
  }
}

return tws