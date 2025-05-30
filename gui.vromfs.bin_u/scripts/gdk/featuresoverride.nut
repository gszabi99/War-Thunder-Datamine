from "%scripts/dagui_library.nut" import *

let { setOverrideFeature } = require("%scripts/user/features.nut")

let gdkOverrides = {
  AchievementsUrl = false
}

gdkOverrides.map(setOverrideFeature)
