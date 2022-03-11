let workshopCraftTree = require("workshopCraftTree.nut")
let { hasAllFeatures } = require("scripts/user/features.nut")
let { getTimestampFromStringUtc } = require("scripts/time.nut")

const KNOWN_ITEMS_SAVE_ID = "workshop/known"
const KNOWN_REQ_ITEMS_SAVE_ID = "workshop/knownReqItems"
const KNOWN_ITEMS_SAVE_KEY = "id"
const PREVIEWED_SAVE_PATH = "workshop/previewed/"
const CURRENT_SUBSET_SAVE_PATH = "workshop/curSubSetBySet/"
const ACCENT_CRAFT_TREE_SAVE_PATH = "seen/workshopCraftTree/"

local WorkshopSet = class {
  id = "" //name of config blk. not unique
  uid = -1
  reqFeature = null //""
  isForcedDisplayByDate = null
  locId = ""

  itemdefsSorted = null //[]
  itemdefs = null //{ <itemdef> = sortId }
  itemsReqRulesTbl = null  // { <itemId> = bool } (true = need to have, false = need to NOT have)
  hiddenItemsBlocks = null // { <blockId> = true }
  alwaysVisibleItemdefs = null // { <itemdef> = sortId }
  knownItemdefs = null // { <itemdef> = true }
  knownReqItemdefs = null // { <reqitemdef> = true }
  itemsVisibleOnlyInCraftTree = null // { <itemId> = true }

  isToStringForDebug = true

  itemsListCache = null
  visibleSeenIds = null

  previewBlk = null

  craftTrees = null
  hasSubsets  = false
  subsetsList = null
  curSubsetId   = null

  constructor(blk)
  {
    id = blk.getBlockName() || ""
    reqFeature = blk?.reqFeature
    locId = blk?.locId || id
    hasSubsets = blk?.hasSubsets ?? false

    itemdefsSorted = []
    itemdefs = {}
    itemsReqRulesTbl = {}
    alwaysVisibleItemdefs = {}
      itemsVisibleOnlyInCraftTree = {}
    subsetsList = {}
    local firstSubsetId = null

    foreach (itemsBlkIdx, itemsBlk in (blk % "items"))
    {
      let subsetBlockIdx = itemsBlkIdx * 100
      let subsetItems = []
      let subsetId = itemsBlk?.setId ?? ""
      local items = getItemsFromBlk(itemsBlk, subsetBlockIdx + 0, subsetId)
      subsetItems.extend(items)
      if (itemsBlk)
        foreach (idx, itemBlk in itemsBlk % "itemBlock")
        {
          items = getItemsFromBlk(itemBlk, subsetBlockIdx + idx + 1, subsetId)
          subsetItems.extend(items)
        }
      itemdefsSorted.extend(subsetItems)
      if (!hasSubsets)
        break

      firstSubsetId = firstSubsetId ?? subsetId
      subsetsList[subsetId] <- {
        id = subsetId
        sortIdx = itemsBlkIdx
        locId = itemsBlk.locId
        items = subsetItems
        reqFeature = itemsBlk?.reqFeature
      }
    }

    if (blk?.eventPreview)
    {
      previewBlk = ::DataBlock()
      previewBlk.setFrom(blk.eventPreview)
    }

    craftTrees = (blk % "craftTree").map(workshopCraftTree.bindenv(this))

    if (hasSubsets)
      curSubsetId = ::load_local_account_settings(CURRENT_SUBSET_SAVE_PATH + id, firstSubsetId)

    ::subscribe_handler(this, ::g_listener_priority.CONFIG_VALIDATION)
    checkForcedDisplayTime(blk?.forcedDisplayWithoutFeature)
  }

  isValid                   = @() id.len() > 0 && itemdefs.len() > 0
  isVisible                 = @() !reqFeature || ::has_feature(reqFeature) || isForcedDisplayByDate
  isItemDefAlwaysVisible    = @(itemdef) itemdef in alwaysVisibleItemdefs
  getItemdefs               = @() itemdefsSorted
  getLocName                = @() ::loc(locId)
  getShopTabId              = @() "WORKSHOP_SET_" + uid
  getSeenId                 = @() "##workshop_set_" + uid
  isVisibleSubset           = @(subset) !subset.reqFeature || ::has_feature(subset.reqFeature)
  isVisibleSubsetId         = @(subsetId) subsetsList?[subsetId] != null && isVisibleSubset(subsetsList[subsetId])

  isItemInSet               = @(item) item.id in itemdefs
  isItemIdInSet             = @(id) id in itemdefs
  isItemIdHidden            = @(id) (itemdefs[id].blockNumber in hiddenItemsBlocks)
                                || (hasSubsets && !isVisibleSubsetId(itemdefs[id].subsetId))
  isVisibleOnlyInCraftTree  = @(id) itemsVisibleOnlyInCraftTree?[id] != null
  isItemIdKnown             = @(id) initKnownItemsOnce() || id in knownItemdefs
  isReqItemIdKnown          = @(id) id in knownReqItemdefs
  shouldDisguiseItem        = @(item) !(item.id in alwaysVisibleItemdefs) && !isItemIdKnown(item.id)
    && !item?.itemDef?.tags?.alwaysKnownItem

  hasPreview                = @() previewBlk != null

  function getItemsFromBlk(itemsBlk, blockNumber, subsetId)
  {
    let items = []
    if (!itemsBlk)
      return items

    let sortByParam = itemsBlk?.sortByParam
    let itemsReqRules = []
    let passBySavedReqItems = itemsBlk?.passBySavedReqItems ?? false
    let showOnlyInCraftTree = itemsBlk?.showOnlyInCraftTree ?? false
    foreach(reqItems in itemsBlk % "reqItems")
    {
      let itemsTbl = {}
      foreach (reqId in reqItems.split(","))
      {
        let needHave = !::g_string.startsWith(reqId, "!") // true = need to have, false = need to NOT have.
        let itemId = reqId.slice(needHave ? 0 : 1).tointeger()

        itemsTbl[itemId] <- needHave
        if (!(itemId in itemsReqRulesTbl))
          itemsReqRulesTbl[itemId] <- needHave
      }
      itemsReqRules.append(itemsTbl)
    }

    for (local i = 0; i < itemsBlk.paramCount(); i++)
    {
      let itemdef = itemsBlk.getParamValue(i)
      if (typeof(itemdef) != "integer")
        continue

      if (itemsBlk.getParamName(i) == "alwaysVisibleItem")
        alwaysVisibleItemdefs[itemdef] <- true

      items.append(itemdef)

      if (showOnlyInCraftTree)
        itemsVisibleOnlyInCraftTree[itemdef] <-true
    }

    foreach (idx, itemId in items)
      itemdefs[itemId] <- {
        blockNumber = blockNumber
        itemNumber = idx
        sortByParam = sortByParam
        itemsReqRules = itemsReqRules
        passBySavedReqItems = passBySavedReqItems
        subsetId = subsetId
      }

    return items
  }

  function initHiddenItemsBlocks()
  {
    loadKnownReqItemsOnce()

    hiddenItemsBlocks = {}

    let reqItems = ::ItemsManager.getInventoryList(itemType.ALL,
      (@(item) item.id in itemsReqRulesTbl).bindenv(this))

    let reqItemsAmountTbl = {}
    foreach (item in reqItems)
      reqItemsAmountTbl[item.id] <- item.getAmount() + (reqItemsAmountTbl?[item.id] ?? 0)

    updateKnownReqItems(reqItemsAmountTbl)

    foreach (itemData in itemdefs)
    {
      let blockNumber = itemData.blockNumber
      if (itemData.blockNumber in hiddenItemsBlocks)
        continue

      let itemsReqRules = itemData?.itemsReqRules
      if (!itemsReqRules || !itemsReqRules.len())
        continue

      local isHidden = true
      foreach (itemsTbl in itemsReqRules)
      {
        local canShow = true
        foreach (itemId, needHave in itemsTbl)
        {
          let amount = reqItemsAmountTbl?[itemId] ?? 0
          if ((needHave && amount > 0)
            || (needHave && itemData.passBySavedReqItems && knownReqItemdefs?[itemId])
            || (!needHave && amount == 0))
            continue

          canShow = false
          break
        }

        if (canShow)
        {
          isHidden = false
          break
        }
      }

      if (isHidden)
        hiddenItemsBlocks[blockNumber] <- true
    }
  }

  function getItemsList()
  {
    if (itemsListCache && !itemsReqRulesTbl.len())
      return itemsListCache

    initHiddenItemsBlocks()
    itemsListCache = ::ItemsManager.getInventoryList(itemType.ALL,
      (@(item) isItemIdInSet(item.id) && !item.isHiddenItem() && !isItemIdHidden(item.id)).bindenv(this))
    updateKnownItems(itemsListCache)
    itemsListCache = itemsListCache.filter((@(item) !isVisibleOnlyInCraftTree(item.id)).bindenv(this))

    let visibleKnownItemdefs = knownItemdefs.filter((@(value, itemId) !isVisibleOnlyInCraftTree(itemId)).bindenv(this))
    let requiredList = alwaysVisibleItemdefs.__merge(visibleKnownItemdefs)

    //add all craft parts recipes result to visible items.
    if (requiredList.len() != itemdefs.len())
      foreach(item in itemsListCache)
        if (item.iType == itemType.CRAFT_PART)
        {
          let recipes = item.getRelatedRecipes()
          if (!recipes.len())
            continue
          foreach(r in recipes)
            if (r.generatorId in itemdefs)
              requiredList[r.generatorId] <- 0
        }

    foreach(item in itemsListCache)
      if (item.id in requiredList)
        delete requiredList[item.id]

    foreach(itemdef, sortId in requiredList)
    {
      if (isItemIdHidden(itemdef))
        continue

      let item = ItemsManager.getItemOrRecipeBundleById(itemdef)
      if (!item
          || (item.iType == itemType.RECIPES_BUNDLE && !item.getMyRecipes().len()))
        continue

      let newItem = item.makeEmptyInventoryItem()
      if (!newItem.isEnabled())
        continue

      if (shouldDisguiseItem(item))
        newItem.setDisguise(true)

      itemsListCache.append(newItem)
    }

    itemsListCache.sort((@(a, b)
      (itemdefs?[a.id].blockNumber ?? -1) <=> (itemdefs?[b.id].blockNumber ?? -1)
      || (itemdefs?[a.id].sortByParam == "name" && a.getName(false) <=> b.getName(false))
      || (itemdefs?[a.id].itemNumber ?? -1) <=> (itemdefs?[b.id].itemNumber ?? -1)).bindenv(this))

    return itemsListCache
  }

  static function clearOutdatedData(actualSets)
  {
    let knownBlk = ::load_local_account_settings(KNOWN_ITEMS_SAVE_ID)
    if (!knownBlk)
      return

    local hasChanges = false
    for(local i = knownBlk.paramCount() - 1; i >= 0; i--)
    {
      let id = knownBlk.getParamValue(i)
      local isActual = false
      foreach(set in actualSets)
        if (set.isItemIdInSet(id))
        {
          isActual = true
          break
        }
      if (isActual)
        continue
      knownBlk.removeParamById(i)
      hasChanges = true
    }
    if (hasChanges)
      ::save_local_account_settings(KNOWN_ITEMS_SAVE_ID, knownBlk)
  }

  function loadKnownItemsOnce()
  {
    if (knownItemdefs)
      return

    knownItemdefs = {}
    let knownBlk = ::load_local_account_settings(KNOWN_ITEMS_SAVE_ID)
    if (!knownBlk)
      return

    let knownList = knownBlk % KNOWN_ITEMS_SAVE_KEY
    foreach(_id in knownList)
      if (isItemIdInSet(_id))
        knownItemdefs[_id] <- true
  }

  function loadKnownReqItemsOnce()
  {
    if (knownReqItemdefs)
      return

    knownReqItemdefs = {}
    let knownBlk = ::load_local_account_settings(KNOWN_REQ_ITEMS_SAVE_ID)
    if (!knownBlk)
      return

    let knownList = knownBlk % KNOWN_ITEMS_SAVE_KEY
    foreach(_id in knownList)
      knownReqItemdefs[_id] <- true
  }

  function initKnownItemsOnce()
  {
    if (!knownItemdefs)
      updateKnownItems(::ItemsManager.getInventoryList(itemType.ALL, isItemInSet.bindenv(this) ))
  }

  function updateKnownItems(curInventoryItems)
  {
    loadKnownItemsOnce()

    let newKnownIds = []
    foreach(item in curInventoryItems)
      if (!isItemIdKnown(item.id))
      {
        knownItemdefs[item.id] <- true
        newKnownIds.append(item.id)
      }

    saveKnownItems(newKnownIds, KNOWN_ITEMS_SAVE_ID)
  }

  function updateKnownReqItems(reqItemsAmountTbl)
  {
    loadKnownReqItemsOnce()

    let newKnownIds = []
    foreach(reqItemId, amount in reqItemsAmountTbl)
      if (amount > 0 && !isReqItemIdKnown(reqItemId))
      {
        knownReqItemdefs[reqItemId] <- true
        newKnownIds.append(reqItemId)
      }

    saveKnownItems(newKnownIds, KNOWN_REQ_ITEMS_SAVE_ID)
  }

  function saveKnownItems(newKnownIds, saveId)
  {
    if (!newKnownIds.len())
      return

    local knownBlk = ::load_local_account_settings(saveId)
    if (!knownBlk)
      knownBlk = ::DataBlock()
    foreach(_id in newKnownIds)
      knownBlk[KNOWN_ITEMS_SAVE_KEY] <- _id

    ::save_local_account_settings(saveId, knownBlk)
  }

  getPreviewedSaveId   = @() PREVIEWED_SAVE_PATH + id
  needShowPreview      = @() hasPreview() && !::load_local_account_settings(getPreviewedSaveId(), false)
  markPreviewed        = @() ::save_local_account_settings(getPreviewedSaveId(), true)

  function invalidateItemsCache()
  {
    visibleSeenIds = null
    itemsListCache = null
  }

  function getVisibleSeenIds()
  {
    if (!visibleSeenIds)
    {
      visibleSeenIds = {}
      foreach(item in getItemsList())
        if (!item.isDisguised)
          visibleSeenIds[item.id] <- item.getSeenId()
    }
    return visibleSeenIds
  }

  _tostring        = @() ::format("WorkshopSet %s (itemdefsAmount = %d)", id, itemdefs.len())

  isVisibleCraftTree = @(craftTree) hasAllFeatures(craftTree.reqFeaturesArr)
  getCraftTree       = @() ::u.search(craftTrees, isVisibleCraftTree.bindenv(this))

  function getItemsListForCraftTree(craftTree)
  {
    let itemDefIds = craftTree.craftTreeItemsIdArray
    let itemsList = {}
    let itemsArray = ::ItemsManager.getInventoryList(itemType.ALL, @(item) itemDefIds.indexof(item.id) != null)
    foreach (item in itemsArray)
      itemsList[item.id] <- item

    foreach(itemdefid in itemDefIds)
    {
      if (itemsList?[itemdefid] != null)
        continue

      let item = ::ItemsManager.getItemOrRecipeBundleById(itemdefid)
      if (!item)
        continue

      local newItem = item.makeEmptyInventoryItem()
      itemsList[itemdefid] <- newItem
    }

    return itemsList
  }

  function getItemsSubList(subsetId)
  {
    let fullItemsList = getItemsList()
    if (!hasSubsets)
      return fullItemsList

    if (!(subsetId in subsetsList))
      subsetId = curSubsetId

    let subsetItems = subsetsList?[subsetId].items ?? []
    return fullItemsList.filter(@(item) ::isInArray(item.id, subsetItems))
  }

  function getSubsetsList()
  {
    return subsetsList.filter(isVisibleSubset.bindenv(this)).values().sort(
      @(a, b) a.sortIdx <=> b.sortIdx)
  }

  getCurSubsetId = @() curSubsetId
  function setSubset(subsetId)
  {
    if (!hasSubsets || !(subsetId in subsetsList))
      return

    curSubsetId = subsetId
    ::save_local_account_settings(CURRENT_SUBSET_SAVE_PATH + id, subsetId)
  }

  function getSubsetIdByItemId(itemId)
  {
    if (!hasSubsets)
      return null

    foreach(subset in subsetsList)
      if (isVisibleSubset(subset) && ::u.search(subset.items, @(i) i == itemId) != null)
        return subset.id

    return null
  }

  function needReqItems(itemBlock, itemsList)
  {
    foreach (reqItemId in (itemBlock?.reqItems ?? []))
      if (reqItemId != null && (itemsList?[reqItemId].getAmount() ?? 0) == 0)
        return true

    return false
  }

  function isRequireCondition(reqItems, itemsList, isMetConditionFunc)
  {
    local needCondForCraft = false
    foreach (reqItemBlock in (reqItems ?? []))
    {
      local canCraft = true
      foreach (itemId, needHave in reqItemBlock)
      {
        let isMetCondition = isMetConditionFunc(itemsList, itemId)
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

  hasAmountFunc = @(itemsList, itemId) (itemsList?[itemId].getAmount() ?? 0) > 0
  isItemIdKnownFunc = @(itemsList, itemId) isItemIdKnown(itemId)

  isRequireItemsForCrafting = @(itemBlock, itemsList)
    isRequireCondition(itemBlock?.reqItemForCrafting, itemsList, hasAmountFunc)
  isDisquised = @(itemBlock, itemsList)
    isRequireCondition(itemBlock?.reqItemForIdentification, itemsList, isItemIdKnownFunc)
  isRequireItemsForDisplaying = @(itemBlock, itemsList)
    isRequireCondition(itemBlock?.reqItemForDisplaying, itemsList, isItemIdKnownFunc) ||
    isRequireCondition(itemBlock?.reqItemExistsForDisplaying, itemsList, hasAmountFunc)

  function findTutorialItem()
  {
    if (::load_local_account_settings(getCraftTreeIdPathForSave(), false))
      return null

    let craftTree = getCraftTree()
    if (!craftTree)
      return null

    let branches = craftTree.branches
    let itemsList = getItemsListForCraftTree(craftTree)

    foreach (branch in branches)
      foreach (itemBlock in branch.branchItems)
      {
        if (!craftTree.allowableItemsForCraftingTutorial?[itemBlock?.id])
          continue

        let item = itemsList?[itemBlock.id]
        if (!item?.id)
          continue

        if (item.isHiddenItem()
            || (item.getAmount() == 0 && isRequireItemsForDisplaying(itemBlock, itemsList)))
          continue

        if (item.isCrafting() || item.hasCraftResult()
            || isRequireItemsForCrafting(itemBlock, itemsList)
            || needReqItems(itemBlock, itemsList)
            || (item.hasMainActionDisassemble() && item.canDisassemble() && item.getAmount() > 0)
            || !item.canAssemble() || item.hasReachedMaxAmount() || !item.hasUsableRecipe())
          continue

        return item
      }

    return null
  }

  getCraftTreeIdPathForSave = @() "".join([ACCENT_CRAFT_TREE_SAVE_PATH, id])
  saveTutorialWasShown = @() ::save_local_account_settings(getCraftTreeIdPathForSave(), true)

  function checkForcedDisplayTime(forcedDisplayWithoutFeature)
  {
    if (!forcedDisplayWithoutFeature)
      return

    let startTime = getTimestampFromStringUtc(forcedDisplayWithoutFeature.beginDate)
    let endTime = getTimestampFromStringUtc(forcedDisplayWithoutFeature.endDate)
    let currentTime = ::get_charserver_time_sec()

    if (currentTime >= endTime)
      return

    if(currentTime >= startTime && currentTime < endTime)
    {
      isForcedDisplayByDate = true
      ::g_delayed_actions.add(::Callback(function() {
          isForcedDisplayByDate = false
          ::broadcastEvent("WorkshopAvailableChanged")
        }, this), (endTime - currentTime)*1000)

      return
    }

    ::g_delayed_actions.add(::Callback(function() {
        isForcedDisplayByDate = true
        ::broadcastEvent("WorkshopAvailableChanged")
      }, this), (startTime - currentTime)*1000)
  }
}

return WorkshopSet