//-file:plus-string
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let DataBlock  = require("DataBlock")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { format } = require("string")
let workshopCraftTree = require("workshopCraftTree.nut")
let { hasAllFeatures } = require("%scripts/user/features.nut")
let { getTimestampFromStringUtc } = require("%scripts/time.nut")
let { startsWith } = require("%sqstd/string.nut")
let { get_charserver_time_sec } = require("chard")

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

  constructor(blk) {
    this.id = blk.getBlockName() || ""
    this.reqFeature = blk?.reqFeature
    this.locId = blk?.locId || this.id
    this.hasSubsets = blk?.hasSubsets ?? false

    this.itemdefsSorted = []
    this.itemdefs = {}
    this.itemsReqRulesTbl = {}
    this.alwaysVisibleItemdefs = {}
      this.itemsVisibleOnlyInCraftTree = {}
    this.subsetsList = {}
    local firstSubsetId = null

    foreach (itemsBlkIdx, itemsBlk in (blk % "items")) {
      let subsetBlockIdx = itemsBlkIdx * 100
      let subsetItems = []
      let subsetId = itemsBlk?.setId ?? ""
      local items = this.getItemsFromBlk(itemsBlk, subsetBlockIdx + 0, subsetId)
      subsetItems.extend(items)
      if (itemsBlk)
        foreach (idx, itemBlk in itemsBlk % "itemBlock") {
          items = this.getItemsFromBlk(itemBlk, subsetBlockIdx + idx + 1, subsetId)
          subsetItems.extend(items)
        }
      this.itemdefsSorted.extend(subsetItems)
      if (!this.hasSubsets)
        break

      firstSubsetId = firstSubsetId ?? subsetId
      this.subsetsList[subsetId] <- {
        id = subsetId
        sortIdx = itemsBlkIdx
        locId = itemsBlk.locId
        items = subsetItems
        reqFeature = itemsBlk?.reqFeature
      }
    }

    if (blk?.eventPreview) {
      this.previewBlk = DataBlock()
      this.previewBlk.setFrom(blk.eventPreview)
    }

    this.craftTrees = (blk % "craftTree").map(workshopCraftTree.bindenv(this))

    if (this.hasSubsets)
      this.curSubsetId = loadLocalAccountSettings(CURRENT_SUBSET_SAVE_PATH + this.id, firstSubsetId)

    subscribe_handler(this, g_listener_priority.CONFIG_VALIDATION)
    this.checkForcedDisplayTime(blk?.forcedDisplayWithoutFeature)
  }

  isValid                   = @() this.id.len() > 0 && this.itemdefs.len() > 0
  isVisible                 = @() !this.reqFeature || hasFeature(this.reqFeature) || this.isForcedDisplayByDate
  isItemDefAlwaysVisible    = @(itemdef) itemdef in this.alwaysVisibleItemdefs
  getItemdefs               = @() this.itemdefsSorted
  getLocName                = @() loc(this.locId)
  getShopTabId              = @() "WORKSHOP_SET_" + this.uid
  getSeenId                 = @() "##workshop_set_" + this.uid
  isVisibleSubset           = @(subset) !subset.reqFeature || hasFeature(subset.reqFeature)
  isVisibleSubsetId         = @(subsetId) this.subsetsList?[subsetId] != null && this.isVisibleSubset(this.subsetsList[subsetId])

  isItemInSet               = @(item) item.id in this.itemdefs
  isItemIdInSet             = @(item_id) item_id in this.itemdefs
  isItemIdHidden            = @(item_id) (this.itemdefs[item_id].blockNumber in this.hiddenItemsBlocks)
                                || (this.hasSubsets && !this.isVisibleSubsetId(this.itemdefs[item_id].subsetId))
  isVisibleOnlyInCraftTree  = @(item_id) this.itemsVisibleOnlyInCraftTree?[item_id] != null
  isItemIdKnown             = @(item_id) this.initKnownItemsOnce() || item_id in this.knownItemdefs
  isReqItemIdKnown          = @(item_id) item_id in this.knownReqItemdefs
  shouldDisguiseItem        = @(item) !(item.id in this.alwaysVisibleItemdefs) && !this.isItemIdKnown(item.id)
    && !item?.itemDef?.tags?.alwaysKnownItem

  hasPreview                = @() this.previewBlk != null

  function getItemsFromBlk(itemsBlk, blockNumber, subsetId) {
    let items = []
    if (!itemsBlk)
      return items

    let sortByParam = itemsBlk?.sortByParam
    let itemsReqRules = []
    let passBySavedReqItems = itemsBlk?.passBySavedReqItems ?? false
    let showOnlyInCraftTree = itemsBlk?.showOnlyInCraftTree ?? false
    foreach (reqItems in itemsBlk % "reqItems") {
      let itemsTbl = {}
      foreach (reqId in reqItems.split(",")) {
        let needHave = !startsWith(reqId, "!") // true = need to have, false = need to NOT have.
        let itemId = reqId.slice(needHave ? 0 : 1).tointeger()

        itemsTbl[itemId] <- needHave
        if (!(itemId in this.itemsReqRulesTbl))
          this.itemsReqRulesTbl[itemId] <- needHave
      }
      itemsReqRules.append(itemsTbl)
    }

    for (local i = 0; i < itemsBlk.paramCount(); i++) {
      let itemdef = itemsBlk.getParamValue(i)
      if (type(itemdef) != "integer")
        continue

      if (itemsBlk.getParamName(i) == "alwaysVisibleItem")
        this.alwaysVisibleItemdefs[itemdef] <- true

      items.append(itemdef)

      if (showOnlyInCraftTree)
        this.itemsVisibleOnlyInCraftTree[itemdef] <- true
    }

    foreach (idx, itemId in items)
      this.itemdefs[itemId] <- {
        blockNumber = blockNumber
        itemNumber = idx
        sortByParam = sortByParam
        itemsReqRules = itemsReqRules
        passBySavedReqItems = passBySavedReqItems
        subsetId = subsetId
      }

    return items
  }

  function initHiddenItemsBlocks() {
    this.loadKnownReqItemsOnce()

    this.hiddenItemsBlocks = {}

    let reqItems = ::ItemsManager.getInventoryList(itemType.ALL,
      (@(item) item.id in this.itemsReqRulesTbl).bindenv(this))

    let reqItemsAmountTbl = {}
    foreach (item in reqItems)
      reqItemsAmountTbl[item.id] <- item.getAmount() + (reqItemsAmountTbl?[item.id] ?? 0)

    this.updateKnownReqItems(reqItemsAmountTbl)

    foreach (itemData in this.itemdefs) {
      let blockNumber = itemData.blockNumber
      if (itemData.blockNumber in this.hiddenItemsBlocks)
        continue

      let itemsReqRules = itemData?.itemsReqRules
      if (!itemsReqRules || !itemsReqRules.len())
        continue

      local isHidden = true
      foreach (itemsTbl in itemsReqRules) {
        local canShow = true
        foreach (itemId, needHave in itemsTbl) {
          let amount = reqItemsAmountTbl?[itemId] ?? 0
          if ((needHave && amount > 0)
            || (needHave && itemData.passBySavedReqItems && this.knownReqItemdefs?[itemId])
            || (!needHave && amount == 0))
            continue

          canShow = false
          break
        }

        if (canShow) {
          isHidden = false
          break
        }
      }

      if (isHidden)
        this.hiddenItemsBlocks[blockNumber] <- true
    }
  }

  function getItemsList() {
    if (this.itemsListCache && !this.itemsReqRulesTbl.len())
      return this.itemsListCache

    this.initHiddenItemsBlocks()
    this.itemsListCache = ::ItemsManager.getInventoryList(itemType.ALL,
      (@(item) this.isItemIdInSet(item.id) && !item.isHiddenItem() && !this.isItemIdHidden(item.id)).bindenv(this))
    this.updateKnownItems(this.itemsListCache)
    this.itemsListCache = this.itemsListCache.filter((@(item) !this.isVisibleOnlyInCraftTree(item.id)).bindenv(this))

    let visibleKnownItemdefs = this.knownItemdefs.filter((@(_value, itemId) !this.isVisibleOnlyInCraftTree(itemId)).bindenv(this))
    let requiredList = this.alwaysVisibleItemdefs.__merge(visibleKnownItemdefs)

    //add all craft parts recipes result to visible items.
    if (requiredList.len() != this.itemdefs.len())
      foreach (item in this.itemsListCache)
        if (item.iType == itemType.CRAFT_PART) {
          let recipes = item.getRelatedRecipes()
          if (!recipes.len())
            continue
          foreach (r in recipes)
            if (r.generatorId in this.itemdefs)
              requiredList[r.generatorId] <- 0
        }

    foreach (item in this.itemsListCache)
      requiredList?.$rawdelete(item.id)

    foreach (itemdef, _sortId in requiredList) {
      if (this.isItemIdHidden(itemdef))
        continue

      let item = ::ItemsManager.getItemOrRecipeBundleById(itemdef)
      if (!item
          || (item.iType == itemType.RECIPES_BUNDLE && !item.getMyRecipes().len()))
        continue

      let newItem = item.makeEmptyInventoryItem()
      if (!newItem.isEnabled())
        continue

      if (this.shouldDisguiseItem(item))
        newItem.setDisguise(true)

      this.itemsListCache.append(newItem)
    }

    this.itemsListCache.sort((@(a, b)
      (this.itemdefs?[a.id].blockNumber ?? -1) <=> (this.itemdefs?[b.id].blockNumber ?? -1)
      || (this.itemdefs?[a.id].sortByParam == "name" && a.getName(false) <=> b.getName(false))
      || (this.itemdefs?[a.id].itemNumber ?? -1) <=> (this.itemdefs?[b.id].itemNumber ?? -1)).bindenv(this))

    return this.itemsListCache
  }

  static function clearOutdatedData(actualSets) {
    let knownBlk = loadLocalAccountSettings(KNOWN_ITEMS_SAVE_ID)
    if (!knownBlk)
      return

    local hasChanges = false
    for (local i = knownBlk.paramCount() - 1; i >= 0; i--) {
      let id = knownBlk.getParamValue(i)
      local isActual = false
      foreach (set in actualSets)
        if (set.isItemIdInSet(id)) {
          isActual = true
          break
        }
      if (isActual)
        continue
      knownBlk.removeParamById(i)
      hasChanges = true
    }
    if (hasChanges)
      saveLocalAccountSettings(KNOWN_ITEMS_SAVE_ID, knownBlk)
  }

  function loadKnownItemsOnce() {
    if (this.knownItemdefs)
      return

    this.knownItemdefs = {}
    let knownBlk = loadLocalAccountSettings(KNOWN_ITEMS_SAVE_ID)
    if (!knownBlk)
      return

    let knownList = knownBlk % KNOWN_ITEMS_SAVE_KEY
    foreach (d in knownList)
      if (this.isItemIdInSet(d))
        this.knownItemdefs[d] <- true
  }

  function loadKnownReqItemsOnce() {
    if (this.knownReqItemdefs)
      return

    this.knownReqItemdefs = {}
    let knownBlk = loadLocalAccountSettings(KNOWN_REQ_ITEMS_SAVE_ID)
    if (!knownBlk)
      return

    let knownList = knownBlk % KNOWN_ITEMS_SAVE_KEY
    foreach (d in knownList)
      this.knownReqItemdefs[d] <- true
  }

  function initKnownItemsOnce() {
    if (!this.knownItemdefs)
      this.updateKnownItems(::ItemsManager.getInventoryList(itemType.ALL, this.isItemInSet.bindenv(this)))
  }

  function updateKnownItems(curInventoryItems) {
    this.loadKnownItemsOnce()

    let newKnownIds = []
    foreach (item in curInventoryItems)
      if (!this.isItemIdKnown(item.id)) {
        this.knownItemdefs[item.id] <- true
        newKnownIds.append(item.id)
      }

    this.saveKnownItems(newKnownIds, KNOWN_ITEMS_SAVE_ID)
  }

  function updateKnownReqItems(reqItemsAmountTbl) {
    this.loadKnownReqItemsOnce()

    let newKnownIds = []
    foreach (reqItemId, amount in reqItemsAmountTbl)
      if (amount > 0 && !this.isReqItemIdKnown(reqItemId)) {
        this.knownReqItemdefs[reqItemId] <- true
        newKnownIds.append(reqItemId)
      }

    this.saveKnownItems(newKnownIds, KNOWN_REQ_ITEMS_SAVE_ID)
  }

  function saveKnownItems(newKnownIds, saveId) {
    if (!newKnownIds.len())
      return

    local knownBlk = loadLocalAccountSettings(saveId)
    if (!knownBlk)
      knownBlk = DataBlock()
    foreach (d in newKnownIds)
      knownBlk[KNOWN_ITEMS_SAVE_KEY] <- d

    saveLocalAccountSettings(saveId, knownBlk)
  }

  getPreviewedSaveId   = @() PREVIEWED_SAVE_PATH + this.id
  needShowPreview      = @() this.hasPreview() && !loadLocalAccountSettings(this.getPreviewedSaveId(), false)
  markPreviewed        = @() saveLocalAccountSettings(this.getPreviewedSaveId(), true)

  function invalidateItemsCache() {
    this.visibleSeenIds = null
    this.itemsListCache = null
  }

  function getVisibleSeenIds() {
    if (!this.visibleSeenIds) {
      this.visibleSeenIds = {}
      foreach (item in this.getItemsList())
        if (!item.isDisguised)
          this.visibleSeenIds[item.id] <- item.getSeenId()
    }
    return this.visibleSeenIds
  }

  _tostring        = @() format("WorkshopSet %s (itemdefsAmount = %d)", this.id, this.itemdefs.len())

  isVisibleCraftTree = @(craftTree) hasAllFeatures(craftTree.reqFeaturesArr)
  getCraftTree       = @() u.search(this.craftTrees, this.isVisibleCraftTree.bindenv(this))

  function getItemsListForCraftTree(craftTree) {
    let itemDefIds = craftTree.craftTreeItemsIdArray
    let itemsList = {}
    let itemsArray = ::ItemsManager.getInventoryList(itemType.ALL, @(item) itemDefIds.indexof(item.id) != null)
    foreach (item in itemsArray)
      itemsList[item.id] <- item

    foreach (itemdefid in itemDefIds) {
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

  function getItemsSubList(subsetId) {
    let fullItemsList = this.getItemsList()
    if (!this.hasSubsets)
      return fullItemsList

    if (!(subsetId in this.subsetsList))
      subsetId = this.curSubsetId

    let subsetItems = this.subsetsList?[subsetId].items ?? []
    return fullItemsList.filter(@(item) isInArray(item.id, subsetItems))
  }

  function getSubsetsList() {
    return this.subsetsList.filter(this.isVisibleSubset.bindenv(this)).values().sort(
      @(a, b) a.sortIdx <=> b.sortIdx)
  }

  getCurSubsetId = @() this.curSubsetId
  function setSubset(subsetId) {
    if (!this.hasSubsets || !(subsetId in this.subsetsList))
      return

    this.curSubsetId = subsetId
    saveLocalAccountSettings(CURRENT_SUBSET_SAVE_PATH + this.id, subsetId)
  }

  function getSubsetIdByItemId(itemId) {
    if (!this.hasSubsets)
      return null

    foreach (subset in this.subsetsList)
      if (this.isVisibleSubset(subset) && u.search(subset.items, @(i) i == itemId) != null)
        return subset.id

    return null
  }

  function needReqItems(itemBlock, itemsList) {
    foreach (reqItemId in (itemBlock?.reqItems ?? []))
      if (reqItemId != null && (itemsList?[reqItemId].getAmount() ?? 0) == 0)
        return true

    return false
  }

  function isRequireCondition(reqItems, itemsList, isMetConditionFunc) {
    local needCondForCraft = false
    foreach (reqItemBlock in (reqItems ?? [])) {
      local canCraft = true
      foreach (itemId, needHave in reqItemBlock) {
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
  isItemIdKnownFunc = @(_itemsList, itemId) this.isItemIdKnown(itemId)

  isRequireItemsForCrafting = @(itemBlock, itemsList)
    this.isRequireCondition(itemBlock?.reqItemForCrafting, itemsList, this.hasAmountFunc)
  isDisquised = @(itemBlock, itemsList)
    this.isRequireCondition(itemBlock?.reqItemForIdentification, itemsList, this.isItemIdKnownFunc)
  isRequireItemsForDisplaying = @(itemBlock, itemsList)
    this.isRequireCondition(itemBlock?.reqItemForDisplaying, itemsList, this.isItemIdKnownFunc)
  isRequireExistItemsForDisplaying = @(itemBlock, itemsList)
    this.isRequireCondition(itemBlock?.reqItemExistsForDisplaying, itemsList, this.hasAmountFunc)

  function findTutorialItem() {
    if (loadLocalAccountSettings(this.getCraftTreeIdPathForSave(), false))
      return null

    let craftTree = this.getCraftTree()
    if (!craftTree)
      return null

    let branches = craftTree.branches
    let itemsList = this.getItemsListForCraftTree(craftTree)

    foreach (branch in branches)
      foreach (itemBlock in branch.branchItems) {
        if (!craftTree.allowableItemsForCraftingTutorial?[itemBlock?.id])
          continue

        let item = itemsList?[itemBlock.id]
        if (!item?.id)
          continue

        if (item.isHiddenItem()
            || (item.getAmount() == 0 && this.isRequireItemsForDisplaying(itemBlock, itemsList)))
          continue

        if (item.isCrafting() || item.hasCraftResult()
            || this.isRequireItemsForCrafting(itemBlock, itemsList)
            || this.needReqItems(itemBlock, itemsList)
            || (item.hasMainActionDisassemble() && item.canDisassemble() && item.getAmount() > 0)
            || !item.canAssemble() || item.hasReachedMaxAmount() || !item.hasUsableRecipe())
          continue

        return item
      }

    return null
  }

  getCraftTreeIdPathForSave = @() "".join([ACCENT_CRAFT_TREE_SAVE_PATH, this.id])
  saveTutorialWasShown = @() saveLocalAccountSettings(this.getCraftTreeIdPathForSave(), true)

  function checkForcedDisplayTime(forcedDisplayWithoutFeature) {
    if (!forcedDisplayWithoutFeature)
      return

    let startTime = getTimestampFromStringUtc(forcedDisplayWithoutFeature.beginDate)
    let endTime = getTimestampFromStringUtc(forcedDisplayWithoutFeature.endDate)
    let currentTime = get_charserver_time_sec()

    if (currentTime >= endTime)
      return

    if (currentTime >= startTime && currentTime < endTime) {
      this.isForcedDisplayByDate = true
      ::g_delayed_actions.add(Callback(function() {
          this.isForcedDisplayByDate = false
          broadcastEvent("WorkshopAvailableChanged")
        }, this), (endTime - currentTime) * 1000)

      return
    }

    ::g_delayed_actions.add(Callback(function() {
        this.isForcedDisplayByDate = true
        broadcastEvent("WorkshopAvailableChanged")
      }, this), (startTime - currentTime) * 1000)
  }
}

return WorkshopSet