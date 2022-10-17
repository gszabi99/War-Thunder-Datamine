let { format } = require("string")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let { getBoostersEffectsArray, sortBoosters } = require("%scripts/items/boosterEffect.nut")

let function fillItemTable(item, holderObj)
{
  let containerObj = holderObj.findObject("item_table_container")
  if (!::checkObj(containerObj))
    return false

  let tableData = item && item?.getTableData ? item.getTableData() : null
  let show = tableData != null
  containerObj.show(show)

  if (show)
    holderObj.getScene().replaceContentFromText(containerObj, tableData, tableData.len(), this)
  return show
}

let function fillItemTableInfo(item, holderObj)
{
  if (!::check_obj(holderObj))
    return

  local hasItemAdditionalDescTable = fillItemTable(item, holderObj)

  local obj = holderObj.findObject("item_desc_above_table")
  local text = item?.getDescriptionAboveTable() ?? ""
  if (::check_obj(obj))
    obj.setValue(text)
  hasItemAdditionalDescTable = hasItemAdditionalDescTable || text != ""

  obj = holderObj.findObject("item_desc_under_table")
  text = item?.getDescriptionUnderTable() ?? ""
  if (::check_obj(obj))
    obj.setValue(text)
  hasItemAdditionalDescTable = hasItemAdditionalDescTable || text != ""

  ::showBtn("item_additional_desc_table", hasItemAdditionalDescTable, holderObj)
}

let function getDescTextAboutDiv(item, preferMarkup = true)
{
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

let function fillDescTextAboutDiv(item, descObj)
{
  let isDescTextBeforeDescDiv = item?.isDescTextBeforeDescDiv ?? false
  let obj = descObj.findObject(isDescTextBeforeDescDiv ? "item_desc" : "item_desc_under_div")
  if (obj?.isValid())
    obj.setValue(getDescTextAboutDiv(item))
}

let function fillItemDescUnderTable(item, descObj) {
  let obj = descObj.findObject("item_desc_under_table")
  if (obj?.isValid())
    obj.setValue(item.getDescriptionUnderTable())
}

local function fillItemDescr(item, holderObj, handler = null, shopDesc = false, preferMarkup = false, params = null)
{
  handler = handler || ::get_cur_base_gui_handler()
  item = item?.getSubstitutionItem() ?? item

  local obj = holderObj.findObject("item_name")
  if (::checkObj(obj))
    obj.setValue(item? item.getDescriptionTitle() : "")

  let addDescObj = holderObj.findObject("item_desc_under_title")
  if (::checkObj(addDescObj))
    addDescObj.setValue(item?.getDescriptionUnderTitle?() ?? "")

  let helpObj = holderObj.findObject("item_type_help")
  if (::checkObj(helpObj))
  {
    let helpText = item && item?.getItemTypeDescription? item.getItemTypeDescription() : ""
    helpObj.tooltip = helpText
    helpObj.show(shopDesc && helpText != "")
  }

  let isDescTextBeforeDescDiv = !item || item?.isDescTextBeforeDescDiv || false
  obj = holderObj.findObject(isDescTextBeforeDescDiv ? "item_desc" : "item_desc_under_div")

  if (obj?.isValid())
  {
    local desc = getDescTextAboutDiv(item, preferMarkup)
    if (params?.descModifyFunc) {
      desc = params.descModifyFunc(desc)
      params.rawdelete("descModifyFunc")
    }

    let warbondId = params?.wbId
    if (warbondId)
    {
      let warbond = ::g_warbonds.findWarbond(warbondId, params?.wbListId)
      let award = warbond? warbond.getAwardById(item.id) : null
      if (award)
        desc = award.addAmountTextToDesc(desc)
    }

    obj.setValue(desc)
  }

  obj = holderObj.findObject("item_desc_div")
  if (::checkObj(obj))
  {
    let longdescMarkup = (preferMarkup && item?.getLongDescriptionMarkup)
      ? item.getLongDescriptionMarkup((params ?? {}).__merge({ shopDesc = shopDesc })) : ""

    obj.show(longdescMarkup != "")
    if (longdescMarkup != "")
      obj.getScene().replaceContentFromText(obj, longdescMarkup, longdescMarkup.len(), handler)
  }

  obj = holderObj.findObject(isDescTextBeforeDescDiv ? "item_desc_under_div" : "item_desc")
  if (::checkObj(obj))
    obj.setValue("")

  fillItemTableInfo(item, holderObj)

  obj = holderObj.findObject("item_icon")
  obj.show(item != null)
  if (item)
  {
    let iconSetParams = {
      bigPicture = item?.allowBigPicture || false
      addItemName = !shopDesc
    }
    item.setIcon(obj, iconSetParams)
  }

  if (item && item?.getDescTimers)
    foreach(timerData in item.getDescTimers())
    {
      if (!timerData.needTimer.call(item))
        continue

      let timerObj = holderObj.findObject(timerData.id)
      let tData = timerData
      if (::check_obj(timerObj))
        SecondsUpdater(timerObj, function(tObj, params)
        {
          tObj.setValue(tData.getText.call(item))
          return !tData.needTimer.call(item)
        })
    }
}

let function getActiveBoostersDescription(boostersArray, effectType, selectedItem = null)
{
  if (!boostersArray || boostersArray.len() == 0)
    return ""

  let getColoredNumByType = (@(effectType) function(num) {
    return "".concat(::colorize("activeTextColor", $"+{num.tointeger()}%"), effectType.currencyMark)
  })(effectType)

  let separateBoosters = []

  let itemsArray = []
  foreach(booster in boostersArray)
  {
    if (booster.showBoosterInSeparateList)
      separateBoosters.append($"{booster.getName()}{::loc("ui/colon")}{booster.getEffectDesc(true, effectType)}")
    else
      itemsArray.append(booster)
  }
  if (separateBoosters.len())
    separateBoosters.append("\n")

  let sortedItemsTable = sortBoosters(itemsArray, effectType)
  let detailedDescription = []
  for (local i = 0; i <= sortedItemsTable.maxSortOrder; i++)
  {
    let arraysList = ::getTblValue(i, sortedItemsTable)
    if (!arraysList || arraysList.len() == 0)
      continue

    let personalTotal = arraysList.personal.len() == 0
      ? 0
      : ::calc_personal_boost(getBoostersEffectsArray(arraysList.personal, effectType))

    let publicTotal = arraysList.public.len() == 0
      ? 0
      : ::calc_public_boost(getBoostersEffectsArray(arraysList.public, effectType))

    let isBothBoosterTypesAvailable = personalTotal != 0 && publicTotal != 0

    local header = ""
    let detailedArray = []
    local insertedSubHeader = false

    foreach(j, arrayName in ["personal", "public"])
    {
      let arr = arraysList[arrayName]
      if (arr.len() == 0)
        continue

      let personal = arr[0].personal
      let boostNum = personal? personalTotal : publicTotal

      header = ::loc("mainmenu/boosterType/common")
      if (arr[0].eventConditions)
        header = ::UnlockConditions.getConditionsText(arr[0].eventConditions, null, null, { inlineText = true })

      local subHeader = "".concat("* ", ::loc($"mainmenu/booster/{arrayName}"))
      if (isBothBoosterTypesAvailable)
      {
        subHeader += ::loc("ui/colon")
        subHeader += getColoredNumByType(boostNum)
      }

      detailedArray.append(subHeader)

      let effectsArray = []
      foreach(idx, item in arr)
      {
        let effOld = personal? ::calc_personal_boost(effectsArray) : ::calc_public_boost(effectsArray)
        effectsArray.append(item[effectType.name])
        let effNew = personal? ::calc_personal_boost(effectsArray) : ::calc_public_boost(effectsArray)

        local string = arr.len() == 1 ? "" : $"{idx+1}) "
        string = $"{string}{item.getEffectDesc(false)}{::loc("ui/comma")}"
        string = $"{string}{::loc("items/booster/giveRealBonus", {realBonus = getColoredNumByType(format("%.02f", effNew - effOld).tofloat())})}"
        string = $"{string}{idx == arr.len()-1 ? ::loc("ui/dot") : ::loc("ui/semicolon")}"

        if (selectedItem != null && selectedItem.id == item.id)
          string = ::colorize("userlogColoredText", string)

        detailedArray.append(string)
      }

      if (!insertedSubHeader)
      {
        let totalBonus = publicTotal + personalTotal
        header = $"{header}{::loc("ui/colon")}{getColoredNumByType(totalBonus)}"
        detailedArray.insert(0, header)
        insertedSubHeader = true
      }
    }
    detailedDescription.append(::g_string.implode(detailedArray, "\n"))
  }

  let description = $"{::loc("mainmenu/boostersTooltip", effectType)}{::loc("ui/colon")}\n"
  return $"{description}{::g_string.implode(separateBoosters, "\n")}{::g_string.implode(detailedDescription, "\n\n")}"
}

let function updateExpireAlarmIcon(item, itemObj)
{
  if (!itemObj?.isValid())
    return

  let expireType = item.getExpireType()
  if (!expireType)
    return

  ::showBtn("alarm_icon", true, itemObj)
  let borderObj = itemObj.findObject("rarity_border")
  if (!borderObj?.isValid())
    return

  borderObj.expired = expireType.id
}

return {
  fillItemDescr
  getDescTextAboutDiv
  fillDescTextAboutDiv
  getActiveBoostersDescription
  updateExpireAlarmIcon
  fillItemDescUnderTable
}