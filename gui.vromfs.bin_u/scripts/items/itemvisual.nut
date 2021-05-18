local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
local { getBoostersEffectsArray, sortBoosters } = require("scripts/items/boosterEffect.nut")

local function fillItemTable(item, holderObj)
{
  local containerObj = holderObj.findObject("item_table_container")
  if (!::checkObj(containerObj))
    return false

  local tableData = item && item?.getTableData ? item.getTableData() : null
  local show = tableData != null
  containerObj.show(show)

  if (show)
    holderObj.getScene().replaceContentFromText(containerObj, tableData, tableData.len(), this)
  return show
}

local function fillItemTableInfo(item, holderObj)
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

local function fillItemDescr(item, holderObj, handler = null, shopDesc = false, preferMarkup = false, params = null)
{
  handler = handler || ::get_cur_base_gui_handler()
  item = item?.getSubstitutionItem() ?? item

  local obj = holderObj.findObject("item_name")
  if (::checkObj(obj))
    obj.setValue(item? item.getDescriptionTitle() : "")

  local addDescObj = holderObj.findObject("item_desc_under_title")
  if (::checkObj(addDescObj))
    addDescObj.setValue(item?.getDescriptionUnderTitle?() ?? "")

  local helpObj = holderObj.findObject("item_type_help")
  if (::checkObj(helpObj))
  {
    local helpText = item && item?.getItemTypeDescription? item.getItemTypeDescription() : ""
    helpObj.tooltip = helpText
    helpObj.show(shopDesc && helpText != "")
  }

  local isDescTextBeforeDescDiv = !item || item?.isDescTextBeforeDescDiv || false
  obj = holderObj.findObject(isDescTextBeforeDescDiv ? "item_desc" : "item_desc_under_div")
  if (::checkObj(obj))
  {
    local desc = ""
    if (item)
    {
      if (item?.getShortItemTypeDescription)
        desc = item.getShortItemTypeDescription()
      local descText = preferMarkup ? item.getLongDescription() : item.getDescription()
      if (descText.len() > 0)
        desc += (desc.len() ? "\n\n" : "") + descText
      local itemLimitsDesc = item?.getLimitsDescription ? item.getLimitsDescription() : ""
      if (itemLimitsDesc.len() > 0)
        desc += (desc.len() ? "\n" : "") + itemLimitsDesc
    }
    if ("descModifyFunc" in params) {
      desc = params.descModifyFunc(desc)
      params.rawdelete("descModifyFunc")
    }

    local warbondId = ::getTblValue("wbId", params)
    if (warbondId)
    {
      local warbond = ::g_warbonds.findWarbond(warbondId, ::getTblValue("wbListId", params))
      local award = warbond? warbond.getAwardById(item.id) : null
      if (award)
        desc = award.addAmountTextToDesc(desc)
    }

    obj.setValue(desc)
  }

  obj = holderObj.findObject("item_desc_div")
  if (::checkObj(obj))
  {
    local longdescMarkup = (preferMarkup && item?.getLongDescriptionMarkup)
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
    local iconSetParams = {
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

      local timerObj = holderObj.findObject(timerData.id)
      local tData = timerData
      if (::check_obj(timerObj))
        SecondsUpdater(timerObj, function(tObj, params)
        {
          tObj.setValue(tData.getText.call(item))
          return !tData.needTimer.call(item)
        })
    }
}

local function getActiveBoostersDescription(boostersArray, effectType, selectedItem = null)
{
  if (!boostersArray || boostersArray.len() == 0)
    return ""

  local getColoredNumByType = (@(effectType) function(num) {
    return "".concat(::colorize("activeTextColor", $"+{num.tointeger()}%"), effectType.currencyMark)
  })(effectType)

  local separateBoosters = []

  local itemsArray = []
  foreach(booster in boostersArray)
  {
    if (booster.showBoosterInSeparateList)
      separateBoosters.append($"{booster.getName()}{::loc("ui/colon")}{booster.getEffectDesc(true, effectType)}")
    else
      itemsArray.append(booster)
  }
  if (separateBoosters.len())
    separateBoosters.append("\n")

  local sortedItemsTable = sortBoosters(itemsArray, effectType)
  local detailedDescription = []
  for (local i = 0; i <= sortedItemsTable.maxSortOrder; i++)
  {
    local arraysList = ::getTblValue(i, sortedItemsTable)
    if (!arraysList || arraysList.len() == 0)
      continue

    local personalTotal = arraysList.personal.len() == 0
      ? 0
      : ::calc_personal_boost(getBoostersEffectsArray(arraysList.personal, effectType))

    local publicTotal = arraysList.public.len() == 0
      ? 0
      : ::calc_public_boost(getBoostersEffectsArray(arraysList.public, effectType))

    local isBothBoosterTypesAvailable = personalTotal != 0 && publicTotal != 0

    local header = ""
    local detailedArray = []
    local insertedSubHeader = false

    foreach(j, arrayName in ["personal", "public"])
    {
      local arr = arraysList[arrayName]
      if (arr.len() == 0)
        continue

      local personal = arr[0].personal
      local boostNum = personal? personalTotal : publicTotal

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

      local effectsArray = []
      foreach(idx, item in arr)
      {
        local effOld = personal? ::calc_personal_boost(effectsArray) : ::calc_public_boost(effectsArray)
        effectsArray.append(item[effectType.name])
        local effNew = personal? ::calc_personal_boost(effectsArray) : ::calc_public_boost(effectsArray)

        local string = arr.len() == 1 ? "" : $"{idx+1}) "
        string = $"{string}{item.getEffectDesc(false)}{::loc("ui/comma")}"
        string = $"{string}{::loc("items/booster/giveRealBonus", {realBonus = getColoredNumByType(::format("%.02f", effNew - effOld).tofloat())})}"
        string = $"{string}{idx == arr.len()-1 ? ::loc("ui/dot") : ::loc("ui/semicolon")}"

        if (selectedItem != null && selectedItem.id == item.id)
          string = ::colorize("userlogColoredText", string)

        detailedArray.append(string)
      }

      if (!insertedSubHeader)
      {
        local totalBonus = publicTotal + personalTotal
        header = $"{header}{::loc("ui/colon")}{getColoredNumByType(totalBonus)}"
        detailedArray.insert(0, header)
        insertedSubHeader = true
      }
    }
    detailedDescription.append(::g_string.implode(detailedArray, "\n"))
  }

  local description = $"{::loc("mainmenu/boostersTooltip", effectType)}{::loc("ui/colon")}\n"
  return $"{description}{::g_string.implode(separateBoosters, "\n")}{::g_string.implode(detailedDescription, "\n\n")}"
}

return {
  fillItemDescr                = fillItemDescr
  getActiveBoostersDescription = getActiveBoostersDescription
}