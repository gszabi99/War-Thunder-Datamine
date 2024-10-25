from "%scripts/dagui_natives.nut" import ww_enable_render_map_category, ww_enable_render_map_category_for_preveiw
from "%scripts/dagui_library.nut" import *
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { is_bit_set, change_bit } = require("%sqstd/math.nut")

const WW_ENABLE_RENDER_CATEGORY_ID = "ww_enable_render_category_bitmask"

let DEFAULT_FLAGS = ~(1 << ERC_ARMY_RADIUSES)
let DEFAULT_PREVIEW_FLAGS = (1 << ERC_ZONES) | (1 << ERC_BATTLES) | (1 << ERC_MAP_PICTURE)
local flags = 0

let isCategoryEnabled = @(category) is_bit_set(flags, category)

function setCategory(category, enable) {
  flags = change_bit(flags, category, enable)
  saveLocalByAccount(WW_ENABLE_RENDER_CATEGORY_ID, flags)

  ww_enable_render_map_category(category, enable)
}

function setPreviewCategories() {
  for (local cat = ERC_ARMY_RADIUSES; cat < ERC_TOTAL; ++cat) {
    let previewCatEnabled = is_bit_set(DEFAULT_PREVIEW_FLAGS, cat)
    ww_enable_render_map_category_for_preveiw(cat, previewCatEnabled)
  }
}

function init() {
  flags = loadLocalByAccount(WW_ENABLE_RENDER_CATEGORY_ID, DEFAULT_FLAGS)
  for (local cat = ERC_ARMY_RADIUSES; cat < ERC_TOTAL; ++cat)
    setCategory(cat, isCategoryEnabled(cat))
}

return {
  init,
  isCategoryEnabled,
  setCategory,
  isCategoryVisible = @(_category) true,
  setPreviewCategories
}
