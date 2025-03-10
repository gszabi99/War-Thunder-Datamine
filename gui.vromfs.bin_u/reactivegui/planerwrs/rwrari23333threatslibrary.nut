from "%rGui/globals/ui_library.nut" import *

let rwrSetting = require("%rGui/rwrSetting.nut")

let directionGroups = [
  {
    text = "F",
    originalName = "hud/rwr_threat_ai",
    lethalRangeMax = 40000.0
  },
  {
    text = "L",
    originalName = "hud/rwr_threat_pd",
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
    text = "19",
    originalName = "2S6",
    lethalRangeMax = 8000.0
  },
  {
    text = "22",
    originalName = "S1",
    lethalRangeMax = 16000.0
  },
  {
    text = "M",
    originalName = "hud/rwr_threat_sam",
    lethalRangeMax = 12000.0
  },
  {
    text = "A",
    originalName = "hud/rwr_threat_aaa",
    lethalRangeMax = 4000.0
  },
  {
    text = "Z",
    originalName = "Z23",
    lethalRangeMax = 2500.0
  },
  {
    text = "W",
    originalName = "ARH",
    isWeapon = true
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
        isWeapon = directionGroup?.isWeapon
        lethalRangeRel = directionGroup?.lethalRangeMax != null ? (directionGroup.lethalRangeMax - rwrSetting.get().range.x) / (rwrSetting.get().range.y - rwrSetting.get().range.x) : null
      }
    }
  }
  return { directionGroups = directionGroupOut, unknownText = "U" }
})

return {
  settings
}