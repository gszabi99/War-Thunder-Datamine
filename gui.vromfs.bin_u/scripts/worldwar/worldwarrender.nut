from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let stdMath = require("%sqstd/math.nut")

const WW_ENABLE_RENDER_CATEGORY_ID = "ww_enable_render_category_bitmask"

::g_world_war_render <- {
  flags = 0
  DEFAULT_FLAGS = ~(1 << ERC_ARMY_RADIUSES)
  DEFAULT_PREVIEW_FLAGS = (1 << ERC_ZONES) | (1 << ERC_BATTLES) | (1 << ERC_MAP_PICTURE)
}


::g_world_war_render.init <- function init()
{
  flags = ::loadLocalByAccount(WW_ENABLE_RENDER_CATEGORY_ID, DEFAULT_FLAGS)
  for (local cat = ERC_ARMY_RADIUSES; cat < ERC_TOTAL; ++cat)
    setCategory(cat, isCategoryEnabled(cat))
}


::g_world_war_render.isCategoryEnabled <- function isCategoryEnabled(category)
{
  return stdMath.is_bit_set(flags, category)
}


::g_world_war_render.isCategoryVisible <- function isCategoryVisible(category)
{
  return true
}


::g_world_war_render.setPreviewCategories <- function setPreviewCategories()
{
  for (local cat = ERC_ARMY_RADIUSES; cat < ERC_TOTAL; ++cat)
  {
    let previewCatEnabled = stdMath.is_bit_set(DEFAULT_PREVIEW_FLAGS, cat)
    ::ww_enable_render_map_category_for_preveiw(cat, previewCatEnabled)
  }
}


::g_world_war_render.setCategory <- function setCategory(category, enable)
{
  flags = stdMath.change_bit(flags, category, enable)
  ::saveLocalByAccount(WW_ENABLE_RENDER_CATEGORY_ID, flags)

  ::ww_enable_render_map_category(category, enable)
}
