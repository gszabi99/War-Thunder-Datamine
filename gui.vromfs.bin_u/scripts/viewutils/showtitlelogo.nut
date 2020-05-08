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

  obj["background-image"] = getTitleLogo(logoHeight)
  obj.show(true)
}