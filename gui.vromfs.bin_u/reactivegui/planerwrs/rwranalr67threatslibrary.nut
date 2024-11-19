from "%rGui/globals/ui_library.nut" import *

let rwrSetting = require("%rGui/rwrSetting.nut")

let ThreatType = {
  AI = 0,
  AAA = 1,
  SAM = 2,
  SHIP = 3,
  WEAPON = 4
}

let directionGroups = [
  {
    text = "F",
    originalName = "hud/rwr_threat_ai",
    type = ThreatType.AI,
    lethalRangeMax = 5000.0
  },
  {
    text = "A",
    originalName = "hud/rwr_threat_attacker",
    type = ThreatType.AI,
    lethalRangeMax = 5000.0
  },
  {
    text = "21",
    originalName = "M21",
    type = ThreatType.AI,
    lethalRangeMax = 5000.0
  },
  {
    text = "23",
    originalName = "M23",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  {
    text = "29",
    originalName = "M29",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  {
    text = "F4",
    type = ThreatType.AI,
    originalName = "F4",
    lethalRangeMax = 40000.0
  },
  {
    text = "F5",
    originalName = "F5",
    type = ThreatType.AI,
    lethalRangeMax = 5000.0
  },
  {
    text = "14",
    originalName = "F14",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  {
    text = "15",
    originalName = "F15",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  {
    text = "16",
    originalName = "F16",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  {
    text = "18",
    originalName = "F18",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  {
    text = "HR",
    originalName = "HRR",
    type = ThreatType.AI,
    lethalRangeMax = 5000.0
  },
  {
    text = "T",
    originalName = "TRF",
    type = ThreatType.AI,
    lethalRangeMax = 30000.0
  },
  {
    text = "20",
    originalName = "M2K",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  {
    text = "39",
    originalName = "J39",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  {
    text = "JF",
    originalName = "J17",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  //







  {
    text = "3",
    originalName = "S125",
    type = ThreatType.SAM,
    lethalRangeMax = 16000.0
  },
  {
    text = "8",
    originalName = "93",
    type = ThreatType.SAM,
    lethalRangeMax = 12000.0
  },
  {
    text = "15",
    originalName = "9K3",
    type = ThreatType.SAM,
    lethalRangeMax = 12000.0
  },
  {
    text = "RO",
    originalName = "RLD",
    type = ThreatType.SAM,
    lethalRangeMax = 12000.0
  },
  {
    text = "CR",
    originalName = "CRT",
    type = ThreatType.SAM,
    lethalRangeMax = 12000.0
  },
  {
    text = "19",
    originalName = "2S6",
    lethalRangeMax = 8000.0
  },
  {
    text = "AD",
    originalName = "ADS",
    lethalRangeMax = 8000.0
  },
  {
    text = "AR",
    originalName = "ASR",
    lethalRangeMax = 8000.0
  },
  {
    text = "A",
    originalName = "hud/rwr_threat_aaa",
    type = ThreatType.AAA,
    lethalRangeMax = 4000.0
  },
  {
    originalName = "hud/rwr_threat_sam",
    type = ThreatType.SAM,
    lethalRangeMax = 16000.0
  },
  {
    text = "S",
    originalName = "hud/rwr_threat_naval",
    type = ThreatType.SHIP,
    lethalRangeMax = 16000.0
  },
  {
    text = "M",
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
        lethalRangeRel = directionGroup?.lethalRangeMax != null ? (directionGroup.lethalRangeMax - rwrSetting.get().range.x) / (rwrSetting.get().range.y - rwrSetting.get().range.x) : null
      }
    }
  }
  return { directionGroups = directionGroupOut, unknownText = "U" }
})

return {
  ThreatType,
  settings
}