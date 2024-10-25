from "%scripts/dagui_library.nut" import *

let { calc_personal_boost, calc_public_boost } = require("%appGlobals/ranks_common_shared.nut")
let { format } = require("string")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let { getBoostersEffectsArray, sortBoosters } = require("%scripts/items/boosterEffect.nut")
let { getFullUnlockCondsDescInline } = require("%scripts/unlocks/unlocksViewModule.nut")
let { get_cur_base_gui_handler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { addTooltipTypes } = require("%scripts/utils/genericTooltipTypes.nut")
let {shouldDisguiseItem } = require("%scripts/items/workshop/workshop.nut")

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

  let isDescTextBeforeDescDiv = !item || item?.isDescTextBeforeDescDiv || false

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

function getActiveBoostersDescription(boostersArray, effectType, selectedItem = null, plainText = false) {
  if (!boostersArray || boostersArray.len() == 0)
    return ""

  let getColoredNumByType =  function(num) {
    let value = plainText ? $"+{num.tointeger()}%" : colorize("activeTextColor", $"+{num.tointeger()}%")
    let currency = effectType.getCurrencyMark(plainText)
    return "".concat(value, currency)
  }

  let separateBoosters = []

  let itemsArray = []
  foreach (booster in boostersArray) {
    if (booster.showBoosterInSeparateList)
      separateBoosters.append($"{booster.getName()}{loc("ui/colon")}{booster.getEffectDesc(true, effectType, plainText)}")
    else
      itemsArray.append(booster)
  }
  if (separateBoosters.len())
    separateBoosters.append("\n")

  let sortedItemsTable = sortBoosters(itemsArray, effectType)
  let detailedDescription = []
  for (local i = 0; i <= sortedItemsTable.maxSortOrder; i++) {
    let arraysList = getTblValue(i, sortedItemsTable)
    if (!arraysList || arraysList.len() == 0)
      continue

    let personalTotal = arraysList.personal.len() == 0
      ? 0
      : calc_personal_boost(getBoostersEffectsArray(arraysList.personal, effectType))

    let publicTotal = arraysList.public.len() == 0
      ? 0
      : calc_public_boost(getBoostersEffectsArray(arraysList.public, effectType))

    let isBothBoosterTypesAvailable = personalTotal != 0 && publicTotal != 0

    local header = ""
    let detailedArray = []
    local insertedSubHeader = false

    foreach (_j, arrayName in ["personal", "public"]) {
      let arr = arraysList[arrayName]
      if (arr.len() == 0)
        continue

      let personal = arr[0].personal
      let boostNum = personal ? personalTotal : publicTotal

      header = arr[0].eventConditions
        ? getFullUnlockCondsDescInline(arr[0].eventConditions)
        : loc("mainmenu/boosterType/common")

      local subHeader = "".concat("* ", loc($"mainmenu/booster/{arrayName}"))
      if (isBothBoosterTypesAvailable) {
        subHeader += loc("ui/colon")
        subHeader += getColoredNumByType(boostNum)
      }

      detailedArray.append(subHeader)

      let effectsArray = []
      foreach (idx, item in arr) {
        let effOld = personal ? calc_personal_boost(effectsArray) : calc_public_boost(effectsArray)
        effectsArray.append(item[effectType.name])
        let effNew = personal ? calc_personal_boost(effectsArray) : calc_public_boost(effectsArray)

        local string = arr.len() == 1 ? "" : $"{idx+1}) "
        string = $"{string}{item.getEffectDesc(false, null, plainText)}{loc("ui/comma")}"
        string = $"{string}{loc("items/booster/giveRealBonus", {realBonus = getColoredNumByType(format("%.02f", effNew - effOld).tofloat())})}"
        string = $"{string}{idx == arr.len()-1 ? loc("ui/dot") : loc("ui/semicolon")}"

        if (selectedItem != null && selectedItem.id == item.id)
          string = colorize("userlogColoredText", string)

        detailedArray.append(string)
      }

      if (!insertedSubHeader) {
        let totalBonus = publicTotal + personalTotal
        header = $"{header}{loc("ui/colon")}{getColoredNumByType(totalBonus)}"
        detailedArray.insert(0, header)
        insertedSubHeader = true
      }
    }
    detailedDescription.append("\n".join(detailedArray, true))
  }

  let description = $"{loc("mainmenu/boostersTooltip", { currencyMark = effectType.getCurrencyMark(plainText) })}{loc("ui/colon")}\n"
  return $"{description}{"\n".join(separateBoosters, true)}{"\n\n".join(detailedDescription, true)}"
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
  ITEM = { //by item name
    item = null
    tooltipObj = null
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, itemName, params = null) {
      if (!checkObj(obj))
        return false

      this.item = ::ItemsManager.findItemById(itemName)
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

  INVENTORY = { //by inventory item uid
    isCustomTooltipFill = true
    item = null
    tooltipObj = null
    fillTooltip = function(obj, handler, itemUid, ...) {
      if (!checkObj(obj))
        return false

      this.tooltipObj = obj
      this.item = ::ItemsManager.findItemByUid(itemUid)
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

  SUBTROPHY = { //by item Name
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, itemName, ...) {
      if (!checkObj(obj))
        return false

      let item = ::ItemsManager.findItemById(itemName)
      if (!item)
        return false
      let data = item.getLongDescriptionMarkup()
      if (data == "")
        return false

      // Showing only trophy content, without title and icon.
      obj.width = "@itemInfoWidth"
      obj.getScene().replaceContentFromText(obj, data, data.len(), handler)
      return true
    }
  }
})

return {
  fillItemDescr
  fillDescTextAboutDiv
  getActiveBoostersDescription
  updateExpireAlarmIcon
  fillItemDescUnderTable
}