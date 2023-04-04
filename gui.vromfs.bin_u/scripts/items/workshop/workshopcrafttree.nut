//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let inventoryClient = require("%scripts/inventory/inventoryClient.nut")
let { appendOnce } = require("%sqStdLibs/helpers/u.nut")

let DEFAULT_BRANCH_CONFIG = {
  locId = ""
  minPosX = 1
  itemsCountX = 1
  columnWithResourcesCount = 0
  headerItems = []
  branchItems = {}
  bodyIdx = 0
  textBlocks = []
  buttonConfig = null
  itemsIdList = {}
}

let function getHeaderItems(branchBlk) {
  let headerItems = branchBlk?.headerItems
  return headerItems != null ? (headerItems % "headerItem") : []
}

let function getArrowConfigByItems(item, reqItem) {
  let reqItemPos = reqItem.posXY
  let itemPos = item.posXY
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

let function addDownOutArrow(reqItemsWithDownOutArrows, arrowConfig) {
  if (arrowConfig.sizeY != 0) { //not horizontal arrow
    let reqItemId = arrowConfig.reqItemId
    reqItemsWithDownOutArrows[reqItemId] <-
      (reqItemsWithDownOutArrows?[reqItemId] ?? []).append(arrowConfig.itemId)
  }

  return reqItemsWithDownOutArrows
}

let function getReqItemsArray(reqItems) {
  let itemsIdArray = []
  let fullItemsIdList = {}
  foreach (reqItemsString in reqItems) {
    let itemsTbl = {}
    foreach (reqId in reqItemsString.split(",")) {
      let needHave = !::g_string.startsWith(reqId, "!") // true = need to have, false = need to NOT have.
      let itemId = reqId.slice(needHave ? 0 : 1).tointeger()
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

let function addItemConfigToTree(treeRows, bodyIdx, posX, posY, itemConfig) {
  if (treeRows[bodyIdx][posY][posX] == null)
    treeRows[bodyIdx][posY][posX] = []
  appendOnce(itemConfig, treeRows[bodyIdx][posY][posX], true, @(arrValue, value) arrValue.id == value.id)
}

let function generateRows(branchBlk, treeRows, treeBlk) {
  let branchItems = {}
  let textBlocks = []
  let notFoundReqForItems = {}
  local minPosX = null
  local maxPosX = null
  let resourcesInColumn = {} //!!!FIX Looks like counter of resources by column, but actually contains flag for column which has resources.
  local reqItemsWithDownOutArrows = {}
  let bodyIdx = branchBlk?.bodyItemIdx ?? 0
  let hasItemBackground = ((treeBlk % "bodyTiledBackImage")?[bodyIdx] ?? "") == ""
  let itemsIdList = {}
  if (treeRows.len() < bodyIdx + 1)
    treeRows.resize(bodyIdx + 1, array(0, null))

  for (local i = 0; i < branchBlk.blockCount(); i++) {
    let iBlk = branchBlk.getBlock(i)
    local id = iBlk.getBlockName()
    let shouldRemoveBlankRows = branchBlk?.shouldRemoveBlankRows ?? false
    if (id == "textArea") {
      let posX = iBlk.posXYFrom.x.tointeger()
      let posY = iBlk.posXYFrom.y.tointeger()
      let endPosX = iBlk.posXYTo.x.tointeger()
      let endPosY = iBlk.posXYTo.y.tointeger()
      minPosX = min(minPosX ?? posX, posX)
      maxPosX = max(maxPosX ?? endPosX, endPosX)
      let reqItems = getReqItemsArray(iBlk % "reqItemExistsForDisplaying")
      itemsIdList.__update(reqItems.fullItemsIdList)
      textBlocks.append({
        posX = posX - 1
        posY = posY - 1
        endPosX = endPosX - 1
        endPosY = endPosY - 1
        sizeX = endPosX - posX + 1
        sizeY = endPosY - posY + 1
        bodyIdx = bodyIdx
        texts = iBlk % "text"
        reqItemExistsForDisplaying = reqItems.itemsIdArray
        valign = iBlk?.valign
        halign = iBlk?.halign
      })
      continue
    }

    id = ::to_integer_safe(id, id, false)
    if (!::ItemsManager.isItemdefId(id))
      continue

    let itemConfig = {
      id = id
      bodyIdx = bodyIdx
      conectionInRowText = branchBlk?.conectionInRowText ?? "+"
      posXY = iBlk.posXY
      showResources = iBlk?.showResources ?? false
      reqItems = (iBlk % "reqItem").map(@(itemId)itemId.tointeger())
      reqItemForDisplaying = []
      reqItemExistsForDisplaying = []
      reqItemForIdentification = []
      reqItemForCrafting = []
      arrows = []
      hasItemBackground
      shouldRemoveBlankRows
    }

    foreach (reqListId in ["reqItemForCrafting", "reqItemForDisplaying",
      "reqItemExistsForDisplaying", "reqItemForIdentification"]) {
      let reqItems = getReqItemsArray(iBlk % reqListId)
      itemsIdList.__update(reqItems.fullItemsIdList)
      itemConfig[reqListId] = reqItems.itemsIdArray
    }

    let posX = itemConfig.posXY.x.tointeger()
    let posY = itemConfig.posXY.y.tointeger()
    minPosX = branchBlk?.startX ?? min(minPosX ?? posX, posX)
    maxPosX = branchBlk?.endX ?? max(maxPosX ?? posX, posX)
    if (itemConfig.showResources && resourcesInColumn?[posX - 1] == null)
      resourcesInColumn[posX - 1] <- 1

    foreach (reqItemId in itemConfig.reqItems) {
      if (branchItems?[reqItemId] != null) {
        let arrowConfig = getArrowConfigByItems(itemConfig, branchItems[reqItemId])
        reqItemsWithDownOutArrows = addDownOutArrow(reqItemsWithDownOutArrows, arrowConfig)
        itemConfig.arrows.append(arrowConfig)
      }
      else
        notFoundReqForItems[reqItemId] <- (notFoundReqForItems?[reqItemId] ?? []).append(itemConfig)
    }

    if (treeRows[bodyIdx].len() < posY) {
      let rowsCount = treeRows[bodyIdx].len()
      for (local k = rowsCount; k < posY; k++)
        treeRows[bodyIdx].append(array(posX, null))
    }

    if (treeRows[bodyIdx][posY - 1].len() < posX)
      treeRows[bodyIdx][posY - 1].resize(posX, null)

    branchItems[id] <- itemConfig
    itemsIdList[id] <- true
    addItemConfigToTree(treeRows, bodyIdx, posX - 1, posY - 1, itemConfig)
  }

  let searchReqForItems = clone notFoundReqForItems
  foreach (reqItemId, itemConfigs in searchReqForItems) {
    if (!(reqItemId in branchItems))
      continue

    foreach (itemConfig in itemConfigs) {
      let arrowConfig = getArrowConfigByItems(itemConfig, branchItems[reqItemId])
      reqItemsWithDownOutArrows = addDownOutArrow(reqItemsWithDownOutArrows, arrowConfig)
      itemConfig.arrows.append(arrowConfig)

      branchItems[itemConfig.id] = itemConfig
      itemsIdList[itemConfig.id] <- true
      addItemConfigToTree(treeRows, bodyIdx, itemConfig.posXY.x - 1, itemConfig.posXY.y - 1, itemConfig)
    }
    notFoundReqForItems.rawdelete(reqItemId)
  }

  if (notFoundReqForItems.len() > 0) {
    let craftTreeName = branchBlk?.locId ?? ""  // warning disable: -declared-never-used
    let reqItems = ::g_string.implode(notFoundReqForItems.keys(), "; ") // warning disable: -declared-never-used
    ::script_net_assert_once("Not found reqItems for craftTree", "Error: Not found reqItems")
  }

  foreach (reqItemId, downOutArrowIds in reqItemsWithDownOutArrows) {
    if (downOutArrowIds.len() <= 1) //is not multiple out arrow
      continue

    foreach (itemId in downOutArrowIds) {
      let itemConfig = branchItems[itemId]
      let arrowIdx = itemConfig.arrows.findindex(@(v) v.reqItemId == reqItemId)
      if (arrowIdx != null) {
        itemConfig.arrows[arrowIdx].isOutMultipleArrow = true
        branchItems[itemId] = itemConfig
        itemsIdList[itemId] <- true
        addItemConfigToTree(treeRows, bodyIdx, itemConfig.posXY.x - 1, itemConfig.posXY.y - 1, itemConfig)
      }
    }
  }

  minPosX = minPosX ?? 0
  maxPosX = maxPosX ?? 0
  let headerItems = getHeaderItems(branchBlk)
  headerItems.each(@(itemId) itemsIdList[itemId] <- true)
  let buttonConfig = ("button" in branchBlk) ? ::buildTableFromBlk(branchBlk.button) : null
  if (buttonConfig?.generatorId != null)
    itemsIdList[buttonConfig.generatorId] <- true
  return {
    treeRows
    branch = DEFAULT_BRANCH_CONFIG.__merge({
      locId = branchBlk?.locId
      headerItems
      minPosX
      maxPosX
      itemsCountX = maxPosX - minPosX + 1
      branchItems
      resourcesInColumn
      columnWithResourcesCount = resourcesInColumn.reduce(@(res, value) res + value, 0)
      bodyIdx
      textBlocks
      buttonConfig
      itemsIdList
    })
  }
}

let function getAllowableResources(resourcesBlk, resourcesName) {
  if (resourcesBlk == null)
    return null

  let allowableResources = {}
  foreach (res in (resourcesBlk % resourcesName))
    allowableResources[::to_integer_safe(res, res, false)] <- true

  return allowableResources
}

let function getCraftResult(treeBlk) {
  let craftResult = treeBlk?.craftResult
  if (!craftResult || !craftResult?.item)
    return null

  let reqItems = craftResult?.reqItems ?? ""
  return {
    id = craftResult.item
    reqItems = reqItems.split(",").map(@(item) item.tointeger())
  }
}

let function generateTreeConfig(blk) {
  let branches = []
  local treeRowsByBodies = []
  foreach (branchBlk in blk % "treeBlock") {
    let configByBranch = generateRows(branchBlk, treeRowsByBodies, blk)
    treeRowsByBodies = configByBranch.treeRows
    branches.append(DEFAULT_BRANCH_CONFIG.__merge(configByBranch.branch))
  }

  branches.sort(@(a, b) a.bodyIdx <=> b.bodyIdx
    || a.minPosX <=> b.minPosX)

  let craftResult = getCraftResult(blk)
  let craftTreeItemsList = {}
  if (craftResult != null)
    craftTreeItemsList[craftResult.id] <- true

  let bodyItemsTitles = blk % "bodyItemsTitle"
  let bodyTiledBackImage = blk % "bodyTiledBackImage"
  let allowableResources = blk % "allowableResources"
  local hasHeaderItems = false
  let bodiesConfig = []
  foreach (_idx, branch in branches) {
     craftTreeItemsList.__update(branch.itemsIdList)
     hasHeaderItems = hasHeaderItems || branch.headerItems.len() > 0

     let bodyIdx = branch.bodyIdx
     let bodyTitle = bodyItemsTitles?[bodyIdx] ?? ""
     if (!(bodyIdx in bodiesConfig))
       bodiesConfig.append({
         bodyIdx = bodyIdx
         branchesCount = 0
         itemsCountX = 0
         columnWithResourcesCount = 0
         title = bodyTitle
         bodyTiledBackImage = bodyTiledBackImage?[bodyIdx] ?? ""
         allowableResources = getAllowableResources(allowableResources?[bodyIdx], "allowableResource")
         hasBranchesTitles = false
         bodyTitlesCount = bodyTitle != "" ? 1 : 0
         treeColumnsCount = 0
         textBlocks = []
         availableBranchByColumns = {}
         resourcesInColumn = {}
         button = null
       })

     let curBodyConfig = bodiesConfig[bodyIdx]
     let hasBranchesTitlesInBody = curBodyConfig.hasBranchesTitles
     let hasBranchTitle = branch?.locId != null
     curBodyConfig.branchesCount++
     curBodyConfig.itemsCountX += branch.itemsCountX
     curBodyConfig.columnWithResourcesCount += branch.columnWithResourcesCount
     curBodyConfig.bodyTitlesCount += !hasBranchesTitlesInBody && hasBranchTitle ? 1 : 0
     curBodyConfig.hasBranchesTitles = hasBranchesTitlesInBody || hasBranchTitle
     curBodyConfig.treeColumnsCount = max(branch.maxPosX, curBodyConfig.treeColumnsCount)
     curBodyConfig.textBlocks.extend(branch.textBlocks)
     curBodyConfig.availableBranchByColumns[branch.minPosX - 1] <- true
     curBodyConfig.resourcesInColumn.__update(branch.resourcesInColumn)
     curBodyConfig.button = branch.buttonConfig ?? curBodyConfig.button
  }

  let craftTreeItemsIdArray = craftTreeItemsList.keys()
  if (craftTreeItemsIdArray.len() > 0)   //request items by itemDefId for craft tree
    inventoryClient.requestItemdefsByIds(craftTreeItemsIdArray)

  return {
    headerlocId = blk?.main_header ?? ""
    headerItemsTitle = blk?.headerItemsTitle
    openButtonLocId = blk?.openButtonLocId ?? ""
    allowableResourcesForCraftResult = getAllowableResources(allowableResources?[bodiesConfig.len()], "allowableResource")
    allowableItemsForCraftingTutorial = getAllowableResources(blk?.allowableItemsForCraftingTutorial, "item")
    craftTreeItemsIdArray = craftTreeItemsIdArray
    branches = branches
    treeRowsByBodies = treeRowsByBodies
    reqFeaturesArr = blk?.reqFeature != null ? (blk.reqFeature).split(",") : []
    baseEfficiency = blk?.baseEfficiency.tointeger() ?? 0
    craftResult = craftResult
    hasHeaderItems = hasHeaderItems
    bodiesConfig = bodiesConfig
    isShowHeaderPlace = bodiesConfig.len() == 1
  }
}

return generateTreeConfig