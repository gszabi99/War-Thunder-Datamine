let { format, split_by_chars } = require("string")
let shopTree = require("%scripts/shop/shopTree.nut")
let shopSearchBox = require("%scripts/shop/shopSearchBox.nut")
let slotActions = require("%scripts/slotbar/slotActions.nut")
let unitActions = require("%scripts/unit/unitActions.nut")
let { topMenuHandler, topMenuShopActive } = require("%scripts/mainmenu/topMenuStates.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { getStatusTbl, getTimedStatusTbl, updateCellStatus, updateCellTimedStatus, initCell
} = require("shopUnitCellFill.nut")
let unitContextMenuState = require("%scripts/unit/unitContextMenuState.nut")
let { hideWaitIcon } = require("%scripts/utils/delayedTooltip.nut")
let { findChildIndex } = require("%sqDagui/daguiUtil.nut")
let { isSmallScreen } = require("%scripts/clientState/touchScreen.nut")
let getShopBlkData = require("%scripts/shop/getShopBlkData.nut")
let { hasMarkerByUnitName, getUnlockIdByUnitName,
  getUnlockIdsByArmyId } = require("%scripts/unlocks/unlockMarkers.nut")
let { getShopDiffMode, storeShopDiffMode, isAutoDiff, getShopDiffCode
} = require("%scripts/shop/shopDifficulty.nut")
let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let seenList = require("%scripts/seen/seenList.nut").get(SEEN.UNLOCK_MARKERS)
let { buildDateStr } = require("%scripts/time.nut")

local lastUnitType = null

const OPEN_RCLICK_UNIT_MENU_AFTER_SELECT_TIME = 500 // when select slot by right click button
                                                    // then menu vehilce opened and close

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

::gui_handlers.ShopMenuHandler <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/shop/shopInclude.blk"
  sceneNavBlkName = "%gui/shop/shopNav.blk"
  shouldBlurSceneBg = false
  needVoiceChat = false
  keepLoaded = true
  boughtVehiclesCount = null
  totalVehiclesCount = null

  closeShop = null //function to hide close shop
  forceUnitType = null //unitType to set on next pages fill

  curCountry = null
  curPage = ""
  curUnitsList = null
  curAirName = ""
  curPageGroups = null
  groupChooseObj = null
  skipOpenGroup = true
  repairAllCost = 0
  availableFlushExp = 0
  brokenList = null
  _timer = 0.0

  shopData = null
  slotbarActions = [
    "research", "find_in_market", "buy", "take", "sec_weapons", "weapons",
    "showroom", "testflight", "crew", "goto_unlock", "info", "repair"
  ]
  needUpdateSlotbar = false
  needUpdateSquadInfo = false
  shopResearchMode = false
  setResearchManually = true
  lastPurchase = null

  showModeList = null

  navBarObj = null
  navBarGroupObj = null

  searchBoxWeak = null
  selCellOnSearchQuit = null

  unitActionsListTimer = null
  hasSpendExpProcess = false
  actionsListOpenTime = 0

  function initScreen()
  {
    if (!curAirName.len())
    {
      curCountry = ::get_profile_country_sq()
      let unit = ::getAircraftByName(::hangar_get_current_unit_name())
      if (unit && unit.shopCountry == curCountry)
        curAirName = unit.name
    }

    skipOpenGroup = true
    scene.findObject("shop_timer").setUserData(this)
    brokenList = []
    curUnitsList = []

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

  function loadFullAircraftsTable(selAirName = "")
  {
    let shopBlkData = getShopBlkData(selAirName)
    shopData = shopBlkData.shopData
    curCountry = shopBlkData.curCountry ?? curCountry
    curPage = shopBlkData.curPage ?? curPage
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
          let treeData = shopTree.generateTreeData(pageData)
          foreach(rowArr in treeData.tree)
            for(local col = 0; col < rowArr.len(); col++)
              if (rowArr[col])
              {
                let air = rowArr[col]
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
    let res = {
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
        let isOwn = ::isUnitBought(air)
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

  function initUnitCells(tableObj, cellsList) {
    local count = tableObj.childrenCount()
    let needCount = cellsList.len()
    if (needCount > count)
      guiScene.createMultiElementsByObject(tableObj, "%gui/shop/shopUnitCell.blk", "unitCell", needCount - count, this)

    count = max(count, needCount)
    if (count != tableObj.childrenCount())
      return //prevent crash on error, but anyway we will get assert in such case on update

    for(local i = 0; i < count; i++) {
      let cellObj = tableObj.getChild(i)
      if (i not in cellsList) {
        cellObj.show(false)
        cellObj.enable(false)
      }
      else
        initCell(cellObj, cellsList[i])
    }
  }

  function onUnitMarkerClick(obj) {
    let unitName = obj.holderId
    ::gui_start_profile({
      initialSheet = "UnlockAchievement"
      curUnlockId = getUnlockIdByUnitName(unitName, getCurrentEdiff())
    })
  }

  function updateUnitCell(cellObj, unit) {
    let params = getUnitItemParams(unit)
    updateCellStatus(cellObj, getStatusTbl(unit, params))
    updateCellTimedStatus(cellObj, @() getTimedStatusTbl(unit, params))
  }

  function updateCurUnitsList() {
    let tableObj = scene.findObject("shop_items_list")
    let total = tableObj.childrenCount()
    foreach(idx, unit in curUnitsList)
      if (idx < total)
        updateUnitCell(tableObj.getChild(idx), unit)
      else
        ::script_net_assert_once("shop early update", "Try to update shop units before init")
  }

  function fillAircraftsList(curName = "")
  {
    if (!::checkObj(scene))
      return
    let tableObj = scene.findObject("shop_items_list")
    if (!::checkObj(tableObj))
      return

    updateBoughtVehiclesCount()
    lastUnitType = getCurPageUnitType()

    if (curName=="")
      curName = getResearchingSquadronVehicle()?.name ?? curAirName

    let treeData = getCurTreeData()
    brokenList = []

    fillBGLines(treeData)
    guiScene.setUpdatesEnabled(false, false);

    let cellsList = []
    local maxCols = -1
    foreach(row, rowArr in treeData.tree)
      for(local col = 0; col < rowArr.len(); col++)
        if (rowArr[col]) {
          maxCols = max(maxCols, col)
          let unitOrGroup = rowArr[col]
          cellsList.append({ unitOrGroup, id = unitOrGroup.name, posX = col, posY = row, position = "absolute" })
        }

    tableObj.size = $"{maxCols+1}@shop_width, {treeData.tree.len()}@shop_height"
    tableObj.isShopItemsWide = ::to_pixels("@is_shop_items_wide")
    initUnitCells(tableObj, cellsList)
    curUnitsList = cellsList.map(@(c) c.unitOrGroup)
    updateCurUnitsList()

    local curIdx = -1
    foreach(idx, unit in curUnitsList) {
      let config = getItemStatusData(unit, curName)
      if (config.checkAir || ((curIdx < 0) && !unit?.isFakeUnit))
        curIdx = idx
      if (config.broken)
        brokenList.append(unit) //fix me: we can update it together with update units instead of fill all
    }

    guiScene.setUpdatesEnabled(true, true)
    tableObj.setValue(curIdx)

    updateButtons()

    ::broadcastEvent("ShopUnitTypeSwitched", { esUnitType = getCurPageEsUnitType() })
  }

  function onEventDiscountsDataUpdated(params = {})
  {
    updateDiscountIconsOnTabs()
    updateCurUnitsList()
  }

  function onEventUnlockMarkersCacheInvalidate(params = {}) {
    updateCurUnitsList()
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

    let show = brokenList.len() > 0 && repairAllCost > 0
    showNavButton("btn_repairall", show)
    if (!show)
      return

    let locText = ::loc("mainmenu/btnRepairAll")
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

      let unit = brokenList[i]
      if (checkBrokenListStatus(unit))
        checkUnitItemAndUpdate(unit)
    }
  }

  function getLineStatus(lc)
  {
    let config = getItemStatusData(lc.air)
    let configReq = getItemStatusData(lc.reqAir)

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

  function createLine(r0, c0, r1, c1, status, lineConfig = {})
  {
    let { air = null, reqAir = null, arrowCount = 1, hasNextFutureReqLine = false } = lineConfig
    let isFutureReqAir = air?.futureReqAir != null && air.futureReqAir == reqAir?.name
    let isFakeUnitReq = reqAir?.isFakeUnit
    let isMultipleArrow = arrowCount > 1
    let isLineParallelFutureReqLine = isMultipleArrow
      && !isFutureReqAir && air?.futureReqAir != null
    let isLineShiftedToRight = hasNextFutureReqLine

    local lines = ""
    let arrowProps = $"shopStat:t='{status}'; isOutlineIcon:t={isFutureReqAir ? "yes" : "no"};"
    let arrowFormat = "".concat("shopArrow { type:t='%s'; size:t='%s, %s';",
      "pos:t='%s, %s'; rotation:t='%s';", arrowProps, " } ")
    let lineFormat = "".concat("shopLine { size:t='%s, %s'; pos:t='%s, %s'; rotation:t='%s';",
      arrowProps, " } ")
    let angleFormat = "".concat("shopAngle { size:t='%s, %s'; pos:t='%s, %s'; rotation:t='%s';",
      arrowProps, " } ")
    local alarmTooltip = ""
    if (isFutureReqAir) {
      let endReleaseDate = reqAir.getEndRecentlyReleasedTime()
      if (endReleaseDate > 0) {
        let hasReqAir = (air?.reqAir ?? "") != ""
        let locId = hasReqAir ? "shop/futureReqAir/desc" : "shop/futureReqAir/desc/withoutReqAir"
        alarmTooltip = ::g_string.stripTags(::loc(locId, {
          futureReqAir = getUnitName(air.futureReqAir)
          curAir = getUnitName(air)
          reqAir = hasReqAir ? getUnitName(air.reqAir) : ""
          date = buildDateStr(endReleaseDate)
        }))
      }
    }
    let alarmIconFormat = "".concat("shopAlarmIcon { pos:t='%s, %s'; tooltip:t='",
      alarmTooltip, "'; } ")
    let pad1 = "1@lines_pad"
    let pad2 = "1@lines_pad"
    let interval1 = "1@lines_shop_interval"
    let interval2 = "1@lines_shop_interval"

    if (c0 == c1)
    {//vertical
      let offset = isLineParallelFutureReqLine ? -0.1
        : isLineShiftedToRight ? 0.1
        : 0
      let posX = $"{(c0 + 0.5 + offset)}@shop_width - 0.5@modArrowWidth"
      let height = $"{pad1} + {pad2} + {(r1 - r0 - 1)}@shop_height"
      let posY = $"{(r0 + 1)}@shop_height - {pad1}"
      lines += format(arrowFormat, "vertical", "1@modArrowWidth", height,
        posX, posY, "0")

      if (isFutureReqAir)
        lines = "".concat(lines,
          format(alarmIconFormat, $"{posX} + 0.5@modArrowWidth - 0.5w",
           $"{posY} + 0.5*({height}) - 0.5h"))
    }
    else if (r0==r1)
    {//horizontal
      let offset = isLineParallelFutureReqLine ? -0.1
        : isLineShiftedToRight ? 0.1
        : 0
      let posX = $"{(c0 + 1)}@shop_width - {interval1}"
      let width = $"{(c1 - c0 - 1)}@shop_width + {interval1} + {interval2}"
      let posY = $"{(r0 + 0.5 + offset)}@shop_height - 0.5@modArrowWidth"
      lines += format(arrowFormat, "horizontal", width, "1@modArrowWidth",
        posX, posY, "0")

      if (isFutureReqAir)
        lines = "".concat(lines,
          format(alarmIconFormat, $"{posX} + 0.5*({width}) - 0.5w",
           $"{posY} + 0.5@modArrowWidth - 0.5h"))
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
      let lh = 0
      let offset = isMultipleArrow ? 0.1 : 0
      let arrowOffset = c0 > c1 ? -offset : offset

      lines += format(lineFormat,
                       pad1 + " + " + lh + "@shop_height",//height
                       "1@modLineWidth", //width
                       (c0 + 0.5 + arrowOffset) + "@shop_width" + ((c0 > c1) ? "-" : "+") + " 0.5@modLineWidth", //posX
                       (r0 + 1) + "@shop_height - " + pad1 + ((c0 > c1) ? "+ w " : ""), // posY
                       (c0 > c1) ? "-90" : "90")

      lines += format(lineFormat,
                      (::abs(c1-c0) - offset) + "@shop_width",
                      "1@modLineWidth", //height
                      (min(c0, c1) + 0.5 + (c0 > c1 ? 0 : offset)) + "@shop_width",
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

    let contentWidth = scene.findObject("shopTable_air_rows").getSize()[0]
    let containerWidth = scene.findObject("shop_useful_width").getSize()[0]
    let pos = (contentWidth >= containerWidth)? "0" : "(pw-w)/2"
    scene.findObject("shop_items_pos_div").left = pos
  }

  function generateAirAddictiveArrows(treeData)
  {
    let tblBgObj = scene.findObject("shopTable_air_rows")
    local data = ""
    foreach(lc in treeData.lines)
    {
      fillAirReq(lc.air, lc.reqAir)
      data += createLine(lc.line[0], lc.line[1], lc.line[2], lc.line[3], getLineStatus(lc), lc)
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
    let obj = scene.findObject("tree_header_div")
    let view = {
      plates = [],
      separators = [],
    }

    let sectionsTotal = treeData.sectionsPos.len() - 1
    let widthStr = isSmallScreen
      ? "1@maxWindowWidth -1@modBlockTierNumHeight -1@scrollBarSize"
      : "1@slotbarWidthFull -1@modBlockTierNumHeight -1@scrollBarSize"
    let totalWidth = guiScene.calcString(widthStr, null)
    let itemWidth = guiScene.calcString("@shop_width", null)

    let extraWidth = "+" + max(0, totalWidth - (itemWidth * treeData.sectionsPos[sectionsTotal])) / 2
    let extraLeft = extraWidth + "+1@modBlockTierNumHeight"
    let extraRight = extraWidth + "+1@scrollBarSize - 2@frameHeaderPad"

    for (local s = 0; s < sectionsTotal; s++)
    {
      let isLeft = s == 0
      let isRight = s == sectionsTotal - 1

      let x = treeData.sectionsPos[s] + "@shop_width" + (isLeft ? "" : extraLeft)
      let w = (treeData.sectionsPos[s + 1] - treeData.sectionsPos[s]) + "@shop_width" + (isLeft ? extraLeft : "") + (isRight ? extraRight : "")

      let isResearchable = ::getTblValue(s, treeData.sectionsResearchable)
      let title = isResearchable ? "#shop/section/researchable" : "#shop/section/premium"

      view.plates.append({ title = title, x = x, w = w })
      if (!isLeft)
        view.separators.append({ x = x })
    }

    let data = ::handyman.renderCached("%gui/shop/treeHeadPlates", view)
    guiScene.replaceContentFromText(obj, data, data.len(), this)
  }

  function generateBGPlates(treeData)
  {
    let tblBgObj = scene.findObject("shopTable_air_plates")
    let view = {
      plates = [],
      vertSeparators = [],
      horSeparators = [],
    }

    local tiersTotal = treeData.ranksHeight.len() - 1
    for(local i = tiersTotal - 1; i >= 0; i--)
    {
      if (treeData.ranksHeight[i] != treeData.ranksHeight[tiersTotal])
        break
      tiersTotal = i
    }

    let sectionsTotal = treeData.sectionsPos.len() - 1

    let widthStr = isSmallScreen
      ? "1@maxWindowWidth -1@modBlockTierNumHeight -1@scrollBarSize"
      : "1@slotbarWidthFull -1@modBlockTierNumHeight -1@scrollBarSize"
    let totalWidth = guiScene.calcString(widthStr, null)
    let itemWidth = guiScene.calcString("@shop_width", null)

    let extraRight = "+" + max(0, totalWidth - (itemWidth * treeData.sectionsPos[sectionsTotal])) / 2
    let extraLeft = extraRight + "+1@modBlockTierNumHeight"
    let extraTop = "+1@shop_h_extra_first"
    let extraBottom = "+1@shop_h_extra_last"

    for(local i = 0; i < tiersTotal; i++)
    {
      let tierNum = (i+1).tostring()
      let tierUnlocked = ::is_era_available(curCountry, i + 1, getCurPageEsUnitType())
      let fakeRowsCount = treeData.fakeRanksRowsCount[i + 1]

      let pY = treeData.ranksHeight[i] + fakeRowsCount
      let pH = treeData.ranksHeight[i + 1] - pY

      let isTop = pY == 0
      let isBottom = i == tiersTotal - 1

      for(local s = 0; s < sectionsTotal; s++)
      {
        let isLeft = s == 0
        let isRight = s == sectionsTotal - 1
        let isResearchable = ::getTblValue(s, treeData.sectionsResearchable)
        let tierType = tierUnlocked || !isResearchable ? "unlocked" : "locked"

        let pX = treeData.sectionsPos[s]
        let pW = treeData.sectionsPos[s + 1] - pX

        let x = "".concat($"{pX}@shop_width", isLeft ? "" : extraLeft)
        let y = "".concat($"{pY}@shop_height", isTop ? "" : extraTop)
        let w = "".concat($"{pW}@shop_width", isLeft ? extraLeft : "", isRight ? extraRight : "")
        let h = "".concat($"{pH}@shop_height", isTop ? extraTop : "", isBottom ? extraBottom : "")

        if (fakeRowsCount > 0)
        {
          let fakePY = treeData.ranksHeight[i]
          let isFakeTop = fakePY == 0
          let fakeRowY = "".concat($"{fakePY}@shop_height", isFakeTop ? "" : extraTop)
          let fakeRowH = "".concat($"{fakeRowsCount}@shop_height", isFakeTop ? extraTop : "", isBottom ? extraBottom : "")

          view.plates.append({ tierNum = tierNum, tierType = "unlocked", x = x, y = fakeRowY, w = w, h = fakeRowH })
          if (!isLeft)
            view.vertSeparators.append({ x = x, y = fakeRowY, h = fakeRowH, isTop = isFakeTop, isBottom = isBottom })
        }

        if (pH == 0)
          continue

        view.plates.append({ tierNum = tierNum, tierType = tierType, x = x, y = y, w = w, h = h })
        if (!isLeft)
          view.vertSeparators.append({ x = x, y = y, h = h, isTop = isTop, isBottom = isBottom })
        if (!isTop)
          view.horSeparators.append({ x = x, y = y, w = w, isLeft = isLeft })
      }
    }

    local data = ::handyman.renderCached("%gui/shop/treeBgPlates", view)
    guiScene.replaceContentFromText(tblBgObj, data, data.len(), this)
  }

  function getRankProgressTexts(rank, ranksBlk, isTreeReserchable)
  {
    if (!ranksBlk)
      ranksBlk = ::get_ranks_blk()

    let isEraAvailable = !isTreeReserchable || ::is_era_available(curCountry, rank, getCurPageEsUnitType())
    local tooltipPlate = ""
    local tooltipRank = ""
    local tooltipReqCounter = ""
    local reqCounter = ""

    if (isEraAvailable)
    {
      let unitsCount = boughtVehiclesCount[rank]
      let unitsTotal = totalVehiclesCount[rank]
      tooltipRank = ::loc("shop/age/tooltip") + ::loc("ui/colon") + ::colorize("userlogColoredText", ::get_roman_numeral(rank))
        + "\n" + ::loc("shop/tier/unitsBought") + ::loc("ui/colon") + ::colorize("userlogColoredText", format("%d/%d", unitsCount, unitsTotal))
    }
    else
    {
      let unitType = getCurPageEsUnitType()
      for (local prevRank = rank - 1; prevRank > 0; prevRank--)
      {
        let unitsCount = boughtVehiclesCount[prevRank]
        let unitsNeed = ::getUnitsNeedBuyToOpenNextInEra(curCountry, unitType, prevRank, ranksBlk)
        let unitsLeft = max(0, unitsNeed - unitsCount)

        if (unitsLeft > 0)
        {
          let txtThisRank = ::colorize("userlogColoredText", ::get_roman_numeral(rank))
          let txtPrevRank = ::colorize("userlogColoredText", ::get_roman_numeral(prevRank))
          let txtUnitsNeed = ::colorize("badTextColor", unitsNeed)
          let txtUnitsLeft = ::colorize("badTextColor", unitsLeft)
          let txtCounter = format("%d/%d", unitsCount, unitsNeed)
          let txtCounterColored = ::colorize("badTextColor", txtCounter)

          let txtRankIsLocked = ::loc("shop/unlockTier/locked", { rank = txtThisRank })
          let txtNeedUnits = ::loc("shop/unlockTier/reqBoughtUnitsPrevRank", { prevRank = txtPrevRank, amount = txtUnitsLeft })
          let txtRankLockedDesc = ::loc("shop/unlockTier/desc", { rank = txtThisRank, prevRank = txtPrevRank, amount = txtUnitsNeed })
          let txtRankProgress = ::loc("shop/unlockTier/progress", { rank = txtThisRank }) + ::loc("ui/colon") + txtCounterColored

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
    let blk = ::get_ranks_blk()
    let pageUnitsType = getCurPageEsUnitType()

    let isTreeReserchable = treeData.sectionsResearchable.contains(true)

    for(local i = 1; i <= ::max_country_rank; i++)
    {
      let curEraPos = treeData.ranksHeight[i]
      let prevEraPos = treeData.ranksHeight[i-1]
      let curFakeRowRankCount = treeData.fakeRanksRowsCount[i]

      if (curEraPos == prevEraPos || ((curEraPos - curFakeRowRankCount) == prevEraPos ))
        continue

      let prevFakeRowRankCount = treeData.fakeRanksRowsCount[i-1]
      let drawArrow = i > 1 && prevEraPos != (treeData.ranksHeight[i-2] + prevFakeRowRankCount)
      let isRankAvailable = !isTreeReserchable || ::is_era_available(curCountry, i, pageUnitsType)
      let status =  isRankAvailable ?  "owned" : "locked"

      let texts = getRankProgressTexts(i, blk, isTreeReserchable)

      local arrowData = ""
      if (drawArrow)
      {
        arrowData = format("shopArrow { type:t='vertical'; size:t='1@modArrowWidth, %s@shop_height - 1@modBlockTierNumHeight';" +
                      "pos:t='0.5pw - 0.5w, %s@shop_height + 0.5@modBlockTierNumHeight';" +
                      "shopStat:t='%s'; modArrowPlate{ text:t='%s'; tooltip:t='%s'}}",
                    (treeData.ranksHeight[i-1] - treeData.ranksHeight[i-2] - prevFakeRowRankCount).tostring(),
                    (treeData.ranksHeight[i-2] + prevFakeRowRankCount).tostring(),
                    status,
                    texts.reqCounter,
                    ::g_string.stripTags(texts.tooltipReqCounter)
                    )
      }
      let modBlockFormat = "modBlockTierNum { class:t='vehicleRanks' status:t='%s'; pos:t='0, %s@shop_height - 0.5h'; text:t='%s'; tooltip:t='%s'}"

      if (curFakeRowRankCount > 0)
        data += format(modBlockFormat,
                  "owner",
                  prevEraPos.tostring(),
                  "",
                  "")

      data += format(modBlockFormat,
                  status,
                  (prevEraPos + curFakeRowRankCount).tostring(),
                  ::loc("shop/age/num", { num = ::get_roman_numeral(i) }),
                  ::g_string.stripTags(texts.tooltipRank))

      data += arrowData

      let tierObj = scene.findObject("shop_tier_" + i.tostring())
      if (::checkObj(tierObj))
        tierObj.tooltip = texts.tooltipPlate
    }

    let height = treeData.ranksHeight[treeData.ranksHeight.len()-1] + "@shop_height"
    let tierObj = scene.findObject("tier_arrows_div")
    tierObj.height = height
    guiScene.replaceContentFromText(tierObj, data, data.len(), this)

    scene.findObject("shop_items_scroll_div").height = height + " + 1@shop_h_extra_first + 1@shop_h_extra_last"
  }

  function updateBoughtVehiclesCount()
  {
    let bought = array(::max_country_rank + 1, 0)
    let total = array(::max_country_rank + 1, 0)
    let pageUnitsType = getCurPageEsUnitType()

    foreach(unit in ::all_units)
      if (unit.shopCountry == curCountry && pageUnitsType == ::get_es_unit_type(unit))
      {
        let isOwn = ::isUnitBought(unit)
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
      unitTypes.getByName(unit?.isReqForFakeUnit ? split_by_chars(unit.name, "_")?[0] : unit.name,
        false).esUnitType,
      unit.country, true)
      >= (((split_by_chars(unit.name, "_"))?[1] ?? "0").tointeger() + 1)
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
    let airObj = findUnitInGroupTableById(unitName)
    if (::checkObj(airObj))
      return airObj

    return findAirTableObjById(unitName)
  }

  function getUnitCellObj(unitName)
  {
    let cellObj = findUnitInGroupTableById($"unitCell_{unitName}")
    if (::checkObj(cellObj))
      return cellObj

    return findAirTableObjById($"unitCell_{unitName}")
  }

  function getCellObjByValue(value) {
    let tableObj = scene.findObject("shop_items_list")
    return value < tableObj.childrenCount() ? tableObj.getChild(value) : null
  }

  function checkUnitItemAndUpdate(unit)
  {
    if (!unit || unit?.isFakeUnit)
      return

    let unitObj = getUnitCellObj(unit.name)
    if ((unitObj?.isValid() ?? false) && unitObj.isVisible()) //need update only visible cell
      updateUnitItem(unit, unitObj)

    ::updateAirAfterSwitchMod(unit)

    if (!::isUnitGroup(unit) && ::isGroupPart(unit))
      updateGroupItem(unit.group)
  }

  function updateUnitItem(unit, cellObj)
  {
    if (cellObj?.isValid())
      updateUnitCell(cellObj, unit)
  }

  function updateGroupItem(groupName)
  {
    let block = getItemBlockFromShopTree(groupName)
    if (!block)
      return

    updateUnitItem(block, findCloneGroupObjById(groupName))
    updateUnitItem(block, findAirTableObjById($"unitCell_{groupName}"))
  }

  function checkBrokenListStatus(unit)
  {
    if (!unit)
      return false

    let posNum = ::find_in_array(brokenList, unit)
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

    let is_unit = !::isUnitGroup(unit) && !unit?.isFakeUnit
    let params = {
      availableFlushExp = availableFlushExp
      setResearchManually = setResearchManually
    }
    let mainActionLocId = is_unit ? slotActions.getSlotActionFunctionName(unit, params) : ""
    return {
      mainActionText = mainActionLocId != "" ? ::loc(mainActionLocId) : ""
      shopResearchMode = shopResearchMode
      forceNotInResearch = !setResearchManually
      flushExp = availableFlushExp
      showBR = ::has_feature("GlobalShowBattleRating")
      getEdiffFunc = getCurrentEdiff.bindenv(this)
      tooltipParams = { needShopInfo = true }
    }
  }

  function findUnitInTree(isFits) {
    let tree = getCurTreeData().tree
    local idx = -1
    foreach(row, rowArr in tree)
      foreach(col, unit in rowArr)
        if (unit != null && isFits(unit, ++idx))
          return { unit = unit, row = row, col = col, idx = idx }
    return { unit = null, row = -1, col = -1, idx = -1 }
  }

  getUnitByIdx = @(curIdx) findUnitInTree(@(unit, idx) idx == curIdx)

  function getCurAircraft(checkGroups = true, returnDefaultUnitForGroups = false)
  {
    if (!checkObj(scene))
      return null

    local tableObj = scene.findObject("shop_items_list")
    let curIdx = tableObj.getValue()
    if (curIdx < 0)
      return null
    let mainTblUnit = getUnitByIdx(curIdx).unit
    if (!::isUnitGroup(mainTblUnit))
      return mainTblUnit

    if (checkGroups && ::checkObj(groupChooseObj))
    {
      tableObj = groupChooseObj.findObject("airs_table")
      let idx = tableObj.getValue()
      if (idx in mainTblUnit.airsGroup)
        return mainTblUnit.airsGroup[idx]
    }

    if (returnDefaultUnitForGroups)
      return getDefaultUnitInGroup(mainTblUnit)

    return mainTblUnit
  }

  function getDefaultUnitInGroup(unitGroup)
  {
    let airsList = ::getTblValue("airsGroup", unitGroup)
    return ::getTblValue(0, airsList)
  }

  function getItemBlockFromShopTree(itemName)
  {
    let tree = getCurTreeData().tree
    for(local i = 0; i < tree.len(); ++i)
      for(local j = 0; j < tree[i].len(); ++j)
      {
        let name = ::getTblValue("name", tree[i][j])
        if (!name)
          continue

        if (itemName == name)
          return tree[i][j]
      }

    return null
  }

  function onAircraftsPage()
  {
    let pagesObj = scene.findObject("shop_pages_list")
    if (pagesObj)
    {
      let pageIdx = pagesObj.getValue()
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

    let pagesObj = scene.findObject("shop_pages_list")
    if (!::checkObj(pagesObj))
      return

    let unitType = forceUnitType
      ?? lastUnitType
      ?? ::getAircraftByName(curAirName)?.unitType
      ?? unitTypes.INVALID

    forceUnitType = null //forceUnitType applyied only once

    local data = ""
    local curIdx = 0
    let countryData = ::u.search(shopData, (@(curCountry) function(country) { return country.name == curCountry})(curCountry))
    if (countryData)
    {
      let ediff = getCurrentEdiff()
      let view = { tabs = [] }
      foreach(idx, page in countryData.pages)
      {
        let name = page.name
        view.tabs.append({
          id = name
          tabName = "#mainmenu/" + name
          discount = {
            discountId = getDiscountIconTabId(countryData.name, name)
          }
          squadronExpIconId = curCountry + ";" + name
          seenIconCfg = bhvUnseen.makeConfigStr(seenList.id,
            getUnlockIdsByArmyId(curCountry, name, ediff))
          navImagesText = ::get_navigation_images_text(idx, countryData.pages.len())
          remainingTimeUnitPageMarker = true
          countryId = countryData.name
          armyId = name
        })

        if (name == unitType.armyId)
          curIdx = view.tabs.len() - 1
      }

      let tabCount = view.tabs.len()
      foreach(idx, tab in view.tabs)
        tab.navImagesText = ::get_navigation_images_text(idx, tabCount)

      data = ::handyman.renderCached("%gui/frameHeaderTabs", view)
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
    let pagesObj = scene.findObject("shop_pages_list")
    if (!::checkObj(pagesObj))
      return

    foreach(country in shopData)
    {
      if (country.name != curCountry)
        continue

      foreach(idx, page in country.pages)
      {
        let tabObj = pagesObj.findObject(page.name)
        if (!::checkObj(tabObj))
          continue

        let discountObj = tabObj.findObject(getDiscountIconTabId(curCountry, page.name))
        if (!::checkObj(discountObj))
          continue

        let discountData = getDiscountByCountryAndArmyId(curCountry, page.name)

        let maxDiscount = discountData?.maxDiscount ?? 0
        let discountTooltip = ::getTblValue("discountTooltip", discountData, "")
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

    let unitType = unitTypes.getByArmyId(armyId)
    let discountsList = {}
    foreach(unit in ::all_units)
      if (unit.unitType == unitType
          && unit.shopCountry == country)
      {
        let discount = ::g_discount.getUnitDiscount(unit)
        if (discount > 0)
          discountsList[unit.name + "_shop"] <- discount
      }

    return ::g_discount.generateDiscountInfo(discountsList)
  }

  function initSearchBox()
  {
    if (shopResearchMode || !::has_feature("UnitsSearchBoxInShop"))
      return
    let handler = shopSearchBox.init({
      scene = scene.findObject("shop_search_box")
      curCountry = curCountry
      curEsUnitType = getCurPageEsUnitType()
      cbOwnerSearchHighlight = ::Callback(searchHighlight, this)
      cbOwnerSearchCancel    = ::Callback(searchCancel,    this)
      cbOwnerShowUnit        = ::Callback(showUnitInShop,  this)
      cbOwnerClose           = ::Callback(onCloseShop, this)
      getEdiffFunc           = ::Callback(getCurrentEdiff, this)
    })
    registerSubHandler(handler)
    searchBoxWeak = handler.weakref()
  }

  function searchHighlight(units, isClear)
  {
    if (isClear)
      return highlightUnitsClear()
    let slots = highlightUnitsInTree(units.map(@(unit) unit.name))
    let tableObj = scene.findObject("shop_items_list")
    if (!::check_obj(tableObj))
      return
    foreach (value in [ slots.valueLast, slots.valueFirst ])
    {
      let cellObj = value != null ? getCellObjByValue(value) : null
      if (::check_obj(cellObj))
        cellObj.scrollToView()
    }
    selCellOnSearchQuit = slots.valueFirst
  }

  function highlightUnitsInTree(units)
  {
    let shadingObj = scene.findObject("shop_dark_screen")
    shadingObj.show(true)
    guiScene.applyPendingChanges(true)

    let res = { valueFirst = null, valueLast = null }
    let highlightList = []
    let tree = getCurTreeData().tree
    let tableObj = scene.findObject("shop_items_list")
    local slotIdx = -1
    foreach(row, rowArr in tree)
      foreach(col, cell in rowArr)
      {
        if (!cell)
          continue
        slotIdx++
        let isGroup = ::isUnitGroup(cell)
        local isHighlight = !cell?.isFakeUnit && !isGroup && ::isInArray(cell?.name, units)
        if (isGroup)
          foreach (unit in cell.airsGroup)
            isHighlight = isHighlight || ::isInArray(unit?.name, units)
        if (!isHighlight)
          continue
        res.valueFirst = res.valueFirst ?? slotIdx
        res.valueLast  = slotIdx
        let objData  = {
          obj = getCellObjByValue(slotIdx)
          id = $"high_{slotIdx}"
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

    if (selCellOnSearchQuit != null)
    {
      let tableObj = scene.findObject("shop_items_list")
      if (::check_obj(tableObj))
      {
        skipOpenGroup = true
        tableObj.setValue(selCellOnSearchQuit)
        ::move_mouse_on_child(tableObj, selCellOnSearchQuit)
        skipOpenGroup = false
      }
      selCellOnSearchQuit = null
    }
  }

  function highlightUnitsClear()
  {
    let shadingObj = scene.findObject("shop_dark_screen")
    if (::check_obj(shadingObj))
      shadingObj.show(false)
  }

  function onHighlightedCellClick(obj)
  {
    let value = ::to_integer_safe(::g_string.cutPrefix(obj?.id, "high_") ?? "-1", -1, false)
    if (value >= 0)
      selCellOnSearchQuit = value
    guiScene.performDelayed(this, function() {
      if (isValid())
        searchBoxWeak?.searchCancel()
    })
  }

  function onShadedCellClick(obj)
  {
    if (searchBoxWeak)
      searchBoxWeak.searchCancel()
  }

  function openMenuForUnit(unit, ignoreMenuHover = false)
  {
    if ("name" not in unit)
      return
    local curAirObj = scene.findObject(unit.name)
    if (curAirObj == null && groupChooseObj?.isValid())
      curAirObj = groupChooseObj.findObject(unit.name)
    if (curAirObj?.isValid())
      openUnitActionsList(curAirObj, false, ignoreMenuHover)
  }

  function selectCell(obj) {
    let holderId = obj?.holderId
    let listObj = getCurListObj()
    let idx = findChildIndex(listObj, holderId == null
      ? @(c) c.isHovered()
      : @(c) c?.holderId == holderId)

    if (idx < 0 || idx == listObj.getValue())
      return

    listObj.setValue(idx)
  }

  function getCurListObj()
  {
    if (groupChooseObj?.isValid())
      return groupChooseObj.findObject("airs_table")
    else
      return scene.findObject("shop_items_list")
  }

  function onUnitActivate(obj)
  {
    if (findChildIndex(obj, @(c) c.isHovered()) == -1)
      return

    hideWaitIcon()
    onAircraftClick(obj)
  }

  function onAircraftClick(obj, ignoreMenuHover = false)
  {
    selectCell(obj)
    let unit = getCurAircraft()
    checkSelectAirGroup(unit)
    openMenuForUnit(unit, ignoreMenuHover)
  }

  function onUnitDblClick(obj) {
    if (!::show_console_buttons) //to use for not console buttons need to divide events activate and dbl_click
      onUnitMainFunc(obj)
  }

  function onUnitClick(obj) {
    hideWaitIcon()
    actionsListOpenTime = ::dagor.getCurTime()
    onAircraftClick(obj)
  }

  function onUnitRightClick(obj) {
    if (::dagor.getCurTime() - actionsListOpenTime
        < OPEN_RCLICK_UNIT_MENU_AFTER_SELECT_TIME)
      return
    onAircraftClick(obj)
  }

  function checkSelectAirGroup(item, selectUnitName = "")
  {
    if (skipOpenGroup || groupChooseObj || !item || !::isUnitGroup(item))
      return
    let silObj = scene.findObject("shop_items_list")
    if (!::checkObj(silObj))
      return
    let grObj = silObj.findObject(item.name)
    if (!::checkObj(grObj))
      return

    skipOpenGroup = true
    //choose aircraft from group window
    let tdObj = grObj.getParent()
    let tdPos = tdObj.getPosRC()
    let tdSize = tdObj.getSize()
    let leftPos = (tdPos[0] + tdSize[0] / 2) + " -50%w"

    let cellHeight = tdSize[1] || 86 // To avoid division by zero
    let screenHeight = ::screen_height()
    let safeareaHeight = guiScene.calcString("@rh", null)
    let safeareaBorderHeight = ::floor((screenHeight - safeareaHeight) / 2)
    let containerHeight = item.airsGroup.len() * cellHeight

    local topPos = tdPos[1]
    let heightOutOfSafearea = (topPos + containerHeight) - (safeareaBorderHeight + safeareaHeight)
    if (heightOutOfSafearea > 0)
      topPos -= ::ceil(heightOutOfSafearea / cellHeight) * cellHeight
    topPos = max(topPos, safeareaBorderHeight)

    groupChooseObj = guiScene.loadModal("", "%gui/shop/shopGroup.blk", "massTransp", this)
    let placeObj = groupChooseObj.findObject("tablePlace")
    placeObj.left = leftPos.tostring()
    placeObj.top = topPos.tostring()

    groupChooseObj.group = item.name
    let tableDiv = groupChooseObj.findObject("slots_scroll_div")
    tableDiv.pos = "0,0"

    fillGroupObj(selectUnitName)
    fillGroupObjAnimParams(tdSize, tdPos)

    updateGroupObjNavBar()
    skipOpenGroup = false
  }

  function fillGroupObjAnimParams(tdSize, tdPos)
  {
    let animObj = groupChooseObj.findObject("tablePlace")
    if (!animObj)
      return
    let size = animObj.getSize()
    if (!size[1])
      return

    animObj["height-base"] = tdSize[1].tostring()
    animObj["height-end"] = size[1].tostring()

    //update anim fixed position
    let heightDiff = size[1] - tdSize[1]
    if (heightDiff <= 0)
      return

    let pos = animObj.getPosRC()
    let topPart = (tdPos[1] - pos[1]).tofloat() / heightDiff
    let animFixedY = tdPos[1] + topPart * tdSize[1]
    animObj.top = format("%d - %fh", animFixedY.tointeger(), topPart)
  }

  function updateGroupObjNavBar()
  {
    navBarGroupObj = groupChooseObj.findObject("nav-help-group")
    navBarGroupObj.hasMaxWindowSize = isSmallScreen ? "yes" : "no"
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
      let reqUnit = ::getPrevUnit(unit)
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

    let item = getCurAircraft(false)
    if (!item || !::isUnitGroup(item))
      return

    let gTblObj = groupChooseObj.findObject("airs_table")
    if (!::checkObj(gTblObj))
      return

    if (selectUnitName == "")
    {
      let groupUnit = getDefaultUnitInGroup(item)
      if (groupUnit)
        selectUnitName = groupUnit.name
    }
    fillUnitsInGroup(gTblObj, item.airsGroup, selectUnitName)

    let lines = fillGroupObjArrows(item.airsGroup)
    guiScene.appendWithBlk(groupChooseObj.findObject("arrows_nest"), lines, this)

    foreach(unit in item.airsGroup)
      if (::isUnitBroken(unit))
        ::u.appendOnce(unit, brokenList)
  }

  function fillUnitsInGroup(tblObj, unitList, selectUnitName = "")
  {
    let selected = unitList.findindex(@(u) selectUnitName == u.name) ?? tblObj.getValue()
    initUnitCells(tblObj, unitList.map(@(u) { id = u.name, position = "relative" }))
    foreach(idx, unit in unitList)
      updateUnitCell(tblObj.getChild(idx), unit)

    tblObj.setValue(selected)
    ::move_mouse_on_child(tblObj, selected)
  }

  function onSceneActivate(show)
  {
    base.onSceneActivate(show)
    scene.enable(show)
    if (!show)
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
    ::move_mouse_on_child_by_value(scene.findObject("shop_items_list"))
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
    let cost = ::Cost()
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
      let curAir = getCurAircraft()
      lastPurchase = curAir
      needUpdateSlotbar = true
      needUpdateSquadInfo = true
      destroyProgressBox()
    }
  }

  function onEventUnitRepaired(params)
  {
    let unit = ::getTblValue("unit", params)

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
    let unitName = ::getTblValue("unitName", params, ::shop_get_researchable_unit_name(curCountry, getCurPageEsUnitType()))
    checkUnitItemAndUpdate(::getAircraftByName(unitName))
  }

  function onOpenOnlineShop(obj)
  {
    OnlineShopModel.showUnitGoods(getCurAircraft().name, "shop")
  }

  function onBuy()
  {
    unitActions.buy(getCurAircraft(true, true), "shop")
  }

  function onResearch(obj)
  {
    let unit = getCurAircraft()
    if (!unit || ::isUnitGroup(unit) || unit?.isFakeUnit || !::checkForResearch(unit))
      return

    unitActions.research(unit)
  }

  function onConvert(obj)
  {
    let unit = getCurAircraft()
    if (!unit || !::can_spend_gold_on_unit_with_popup(unit))
      return

    let unitName = unit.name
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

    let prevUnitName = ::getTblValue("prevUnitName", params)
    let unitName = ::getTblValue("unitName", params)

    if (prevUnitName && prevUnitName != unitName)
      checkUnitItemAndUpdate(::getAircraftByName(prevUnitName))

    let unit = ::getAircraftByName(unitName)
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
    let unitName = ::getTblValue("unitName", params)
    let unit = unitName ? ::getAircraftByName(unitName) : null
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

    highlightUnitsClear()
    if (unitId == null)
      return

    let unit = ::getAircraftByName(unitId)
    if (!unit || !unit.isVisibleInShop())
      return

    curAirName = unitId
    setUnitType(unit.unitType)
    ::switch_profile_country(::getUnitCountry(unit))
    searchBoxWeak?.searchCancel()
    selectCellByUnitName(unitId)
    // In mouse mode, mouse pointer don't move to slot, so we need a highlight.
    if (!::show_console_buttons || ::is_mouse_last_time_used())
      doWhenActive(@() highlightUnitsInTree([ unitId ]))
  }

  function selectCellByUnitName(unitName)
  {
    if (!unitName || unitName == "")
      return false

    if (!::checkObj(scene))
      return false

    let tableObj = scene.findObject("shop_items_list")
    if (!::checkObj(tableObj))
      return false

    let tree = getCurTreeData().tree
    local idx = -1
    foreach(rowIdx, row in tree)
      foreach(colIdx, item in row) {
        if (item == null)
          continue
        idx++
        if (::isUnitGroup(item))
        {
          foreach(groupItemIdx, groupItem in item.airsGroup)
            if (groupItem.name == unitName)
            {
              let obj = getCellObjByValue(idx)
              if (!obj?.isValid())
                return false

              obj.scrollToView()
              tableObj.setValue(idx)
              obj.setMouseCursorOnObject()
              if (::checkObj(groupChooseObj))
                groupChooseObj.findObject("airs_table").setValue(groupItemIdx)
              return true
            }
        }
        else if (item.name == unitName) {
          let obj = getCellObjByValue(idx)
          if (!obj?.isValid())
            return false

          obj.scrollToView()
          tableObj.setValue(idx)
          obj.setMouseCursorOnObject()
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
      let unit = ::getTblValue(param, params)
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

  function onUnitMainFunc(obj)
  {
    if (::show_console_buttons) { // open vehicle menu on slot button click
      onAircraftClick(obj, true)
      return
    }

    selectCell(obj)
    let unit = ::getAircraftByName(obj?.holderId) ?? getCurAircraft()
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

  function onUnitMainFuncBtnUnHover(obj) {
    if (!::show_console_buttons)
      return

    let unitObj = unitContextMenuState.value?.unitObj
    if (!unitObj?.isValid())
      return

    let actionListObj = unitObj.findObject("actions_list")
    if (actionListObj?.isValid())
      actionListObj.closeOnUnhover = "yes"
  }

  function onModifications(obj)
  {
    this.msgBox("not_available", ::loc("msgbox/notAvailbleYet"), [["ok", function() {} ]], "ok", { cancel_fn = function() {}})
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
    let country = ::get_profile_country_sq()
    if (country == curCountry)
      return

    curCountry = country
    doWhenActiveOnce("fillPagesListBoxNoOpenGroup")
  }

  hasModeList = @() (showModeList?.len() ?? 0) > 2

  function initShowMode(tgtNavBar)
  {
    let obj = tgtNavBar.findObject("show_mode")
    if (!::g_login.isProfileReceived() || !::checkObj(obj))
      return

    let storedMode = getShopDiffMode()
    local curMode = -1
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
        if (storedMode == diff.diffCode)
          curMode = storedMode
      }

    if (!hasModeList()) {
      obj.show(false)
      obj.enable(false)
      return
    }

    storeShopDiffMode(curMode)

    foreach (item in showModeList)
      item.selected <- item.diffCode == curMode

    let view = {
      id = "show_mode"
      optionTag = "option"
      cb = "onChangeShowMode"
      options= showModeList
    }
    let data = ::handyman.renderCached("%gui/options/spinnerOptions", view)
    guiScene.replaceContentFromText(obj, data, data.len(), this)
    updateShowModeTooltip(obj)
  }

  function updateShowModeTooltip(obj)
  {
    if (!::checkObj(obj))
      return
    local adviceText = ::loc(isAutoDiff() ? "mainmenu/showModesInfo/advice" : "mainmenu/showModesInfo/warning", { automatic = ::loc("options/auto") })
    adviceText = ::colorize(isAutoDiff() ? "goodTextColor" : "warningTextColor", adviceText)
    obj["tooltip"] = ::loc("mainmenu/showModesInfo/tooltip") + "\n" + adviceText
  }

  _isShowModeInChange = false
  function onChangeShowMode(obj)
  {
    if (_isShowModeInChange)
      return
    if (!::checkObj(obj))
      return

    let value = obj.getValue()
    let item = ::getTblValue(value, showModeList)
    if (!item)
      return

    _isShowModeInChange = true
    let prevEdiff = getCurrentEdiff()
    storeShopDiffMode(item.diffCode)

    foreach(tgtNavBar in [navBarObj, navBarGroupObj])
    {
      if (!::check_obj(tgtNavBar))
        continue

      let listObj = tgtNavBar.findObject("show_mode")
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
    return hasModeList() ? getShopDiffCode() : ::get_current_ediff()
  }

  function updateSlotbarDifficulty()
  {

    let slotbar = topMenuHandler.value?.getSlotbar()
    if (slotbar)
      slotbar.updateDifficulty()
  }

  function updateTreeDifficulty()
  {
    if (!::has_feature("GlobalShowBattleRating"))
      return
    let curEdiff = getCurrentEdiff()
    let tree = getCurTreeData().tree
    foreach(row in tree)
      foreach(unit in row)
      {
        let unitObj = unit ? getUnitCellObj(unit.name) : null
        if (::checkObj(unitObj))
        {
          let obj = unitObj.findObject("rankText")
          if (::checkObj(obj))
            obj.setValue(::get_unit_rank_text(unit, null, true, curEdiff))

          if (!shopResearchMode) {
            let hasObjective = ::isUnitGroup(unit)
              ? unit.airsGroup.findindex((@(u) hasMarkerByUnitName(u.name, curEdiff))) != null
              : ::u.isUnit(unit) && hasMarkerByUnitName(unit.name, curEdiff)
            show_obj(unitObj.findObject("unlockMarker"), hasObjective)
          }
        }
      }
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
    if (!(p?.isVisible ?? false))
      return
    shouldBlurSceneBg = p?.isShow ?? false
    ::handlersManager.updateSceneBgBlur()
  }

  function onEventCurrentGameModeIdChanged(params)
  {
    if (!isAutoDiff())
      return

    doWhenActiveOnce("updateTreeDifficulty")
  }

  function onUnitSelect() {}
  function selectRequiredUnit() {}
  function onSpendExcessExp() {}
  function updateResearchVariables() {}

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

    let unit = ::getAircraftByName(::clan_get_researching_unit())
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
