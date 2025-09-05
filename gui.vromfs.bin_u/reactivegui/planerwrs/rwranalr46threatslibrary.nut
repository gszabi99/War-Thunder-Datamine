from "%rGui/globals/ui_library.nut" import *

let rwrSetting = require("%rGui/rwrSetting.nut")

let ThreatType = {
  AIRBORNE_PULSE = 0,
  AIRBORNE_PULSE_DOPPLER = 1,
  SHIP = 2
}

let directionGroups = [
  {
    originalName = "hud/rwr_threat_ai",
    type = ThreatType.AIRBORNE_PULSE,
    lethalRangeMax = 20000.0
  },
  {
    originalName = "hud/rwr_threat_pd",
    type = ThreatType.AIRBORNE_PULSE_DOPPLER,
    lethalRangeMax = 40000.0
  },
  {
    text = "2",
    originalName = "S75",
    lethalRangeMax = 40000.0
  },
  {
    text = "3",
    originalName = "S125",
    lethalRangeMax = 16000.0
  },
  {
    text = "8",
    originalName = "93",
    lethalRangeMax = 12000.0
  },
  {
    text = "15",
    originalName = "9K3",
    lethalRangeMax = 12000.0
  },
  {
    text = "R",
    originalName = "RLD",
    lethalRangeMax = 12000.0
  },
  {
    text = "C",
    originalName = "CRT",
    lethalRangeMax = 12000.0
  },
  {
    text = "A",
    originalName = "hud/rwr_threat_aaa",
    lethalRangeMax = 4000.0
  },
  {
    type = ThreatType.SHIP,
    originalName = "hud/rwr_threat_naval",
    lethalRangeMax = 4000.0
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