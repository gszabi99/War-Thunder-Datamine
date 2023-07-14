//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { removeTextareaTags } = require("%sqDagui/daguiUtil.nut")
let { format } = require("string")
let { get_game_version_str } = require("app")

local function setDoubleTextToButton(nestObj, firstBtnId, firstText, secondText = null, textBlock = null) {
  if (!checkObj(nestObj) || firstBtnId == "")
    return null

  if (!secondText)
    secondText = firstText

  let fObj = nestObj.findObject(firstBtnId)
  if (!checkObj(fObj))
    return null

  local hasTextBlock = textBlock != null
  let textBlockObj = ::showBtn($"{firstBtnId}_text_block", hasTextBlock, fObj)
  hasTextBlock = hasTextBlock && checkObj(textBlockObj)
  if (hasTextBlock) {
    let guiScene = ::get_cur_gui_scene()
    if (guiScene != null)
      guiScene.replaceContentFromText(textBlockObj, textBlock, textBlock.len(), {})
  }

  fObj.setValue(hasTextBlock ? "" : firstText)
  let sObj = ::showBtn($"{firstBtnId}_text", !hasTextBlock, fObj)
  if (!hasTextBlock && checkObj(sObj))
    sObj.setValue(secondText)

  return fObj
}

let function setColoredDoubleTextToButton(nestObj, btnId, coloredText) {
  return setDoubleTextToButton(nestObj, btnId, removeTextareaTags(coloredText), coloredText)
}

//instead of wpCost you can use direc Cost  (instance of money)

/**
 * placePriceTextToButton(nestObj, btnId, localizedText, wpCost (int), goldCost (int))
 * placePriceTextToButton(nestObj, btnId, localizedText, cost (Cost) )
 */
let function placePriceTextToButton(nestObj, btnId, localizedText, arg1 = 0, arg2 = 0, fullCost = null) {
  let cost = u.isMoney(arg1) ? arg1 : Cost(arg1, arg2)
  let needShowPrice = !cost.isZero()
  let needShowDiscount = needShowPrice && fullCost != null && (fullCost.gold > cost.gold || fullCost.wp > cost.wp)
  let priceFormat = needShowPrice ? " ({0})" : ""
  let priceText = "".concat(localizedText, priceFormat.subst(cost.getUncoloredText()))
  let coloredCost = cost.getTextAccordingToBalance()
  let priceTextColored = "".concat(localizedText, priceFormat.subst(coloredCost))
  let textBlock = needShowPrice
    ? handyman.renderCached("%gui/commonParts/discount.tpl", {
      headerText = $"{localizedText} ("
      priceText = coloredCost
      listPriceText = fullCost?.getUncoloredText() ?? ""
      haveDiscount = needShowDiscount
      needHeader = true
      endText = ")"
      needDiscountOnRight = true
    })
  : null
  setDoubleTextToButton(nestObj, btnId, priceText, priceTextColored, textBlock)
}

let function setHelpTextOnLoading(nestObj = null) {
  if (!checkObj(nestObj))
    return

  let text = ::show_console_buttons ? "" : loc("loading/help_tip01")
  nestObj.setValue(text)
}

let function setVersionText(scene = null) {
  let verObj = scene ? scene.findObject("version_text") : ::get_cur_gui_scene()["version_text"]
  if (checkObj(verObj))
    verObj.setValue(format(loc("mainmenu/version"), get_game_version_str()))
}

let function formatLocalizationArrayToDescription(locArr) {
  local descr = ""

  foreach (idx, locObj in locArr) {
    local str = locObj.text

    if (locObj.isBold)
      str = "".concat("<b>", str, "</b>")
    if (locObj.color != null)
      str = "".concat($"<color={locObj.color}>", str, "</color>")

    descr = "".concat(descr, idx != 0 ? "\u2022 " : "", str, "\n")
  }

  return descr
}

return {
  setDoubleTextToButton = setDoubleTextToButton
  setColoredDoubleTextToButton = setColoredDoubleTextToButton
  placePriceTextToButton = placePriceTextToButton
  setHelpTextOnLoading = setHelpTextOnLoading
  setVersionText = setVersionText
  formatLocalizationArrayToDescription
}