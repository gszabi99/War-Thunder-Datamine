from "%scripts/user/features.nut" import setOverrideFeature
from "%scripts/dagui_library.nut" import *

let gdkOverrides = {
  AchievementsUrl = false
}

gdkOverrides.each(setOverrideFeature)
