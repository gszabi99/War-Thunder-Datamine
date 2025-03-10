from "%rGui/globals/ui_library.nut" import *

let rwrSetting = require("%rGui/rwrSetting.nut")

let ThreatType = {
  AI = 0,
  SAM = 1,
  AAA = 2,
  MSL = 3
}

let directionGroups = [
  {
    text = "ИСТ",
    type = ThreatType.AI,
    originalName = "hud/rwr_threat_ai",
    lethalRangeMax = 5000.0
  },
  {
    text = "БМБ",
    type = ThreatType.AI,
    originalName = "hud/rwr_threat_attacker",
    lethalRangeMax = 5000.0
  },
  {
    text = "М21",
    type = ThreatType.AI,
    originalName = "M21"
    lethalRangeMax = 5000.0
  },
  {
    text = "М23",
    type = ThreatType.AI,
    originalName = "M23",
    lethalRangeMax = 40000.0
  },
  {
    text = "М29",
    type = ThreatType.AI,
    originalName = "M29",
    lethalRangeMax = 40000.0
  },
  {
    text = "С34",
    type = ThreatType.AI,
    originalName = "S34",
    lethalRangeMax = 40000.0
  },
  {
    text = "С24",
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
    text = "TRF",
    type = ThreatType.AI,
    originalName = "TRF",
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
  







  {
    text = "125",
    originalName = "S125",
    type = ThreatType.SAM,
    lethalRangeMax = 16000.0
  },
  {
    text = "ОСА",
    originalName = "93",
    type = ThreatType.SAM,
    lethalRangeMax = 12000.0
  },
  {
    text = "ТОР",
    originalName = "9K3",
    type = ThreatType.SAM,
    lethalRangeMax = 12000.0
  },
  {
    text = "2С6",
    originalName = "2S6",
    type = ThreatType.SAM,
    lethalRangeMax = 8000.0
  },
  {
    text = "С1",
    originalName = "S1",
    type = ThreatType.SAM,
    lethalRangeMax = 16000.0
  },
  {
    text = "ADS",
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
    text = "ASR",
    originalName = "ASR",
    lethalRangeMax = 8000.0
  },
  {
    text = "ЗА",
    originalName = "hud/rwr_threat_aaa",
    type = ThreatType.AAA,
    lethalRangeMax = 4000.0
  },
  {
    text = "КРБ",
    originalName = "hud/rwr_threat_naval",
    lethalRangeMax = 16000.0
  },
  {
    text = "РКТ"
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
  return { directionGroups = directionGroupOut, rangeMax = rwrSetting.get().range.y, unknownText = "?/?" }
})

return {
  ThreatType,
  settings
}