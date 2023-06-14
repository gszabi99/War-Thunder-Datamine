//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { getTitleLogo } = require("%scripts/viewUtils/getTitleLogo.nut")

return function(scene = null, logoHeight = -1) {
  let guiScene = ::get_cur_gui_scene()
  if (logoHeight == -1) {
    let displayHeight = ::g_dagui_utils.toPixels(guiScene, "@titleLogoPlateHeight")
    logoHeight = min(max(displayHeight.tointeger(), 64), 128)
  }

  let obj = scene ? scene.findObject("titleLogo") : guiScene["titleLogo"]
  if (!checkObj(obj))
    return

  let logo = getTitleLogo(logoHeight)
  obj["background-image"] = logo

  let showLogo = logo != ""
  obj.show(showLogo)
  if (!showLogo) {
    let placeObj = scene ? scene.findObject("top_gamercard_bg") : guiScene["top_gamercard_bg"]
    if (checkObj(placeObj))
      placeObj.needRedShadow = "no"

    let logoPlaceObj = scene ? scene.findObject("gamercard_logo_place") : guiScene["gamercard_logo_place"]
    if (checkObj(logoPlaceObj))
      logoPlaceObj.show(showLogo)
  }
}