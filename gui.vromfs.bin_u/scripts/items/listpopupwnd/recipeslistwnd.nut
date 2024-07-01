//-file:plus-string
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import MARK_RECIPE

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { hasFakeRecipesInList } = require("%scripts/items/exchangeRecipes.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_child_by_value, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { ceil } = require("math")
let u = require("%sqStdLibs/helpers/u.nut")
let stdMath = require("%sqstd/math.nut")
let tutorAction = require("%scripts/tutorials/tutorialActions.nut")
let { findChildIndex, setPopupMenuPosAndAlign } = require("%sqDagui/daguiUtil.nut")

local MIN_ITEMS_IN_ROW = 7

gui_handlers.RecipesListWnd <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/items/recipesListWnd.tpl"

  recipesList = null
  curRecipe = null

  headerText = ""
  buttonText = "#item/assemble"
  onAcceptCb = null //if return true, recipes list will not close.
  alignObj = null
  align = "bottom"
  needMarkRecipes = false
  showRecipeAsProduct = false
  showTutorial = false

  function getSceneTplView() {
    this.recipesList = clone this.recipesList
    let hasMarkers = hasFakeRecipesInList(this.recipesList)
    if (hasMarkers)
      this.recipesList.sort(@(a, b) a.idx <=> b.idx)
    else
      this.recipesList.sort(@(a, b) b.isUsable <=> a.isUsable
        || a.sortReqQuantityComponents <=> b.sortReqQuantityComponents
        || a.idx <=> b.idx)
    this.curRecipe = this.recipesList[0]

    local maxRecipeLen = 1
    foreach (r in this.recipesList)
      maxRecipeLen = max(maxRecipeLen, r.getVisibleMarkupComponents())

    let recipeWidthPx = maxRecipeLen * to_pixels("0.5@itemWidth")
    let recipeHeightPx = to_pixels("0.5@itemHeight")
    let minColumns = ceil(MIN_ITEMS_IN_ROW.tofloat() / maxRecipeLen).tointeger()
    let columns = max(minColumns,
      stdMath.calc_golden_ratio_columns(this.recipesList.len(), recipeWidthPx / (recipeHeightPx || 1)))
    let rows = ceil(this.recipesList.len().tofloat() / columns).tointeger()

    local itemsInRow = 0 //some columns are thinner than max
    local columnWidth = 0
    let separatorsIdx = []
    foreach (i, recipe in this.recipesList) {
      let recipeWidth = recipe.getVisibleMarkupComponents()
      columnWidth = max(columnWidth, recipeWidth)
      if (i == 0 || (i % rows))
        continue
      itemsInRow += columnWidth
      columnWidth = recipeWidth
      separatorsIdx.append(i + separatorsIdx.len())
    }
    foreach (idx in separatorsIdx)
      this.recipesList.insert(idx, { isSeparator = true })

    itemsInRow += columnWidth

    let res = {
      maxRecipeLen
      recipesList = this.recipesList
      columns
      rows
      itemsInRow = max(itemsInRow, MIN_ITEMS_IN_ROW)
      hasMarkers
      showRecipeAsProduct = this.showRecipeAsProduct
    }

    foreach (key in ["headerText", "buttonText"])
      res[key] <- this[key]
    return res
  }

  function initScreen() {
    this.align = setPopupMenuPosAndAlign(this.alignObj, this.align, this.scene.findObject("main_frame"))
    this.needMarkRecipes = hasFakeRecipesInList(this.recipesList)
    let recipesListObj = this.scene.findObject("recipes_list")
    if (this.recipesList.len() > 0)
      recipesListObj.setValue(0)

    this.guiScene.applyPendingChanges(false)
    move_mouse_on_child_by_value(recipesListObj)
    this.updateCurRecipeInfo()

    if (this.showTutorial)
      this.startTutorial()
  }

  function startTutorial() {
    let steps = [{
      obj = this.getUsableRecipeObjs().map(@(r) { obj = r, hasArrow = true })
      text = loc("workshop/tutorial/selectRecipe")
      actionType = tutorAction.OBJ_CLICK
      shortcut = ::GAMEPAD_ENTER_SHORTCUT
      cb = @() this.selectRecipe()
    },
    {
      obj = this.scene.findObject("btn_apply")
      text = loc("workshop/tutorial/pressButton", {
        button_name = this.buttonText
      })
      actionType = tutorAction.OBJ_CLICK
      shortcut = ::GAMEPAD_ENTER_SHORTCUT
      cb = @() this.onRecipeApply()
    }]
    ::gui_modal_tutor(steps, this, true)
  }

  function selectRecipe() {
    let recipesListObj = this.scene.findObject("recipes_list")
    if (!recipesListObj?.isValid())
      return

    let cursorPos = get_dagui_mouse_cursor_pos_RC()
    let idx = findChildIndex(recipesListObj, function(childObj) {
      let posRC = childObj.getPosRC()
      let size = childObj.getSize()
      return cursorPos[0] >= posRC[0] && cursorPos[0] <= posRC[0] + size[0]
        && cursorPos[1] >= posRC[1] && cursorPos[1] <= posRC[1] + size[1]
    })

    if (idx == -1 || idx == recipesListObj.getValue())
      return

    recipesListObj.setValue(idx)
  }

  function getUsableRecipeObjs() {
    let res = []
    let recipesListObj = this.scene.findObject("recipes_list")
    foreach (recipe in this.recipesList)
      if (!recipe?.isSeparator && recipe.isUsable && !recipe.isRecipeLocked())
        res.append(recipesListObj.findObject($"id_{recipe.uid}"))
    return res
  }

  function updateCurRecipeInfo() {
    let infoObj = this.scene.findObject("selected_recipe_info")
    let markup = this.curRecipe ? this.curRecipe.getTextMarkup() + this.curRecipe.getMarkDescMarkup() : ""
    this.guiScene.replaceContentFromText(infoObj, markup, markup.len(), this)

    this.updateButtons()
  }

  function updateButtons() {
    local btnObj = this.scene.findObject("btn_apply")
    btnObj.inactiveColor = this.curRecipe?.isUsable && !this.curRecipe.isRecipeLocked() ? "no" : "yes"

    local btnText = loc(this.curRecipe.getActionButtonLocId() ?? this.buttonText)
    if (this.curRecipe.hasCraftTime())
      btnText += " " + loc("ui/parentheses", { text = this.curRecipe.getCraftTimeText() })
    btnObj.setValue(btnText)

    if (!this.needMarkRecipes)
      return

    btnObj = this.scene.findObject("btn_mark")
    btnObj.show(this.needMarkRecipes && (this.curRecipe?.mark ?? MARK_RECIPE.NONE) < MARK_RECIPE.USED)
    btnObj.setValue(this.getMarkBtnText())
  }

  function onRecipeSelect(obj) {
    let newRecipe = this.recipesList?[obj.getValue()]
    if (!u.isRecipe(newRecipe) || newRecipe == this.curRecipe)
      return
    this.curRecipe = newRecipe
    this.updateCurRecipeInfo()
  }

  function onRecipeApply() {
    if (this.curRecipe && this.curRecipe.isRecipeLocked())
      return scene_msg_box("cant_cancel_craft", null,
        colorize("badTextColor", loc(this.curRecipe.getCantAssembleMarkedFakeLocId())),
        [[ "ok" ]],
        "ok")

    local needLeaveWndOpen = false
    if (this.curRecipe && this.onAcceptCb)
      needLeaveWndOpen = this.onAcceptCb(this.curRecipe)
    if (!needLeaveWndOpen)
      this.goBack()
  }

  getMarkBtnText = @() loc(this.curRecipe.mark == MARK_RECIPE.BY_USER
    ? "item/recipes/unmarkFake"
    : "item/recipes/markFake")

  function onRecipeMark() {
    if (!this.curRecipe || !this.needMarkRecipes)
      return

    this.curRecipe.markRecipe(true)
    let recipeObj = this.scene.findObject("id_" + this.curRecipe.uid)
    if (!checkObj(recipeObj))
      return

    recipeObj.isRecipeLocked = this.curRecipe.isRecipeLocked() ? "yes" : "no"
    let markImgObj = recipeObj.findObject("img_" + this.curRecipe.uid)
    markImgObj["background-image"] = this.curRecipe.getMarkIcon()
    markImgObj.tooltip = this.curRecipe.getMarkTooltip()
    this.updateCurRecipeInfo()
  }
}

return {
  open = function(params) {
    let recipesList = params?.recipesList
    if (!recipesList || !recipesList.len())
      return
    handlersManager.loadHandler(gui_handlers.RecipesListWnd, params)
  }
}