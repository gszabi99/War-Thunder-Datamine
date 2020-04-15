::dagui_propid.add_name_id("itemId")

local branchIdPrefix = "branch_"
local getBranchId = @(idx) "".concat(branchIdPrefix, idx)
local posFormatString = "{0}, {1}"

local sizeAndPosViewConfig = {
  verticalArrow = ::kwarg(
    function verticalArrow(itemSizes, bodyIdx, arrowSizeX, arrowSizeY, arrowPosX, arrowPosY) {
      local w = itemSizes.arrowWidth
      local h = (::abs(arrowSizeY) - 1)*(itemSizes.itemBlockHeight)
        + itemSizes.itemBlockInterval - 2*itemSizes.blockInterval
      local isInUpArrow = arrowSizeY < 0
      local posY = isInUpArrow ? arrowPosY + arrowSizeY : arrowPosY
      return {
        arrowsParts = [{
          partTag = "shopArrow"
          partType = "vertical"
          partSize = posFormatString.subst(w, h)
          partPos = posFormatString.subst(
            arrowPosX * itemSizes.itemBlockWidth + itemSizes.columnOffests[arrowPosX - 1]
              - 0.5*itemSizes.itemHeight - 0.5*w,
            itemSizes.itemsOffsetByBodies[bodyIdx]
              + posY * itemSizes.itemBlockHeight - itemSizes.itemBlockInterval
              + itemSizes.headerBlockInterval + itemSizes.blockInterval)
          partRotation = isInUpArrow ? 180 : 0
        }]
      }
  })
  horizontalArrow = ::kwarg(
    function horizontalArrow(itemSizes, bodyIdx, arrowSizeX, arrowSizeY, arrowPosX, arrowPosY) {
      local countBranches = ::abs(itemSizes.columnBranchsCount[arrowPosX -1]
        - itemSizes.columnBranchsCount[arrowPosX + arrowSizeX - 1])
      local w = (countBranches + 1) * itemSizes.itemInterval
        + (::abs(arrowSizeX) - 1)*(itemSizes.itemBlockWidth + itemSizes.resourceWidth)
        + itemSizes.resourceWidth - 2*itemSizes.blockInterval
      local h = itemSizes.arrowWidth
      local isInLeftArrow = arrowSizeX < 0
      local posX = isInLeftArrow ? arrowPosX + arrowSizeX : arrowPosX
      return {
        arrowsParts = [{
          partTag = "shopArrow"
          partType = "horizontal"
          partSize = posFormatString.subst(w, h)
          partPos = posFormatString.subst(
            posX*(itemSizes.itemBlockWidth)
              + itemSizes.columnOffests[posX - 1] + itemSizes.blockInterval,
            itemSizes.itemsOffsetByBodies[bodyIdx]
              + (arrowPosY - 1)*(itemSizes.itemBlockHeight)
              + 0.5*itemSizes.itemHeight - 0.5*h + itemSizes.headerBlockInterval)
          partRotation = isInLeftArrow ? 180 : 0
        }]
      }
  })
  combineArrow = ::kwarg(
    function combineArrow(itemSizes, bodyIdx, arrowSizeX, arrowSizeY, arrowPosX, arrowPosY, isInMultipleArrow, isOutMultipleArrow) {
      local isInLeftArrow = arrowSizeX < 0
      local offsetIn = isInMultipleArrow ? 0.2 : 0
      local arrowOffsetIn = isInLeftArrow ? offsetIn : -offsetIn
      local offsetOut = isOutMultipleArrow ? 0.2 : 0
      local arrowOffsetOut = isInLeftArrow ? -offsetOut : offsetOut
      local posX = isInLeftArrow ? arrowPosX + arrowSizeX : arrowPosX
      local countBranches = ::abs(itemSizes.columnBranchsCount[arrowPosX - 1]
        - itemSizes.columnBranchsCount[arrowPosX + arrowSizeX - 1])

      local beginLineHeight = 0.5*((::abs(arrowSizeY) - 1) * itemSizes.itemBlockHeight
        + itemSizes.itemBlockInterval - 2*itemSizes.blockInterval)
      local absoluteArrowPosX = (arrowPosX + arrowSizeX)*(itemSizes.itemBlockWidth)
        + itemSizes.columnOffests[arrowPosX + arrowSizeX - 1]
        - 0.5*itemSizes.itemHeight - 0.5*itemSizes.arrowWidth + arrowOffsetIn*itemSizes.itemHeight
      local absoluteArrowPosY = itemSizes.itemsOffsetByBodies[bodyIdx]
        + arrowPosY * itemSizes.itemBlockHeight - beginLineHeight
        + itemSizes.headerBlockInterval - itemSizes.blockInterval
      local absoluteBeginLinePosY = itemSizes.itemsOffsetByBodies[bodyIdx]
        + (arrowPosY - 1)*(itemSizes.itemBlockHeight)
        + itemSizes.itemHeight + itemSizes.headerBlockInterval + itemSizes.blockInterval

      return {
        arrowsParts = [{
          partTag = "shopArrow"
          partType = "vertical"
          partSize = posFormatString.subst(itemSizes.arrowWidth, beginLineHeight)
          partPos = posFormatString.subst(absoluteArrowPosX, absoluteArrowPosY)
          partRotation = 0
        },
        {
          partTag = "shopLine"
          partSize = posFormatString.subst(beginLineHeight, itemSizes.arrowWidth)
          partPos = posFormatString.subst(
            arrowPosX * itemSizes.itemBlockWidth + itemSizes.columnOffests[arrowPosX - 1]
              + (arrowOffsetOut - 0.5) * itemSizes.itemHeight + 0.5*itemSizes.arrowWidth,
            absoluteBeginLinePosY)
          partRotation = 90
        },
        {
          partTag = "shopLine"
          partSize = posFormatString.subst(
            ::abs(arrowSizeX) * (itemSizes.itemBlockWidth + itemSizes.resourceWidth)
              + countBranches * itemSizes.itemInterval
              - (offsetIn + offsetOut)*itemSizes.itemHeight,
            itemSizes.arrowWidth)
          partPos = posFormatString.subst(
            posX*(itemSizes.itemBlockWidth)
              + itemSizes.columnOffests[posX - 1]
              + ((isInLeftArrow ? arrowOffsetIn : arrowOffsetOut) - 0.5) * itemSizes.itemHeight,
            absoluteBeginLinePosY + beginLineHeight - 0.5*itemSizes.arrowWidth)
          partRotation = 0
        },
        {
          partTag = "shopAngle"
          partSize = posFormatString.subst(itemSizes.arrowWidth, itemSizes.arrowWidth)
          partPos = posFormatString.subst(absoluteArrowPosX, absoluteArrowPosY - 0.5*itemSizes.arrowWidth)
          partRotation = isInLeftArrow ? 90 : 180
        },
        {
          partTag = "shopAngle"
          partSize = posFormatString.subst(itemSizes.arrowWidth, itemSizes.arrowWidth)
          partPos = posFormatString.subst(
            arrowPosX * itemSizes.itemBlockWidth + itemSizes.columnOffests[arrowPosX - 1]
              + (arrowOffsetOut - 0.5) * itemSizes.itemHeight - 0.5*itemSizes.arrowWidth,
            absoluteBeginLinePosY + beginLineHeight - 0.5*itemSizes.arrowWidth)
          partRotation = isInLeftArrow ? -90 : 0
        }]
      }
  })
  conectionInRow = ::kwarg(function conectionInRow(itemSizes, bodyIdx, itemPosX, itemPosY) {
    return {
      conectionWidth = itemSizes.itemInterval
      conectionPos = posFormatString.subst(
        itemPosX * itemSizes.itemBlockWidth
          + itemSizes.columnOffests[itemPosX],
        "{0} - 0.5h".subst(itemSizes.itemsOffsetByBodies[bodyIdx]
          + itemPosY*(itemSizes.itemBlockHeight)
          + 0.5*itemSizes.itemHeight  + itemSizes.headerBlockInterval))
    }
  })
  itemPos = ::kwarg(function itemPos(itemSizes, bodyIdx, itemPosX, itemPosY) {
    return posFormatString.subst(
      itemPosX * itemSizes.itemBlockWidth + itemSizes.itemInterval
        + itemSizes.columnOffests[itemPosX],
      itemSizes.itemsOffsetByBodies[bodyIdx]
        + itemPosY * itemSizes.itemBlockHeight + itemSizes.headerBlockInterval)
  })
  textBlock = ::kwarg(function textBlock(itemSizes, bodyIdx, posX, posY, endPosX, endPosY, sizeX, sizeY, texts) {
    local countBranches = itemSizes.columnBranchsCount[endPosX]- itemSizes.columnBranchsCount[posX]
    local w = (countBranches - 1) * itemSizes.itemInterval
      + sizeX * (itemSizes.itemBlockWidth + itemSizes.resourceWidth)

    return {
      textBlockSize = posFormatString.subst(
        w,
        sizeY * itemSizes.itemBlockHeight - itemSizes.itemBlockInterval
      )
      textBlockPos = posFormatString.subst(
        posX * itemSizes.itemBlockWidth + itemSizes.itemInterval
          + itemSizes.columnOffests[posX],
        itemSizes.itemsOffsetByBodies[bodyIdx]
          + posY * itemSizes.itemBlockHeight + itemSizes.headerBlockInterval
      )
      textInBlock = "\n".join(texts.map(@(text) ::loc(text)))
      textSize = itemSizes.textInTextBlockSize
    }
  })
}

local sucessItemCraftIconParam = {
  amountIcon = "#ui/gameuiskin#check.svg"
  amountIconColor = "@goodTextColor"
}

local function getSucessItemCraftIcon(item) {
  return item.maxAmount != 0
    ? sucessItemCraftIconParam
    : {
      amountIcon = ""
      amountIconColor = ""
    }
}

local function needReqItems(itemBlock, itemsList) {
  foreach(reqItemId in (itemBlock?.reqItems ?? []))
    if (reqItemId != null && (itemsList?[reqItemId].getAmount() ?? 0) == 0)
      return true

  return false
}

local function needReqItemsForCraft(itemBlock, itemsList) {
  local needCondForCraft = false
  foreach (reqItemBlock in (itemBlock?.reqItemForCrafting ?? [])) {
    local canCraft = true
    foreach (itemId, needHave in reqItemBlock) {
      local amount = itemsList?[itemId].getAmount() ?? 0
      if ((needHave && amount > 0) || (!needHave && amount == 0))
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

local function getConfigByItemBlock(itemBlock, itemsList, workshopSet)
{
  local item = itemsList?[itemBlock?.id]
  local hasComponent = itemBlock?.showResources
  local itemId = item?.id ?? "-1"
  local isCraftingOrHasCraftResult = item != null && (item.isCrafting() || item.hasCraftResult())
  local needReqItemForCraft = needReqItemsForCraft(itemBlock, itemsList)
  local isDisabledAction = !isCraftingOrHasCraftResult
    && (needReqItemForCraft || needReqItems(itemBlock, itemsList))
  local isDisguised = (itemBlock?.reqItemForIdentification ?? []).findindex(
    @(itemId) !workshopSet.isItemIdKnown(itemId)) != null
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
    iconInsteadAmount = hasReachedMaxAmount ? getSucessItemCraftIcon(item) : null
    conectionInRowText = itemBlock?.conectionInRowText
    isDisguised = !hasItemInInventory && isDisguised
    isHidden = !hasItemInInventory && (itemBlock?.reqItemForDisplaying ?? []).findindex(
        @(itemId) !workshopSet.isItemIdKnown(itemId)) != null
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
    return {
      isDisabled = itemConfig.isDisabled
      itemId = itemConfig.itemId
      items = [item.getViewData(viewItemsParams.__merge({
        itemIndex = itemConfig.itemId,
        showAction = !itemConfig.isDisabledAction
        iconInsteadAmount = itemConfig.iconInsteadAmount
        count = item.maxAmount == 1 ? item.getAdditionalTextInAmmount(true, true) : null
        showTooltip = !itemConfig.isDisguised
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
    foreach (idx, itemBlock in row)
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

      local arrows = itemBlock?.arrows ?? []
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
        local curBranchIdx = itemSizes.columnBranchsCount[itemPosX]
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
    items.append(item.getViewData(viewItemsParams.__merge({
      hasBoostEfficiency = true
      iconInsteadAmount = item.hasReachedMaxAmount() ? sucessItemCraftIconParam : null
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
  return {
    separatorPos = posFormatString.subst(posX * itemSizes.itemBlockWidth
        + itemSizes.columnOffests[posX],
      $"3@dp + {rowOffset}")
    separatorSize = posFormatString.subst("1@dp", "{0} - 6@dp".subst(branchHeight))
  }
}

local function getBodyItemsTitles(titlesConfig, itemSizes) {
  local titlesView = []
  foreach (body in titlesConfig)
    if (body.title != "")
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
    isHidden = @() !::ItemsManager.isMarketplaceEnabled()
  }
}
local buttonViewParams = {
  shortcut = ""
  btnName = "A"
  showOnSelect = "focus"
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

local handlerClass = class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType          = handlerType.MODAL
  sceneTplName     = "gui/items/craftTreeWnd"
  focusArray       = ["craft_body"]
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
    restoreFocus()
    setFocusItem(showItemOnInit)
  }

  function getItemSizes() {
    local bodiesConfig = craftTree.bodiesConfig
    local maxItemsCountX = bodiesConfig.reduce(@(res, value) ::max(res, value.itemsCountX), 0)
    local maxBranchesCount = bodiesConfig.reduce(@(res, value) ::max(res, value.branchesCount), 0)
    local resourceWidth = ::to_pixels("1@craftTreeResourceWidth")
    local allColumnResourceWidth = bodiesConfig.reduce(
      @(res, value) ::max(res, value.columnWithResourcesCount), 0) * resourceWidth
    local maxAllowedCrafTreeWidth = ::to_pixels("1@maxWindowWidth - 2@frameHeaderPad + 1@scrollBarSize")
    local craftTreeWidthString = ("{itemsCount}(1@{itemPrefix}temHeight + 1@{intervalPrefix}raftTreeItemInterval) + "
      + "{branchesCount}@{intervalPrefix}raftTreeItemInterval + {allColumnResourceWidth}").subst({
        itemsCount = maxItemsCountX
        branchesCount = maxBranchesCount
        allColumnResourceWidth = allColumnResourceWidth
      })

    local sizes = ::u.search(sizePrefixNames,
        @(prefix) ::to_pixels(craftTreeWidthString.subst({
            itemPrefix = prefix.itemPrefix
            intervalPrefix = prefix.intervalPrefix
          })) <= maxAllowedCrafTreeWidth)
      ?? sizePrefixNames.small
    local itemInterval = ::to_pixels("1@{0}raftTreeItemInterval)".subst(sizes.intervalPrefix))
    local columnOffests = []
    local columnBranchsCount =[]
    foreach(paramsColumn in craftTree.paramsForPosByColumns)
    {
      columnOffests.append(paramsColumn.countBranchs * itemInterval
        + paramsColumn.prevResourcesCount * resourceWidth)
      columnBranchsCount.append(paramsColumn.countBranchs)
    }

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
    local isItemIdKnown = workshopSet.isItemIdKnown.bindenv(workshopSet)
    local buttonHeight = ::to_pixels("1@buttonHeight") + 2*::to_pixels("1@buttonMargin")
    local items = itemsList
    foreach (idx, rows in craftTree.treeRowsByBodies) {
      local visibleItemsCountY = 0
      for (local i = rows.len(); i > 0; i--)
        if (rows[i-1].findindex(
          function(itemBlock) {
            local item = items?[itemBlock?.id]
            local hasItemInInventory = item != null
              && (item.getAmount() != 0 || item.isCrafting() || item.hasCraftResult())
            return hasItemInInventory
              || ((itemBlock?.reqItemForDisplaying ?? []).findindex(@(itemId) !isItemIdKnown(itemId)) == null)
          }) != null)
        {
          visibleItemsCountY = i
          break
        }
      local textBlocks = bodiesConfig[idx].textBlocks
      textBlocks.sort(@(a, b) a.endPosY <=> b.endPosY)
      visibleItemsCountY = ::max(visibleItemsCountY,
        textBlocks.len() > 0 ? (textBlocks.top().endPosY + 1) : 0)
      curBodiesOffset += isShowHeaderPlace || idx == 0 ? 0
        : (bodiesConfig[idx-1].bodyTitlesCount * titleHeight
            + visibleItemsCountYByBodies[idx-1] * itemBlockHeight + headerBlockInterval
            + (bodiesConfig[idx-1].button != null ? buttonHeight : 0)
          )
      itemsOffsetByBodies.append(curBodiesOffset
        + (isShowHeaderPlace ? 0 : (bodiesConfig[idx].bodyTitlesCount * titleHeight)))
      bodiesOffset.append(curBodiesOffset)
      visibleItemsCountYByBodies.append(visibleItemsCountY)
    }

    return sizes.__update({
      itemHeight = itemHeight
      itemHeightFull = ::to_pixels("1@itemHeight")
      itemInterval = itemInterval
      itemBlockInterval = itemBlockInterval
      resourceWidth = resourceWidth
      scrollBarSize = ::to_pixels("1@scrollBarSize")
      arrowWidth = ::to_pixels("1@modArrowWidth")
      headerBlockInterval = headerBlockInterval
      blockInterval = ::to_pixels("1@blockInterval")
      columnOffests = columnOffests
      columnBranchsCount = columnBranchsCount
      itemBlockHeight = itemBlockHeight
      itemBlockWidth = itemHeight + itemInterval
      titleHeight = titleHeight
      maxItemsCountX = maxItemsCountX
      maxBranchesCount = maxBranchesCount
      allColumnResourceWidth = allColumnResourceWidth
      itemsOffsetByBodies = itemsOffsetByBodies
      bodiesOffset = bodiesOffset
      visibleItemsCountYByBodies = visibleItemsCountYByBodies
    })
  }

  getBranchWidth = @(branch, hasScrollBar) branch.itemsCountX * itemSizes.itemBlockWidth
    + itemSizes.itemInterval + branch.columnWithResourcesCount * itemSizes.resourceWidth
    + (hasScrollBar ? itemSizes.scrollBarSize : 0)

  function getHeadersView()
  {
    if (!craftTree.isShowHeaderPlace)
      return null

    local lastBranchIdx = branches.len() - 1
    local baseEff = craftTree.baseEfficiency
    local headerItemsTitle = craftTree?.headerItemsTitle ? ::loc(craftTree.headerItemsTitle) : null
    local bodyTitle = craftTree.bodiesConfig[0].title
    local bodyItemsTitle = bodyTitle != "" ? ::loc(bodyTitle) : null
    local headersView = branches.map((@(branch, idx) {
      branchHeader = branch?.locId != null ? ::loc(branch.locId) : null
      headerItemsTitle = idx == lastBranchIdx ? headerItemsTitle : ""
      bodyItemsTitle = idx == lastBranchIdx ? bodyItemsTitle : ""
      positionsTitleX = 0
      branchId = getBranchId(idx)
      branchHeaderItems = getHeaderView(branch.headerItems, itemsList, baseEff)
      branchWidth = getBranchWidth(branch, idx == lastBranchIdx)
      separators = idx != 0
      hasHeaderItems = craftTree.hasHeaderItems
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

    local bodyWidth = itemSizes.maxItemsCountX * itemSizes.itemBlockWidth
      + itemSizes.maxBranchesCount * itemSizes.itemInterval + itemSizes.allColumnResourceWidth
      + itemSizes.scrollBarSize
    local separators = []
    local isShowHeaderPlace = craftTree.isShowHeaderPlace
    local bodyTitles = isShowHeaderPlace ? [] : getBodyItemsTitles(bodiesConfig, itemSizes)
    foreach (idx, branch in branches) {
      local bodyConfig = bodiesConfig[branch.bodyIdx]
      local itemsCountY = itemSizes.visibleItemsCountYByBodies[branch.bodyIdx]
      local posX = branch.minPosX -1
      separators.append(getBranchSeparator(branch, itemSizes,
        itemsCountY * itemSizes.itemBlockHeight + itemSizes.headerBlockInterval))
      if (!isShowHeaderPlace && branch?.locId != null)
        bodyTitles.append({
          bodyTitleText = ::loc(branch.locId)
          titlePos = posFormatString.subst(posX * itemSizes.itemBlockWidth
              + itemSizes.columnOffests[posX],
            $"1@dp + {itemSizes.bodiesOffset[branch.bodyIdx] + (bodyConfig.title != "" ? itemSizes.titleHeight : 0)}")
          titleSize = posFormatString.subst(getBranchWidth(branch, false),
            itemSizes.titleHeight)
          hasSeparator = posX != 0
        })
    }

    local fullBodyHeightWithoutResult = itemSizes.itemsOffsetByBodies.top()
      + itemSizes.headerBlockInterval
      + itemSizes.visibleItemsCountYByBodies.top() * itemSizes.itemBlockHeight
    local craftResult = craftTree?.craftResult
    local hasCraftResult = craftResult != null
    if (hasCraftResult)
    {
      local itemBlock = craftResult.__merge({
        showResources = true
        isFullSize = true
        overridePos = posFormatString.subst(0.5*bodyWidth - 0.5*(itemSizes.itemHeightFull + itemSizes.resourceWidth),
          fullBodyHeightWithoutResult + itemSizes.headerBlockInterval)
      })
      itemBlocksArr.append(getItemBlockView({
        itemBlock = itemBlock,
        itemConfig = getConfigByItemBlock(itemBlock, itemsList, workshopSet),
        itemSizes = itemSizes,
        allowableResources = craftTree.allowableResourcesForCraftResult
      }))

      separators.append({
        separatorPos = posFormatString.subst("0.5pw - 0.5w", fullBodyHeightWithoutResult)
        separatorSize = posFormatString.subst(bodyWidth, "1@dp")
      })
    }
    return {
      bodyTitles = bodyTitles
      bodyHeight = fullBodyHeightWithoutResult
        + (hasCraftResult
          ? (itemSizes.headerBlockInterval + itemSizes.itemHeightFull + itemSizes.itemBlockInterval)
          : 0)
      bodyWidth = bodyWidth
      separators = separators
      itemBlock = itemBlocksArr
      shopArrows = shopArrows
      conectionsInRow = conectionsInRow
      textBlocks = textBlocks
      buttons = buttons
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
    setFocusItem(item)
    doMainAction(item, itemObj)
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
          || needReqItemsForCraft(itemBlock, itemsList)))
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
    if (enabledValue != null)
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
    ::ItemsManager.goToMarketplace()
  }
}

::gui_handlers.vehiclesModal <- handlerClass

return {
  open = @(craftTreeParams) ::handlersManager.loadHandler(handlerClass, craftTreeParams)
}