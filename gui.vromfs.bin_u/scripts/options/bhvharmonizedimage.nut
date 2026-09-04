import "%sqStdLibs/helpers/u.nut" as u
from "%globalScripts/guiBehaviourConsts.nut" import *
from "%scripts/dagui_library.nut" import *

let { getCountryFlagImg } = require("%scripts/options/countryFlagsPreset.nut")

dagui_propid_add_name_id("harmonizedImageId")

let HarmonizedImage = class {
  eventMask = 0

  function onAttach(obj) {
    let textureId = obj?.harmonizedImageId
    if (!u.isEmpty(textureId))
      obj["background-image"] = getCountryFlagImg(textureId)
    return RETCODE_NOTHING
  }
}

replace_script_gui_behaviour("HarmonizedImage", HarmonizedImage)
