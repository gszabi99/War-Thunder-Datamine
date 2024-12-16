from "%scripts/dagui_library.nut" import *

let buyAndOpenChestWndStyles = {
  newYear23 = {
    headerBackgroundImage = "!ui/images/chests_wnd/golden_new_year_image"
    chestNameBackgroundImage = "!ui/images/chests_wnd/golden_new_year_header"
    headerBackgroundImageHeight = "512.0/2420w"
    headerBackgroundImageMaxHeight = "0.43ph"
    bgCornersShadowSize = "(sw - 1@swOrRwInVr) $max (sw - 2420.0*0.43sh/512)"
    timeExpiredTextParams = "pos:t='0.75pw, 0.4ph-0.5h'"
  }
  silverCommon = {
    headerBackgroundImage = "!ui/images/chests_wnd/silver_common_image"
    chestNameBackgroundImage = "!ui/images/chests_wnd/silver_common_header"
    headerBackgroundImageHeight = "720.0/1920w"
    headerBackgroundImageMaxHeight = "0.70ph"
    bgCornersShadowSize = "(sw - 1@swOrRwInVr) $max (sw - 1920.0*0.70sh/720)"
    timeExpiredTextParams="pos:t='0.65pw, 0.41ph-0.5h'; overlayTextColor:t='active'"
    chestNameTextParams="font-ht:t='40@sf/@pf'"
  }
  silverSummer = {
    headerBackgroundImage = "!ui/images/chests_wnd/silver_summer_image"
    chestNameBackgroundImage = "!ui/images/chests_wnd/silver_summer_header"
    headerBackgroundImageHeight = "720.0/1920w"
    headerBackgroundImageMaxHeight = "0.70ph"
    bgCornersShadowSize = "(sw - 1@swOrRwInVr) $max (sw - 1920.0*0.70sh/720)"
    timeExpiredTextParams="pos:t='0.75pw, 0.41ph-0.5h'; overlayTextColor:t='active'"
    chestNameTextParams="font-ht:t='40@sf/@pf'"
    needTopGradient = "yes"
  }
  silverWinter = {
    headerBackgroundImage = "!ui/images/chests_wnd/silver_winter_image"
    chestNameBackgroundImage = "!ui/images/chests_wnd/golden_new_year_header"
    headerBackgroundImageHeight = "720.0/1920w"
    headerBackgroundImageMaxHeight = "0.70ph"
    bgCornersShadowSize = "(sw - 1@swOrRwInVr) $max (sw - 1920.0*0.70sh/720)"
    timeExpiredTextParams="pos:t='0.75pw, 0.41ph-0.5h'; overlayTextColor:t='active'"
    chestNameTextParams="font-ht:t='40@sf/@pf'"
    needTopGradient = "yes"
  }
}

let hasBuyAndOpenChestWndStyle = @(item) buyAndOpenChestWndStyles?[item?.itemDef.tags.openingWndStyle ?? ""] != null

function getBuyAndOpenChestWndStyle(item) {
  let params = buyAndOpenChestWndStyles?[item?.itemDef.tags.openingWndStyle ?? ""]
  if (params == null || params?.bgCornersShadowSize == null)
    return params
  let bgCornersShadowSize = to_pixels(params.bgCornersShadowSize)
  params.hasCornerGradient <- bgCornersShadowSize > 0
  return params
}

return {
  hasBuyAndOpenChestWndStyle
  getBuyAndOpenChestWndStyle
}