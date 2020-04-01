local inventoryClient = require("scripts/inventory/inventoryClient.nut")

local DEFAULT_BRANCH_CONFIG = {
  locId = ""
  minPosX = 1
  itemsCountX = 1
  columnWithResourcesCount = 0
  headerItems = []
  branchItems = {}
  bodyIdx = 0
  textBlocks = []
  itemsIdList = {}
}

local function getHeaderItems(branchBlk)
{
  local headerItems = branchBlk?.headerItems
  return headerItems != null ? (headerItems % "headerItem") : []
}

local function getArrowConfigByItems(item, reqItem)
{
  local reqItemPos = reqItem.posXY
  local itemPos = item.posXY
  return {
    posX = reqItemPos.x
    posY = reqItemPos.y
    sizeX = itemPos.x - reqItemPos.x
    sizeY = itemPos.y - reqItemPos.y
    reqItemId = reqItem.id
    itemId = item.id
    bodyIdx = item.bodyIdx
    isOutMultipleArrow = false
  }
}

local function addDownOutArrow(reqItemsWithDownOutArrows, arrowConfig) {
  if (arrowConfig.sizeY != 0) {//not horizontal arrow
    local reqItemId = arrowConfig.reqItemId
    reqItemsWithDownOutArrows[reqItemId] <-
      (reqItemsWithDownOutArrows?[reqItemId] ?? []).append(arrowConfig.itemId)
  }

  return reqItemsWithDownOutArrows
}

local function getReqItemsArray(reqItems) {
  local itemsIdArray = []
  local fullItemsIdList = {}
  foreach (reqItemsString in reqItems) {
    local itemsTbl = {}
    foreach (reqId in reqItemsString.split(",")) {
      local needHave = !::g_string.startsWith(reqId, "!") // true = need to have, false = need to NOT have.
      local itemId = reqId.slice(needHave ? 0 : 1).tointeger()
      itemsTbl[itemId] <- needHave
    }
    itemsIdArray.append(itemsTbl)
    fullItemsIdList.__update(itemsTbl)
  }
  return {
    fullItemsIdList = fullItemsIdList
    itemsIdArray = itemsIdArray
  }
}

local function generateRows(branchBlk, treeRows)
{
  local branchItems = {}
  local textBlocks = []
  local notFoundReqForItems = {}
  local minPosX = null
  local maxPosX = null
  local resourcesInColumn = {}
  local reqItemsWithDownOutArrows = {}
  local bodyIdx = branchBlk?.bodyItemIdx ?? 0
  local itemsIdList = {}
  if (treeRows.len() < bodyIdx + 1)
    treeRows.resize(bodyIdx + 1, array(0, null))

  for(local i = 0; i < branchBlk.blockCount(); i++)
  {
    local iBlk = branchBlk.getBlock(i)
    local id = iBlk.getBlockName()
    if (id == "textArea") {
      local posX = iBlk.posXYFrom.x.tointeger()
      local posY = iBlk.posXYFrom.y.tointeger()
      local endPosX = iBlk.posXYTo.x.tointeger()
      local endPosY = iBlk.posXYTo.y.tointeger()
      minPosX = ::min(minPosX ?? posX, posX)
      maxPosX = ::max(maxPosX ?? endPosX, endPosX)
      textBlocks.append({
        posX = posX - 1
        posY = posY - 1
        endPosX = endPosX - 1
        endPosY = endPosY - 1
        sizeX = endPosX - posX + 1
        sizeY = endPosY - posY + 1
        bodyIdx = bodyIdx
        texts = iBlk % "text"
      })
      continue
    }

    id = ::to_integer_safe(id, id, false)
    if (!::ItemsManager.isItemdefId(id))
      continue

    local addReqItemId = function(itemId) {
      itemId = itemId.tointeger()
      itemsIdList[itemId] <- true
      return itemId
    }
    local reqItemForCrafting = getReqItemsArray(iBlk % "reqItemForCrafting")
    itemsIdList.__update(reqItemForCrafting.fullItemsIdList)
    local itemConfig = {
      id = id
      bodyIdx = bodyIdx
      conectionInRowText = branchBlk?.conectionInRowText ?? "+"
      posXY = iBlk.posXY
      showResources = iBlk?.showResources ?? false
      reqItems = (iBlk % "reqItem").map(@(itemId)itemId.tointeger())
      reqItemForDisplaying = (iBlk % "reqItemForDisplaying").map(addReqItemId)
      reqItemForIdentification = (iBlk % "reqItemForIdentification").map(addReqItemId)
      reqItemForCrafting = reqItemForCrafting.itemsIdArray
      arrows = []
    }

    local posX = itemConfig.posXY.x.tointeger()
    local posY = itemConfig.posXY.y.tointeger()
    minPosX = ::min(minPosX ?? posX, posX)
    maxPosX = ::max(maxPosX ?? posX, posX)
    if (itemConfig.showResources && resourcesInColumn?[posX] == null)
      resourcesInColumn[posX] <- 1

    foreach(reqItemId in itemConfig.reqItems) {
      if (branchItems?[reqItemId] != null) {
        local arrowConfig = getArrowConfigByItems(itemConfig, branchItems[reqItemId])
        reqItemsWithDownOutArrows = addDownOutArrow(reqItemsWithDownOutArrows, arrowConfig)
        itemConfig.arrows.append(arrowConfig)
      }
      else
        notFoundReqForItems[reqItemId] <- (notFoundReqForItems?[reqItemId] ?? []).append(itemConfig)
    }

    if (treeRows[bodyIdx].len() < posY)
      treeRows[bodyIdx].resize(posY, array(posX, null))

    if (treeRows[bodyIdx][posY-1].len() < posX)
      treeRows[bodyIdx][posY-1].resize(posX, null)

    branchItems[id] <- itemConfig
    itemsIdList[id] <- true
    treeRows[bodyIdx][posY-1][posX-1] = itemConfig
  }

  local searchReqForItems = clone notFoundReqForItems
  foreach(reqItemId, itemConfigs in searchReqForItems) {
    if (!(reqItemId in branchItems))
      continue

    foreach(itemConfig in itemConfigs) {
      local arrowConfig = getArrowConfigByItems(itemConfig, branchItems[reqItemId])
      reqItemsWithDownOutArrows = addDownOutArrow(reqItemsWithDownOutArrows, arrowConfig)
      itemConfig.arrows.append(arrowConfig)

      branchItems[itemConfig.id] = itemConfig
      itemsIdList[itemConfig.id] <- true
      treeRows[bodyIdx][itemConfig.posXY.y-1][itemConfig.posXY.x-1] = itemConfig
    }
    notFoundReqForItems.rawdelete(reqItemId)
  }

  if (notFoundReqForItems.len() > 0) {
    local craftTreeName = branchBlk?.locId ?? ""  // warning disable: -declared-never-used
    local reqItems = ::g_string.implode(notFoundReqForItems.keys(), "; ") // warning disable: -declared-never-used
    ::script_net_assert_once("Not found reqItems for craftTree", "Error: Not found reqItems")
  }

  foreach (reqItemId, downOutArrowIds in reqItemsWithDownOutArrows) {
    if (downOutArrowIds.len() <= 1) //is not multiple out arrow
      continue

    foreach (itemId in downOutArrowIds) {
      local itemConfig = branchItems[itemId]
      local arrowIdx = itemConfig.arrows.findindex(@(v) v.reqItemId == reqItemId)
      if (arrowIdx != null) {
        itemConfig.arrows[arrowIdx].isOutMultipleArrow = true
        branchItems[itemId] = itemConfig
        itemsIdList[itemId] <- true
        treeRows[bodyIdx][itemConfig.posXY.y-1][itemConfig.posXY.x-1] = itemConfig
      }
    }
  }

  minPosX = minPosX ?? 0
  maxPosX = maxPosX ?? 0
  local headerItems = getHeaderItems(branchBlk)
  headerItems.each(@(itemId) itemsIdList[itemId] <- true)
  return {
    treeRows = treeRows
    branch = DEFAULT_BRANCH_CONFIG.__merge({
      locId = branchBlk?.locId
      headerItems = headerItems
      minPosX = minPosX
      itemsCountX = maxPosX - minPosX + 1
      branchItems = branchItems
      resourcesInColumn = resourcesInColumn
      columnWithResourcesCount = resourcesInColumn.reduce(@(res, value) res + value, 0)
      bodyIdx = bodyIdx
      textBlocks = textBlocks
      itemsIdList = itemsIdList
    })
  }
}

local function getAllowableResources(resourcesBlk)
{
  if (resourcesBlk == null)
    return null

  local allowableResources = {}
  foreach(res in (resourcesBlk % "allowableResource"))
    allowableResources[::to_integer_safe(res, res, false)] <- true

  return allowableResources
}

local function getCraftResult(treeBlk)
{
  local craftResult = treeBlk?.craftResult
  if (!craftResult || !craftResult?.item)
    return null

  local reqItems = craftResult?.reqItems ?? ""
  return {
    id = craftResult.item
    reqItems = reqItems.split(",").map(@(item) item.tointeger())
  }
}

local function generateTreeConfig(blk)
{
  local branches = []
  local treeRowsByBodies = []
  foreach(branchBlk in blk % "treeBlock")
  {
    local configByBranch = generateRows(branchBlk, treeRowsByBodies)
    treeRowsByBodies = configByBranch.treeRows
    branches.append(DEFAULT_BRANCH_CONFIG.__merge(configByBranch.branch))
  }

  branches.sort(@(a, b) a.bodyIdx <=> b.bodyIdx
    || a.minPosX <=> b.minPosX)

  local craftResult = getCraftResult(blk)
  local craftTreeItemsList = {}
  if (craftResult != null)
    craftTreeItemsList[craftResult.id] <- true

  local bodyItemsTitles = blk % "bodyItemsTitle"
  local allowableResources = blk % "allowableResources"
  local resourcesInColumn = {}
  local availableBranchByColumns = {}
  local hasHeaderItems = false
  local bodiesConfig = []
  foreach (idx, branch in branches) {
     availableBranchByColumns[branch.minPosX-1] <- true
     craftTreeItemsList.__update(branch.itemsIdList)
     resourcesInColumn.__update(branch.resourcesInColumn)
     hasHeaderItems = hasHeaderItems || branch.headerItems.len() > 0

     local bodyIdx = branch.bodyIdx
     local bodyTitle = bodyItemsTitles?[bodyIdx] ?? ""
     if (!(bodyIdx in bodiesConfig))
       bodiesConfig.append({
         bodyIdx = bodyIdx
         branchesCount = 0
         itemsCountX = 0
         columnWithResourcesCount = 0
         title = bodyTitle
         allowableResources = getAllowableResources(allowableResources?[bodyIdx])
         hasBranchesTitles = false
         bodyTitlesCount = bodyTitle != "" ? 1 : 0
         treeColumnsCount = 0
         textBlocks = []
       })

     local curBodyConfig = bodiesConfig[bodyIdx]
     local hasBranchesTitlesInBody = curBodyConfig.hasBranchesTitles
     local hasBranchTitle = branch?.locId != null
     curBodyConfig.branchesCount++
     curBodyConfig.itemsCountX += branch.itemsCountX
     curBodyConfig.columnWithResourcesCount += branch.columnWithResourcesCount
     curBodyConfig.bodyTitlesCount += !hasBranchesTitlesInBody && hasBranchTitle ? 1 : 0
     curBodyConfig.hasBranchesTitles = hasBranchesTitlesInBody || hasBranchTitle
     curBodyConfig.treeColumnsCount += branch.itemsCountX
     curBodyConfig.textBlocks.extend(branch.textBlocks)
  }
  local paramsForPosByColumns = array(
    bodiesConfig.reduce(@(res, value) ::max(res, value.treeColumnsCount), 0), null)
  local resourcesCount = 0
  local countBranchs = 0
  foreach(idx, column in paramsForPosByColumns) {
    countBranchs += availableBranchByColumns?[idx] != null && idx > 0 ? 1 : 0
    paramsForPosByColumns[idx] = { countBranchs = countBranchs,
      prevResourcesCount = resourcesCount }
    resourcesCount += (resourcesInColumn?[idx+1] ?? 0)
  }

  local craftTreeItemsIdArray = craftTreeItemsList.keys()
  if (craftTreeItemsIdArray.len() > 0)   //request items by itemDefId for craft tree
    inventoryClient.requestItemdefsByIds(craftTreeItemsIdArray)

  return {
    headerlocId = blk?.main_header ?? ""
    headerItemsTitle = blk?.headerItemsTitle
    openButtonLocId = blk?.openButtonLocId ?? ""
    allowableResourcesForCraftResult = getAllowableResources(allowableResources?[bodiesConfig.len()])
    craftTreeItemsIdArray = craftTreeItemsIdArray
    branches = branches
    treeRowsByBodies = treeRowsByBodies
    reqFeaturesArr = blk?.reqFeature != null ? (blk.reqFeature).split(",") : []
    baseEfficiency = blk?.baseEfficiency.tointeger() ?? 0
    craftResult = craftResult
    paramsForPosByColumns = paramsForPosByColumns
    hasHeaderItems = hasHeaderItems
    bodiesConfig = bodiesConfig
    isShowHeaderPlace = bodiesConfig.len() == 1
  }
}

return generateTreeConfig