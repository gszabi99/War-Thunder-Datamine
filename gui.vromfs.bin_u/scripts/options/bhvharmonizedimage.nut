//checked for plus_string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")
let { getCountryFlagImg } = require("%scripts/options/countryFlagsPreset.nut")

if (!("gui_bhv" in getroottable()))
  ::gui_bhv <- {}

dagui_propid_add_name_id("harmonizedImageId")

::gui_bhv.HarmonizedImage <- class {
  eventMask = 0

  function onAttach(obj) {
    let textureId = obj?.harmonizedImageId
    if (!u.isEmpty(textureId))
      obj["background-image"] = getCountryFlagImg(textureId)
    return RETCODE_NOTHING
  }
}