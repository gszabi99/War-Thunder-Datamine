if (!("gui_bhv" in ::getroottable()))
  ::gui_bhv <- {}

::dagui_propid.add_name_id("harmonizedImageId")

class ::gui_bhv.HarmonizedImage
{
  eventMask = 0

  function onAttach(obj)
  {
    local textureId = obj?.harmonizedImageId
    if (!::u.isEmpty(textureId))
      obj["background-image"] = ::get_country_flag_img(textureId)
    return ::RETCODE_NOTHING
  }
}