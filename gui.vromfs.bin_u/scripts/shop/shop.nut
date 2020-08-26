local shopTree = require("scripts/shop/shopTree.nut")
local shopSearchBox = require("scripts/shop/shopSearchBox.nut")
local slotActions = require("scripts/slotbar/slotActions.nut")
local unitActions = require("scripts/unit/unitActions.nut")
local { topMenuHandler, topMenuShopActive } = require("scripts/mainmenu/topMenuStates.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")
local { placePriceTextToButton } = require("scripts/viewUtils/objectTextUpdate.nut")

local lastUnitType = null

const COUNT_REQ_FOR_FAKE_UNIT = 2
/*
shopData = [
  { name = "country_japan"
    pages = [
      { name = "type_fighter"
        airList - table readed from blk need to generate a tree. remove after tree generation
                  [[{air, reqAir}, ...], ...]
        tree = [
          [1, "",    "la5", ...]  //rank, range1 aircraft, range2 aircraft, ...
          [1, "la6", "",    ...]
        ]
        lines = [ { air, line }, ...]
      }
      ...
    ]
  }
  ...
]
*/

::gui_start_shop_research <- function gui_start_shop_research(config)
{
  ::gui_start_modal_wnd(::gui_handlers.ShopCheckResearch, config)
}

class ::gui_handlers.ShopMenuHandler extends ::gui_handlers.GenericOptions
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "gui/shop/shopInclude.blk"
  sceneNavBlkName = "gui/shop/shopNav.blk"
  shouldBlurSceneBg = false
  needVoiceChat = false
  keepLoaded = true
  boughtVehiclesCount = null
  totalVehiclesCount = null

  closeShop = null //function to hide close shop
  forceUnitType = null //unitType to set on next pages fill

  curCountry = null
  curPage = ""
  curAirName = ""
  curPageGroups = null
  groupChooseObj = null
  skipOpenGroup = true
  repairAllCost = 0
  availableFlushExp = 0
  brokenList = null
  _timer = 0.0

  shopData = null
  slotbarActions = [ "research", "find_in_market", "buy", "take", "sec_weapons", "weapons", "showroom", "testflight", "crew", "info", "repair" ]
  needUpdateSlotbar = false
  needUpdateSquadInfo = false
  shopResearchMode = false
  setResearchManually = true
  lastPurchase = null

  showModeList = null
  curDiffCode = -1

  navBarObj = null
  navBarGroupObj = null

  searchBoxWeak = null
  selCellOnSearchQuit = null

  unitActionsListTimer = null
  hasSpendExpProcess = false

  function initScreen()
  {
    if (!curAirName.len())
    {
      curCountry = ::get_profile_country_sq()
      local unit = ::getAircraftByName(::hangar_get_current_unit_name())
      if (unit && unit.shopCountry == curCountry)
        curAirName = unit.name
    }

    skipOpenGroup = true
    scene.findObject("shop_timer").setUserData(this)
    brokenList = []

    navBarObj = scene.findObject("nav-help")

    initShowMode(navBarObj)
    loadFullAircraftsTable(curAirName)

    fillPagesListBox()
    initSearchBox()
    skipOpenGroup = false
  }

  function isSceneActive()
  {
    return base.isSceneActive()
           && (wndType != handlerType.CUSTOM || topMenuShopActive.value)
  }

  function getMainFocusObj()
  {
    return scene.findObject("shop_items_list")
  }

  function loadFullAircraftsTable(selAirName = "")
  {
    shopData = []

    local blk = ::get_shop_blk()

    local totalCountries = blk.blockCount()
    local selAir = getAircraftByName(selAirName)
    local selAirCountry = ::getUnitCountry(selAir)
    local selAirType = ::get_es_unit_type(selAir)
    for(local c = 0; c < totalCountries; c++)  //country
    {
      local cblk = blk.getBlock(c)
      local countryData = {
        name = cblk.getBlockName()
        pages = []
      }

      local hasSquadronUnitsInCountry = false
      if (selAir && selAir.shopCountry == countryData.name)
        curCountry = countryData.name

      local totalPages = cblk.blockCount()
      for(local p = 0; p < totalPages; p++)
      {
        local pblk = cblk.getBlock(p)
        local pageData = {
          name = pblk.getBlockName()
          airList = []
          tree = null
          lines = []
        }
        local selected = false
        local hasRankPosXY =false
        local hasFakeUnits =false
        local hasSquadronUnits =false

        local totalRanges = pblk.blockCount()
        for(local r = 0; r < totalRanges; r++)
        {
          local rblk = pblk.getBlock(r)
          local rangeData = []
          local totalAirs = rblk.blockCount()

          for(local a = 0; a < totalAirs; a++)
          {
            local airBlk = rblk.getBlock(a)
            local airData = { name = airBlk.getBlockName() }
            local air = getAircraftByName(airBlk.getBlockName())
            if (air)
            {
              selected = selected || (::get_es_unit_type(air) == selAirType && ::getUnitCountry(air) == selAirCountry)

              if (!air.isVisibleInShop())
                continue

              airData.air <- air
              airData.rank <- air.rank
              hasSquadronUnits = hasSquadronUnits || air.isSquadronVehicle()
            }
            else  //aircraft group
            {
              airData.airsGroup <- []
              local groupTotal = airBlk.blockCount()
              for(local ga = 0; ga < groupTotal; ga++)
              {
                local gAirBlk = airBlk.getBlock(ga)
                air = getAircraftByName(gAirBlk.getBlockName())
                if (!air || !air.isVisibleInShop())
                  continue

                if (!("rank" in airData))
                  airData.rank <- air.rank
                airData.airsGroup.append(air)
                selected = selected || (::get_es_unit_type(air) == selAirType && ::getUnitCountry(air) == selAirCountry)
                hasSquadronUnits = hasSquadronUnits || air.isSquadronVehicle()
              }
              if (airData.airsGroup.len()==0)
                continue

              if (airData.airsGroup.len()==1)
              {
                airData.air <- airData.airsGroup[0]
                airData.rawdelete("airsGroup")
              }

              airData.image <- airBlk?.image
            }
            if (airBlk?.reqAir != null)
              airData.reqAir <- airBlk.reqAir
            if (airBlk?.rankPosXY)
            {
              airData.rankPosXY <- airBlk.rankPosXY
              hasRankPosXY = true
            }
            if (airBlk?.fakeReqUnitType)
            {
              local fakeUnitRanges = genFakeUnitRanges(airBlk, countryData.name)
              airData.fakeReqUnits <- fakeUnitRanges.map(@(range) (range.top()).name)
              pageData.airList = fakeUnitRanges.extend(pageData.airList)
              hasFakeUnits = true
            }
            rangeData.append(airData)
          }
          if (rangeData.len() > 0)
            pageData.airList.append(rangeData)
          if (hasRankPosXY)
            pageData.hasRankPosXY <- hasRankPosXY
          if (hasFakeUnits)
            pageData.hasFakeUnits <- hasFakeUnits
          if (hasSquadronUnits)
          {
            pageData.hasSquadronUnits <- hasSquadronUnits
            hasSquadronUnitsInCountry = hasSquadronUnits
          }
        }
        if (selected)
        {
          curCountry = countryData.name
          curPage = pageData.name
        }

        if (pageData.airList.len() > 0)
          countryData.pages.append(pageData)
        if (hasSquadronUnitsInCountry)
          countryData.hasSquadronUnits <- hasSquadronUnitsInCountry
      }
      if (countryData.pages.len() > 0)
        shopData.append(countryData)
    }
  }

  function getCurTreeData()
  {
    foreach(cData in shopData)
      if (cData.name == curCountry)
      {
        foreach(pageData in cData.pages)
          if (pageData.name == curPage)
            return shopTree.generateTreeData(pageData)
        if (cData.pages.len()>0)
        {
          curPage = cData.pages[0].name
          return shopTree.generateTreeData(cData.pages[0])
        }
      }

    curCountry = shopData[0].name
    curPage = shopData[0].pages[0].name
    return shopTree.generateTreeData(shopData[0].pages[0])
  }

  function countFullRepairCost()
  {
    repairAllCost = 0
    foreach(cData in shopData)
      if (cData.name == curCountry)
        foreach(pageData in cData.pages)
        {
          local treeData = shopTree.generateTreeData(pageData)
          foreach(rowArr in treeData.tree)
            for(local col = 0; col < rowArr.len(); col++)
              if (rowArr[col])
              {
                local air = rowArr[col]
                if (air?.isFakeUnit)
                  continue

                if (::isUnitGroup(air))
                {
                  foreach(gAir in air.airsGroup)
                    if (gAir.isUsable() && ::shop_get_aircraft_hp(gAir.name) < 1.0)
                    repairAllCost += ::wp_get_repair_cost(gAir.name)
                }
                else if (air.isUsable() && ::shop_get_aircraft_hp(air.name) < 1.0)
                  repairAllCost += ::wp_get_repair_cost(air.name)
              }
        }
  }

  function getItemStatusData(item, checkAir="")
  {
    local res = {
      shopReq = checkAirShopReq(item)
      own = true
      partOwn = false
      broken = false
      checkAir = checkAir == item.name
    }
    if (::isUnitGroup(item))
    {
      foreach(air in item.airsGroup)
      {
        local isOwn = ::isUnitBought(air)
        res.own = res.own && isOwn
        res.partOwn = res.partOwn || isOwn
        res.broken = res.broken || ::isUnitBroken(air)
        res.checkAir = res.checkAir || checkAir == air.name
      }
    }
    else if (item?.isFakeUnit)
    {
      res.own = isUnlockedFakeUnit(item)
    }
    else
    {
      res.own = ::isUnitBought(item)
      res.partOwn = res.own
      res.broken = ::isUnitBroken(item)
    }
    return res
  }

  function fillAircraftsList(curName = "")
  {
    if (!::checkObj(scene))
      return
    local tableObj = scene.findObject("shop_items_list")
    if (!::checkObj(tableObj))
      return

    updateBoughtVehiclesCount()
    lastUnitType = getCurPageUnitType()
    ::update_gamercards()

    if (curName=="")
      curName = getResearchingSquadronVehicle()?.name ?? curAirName

    local curRow = -1
    local curCol = -1

    local data = ""
    local treeData = getCurTreeData()
    local unitItems = []
    brokenList = []

    fillBGLines(treeData)
    guiScene.setUpdatesEnabled(false, false);
    foreach(row, rowArr in treeData.tree)
    {
      local rowData = ""
      for(local col = 0; col < rowArr.len(); col++)
        if (!rowArr[col])
          rowData += "td { inactive:t='yes' } "
        else
        {
          local item = rowArr[col]
          local config = getItemStatusData(item, curName)
          if (config.checkAir || ((curRow < 0) && !item?.isFakeUnit))
          {
            curRow = row
            curCol = col
          }
          if (config.broken)
            brokenList.append(item)
          local params = getUnitItemParams(item)
          rowData += ::build_aircraft_item(item.name, item, params)
          unitItems.append({ id = item.name, unit = item, params = params })
        }
      data += format("tr { %s }\n", rowData)
    }
    guiScene.replaceContentFromText(tableObj, data, data.len(), this)
    foreach (unitItem in unitItems)
    {
      local obj = tableObj.findObject(unitItem.id)
      local unit = ::isUnitGroup(unitItem.unit) ? ::getAircraftByName(obj.primaryUnitId)
        : unitItem.unit?.isFakeUnit ? null
        : unitItem.unit
      ::fill_unit_item_timers(obj, unit, unitItem.params)
    }

    updateDiscountIcons()

    guiScene.setUpdatesEnabled(true, true)
    ::gui_bhv.columnNavigator.selectCell(tableObj, curRow, curCol, false)

    updateButtons()

    ::broadcastEvent("ShopUnitTypeSwitched", { esUnitType = getCurPageEsUnitType() })
  }

  function updateDiscountIcons()
  {
    if (!::checkObj(scene))
      return

    local tableObj = scene.findObject("shop_items_list")
    if (!::checkObj(tableObj))
      return

    local treeData = getCurTreeData()
    foreach (row, rowArr in treeData.tree)
      for (local col = 0; col < rowArr.len(); col++)
      {
        local air = rowArr[col]
        if (!air || air?.isFakeUnit)
          continue

        ::showUnitDiscount(tableObj.findObject(air.name+"-discount"), air)

        local bonusData = air.name
        if (::isUnitGroup(air))
          bonusData = ::u.map(air.airsGroup, function(unit) { return unit.name })
        ::showAirExpWpBonus(tableObj.findObject(air.name+"-bonus"), bonusData)
      }
  }

  function onEventDiscountsDataUpdated(params = {})
  {
    updateDiscountIconsOnTabs()
    updateDiscountIcons()
    updateDiscountSlotsPriceText()
  }

  function updateDiscountSlotsPriceText()
  {
    local tableObj = scene.findObject("shop_items_list")
    local treeData = getCurTreeData()
    foreach (row, rowArr in treeData.tree)
    {
      local units = ::u.filter(rowArr, function (item) { return item && !::isUnitGroup(item) && !item?.isFakeUnit })
      foreach (unit in units)
      {
        local params = getUnitItemParams(unit)
        local priceText = ::get_unit_item_price_text(unit, params)
        local shopAirObj = tableObj.findObject(unit.name)
        if (::checkObj(shopAirObj))
        {
          local priceObj = shopAirObj.findObject("bottom_item_price_text")
          if (::checkObj(priceObj))
            priceObj.setValue(priceText)
        }
      }
    }
  }

  function updateButtons()
  {
    updateRepairAllButton()
  }

  function showNavButton(id, show)
  {
    ::showBtn(id, show, navBarObj)
    if (::checkObj(navBarGroupObj))
      ::showBtn(id, show, navBarGroupObj)
  }

  function updateRepairAllButton()
  {
    if (brokenList.len() > 0)
      countFullRepairCost()

    local show = brokenList.len() > 0 && repairAllCost > 0
    showNavButton("btn_repairall", show)
    if (!show)
      return

    local locText = ::loc("mainmenu/btnRepairAll")
    placePriceTextToButton(navBarObj, "btn_repairall", locText, repairAllCost)
    placePriceTextToButton(navBarGroupObj, "btn_repairall", locText, repairAllCost)
  }

  function onEventOnlineShopPurchaseSuccessful(params)
  {
    doWhenActiveOnce("fillAircraftsList")
  }

  function onEventSlotbarPresetLoaded(p)
  {
    doWhenActiveOnce("fillAircraftsList")
  }

  function onEventProfileUpdated(p)
  {
    if (p.transactionType == ::EATT_UPDATE_ENTITLEMENTS || p.transactionType == ::EATT_BUY_ENTITLEMENT)
      doWhenActiveOnce("fillAircraftsList")
  }

  function onEventItemsShopUpdate(p)
  {
    doWhenActiveOnce("fillAircraftsList")
  }

  function onUpdate(obj, dt)
  {
    _timer -= dt
    if (_timer > 0)
      return
    _timer += 1.0

    checkBrokenUnitsAndUpdateThem()
    updateRepairAllButton()
  }

  function checkBrokenUnitsAndUpdateThem()
  {
    for(local i = brokenList.len() - 1; i >= 0; i--)
    {
      if (i >= brokenList.len()) //update unit item is not instant, so broken list can change at that time by other events
        continue

      local unit = brokenList[i]
      if (checkBrokenListStatus(unit))
        checkUnitItemAndUpdate(unit)
    }
  }

  function getLineStatus(lc)
  {
    local config = getItemStatusData(lc.air)
    local configReq = getItemStatusData(lc.reqAir)

    if (config.own || config.partOwn)
      return "owned"
    else if (!config.shopReq || !configReq.own)
      return "locked"
    return ""
  }
/*
  function findAircraftPos(tree, airName)
  {
    for(local row = 0; row < tree.len(); row++)
      for(local col = 0; col < tree[row].len() - 1; col++)
        if (tree[row][col+1] && (tree[row][col+1].name == airName))
          return [row, col]
    return null
  }
*/

  function createLine(r0, c0, r1, c1, status, params = {})
  {
    local isFakeUnitReq = params?.isFakeUnitReq ?? false
    local isMultipleArrow = params?.isMultipleArrow ?? false

    local lines = ""
    local arrowFormat = "shopArrow { type:t='%s'; size:t='%s, %s'; pos:t='%s, %s'; rotation:t='%s' shopStat:t='" + status + "' } "
    local lineFormat = "shopLine { size:t='%s, %s'; pos:t='%s, %s'; rotation:t='%s'; shopStat:t='" + status + "' } "
    local angleFormat = "shopAngle { size:t='%s, %s'; pos:t='%s, %s'; rotation:t='%s'; shopStat:t='" + status + "' } "
    local pad1 = "1@lines_pad"
    local pad2 = "1@lines_pad"
    local interval1 = "1@lines_shop_interval"
    local interval2 = "1@lines_shop_interval"

    if (c0 == c1)
    {//vertical
      lines += format(arrowFormat,
                 "vertical", //type
                 "1@modArrowWidth", //width
                 pad1 + " + " + pad2 + " + " + (r1 - r0 - 1) + "@shop_height", //height
                 (c0 + 0.5) + "@shop_width - 0.5@modArrowWidth", //posX
                 (r0 + 1) + "@shop_height - " + pad1, //posY
                 "0")
    }
    else if (r0==r1)
    {//horizontal
      lines += format(arrowFormat,
                 "horizontal",  //type
                 (c1 - c0 - 1) + "@shop_width + " + interval1 + " + " + interval2, //width
                 "1@modArrowWidth", //height
                 (c0 + 1) + "@shop_width - " + interval1, //posX
                 (r0 + 0.5) + "@shop_height - 0.5@modArrowWidth", // posY
                 "0")
    }
    else if (isFakeUnitReq)
    {//special line for fake unit. Line is go to unit plate on side
      lines += format(lineFormat,
                       pad1 + " + " + (r1 - r0 - 0.5) + "@shop_height",//height
                       "1@modLineWidth", //width
                       (c0 + 0.5) + "@shop_width" + ((c0 > c1) ? "- 0.5@modLineWidth" : "+ 0.5@modLineWidth"), //posX
                       (r0 + 1) + "@shop_height - " + pad1 + ((c0 > c1) ? "+w" : ""), // posY
                       (c0 > c1) ? "-90" : "90")
      lines += format(arrowFormat,
                       "horizontal",  //type
                       (::abs(c1 - c0) - 0.5) + "@shop_width + " + interval1, //width
                       "1@modArrowWidth", //height
                       (c1 > c0 ? (c0 + 0.5) : c0) + "@shop_width" + (c1 > c0 ? "" : (" - " + interval1)), //posX
                       (r1 + 0.5) + "@shop_height - 0.5@modArrowWidth", // posY
                       (c0 > c1) ? "180" : "0")
      lines += format(angleFormat,
                       "1@modAngleWidth", //width
                       "1@modAngleWidth", //height
                       (c0 + 0.5) + "@shop_width - 0.5@modAngleWidth", //posX
                       (r1 + 0.5) + "@shop_height - 0.5@modAngleWidth", // posY
                       (c0 > c1 ? "-90" : "0"))
    }
    else
    {//double
      local lh = 0
      local offset = isMultipleArrow ? 0.1 : 0
      local arrowOffset = c0 > c1 ? -offset : offset

      lines += format(lineFormat,
                       pad1 + " + " + lh + "@shop_height",//height
                       "1@modLineWidth", //width
                       (c0 + 0.5 + arrowOffset) + "@shop_width" + ((c0 > c1) ? "-" : "+") + " 0.5@modLineWidth", //posX
                       (r0 + 1) + "@shop_height - " + pad1 + ((c0 > c1) ? "+ w " : ""), // posY
                       (c0 > c1) ? "-90" : "90")

      lines += format(lineFormat,
                      (::abs(c1-c0) - offset) + "@shop_width",
                      "1@modLineWidth", //height
                      (::min(c0, c1) + 0.5 + (c0 > c1 ? 0 : offset)) + "@shop_width",
                      (lh + r0 + 1) + "@shop_height - 0.5@modLineWidth",
                      "0")
      lines += format(angleFormat,
                       "1@modAngleWidth", //width
                       "1@modAngleWidth", //height
                       (c0 + 0.5 + arrowOffset) + "@shop_width - 0.5@modAngleWidth", //posX
                       (lh + r0 + 1) + "@shop_height - 0.5@modAngleWidth", // posY
                       (c0 > c1 ? "-90" : "0"))
      lines += format(arrowFormat,
                      "vertical",
                      "1@modArrowWidth",
                      pad2 + " + " + (r1 - r0 - 1 - lh) + "@shop_height",
                      (c1 + 0.5) + "@shop_width - 0.5@modArrowWidth",
                      (lh + r0 + 1) + "@shop_height + 0.2@modArrowWidth",
                      "0")
      lines += format(angleFormat,
                       "1@modAngleWidth", //width
                       "1@modAngleWidth", //height
                       (c1 + 0.5) + "@shop_width - 0.5@modAngleWidth",
                       (lh + r0 + 1) + "@shop_height - 0.5@modAngleWidth",
                       (c0 > c1 ? "90" : "180"))
    }

    return lines
  }

  function fillBGLines(treeData)
  {
    guiScene.setUpdatesEnabled(false, false)
    generateHeaders(treeData)
    generateBGPlates(treeData)
    generateTierArrows(treeData)
    generateAirAddictiveArrows(treeData)
    guiScene.setUpdatesEnabled(true, true)

    local contentWidth = scene.findObject("shopTable_air_rows").getSize()[0]
    local containerWidth = scene.findObject("shop_useful_width").getSize()[0]
    local pos = (contentWidth >= containerWidth)? "0" : "(pw-w)/2"
    scene.findObject("shop_items_pos_div").left = pos
  }

  function generateAirAddictiveArrows(treeData)
  {
    local tblBgObj = scene.findObject("shopTable_air_rows")
    local data = ""
    foreach(lc in treeData.lines)
    {
      fillAirReq(lc.air, lc.reqAir)
      data += createLine(lc.line[0], lc.line[1], lc.line[2], lc.line[3], getLineStatus(lc),
        {
          isFakeUnitReq = lc.reqAir?.isFakeUnit
          isMultipleArrow = lc.arrowCount > 1
        }
      )
    }

    foreach(row, rowArr in treeData.tree) //check groups even they dont have requirements
      for(local col = 0; col < rowArr.len(); col++)
        if (::isUnitGroup(rowArr[col]))
          fillAirReq(rowArr[col])

    guiScene.replaceContentFromText(tblBgObj, data, data.len(), this)

    tblBgObj.width = treeData.tree[0].len() + "@shop_width"
  }

  function generateHeaders(treeData)
  {
    local obj = scene.findObject("tree_header_div")
    local view = {
      plates = [],
      separators = [],
    }

    local sectionsTotal = treeData.sectionsPos.len() - 1
    local widthStr = ::is_small_screen
      ? "1@maxWindowWidth -1@modBlockTierNumHeight -1@scrollBarSize"
      : "1@slotbarWidthFull -1@modBlockTierNumHeight -1@scrollBarSize"
    local totalWidth = guiScene.calcString(widthStr, null)
    local itemWidth = guiScene.calcString("@shop_width", null)

    local extraWidth = "+" + ::max(0, totalWidth - (itemWidth * treeData.sectionsPos[sectionsTotal])) / 2
    local extraLeft = extraWidth + "+1@modBlockTierNumHeight"
    local extraRight = extraWidth + "+1@scrollBarSize - 2@frameHeaderPad"

    for (local s = 0; s < sectionsTotal; s++)
    {
      local isLeft = s == 0
      local isRight = s == sectionsTotal - 1

      local x = treeData.sectionsPos[s] + "@shop_width" + (isLeft ? "" : extraLeft)
      local w = (treeData.sectionsPos[s + 1] - treeData.sectionsPos[s]) + "@shop_width" + (isLeft ? extraLeft : "") + (isRight ? extraRight : "")

      local isResearchable = ::getTblValue(s, treeData.sectionsResearchable)
      local title = isResearchable ? "#shop/section/researchable" : "#shop/section/premium"

      view.plates.append({ title = title, x = x, w = w })
      if (!isLeft)
        view.separators.append({ x = x })
    }

    local data = ::handyman.renderCached("gui/shop/treeHeadPlates", view)
    guiScene.replaceContentFromText(obj, data, data.len(), this)
  }

  function generateBGPlates(treeData)
  {
    local tblBgObj = scene.findObject("shopTable_air_plates")
    local view = {
      plates = [],
      vertSeparators = [],
      horSeparators = [],
    }

    local lastFilledRank = treeData.ranksHeight.len() - 1
    for(local i = lastFilledRank - 1; i >= 0; i--)
    {
      if (treeData.ranksHeight[i] != treeData.ranksHeight[lastFilledRank])
        break
      lastFilledRank = i
    }

    local tiersTotal = min(lastFilledRank, treeData.tree.len())
    local sectionsTotal = treeData.sectionsPos.len() - 1

    local widthStr = ::is_small_screen
      ? "1@maxWindowWidth -1@modBlockTierNumHeight -1@scrollBarSize"
      : "1@slotbarWidthFull -1@modBlockTierNumHeight -1@scrollBarSize"
    local totalWidth = guiScene.calcString(widthStr, null)
    local itemWidth = guiScene.calcString("@shop_width", null)

    local extraRight = "+" + ::max(0, totalWidth - (itemWidth * treeData.sectionsPos[sectionsTotal])) / 2
    local extraLeft = extraRight + "+1@modBlockTierNumHeight"
    local extraTop = "+1@shop_h_extra_first"
    local extraBottom = "+1@shop_h_extra_last"

    for(local i = 0; i < tiersTotal; i++)
    {
      local isTop = i == 0 || treeData.ranksHeight[i] == 0
      local isBottom = i == tiersTotal - 1
      local tierNum = (i+1).tostring()
      local tierUnlocked = ::is_era_available(curCountry, i + 1, getCurPageEsUnitType())
      local fakeRowsCount = treeData.fakeRanksRowsCount[i + 1]

      for(local s = 0; s < sectionsTotal; s++)
      {
        local isLeft = s == 0
        local isRight = s == sectionsTotal - 1
        local isResearchable = ::getTblValue(s, treeData.sectionsResearchable)
        local tierType = tierUnlocked || !isResearchable ? "unlocked" : "locked"

        local x = treeData.sectionsPos[s] + "@shop_width" + (isLeft ? "" : extraLeft)
        local y = (treeData.ranksHeight[i] + fakeRowsCount) + "@shop_height" + (isTop && fakeRowsCount == 0 ? "" : extraTop)
        local w = (treeData.sectionsPos[s + 1] - treeData.sectionsPos[s]) + "@shop_width"
          + (isLeft ? extraLeft : "") + (isRight ? extraRight : "")
        local h = (treeData.ranksHeight[i + 1] - treeData.ranksHeight[i] - fakeRowsCount)
          + "@shop_height" + ((isTop && fakeRowsCount == 0) ? extraTop : "") + (isBottom ? extraBottom : "")


        if (fakeRowsCount > 0)
        {
          local fakeRowY = treeData.ranksHeight[i] + "@shop_height" + (isTop ? "" : extraTop)
          local fakeRowH = fakeRowsCount + "@shop_height" + (isTop ? extraTop : "") + (isBottom ? extraBottom : "")
          view.plates.append({ tierNum = tierNum, tierType = "unlocked", x = x, y = fakeRowY, w = w, h = fakeRowH })
          if (!isLeft)
            view.vertSeparators.append({ x = x, y = fakeRowY, h = fakeRowH, isTop = isTop, isBottom = isBottom })
          if (!isTop)
            view.horSeparators.append({ x = x, y = fakeRowY, w = w, isLeft = isLeft })
          isTop = false
        }

        view.plates.append({ tierNum = tierNum, tierType = tierType, x = x, y = y, w = w, h = h })
        if (!isLeft)
          view.vertSeparators.append({ x = x, y = y, h = h, isTop = isTop, isBottom = isBottom })
        if (!isTop)
          view.horSeparators.append({ x = x, y = y, w = w, isLeft = isLeft })
      }
    }
    local data = ::handyman.renderCached("gui/shop/treeBgPlates", view)
    guiScene.replaceContentFromText(tblBgObj, data, data.len(), this)
  }

  function getRankProgressTexts(rank, ranksBlk = null)
  {
    if (!ranksBlk)
      ranksBlk = ::get_ranks_blk()

    local isEraAvailable = ::is_era_available(curCountry, rank, getCurPageEsUnitType())
    local tooltipPlate = ""
    local tooltipRank = ""
    local tooltipReqCounter = ""
    local reqCounter = ""

    if (isEraAvailable)
    {
      local unitsCount = boughtVehiclesCount[rank]
      local unitsTotal = totalVehiclesCount[rank]
      tooltipRank = ::loc("shop/age/tooltip") + ::loc("ui/colon") + ::colorize("userlogColoredText", ::get_roman_numeral(rank))
        + "\n" + ::loc("shop/tier/unitsBought") + ::loc("ui/colon") + ::colorize("userlogColoredText", ::format("%d/%d", unitsCount, unitsTotal))
    }
    else
    {
      local unitType = getCurPageEsUnitType()
      for (local prevRank = rank - 1; prevRank > 0; prevRank--)
      {
        local unitsCount = boughtVehiclesCount[prevRank]
        local unitsNeed = ::getUnitsNeedBuyToOpenNextInEra(curCountry, unitType, prevRank, ranksBlk)
        local unitsLeft = max(0, unitsNeed - unitsCount)

        if (unitsLeft > 0)
        {
          local txtThisRank = ::colorize("userlogColoredText", ::get_roman_numeral(rank))
          local txtPrevRank = ::colorize("userlogColoredText", ::get_roman_numeral(prevRank))
          local txtUnitsNeed = ::colorize("badTextColor", unitsNeed)
          local txtUnitsLeft = ::colorize("badTextColor", unitsLeft)
          local txtCounter = ::format("%d/%d", unitsCount, unitsNeed)
          local txtCounterColored = ::colorize("badTextColor", txtCounter)

          local txtRankIsLocked = ::loc("shop/unlockTier/locked", { rank = txtThisRank })
          local txtNeedUnits = ::loc("shop/unlockTier/reqBoughtUnitsPrevRank", { prevRank = txtPrevRank, amount = txtUnitsLeft })
          local txtRankLockedDesc = ::loc("shop/unlockTier/desc", { rank = txtThisRank, prevRank = txtPrevRank, amount = txtUnitsNeed })
          local txtRankProgress = ::loc("shop/unlockTier/progress", { rank = txtThisRank }) + ::loc("ui/colon") + txtCounterColored

          if (prevRank == rank - 1)
          {
            reqCounter = txtCounter
            tooltipReqCounter = txtRankProgress + "\n" + txtNeedUnits
          }

          tooltipRank = txtRankIsLocked + "\n" + txtNeedUnits + "\n" + txtRankLockedDesc
          tooltipPlate = txtRankProgress + "\n" + txtNeedUnits

          break
        }
      }
    }

    return { tooltipPlate = tooltipPlate, tooltipRank = tooltipRank, tooltipReqCounter = tooltipReqCounter, reqCounter = reqCounter }
  }

  function generateTierArrows(treeData)
  {
    local data = ""
    local blk = ::get_ranks_blk()
    local pageUnitsType = getCurPageEsUnitType()

    for(local i = 1; i <= ::max_country_rank; i++)
    {
      local curEraPos = treeData.ranksHeight[i]
      local prevEraPos = treeData.ranksHeight[i-1]
      local curFakeRowRankCount = treeData.fakeRanksRowsCount[i]

      if (curEraPos == prevEraPos || ((curEraPos - curFakeRowRankCount) == prevEraPos ))
        continue

      local prevFakeRowRankCount = treeData.fakeRanksRowsCount[i-1]
      local drawArrow = i > 1 && prevEraPos != (treeData.ranksHeight[i-2] + prevFakeRowRankCount)
      local isRankAvailable = ::is_era_available(curCountry, i, pageUnitsType)
      local status =  isRankAvailable ?  "owned" : "locked"

      local texts = getRankProgressTexts(i, blk)

      local arrowData = ""
      if (drawArrow)
      {
        arrowData = ::format("shopArrow { type:t='vertical'; size:t='1@modArrowWidth, %s@shop_height - 1@modBlockTierNumHeight';" +
                      "pos:t='0.5pw - 0.5w, %s@shop_height + 0.5@modBlockTierNumHeight';" +
                      "shopStat:t='%s'; modArrowPlate{ text:t='%s'; tooltip:t='%s'}}",
                    (treeData.ranksHeight[i-1] - treeData.ranksHeight[i-2] - prevFakeRowRankCount).tostring(),
                    (treeData.ranksHeight[i-2] + prevFakeRowRankCount).tostring(),
                    status,
                    texts.reqCounter,
                    ::g_string.stripTags(texts.tooltipReqCounter)
                    )
      }
      local modBlockFormat = "modBlockTierNum { class:t='vehicleRanks' status:t='%s'; pos:t='0, %s@shop_height - 0.5h'; text:t='%s'; tooltip:t='%s'}"

      if (curFakeRowRankCount > 0)
        data += ::format(modBlockFormat,
                  "owner",
                  prevEraPos.tostring(),
                  "",
                  "")

      data += ::format(modBlockFormat,
                  status,
                  (prevEraPos + curFakeRowRankCount).tostring(),
                  ::loc("shop/age/num", { num = ::get_roman_numeral(i) }),
                  ::g_string.stripTags(texts.tooltipRank))

      data += arrowData

      local tierObj = scene.findObject("shop_tier_" + i.tostring())
      if (::checkObj(tierObj))
        tierObj.tooltip = texts.tooltipPlate
    }

    local height = treeData.ranksHeight[treeData.ranksHeight.len()-1] + "@shop_height"
    local tierObj = scene.findObject("tier_arrows_div")
    tierObj.height = height
    guiScene.replaceContentFromText(tierObj, data, data.len(), this)

    scene.findObject("shop_items_scroll_div").height = height + " + 1@shop_h_extra_first + 1@shop_h_extra_last"
  }

  function updateBoughtVehiclesCount()
  {
    local bought = array(::max_country_rank + 1, 0)
    local total = array(::max_country_rank + 1, 0)
    local pageUnitsType = getCurPageEsUnitType()

    foreach(unit in ::all_units)
      if (unit.shopCountry == curCountry && pageUnitsType == ::get_es_unit_type(unit))
      {
        local isOwn = ::isUnitBought(unit)
        if (isOwn)
          bought[unit.rank]++
        if (isOwn || unit.isVisibleInShop())
          total[unit.rank]++
      }

    boughtVehiclesCount = bought
    totalVehiclesCount = total
  }

  function fillAirReq(item, reqUnit = null)
  {
    local req = true
    if (item?.reqAir)
      req = ::isUnitBought(::getAircraftByName(item.reqAir))
    if (req && reqUnit?.isFakeUnit)
      req = isUnlockedFakeUnit(reqUnit)
    if (::isUnitGroup(item))
    {
      foreach(idx, air in item.airsGroup)
        air.shopReq = req
      item.shopReq <- req
    }
    else if (item?.isFakeUnit)
      item.shopReq <- req
    else
      item.shopReq = req
  }

  function isUnlockedFakeUnit(unit)
  {
    return get_units_count_at_rank(unit?.rank,
      unitTypes.getByName(unit?.isReqForFakeUnit ? ::split(unit.name, "_")?[0] : unit.name,
        false).esUnitType,
      unit.country, true)
      >= (((::split(unit.name, "_"))?[1] ?? "0").tointeger() + 1)
  }

  function getCurPageEsUnitType()
  {
    return getCurPageUnitType().esUnitType
  }

  function getCurPageUnitType()
  {
    return unitTypes.getByArmyId(curPage)
  }

  function findUnitInGroupTableById(id)
  {
    if (::checkObj(groupChooseObj))
      return groupChooseObj.findObject("airs_table").findObject(id)

    return null
  }

  function findCloneGroupObjById(id)
  {
    if (::checkObj(groupChooseObj))
      return groupChooseObj.findObject("clone_td_" + id)

    return null
  }

  function findAirTableObjById(id)
  {
    if (::checkObj(scene))
      return scene.findObject("shop_items_list").findObject(id)

    return null
  }

  function getAirObj(unitName)
  {
    local airObj = findUnitInGroupTableById(unitName)
    if (::checkObj(airObj))
      return airObj

    return findAirTableObjById(unitName)
  }

  function getUnitCellObj(unitName)
  {
    local cellObj = findUnitInGroupTableById("td_" + unitName)
    if (::checkObj(cellObj))
      return cellObj

    return findAirTableObjById("td_" + unitName)
  }

  function getCellObjByRowCol(row, col)
  {
    local tableObj = scene.findObject("shop_items_list")
    if (!::check_obj(tableObj))
      return null
    local rowObj = row < tableObj.childrenCount() ? tableObj.getChild(row) : null
    return rowObj && col < rowObj.childrenCount() ? rowObj.getChild(col) : null
  }

  function checkUnitItemAndUpdate(unit)
  {
    if (!unit || unit?.isFakeUnit)
      return

    local unitObj = getUnitCellObj(unit.name)
    updateUnitItem(unit, unitObj)

    ::updateAirAfterSwitchMod(unit)

    if (!::isUnitGroup(unit) && ::isGroupPart(unit))
      updateGroupItem(unit.group)
  }

  function updateUnitItem(unit, placeObj)
  {
    if (!::checkObj(placeObj))
      return

    local params = getUnitItemParams(unit)
    params.fullBlock = false

    local unitBlock = ::build_aircraft_item(unit.name, unit, params)
    guiScene.replaceContentFromText(placeObj, unitBlock, unitBlock.len(), this)

    ::fill_unit_item_timers(placeObj.findObject(unit.name), unit, params)

    ::showUnitDiscount(placeObj.findObject(unit.name+"-discount"), unit)

    local bonusData = unit.name
    if (::isUnitGroup(unit))
      bonusData = ::u.map(unit.airsGroup, function(unit) { return unit.name })
    showAirExpWpBonus(placeObj.findObject(unit.name+"-bonus"), bonusData)
  }

  function updateGroupItem(groupName)
  {
    local block = getItemBlockFromShopTree(groupName)
    if (!block)
      return

    updateUnitItem(block, findCloneGroupObjById(groupName))
    updateUnitItem(block, findAirTableObjById("td_" + groupName))
  }

  function checkBrokenListStatus(unit)
  {
    if (!unit)
      return false

    local posNum = ::find_in_array(brokenList, unit)
    if (!getItemStatusData(unit).broken && posNum >= 0)
    {
      brokenList.remove(posNum)
      return true
    }

    return false
  }

  function getUnitItemParams(unit)
  {
    if (!unit)
      return {}

    local is_unit = !::isUnitGroup(unit) && !unit?.isFakeUnit
    local params = {
      availableFlushExp = availableFlushExp
      setResearchManually = setResearchManually
    }
    return {
             hasActions     = true,
             showInService  = true,
             fullGroupBlock = !is_unit
             mainActionFunc = is_unit? "onUnitMainFunc" : "",
             mainActionText = is_unit? slotActions.getSlotActionFunctionName(unit, params) : ""
             fullBlock      = true
             shopResearchMode = shopResearchMode
             forceNotInResearch = !setResearchManually
             flushExp = availableFlushExp
             showBR = ::has_feature("GlobalShowBattleRating")
             getEdiffFunc = getCurrentEdiff.bindenv(this)
             tooltipParams = { needShopInfo = true }
           }
  }

  function getCurAircraft(checkGroups = true, returnDefaultUnitForGroups = false)
  {
    if (!checkObj(scene))
      return null

    local tableObj = scene.findObject("shop_items_list")
    local tree = getCurTreeData().tree
    local curRow = tableObj.cur_row.tointeger()
    local curCol = tableObj.cur_col.tointeger()
    if ((tree.len() <= curRow) || (tree[curRow].len() <= curCol))
      return null

    local mainTblUnit = tree[curRow][curCol]
    if (!::isUnitGroup(mainTblUnit))
      return mainTblUnit

    if (checkGroups && ::checkObj(groupChooseObj))
    {
      tableObj = groupChooseObj.findObject("airs_table")
      local idx = tableObj.cur_row.tointeger()
      if (idx in mainTblUnit.airsGroup)
        return mainTblUnit.airsGroup[idx]
    }

    if (returnDefaultUnitForGroups)
      return getDefaultUnitInGroup(mainTblUnit)

    return mainTblUnit
  }

  function getDefaultUnitInGroup(unitGroup)
  {
    local airsList = ::getTblValue("airsGroup", unitGroup)
    return ::getTblValue(0, airsList)
  }

  function getItemBlockFromShopTree(itemName)
  {
    local tree = getCurTreeData().tree
    for(local i = 0; i < tree.len(); ++i)
      for(local j = 0; j < tree[i].len(); ++j)
      {
        local name = ::getTblValue("name", tree[i][j])
        if (!name)
          continue

        if (itemName == name)
          return tree[i][j]
      }

    return null
  }

  function onAircraftsPage()
  {
    local pagesObj = scene.findObject("shop_pages_list")
    if (pagesObj)
    {
      local pageIdx = pagesObj.getValue()
      if (pageIdx < 0 || pageIdx >= pagesObj.childrenCount())
        return
      curPage = pagesObj.getChild(pageIdx).id
    }
    fillAircraftsList()
  }

  function onCloseShop()
  {
    if (closeShop)
      closeShop()
  }

  function fillPagesListBoxNoOpenGroup()
  {
    skipOpenGroup = true
    fillPagesListBox()
    skipOpenGroup = false
  }

  function fillPagesListBox()
  {
    if (shopResearchMode)
    {
      fillAircraftsList()
      return
    }

    local pagesObj = scene.findObject("shop_pages_list")
    if (!::checkObj(pagesObj))
      return

    local unitType = forceUnitType
      ?? lastUnitType
      ?? ::getAircraftByName(curAirName)?.unitType
      ?? unitTypes.INVALID

    forceUnitType = null //forceUnitType applyied only once

    local data = ""
    local curIdx = 0
    local countryData = ::u.search(shopData, (@(curCountry) function(country) { return country.name == curCountry})(curCountry))
    if (countryData)
    {
      local view = { tabs = [] }
      foreach(idx, page in countryData.pages)
      {
        local name = page.name
        view.tabs.append({
          id = name
          tabName = "#mainmenu/" + name
          discount = {
            discountId = getDiscountIconTabId(countryData.name, name)
          }
          squadronExpIconId = curCountry + ";" + name
          navImagesText = ::get_navigation_images_text(idx, countryData.pages.len())
        })

        if (name == unitType.armyId)
          curIdx = view.tabs.len() - 1
      }

      local tabCount = view.tabs.len()
      foreach(idx, tab in view.tabs)
        tab.navImagesText = ::get_navigation_images_text(idx, tabCount)

      data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    }
    guiScene.replaceContentFromText(pagesObj, data, data.len(), this)

    updateDiscountIconsOnTabs()

    pagesObj.setValue(curIdx)
  }

  function getDiscountIconTabId(country, unitType)
  {
    return country + "_" + unitType + "_discount"
  }

  function updateDiscountIconsOnTabs()
  {
    local pagesObj = scene.findObject("shop_pages_list")
    if (!::checkObj(pagesObj))
      return

    foreach(country in shopData)
    {
      if (country.name != curCountry)
        continue

      foreach(idx, page in country.pages)
      {
        local tabObj = pagesObj.findObject(page.name)
        if (!::checkObj(tabObj))
          continue

        local discountObj = tabObj.findObject(getDiscountIconTabId(curCountry, page.name))
        if (!::checkObj(discountObj))
          continue

        local discountData = getDiscountByCountryAndArmyId(curCountry, page.name)

        local maxDiscount = discountData?.maxDiscount ?? 0
        local discountTooltip = ::getTblValue("discountTooltip", discountData, "")
        tabObj.tooltip = discountTooltip
        discountObj.setValue(maxDiscount > 0? ("-" + maxDiscount + "%") : "")
        discountObj.tooltip = discountTooltip
      }
      break
    }
  }

  function getDiscountByCountryAndArmyId(country, armyId)
  {
    if (!::g_discount.haveAnyUnitDiscount())
      return null

    local unitType = unitTypes.getByArmyId(armyId)
    local discountsList = {}
    foreach(unit in ::all_units)
      if (unit.unitType == unitType
          && unit.shopCountry == country)
      {
        local discount = ::g_discount.getUnitDiscount(unit)
        if (discount > 0)
          discountsList[unit.name + "_shop"] <- discount
      }

    return ::g_discount.generateDiscountInfo(discountsList)
  }

  function initSearchBox()
  {
    if (shopResearchMode || !::has_feature("UnitsSearchBoxInShop"))
      return
    local handler = shopSearchBox.init({
      scene = scene.findObject("shop_search_box")
      curCountry = curCountry
      curEsUnitType = getCurPageEsUnitType()
      cbOwnerSearchHighlight = ::Callback(searchHighlight, this)
      cbOwnerSearchCancel    = ::Callback(searchCancel,    this)
      cbOwnerShowUnit        = ::Callback(showUnitInShop,  this)
      getEdiffFunc           = ::Callback(getCurrentEdiff, this)
    })
    registerSubHandler(handler)
    searchBoxWeak = handler.weakref()
  }

  function searchHighlight(units, isClear)
  {
    if (isClear)
      return highlightUnitsClear()
    local slots = highlightUnitsInTree(units.map(@(unit) unit.name))
    local tableObj = scene.findObject("shop_items_list")
    if (!::check_obj(tableObj))
      return
    foreach (coords in [ slots.coordsLast, slots.coordsFirst ])
    {
      local cellObj = coords ? getCellObjByRowCol(coords[0], coords[1]) : null
      if (::check_obj(cellObj))
        cellObj.scrollToView()
    }
    selCellOnSearchQuit = slots.coordsFirst
  }

  function highlightUnitsInTree(units)
  {
    local shadingObj = scene.findObject("shop_dark_screen")
    shadingObj.show(true)
    guiScene.applyPendingChanges(true)

    local res = { coordsFirst = null, coordsLast = null }
    local highlightList = []
    local tree = getCurTreeData().tree
    local tableObj = scene.findObject("shop_items_list")
    for(local row = 0; row < tree.len(); row++)
      for(local col = 0; col < tree[row].len(); col++)
      {
        local cell = tree[row][col]
        local isGroup = ::isUnitGroup(cell)
        local isHighlight = !cell?.isFakeUnit && !isGroup && ::isInArray(cell?.name, units)
        if (isGroup)
          foreach (unit in cell.airsGroup)
            isHighlight = isHighlight || ::isInArray(unit?.name, units)
        if (!isHighlight)
          continue
        res.coordsFirst = res.coordsFirst || [ row, col ]
        res.coordsLast  = [ row, col ]
        local objData  = {
          obj = getCellObjByRowCol(row, col)
          id = ::format("high_%d_%d", row, col)
          onClick = "onHighlightedCellClick"
          isNoDelayOnClick = true
        }
        highlightList.append(::guiTutor.getBlockFromObjData(objData, tableObj))
      }

    ::guiTutor.createHighlight(shadingObj, highlightList, this, {
      onClick = "onShadedCellClick"
      lightBlock = "tdiv"
      sizeIncAdd = 0
      isFullscreen = false
    })

    return res
  }

  function searchCancel()
  {
    highlightUnitsClear()

    if (selCellOnSearchQuit)
    {
      local tableObj = scene.findObject("shop_items_list")
      if (::check_obj(tableObj))
      {
        skipOpenGroup = true
        ::gui_bhv.OptionsNavigator.selectCell(tableObj, selCellOnSearchQuit[0], selCellOnSearchQuit[1])
        skipOpenGroup = false
      }
      selCellOnSearchQuit = null
    }

    restoreFocus()
  }

  function highlightUnitsClear()
  {
    local shadingObj = scene.findObject("shop_dark_screen")
    if (::check_obj(shadingObj))
      shadingObj.show(false)
  }

  function onHighlightedCellClick(obj)
  {
    local coordsStr = ::g_string.cutPrefix(obj?.id, "high_") ?? ""
    local coords = ::g_string.split(coordsStr, "_").map(@(c) ::to_integer_safe(c, -1, false))
    if ((coords?[0] ?? -1) >= 0 && (coords?[1] ?? -1) >= 0)
      selCellOnSearchQuit = coords
    guiScene.performDelayed(this, @() searchBoxWeak && searchBoxWeak.searchCancel())
  }

  function onShadedCellClick(obj)
  {
    if (searchBoxWeak)
      searchBoxWeak.searchCancel()
  }

  function openMenuForCurAir(obj)
  {
    local curAir = getCurAircraft()
    if (!("name" in curAir))
      return
    local curAirObj = obj.findObject(getCurAircraft().name)
    if (::checkObj(curAirObj))
      openUnitActionsList(curAirObj, true)
  }

  function onAircraftClick(obj)
  {
    scene.findObject("shop_items_list").select()
    checkSelectAirGroup()
    openMenuForCurAir(obj)
  }

  function checkSelectAirGroup(block = null, selectUnitName = "")
  {
    local item = block == null? getCurAircraft() : block
    if (skipOpenGroup || groupChooseObj || !item || !::isUnitGroup(item))
      return
    local silObj = scene.findObject("shop_items_list")
    if (!::checkObj(silObj))
      return
    local grObj = silObj.findObject(item.name)
    if (!::checkObj(grObj))
      return

    //choose aircraft from group window
    local tdObj = grObj.getParent()
    local tdPos = tdObj.getPosRC()
    local tdSize = tdObj.getSize()
    local leftPos = (tdPos[0] + tdSize[0] / 2) + " -50%w"

    local cellHeight = tdSize[1] || 86 // To avoid division by zero
    local screenHeight = ::screen_height()
    local safeareaHeight = guiScene.calcString("@rh", null)
    local safeareaBorderHeight = ::floor((screenHeight - safeareaHeight) / 2)
    local containerHeight = item.airsGroup.len() * cellHeight

    local topPos = tdPos[1]
    local heightOutOfSafearea = (topPos + containerHeight) - (safeareaBorderHeight + safeareaHeight)
    if (heightOutOfSafearea > 0)
      topPos -= ::ceil(heightOutOfSafearea / cellHeight) * cellHeight
    topPos = ::max(topPos, safeareaBorderHeight)

    groupChooseObj = guiScene.loadModal("", "gui/shop/shopGroup.blk", "massTransp", this)
    local placeObj = groupChooseObj.findObject("tablePlace")
    placeObj.left = leftPos.tostring()
    placeObj.top = topPos.tostring()

    groupChooseObj.group = item.name
    local tableDiv = groupChooseObj.findObject("slots_scroll_div")
    tableDiv.pos = "0,0"

    fillGroupObj(selectUnitName)
    fillGroupObjAnimParams(tdSize, tdPos)

    updateGroupObjNavBar()
  }

  function fillGroupObjAnimParams(tdSize, tdPos)
  {
    local animObj = groupChooseObj.findObject("tablePlace")
    if (!animObj)
      return
    local size = animObj.getSize()
    if (!size[1])
      return

    animObj["height-base"] = tdSize[1].tostring()
    animObj["height-end"] = size[1].tostring()

    //update anim fixed position
    local heightDiff = size[1] - tdSize[1]
    if (heightDiff <= 0)
      return

    local pos = animObj.getPosRC()
    local topPart = (tdPos[1] - pos[1]).tofloat() / heightDiff
    local animFixedY = tdPos[1] + topPart * tdSize[1]
    animObj.top = format("%d - %fh", animFixedY.tointeger(), topPart)
  }

  function updateGroupObjNavBar()
  {
    navBarGroupObj = groupChooseObj.findObject("nav-help-group")
    navBarGroupObj.hasMaxWindowSize = ::is_small_screen ? "yes" : "no"
    initShowMode(navBarGroupObj)
    updateButtons()
  }

  function fillGroupObjArrows(group)
  {
    local unitPosNum = 0
    local prevGroupUnit = null
    local lines = ""
    foreach(unit in group)
    {
      if (!unit)
        continue
      local reqUnit = ::getPrevUnit(unit)
      if (reqUnit  && prevGroupUnit
          && reqUnit.name == prevGroupUnit.name)
      {
        local status = ::isUnitBought(prevGroupUnit) || ::isUnitBought(unit)
                       ? ""
                       : "locked"
        lines += createLine(unitPosNum - 1, 0, unitPosNum, 0, status)
      }
      prevGroupUnit = unit
      unitPosNum++
    }
    return lines
  }

  function fillGroupObj(selectUnitName = "")
  {
    if (!::checkObj(scene) || !::checkObj(groupChooseObj))
      return

    local item = getCurAircraft(false)
    if (!item || !::isUnitGroup(item))
      return

    local gTblObj = groupChooseObj.findObject("airs_table")
    if (!::checkObj(gTblObj))
      return

    gTblObj["class"] = "shopTable"
    gTblObj.navigatorShortcuts = "yes"
    gTblObj.alwaysShowBorder = "yes"

    if (selectUnitName == "")
    {
      local groupUnit = getDefaultUnitInGroup(item)
      if (groupUnit)
        selectUnitName = groupUnit.name
    }
    fillUnitsInGroup(gTblObj, item.airsGroup, selectUnitName)

    local lines = fillGroupObjArrows(item.airsGroup)
    guiScene.appendWithBlk(groupChooseObj.findObject("arrows_nest"), lines, this)

    foreach(air in item.airsGroup)
      if (air)
      {
        ::showUnitDiscount(gTblObj.findObject(air.name+"-discount"), air)
        ::showAirExpWpBonus(gTblObj.findObject(air.name+"-bonus"), air.name)
        if (getItemStatusData(air).broken && !::isInArray(air, brokenList))
          brokenList.append(air)
      }
  }

  function fillUnitsInGroup(tblObj, airList, selectUnitName = "")
  {
    local data = ""
    local selected = tblObj.cur_row.tointeger()
    local unitItems = []
    for(local i = 0; i < airList.len(); i++)
    {
      if (selectUnitName == airList[i].name)
        selected = i

      local params = getUnitItemParams(airList[i])
      local unitBlk = ::build_aircraft_item(airList[i].name, airList[i], params)
      unitItems.append({ id = airList[i].name, unit = airList[i], params = params })
      data += ::format("tr { %s }\n", unitBlk)
    }

    guiScene.replaceContentFromText(tblObj, data, data.len(), this)
    foreach (unitItem in unitItems)
      ::fill_unit_item_timers(tblObj.findObject(unitItem.id), unitItem.unit, unitItem.params)
    tblObj.select()
    ::gui_bhv.columnNavigator.selectCell(tblObj, selected, 0, false, false, false)
  }

  function onSceneActivate(show)
  {
    base.onSceneActivate(show)
    scene.enable(show)
    if (show)
      restoreFocus()
    else
      destroyGroupChoose()
  }

  function onDestroy()
  {
    destroyGroupChoose()
  }

  function destroyGroupChoose(destroySpecGroupName = "")
  {
    if (!::checkObj(groupChooseObj)
        || (destroySpecGroupName != "" &&
            destroySpecGroupName == groupChooseObj.group))
      return

    guiScene.destroyElement(groupChooseObj)
    groupChooseObj=null
    updateButtons()
    ::broadcastEvent("ModalWndDestroy")
  }

  function destroyGroupChooseDelayed()
  {
    guiScene.performDelayed(this, destroyGroupChoose)
  }

  function onCancelSlotChoose(obj)
  {
    if (::checkObj(groupChooseObj))
      destroyGroupChooseDelayed()
  }

  function onRepairAll(obj)
  {
    local cost = ::Cost()
    cost.wp = repairAllCost

    if (!::check_balance_msgBox(cost))
      return

    taskId = ::shop_repair_all(curCountry, false)
    if (taskId < 0)
      return

    ::set_char_cb(this, slotOpCb)
    showTaskProgressBox()

    afterSlotOp = function()
    {
      showTaskProgressBox()
      checkBrokenUnitsAndUpdateThem()
      local curAir = getCurAircraft()
      lastPurchase = curAir
      needUpdateSlotbar = true
      needUpdateSquadInfo = true
      destroyProgressBox()
    }
  }

  function onEventUnitRepaired(params)
  {
    local unit = ::getTblValue("unit", params)

    if (checkBrokenListStatus(unit))
      checkUnitItemAndUpdate(unit)

    updateRepairAllButton()
  }

  function onEventSparePurchased(params)
  {
    if (!scene.isEnabled() || !scene.isVisible())
      return
    checkUnitItemAndUpdate(::getTblValue("unit", params))
  }

  function onEventModificationPurchased(params)
  {
    if (!scene.isEnabled() || !scene.isVisible())
      return
    checkUnitItemAndUpdate(::getTblValue("unit", params))
  }

  function onEventAllModificationsPurchased(params)
  {
    if (!scene.isEnabled() || !scene.isVisible())
      return
    checkUnitItemAndUpdate(::getTblValue("unit", params))
  }

  function onEventUpdateResearchingUnit(params)
  {
    local unitName = ::getTblValue("unitName", params, ::shop_get_researchable_unit_name(curCountry, getCurPageEsUnitType()))
    checkUnitItemAndUpdate(::getAircraftByName(unitName))
  }

  function onOpenOnlineShop(obj)
  {
    OnlineShopModel.showGoods({
      unitName = getCurAircraft().name
    }, "shop")
  }

  function onBuy()
  {
    unitActions.buy(getCurAircraft(true, true), "shop")
  }

  function onResearch(obj)
  {
    local unit = getCurAircraft()
    if (!unit || ::isUnitGroup(unit) || unit?.isFakeUnit || !::checkForResearch(unit))
      return

    unitActions.research(unit)
  }

  function onConvert(obj)
  {
    local unit = getCurAircraft()
    if (!unit || !::can_spend_gold_on_unit_with_popup(unit))
      return

    local unitName = unit.name
    selectCellByUnitName(unitName)
    ::gui_modal_convertExp(unit)
  }

  function getUnitNameByBtnId(id)
  {
    if (id.len() < 13)
      return ""
    return id.slice(13)
  }

  function onEventUnitResearch(params)
  {
    if (!::checkObj(scene))
      return

    local prevUnitName = ::getTblValue("prevUnitName", params)
    local unitName = ::getTblValue("unitName", params)

    if (prevUnitName && prevUnitName != unitName)
      checkUnitItemAndUpdate(::getAircraftByName(prevUnitName))

    local unit = ::getAircraftByName(unitName)
    updateResearchVariables()
    checkUnitItemAndUpdate(unit)

    selectCellByUnitName(unit)

    if (shopResearchMode && availableFlushExp <= 0)
    {
      ::buyUnit(unit)
      onCloseShop()
    }
  }

  function onEventUnitBought(params)
  {
    ::update_gamercards()

    local unitName = ::getTblValue("unitName", params)
    local unit = unitName ? ::getAircraftByName(unitName) : null
    if (!unit)
      return

    if (::getTblValue("receivedFromTrophy", params, false) && unit.isVisibleInShop())
    {
      doWhenActiveOnce("loadFullAircraftsTable")
      doWhenActiveOnce("fillAircraftsList")
      return
    }

    updateResearchVariables()
    fillAircraftsList(unitName)
    fillGroupObj()

    if (!isSceneActive())
      return

    if (!::checkIsInQueue() && !shopResearchMode)
      onTake(unit, {isNewUnit = true})
    else if (shopResearchMode)
      selectRequiredUnit()
  }

  function onEventDebugUnlockEnabled(params)
  {
    doWhenActiveOnce("loadFullAircraftsTable")
    doWhenActiveOnce("fillAircraftsList")
  }

  function onEventUnitRented(params)
  {
    onEventUnitBought(params)
  }

  function showUnitInShop(unitId)
  {
    if (!isSceneActive() || ::checkIsInQueue() || shopResearchMode)
      return
    local unit = ::getAircraftByName(unitId)
    if (!unit || !unit.isVisibleInShop() || unitId == curAirName)
      return

    curAirName = unitId
    setUnitType(unit.unitType)
    ::switch_profile_country(::getUnitCountry(unit))
    selectCellByUnitName(unitId)
  }

  function selectCellByUnitName(unitName)
  {
    if (!unitName || unitName == "")
      return false

    if (!::checkObj(scene))
      return false

    local tree = getCurTreeData().tree
    local tableObj = scene.findObject("shop_items_list")
    if (!::checkObj(tableObj))
      return false

    foreach(rowIdx, row in tree)
      foreach(colIdx, item in row)
        if (::isUnitGroup(item))
        {
          foreach(groupItemIdx, groupItem in item.airsGroup)
            if (groupItem.name == unitName)
            {
              ::gui_bhv.columnNavigator.selectCell.call(::gui_bhv.columnNavigator, tableObj, rowIdx, colIdx)
              if (::checkObj(groupChooseObj))
              {
                local groupTableObj = groupChooseObj.findObject("airs_table")
                ::gui_bhv.columnNavigator.selectCell.call(::gui_bhv.columnNavigator, groupTableObj, groupItemIdx, groupTableObj.cur_col.tointeger())
              }
              return true
            }
        }
        else
        {
          if (item && item.name == unitName)
          {
            ::gui_bhv.columnNavigator.selectCell.call(::gui_bhv.columnNavigator, tableObj, rowIdx, colIdx)
            return true
          }
        }
    return false
  }

  function onTake(unit, params = {})
  {
    base.onTake(unit, {
      unitObj = getAirObj(unit.name)
      cellClass = "shopClone"
      isNewUnit = false
      getEdiffFunc = getCurrentEdiff.bindenv(this)
    }.__merge(params))
  }

  function onEventExpConvert(params)
  {
    doWhenActiveOnce("fillAircraftsList")
    fillGroupObj()
  }

  function onEventCrewTakeUnit(params)
  {
    foreach(param in ["unit", "prevUnit"])
    {
      local unit = ::getTblValue(param, params)
      if (!unit)
        continue

      checkUnitItemAndUpdate(unit)
    }

    destroyGroupChoose()
  }

  function onBack(obj)
  {
    save(false)
  }
  function afterSave()
  {
    goBack()
  }

  function onDoubleClick(obj)
  {
    onUnitMainFunc(obj)
  }

  function onUnitMainFunc(obj)
  {
    local unit = getCurAircraft()
    if (!unit)
      return

    slotActions.slotMainAction(unit, {
      onSpendExcessExp = ::Callback(onSpendExcessExp, this)
      onTakeParams = {
        unitObj = getAirObj(unit.name)
        cellClass = "shopClone"
        isNewUnit = false
        getEdiffFunc = getCurrentEdiff.bindenv(this)
      }
      curEdiff = getCurrentEdiff()
      setResearchManually = setResearchManually
      availableFlushExp = availableFlushExp
    })
  }

  function onModifications(obj)
  {
    msgBox("not_available", ::loc("msgbox/notAvailbleYet"), [["ok", function() {} ]], "ok", { cancel_fn = function() {}})
  }

  function checkTag(aircraft, tag)
  {
    if (!tag) return true
    return isInArray(tag, aircraft.tags)
  }

  function setUnitType(unitType)
  {
    if (unitType == lastUnitType)
      return

    forceUnitType = unitType
    doWhenActiveOnce("fillPagesListBoxNoOpenGroup")
  }

  function onEventCountryChanged(p)
  {
    local country = ::get_profile_country_sq()
    if (country == curCountry)
      return

    curCountry = country
    doWhenActiveOnce("fillPagesListBoxNoOpenGroup")
  }

  function initShowMode(tgtNavBar)
  {
    local obj = tgtNavBar.findObject("show_mode")
    if (!::g_login.isProfileReceived() || !::checkObj(obj))
      return

    local showModeRaw = ::load_local_account_settings("shopShowMode", -1)

    curDiffCode = -1
    showModeList = []
    foreach(diff in ::g_difficulty.types)
      if (diff.diffCode == -1 || (!shopResearchMode && diff.isAvailable()))
      {
        showModeList.append({
          text = diff.diffCode == -1 ? ::loc("options/auto") : ::colorize("warningTextColor", diff.getLocName())
          diffCode = diff.diffCode
          enabled = true
          textStyle = "textStyle:t='textarea';"
        })
        if (showModeRaw == diff.diffCode)
          curDiffCode = showModeRaw
      }

    if (showModeList.len() <= 2)
    {
      curDiffCode = -1
      obj.show(false)
      obj.enable(false)
      return
    }

    foreach (item in showModeList)
      item.selected <- item.diffCode == curDiffCode
    local view = {
      id = "show_mode"
      optionTag = "option"
      cb = "onChangeShowMode"
      options= showModeList
    }
    local data = ::handyman.renderCached("gui/options/spinnerOptions", view)
    guiScene.replaceContentFromText(obj, data, data.len(), this)
    updateShowModeTooltip(obj)
  }

  function updateShowModeTooltip(obj)
  {
    if (!::checkObj(obj))
      return
    local isAuto = curDiffCode == -1
    local adviceText = ::loc(isAuto ? "mainmenu/showModesInfo/advice" : "mainmenu/showModesInfo/warning", { automatic = ::loc("options/auto") })
    adviceText = ::colorize(isAuto ? "goodTextColor" : "warningTextColor", adviceText)
    obj["tooltip"] = ::loc("mainmenu/showModesInfo/tooltip") + "\n" + adviceText
  }

  _isShowModeInChange = false
  function onChangeShowMode(obj)
  {
    if (_isShowModeInChange)
      return
    if (!::checkObj(obj))
      return

    local value = obj.getValue()
    local item = ::getTblValue(value, showModeList)
    if (!item)
      return

    _isShowModeInChange = true
    local prevEdiff = getCurrentEdiff()
    curDiffCode = item.diffCode
    ::save_local_account_settings("shopShowMode", curDiffCode)

    foreach(tgtNavBar in [navBarObj, navBarGroupObj])
    {
      if (!::check_obj(tgtNavBar))
        continue

      local listObj = tgtNavBar.findObject("show_mode")
      if (!::check_obj(listObj))
        continue

      if (listObj.getValue() != value)
        listObj.setValue(value)
      updateShowModeTooltip(listObj)
    }

    if (prevEdiff != getCurrentEdiff())
    {
      updateSlotbarDifficulty()
      updateTreeDifficulty()
      fillGroupObj()
    }
    _isShowModeInChange = false
  }

  function getCurrentEdiff()
  {
    return curDiffCode == -1 ? ::get_current_ediff() : curDiffCode
  }

  function updateSlotbarDifficulty()
  {

    local slotbar = topMenuHandler.value?.getSlotbar()
    if (slotbar)
      slotbar.updateDifficulty()
  }

  function updateTreeDifficulty()
  {
    if (!::has_feature("GlobalShowBattleRating"))
      return
    local curEdiff = getCurrentEdiff()
    local tree = getCurTreeData().tree
    foreach(row in tree)
      foreach(unit in row)
      {
        local unitObj = unit ? getUnitCellObj(unit.name) : null
        if (::checkObj(unitObj))
        {
          local obj = unitObj.findObject("rank_text")
          if (::checkObj(obj))
            obj.setValue(::get_unit_rank_text(unit, null, true, curEdiff))
        }
      }
  }

  function restoreFocus(checkPrimaryFocus = true)
  {
    if (isSceneActive() && !checkGroupObj())
      topMenuHandler.value?.restoreFocus.call(topMenuHandler.value, checkPrimaryFocus)
  }

  function onEventClosedUnitItemMenu(params)
  {
    if (!checkGroupObj())
      restoreFocus()
  }

  function checkGroupObj()
  {
    if (::checkObj(groupChooseObj))
    {
      local tableObj = groupChooseObj.findObject("airs_table")
      if (::checkObj(tableObj))
      {
        tableObj.select()
        return true
      }
    }
    return false
  }

  function onWrapUp(obj)
  {
    topMenuHandler.value?.onWrapUp.call(topMenuHandler.value, obj)
  }

  function onWrapDown(obj)
  {
    topMenuHandler.value?.onWrapDown.call(topMenuHandler.value, obj)
  }

  function onShopShow(show)
  {
    onSceneActivate(show)
    if (!show && ::checkObj(groupChooseObj))
      destroyGroupChoose()
    if (show)
      popDelayedActions()
  }

  function onEventShopWndAnimation(p)
  {
    if (::getTblValue("isVisible", p, false))
    {
      shouldBlurSceneBg = ::getTblValue("isShow", p, false)
      ::handlersManager.updateSceneBgBlur()
    }
  }

  function onEventCurrentGameModeIdChanged(params)
  {
    if (curDiffCode != -1)
      return

    doWhenActiveOnce("updateTreeDifficulty")
  }

  function onEventXboxSystemUIReturn(p)
  {
    restoreFocus()
  }

  function onUnitSelect() {}
  function selectRequiredUnit() {}
  function onSpendExcessExp() {}
  function updateResearchVariables() {}

  static fakeUnitConfig = {
    name = ""
    image = "!#ui/unitskin#random_unit"
    rank = 1
    isFakeUnit = true
  }
  function genFakeUnitRanges(airBlk, country)
  {
    local ranges = []
    local fakeReqUnitsType = airBlk % "fakeReqUnitType"
    local fakeReqUnitsImage = airBlk % "fakeReqUnitImage"
    local fakeReqUnitsRank = airBlk % "fakeReqUnitRank"
    local fakeReqUnitsPosXY = airBlk % "fakeReqUnitPosXY"
    foreach(idx, unitType in fakeReqUnitsType)
    {
      local range = []
      local fakeUnitParams = fakeUnitConfig.__merge({
        name = unitType
        image = fakeReqUnitsImage?[idx] ?? "!#ui/unitskin#random_unit"
        rank = fakeReqUnitsRank?[idx] ?? 2
        country = country
      })
      if (fakeReqUnitsPosXY?[idx])
        fakeUnitParams.rankPosXY <-fakeReqUnitsPosXY[idx]
      for(local i = 0; i < COUNT_REQ_FOR_FAKE_UNIT; i++)
      {
        local reqForFakeUnitParams = fakeUnitConfig.__merge({
          name = fakeUnitParams.name + "_" + i
          image = fakeUnitParams.image
          rank = fakeUnitParams.rank - 1
          country = country
          isReqForFakeUnit = true })
        local rankPosXY = fakeUnitParams?.rankPosXY
        if (rankPosXY)
          reqForFakeUnitParams.rankPosXY <- Point2(rankPosXY.x + (rankPosXY.x < 3 ? -i : i), 1)

        range.append(reqForFakeUnitParams)
      }
      fakeUnitParams.fakeReqUnits <- range.map(@(fakeReqUnit) fakeReqUnit.name)
      range.append(fakeUnitParams)
      ranges.append(range)
    }
    return ranges
  }

  function onEventClanChanged(params)
  {
    doWhenActiveOnce("fillAircraftsList")
  }

  function onEventSquadronExpChanged(params)
  {
    checkUnitItemAndUpdate(::getAircraftByName(::clan_get_researching_unit()))
  }

  function onEventFlushSquadronExp(params)
  {
    fillAircraftsList(params?.unit?.name)
  }

  getResearchingSquadronVehicle = function()
  {
    if (::clan_get_exp() <= 0)
      return null

    local unit = ::getAircraftByName(::clan_get_researching_unit())
    if(!unit)
      return null

    if (unit.shopCountry != curCountry || unit.unitType != lastUnitType)
      return null

    return unit
  }

  getParamsForActionsList = @() {
    setResearchManually = setResearchManually
    shopResearchMode = shopResearchMode
    onSpendExcessExp = ::Callback(onSpendExcessExp, this)
    onCloseShop = ::Callback(onCloseShop, this)
  }

  checkAirShopReq = @(air) air?.shopReq ?? true
}
