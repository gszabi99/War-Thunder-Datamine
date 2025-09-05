from "%scripts/dagui_library.nut" import *

let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let { get_cur_base_gui_handler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { addTooltipTypes } = require("%scripts/utils/genericTooltipTypes.nut")
let {shouldDisguiseItem } = require("%scripts/items/workshop/workshop.nut")
let { findItemById, findItemByUid } = require("%scripts/items/itemsManager.nut")

function fillItemTable(item, holderObj) {
  let containerObj = holderObj.findObject("item_table_container")
  if (!checkObj(containerObj))
    return false

  let tableData = item && item?.getTableData ? item.getTableData() : null
  let show = tableData != null
  containerObj.show(show)

  if (show)
    holderObj.getScene().replaceContentFromText(containerObj, tableData, tableData.len(), this)
  return show
}

function fillItemTableInfo(item, holderObj) {
  if (!checkObj(holderObj))
    return

  local hasItemAdditionalDescTable = fillItemTable(item, holderObj)

  local obj = holderObj.findObject("item_desc_above_table")
  local text = item?.getDescriptionAboveTable() ?? ""
  if (checkObj(obj))
    obj.setValue(text)
  hasItemAdditionalDescTable = hasItemAdditionalDescTable || text != ""

  obj = holderObj.findObject("item_desc_under_table")
  text = item?.getDescriptionUnderTable() ?? ""
  if (checkObj(obj))
    obj.setValue(text)
  hasItemAdditionalDescTable = hasItemAdditionalDescTable || text != ""

  showObjById("item_additional_desc_table", hasItemAdditionalDescTable, holderObj)
}

function getDescTextAboutDiv(item, preferMarkup = true) {
  local desc = ""
  if (!item)
    return desc

  desc = item.getShortItemTypeDescription()
  let descText = preferMarkup ? item.getLongDescription() : item.getDescription()
  if (descText.len() > 0)
    desc = $"{desc}{desc.len() ? "\n\n" : ""}{descText}"
  let itemLimitsDesc = item?.getLimitsDescription ? item.getLimitsDescription() : ""
  if (itemLimitsDesc.len() > 0)
    desc = $"{desc.len() ? "\n" : ""}{itemLimitsDesc}"

  return desc
}

function fillDescTextAboutDiv(item, descObj) {
  let isDescTextBeforeDescDiv = item?.isDescTextBeforeDescDiv ?? false
  let obj = descObj.findObject(isDescTextBeforeDescDiv ? "item_desc" : "item_desc_under_div")
  if (obj?.isValid())
    obj.setValue(getDescTextAboutDiv(item))
}

function fillItemDescUnderTable(item, descObj) {
  let obj = descObj.findObject("item_desc_under_table")
  if (obj?.isValid())
    obj.setValue(item.getDescriptionUnderTable())
}

function fillItemDescr(item, holderObj, handler = null, shopDesc = false, preferMarkup = false, params = null) {
  handler = handler || get_cur_base_gui_handler()
  item = item?.getSubstitutionItem() ?? item

  local obj = holderObj.findObject("item_name")
  if (checkObj(obj))
    obj.setValue(item ? item.getDescriptionTitle() : "")

  let addDescObj = holderObj.findObject("item_desc_under_title")
  if (checkObj(addDescObj))
    addDescObj.setValue(item?.getDescriptionUnderTitle?() ?? "")

  let helpObj = holderObj.findObject("item_type_help")
  if (checkObj(helpObj)) {
    let helpText = item && item?.getItemTypeDescription ? item.getItemTypeDescription() : ""
    helpObj.tooltip = helpText
    helpObj.show(shopDesc && helpText != "")
  }

  let isDescTextBeforeDescDiv = !item || item?.isDescTextBeforeDescDiv

  if (params?.showDesc ?? true) {
    obj = holderObj.findObject(isDescTextBeforeDescDiv ? "item_desc" : "item_desc_under_div")

    if (obj?.isValid()) {
      local desc = getDescTextAboutDiv(item, preferMarkup)
      if (params?.descModifyFunc) {
        desc = params.descModifyFunc(desc)
        params.$rawdelete("descModifyFunc")
      }

      let warbondId = params?.wbId
      if (warbondId) {
        let warbond = ::g_warbonds.findWarbond(warbondId, params?.wbListId)
        let award = warbond ? warbond.getAwardById(item.id) : null
        if (award)
          desc = award.addAmountTextToDesc(desc)
      }

      obj.setValue(desc)
    }
  }

  obj = holderObj.findObject("item_desc_div")
  if (checkObj(obj)) {
    let longdescMarkup = (preferMarkup && item?.getLongDescriptionMarkup)
      ? item.getLongDescriptionMarkup((params ?? {}).__merge({ shopDesc = shopDesc })) : ""

    obj.show(longdescMarkup != "")
    if (longdescMarkup != "")
      obj.getScene().replaceContentFromText(obj, longdescMarkup, longdescMarkup.len(), handler)
  }

  obj = holderObj.findObject(isDescTextBeforeDescDiv ? "item_desc_under_div" : "item_desc")
  if (checkObj(obj))
    obj.setValue("")

  fillItemTableInfo(item, holderObj)

  obj = holderObj.findObject("item_icon")
  obj.show(item != null)
  if (item) {
    let iconSetParams = {
      addItemName = !shopDesc
    }
    obj["isPrizeUnitBought"] = item?.isPrizeUnitBought() ? "yes" : "no"
    item.setIcon(obj, iconSetParams)
  }

  if (item && item?.getDescTimers)
    foreach (timerData in item.getDescTimers()) {
      if (!timerData.needTimer.call(item))
        continue

      let timerObj = holderObj.findObject(timerData.id)
      let tData = timerData
      if (checkObj(timerObj))
        SecondsUpdater(timerObj, function(tObj, _params) {
          tObj.setValue(tData.getText.call(item))
          return !tData.needTimer.call(item)
        })
    }
}

function updateExpireAlarmIcon(item, itemObj) {
  if (!itemObj?.isValid())
    return

  let expireType = item.getExpireType()
  if (!expireType)
    return

  showObjById("alarm_icon", true, itemObj)
  let borderObj = itemObj.findObject("rarity_border")
  if (!borderObj?.isValid())
    return

  borderObj.expired = expireType.id
}

addTooltipTypes({
  ITEM = { 
    item = null
    tooltipObj = null
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, itemName, params = null) {
      if (!checkObj(obj))
        return false

      this.item = findItemById(itemName)
      if (!this.item)
        return false

      this.tooltipObj = obj

      if (params?.isDisguised || shouldDisguiseItem(this.item)) {
        this.item = this.item.makeEmptyInventoryItem()
        this.item.setDisguise(true)
      }

      local preferMarkup = this.item.isPreferMarkupDescInTooltip
      obj.getScene().replaceContent(obj, "%gui/items/itemTooltip.blk", handler)
      fillItemDescr(this.item, obj, handler, false, preferMarkup, (params ?? {}).__merge({
        showOnlyCategoriesOfPrizes = true
        showTooltip = false
        showDesc = !(this.item?.showDescInRewardWndOnly() ?? false)
      }))

      if (this.item?.hasLifetimeTimer())
        obj?.findObject("update_timer").setUserData(this)

      return true
    }
    onEventItemsShopUpdate = function(_eventParams, obj, handler, id, params) {
      this.fillTooltip(obj, handler, id, params)
    }
    onTimer = function (_obj, _dt) {
      if (this.item && this.tooltipObj?.isValid())
        fillItemDescUnderTable(this.item, this.tooltipObj)
    }
  }

  INVENTORY = { 
    isCustomTooltipFill = true
    item = null
    tooltipObj = null
    fillTooltip = function(obj, handler, itemUid, ...) {
      if (!checkObj(obj))
        return false

      this.tooltipObj = obj
      this.item = findItemByUid(itemUid)
      if (!this.item)
        return false

      let preferMarkup = this.item.isPreferMarkupDescInTooltip
      obj.getScene().replaceContent(obj, "%gui/items/itemTooltip.blk", handler)
      fillItemDescr(this.item, obj, handler, false, preferMarkup, {
        showOnlyCategoriesOfPrizes = true
        showDesc = !(this.item?.showDescInRewardWndOnly ?? false)
      })

      if (this.item.hasTimer())
        obj?.findObject("update_timer").setUserData(this)

      return true
    }
    onEventItemsShopUpdate = function(_eventParams, obj, handler, id, params) {
      this.fillTooltip(obj, handler, id, params)
    }
    onTimer = function (_obj, _dt) {
      if (!this.item || !this.tooltipObj?.isValid())
        return

      fillDescTextAboutDiv(this.item, this.tooltipObj)
    }
  }

  SUBTROPHY = { 
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, itemName, ...) {
      if (!checkObj(obj))
        return false

      let item = findItemById(itemName)
      if (!item)
        return false
      let data = item.getLongDescriptionMarkup()
      if (data == "")
        return false

      
      obj.width = "@itemInfoWidth"
      obj.getScene().replaceContentFromText(obj, data, data.len(), handler)
      return true
    }
  }
})

return {
  fillItemDescr
  fillDescTextAboutDiv
  updateExpireAlarmIcon
  fillItemDescUnderTable
}