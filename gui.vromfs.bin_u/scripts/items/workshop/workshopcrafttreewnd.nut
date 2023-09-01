//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { isMarketplaceEnabled, goToMarketplace } = require("%scripts/items/itemsMarketplace.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { abs } = require("math")
let { Point2 } = require("dagor.math")
let { findChild, getObjValidIndex } = require("%sqDagui/daguiUtil.nut")
let tutorAction = require("%scripts/tutorials/tutorialActions.nut")
let { KWARG_NON_STRICT } = require("%sqstd/functools.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")

::dagui_propid.add_name_id("itemId")

let branchIdPrefix = "branch_"
let getBranchId = @(idx) "".concat(branchIdPrefix, idx)
let posFormatString = "{0}, {1}"

let sizeAndPosViewConfig = {
  verticalArrow = kwarg(
    function verticalArrow(itemSizes, bodyIdx, arrowSizeY, arrowPosX, arrowPosY) {
      let { arrowWidth, itemBlockHeight, itemBlockInterval, blockInterval,
        headerBlockInterval, itemHeight, itemsOffsetByBodies, paramsPosColumnsByBodies,
        itemInterval } = itemSizes
      let h = (abs(arrowSizeY) - 1) * (itemBlockHeight)
        + itemBlockInterval - 2 * blockInterval
      let isInUpArrow = arrowSizeY < 0
      let posY = isInUpArrow ? arrowPosY + arrowSizeY : arrowPosY
      return {
        arrowsParts = [{
          partTag = "shopArrow"
          partType = "vertical"
          partSize = posFormatString.subst(arrowWidth, h)
          partPos = posFormatString.subst(
            paramsPosColumnsByBodies[bodyIdx][arrowPosX - 1].columnPos
              + itemInterval + 0.5 * itemHeight - 0.5 * arrowWidth,
            itemsOffsetByBodies[bodyIdx]
              + posY * itemBlockHeight - itemBlockInterval
              + headerBlockInterval + blockInterval)
          partRotation = isInUpArrow ? 180 : 0
        }]
      }
  })
  horizontalArrow = kwarg(
    function horizontalArrow(itemSizes, bodyIdx, arrowSizeX, arrowPosX, arrowPosY) {
      let { itemInterval, blockInterval, arrowWidth, itemBlockHeight,
        headerBlockInterval, itemsOffsetByBodies, itemHeight } = itemSizes
      let columnConfig = itemSizes.paramsPosColumnsByBodies[bodyIdx]
      let cloumnsWidth = abs(columnConfig[arrowPosX - 1].columnPos
        - columnConfig[arrowPosX + arrowSizeX - 1].columnPos)
      let w = cloumnsWidth - itemHeight - 2 * blockInterval
      let h = arrowWidth
      let isInLeftArrow = arrowSizeX < 0
      let posX = isInLeftArrow ? arrowPosX + arrowSizeX : arrowPosX
      return {
        arrowsParts = [{
          partTag = "shopArrow"
          partType = "horizontal"
          partSize = posFormatString.subst(w, h)
          partPos = posFormatString.subst(
            itemInterval + itemHeight + columnConfig[posX - 1].columnPos + blockInterval,
            itemsOffsetByBodies[bodyIdx]
              + (arrowPosY - 1) * (itemBlockHeight)
              + 0.5 * itemHeight - 0.5 * h + headerBlockInterval)
          partRotation = isInLeftArrow ? 180 : 0
        }]
      }
  })
  combineArrow = kwarg(
    function combineArrow(itemSizes, bodyIdx, arrowSizeX, arrowSizeY, arrowPosX, arrowPosY, isInMultipleArrow, isOutMultipleArrow) {
      let { itemInterval, blockInterval, arrowWidth, itemBlockHeight,
        headerBlockInterval, itemsOffsetByBodies, itemHeight, itemBlockInterval } = itemSizes
      let columnConfig = itemSizes.paramsPosColumnsByBodies[bodyIdx]
      let isInLeftArrow = arrowSizeX < 0
      let offsetIn = isInMultipleArrow ? 0.2 : 0
      let arrowOffsetIn = isInLeftArrow ? offsetIn : -offsetIn
      let offsetOut = isOutMultipleArrow ? 0.2 : 0
      let arrowOffsetOut = isInLeftArrow ? -offsetOut : offsetOut
      let posX = isInLeftArrow ? arrowPosX + arrowSizeX : arrowPosX
      let cloumnsWidth = abs(columnConfig[arrowPosX - 1].columnPos
        - columnConfig[arrowPosX + arrowSizeX - 1].columnPos)

      let beginLineHeight = 0.5 * ((abs(arrowSizeY) - 1) * itemBlockHeight
        + itemBlockInterval - 2 * blockInterval)
      let absoluteArrowPosX = itemInterval
        + columnConfig[arrowPosX + arrowSizeX - 1].columnPos
        + 0.5 * itemHeight - 0.5 * arrowWidth + arrowOffsetIn * itemHeight
      let absoluteArrowPosY = itemsOffsetByBodies[bodyIdx]
        + arrowPosY * itemBlockHeight - beginLineHeight + headerBlockInterval - blockInterval
      let absoluteBeginLinePosY = itemsOffsetByBodies[bodyIdx]
        + (arrowPosY - 1) * (itemBlockHeight) + itemHeight + headerBlockInterval + blockInterval

      return {
        arrowsParts = [{
          partTag = "shopArrow"
          partType = "vertical"
          partSize = posFormatString.subst(arrowWidth, beginLineHeight)
          partPos = posFormatString.subst(absoluteArrowPosX, absoluteArrowPosY)
          partRotation = 0
        },
        {
          partTag = "shopLine"
          partSize = posFormatString.subst(beginLineHeight, arrowWidth)
          partPos = posFormatString.subst(itemInterval + columnConfig[arrowPosX - 1].columnPos
              + (arrowOffsetOut + 0.5) * itemHeight + 0.5 * arrowWidth,
            absoluteBeginLinePosY)
          partRotation = 90
        },
        {
          partTag = "shopLine"
          partSize = posFormatString.subst(
            cloumnsWidth - (offsetIn + offsetOut) * itemHeight,
            arrowWidth)
          partPos = posFormatString.subst(itemInterval + columnConfig[posX - 1].columnPos
              + ((isInLeftArrow ? arrowOffsetIn : arrowOffsetOut) + 0.5) * itemHeight,
            absoluteBeginLinePosY + beginLineHeight - 0.5 * arrowWidth)
          partRotation = 0
        },
        {
          partTag = "shopAngle"
          partSize = posFormatString.subst(arrowWidth, arrowWidth)
          partPos = posFormatString.subst(absoluteArrowPosX, absoluteArrowPosY - 0.5 * arrowWidth)
          partRotation = isInLeftArrow ? 90 : 180
        },
        {
          partTag = "shopAngle"
          partSize = posFormatString.subst(arrowWidth, arrowWidth)
          partPos = posFormatString.subst(
            columnConfig[arrowPosX - 1].columnPos + itemInterval
              + (arrowOffsetOut + 0.5) * itemHeight - 0.5 * arrowWidth,
            absoluteBeginLinePosY + beginLineHeight - 0.5 * arrowWidth)
          partRotation = isInLeftArrow ? -90 : 0
        }]
      }
  })
  conectionInRow = kwarg(function conectionInRow(itemSizes, bodyIdx, itemPosX, itemPosY) {
    let { itemInterval, itemBlockHeight, headerBlockInterval,
      itemsOffsetByBodies, itemHeight } = itemSizes
    let { columnPos } = itemSizes.paramsPosColumnsByBodies[bodyIdx][itemPosX]
    return {
      conectionWidth = itemInterval
      conectionPos = posFormatString.subst(columnPos,
        "{0} - 0.5h".subst(itemsOffsetByBodies[bodyIdx]
          + itemPosY * (itemBlockHeight) + 0.5 * itemHeight  + headerBlockInterval))
    }
  })
  itemPos = kwarg(function itemPos(itemSizes, bodyIdx, itemPosX, itemPosY) {
    let { itemInterval, itemBlockHeight, headerBlockInterval,
      itemsOffsetByBodies } = itemSizes
    let { columnPos } = itemSizes.paramsPosColumnsByBodies[bodyIdx][itemPosX]
    return posFormatString.subst(
      itemInterval + columnPos,
      itemsOffsetByBodies[bodyIdx] + itemPosY * itemBlockHeight + headerBlockInterval)
  })
  textBlock = kwarg(function textBlock(itemSizes, bodyIdx, posX, posY, endPosX,
      sizeY, texts, valign, halign) {
    let { itemInterval, itemBlockHeight, itemBlockInterval,
      headerBlockInterval, itemsOffsetByBodies, textInTextBlockSize, maxBodyWidth } = itemSizes
    let columnConfig = itemSizes.paramsPosColumnsByBodies[bodyIdx]
    let cloumnsWidth = (columnConfig?[endPosX + 1].columnPos ?? maxBodyWidth)
      - columnConfig[posX].columnPos
    return {
      textBlockSize = posFormatString.subst(cloumnsWidth - 2 * itemInterval, sizeY * itemBlockHeight - itemBlockInterval)
      textBlockPos = posFormatString.subst(
        itemInterval + columnConfig[posX].columnPos,
        itemsOffsetByBodies[bodyIdx] + posY * itemBlockHeight + headerBlockInterval
      )
      textInBlock = "\n".join(texts.map(@(text) loc(text)))
      textSize = textInTextBlockSize
      textBlockHalign = halign
      textBlockValign = valign
    }
  })
}

let function getConfigByItemBlock(itemBlock, itemsList, workshopSet) {
  local item = itemsList?[itemBlock?.id]
  if (item?.showAsEmptyItem() ?? false)
    item = null
  let hasComponent = itemBlock?.showResources
  let itemId = item?.id ?? "-1"
  let hasReachedMaxAmount = item?.hasReachedMaxAmount() ?? false
  let isCraftingOrHasCraftResult = item != null && (item.isCrafting() || item.hasCraftResult())
  let needReqItemForCraft = workshopSet.isRequireItemsForCrafting(itemBlock, itemsList)
  let altActionName = item?.getAltActionName() ?? ""
  let hasMainAction = isCraftingOrHasCraftResult
    || (!needReqItemForCraft && !workshopSet.needReqItems(itemBlock, itemsList))
  let hasAltAction = !isCraftingOrHasCraftResult && hasReachedMaxAmount && altActionName != ""
  let isDisabledAction = !hasMainAction && !hasAltAction
  let isDisguised = workshopSet.isDisquised(itemBlock, itemsList)
  let hasItemInInventory = (item?.getAmount() ?? 0) != 0 || isCraftingOrHasCraftResult
  return {
    item = item
    hasComponent = hasComponent
    isHiddenResource = !hasComponent || isDisguised || hasReachedMaxAmount || needReqItemForCraft
      || (((item?.maxAmount ?? -1) == 1) && isCraftingOrHasCraftResult)
    itemId = itemId
    isDisabledAction = isDisabledAction
    isDisabled = item != null && !item.showAlwaysAsEnabledAndUnlocked()
      && !hasItemInInventory && (!item.hasUsableRecipeOrNotRecipes() || isDisabledAction)
    overrideMainActionData = hasAltAction ? {
      isInactive = false
      btnName = altActionName
      onItemAction = "onAltItemAction"
    } : null
    iconInsteadAmount = hasReachedMaxAmount ? loc(item?.getLocIdsList().maxAmountIcon ?? "") : null
    conectionInRowText = itemBlock?.conectionInRowText
    isDisguised = !hasItemInInventory && isDisguised
    isHidden = item?.isHiddenItem()
      || (!hasItemInInventory && workshopSet.isRequireItemsForDisplaying(itemBlock, itemsList))
      || workshopSet.isRequireExistItemsForDisplaying(itemBlock, itemsList)
    hasItemBackground = itemBlock?.hasItemBackground ?? true
    posXY = itemBlock?.posXY ?? Point2(0, 0)
  }
}

let getArrowView = kwarg(function getArrowView(arrow, itemSizes, isInMultipleArrow, isOutMultipleArrow) {
  let arrowType = arrow.sizeX != 0 && arrow.sizeY != 0 ? "combineArrow"
    : arrow.sizeX == 0 ? "verticalArrow"
    : "horizontalArrow"
  let arrowParam = {
    itemSizes = itemSizes
    bodyIdx = arrow.bodyIdx
    arrowSizeX = arrow.sizeX
    arrowSizeY = arrow.sizeY
    arrowPosX = arrow.posX
    arrowPosY = arrow.posY
    isInMultipleArrow = isInMultipleArrow
    isOutMultipleArrow = isOutMultipleArrow
  }
  return sizeAndPosViewConfig[arrowType](arrowParam, KWARG_NON_STRICT)
})

let viewItemsParams = {
  showAction = false,
  overrideMainActionData = null,
  showButtonInactiveIfNeed = true,
  showPrice = false,
  contentIcon = false
  shouldHideAdditionalAmmount = true
  canConsume = false
  count = -1
}

let getItemBlockView = kwarg(
  function getItemBlockView(itemBlock, itemConfig, itemSizes, allowableResources) {
    local item = itemConfig.item
    if (item == null)
      return null

    if (itemConfig.isDisguised) {
      item = item.makeEmptyInventoryItem()
      item.setDisguise(true)
    }

    let overridePos = itemBlock?.overridePos
    let count = itemConfig.iconInsteadAmount
      ?? (item.maxAmount == 1 ? item.getAdditionalTextInAmmount(true, true) : null)
    return {
      isDisabled = itemConfig.isDisabled
      itemId = itemConfig.itemId
      items = [item.getViewData(viewItemsParams.__merge({
        itemIndex = itemConfig.itemId,
        showAction = !itemConfig.isDisabledAction
        overrideMainActionData = itemConfig.overrideMainActionData
        count = count
        hasIncrasedAmountTextSize = count != null
        showTooltip = !itemConfig.isDisguised
        enableBackground = itemConfig.hasItemBackground
        onHover = "onItemHover"
      }))]
      blockPos = overridePos ?? sizeAndPosViewConfig.itemPos({
        itemSizes = itemSizes
        bodyIdx = itemBlock.bodyIdx
        itemPosX = itemConfig.posXY.x - 1
        itemPosY = itemConfig.posXY.y - 1
      })
      hasComponent = itemConfig.hasComponent
      isFullSize = itemBlock?.isFullSize ?? false
      component = itemConfig.isHiddenResource
        ? null
        : item.getDescRecipesMarkup({
            maxRecipes = 1
            needShowItemName = false
            needShowHeader = false
            isShowItemIconInsteadItemType = true
            visibleResources = allowableResources
            isTooltipByHold = showConsoleButtons.value
          })
    }
})

let function hasTextBlockAt(textBlocks, x, y, workshopSet, itemsList) {
  foreach (block in textBlocks)
    if (x >= block.posX && x <= block.endPosX && y >= block.posY && y <= block.endPosY
        && !workshopSet.isRequireExistItemsForDisplaying(block, itemsList))
      return true

  return false
}

let function getRowsElementsView(rows, itemSizes, itemsList, allowableResources, textBlocks, workshopSet) {
  let shopArrows = []
  let conectionsInRow = []
  let itemBlocksArr = []
  let lastFilled = {}
  foreach (row in rows) {
    local hasPrevItemInRow = false
    local prevBranchIdx = 0
    foreach (items in row) {
      if (items == null)
        continue
      foreach (_idx, itemBlock in items) {
        let itemConfig = getConfigByItemBlock(itemBlock, itemsList, workshopSet)
        if (itemConfig.isHidden)
          continue

        let curColumnIdx = itemConfig.posXY.x.tointeger() - 1
        lastFilled[curColumnIdx] <- (lastFilled?[curColumnIdx] ?? 0) + 1
        while (hasTextBlockAt(textBlocks, curColumnIdx, lastFilled[curColumnIdx] - 1, workshopSet, itemsList))
          lastFilled[curColumnIdx]++

        if (itemBlock?.shouldRemoveBlankRows ?? false)
          itemConfig.posXY.y = lastFilled[curColumnIdx]

        let itemBlockView = getItemBlockView({
          itemBlock = itemBlock,
          itemSizes = itemSizes,
          allowableResources = allowableResources,
          itemConfig = itemConfig
        })
        if (itemBlockView != null)
          itemBlocksArr.append(itemBlockView)

        let arrows = itemBlock?.arrows.filter(@(a) !itemsList?[a.reqItemId].isHiddenItem()) ?? []
        let isInMultipleArrow = arrows.len() > 1
        foreach (arrow in arrows)
          shopArrows.append({ isDisabled = itemConfig.isDisabled }.__update(
            getArrowView({
              arrow = arrow
              itemSizes = itemSizes
              isInMultipleArrow = isInMultipleArrow
              isOutMultipleArrow = arrow.isOutMultipleArrow
            })
          ))

        let hasCurItem = itemConfig.item != null
        if (hasPrevItemInRow && hasCurItem) {
          let itemPosX = itemConfig.posXY.x - 1
          let curBranchIdx = itemSizes.paramsPosColumnsByBodies[itemBlock.bodyIdx][itemPosX].columnBranchsCount
          if (prevBranchIdx == curBranchIdx)
            conectionsInRow.append({ conectionInRowText = itemBlock.conectionInRowText }.__update(
              sizeAndPosViewConfig.conectionInRow({
                itemSizes = itemSizes
                bodyIdx = itemBlock.bodyIdx
                itemPosX = itemPosX
                itemPosY = itemConfig.posXY.y - 1
              })
            ))
          prevBranchIdx = curBranchIdx
        }
        hasPrevItemInRow = hasCurItem
      }
    }
  }
  return {
    shopArrows = shopArrows
    conectionsInRow = conectionsInRow
    itemBlocksArr = itemBlocksArr
  }
}

let sizePrefixNames = {
  normal = {
    name = ""
    itemPrefix = "i"
    intervalPrefix = "c"
    textInTextBlockSize = ""
  },
  compact = {
    name = "compact"
    itemPrefix = "compactI"
    intervalPrefix = "compactC"
    textInTextBlockSize = "smallFont:t='yes'"
  },
  small = {
    name = "small"
    itemPrefix = "smallI"
    intervalPrefix = "smallC"
    textInTextBlockSize = "smallFont:t='yes'"
  }
}

let function getMaxBodyWidthConfig(craftTreeWidthStringByBodies, prefix) {
  return craftTreeWidthStringByBodies
    .map(@(v, idx) {
      maxBodyWidth = to_pixels(v.subst(prefix)),
      maxBodyIdx = idx
    }).sort(@(a, b) b.maxBodyWidth <=> a.maxBodyWidth)?[0]
    ?? { maxBodyWidth = null, maxBodyIdx = -1 }
}

let function getHeaderView (headerItems, localItemsList, baseEff) {
  let getItemEff = function(item) {
    return item?.getAmount() ? item.getBoostEfficiency() ?? 0 : 0
  }
  let items = []
  local totalEff = baseEff
  let itemsEff = [baseEff]
  foreach (id in headerItems) {
    let item = localItemsList?[id]
    if (!item)
      continue
    let eff = getItemEff(item)
    let hasMaxAmountIcon = item.hasReachedMaxAmount()
    items.append(item.getViewData(viewItemsParams.__merge({
      hasBoostEfficiency = true
      count = hasMaxAmountIcon
        ? loc(item.getLocIdsList().maxAmountIcon)
        : null
      hasIncrasedAmountTextSize = hasMaxAmountIcon
    })))
    totalEff += eff
    itemsEff.append(eff)
  }

  return {
    items = items
    totalEfficiency = colorize(totalEff == 100
      ? "activeTextColor" : totalEff < 100
      ? "badTextColor" : "goodTextColor",  totalEff + loc("measureUnits/percent"))
    itemsEfficiency = loc("ui/parentheses/space", { text = "+".join(itemsEff, true) })
  }
}

let function getBranchSeparator(branch, itemSizes, branchHeight) {
  let posX = branch.minPosX - 1
  if (posX == 0)
    return null

  let rowOffset = itemSizes.itemsOffsetByBodies[branch.bodyIdx]
  let { columnPos } =  itemSizes.paramsPosColumnsByBodies[branch.bodyIdx][posX]
  return {
    separatorPos = posFormatString.subst(columnPos, $"3@dp + {rowOffset}")
    separatorSize = posFormatString.subst("1@dp", "{0} - 6@dp".subst(branchHeight))
  }
}

let function getBodyItemsTitles(titlesConfig, itemSizes) {
  let titlesView = []
  foreach (body in titlesConfig)
    if (body.title != "" && itemSizes.visibleItemsCountYByBodies[body.bodyIdx] > 0)
      titlesView.append({
        bodyTitleText = loc(body.title)
        titlePos = posFormatString.subst(0, itemSizes.bodiesOffset[body.bodyIdx])
        titleSize = posFormatString.subst("pw", itemSizes.titleHeight)
      })

  return titlesView
}

let getAvailableRecipe = @(genId) ::ItemsManager.findItemById(genId)
  ?.getVisibleRecipes()
  .findvalue(@(r) r.isUsable && !r.isRecipeLocked())

let function getTextBlocksView(textBlocks, itemSizes, workshopSet, itemsList) {
  return textBlocks
    .filter(@(block) !workshopSet.isRequireExistItemsForDisplaying(block, itemsList))
    .map(@(block) sizeAndPosViewConfig.textBlock(block.__merge({ itemSizes }), KWARG_NON_STRICT))
}

let bodyButtonsConfig = {
  marketplace = {
    id = "marketplace"
    text = "#mainmenu/marketplace"
    onClick = "onToMarketplaceButton"
    link = ""
    isLink = true
    isFeatured = true
    isButtonHidden = @(_) !isMarketplaceEnabled()
  }
  exchange = {
    id = "exchange"
    text = "#item/assemble"
    onClick = "onExchangeRecipe"
    isButtonHidden = @(btn) getAvailableRecipe(btn?.generatorId.tointeger()) == null
  }
}
let buttonViewParams = {
  shortcut = ""
  btnName = "A"
  showOnSelect = "hover"
  actionParamsMarkup = ""
}
let function getButtonView(bodyConfig, itemSizes) {
  let button = bodyConfig.button
  if (button == null)
    return null

  let buttonConfig = bodyButtonsConfig?[button?.type ?? ""]
  if (buttonConfig?.isButtonHidden(button) ?? true)
    return null

  let buttonView = buttonConfig.__merge(button).__merge(buttonViewParams)
  let posY = button?.position == "top"
    ? itemSizes.itemsOffsetByBodies[bodyConfig.bodyIdx]
      - to_pixels("1@buttonHeight")
    : itemSizes.itemsOffsetByBodies[bodyConfig.bodyIdx]
      + itemSizes.visibleItemsCountYByBodies[bodyConfig.bodyIdx] * itemSizes.itemBlockHeight
      + itemSizes.headerBlockInterval
  let genId = button?.generatorId ? $"generatorId:t='{button.generatorId}'" : ""
  buttonView.actionParamsMarkup = $"pos:t='0.5pw - 0.5w, {posY}'; position:t='absolute'; noMargin:t='yes';{genId}"
  return buttonView
}

let function getBodyBackground(bodiesConfig, itemSizes, fullBodiesHeight) {
  let backgroundView = []
  foreach (body in bodiesConfig)
    if (body.bodyTiledBackImage != "") {
      let posY = itemSizes.itemsOffsetByBodies[body.bodyIdx]
      backgroundView.append({
        bodyBackground = body.bodyTiledBackImage
        bodyBackgroundPos = posFormatString.subst(0, posY)
        bodyBackgroundSize = posFormatString.subst("pw",
          (itemSizes.bodiesOffset?[body.bodyIdx + 1] ?? fullBodiesHeight) - posY)
      })
    }
  return backgroundView
}

local handlerClass = class extends gui_handlers.BaseGuiHandlerWT {
  wndType          = handlerType.MODAL
  sceneTplName     = "%gui/items/craftTreeWnd.tpl"
  branches         = null
  workshopSet      = null
  craftTree        = null
  itemsList        = null
  itemSizes        = null
  itemsListObj     = null
  showItemOnInit   = null
  tutorialItem     = null

  function getSceneTplView() {
    this.craftTree = this.workshopSet.getCraftTree()
    if (this.craftTree == null)
      return null

    this.branches = this.craftTree.branches
    this.itemsList = this.workshopSet.getItemsListForCraftTree(this.craftTree)
    this.itemSizes = this.getItemSizes()
    return {
      frameHeaderText = loc(this.craftTree.headerlocId)
      itemsSize = this.itemSizes.name
      headersView = this.getHeadersView()
    }.__update(this.getBodyView())
  }

  function initScreen() {
    this.scene.findObject("update_timer").setUserData(this)
    this.itemsListObj = this.scene.findObject("craft_body")

    if (this.tutorialItem) {
      this.accentAssembleBtn()
      return
    }

    this.setFocusItem(this.showItemOnInit)
    ::move_mouse_on_child_by_value(this.itemsListObj)
  }

  function getItemSizes() {
    let bodiesConfig = this.craftTree.bodiesConfig
    let resourceWidth = to_pixels("1@craftTreeResourceWidth")
    let maxAllowedCrafTreeWidth = to_pixels("1@maxWindowWidth - 2@frameHeaderPad + 1@scrollBarSize")
    let craftTreeWidthStringByBodies = bodiesConfig.map(@(bodyConfig)
      "".concat(
        "{itemsCountX}(1@{itemPrefix}temHeight + 1@{intervalPrefix}raftTreeItemInterval) + ".subst(bodyConfig),
        "({branchesCount}+1)@{intervalPrefix}raftTreeItemInterval + {allColumnResourceWidth}".subst({
          branchesCount = bodyConfig.branchesCount
          allColumnResourceWidth = bodyConfig.columnWithResourcesCount * resourceWidth
        })
      )
    )
    let sizes = sizePrefixNames.findvalue(@(prefix)
      getMaxBodyWidthConfig(craftTreeWidthStringByBodies, prefix).maxBodyWidth <= maxAllowedCrafTreeWidth
    ) ?? sizePrefixNames.small
    let itemInterval = to_pixels("1@{0}raftTreeItemInterval)".subst(sizes.intervalPrefix))
    local curBodiesOffset = 0
    let itemsOffsetByBodies = []
    let bodiesOffset = []
    let visibleItemsCountYByBodies = []
    let isShowHeaderPlace = this.craftTree.isShowHeaderPlace
    let titleHeight = to_pixels("1@buttonHeight")
    let itemHeight = to_pixels("1@{0}temHeight".subst(sizes.itemPrefix))
    let itemBlockInterval = to_pixels("1@{0}raftTreeBlockInterval".subst(sizes.intervalPrefix))
    let itemBlockHeight = itemHeight + itemBlockInterval
    let headerBlockInterval = to_pixels("1@headerAndCraftTreeBlockInterval")
    let buttonHeight = to_pixels("1@buttonHeight") + 2 * to_pixels("1@buttonMargin")
    let titleMargin = to_pixels("1@dp")
    foreach (idx, rows in this.craftTree.treeRowsByBodies) {
      local visibleItemsCountY = null
      let lastFilled = {}
      for (local i = rows.len() - 1; i >= 0; i--) {
        foreach (row in rows[i]) {
          let findVisibleItemInColumn = {}
          foreach (itemBlock in (row ?? [])) {
            let { id = "", shouldRemoveBlankRows = false, posXY = Point2(0, 0) } = itemBlock
            let item = this.itemsList?[id]
            let hasItemInInventory = item != null
              && (item.getAmount() != 0 || item.isCrafting() || item.hasCraftResult())
            let hasVisibleItem = !item?.isHiddenItem()
              && (hasItemInInventory || !this.workshopSet.isRequireItemsForDisplaying(itemBlock, this.itemsList))
              && !this.workshopSet.isRequireExistItemsForDisplaying(itemBlock, this.itemsList)
            if (!hasVisibleItem) {
              if (shouldRemoveBlankRows)
                findVisibleItemInColumn[posXY.x] <- findVisibleItemInColumn?[posXY.x] ?? false
              continue
            }

            if (shouldRemoveBlankRows)
              findVisibleItemInColumn[posXY.x] <- true
            else {
              visibleItemsCountY = i + 1
            }
          }
          if (visibleItemsCountY != null)
            break

          foreach (posX, value in findVisibleItemInColumn)
            if (value && (posX not in lastFilled))
              lastFilled[posX] <- i + 1
            else if (!value && (posX in lastFilled))
              --lastFilled[posX]
        }
        if (visibleItemsCountY != null)
          break
      }

      foreach (posX, posY in (clone lastFilled))
        foreach (block in bodiesConfig[idx].textBlocks) {
          if (block.endPosY >= posY - 1)
            continue

          let isHidden = this.workshopSet.isRequireExistItemsForDisplaying(block, this.itemsList)
          if (isHidden)
            lastFilled[posX] -= block.sizeY
        }

      let textBlocks = bodiesConfig[idx].textBlocks
        .filter((@(b) !this.workshopSet.isRequireExistItemsForDisplaying(b, this.itemsList)).bindenv(this))
        .sort(@(a, b) a.endPosY <=> b.endPosY)
      visibleItemsCountY = max(visibleItemsCountY ?? lastFilled.reduce(@(res, value) max(res, value), 0),
        textBlocks.len() > 0 ? (textBlocks.top().endPosY + 1) : 0)

      let prevBtn = bodiesConfig?[idx - 1].button
      let prevBtnCfg = bodyButtonsConfig?[prevBtn?.type]
      let prevBtnHeight = !(prevBtnCfg?.isButtonHidden(prevBtn) ?? true) ? buttonHeight : 0

      let curBtn = bodiesConfig?[idx].button
      let curBtnCfg = bodyButtonsConfig?[curBtn?.type]
      let shiftForTopBtn = (curBtn?.position == "top") && !(curBtnCfg?.isButtonHidden(curBtn) ?? true) ? buttonHeight : 0

      curBodiesOffset += isShowHeaderPlace || idx == 0 || visibleItemsCountYByBodies[idx - 1] == 0 ? 0
        : (bodiesConfig[idx - 1].bodyTitlesCount * titleHeight
            + visibleItemsCountYByBodies[idx - 1] * itemBlockHeight + headerBlockInterval + prevBtnHeight
          )
      let curBodyTitlesCount = bodiesConfig[idx].bodyTitlesCount
      itemsOffsetByBodies.append(curBodiesOffset
        + ((isShowHeaderPlace || visibleItemsCountY == 0)
          ? 0
          : (shiftForTopBtn + curBodyTitlesCount * titleHeight + (curBodyTitlesCount - 1) * titleMargin)
      ))
      bodiesOffset.append(curBodiesOffset)
      visibleItemsCountYByBodies.append(visibleItemsCountY)
    }

    let { maxBodyWidth, maxBodyIdx } = getMaxBodyWidthConfig(craftTreeWidthStringByBodies, sizes)
    let maxBodyConfig = bodiesConfig[maxBodyIdx]
    let maxBranchesCount = maxBodyConfig.branchesCount
    let maxTreeColumnsCount = maxBodyConfig.treeColumnsCount
    let maxAvailableBranchByColumns = maxBodyConfig.availableBranchByColumns
    let paramsPosColumnsByBodies = bodiesConfig.map(function(bodyConfig) {
      local { treeColumnsCount, availableBranchByColumns, branchesCount,
        columnWithResourcesCount, resourcesInColumn } = bodyConfig
      let hasMaxTreeColumnsCount = treeColumnsCount == maxTreeColumnsCount
      if (hasMaxTreeColumnsCount) {
        branchesCount = maxBranchesCount
        availableBranchByColumns = maxAvailableBranchByColumns
      }
      let columnWidth =
        (maxBodyWidth - branchesCount * itemInterval - columnWithResourcesCount * resourceWidth) / (treeColumnsCount || 1)
      let res = []
      local columnBranchsCount = 0
      local columnsWidth = 0
      for (local i = 0; i < treeColumnsCount; i++) {
        columnBranchsCount += availableBranchByColumns?[i] != null && i > 0 ? 1 : 0
        let isLastIdx = i == treeColumnsCount - 1
        let curColumnWidth = columnWidth
          + ((isLastIdx || availableBranchByColumns?[i + 1] != null) ? itemInterval : 0)
          + (resourcesInColumn?[i] ?? 0) * resourceWidth
        res.append({
          columnPos = columnsWidth,
          columnBranchsCount
        })
        columnsWidth += curColumnWidth
      }
      return res
    })

    return sizes.__update({
      itemHeight
      itemHeightFull = to_pixels("1@itemHeight")
      titleMargin
      itemInterval
      itemBlockInterval
      resourceWidth
      scrollBarSize = to_pixels("1@scrollBarSize")
      arrowWidth = to_pixels("1@modArrowWidth")
      headerBlockInterval
      blockInterval = to_pixels("1@blockInterval")
      itemBlockHeight
      titleHeight
      itemsOffsetByBodies
      bodiesOffset
      visibleItemsCountYByBodies
      maxBodyWidth
      paramsPosColumnsByBodies
    })
  }

  function getHeadersView() {
    if (!this.craftTree.isShowHeaderPlace)
      return null

    let lastBranchIdx = this.branches.len() - 1
    let baseEff = this.craftTree.baseEfficiency
    let headerItemsTitle = this.craftTree?.headerItemsTitle ? loc(this.craftTree.headerItemsTitle) : null
    let bodyTitle = this.craftTree.bodiesConfig[0].title
    let bodyItemsTitle = bodyTitle != "" ? loc(bodyTitle) : null
    let headersView = this.branches.map((function(branch, idx) {
      let posX = branch.minPosX - 1
      let paramsPosColumns = this.itemSizes.paramsPosColumnsByBodies[branch.bodyIdx]
      let { columnPos } = paramsPosColumns[posX]
      let nextBranchPos = paramsPosColumns?[posX + branch.itemsCountX].columnPos ?? this.itemSizes.maxBodyWidth
      return {
        branchHeader = branch?.locId != null ? loc(branch.locId) : null
        headerItemsTitle = idx == lastBranchIdx ? headerItemsTitle : ""
        bodyItemsTitle = idx == lastBranchIdx ? bodyItemsTitle : ""
        positionsTitleX = 0
        branchId = getBranchId(idx)
        branchHeaderItems = getHeaderView(branch.headerItems, this.itemsList, baseEff)
        branchWidth = nextBranchPos - columnPos
        separators = idx != 0
        hasHeaderItems = this.craftTree.hasHeaderItems
      }
    }).bindenv(this))

    let totalWidth = headersView.map(@(branch) branch.branchWidth).reduce(@(res, value) res + value)
    let positionsTitleXLastBranch = "{widthLastBranch} - 0.5*{totalWidth} - 0.5w".subst({
      totalWidth = totalWidth
      widthLastBranch = headersView[lastBranchIdx].branchWidth
    })
    headersView[lastBranchIdx].positionsTitleX = positionsTitleXLastBranch
    return headersView
  }

  function getBodyView() {
    let { resourceWidth, itemBlockHeight, visibleItemsCountYByBodies,
      headerBlockInterval, itemsOffsetByBodies, itemBlockInterval, titleMargin,
      bodiesOffset, titleHeight, maxBodyWidth, itemHeightFull, paramsPosColumnsByBodies } = this.itemSizes
    let itemBlocksArr = []
    let shopArrows = []
    let conectionsInRow = []
    let textBlocks = []
    let buttons = []
    let bodiesConfig = this.craftTree.bodiesConfig
    foreach (idx, rows in this.craftTree.treeRowsByBodies) {
      let connectingElements = getRowsElementsView(rows, this.itemSizes, this.itemsList,
        bodiesConfig[idx].allowableResources, bodiesConfig[idx].textBlocks, this.workshopSet)
      shopArrows.extend(connectingElements.shopArrows)
      conectionsInRow.extend(connectingElements.conectionsInRow)
      itemBlocksArr.extend(connectingElements.itemBlocksArr)
      textBlocks.extend(getTextBlocksView(bodiesConfig[idx].textBlocks, this.itemSizes, this.workshopSet, this.itemsList))
      let buttonView = getButtonView(bodiesConfig[idx], this.itemSizes)
      if (buttonView != null)
        buttons.append(buttonView)
    }

    let separators = []
    let isShowHeaderPlace = this.craftTree.isShowHeaderPlace
    let bodyTitles = isShowHeaderPlace ? [] : getBodyItemsTitles(bodiesConfig, this.itemSizes)
    foreach (_idx, branch in this.branches) {
      let bodyConfig = bodiesConfig[branch.bodyIdx]
      let itemsCountY = visibleItemsCountYByBodies[branch.bodyIdx]
      if (itemsCountY == 0)
        continue
      separators.append(getBranchSeparator(branch, this.itemSizes,
        itemsCountY * itemBlockHeight + headerBlockInterval))
      if (!isShowHeaderPlace && branch?.locId != null) {
        let posX = branch.minPosX - 1
        let paramsPosColumns = paramsPosColumnsByBodies[branch.bodyIdx]
        let { columnPos } = paramsPosColumns[posX]
        let nextBranchPos = paramsPosColumns?[posX + branch.itemsCountX].columnPos ?? maxBodyWidth
        bodyTitles.append({
          bodyTitleText = loc(branch.locId)
          titlePos = posFormatString.subst(columnPos,
            (bodiesConfig[branch.bodyIdx].bodyTitlesCount > 1 ? titleMargin : 0)
              + bodiesOffset[branch.bodyIdx] + (bodyConfig.title != "" ? titleHeight : 0))
          titleSize = posFormatString.subst(nextBranchPos - columnPos, titleHeight)
          hasSeparator = posX != 0
        })
      }
    }

    let fullBodyHeightWithoutResult = itemsOffsetByBodies.top()
      + headerBlockInterval + visibleItemsCountYByBodies.top() * itemBlockHeight
    let craftResult = this.craftTree?.craftResult
    let hasCraftResult = craftResult != null
    if (hasCraftResult) {
      let itemBlock = craftResult.__merge({
        showResources = true
        isFullSize = true
        overridePos = posFormatString.subst(0.5 * maxBodyWidth - 0.5 * (itemHeightFull + resourceWidth),
          fullBodyHeightWithoutResult + headerBlockInterval)
      })
      itemBlocksArr.append(getItemBlockView({
        itemBlock = itemBlock,
        itemConfig = getConfigByItemBlock(itemBlock, this.itemsList, this.workshopSet),
        itemSizes = this.itemSizes,
        allowableResources = this.craftTree.allowableResourcesForCraftResult
      }))

      separators.append({
        separatorPos = posFormatString.subst("0.5pw - 0.5w", fullBodyHeightWithoutResult)
        separatorSize = posFormatString.subst(maxBodyWidth, "1@dp")
      })
    }
    return {
      bodyTitles
      bodyBackground = getBodyBackground(bodiesConfig, this.itemSizes, fullBodyHeightWithoutResult)
      bodyHeight = fullBodyHeightWithoutResult
        + (hasCraftResult
          ? (headerBlockInterval + itemHeightFull + itemBlockInterval)
          : 0)
      bodyWidth = maxBodyWidth
      separators
      itemBlock = itemBlocksArr
      shopArrows
      conectionsInRow
      textBlocks
      buttons
      isTooltipByHold = showConsoleButtons.value
    }
  }

  function findItemObj(itemId) {
    return this.scene.findObject("shop_item_" + itemId)
  }

  function onItemAction(buttonObj) {
    let id = buttonObj?.holderId ?? "-1"
    let item = this.itemsList?[id.tointeger()]
    let itemObj = this.findItemObj(id)
    this.doMainAction(item, itemObj)
  }

  function onAltItemAction(buttonObj) {
    let id = buttonObj?.holderId ?? "-1"
    let item = this.itemsList?[id.tointeger()]
    let itemObj = this.findItemObj(id)
    this.doAltAction(item, itemObj)
  }

  function onItemHover(obj) {
    if (!obj.isHovered())
      return

    let id = obj?.holderId ?? "-1"
    let item = this.itemsList?[id.tointeger()]
    this.setFocusItem(item)
  }

  function onMainAction() {
    let curItemParam = this.getCurItemParam()
    let button = curItemParam.button
    if (button?.onClick != null) {
      this[button.onClick]()
      return
    }

    let item = curItemParam.item
    let itemObj = curItemParam.obj
    if (item == null)
      return

    local itemBlock = this.craftTree?.craftResult.id == item.id
      ? this.craftTree.craftResult
      : null
    if (itemBlock == null)
      foreach (branche in this.branches) {
        itemBlock = branche.branchItems?[item.id]
        if (itemBlock != null)
          break
      }

    if (item.isCrafting() || item.hasCraftResult()
        || (!this.workshopSet.needReqItems(itemBlock, this.itemsList)
          && !this.workshopSet.isRequireItemsForCrafting(itemBlock, this.itemsList)))
      this.doMainAction(item, itemObj)
    else if (item.getAltActionName() != "")
      this.doAltAction(item, itemObj)
  }

  function accentAssembleBtn() {
    let item = this.tutorialItem
    let { childObj, childIdx } = findChild(this.itemsListObj, @(c) c?.itemId == item.id.tostring())
    if (childObj == null)
      return

    this.itemsListObj.setValue(childIdx)
    let actionBtnObj = childObj.findObject("actionBtn")
    actionBtnObj.scrollToView()

    let steps = [{
      obj = [actionBtnObj]
      text = loc("workshop/tutorial/pressButton", {
        button_name = item.getAssembleText()
      })
      actionType = tutorAction.OBJ_CLICK
      shortcut = ::GAMEPAD_ENTER_SHORTCUT
      cb = @() this.doMainAction(item, childObj, true)
    }]
    ::gui_modal_tutor(steps, this, true)
  }

  function accentCraftTime() {
    let item = this.tutorialItem
    let { childObj, childIdx } = findChild(this.itemsListObj, @(c) c?.itemId == item.id.tostring())
    this.itemsListObj.setValue(childIdx)

    let timeObj = childObj.findObject("timePlace")
    timeObj.scrollToView()

    let steps = [{
      obj = [timeObj]
      text = loc("workshop/tutorial/wait")
      actionType = tutorAction.ANY_CLICK
      shortcut = ::GAMEPAD_ENTER_SHORTCUT
      waitTime = item.getCraftTimeLeft()
    }]
    ::gui_modal_tutor(steps, this, true)
  }

  getActionParams = @(item, obj, showTutorial = false) {
    obj = obj
    isHidePrizeActionBtn = !item.hasCustomMission()
    canConsume = false
    showTutorial = showTutorial
  }

  doMainAction = @(item, obj, showTutorial = false)
    item?.doMainAction(null, this, this.getActionParams(item, obj, showTutorial))
  doAltAction = @(item, obj) item?.doAltAction(this.getActionParams(item, obj))

  function getCurItemParam() {
    let value = getObjValidIndex(this.itemsListObj)
    if (value < 0)
      return {
        obj = null
        item = null
        button = null
      }

    let itemObj = this.itemsListObj.getChild(value)
    return {
      obj = itemObj
      item = this.itemsList?[(itemObj?.itemId ?? "-1").tointeger()]
      button = bodyButtonsConfig?[itemObj?.id ?? ""]
    }
  }

  function onTimer(_obj, _dt) {
    foreach (item in this.itemsList) {
      if (!item.hasTimer())
        continue

      let itemObj = this.findItemObj(item.id)
      if (!checkObj(itemObj))
        continue
      local timeTxtObj = itemObj.findObject("expire_time")
      if (checkObj(timeTxtObj))
        timeTxtObj.setValue(item.getTimeLeftText())
      timeTxtObj = itemObj.findObject("craft_time")
      if (checkObj(timeTxtObj))
        timeTxtObj.setValue(item.getCraftTimeTextShort())
    }
  }

  function updateCraftTree() {
    let curItemParam = this.getCurItemParam()

    this.craftTree = this.workshopSet.getCraftTree() ?? this.craftTree
    this.branches = this.craftTree.branches
    this.itemsList = this.workshopSet.getItemsListForCraftTree(this.craftTree)
    this.itemSizes = this.getItemSizes()
    this.scene.findObject("wnd_title").setValue(loc(this.craftTree.headerlocId))

    local view = {
      itemsSize = this.itemSizes.name
      headersView = this.getHeadersView()
    }
    local data = handyman.renderCached("%gui/items/craftTreeHeader.tpl", view)
    this.guiScene.replaceContentFromText(this.scene.findObject("craft_header"), data, data.len(), this)

    view = this.getBodyView()
    this.itemsListObj.size = posFormatString.subst(view.bodyWidth, view.bodyHeight)
    data = handyman.renderCached("%gui/items/craftTreeBody.tpl", view)
    this.guiScene.replaceContentFromText(this.itemsListObj, data, data.len(), this)
    if (this.tutorialItem?.isCrafting() && this.tutorialItem.getCraftTimeLeft() > 0) {
      this.accentCraftTime()
      this.tutorialItem = null
      return
    }
    this.setFocusItem(curItemParam.item)
    ::move_mouse_on_child_by_value(this.itemsListObj)
  }

  function setFocusItem(curItem = null) {
    let curItemId = curItem?.id.tostring() ?? ""
    local enabledValue = null
    for (local i = 0; i < this.itemsListObj.childrenCount(); i++) {
      let childObj = this.itemsListObj.getChild(i)
      if (enabledValue == null && childObj.isEnabled())
        enabledValue = i
      if (childObj?.itemId != curItemId)
        continue

      this.itemsListObj.setValue(i)
      return
    }
    let curIdx = getObjValidIndex(this.itemsListObj)
    if (curIdx >= 0 && this.itemsListObj.getChild(curIdx).isEnabled())
      this.itemsListObj.setValue(curIdx)
    else if (enabledValue != null)
      this.itemsListObj.setValue(enabledValue)
  }

  function onEventInventoryUpdate(_p) {
    this.doWhenActiveOnce("updateCraftTree")
  }

  function onEventProfileUpdated(_p) {
    this.doWhenActiveOnce("updateCraftTree")
  }

  function onToMarketplaceButton() {
    goToMarketplace()
  }

  function onExchangeRecipe(obj) {
    let gen = this.itemsList?[obj?.generatorId.tointeger()]
    if (!gen)
      return

    let recipe = gen?.getVisibleRecipes()
      .findvalue(@(r) r.isUsable && !r.isRecipeLocked())

    gen.assemble(null, {
      recipes = [recipe]
      shouldSkipMsgBox = true
    })
  }
}

gui_handlers.craftTreeWnd <- handlerClass

return {
  open = @(craftTreeParams) handlersManager.loadHandler(handlerClass, craftTreeParams)
}