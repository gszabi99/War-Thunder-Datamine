from "%rGui/globals/ui_library.nut" import *

let rwrSetting = require("%rGui/rwrSetting.nut")
let { rwrTargetsTriggers, rwrTargets } = require("%rGui/twsState.nut")

let { ThreatType, baseLineWidth, createCompass, createRwrGrid, createRwrGridMarks, createRwrTarget } = require("rwrAr830Components.nut")

let backGroundColor = Color(0, 0, 0, 255)
let color = Color(255, 255, 255, 255)
let iconColor = Color(200, 0, 0, 255)

let styleText = {
  color = color
  font = Fonts.hud
  fontFxColor = Color(0, 0, 0, 255)
  fontFxFactor = max(70, baseLineWidth * 90)
  fontSize = 10
}

let directionGroups = [
  {
    text = "AI",
    type = ThreatType.AI,
    originalName = "hud/rwr_threat_ai",
    lethalRangeMax = 5000.0
  },
  {
    text = "ATK",
    type = ThreatType.AI,
    originalName = "hud/rwr_threat_attacker",
    lethalRangeMax = 8000.0
  },
  {
    text = "M21",
    type = ThreatType.AI,
    originalName = "M21"
    lethalRangeMax = 5000.0
  },
  {
    text = "M23",
    type = ThreatType.AI,
    originalName = "M23",
    lethalRangeMax = 40000.0
  },
  {
    text = "M29",
    type = ThreatType.AI,
    originalName = "M29",
    lethalRangeMax = 40000.0
  },
  {
    text = "S34",
    type = ThreatType.AI,
    originalName = "S34",
    lethalRangeMax = 40000.0
  },
  {
    text = "S24",
    type = ThreatType.AI,
    originalName = "S24",
  },
  {
    text = "F4",
    type = ThreatType.AI,
    originalName = "F4",
    lethalRangeMax = 40000.0
  },
  {
    text = "F4E",
    type = ThreatType.AI,
    originalName = "F4E",
    lethalRangeMax = 40000.0
  },
  {
    text = "F4J",
    type = ThreatType.AI,
    originalName = "F4J",
    lethalRangeMax = 40000.0
  },
  {
    text = "F5",
    type = ThreatType.AI,
    originalName = "F5",
    lethalRangeMax = 5000.0
  },
  {
    text = "F14",
    type = ThreatType.AI,
    originalName = "F14",
    lethalRangeMax = 40000.0
  },
  {
    text = "F15",
    type = ThreatType.AI,
    originalName = "F15",
    lethalRangeMax = 40000.0
  },
  {
    text = "F16",
    type = ThreatType.AI,
    originalName = "F16",
    lethalRangeMax = 40000.0
  },
  {
    text = "F18",
    type = ThreatType.AI,
    originalName = "F18",
    lethalRangeMax = 40000.0
  },
  {
    text = "HRR",
    type = ThreatType.AI,
    originalName = "HRR",
    lethalRangeMax = 5000.0
  },
  {
    text = "E2K",
    type = ThreatType.AI,
    originalName = "E2K",
    lethalRangeMax = 40000.0
  },
  {
    text = "BCR",
    type = ThreatType.AI,
    originalName = "BCR",
  },
  {
    text = "TRF",
    type = ThreatType.AI,
    originalName = "TRF",
    lethalRangeMax = 30000.0
  },
  {
    text = "M3",
    type = ThreatType.AI,
    originalName = "M3",
    lethalRangeMax = 20000.0
  },
  {
    text = "M5",
    type = ThreatType.AI,
    originalName = "M5",
    lethalRangeMax = 20000.0
  },
  {
    text = "MF1",
    type = ThreatType.AI,
    originalName = "MF1",
    lethalRangeMax = 30000.0
  },
  {
    text = "M20",
    type = ThreatType.AI,
    originalName = "M2K",
    lethalRangeMax = 40000.0
  },
  {
    text = "RFL",
    type = ThreatType.AI,
    originalName = "RFL",
    lethalRangeMax = 40000.0
  },
  {
    text = "A32",
    type = ThreatType.AI,
    originalName = "A32",
    lethalRangeMax = 5000.0
  },
  {
    text = "J35",
    type = ThreatType.AI,
    originalName = "J35",
    lethalRangeMax = 5000.0
  },
  {
    text = "J37",
    type = ThreatType.AI,
    originalName = "J37",
    lethalRangeMax = 30000.0
  },
  {
    text = "J39",
    type = ThreatType.AI,
    originalName = "J39",
    lethalRangeMax = 40000.0
  },
  {
    text = "J17",
    type = ThreatType.AI,
    originalName = "J17",
    lethalRangeMax = 40000.0
  },
  //







  {
    text = "SA3",
    originalName = "S125",
    type = ThreatType.SAM,
    lethalRangeMax = 16000.0
  },
  {
    text = "SA8",
    originalName = "93",
    type = ThreatType.SAM,
    lethalRangeMax = 12000.0
  },
  {
    text = "SA15",
    originalName = "9K3",
    type = ThreatType.SAM,
    lethalRangeMax = 12000.0
  },
  {
    text = "SA19",
    originalName = "2S6",
    type = ThreatType.SAM,
    lethalRangeMax = 8000.0
  },
  {
    text = "S1",
    originalName = "S1",
    type = ThreatType.SAM,
    lethalRangeMax = 16000.0
  },
  {
    text = "AD",
    originalName = "ADS",
    lethalRangeMax = 8000.0
  },
  {
    text = "RLD",
    originalName = "RLD",
    type = ThreatType.SAM,
    lethalRangeMax = 12000.0
  },
  {
    text = "CRT",
    originalName = "CRT",
    type = ThreatType.SAM,
    lethalRangeMax = 12000.0
  },
  {
    text = "AR",
    originalName = "ASR",
    lethalRangeMax = 8000.0
  },
  {
    text = "AAA",
    originalName = "hud/rwr_threat_aaa",
    type = ThreatType.AAA,
    lethalRangeMax = 4000.0
  },
  {
    text = "ZSU",
    originalName = "Z23",
    type = ThreatType.AAA,
    lethalRangeMax = 2500.0
  },
  {
    text = "ZSU",
    originalName = "Z37",
    type = ThreatType.AAA,
    lethalRangeMax = 3500.0
  },
  {
    text = "MSM",
    originalName = "MSM",
    type = ThreatType.AAA,
    lethalRangeMax = 3000.0
  },
  {
    text = "GPD",
    originalName = "GPD",
    type = ThreatType.AAA,
    lethalRangeMax = 3500.0
  },
  {
    text = "NVL",
    originalName = "hud/rwr_threat_naval",
    lethalRangeMax = 16000.0
  },
  {
    text = "MSL",
    originalName = "MSL",
    type = ThreatType.MSL,
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
        lethalRangeRel = directionGroup?.lethalRangeMax != null ? (directionGroup.lethalRangeMax - rwrSetting.get().range.x) / (rwrSetting.get().range.y - rwrSetting.get().range.x) : null
      }
    }
  }
  return { directionGroups = directionGroupOut, rangeMinRel = rwrSetting.get().range.x / rwrSetting.get().range.y, rangeMax = rwrSetting.get().range.y, unknownText = "UNK" }
})

function rwrGridMarksComponent(gridStyle) {
  return @() {
    watch = settings
    size = flex()
    children = createRwrGridMarks(gridStyle, styleText, settings.get())
  }
}

function rwrTargetsComponent(objectStyle) {
  return @() {
    watch = [ rwrTargetsTriggers, settings ]
    size = flex()
    children = rwrTargets.map(@(_, i) createRwrTarget(i, settings.get(), objectStyle, iconColor, backGroundColor, styleText))
  }
}

function scope(scale, style) {
  return {
    size = [pw(scale), ph(scale)]
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = [
      {
        pos = [pw(-20), ph(-25)],
        size = [pw(150 * style.grid.scale), ph(150 * style.grid.scale)],
        children = [
          {
            pos = [pw(10), ph(10)],
            size = [pw(80), ph(80)],
            clipChildren = true,
            children = [
              rwrTargetsComponent(style.object),
              createRwrGrid(style.grid, color, backGroundColor),
              rwrGridMarksComponent(style.grid)
            ]
          },
          createCompass(style.grid, color, backGroundColor, styleText)
        ]
      }
    ]
  }
}

let function tws(posWatched, sizeWatched, scale, style) {
  return @() {
    watch = [posWatched, sizeWatched]
    size = sizeWatched.get()
    pos = posWatched.get()
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = scope(scale, style)
  }
}

return tws