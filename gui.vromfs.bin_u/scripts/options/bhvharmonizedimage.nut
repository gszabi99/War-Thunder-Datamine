from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

if (!("gui_bhv" in getroottable()))
  ::gui_bhv <- {}

::dagui_propid.add_name_id("harmonizedImageId")

::gui_bhv.HarmonizedImage <- class
{
  eventMask = 0

  function onAttach(obj)
  {
    let textureId = obj?.harmonizedImageId
    if (!::u.isEmpty(textureId))
      obj["background-image"] = ::get_country_flag_img(textureId)
    return RETCODE_NOTHING
  }
}