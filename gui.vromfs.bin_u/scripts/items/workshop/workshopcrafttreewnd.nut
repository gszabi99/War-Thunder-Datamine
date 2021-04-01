local { isMarketplaceEnabled, goToMarketplace } = require("scripts/items/itemsMarketplace.nut")

::dagui_propid.add_name_id("itemId")

local branchIdPrefix = "branch_"
local getBranchId = @(idx) "".concat(branchIdPrefix, idx)
local posFormatString = "{0}, {1}"

local sizeAndPosViewConfig = {
  verticalArrow = ::kwarg(
    function verticalArrow(itemSizes, bodyIdx, arrowSizeX, arrowSizeY, arrowPosX, arrowPosY) {
      local { arrowWidth, itemBlockHeight, itemBlockInterval, blockInterval,
        headerBlockInterval, itemHeight, itemsOffsetByBodies, paramsPosColumnsByBodies,
        itemInterval } = itemSizes
      local h = (::abs(arrowSizeY) - 1)*(itemBlockHeight)
        + itemBlockInterval - 2*blockInterval
      local isInUpArrow = arrowSizeY < 0
      local posY = isInUpArrow ? arrowPosY + arrowSizeY : arrowPosY
      return {
        arrowsParts = [{
          partTag = "shopArrow"
          partType = "vertical"
          partSize = posFormatString.subst(arrowWidth, h)
          partPos = posFormatString.subst(
            paramsPosColumnsByBodies[bodyIdx][arrowPosX - 1].columnPos
              + itemInterval + 0.5*itemHeight - 0.5*arrowWidth,
            itemsOffsetByBodies[bodyIdx]
              + posY * itemBlockHeight - itemBlockInterval
              + headerBlockInterval + blockInterval)
          partRotation = isInUpArrow ? 180 : 0
        }]
      }
  })
  horizontalArrow = ::kwarg(
    function horizontalArrow(itemSizes, bodyIdx, arrowSizeX, arrowSizeY, arrowPosX, arrowPosY) {
      local { itemInterval, blockInterval, arrowWidth, itemBlockHeight,
        headerBlockInterval, itemsOffsetByBodies, itemHeight } = itemSizes
      local columnConfig = itemSizes.paramsPosColumnsByBodies[bodyIdx]
      local cloumnsWidth = ::abs(columnConfig[arrowPosX -1].columnPos
        - columnConfig[arrowPosX + arrowSizeX - 1].columnPos)
      local w = cloumnsWidth - itemHeight - 2*blockInterval
      local h = arrowWidth
      local isInLeftArrow = arrowSizeX < 0
      local posX = isInLeftArrow ? arrowPosX + arrowSizeX : arrowPosX
      return {
        arrowsParts = [{
          partTag = "shopArrow"
          partType = "horizontal"
          partSize = posFormatString.subst(w, h)
          partPos = posFormatString.subst(
            itemInterval + itemHeight + columnConfig[posX - 1].columnPos + blockInterval,
            itemsOffsetByBodies[bodyIdx]
              + (arrowPosY - 1)*(itemBlockHeight)
              + 0.5*itemHeight - 0.5*h + headerBlockInterval)
          partRotation = isInLeftArrow ? 180 : 0
        }]
      }
  })
  combineArrow = ::kwarg(
    function combineArrow(itemSizes, bodyIdx, arrowSizeX, arrowSizeY, arrowPosX, arrowPosY, isInMultipleArrow, isOutMultipleArrow) {
      local { itemInterval, blockInterval, arrowWidth, itemBlockHeight,
        headerBlockInterval, itemsOffsetByBodies, itemHeight, itemBlockInterval } = itemSizes
      local columnConfig = itemSizes.paramsPosColumnsByBodies[bodyIdx]
      local isInLeftArrow = arrowSizeX < 0
      local offsetIn = isInMultipleArrow ? 0.2 : 0
      local arrowOffsetIn = isInLeftArrow ? offsetIn : -offsetIn
      local offsetOut = isOutMultipleArrow ? 0.2 : 0
      local arrowOffsetOut = isInLeftArrow ? -offsetOut : offsetOut
      local posX = isInLeftArrow ? arrowPosX + arrowSizeX : arrowPosX
      local cloumnsWidth = ::abs(columnConfig[arrowPosX -1].columnPos
        - columnConfig[arrowPosX + arrowSizeX - 1].columnPos)

      local beginLineHeight = 0.5*((::abs(arrowSizeY) - 1) * itemBlockHeight
        + itemBlockInterval - 2*blockInterval)
      local absoluteArrowPosX = itemInterval
        + columnConfig[arrowPosX + arrowSizeX - 1].columnPos
        + 0.5*itemHeight - 0.5*arrowWidth + arrowOffsetIn*itemHeight
      local absoluteArrowPosY = itemsOffsetByBodies[bodyIdx]
        + arrowPosY * itemBlockHeight - beginLineHeight + headerBlockInterval - blockInterval
      local absoluteBeginLinePosY = itemsOffsetByBodies[bodyIdx]
        + (arrowPosY - 1)*(itemBlockHeight) + itemHeight + headerBlockInterval + blockInterval

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
              + (arrowOffsetOut + 0.5) * itemHeight + 0.5*arrowWidth,
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
            absoluteBeginLinePosY + beginLineHeight - 0.5*arrowWidth)
          partRotation = 0
        },
        {
          partTag = "shopAngle"
          partSize = posFormatString.subst(arrowWidth, arrowWidth)
          partPos = posFormatString.subst(absoluteArrowPosX, absoluteArrowPosY - 0.5*arrowWidth)
          partRotation = isInLeftArrow ? 90 : 180
        },
        {
          partTag = "shopAngle"
          partSize = posFormatString.subst(arrowWidth, arrowWidth)
          partPos = posFormatString.subst(
            columnConfig[arrowPosX - 1].columnPos + itemInterval
              + (arrowOffsetOut + 0.5) * itemHeight - 0.5*arrowWidth,
            absoluteBeginLinePosY + beginLineHeight - 0.5*arrowWidth)
          partRotation = isInLeftArrow ? -90 : 0
        }]
      }
  })
  conectionInRow = ::kwarg(function conectionInRow(itemSizes, bodyIdx, itemPosX, itemPosY) {
    local { itemInterval, itemBlockHeight, headerBlockInterval,
      itemsOffsetByBodies, itemHeight } = itemSizes
    local { columnPos } = itemSizes.paramsPosColumnsByBodies[bodyIdx][itemPosX]
    return {
      conectionWidth = itemInterval
      conectionPos = posFormatString.subst(columnPos,
        "{0} - 0.5h".subst(itemsOffsetByBodies[bodyIdx]
          + itemPosY*(itemBlockHeight) + 0.5*itemHeight  + headerBlockInterval))
    }
  })
  itemPos = ::kwarg(function itemPos(itemSizes, bodyIdx, itemPosX, itemPosY) {
    local { itemInterval, itemBlockHeight, headerBlockInterval,
      itemsOffsetByBodies } = itemSizes
    local { columnPos } = itemSizes.paramsPosColumnsByBodies[bodyIdx][itemPosX]
    return posFormatString.subst(
      itemInterval + columnPos,
      itemsOffsetByBodies[bodyIdx] + itemPosY * itemBlockHeight + headerBlockInterval)
  })
  textBlock = ::kwarg(function textBlock(itemSizes, bodyIdx, posX, posY, endPosX, endPosY, sizeX, sizeY, texts) {
    local { itemInterval, itemBlockHeight, itemBlockInterval,
      headerBlockInterval, itemsOffsetByBodies, textInTextBlockSize, maxBodyWidth } = itemSizes
    local columnConfig = itemSizes.paramsPosColumnsByBodies[bodyIdx]
    local cloumnsWidth = (columnConfig?[endPosX+1].columnPos ?? maxBodyWidth)
      - columnConfig[posX].columnPos
    return {
      textBlockSize = posFormatString.subst(cloumnsWidth - 2*itemInterval, sizeY * itemBlockHeight - itemBlockInterval)
      textBlockPos = posFormatString.subst(
        itemInterval + columnConfig[posX].columnPos,
        itemsOffsetByBodies[bodyIdx] + posY * itemBlockHeight + headerBlockInterval
      )
      textInBlock = "\n".join(texts.map(@(text) ::loc(text)))
      textSize = textInTextBlockSize
    }
  })
}

local function needReqItems(itemBlock, itemsList) {
  foreach(reqItemId in (itemBlock?.reqItems ?? []))
    if (reqItemId != null && (itemsList?[reqItemId].getAmount() ?? 0) == 0)
      return true

  return false
}

local function isRequireCondition(reqItems, itemsList, isMetConditionFunc) {
  local needCondForCraft = false
  foreach (reqItemBlock in (reqItems)) {
    local canCraft = true
    foreach (itemId, needHave in reqItemBlock) {
      local isMetCondition = isMetConditionFunc(itemsList, itemId)
      if ((needHave && isMetCondition) || (!needHave && !isMetCondition))
        continue

      canCraft = false
      break
    }

    if (canCraft)
      return false

    needCondForCraft = true
  }

  return needCondForCraft
}

local hasAmount = @(itemsList, itemId) (itemsList?[itemId].getAmount() ?? 0) > 0

local function getConfigByItemBlock(itemBlock, itemsList, workshopSet)
{
  local item = itemsList?[itemBlock?.id]
  local hasComponent = itemBlock?.showResources
  local itemId = item?.id ?? "-1"
  local isCraftingOrHasCraftResult = item != null && (item.isCrafting() || item.hasCraftResult())
  local needReqItemForCraft = isRequireCondition(itemBlock?.reqItemForCrafting ?? [], itemsList, hasAmount)
  local isDisabledAction = !isCraftingOrHasCraftResult
    && (needReqItemForCraft || needReqItems(itemBlock, itemsList))
  local isItemIdKnown = (@(itemsList, itemId) workshopSet.isItemIdKnown(itemId)).bindenv(workshopSet)
  local isDisguised = isRequireCondition(itemBlock?.reqItemForIdentification ?? [], itemsList, isItemIdKnown)
  local hasReachedMaxAmount = item?.hasReachedMaxAmount() ?? false
  local hasItemInInventory = (item?.getAmount() ?? 0) != 0 || isCraftingOrHasCraftResult
  return {
    item = item
    hasComponent = hasComponent
    isHiddenResource = !hasComponent || isDisguised || hasReachedMaxAmount || needReqItemForCraft
      || (((item?.maxAmount ?? -1) == 1) && isCraftingOrHasCraftResult)
    itemId = itemId
    isDisabledAction = isDisabledAction
    isDisabled = item != null && !hasItemInInventory
      && (!item.hasUsableRecipeOrNotRecipes() || isDisabledAction)
    iconInsteadAmount = hasReachedMaxAmount ? ::loc(item?.getLocIdsList().maxAmountIcon ?? "") : null
    conectionInRowText = itemBlock?.conectionInRowText
    isDisguised = !hasItemInInventory && isDisguised
    isHidden = item?.isHiddenItem()
      || (!hasItemInInventory
        && (isRequireCondition(itemBlock?.reqItemForDisplaying ?? [], itemsList, isItemIdKnown)
          || isRequireCondition(itemBlock?.reqItemExistsForDisplaying ?? [], itemsList, hasAmount)))
    hasItemBackground = itemBlock?.hasItemBackground ?? true
  }
}

local getArrowView = ::kwarg(function getArrowView(arrow, itemSizes, isInMultipleArrow, isOutMultipleArrow) {
  local arrowType = arrow.sizeX != 0 && arrow.sizeY != 0 ? "combineArrow"
    : arrow.sizeX == 0 ? "verticalArrow"
    : "horizontalArrow"
  local arrowParam = {
    itemSizes = itemSizes
    bodyIdx = arrow.bodyIdx
    arrowSizeX = arrow.sizeX
    arrowSizeY = arrow.sizeY
    arrowPosX = arrow.posX
    arrowPosY = arrow.posY
    isInMultipleArrow = isInMultipleArrow
    isOutMultipleArrow = isOutMultipleArrow
  }
  return sizeAndPosViewConfig[arrowType](arrowParam)
})

local viewItemsParams = {
  showAction = false,
  showButtonInactiveIfNeed = true,
  showPrice = false,
  contentIcon = false
  shouldHideAdditionalAmmount = true
  canConsume = false
  count = -1
}

local getItemBlockView = ::kwarg(
  function getItemBlockView(itemBlock, itemConfig, itemSizes, allowableResources) {
    local item = itemConfig.item
    if (item == null)
      return null

    if (itemConfig.isDisguised) {
      item = item.makeEmptyInventoryItem()
      item.setDisguise(true)
    }

    local overridePos = itemBlock?.overridePos
    local count = itemConfig.iconInsteadAmount
      ?? (item.maxAmount == 1 ? item.getAdditionalTextInAmmount(true, true) : null)
    return {
      isDisabled = itemConfig.isDisabled
      itemId = itemConfig.itemId
      items = [item.getViewData(viewItemsParams.__merge({
        itemIndex = itemConfig.itemId,
        showAction = !itemConfig.isDisabledAction
        count = count
        hasIncrasedAmountTextSize = count != null
        showTooltip = !itemConfig.isDisguised
        enableBackground = itemConfig.hasItemBackground
        onHover = "onItemHover"
      }))]
      blockPos = overridePos ?? sizeAndPosViewConfig.itemPos({
        itemSizes = itemSizes
        bodyIdx = itemBlock.bodyIdx
        itemPosX = itemBlock.posXY.x - 1
        itemPosY = itemBlock.posXY.y - 1
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
            isTooltipByHold = ::show_console_buttons
          })
    }
})

local function getRowsElementsView(rows, itemSizes, itemsList, allowableResources, workshopSet) {
  local shopArrows = []
  local conectionsInRow = []
  local itemBlocksArr = []
  foreach (row in rows)
  {
    local hasPrevItemInRow = false
    local prevBranchIdx = 0
    foreach (items in row) {
      if (items == null)
        continue
      foreach (idx, itemBlock in items)
      {
        local itemConfig = getConfigByItemBlock(itemBlock, itemsList, workshopSet)
        if (itemConfig.isHidden)
          continue

        local itemBlockView = getItemBlockView({
          itemBlock = itemBlock,
          itemSizes = itemSizes,
          allowableResources = allowableResources,
          itemConfig = itemConfig
        })
        if (itemBlockView != null)
          itemBlocksArr.append(itemBlockView)

        local arrows = itemBlock?.arrows.filter(@(a) !itemsList?[a.reqItemId].isHiddenItem()) ?? []
        local isInMultipleArrow = arrows.len() > 1
        foreach (arrow in arrows)
          shopArrows.append({ isDisabled = itemConfig.isDisabled }.__update(
            getArrowView({
              arrow = arrow
              itemSizes = itemSizes
              isInMultipleArrow = isInMultipleArrow
              isOutMultipleArrow = arrow.isOutMultipleArrow
            })
          ))

        local hasCurItem = itemConfig.item != null
        if (hasPrevItemInRow && hasCurItem)
        {
          local itemPosX = itemBlock.posXY.x - 1
          local curBranchIdx = itemSizes.paramsPosColumnsByBodies[itemBlock.bodyIdx][itemPosX].columnBranchsCount
          if (prevBranchIdx == curBranchIdx)
            conectionsInRow.append({ conectionInRowText = itemBlock.conectionInRowText }.__update(
              sizeAndPosViewConfig.conectionInRow({
                itemSizes = itemSizes
                bodyIdx = itemBlock.bodyIdx
                itemPosX = itemPosX
                itemPosY = itemBlock.posXY.y - 1
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

local sizePrefixNames = {
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

local function getMaxBodyWidthConfig(craftTreeWidthStringByBodies, prefix) {
  return craftTreeWidthStringByBodies
    .map(@(v, idx) {
      maxBodyWidth = ::to_pixels(v.subst(prefix)),
      maxBodyIdx = idx
    }).sort(@(a,b) b.maxBodyWidth <=> a.maxBodyWidth)?[0]
    ?? { maxBodyWidth = null, maxBodyIdx = -1 }
}

local function getHeaderView (headerItems, localItemsList, baseEff)
{
  local getItemEff = function(item)
  {
    return item?.getAmount() ? item.getBoostEfficiency() ?? 0 : 0
  }
  local items = []
  local totalEff = baseEff
  local itemsEff = [baseEff]
  foreach(id in headerItems)
  {
    local item = localItemsList?[id]
    if(!item)
      continue
    local eff = getItemEff(item)
    local hasMaxAmountIcon = item.hasReachedMaxAmount()
    items.append(item.getViewData(viewItemsParams.__merge({
      hasBoostEfficiency = true
      count = hasMaxAmountIcon
        ? ::loc(item.getLocIdsList().maxAmountIcon)
        : null
      hasIncrasedAmountTextSize = hasMaxAmountIcon
    })))
    totalEff += eff
    itemsEff.append(eff)
  }

  return {
    items = items
    totalEfficiency = ::colorize(totalEff == 100
      ? "activeTextColor" : totalEff < 100
      ? "badTextColor" : "goodTextColor",  totalEff + ::loc("measureUnits/percent"))
    itemsEfficiency = ::loc("ui/parentheses/space", { text = ::g_string.implode (itemsEff, "+")})
  }
}

local function getBranchSeparator(branch, itemSizes, branchHeight) {
  local posX = branch.minPosX -1
  if (posX == 0)
    return null

  local rowOffset = itemSizes.itemsOffsetByBodies[branch.bodyIdx]
  local { columnPos } =  itemSizes.paramsPosColumnsByBodies[branch.bodyIdx][posX]
  return {
    separatorPos = posFormatString.subst(columnPos, $"3@dp + {rowOffset}")
    separatorSize = posFormatString.subst("1@dp", "{0} - 6@dp".subst(branchHeight))
  }
}

local function getBodyItemsTitles(titlesConfig, itemSizes) {
  local titlesView = []
  foreach (body in titlesConfig)
    if (body.title != "" && itemSizes.visibleItemsCountYByBodies[body.bodyIdx] > 0)
      titlesView.append({
        bodyTitleText = ::loc(body.title)
        titlePos = posFormatString.subst(0, itemSizes.bodiesOffset[body.bodyIdx])
        titleSize = posFormatString.subst("pw", itemSizes.titleHeight)
      })

  return titlesView
}

local getTextBlocksView = @(textBlocks, itemSizes)  textBlocks.map(
  @(textBlock) sizeAndPosViewConfig.textBlock(textBlock.__merge({ itemSizes = itemSizes})))

local bodyButtonsConfig = {
  marketplace = {
    id = "marketplace"
    text = "#mainmenu/marketplace"
    onClick = "onToMarketplaceButton"
    link = ""
    isLink = true
    isFeatured = true
    isHidden = @() !isMarketplaceEnabled()
  }
}
local buttonViewParams = {
  shortcut = ""
  btnName = "A"
  showOnSelect = "hover"
  actionParamsMarkup = ""
}
local function getButtonView(bodyConfig, itemSizes) {
  local button = bodyConfig.button
  if (button == null)
    return null

  local buttonConfig = bodyButtonsConfig?[button?.type ?? ""]
  if (buttonConfig?.isHidden() ?? true)
    return null

  local buttonView = buttonConfig.__merge(button).__merge(buttonViewParams)
  local posY = itemSizes.itemsOffsetByBodies[bodyConfig.bodyIdx]
    + itemSizes.visibleItemsCountYByBodies[bodyConfig.bodyIdx] * itemSizes.itemBlockHeight
    + itemSizes.headerBlockInterval
  buttonView.actionParamsMarkup = $"pos:t='0.5pw - 0.5w, {posY}'; position:t='absolute'; noMargin:t='yes'"
  return buttonView
}

local function getBodyBackground(bodiesConfig, itemSizes, fullBodiesHeight) {
  local backgroundView = []
  foreach (body in bodiesConfig)
    if (body.bodyTiledBackImage != "") {
      local posY = itemSizes.itemsOffsetByBodies[body.bodyIdx]
      backgroundView.append({
        bodyBackground = body.bodyTiledBackImage
        bodyBackgroundPos = posFormatString.subst(0, posY)
        bodyBackgroundSize = posFormatString.subst("pw",
          (itemSizes.bodiesOffset?[body.bodyIdx + 1] ?? fullBodiesHeight) - posY)
      })
    }
  return backgroundView
}

local handlerClass = class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType          = handlerType.MODAL
  sceneTplName     = "gui/items/craftTreeWnd"
  branches         = null
  workshopSet      = null
  craftTree        = null
  itemsList        = null
  itemSizes        = null
  itemsListObj     = null
  showItemOnInit   = null

  function getSceneTplView()
  {
    craftTree = workshopSet.getCraftTree()
    if (craftTree == null)
      return null

    branches = craftTree.branches
    itemsList = workshopSet.getItemsListForCraftTree(craftTree)
    itemSizes = getItemSizes()
    return {
      frameHeaderText = ::loc(craftTree.headerlocId)
      itemsSize = itemSizes.name
      headersView = getHeadersView()
    }.__update(getBodyView())
  }

  function initScreen()
  {
    scene.findObject("update_timer").setUserData(this)
    itemsListObj = scene.findObject("craft_body")
    setFocusItem(showItemOnInit)
    ::move_mouse_on_child_by_value(itemsListObj)
  }

  function getItemSizes() {
    local bodiesConfig = craftTree.bodiesConfig
    local resourceWidth = ::to_pixels("1@craftTreeResourceWidth")
    local maxAllowedCrafTreeWidth = ::to_pixels("1@maxWindowWidth - 2@frameHeaderPad + 1@scrollBarSize")
    local craftTreeWidthStringByBodies = bodiesConfig.map(@(bodyConfig)
      "".concat(
        "{itemsCountX}(1@{itemPrefix}temHeight + 1@{intervalPrefix}raftTreeItemInterval) + ".subst(bodyConfig),
        "({branchesCount}+1)@{intervalPrefix}raftTreeItemInterval + {allColumnResourceWidth}".subst({
          branchesCount = bodyConfig.branchesCount
          allColumnResourceWidth = bodyConfig.columnWithResourcesCount * resourceWidth
        })
      )
    )
    local sizes = sizePrefixNames.findvalue(@(prefix)
      getMaxBodyWidthConfig(craftTreeWidthStringByBodies, prefix).maxBodyWidth <= maxAllowedCrafTreeWidth
    ) ?? sizePrefixNames.small
    local itemInterval = ::to_pixels("1@{0}raftTreeItemInterval)".subst(sizes.intervalPrefix))
    local curBodiesOffset = 0
    local itemsOffsetByBodies = []
    local bodiesOffset = []
    local visibleItemsCountYByBodies = []
    local isShowHeaderPlace = craftTree.isShowHeaderPlace
    local titleHeight = ::to_pixels("1@buttonHeight")
    local itemHeight = ::to_pixels("1@{0}temHeight".subst(sizes.itemPrefix))
    local itemBlockInterval = ::to_pixels("1@{0}raftTreeBlockInterval".subst(sizes.intervalPrefix))
    local itemBlockHeight = itemHeight + itemBlockInterval
    local headerBlockInterval = ::to_pixels("1@headerAndCraftTreeBlockInterval")
    local wSet = workshopSet
    local isItemIdKnown = @(itemsList, itemId) wSet.isItemIdKnown(itemId)
    local buttonHeight = ::to_pixels("1@buttonHeight") + 2*::to_pixels("1@buttonMargin")
    local titleMargin = ::to_pixels("1@dp")
    local items = itemsList
    foreach (idx, rows in craftTree.treeRowsByBodies) {
      local visibleItemsCountY = 0
      for (local i = rows.len(); i > 0; i--)
        if (rows[i-1].findindex(@(row)
          row?.findindex(function (itemBlock) {
            local item = items?[itemBlock?.id]
            local hasItemInInventory = item != null
              && (item.getAmount() != 0 || item.isCrafting() || item.hasCraftResult())
            return !item?.isHiddenItem()
              && (hasItemInInventory
                || (!isRequireCondition(itemBlock?.reqItemForDisplaying ?? [], items, isItemIdKnown)
                  && !isRequireCondition(itemBlock?.reqItemExistsForDisplaying ?? [], items, hasAmount)))
          }) != null
        ) != null)
        {
          visibleItemsCountY = i
          break
        }
      local textBlocks = bodiesConfig[idx].textBlocks
      textBlocks.sort(@(a, b) a.endPosY <=> b.endPosY)
      visibleItemsCountY = ::max(visibleItemsCountY,
        textBlocks.len() > 0 ? (textBlocks.top().endPosY + 1) : 0)
      curBodiesOffset += isShowHeaderPlace || idx == 0 || visibleItemsCountYByBodies[idx-1] == 0 ? 0
        : (bodiesConfig[idx-1].bodyTitlesCount * titleHeight
            + visibleItemsCountYByBodies[idx-1] * itemBlockHeight + headerBlockInterval
            + (!(bodyButtonsConfig?[bodiesConfig[idx-1].button?.type].isHidden() ?? true) ? buttonHeight : 0)
          )
      local curBodyTitlesCount = bodiesConfig[idx].bodyTitlesCount
      itemsOffsetByBodies.append(curBodiesOffset
        + ((isShowHeaderPlace || visibleItemsCountY == 0)
          ? 0
          : (curBodyTitlesCount * titleHeight + (curBodyTitlesCount -1) * titleMargin)
      ))
      bodiesOffset.append(curBodiesOffset)
      visibleItemsCountYByBodies.append(visibleItemsCountY)
    }

    local { maxBodyWidth, maxBodyIdx } = getMaxBodyWidthConfig(craftTreeWidthStringByBodies, sizes)
    local maxBodyConfig = bodiesConfig[maxBodyIdx]
    local maxBranchesCount = maxBodyConfig.branchesCount
    local maxTreeColumnsCount = maxBodyConfig.treeColumnsCount
    local maxAvailableBranchByColumns = maxBodyConfig.availableBranchByColumns
    local paramsPosColumnsByBodies = bodiesConfig.map(function(bodyConfig) {
      local { treeColumnsCount, availableBranchByColumns, branchesCount,
        columnWithResourcesCount, resourcesInColumn } = bodyConfig
      local hasMaxTreeColumnsCount = treeColumnsCount == maxTreeColumnsCount
      if (hasMaxTreeColumnsCount) {
        branchesCount = maxBranchesCount
        availableBranchByColumns = maxAvailableBranchByColumns
      }
      local columnWidth =
        (maxBodyWidth - branchesCount * itemInterval - columnWithResourcesCount * resourceWidth)/(treeColumnsCount || 1)
      local res = []
      local columnBranchsCount = 0
      local columnsWidth = 0
      for(local i = 0; i < treeColumnsCount; i++) {
        columnBranchsCount += availableBranchByColumns?[i] != null && i > 0 ? 1 : 0
        local isLastIdx = i == treeColumnsCount - 1
        local curColumnWidth = columnWidth
          + ((isLastIdx || availableBranchByColumns?[i+1] != null) ? itemInterval : 0)
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
      itemHeightFull = ::to_pixels("1@itemHeight")
      titleMargin
      itemInterval
      itemBlockInterval
      resourceWidth
      scrollBarSize = ::to_pixels("1@scrollBarSize")
      arrowWidth = ::to_pixels("1@modArrowWidth")
      headerBlockInterval
      blockInterval = ::to_pixels("1@blockInterval")
      itemBlockHeight
      titleHeight
      itemsOffsetByBodies
      bodiesOffset
      visibleItemsCountYByBodies
      maxBodyWidth
      paramsPosColumnsByBodies
    })
  }

  function getHeadersView()
  {
    if (!craftTree.isShowHeaderPlace)
      return null

    local lastBranchIdx = branches.len() - 1
    local baseEff = craftTree.baseEfficiency
    local headerItemsTitle = craftTree?.headerItemsTitle ? ::loc(craftTree.headerItemsTitle) : null
    local bodyTitle = craftTree.bodiesConfig[0].title
    local bodyItemsTitle = bodyTitle != "" ? ::loc(bodyTitle) : null
    local headersView = branches.map((function(branch, idx) {
      local posX = branch.minPosX -1
      local paramsPosColumns = itemSizes.paramsPosColumnsByBodies[branch.bodyIdx]
      local { columnPos } = paramsPosColumns[posX]
      local nextBranchPos = paramsPosColumns?[posX + branch.itemsCountX].columnPos ?? itemSizes.maxBodyWidth
      return {
        branchHeader = branch?.locId != null ? ::loc(branch.locId) : null
        headerItemsTitle = idx == lastBranchIdx ? headerItemsTitle : ""
        bodyItemsTitle = idx == lastBranchIdx ? bodyItemsTitle : ""
        positionsTitleX = 0
        branchId = getBranchId(idx)
        branchHeaderItems = getHeaderView(branch.headerItems, itemsList, baseEff)
        branchWidth = nextBranchPos - columnPos
        separators = idx != 0
        hasHeaderItems = craftTree.hasHeaderItems
      }
    }).bindenv(this))

    local totalWidth = headersView.map(@(branch) branch.branchWidth).reduce(@(res, value) res + value)
    local positionsTitleXLastBranch = "{widthLastBranch} - 0.5*{totalWidth} - 0.5w".subst({
      totalWidth = totalWidth
      widthLastBranch = headersView[lastBranchIdx].branchWidth
    })
    headersView[lastBranchIdx].positionsTitleX = positionsTitleXLastBranch
    return headersView
  }

  function getBodyView()
  {
    local { resourceWidth, itemBlockHeight, visibleItemsCountYByBodies,
      headerBlockInterval, itemsOffsetByBodies, itemBlockInterval, titleMargin,
      bodiesOffset, titleHeight, maxBodyWidth, itemHeightFull, paramsPosColumnsByBodies } = itemSizes
    local itemBlocksArr = []
    local shopArrows = []
    local conectionsInRow = []
    local textBlocks = []
    local buttons = []
    local bodiesConfig = craftTree.bodiesConfig
    foreach (idx, rows in craftTree.treeRowsByBodies) {
      local connectingElements = getRowsElementsView(rows, itemSizes, itemsList,
        bodiesConfig[idx].allowableResources, workshopSet)
      shopArrows.extend(connectingElements.shopArrows)
      conectionsInRow.extend(connectingElements.conectionsInRow)
      itemBlocksArr.extend(connectingElements.itemBlocksArr)
      textBlocks.extend(getTextBlocksView(bodiesConfig[idx].textBlocks, itemSizes))
      local buttonView = getButtonView(bodiesConfig[idx], itemSizes)
      if (buttonView != null)
        buttons.append(buttonView)
    }

    local separators = []
    local isShowHeaderPlace = craftTree.isShowHeaderPlace
    local bodyTitles = isShowHeaderPlace ? [] : getBodyItemsTitles(bodiesConfig, itemSizes)
    foreach (idx, branch in branches) {
      local bodyConfig = bodiesConfig[branch.bodyIdx]
      local itemsCountY = visibleItemsCountYByBodies[branch.bodyIdx]
      if (itemsCountY == 0)
        continue
      separators.append(getBranchSeparator(branch, itemSizes,
        itemsCountY * itemBlockHeight + headerBlockInterval))
      if (!isShowHeaderPlace && branch?.locId != null) {
        local posX = branch.minPosX -1
        local paramsPosColumns = paramsPosColumnsByBodies[branch.bodyIdx]
        local { columnPos } = paramsPosColumns[posX]
        local nextBranchPos = paramsPosColumns?[posX + branch.itemsCountX].columnPos ?? maxBodyWidth
        bodyTitles.append({
          bodyTitleText = ::loc(branch.locId)
          titlePos = posFormatString.subst(columnPos,
            (bodiesConfig[branch.bodyIdx].bodyTitlesCount > 1 ? titleMargin : 0)
              + bodiesOffset[branch.bodyIdx] + (bodyConfig.title != "" ? titleHeight : 0))
          titleSize = posFormatString.subst(nextBranchPos - columnPos, titleHeight)
          hasSeparator = posX != 0
        })
      }
    }

    local fullBodyHeightWithoutResult = itemsOffsetByBodies.top()
      + headerBlockInterval + visibleItemsCountYByBodies.top() * itemBlockHeight
    local craftResult = craftTree?.craftResult
    local hasCraftResult = craftResult != null
    if (hasCraftResult)
    {
      local itemBlock = craftResult.__merge({
        showResources = true
        isFullSize = true
        overridePos = posFormatString.subst(0.5*maxBodyWidth - 0.5*(itemHeightFull + resourceWidth),
          fullBodyHeightWithoutResult + headerBlockInterval)
      })
      itemBlocksArr.append(getItemBlockView({
        itemBlock = itemBlock,
        itemConfig = getConfigByItemBlock(itemBlock, itemsList, workshopSet),
        itemSizes = itemSizes,
        allowableResources = craftTree.allowableResourcesForCraftResult
      }))

      separators.append({
        separatorPos = posFormatString.subst("0.5pw - 0.5w", fullBodyHeightWithoutResult)
        separatorSize = posFormatString.subst(maxBodyWidth, "1@dp")
      })
    }
    return {
      bodyTitles
      bodyBackground = getBodyBackground(bodiesConfig, itemSizes, fullBodyHeightWithoutResult)
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
      isTooltipByHold = ::show_console_buttons
    }
  }

  function findItemObj(itemId)
  {
    return scene.findObject("shop_item_" + itemId)
  }

  function onItemAction(buttonObj)
  {
    local id = buttonObj?.holderId ?? "-1"
    local item = itemsList?[id.tointeger()]
    local itemObj = findItemObj(id)
    doMainAction(item, itemObj)
  }

  function onItemHover(obj) {
    local id = obj?.holderId ?? "-1"
    local item = itemsList?[id.tointeger()]
    setFocusItem(item)
  }

  function onMainAction()
  {
    local curItemParam = getCurItemParam()
    local button = curItemParam.button
    if (button?.onClick != null) {
      this[button.onClick]()
      return
    }

    local item = curItemParam.item
    local itemObj = curItemParam.obj
    if (item == null)
      return

    local itemBlock = craftTree?.craftResult.id == item.id
      ? craftTree.craftResult
      : null
    if (itemBlock == null)
      foreach(branche in branches)
      {
        itemBlock = branche.branchItems?[item.id]
        if (itemBlock != null)
          break
      }

    if (!(item.isCrafting() || item.hasCraftResult())
        && (needReqItems(itemBlock, itemsList)
          || isRequireCondition(itemBlock?.reqItemForCrafting ?? [], itemsList, hasAmount)))
      return

    doMainAction(item, itemObj)
  }

  function doMainAction(item, obj)
  {
    if (item == null)
      return

    item.doMainAction(null, this, {
      obj = obj
      isHidePrizeActionBtn = true
      canConsume = false
    })
  }

  function getCurItemParam()
  {
    local value = ::get_obj_valid_index(itemsListObj)
    if (value < 0)
      return {
        obj = null
        item = null
        button = null
      }

    local itemObj = itemsListObj.getChild(value)
    return {
      obj = itemObj
      item = itemsList?[(itemObj?.itemId ?? "-1").tointeger()]
      button = bodyButtonsConfig?[itemObj?.id ?? ""]
    }
  }

  function onTimer(obj, dt)
  {
    foreach(item in itemsList)
    {
      if (!item.hasTimer())
        continue

      local itemObj = findItemObj(item.id)
      if (!::check_obj(itemObj))
        continue
      local timeTxtObj = itemObj.findObject("expire_time")
      if (::check_obj(timeTxtObj))
        timeTxtObj.setValue(item.getTimeLeftText())
      timeTxtObj = itemObj.findObject("craft_time")
      if (::check_obj(timeTxtObj))
        timeTxtObj.setValue(item.getCraftTimeTextShort())
    }
  }

  function updateCraftTree()
  {
    local curItemParam = getCurItemParam()

    craftTree = workshopSet.getCraftTree() ?? craftTree
    branches = craftTree.branches
    itemsList = workshopSet.getItemsListForCraftTree(craftTree)
    getItemSizes()
    scene.findObject("wnd_title").setValue(::loc(craftTree.headerlocId))

    local view = {
      itemsSize = itemSizes.name
      headersView = getHeadersView()
    }
    local data = ::handyman.renderCached("gui/items/craftTreeHeader", view)
    guiScene.replaceContentFromText(scene.findObject("craft_header"), data, data.len(), this)

    view = getBodyView()
    itemsListObj.size = posFormatString.subst(view.bodyWidth, view.bodyHeight)
    data = ::handyman.renderCached("gui/items/craftTreeBody", view)
    guiScene.replaceContentFromText(itemsListObj, data, data.len(), this)
    setFocusItem(curItemParam.item)
    ::move_mouse_on_child_by_value(itemsListObj)
  }

  function setFocusItem(curItem = null)
  {
    local curItemId = curItem?.id.tostring() ?? ""
    local enabledValue = null
    for(local i = 0; i < itemsListObj.childrenCount(); i++)
    {
      local childObj = itemsListObj.getChild(i)
      if (enabledValue == null && childObj.isEnabled())
        enabledValue = i
      if (childObj?.itemId != curItemId)
        continue

      itemsListObj.setValue(i)
      return
    }
    local curIdx = ::get_obj_valid_index(itemsListObj)
    if (curIdx >= 0 && itemsListObj.getChild(curIdx).isEnabled())
      itemsListObj.setValue(curIdx)
    else if (enabledValue != null)
      itemsListObj.setValue(enabledValue)
  }

  function onEventInventoryUpdate(p)
  {
    doWhenActiveOnce("updateCraftTree")
  }

  function onEventProfileUpdated(p)
  {
    doWhenActiveOnce("updateCraftTree")
  }

  function onToMarketplaceButton() {
    goToMarketplace()
  }
}

::gui_handlers.craftTreeWnd <- handlerClass

return {
  open = @(craftTreeParams) ::handlersManager.loadHandler(handlerClass, craftTreeParams)
}