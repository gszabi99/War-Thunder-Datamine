local ExchangeRecipes = require("scripts/items/exchangeRecipes.nut")
local u = require("sqStdLibs/helpers/u.nut")
local stdMath = require("std/math.nut")

local MIN_ITEMS_IN_ROW = 7

class ::gui_handlers.RecipesListWnd extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneTplName = "gui/items/recipesListWnd"

  recipesList = null
  curRecipe = null

  headerText = ""
  buttonText = "#item/assemble"
  onAcceptCb = null //if return true, recipes list will not close.
  alignObj = null
  align = "bottom"
  needMarkRecipes = false

  function getSceneTplView()
  {
    recipesList = clone recipesList
    local hasMarkers = ExchangeRecipes.hasFakeRecipes(recipesList)
    if (hasMarkers)
      recipesList.sort(@(a, b) a.idx <=> b.idx)
    else
      recipesList.sort(@(a, b) b.isUsable <=> a.isUsable
        || a.sortReqQuantityComponents <=> b.sortReqQuantityComponents
        || a.idx <=> b.idx)
    curRecipe = recipesList[0]

    local maxRecipeLen = 1
    foreach(r in recipesList)
      maxRecipeLen = ::max(maxRecipeLen, r.visibleComponents.len())

    local recipeWidthPx = maxRecipeLen * ::to_pixels("0.5@itemWidth")
    local recipeHeightPx = ::to_pixels("0.5@itemHeight")
    local minColumns = ::ceil(MIN_ITEMS_IN_ROW.tofloat() / maxRecipeLen).tointeger()
    local columns = ::max(minColumns,
      stdMath.calc_golden_ratio_columns(recipesList.len(), recipeWidthPx / (recipeHeightPx || 1)))
    local rows = ::ceil(recipesList.len().tofloat() / columns).tointeger()

    local itemsInRow = 0 //some columns are thinner than max
    local columnWidth = 0
    foreach(i, recipe in recipesList)
    {
      columnWidth = ::max(columnWidth, recipe.visibleComponents.len())
      if ((i + 1) % (rows + 1))
        continue
      itemsInRow += columnWidth
      columnWidth = 0
      recipesList.insert(i, { isSeparator = true })
    }
    itemsInRow += columnWidth

    local res = {
      maxRecipeLen = maxRecipeLen
      recipesList = recipesList
      columns = columns
      rows = rows
      itemsInRow = ::max(itemsInRow, MIN_ITEMS_IN_ROW)
      hasMarkers = hasMarkers
    }

    foreach(key in ["headerText", "buttonText"])
      res[key] <- this[key]
    return res
  }

  function initScreen()
  {
    align = ::g_dagui_utils.setPopupMenuPosAndAlign(alignObj, align, scene.findObject("main_frame"))
    needMarkRecipes = ExchangeRecipes.hasFakeRecipes(recipesList)

    ::move_mouse_on_child_by_value(scene.findObject("recipes_list"))
    updateCurRecipeInfo()
  }

  function updateCurRecipeInfo()
  {
    local infoObj = scene.findObject("selected_recipe_info")
    local markup = curRecipe ? curRecipe.getTextMarkup() + curRecipe.getMarkDescMarkup() : ""
    guiScene.replaceContentFromText(infoObj, markup, markup.len(), this)

    updateButtons()
  }

  function updateButtons()
  {
    local btnObj = scene.findObject("btn_apply")
    btnObj.inactiveColor = curRecipe?.isUsable && !curRecipe.isRecipeLocked() ? "no" : "yes"

    local btnText = ::loc(curRecipe.getActionButtonLocId() ?? buttonText)
    if (curRecipe.hasCraftTime())
      btnText += " " + ::loc("ui/parentheses", {text = curRecipe.getCraftTimeText()})
    btnObj.setValue(btnText)

    if (!needMarkRecipes)
      return

    btnObj = scene.findObject("btn_mark")
    btnObj.show(needMarkRecipes && (curRecipe?.mark ?? MARK_RECIPE.NONE) < MARK_RECIPE.USED)
    btnObj.setValue(getMarkBtnText())
  }

  function onRecipeSelect(obj)
  {
    local newRecipe = recipesList?[obj.getValue()]
    if (!u.isRecipe(newRecipe) || newRecipe == curRecipe)
      return
    curRecipe = newRecipe
    updateCurRecipeInfo()
  }

  function onRecipeApply()
  {
    if (curRecipe && curRecipe.isRecipeLocked())
      return ::scene_msg_box("cant_cancel_craft", null,
        ::colorize("badTextColor", ::loc(curRecipe.getCantAssembleMarkedFakeLocId())),
        [[ "ok" ]],
        "ok")

    local needLeaveWndOpen = false
    if (curRecipe && onAcceptCb)
      needLeaveWndOpen = onAcceptCb(curRecipe)
    if (!needLeaveWndOpen)
      goBack()
  }

  getMarkBtnText = @() ::loc(curRecipe.mark == MARK_RECIPE.BY_USER
    ? "item/recipes/unmarkFake"
    : "item/recipes/markFake")

  function onRecipeMark()
  {
    if(!curRecipe || !needMarkRecipes)
      return

    curRecipe.markRecipe(true)
    local recipeObj = scene.findObject("id_"+ curRecipe.uid)
    if (!::check_obj(recipeObj))
      return

    recipeObj.isRecipeLocked = curRecipe.isRecipeLocked() ? "yes" : "no"
    local markImgObj = recipeObj.findObject("img_"+ curRecipe.uid)
    markImgObj["background-image"] = curRecipe.getMarkIcon()
    markImgObj.tooltip = curRecipe.getMarkTooltip()
    updateCurRecipeInfo()
  }
}

return {
  open = function(params) {
    local recipesList = params?.recipesList
    if (!recipesList || !recipesList.len())
      return
    ::handlersManager.loadHandler(::gui_handlers.RecipesListWnd, params)
  }
}