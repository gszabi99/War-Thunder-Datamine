local function setDoubleTextToButton(nestObj, firstBtnId, firstText, secondText = null, textBlock = null) {
  if (!::check_obj(nestObj) || firstBtnId == "")
    return null

  if (!secondText)
    secondText = firstText

  local fObj = nestObj.findObject(firstBtnId)
  if(!::check_obj(fObj))
    return null

  local hasTextBlock = textBlock != null
  local textBlockObj = ::showBtn($"{firstBtnId}_text_block", hasTextBlock, fObj)
  hasTextBlock = hasTextBlock && ::check_obj(textBlockObj)
  if (hasTextBlock) {
    local guiScene = ::get_cur_gui_scene()
    if (guiScene != null)
      guiScene.replaceContentFromText(textBlockObj, textBlock, textBlock.len(), {})
  }

  fObj.setValue(hasTextBlock ? null : firstText)
  local sObj = ::showBtn($"{firstBtnId}_text", !hasTextBlock, fObj)
  if(!hasTextBlock && ::check_obj(sObj))
    sObj.setValue(secondText)

  return fObj
}

local function setColoredDoubleTextToButton(nestObj, btnId, coloredText) {
  return setDoubleTextToButton(nestObj, btnId, ::g_dagui_utils.removeTextareaTags(coloredText), coloredText)
}

//instead of wpCost you can use direc Cost  (instance of money)

/**
 * placePriceTextToButton(nestObj, btnId, localizedText, wpCost (int), goldCost (int))
 * placePriceTextToButton(nestObj, btnId, localizedText, cost (Cost) )
 */
local function placePriceTextToButton(nestObj, btnId, localizedText, arg1=0, arg2=0, fullCost = null) {
  local cost = ::u.isMoney(arg1) ? arg1 : ::Cost(arg1, arg2)
  local needShowPrice = !cost.isZero()
  local needShowDiscount = needShowPrice && fullCost != null && (fullCost.gold > cost.gold || fullCost.wp > cost.wp)
  local priceFormat = needShowPrice ? " ({0})" : ""
  local priceText = "".concat(localizedText, priceFormat.subst(cost.getUncoloredText()))
  local coloredCost = cost.getTextAccordingToBalance()
  local priceTextColored = "".concat(localizedText, priceFormat.subst(coloredCost))
  local textBlock = needShowPrice
    ? ::handyman.renderCached("gui/commonParts/discount", {
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

local function setHelpTextOnLoading(nestObj = null) {
  if (!::checkObj(nestObj))
    return

  local text = ::show_console_buttons? ::loc("loading/help_consoleTip") : ::loc("loading/help_tip01")
  nestObj.setValue(text)
}

local function setVersionText(scene=null) {
  local verObj = scene ? scene.findObject("version_text") : ::get_cur_gui_scene()["version_text"]
  if(::checkObj(verObj))
    verObj.setValue(::format(::loc("mainmenu/version"), ::get_game_version_str()))
}

return {
  setDoubleTextToButton = setDoubleTextToButton
  setColoredDoubleTextToButton = setColoredDoubleTextToButton
  placePriceTextToButton = placePriceTextToButton
  setHelpTextOnLoading = setHelpTextOnLoading
  setVersionText = setVersionText
}