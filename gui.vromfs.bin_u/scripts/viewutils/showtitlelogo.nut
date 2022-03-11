local { getTitleLogo } = require("scripts/viewUtils/getTitleLogo.nut")

return function(scene = null, logoHeight = -1)
{
  local guiScene = ::get_cur_gui_scene()
  if (logoHeight == -1)
  {
    local displayHeight = ::g_dagui_utils.toPixels(guiScene, "@titleLogoPlateHeight")
    logoHeight = ::min(::max(displayHeight.tointeger(), 64), 128)
  }

  local obj = scene? scene.findObject("titleLogo") : guiScene["titleLogo"]
  if (!::check_obj(obj))
    return

  local logo = getTitleLogo(logoHeight)
  obj["background-image"] = logo

  local showLogo = logo != ""
  obj.show(showLogo)
  if (!showLogo)
  {
    local placeObj = scene? scene.findObject("top_gamercard_bg") : guiScene["top_gamercard_bg"]
    if (::check_obj(placeObj))
      placeObj.needRedShadow = "no"

    local logoPlaceObj = scene? scene.findObject("gamercard_logo_place") : guiScene["gamercard_logo_place"]
    if (::check_obj(logoPlaceObj))
      logoPlaceObj.show(showLogo)
  }
}