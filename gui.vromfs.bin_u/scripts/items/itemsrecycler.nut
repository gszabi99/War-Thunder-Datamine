from "%scripts/dagui_natives.nut" import char_send_blk
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let DataBlock = require("DataBlock")
let { getItemGenerator } = require("%scripts/items/itemGeneratorsManager.nut")
let { addTask } = require("%scripts/tasker.nut")
let { getInventoryList } = require("%scripts/items/itemsManager.nut")
let { exchangeSeveralRecipes } = require("%scripts/items/exchangeRecipes.nut")
let { get_cur_base_gui_handler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")

const GENERIC_ITEM_GENERATOR_ID = 299030
const SINGLE_GENERATOR_ID_OFFSET = 20
const CRAFT_PART_TO_NEW_ITEM_RATIO = 2

let RECYCLED_ITEMS_IDS = [299000, 299001, 299002, 299003, 299004]

// Inventory items may have non-unique ids. E.g. boosters might have different expiration times.
// We generate an unique key based on the item inventory id and its unique parameters (currently the expiration time, but additional parameters may be added).
let getRecyclingItemUniqKey = @(item) "::".concat(item.id, item.expiredTimeSec)
let getSingleGeneratorForRecycledItem = @(itemId) getItemGenerator(itemId + SINGLE_GENERATOR_ID_OFFSET)

let ItemsRecycler = class {
  craftParts = null
  craftPartsCount = 0

  selectedItemsToRecycle = null  // map composite unique key -> { item, amount }
  selectedItemsToRecycleCount = 0

  recyclingItemsIds = null

  constructor() {
    this.updateCraftParts()
    this.selectedItemsToRecycle = {}
  }

  function selectItemToRecycle(item, amount) {
    let key = getRecyclingItemUniqKey(item)
    if (amount == 0 && key in this.selectedItemsToRecycle) {
      this.selectedItemsToRecycle.$rawdelete(key)
      this.updateItemsToRecycleCount()
      return
    }

    if (key not in this.selectedItemsToRecycle)
      this.selectedItemsToRecycle[key] <- { item, amount }
    else
      this.selectedItemsToRecycle[key].amount = amount

    this.updateItemsToRecycleCount()
  }

  function updateItemsToRecycleCount() {
    this.selectedItemsToRecycleCount = this.selectedItemsToRecycle.values()
      .reduce(@(total, sel) total + sel.amount, 0)
  }

  function updateCraftParts() {
    this.craftParts = getInventoryList(itemType.ALL, @(item) RECYCLED_ITEMS_IDS.contains(item.id))
    this.craftPartsCount = this.craftParts.reduce(@(total, part) total + part.amount, 0)
  }

  function recycleSelectedItems() {
    if (this.selectedItemsToRecycle.len() == 0) {
      scene_msg_box("msg_choose_recycling_items", null,
        loc("items/recycling/chooseItemsToRecycle"), [["ok"]], "ok")
      return
    }

    let onConfirmRecycling = Callback(this.recycleSelectedItemsImpl, this)
    scene_msg_box("msg_items_recycling_confirm", null,
      loc("items/recycling/confirmRecycle"), [["yes", onConfirmRecycling], ["no"]], "no",
      {
        data_below_text = this.getSelectedItemsListMarkup()
        cancel_fn = @() null
        baseHandler = get_cur_base_gui_handler()
      })
  }

  function recycleSelectedItemsImpl() {
    this.recyclingItemsIds = clone this.selectedItemsToRecycle

    let recycleParams = this.getRecycleItemsRequestsParams()
    this.performItemsRecycling(recycleParams)

    this.selectedItemsToRecycle.clear()
    this.selectedItemsToRecycleCount = 0
  }

  function performItemsRecycling(params) {
    if (params.len() == 0) {
      this.recyclingItemsIds.clear() // Inventory updates after the server's cln_recycle_items response, so clear the list only after all queue operations complete.
      return
    }

    let blk = params.pop()
    let self = callee()
    let onFinish = Callback(@() self(params), this)
    let taskId = char_send_blk("cln_recycle_items", blk)

    broadcastEvent("RecyclingItemsStart")
    addTask(taskId, { showProgressBox = true }, onFinish, onFinish)
  }

  function getSelectedItemsListMarkup() {
    let itemsList = this.selectedItemsToRecycle.reduce(function(allItemsMarkup, sel) {
      let itemDesc = sel.item.getNameMarkup(sel.amount)
      return "".concat(allItemsMarkup, "tdiv {margin-top:t='10@sf/@pf';", itemDesc, "}")
    }, "")

    return "".concat("tdiv {padding:t='140@sf/@pf,12@sf/@pf'; flow:t='vertical';", itemsList, "}")
  }

  function getRecycleItemsRequestsParams() {
    let itemsByType = {} // For now it's possible to recycle items only with the same iType per single request

    foreach (sel in this.selectedItemsToRecycle) {
      if (sel.amount < 1)
        continue
      let { item, amount } = sel
      local itemsBlk = itemsByType?[item.iType].items

      if (!itemsBlk) {
        let blk = DataBlock()
        itemsBlk = blk.addBlock("items")
        itemsByType[item.iType] <- blk
      }

      if (item.canPacked) {
        let itemBlk = itemsBlk.addNewBlock("item")
        itemBlk.setStr("itemId", item.uids[0]) // for packed items there is only one uid
        itemBlk.setInt("count", amount)
      } else {
        let uidsToRecycle = item.uids.slice(-amount)
        uidsToRecycle.each(@(uid) itemsBlk.addNewBlock("item").setStr("itemId", uid))
      }
    }

    return itemsByType.values()
  }

  function craftNewItems(amount) {
    if (amount < 1)
      return

    local remaining  = amount
    let exchangeConfigs = []
    let partIdToQuantity = this.craftParts
      .reduce(@(parts, part) parts.__update({[part.id] = part.amount}), {})

    // At first, we must use single generators as many as possible
    let singleGenCfg = this.calculateCraftViaSingleGenerator(partIdToQuantity, remaining)
    exchangeConfigs.extend(singleGenCfg.res)
    remaining = singleGenCfg.remaining

    // If all craft parts types are left with only one, we use a generic generator
    if (remaining > 0)
      exchangeConfigs.extend(this.calculateCraftViaGenericGenerator(partIdToQuantity, remaining))

    exchangeSeveralRecipes(exchangeConfigs)
  }

  function calculateCraftViaSingleGenerator(partIdToQuantity, needed) {
    let res = []
    foreach (part in this.craftParts) {
      if (needed <= 0)
        break

      let currentAmount = partIdToQuantity[part.id]
      if (currentAmount < CRAFT_PART_TO_NEW_ITEM_RATIO)
        continue

      let maxItemsFromCur = currentAmount / CRAFT_PART_TO_NEW_ITEM_RATIO
      let itemsToProduce = min(needed, maxItemsFromCur)

      if (itemsToProduce > 0) {
        let recipe = getSingleGeneratorForRecycledItem(part.id).getRecipes()[0]
        res.append({ item = part, recipe, amount = itemsToProduce })

        partIdToQuantity[part.id] -= itemsToProduce * CRAFT_PART_TO_NEW_ITEM_RATIO
        needed -= itemsToProduce
      }
    }
    return { res, remaining = needed }
  }

  function calculateCraftViaGenericGenerator(partIdToQuantity, needed) {
    let res = []
    if (needed <= 0)
      return res

    foreach (part in this.craftParts) {
      if (needed <= 0)
        break

      let currentAmount = partIdToQuantity[part.id]
      if (currentAmount <= 0)
        continue

      let recipe = this.findGenericGeneratorRecipe(part.id, partIdToQuantity)
      if (!recipe)
        continue

      res.append({item = part, recipe = recipe, amount = 1})
      partIdToQuantity[recipe.components[0].itemdefId]--
      partIdToQuantity[recipe.components[1].itemdefId]--
      needed--
    }

    return res
  }

  function findGenericGeneratorRecipe(partId, partIdToQuantity) {
    let gen = getItemGenerator(GENERIC_ITEM_GENERATOR_ID)
    let suitableIds = partIdToQuantity
      .filter(@(quantity) quantity >= 1)
      .keys()

    return gen.getRecipes().findvalue(function(recipe) {
      let curComp = recipe.components.findvalue(@(comp) comp.itemdefId == partId)
      let suitableComp = recipe.components.findvalue(@(comp) comp.itemdefId != partId
        && suitableIds.contains(comp.itemdefId))
      return !!curComp && !!suitableComp
    })
  }
}

return { ItemsRecycler, CRAFT_PART_TO_NEW_ITEM_RATIO, RECYCLED_ITEMS_IDS, getRecyclingItemUniqKey }
