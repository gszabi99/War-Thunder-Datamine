from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { get_time_msec } = require("dagor.time")
let { format, split_by_chars } = require("string")
let { abs, ceil, floor } = require("math")
let { hangar_get_current_unit_name } = require("hangar")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

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
let { switchProfileCountry, profileCountrySq } = require("%scripts/user/playerCountry.nut")

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
    if (!this.curAirName.len())
    {
      this.curCountry = profileCountrySq.value
      let unit = ::getAircraftByName(hangar_get_current_unit_name())
      if (unit && unit.shopCountry == this.curCountry)
        this.curAirName = unit.name
    }

    this.skipOpenGroup = true
    this.scene.findObject("shop_timer").setUserData(this)
    this.brokenList = []
    this.curUnitsList = []

    this.navBarObj = this.scene.findObject("nav-help")

    this.initShowMode(this.navBarObj)
    this.loadFullAircraftsTable(this.curAirName)

    this.fillPagesListBox()
    this.initSearchBox()
    this.skipOpenGroup = false
  }

  function isSceneActive()
  {
    return base.isSceneActive()
           && (this.wndType != handlerType.CUSTOM || topMenuShopActive.value)
  }

  function loadFullAircraftsTable(selAirName = "")
  {
    let shopBlkData = getShopBlkData(selAirName)
    this.shopData = shopBlkData.shopData
    this.curCountry = shopBlkData.curCountry ?? this.curCountry
    this.curPage = shopBlkData.curPage ?? this.curPage
  }

  function getCurTreeData()
  {
    foreach(cData in this.shopData)
      if (cData.name == this.curCountry)
      {
        foreach(pageData in cData.pages)
          if (pageData.name == this.curPage)
            return shopTree.generateTreeData(pageData)
        if (cData.pages.len()>0)
        {
          this.curPage = cData.pages[0].name
          return shopTree.generateTreeData(cData.pages[0])
        }
      }

    this.curCountry = this.shopData[0].name
    this.curPage = this.shopData[0].pages[0].name
    return shopTree.generateTreeData(this.shopData[0].pages[0])
  }

  function countFullRepairCost()
  {
    this.repairAllCost = 0
    foreach(cData in this.shopData)
      if (cData.name == this.curCountry)
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
                    this.repairAllCost += ::wp_get_repair_cost(gAir.name)
                }
                else if (air.isUsable() && ::shop_get_aircraft_hp(air.name) < 1.0)
                  this.repairAllCost += ::wp_get_repair_cost(air.name)
              }
        }
  }

  function getItemStatusData(item, checkAir="")
  {
    let res = {
      shopReq = this.checkAirShopReq(item)
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
      res.own = this.isUnlockedFakeUnit(item)
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
      this.guiScene.createMultiElementsByObject(tableObj, "%gui/shop/shopUnitCell.blk", "unitCell", needCount - count, this)

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
      curUnlockId = getUnlockIdByUnitName(unitName, this.getCurrentEdiff())
    })
  }

  function updateUnitCell(cellObj, unit) {
    let params = this.getUnitItemParams(unit)
    updateCellStatus(cellObj, getStatusTbl(unit, params))
    updateCellTimedStatus(cellObj, @() getTimedStatusTbl(unit, params))
  }

  function updateCurUnitsList() {
    let tableObj = this.scene.findObject("shop_items_list")
    let total = tableObj.childrenCount()
    foreach(idx, unit in this.curUnitsList)
      if (idx < total)
        this.updateUnitCell(tableObj.getChild(idx), unit)
      else
        ::script_net_assert_once("shop early update", "Try to update shop units before init")
  }

  function fillAircraftsList(curName = "")
  {
    if (!checkObj(this.scene))
      return
    let tableObj = this.scene.findObject("shop_items_list")
    if (!checkObj(tableObj))
      return

    this.updateBoughtVehiclesCount()
    lastUnitType = this.getCurPageUnitType()

    if (curName=="")
      curName = this.getResearchingSquadronVehicle()?.name ?? this.curAirName

    let treeData = this.getCurTreeData()
    this.brokenList = []

    this.fillBGLines(treeData)
    this.guiScene.setUpdatesEnabled(false, false);

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
    tableObj.isShopItemsWide = to_pixels("@is_shop_items_wide")
    this.initUnitCells(tableObj, cellsList)
    this.curUnitsList = cellsList.map(@(c) c.unitOrGroup)
    this.updateCurUnitsList()

    local curIdx = -1
    foreach(idx, unit in this.curUnitsList) {
      let config = this.getItemStatusData(unit, curName)
      if (config.checkAir || ((curIdx < 0) && !unit?.isFakeUnit))
        curIdx = idx
      if (config.broken)
        this.brokenList.append(unit) //fix me: we can update it together with update units instead of fill all
    }

    this.guiScene.setUpdatesEnabled(true, true)
    tableObj.setValue(curIdx)

    this.updateButtons()

    ::broadcastEvent("ShopUnitTypeSwitched", { esUnitType = this.getCurPageEsUnitType() })
  }

  function fullReloadAircraftsList() {
    this.loadFullAircraftsTable()
    this.fillAircraftsList()
  }

  function onEventDiscountsDataUpdated(_params = {})
  {
    this.updateDiscountIconsOnTabs()
    this.updateCurUnitsList()
  }

  function onEventUnlockMarkersCacheInvalidate(_params = {}) {
    this.updateCurUnitsList()
  }

  function onEventPromoteUnitsChanged(_params = {}) {
    this.doWhenActiveOnce("loadFullAircraftsTable")
    this.doWhenActiveOnce("fillPagesListBoxNoOpenGroup")
  }

  function updateButtons()
  {
    this.updateRepairAllButton()
  }

  function showNavButton(id, show)
  {
    ::showBtn(id, show, this.navBarObj)
    if (checkObj(this.navBarGroupObj))
      ::showBtn(id, show, this.navBarGroupObj)
  }

  function updateRepairAllButton()
  {
    if (this.brokenList.len() > 0)
      this.countFullRepairCost()

    let show = this.brokenList.len() > 0 && this.repairAllCost > 0
    this.showNavButton("btn_repairall", show)
    if (!show)
      return

    let locText = loc("mainmenu/btnRepairAll")
    placePriceTextToButton(this.navBarObj, "btn_repairall", locText, this.repairAllCost)
    placePriceTextToButton(this.navBarGroupObj, "btn_repairall", locText, this.repairAllCost)
  }

  function onEventOnlineShopPurchaseSuccessful(_params)
  {
    this.doWhenActiveOnce("fullReloadAircraftsList")
  }

  function onEventSlotbarPresetLoaded(_p)
  {
    this.doWhenActiveOnce("fullReloadAircraftsList")
  }

  function onEventProfileUpdated(_p)
  {
    this.doWhenActiveOnce("fullReloadAircraftsList")
  }

  function onEventItemsShopUpdate(_p)
  {
    this.doWhenActiveOnce("fullReloadAircraftsList")
  }

  function onUpdate(_obj, dt)
  {
    this._timer -= dt
    if (this._timer > 0)
      return
    this._timer += 1.0

    this.checkBrokenUnitsAndUpdateThem()
    this.updateRepairAllButton()
  }

  function checkBrokenUnitsAndUpdateThem()
  {
    for(local i = this.brokenList.len() - 1; i >= 0; i--)
    {
      if (i >= this.brokenList.len()) //update unit item is not instant, so broken list can change at that time by other events
        continue

      let unit = this.brokenList[i]
      if (this.checkBrokenListStatus(unit))
        this.checkUnitItemAndUpdate(unit)
    }
  }

  function getLineStatus(lc)
  {
    let config = this.getItemStatusData(lc.air)
    let configReq = this.getItemStatusData(lc.reqAir)

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
        alarmTooltip = ::g_string.stripTags(loc(locId, {
          futureReqAir = ::getUnitName(air.futureReqAir)
          curAir = ::getUnitName(air)
          reqAir = hasReqAir ? ::getUnitName(air.reqAir) : ""
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
                       (abs(c1 - c0) - 0.5) + "@shop_width + " + interval1, //width
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
                      (abs(c1-c0) - offset) + "@shop_width",
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
    this.guiScene.setUpdatesEnabled(false, false)
    this.generateHeaders(treeData)
    this.generateBGPlates(treeData)
    this.generateTierArrows(treeData)
    this.generateAirAddictiveArrows(treeData)
    this.guiScene.setUpdatesEnabled(true, true)

    let contentWidth = this.scene.findObject("shopTable_air_rows").getSize()[0]
    let containerWidth = this.scene.findObject("shop_useful_width").getSize()[0]
    let pos = (contentWidth >= containerWidth)? "0" : "(pw-w)/2"
    this.scene.findObject("shop_items_pos_div").left = pos
  }

  function generateAirAddictiveArrows(treeData)
  {
    let tblBgObj = this.scene.findObject("shopTable_air_rows")
    local data = ""
    foreach(lc in treeData.lines)
    {
      this.fillAirReq(lc.air, lc.reqAir)
      data += this.createLine(lc.line[0], lc.line[1], lc.line[2], lc.line[3], this.getLineStatus(lc), lc)
    }

    foreach(_row, rowArr in treeData.tree) //check groups even they dont have requirements
      for(local col = 0; col < rowArr.len(); col++)
        if (::isUnitGroup(rowArr[col]))
          this.fillAirReq(rowArr[col])

    this.guiScene.replaceContentFromText(tblBgObj, data, data.len(), this)

    tblBgObj.width = treeData.tree[0].len() + "@shop_width"
  }

  function generateHeaders(treeData)
  {
    let obj = this.scene.findObject("tree_header_div")
    let view = {
      plates = [],
      separators = [],
    }

    let sectionsTotal = treeData.sectionsPos.len() - 1
    let widthStr = isSmallScreen
      ? "1@maxWindowWidth -1@modBlockTierNumHeight -1@scrollBarSize"
      : "1@slotbarWidthFull -1@modBlockTierNumHeight -1@scrollBarSize"
    let totalWidth = this.guiScene.calcString(widthStr, null)
    let itemWidth = this.guiScene.calcString("@shop_width", null)

    let extraWidth = "+" + max(0, totalWidth - (itemWidth * treeData.sectionsPos[sectionsTotal])) / 2
    let extraLeft = extraWidth + "+1@modBlockTierNumHeight"
    let extraRight = extraWidth + "+1@scrollBarSize - 2@frameHeaderPad"

    for (local s = 0; s < sectionsTotal; s++)
    {
      let isLeft = s == 0
      let isRight = s == sectionsTotal - 1

      let x = treeData.sectionsPos[s] + "@shop_width" + (isLeft ? "" : extraLeft)
      let w = (treeData.sectionsPos[s + 1] - treeData.sectionsPos[s]) + "@shop_width" + (isLeft ? extraLeft : "") + (isRight ? extraRight : "")

      let isResearchable = getTblValue(s, treeData.sectionsResearchable)
      let title = isResearchable ? "#shop/section/researchable" : "#shop/section/premium"

      view.plates.append({ title = title, x = x, w = w })
      if (!isLeft)
        view.separators.append({ x = x })
    }

    let data = ::handyman.renderCached("%gui/shop/treeHeadPlates.tpl", view)
    this.guiScene.replaceContentFromText(obj, data, data.len(), this)
  }

  function generateBGPlates(treeData)
  {
    let tblBgObj = this.scene.findObject("shopTable_air_plates")
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
    let totalWidth = this.guiScene.calcString(widthStr, null)
    let itemWidth = this.guiScene.calcString("@shop_width", null)

    let extraRight = "+" + max(0, totalWidth - (itemWidth * treeData.sectionsPos[sectionsTotal])) / 2
    let extraLeft = extraRight + "+1@modBlockTierNumHeight"
    let extraTop = "+1@shop_h_extra_first"
    let extraBottom = "+1@shop_h_extra_last"

    for(local i = 0; i < tiersTotal; i++)
    {
      let tierNum = (i+1).tostring()
      let tierUnlocked = ::is_era_available(this.curCountry, i + 1, this.getCurPageEsUnitType())
      let fakeRowsCount = treeData.fakeRanksRowsCount[i + 1]

      let pY = treeData.ranksHeight[i] + fakeRowsCount
      let pH = treeData.ranksHeight[i + 1] - pY

      let isTop = pY == 0
      let isBottom = i == tiersTotal - 1

      for(local s = 0; s < sectionsTotal; s++)
      {
        let isLeft = s == 0
        let isRight = s == sectionsTotal - 1
        let isResearchable = getTblValue(s, treeData.sectionsResearchable)
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

    local data = ::handyman.renderCached("%gui/shop/treeBgPlates.tpl", view)
    this.guiScene.replaceContentFromText(tblBgObj, data, data.len(), this)
  }

  function getRankProgressTexts(rank, ranksBlk, isTreeReserchable)
  {
    if (!ranksBlk)
      ranksBlk = ::get_ranks_blk()

    let isEraAvailable = !isTreeReserchable || ::is_era_available(this.curCountry, rank, this.getCurPageEsUnitType())
    local tooltipPlate = ""
    local tooltipRank = ""
    local tooltipReqCounter = ""
    local reqCounter = ""

    if (isEraAvailable)
    {
      let unitsCount = this.boughtVehiclesCount[rank]
      let unitsTotal = this.totalVehiclesCount[rank]
      tooltipRank = loc("shop/age/tooltip") + loc("ui/colon") + colorize("userlogColoredText", ::get_roman_numeral(rank))
        + "\n" + loc("shop/tier/unitsBought") + loc("ui/colon") + colorize("userlogColoredText", format("%d/%d", unitsCount, unitsTotal))
    }
    else
    {
      let unitType = this.getCurPageEsUnitType()
      for (local prevRank = rank - 1; prevRank > 0; prevRank--)
      {
        let unitsCount = this.boughtVehiclesCount[prevRank]
        let unitsNeed = ::getUnitsNeedBuyToOpenNextInEra(this.curCountry, unitType, prevRank, ranksBlk)
        let unitsLeft = max(0, unitsNeed - unitsCount)

        if (unitsLeft > 0)
        {
          let txtThisRank = colorize("userlogColoredText", ::get_roman_numeral(rank))
          let txtPrevRank = colorize("userlogColoredText", ::get_roman_numeral(prevRank))
          let txtUnitsNeed = colorize("badTextColor", unitsNeed)
          let txtUnitsLeft = colorize("badTextColor", unitsLeft)
          let txtCounter = format("%d/%d", unitsCount, unitsNeed)
          let txtCounterColored = colorize("badTextColor", txtCounter)

          let txtRankIsLocked = loc("shop/unlockTier/locked", { rank = txtThisRank })
          let txtNeedUnits = loc("shop/unlockTier/reqBoughtUnitsPrevRank", { prevRank = txtPrevRank, amount = txtUnitsLeft })
          let txtRankLockedDesc = loc("shop/unlockTier/desc", { rank = txtThisRank, prevRank = txtPrevRank, amount = txtUnitsNeed })
          let txtRankProgress = loc("shop/unlockTier/progress", { rank = txtThisRank }) + loc("ui/colon") + txtCounterColored

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
    let pageUnitsType = this.getCurPageEsUnitType()

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
      let isRankAvailable = !isTreeReserchable || ::is_era_available(this.curCountry, i, pageUnitsType)
      let status =  isRankAvailable ?  "owned" : "locked"

      let texts = this.getRankProgressTexts(i, blk, isTreeReserchable)

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
                  loc("shop/age/num", { num = ::get_roman_numeral(i) }),
                  ::g_string.stripTags(texts.tooltipRank))

      data += arrowData

      let tierObj = this.scene.findObject("shop_tier_" + i.tostring())
      if (checkObj(tierObj))
        tierObj.tooltip = texts.tooltipPlate
    }

    let height = treeData.ranksHeight[treeData.ranksHeight.len()-1] + "@shop_height"
    let tierObj = this.scene.findObject("tier_arrows_div")
    tierObj.height = height
    this.guiScene.replaceContentFromText(tierObj, data, data.len(), this)

    this.scene.findObject("shop_items_scroll_div").height = height + " + 1@shop_h_extra_first + 1@shop_h_extra_last"
  }

  function updateBoughtVehiclesCount()
  {
    let bought = array(::max_country_rank + 1, 0)
    let total = array(::max_country_rank + 1, 0)
    let pageUnitsType = this.getCurPageEsUnitType()

    foreach(unit in ::all_units)
      if (unit.shopCountry == this.curCountry && pageUnitsType == ::get_es_unit_type(unit))
      {
        let isOwn = ::isUnitBought(unit)
        if (isOwn)
          bought[unit.rank]++
        if (isOwn || unit.isVisibleInShop())
          total[unit.rank]++
      }

    this.boughtVehiclesCount = bought
    this.totalVehiclesCount = total
  }

  function fillAirReq(item, reqUnit = null)
  {
    local req = true
    if (item?.reqAir)
      req = ::isUnitBought(::getAircraftByName(item.reqAir))
    if (req && reqUnit?.isFakeUnit)
      req = this.isUnlockedFakeUnit(reqUnit)
    if (::isUnitGroup(item))
    {
      foreach(_idx, air in item.airsGroup)
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
    return ::get_units_count_at_rank(unit?.rank,
      unitTypes.getByName(unit?.isReqForFakeUnit ? split_by_chars(unit.name, "_")?[0] : unit.name,
        false).esUnitType,
      unit.country, true)
      >= (((split_by_chars(unit.name, "_"))?[1] ?? "0").tointeger() + 1)
  }

  function getCurPageEsUnitType()
  {
    return this.getCurPageUnitType().esUnitType
  }

  function getCurPageUnitType()
  {
    return unitTypes.getByArmyId(this.curPage)
  }

  function findUnitInGroupTableById(id)
  {
    if (checkObj(this.groupChooseObj))
      return this.groupChooseObj.findObject("airs_table").findObject(id)

    return null
  }

  function findCloneGroupObjById(id)
  {
    if (checkObj(this.groupChooseObj))
      return this.groupChooseObj.findObject("clone_td_" + id)

    return null
  }

  function findAirTableObjById(id)
  {
    if (checkObj(this.scene))
      return this.scene.findObject("shop_items_list").findObject(id)

    return null
  }

  function getAirObj(unitName)
  {
    let airObj = this.findUnitInGroupTableById(unitName)
    if (checkObj(airObj))
      return airObj

    return this.findAirTableObjById(unitName)
  }

  function getUnitCellObj(unitName)
  {
    let cellObj = this.findUnitInGroupTableById($"unitCell_{unitName}")
    if (checkObj(cellObj))
      return cellObj

    return this.findAirTableObjById($"unitCell_{unitName}")
  }

  function getCellObjByValue(value) {
    let tableObj = this.scene.findObject("shop_items_list")
    return value < tableObj.childrenCount() ? tableObj.getChild(value) : null
  }

  function checkUnitItemAndUpdate(unit)
  {
    if (!unit || unit?.isFakeUnit)
      return

    let unitObj = this.getUnitCellObj(unit.name)
    if ((unitObj?.isValid() ?? false) && unitObj.isVisible()) //need update only visible cell
      this.updateUnitItem(unit, unitObj)

    ::updateAirAfterSwitchMod(unit)

    if (!::isUnitGroup(unit) && ::isGroupPart(unit))
      this.updateGroupItem(unit.group)
  }

  function updateUnitItem(unit, cellObj)
  {
    if (cellObj?.isValid())
      this.updateUnitCell(cellObj, unit)
  }

  function updateGroupItem(groupName)
  {
    let block = this.getItemBlockFromShopTree(groupName)
    if (!block)
      return

    this.updateUnitItem(block, this.findCloneGroupObjById(groupName))
    this.updateUnitItem(block, this.findAirTableObjById($"unitCell_{groupName}"))
  }

  function checkBrokenListStatus(unit)
  {
    if (!unit)
      return false

    let posNum = ::find_in_array(this.brokenList, unit)
    if (!this.getItemStatusData(unit).broken && posNum >= 0)
    {
      this.brokenList.remove(posNum)
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
      availableFlushExp = this.availableFlushExp
      setResearchManually = this.setResearchManually
    }
    let mainActionLocId = is_unit ? slotActions.getSlotActionFunctionName(unit, params) : ""
    return {
      mainActionText = mainActionLocId != "" ? loc(mainActionLocId) : ""
      shopResearchMode = this.shopResearchMode
      forceNotInResearch = !this.setResearchManually
      flushExp = this.availableFlushExp
      showBR = hasFeature("GlobalShowBattleRating")
      getEdiffFunc = this.getCurrentEdiff.bindenv(this)
      tooltipParams = { needShopInfo = true }
    }
  }

  function findUnitInTree(isFits) {
    let tree = this.getCurTreeData().tree
    local idx = -1
    foreach(row, rowArr in tree)
      foreach(col, unit in rowArr)
        if (unit != null && isFits(unit, ++idx))
          return { unit = unit, row = row, col = col, idx = idx }
    return { unit = null, row = -1, col = -1, idx = -1 }
  }

  getUnitByIdx = @(curIdx) this.findUnitInTree(@(_unit, idx) idx == curIdx)

  function getCurAircraft(checkGroups = true, returnDefaultUnitForGroups = false)
  {
    if (!checkObj(this.scene))
      return null

    local tableObj = this.scene.findObject("shop_items_list")
    let curIdx = tableObj.getValue()
    if (curIdx < 0)
      return null
    let mainTblUnit = this.getUnitByIdx(curIdx).unit
    if (!::isUnitGroup(mainTblUnit))
      return mainTblUnit

    if (checkGroups && checkObj(this.groupChooseObj))
    {
      tableObj = this.groupChooseObj.findObject("airs_table")
      let idx = tableObj.getValue()
      if (idx in mainTblUnit.airsGroup)
        return mainTblUnit.airsGroup[idx]
    }

    if (returnDefaultUnitForGroups)
      return this.getDefaultUnitInGroup(mainTblUnit)

    return mainTblUnit
  }

  function getDefaultUnitInGroup(unitGroup)
  {
    let airsList = getTblValue("airsGroup", unitGroup)
    return getTblValue(0, airsList)
  }

  function getItemBlockFromShopTree(itemName)
  {
    let tree = this.getCurTreeData().tree
    for(local i = 0; i < tree.len(); ++i)
      for(local j = 0; j < tree[i].len(); ++j)
      {
        let name = getTblValue("name", tree[i][j])
        if (!name)
          continue

        if (itemName == name)
          return tree[i][j]
      }

    return null
  }

  function onAircraftsPage()
  {
    let pagesObj = this.scene.findObject("shop_pages_list")
    if (pagesObj)
    {
      let pageIdx = pagesObj.getValue()
      if (pageIdx < 0 || pageIdx >= pagesObj.childrenCount())
        return
      this.curPage = pagesObj.getChild(pageIdx).id
    }
    this.fillAircraftsList()
  }

  function onCloseShop()
  {
    if (this.closeShop)
      this.closeShop()
  }

  function fillPagesListBoxNoOpenGroup()
  {
    this.skipOpenGroup = true
    this.fillPagesListBox()
    this.skipOpenGroup = false
  }

  function fillPagesListBox()
  {
    if (this.shopResearchMode)
    {
      this.fillAircraftsList()
      return
    }

    let pagesObj = this.scene.findObject("shop_pages_list")
    if (!checkObj(pagesObj))
      return

    let unitType = this.forceUnitType
      ?? lastUnitType
      ?? ::getAircraftByName(this.curAirName)?.unitType
      ?? unitTypes.INVALID

    this.forceUnitType = null //forceUnitType applyied only once

    local data = ""
    local curIdx = 0
    let countryData = ::u.search(this.shopData, (@(curCountry) function(country) { return country.name == curCountry})(this.curCountry))
    if (countryData)
    {
      let ediff = this.getCurrentEdiff()
      let view = { tabs = [] }
      foreach(idx, page in countryData.pages)
      {
        let name = page.name
        view.tabs.append({
          id = name
          tabName = "#mainmenu/" + name
          discount = {
            discountId = this.getDiscountIconTabId(countryData.name, name)
          }
          squadronExpIconId = this.curCountry + ";" + name
          seenIconCfg = bhvUnseen.makeConfigStr(seenList.id,
            getUnlockIdsByArmyId(this.curCountry, name, ediff))
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

      data = ::handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
    }
    this.guiScene.replaceContentFromText(pagesObj, data, data.len(), this)

    this.updateDiscountIconsOnTabs()

    pagesObj.setValue(curIdx)
  }

  function getDiscountIconTabId(country, unitType)
  {
    return country + "_" + unitType + "_discount"
  }

  function updateDiscountIconsOnTabs()
  {
    let pagesObj = this.scene.findObject("shop_pages_list")
    if (!checkObj(pagesObj))
      return

    foreach(country in this.shopData)
    {
      if (country.name != this.curCountry)
        continue

      foreach(_idx, page in country.pages)
      {
        let tabObj = pagesObj.findObject(page.name)
        if (!checkObj(tabObj))
          continue

        let discountObj = tabObj.findObject(this.getDiscountIconTabId(this.curCountry, page.name))
        if (!checkObj(discountObj))
          continue

        let discountData = this.getDiscountByCountryAndArmyId(this.curCountry, page.name)

        let maxDiscount = discountData?.maxDiscount ?? 0
        let discountTooltip = getTblValue("discountTooltip", discountData, "")
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
    if (this.shopResearchMode || !hasFeature("UnitsSearchBoxInShop"))
      return
    let handler = shopSearchBox.init({
      scene = this.scene.findObject("shop_search_box")
      curCountry = this.curCountry
      curEsUnitType = this.getCurPageEsUnitType()
      cbOwnerSearchHighlight = Callback(this.searchHighlight, this)
      cbOwnerSearchCancel    = Callback(this.searchCancel,    this)
      cbOwnerShowUnit        = Callback(this.showUnitInShop,  this)
      cbOwnerClose           = Callback(this.onCloseShop, this)
      getEdiffFunc           = Callback(this.getCurrentEdiff, this)
    })
    this.registerSubHandler(handler)
    this.searchBoxWeak = handler.weakref()
  }

  function searchHighlight(units, isClear)
  {
    if (isClear)
      return this.highlightUnitsClear()
    let slots = this.highlightUnitsInTree(units.map(@(unit) unit.name))
    let tableObj = this.scene.findObject("shop_items_list")
    if (!checkObj(tableObj))
      return
    foreach (value in [ slots.valueLast, slots.valueFirst ])
    {
      let cellObj = value != null ? this.getCellObjByValue(value) : null
      if (checkObj(cellObj))
        cellObj.scrollToView()
    }
    this.selCellOnSearchQuit = slots.valueFirst
  }

  function highlightUnitsInTree(units)
  {
    let shadingObj = this.scene.findObject("shop_dark_screen")
    shadingObj.show(true)
    this.guiScene.applyPendingChanges(true)

    let res = { valueFirst = null, valueLast = null }
    let highlightList = []
    let tree = this.getCurTreeData().tree
    let tableObj = this.scene.findObject("shop_items_list")
    local slotIdx = -1
    foreach(_row, rowArr in tree)
      foreach(_col, cell in rowArr)
      {
        if (!cell)
          continue
        slotIdx++
        let isGroup = ::isUnitGroup(cell)
        local isHighlight = !cell?.isFakeUnit && !isGroup && isInArray(cell?.name, units)
        if (isGroup)
          foreach (unit in cell.airsGroup)
            isHighlight = isHighlight || isInArray(unit?.name, units)
        if (!isHighlight)
          continue
        res.valueFirst = res.valueFirst ?? slotIdx
        res.valueLast  = slotIdx
        let objData  = {
          obj = this.getCellObjByValue(slotIdx)
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
    this.highlightUnitsClear()

    if (this.selCellOnSearchQuit != null)
    {
      let tableObj = this.scene.findObject("shop_items_list")
      if (checkObj(tableObj))
      {
        this.skipOpenGroup = true
        tableObj.setValue(this.selCellOnSearchQuit)
        ::move_mouse_on_child(tableObj, this.selCellOnSearchQuit)
        this.skipOpenGroup = false
      }
      this.selCellOnSearchQuit = null
    }
  }

  function highlightUnitsClear()
  {
    let shadingObj = this.scene.findObject("shop_dark_screen")
    if (checkObj(shadingObj))
      shadingObj.show(false)
  }

  function onHighlightedCellClick(obj)
  {
    let value = ::to_integer_safe(::g_string.cutPrefix(obj?.id, "high_") ?? "-1", -1, false)
    if (value >= 0)
      this.selCellOnSearchQuit = value
    this.guiScene.performDelayed(this, function() {
      if (this.isValid())
        this.searchBoxWeak?.searchCancel()
    })
  }

  function onShadedCellClick(_obj)
  {
    if (this.searchBoxWeak)
      this.searchBoxWeak.searchCancel()
  }

  function openMenuForUnit(unit, ignoreMenuHover = false)
  {
    if ("name" not in unit)
      return
    local curAirObj = this.scene.findObject(unit.name)
    if (curAirObj == null && this.groupChooseObj?.isValid())
      curAirObj = this.groupChooseObj.findObject(unit.name)
    if (curAirObj?.isValid())
      this.openUnitActionsList(curAirObj, false, ignoreMenuHover)
  }

  function selectCell(obj) {
    let holderId = obj?.holderId
    let listObj = this.getCurListObj()
    let idx = findChildIndex(listObj, holderId == null
      ? @(c) c.isHovered()
      : @(c) c?.holderId == holderId)

    if (idx < 0 || idx == listObj.getValue())
      return

    listObj.setValue(idx)
  }

  function getCurListObj()
  {
    if (this.groupChooseObj?.isValid())
      return this.groupChooseObj.findObject("airs_table")
    else
      return this.scene.findObject("shop_items_list")
  }

  function onUnitActivate(obj)
  {
    if (findChildIndex(obj, @(c) c.isHovered()) == -1)
      return

    hideWaitIcon()
    this.onAircraftClick(obj)
  }

  function onAircraftClick(obj, ignoreMenuHover = false)
  {
    this.selectCell(obj)
    let unit = this.getCurAircraft()
    this.checkSelectAirGroup(unit)
    this.openMenuForUnit(unit, ignoreMenuHover)
  }

  function onUnitDblClick(obj) {
    if (!::show_console_buttons) //to use for not console buttons need to divide events activate and dbl_click
      this.onUnitMainFunc(obj)
  }

  function onUnitClick(obj) {
    hideWaitIcon()
    this.actionsListOpenTime = get_time_msec()
    this.onAircraftClick(obj)
  }

  function onUnitRightClick(obj) {
    if (get_time_msec() - this.actionsListOpenTime
        < OPEN_RCLICK_UNIT_MENU_AFTER_SELECT_TIME)
      return
    this.onAircraftClick(obj)
  }

  function checkSelectAirGroup(item, selectUnitName = "")
  {
    if (this.skipOpenGroup || this.groupChooseObj || !item || !::isUnitGroup(item))
      return
    let silObj = this.scene.findObject("shop_items_list")
    if (!checkObj(silObj))
      return
    let grObj = silObj.findObject(item.name)
    if (!checkObj(grObj))
      return

    this.skipOpenGroup = true
    //choose aircraft from group window
    let tdObj = grObj.getParent()
    let tdPos = tdObj.getPosRC()
    let tdSize = tdObj.getSize()
    let leftPos = (tdPos[0] + tdSize[0] / 2) + " -50%w"

    let cellHeight = tdSize[1] || 86 // To avoid division by zero
    let screenHeight = ::screen_height()
    let safeareaHeight = this.guiScene.calcString("@rh", null)
    let safeareaBorderHeight = floor((screenHeight - safeareaHeight) / 2)
    let containerHeight = item.airsGroup.len() * cellHeight

    local topPos = tdPos[1]
    let heightOutOfSafearea = (topPos + containerHeight) - (safeareaBorderHeight + safeareaHeight)
    if (heightOutOfSafearea > 0)
      topPos -= ceil(heightOutOfSafearea / cellHeight) * cellHeight
    topPos = max(topPos, safeareaBorderHeight)

    this.groupChooseObj = this.guiScene.loadModal("", "%gui/shop/shopGroup.blk", "massTransp", this)
    let placeObj = this.groupChooseObj.findObject("tablePlace")
    placeObj.left = leftPos.tostring()
    placeObj.top = topPos.tostring()

    this.groupChooseObj.group = item.name
    let tableDiv = this.groupChooseObj.findObject("slots_scroll_div")
    tableDiv.pos = "0,0"

    this.fillGroupObj(selectUnitName)
    this.fillGroupObjAnimParams(tdSize, tdPos)

    this.updateGroupObjNavBar()
    this.skipOpenGroup = false
  }

  function fillGroupObjAnimParams(tdSize, tdPos)
  {
    let animObj = this.groupChooseObj.findObject("tablePlace")
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
    this.navBarGroupObj = this.groupChooseObj.findObject("nav-help-group")
    this.navBarGroupObj.hasMaxWindowSize = isSmallScreen ? "yes" : "no"
    this.initShowMode(this.navBarGroupObj)
    this.updateButtons()
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
        lines += this.createLine(unitPosNum - 1, 0, unitPosNum, 0, status)
      }
      prevGroupUnit = unit
      unitPosNum++
    }
    return lines
  }

  function fillGroupObj(selectUnitName = "")
  {
    if (!checkObj(this.scene) || !checkObj(this.groupChooseObj))
      return

    let item = this.getCurAircraft(false)
    if (!item || !::isUnitGroup(item))
      return

    let gTblObj = this.groupChooseObj.findObject("airs_table")
    if (!checkObj(gTblObj))
      return

    if (selectUnitName == "")
    {
      let groupUnit = this.getDefaultUnitInGroup(item)
      if (groupUnit)
        selectUnitName = groupUnit.name
    }
    this.fillUnitsInGroup(gTblObj, item.airsGroup, selectUnitName)

    let lines = this.fillGroupObjArrows(item.airsGroup)
    this.guiScene.appendWithBlk(this.groupChooseObj.findObject("arrows_nest"), lines, this)

    foreach(unit in item.airsGroup)
      if (::isUnitBroken(unit))
        ::u.appendOnce(unit, this.brokenList)
  }

  function fillUnitsInGroup(tblObj, unitList, selectUnitName = "")
  {
    let selected = unitList.findindex(@(u) selectUnitName == u.name) ?? tblObj.getValue()
    this.initUnitCells(tblObj, unitList.map(@(u) { id = u.name, position = "relative" }))
    foreach(idx, unit in unitList)
      this.updateUnitCell(tblObj.getChild(idx), unit)

    tblObj.setValue(selected)
    ::move_mouse_on_child(tblObj, selected)
  }

  function onSceneActivate(show)
  {
    base.onSceneActivate(show)
    this.scene.enable(show)
    if (!show)
      this.destroyGroupChoose()
  }

  function onDestroy()
  {
    this.destroyGroupChoose()
  }

  function destroyGroupChoose(destroySpecGroupName = "")
  {
    if (!checkObj(this.groupChooseObj)
        || (destroySpecGroupName != "" &&
            destroySpecGroupName == this.groupChooseObj.group))
      return

    this.guiScene.destroyElement(this.groupChooseObj)
    this.groupChooseObj=null
    this.updateButtons()
    ::broadcastEvent("ModalWndDestroy")
    ::move_mouse_on_child_by_value(this.scene.findObject("shop_items_list"))
  }

  function destroyGroupChooseDelayed()
  {
    this.guiScene.performDelayed(this, this.destroyGroupChoose)
  }

  function onCancelSlotChoose(_obj)
  {
    if (checkObj(this.groupChooseObj))
      this.destroyGroupChooseDelayed()
  }

  function onRepairAll(_obj)
  {
    let cost = ::Cost()
    cost.wp = this.repairAllCost

    if (!::check_balance_msgBox(cost))
      return

    this.taskId = ::shop_repair_all(this.curCountry, false)
    if (this.taskId < 0)
      return

    ::set_char_cb(this, this.slotOpCb)
    this.showTaskProgressBox()

    this.afterSlotOp = function()
    {
      this.showTaskProgressBox()
      this.checkBrokenUnitsAndUpdateThem()
      let curAir = this.getCurAircraft()
      this.lastPurchase = curAir
      this.needUpdateSlotbar = true
      this.needUpdateSquadInfo = true
      this.destroyProgressBox()
    }
  }

  function onEventUnitRepaired(params)
  {
    let unit = getTblValue("unit", params)

    if (this.checkBrokenListStatus(unit))
      this.checkUnitItemAndUpdate(unit)

    this.updateRepairAllButton()
  }

  function onEventSparePurchased(params)
  {
    if (!this.scene.isEnabled() || !this.scene.isVisible())
      return
    this.checkUnitItemAndUpdate(getTblValue("unit", params))
  }

  function onEventModificationPurchased(params)
  {
    if (!this.scene.isEnabled() || !this.scene.isVisible())
      return
    this.checkUnitItemAndUpdate(getTblValue("unit", params))
  }

  function onEventAllModificationsPurchased(params)
  {
    if (!this.scene.isEnabled() || !this.scene.isVisible())
      return
    this.checkUnitItemAndUpdate(getTblValue("unit", params))
  }

  function onEventUpdateResearchingUnit(params)
  {
    let unitName = getTblValue("unitName", params, ::shop_get_researchable_unit_name(this.curCountry, this.getCurPageEsUnitType()))
    this.checkUnitItemAndUpdate(::getAircraftByName(unitName))
  }

  function onOpenOnlineShop(_obj)
  {
    ::OnlineShopModel.showUnitGoods(this.getCurAircraft().name, "shop")
  }

  function onBuy()
  {
    unitActions.buy(this.getCurAircraft(true, true), "shop")
  }

  function onResearch(_obj)
  {
    let unit = this.getCurAircraft()
    if (!unit || ::isUnitGroup(unit) || unit?.isFakeUnit || !::checkForResearch(unit))
      return

    unitActions.research(unit)
  }

  function onConvert(_obj)
  {
    let unit = this.getCurAircraft()
    if (!unit || !::can_spend_gold_on_unit_with_popup(unit))
      return

    let unitName = unit.name
    this.selectCellByUnitName(unitName)
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
    if (!checkObj(this.scene))
      return

    let prevUnitName = getTblValue("prevUnitName", params)
    let unitName = getTblValue("unitName", params)

    if (prevUnitName && prevUnitName != unitName)
      this.checkUnitItemAndUpdate(::getAircraftByName(prevUnitName))

    let unit = ::getAircraftByName(unitName)
    this.updateResearchVariables()
    this.checkUnitItemAndUpdate(unit)

    this.selectCellByUnitName(unit)

    if (this.shopResearchMode && this.availableFlushExp <= 0)
    {
      ::buyUnit(unit)
      this.onCloseShop()
    }
  }

  function onEventUnitBought(params)
  {
    let unitName = getTblValue("unitName", params)
    let unit = unitName ? ::getAircraftByName(unitName) : null
    if (!unit)
      return

    if (getTblValue("receivedFromTrophy", params, false) && unit.isVisibleInShop())
    {
      this.doWhenActiveOnce("fullReloadAircraftsList")
      return
    }

    this.updateResearchVariables()
    this.fillAircraftsList(unitName)
    this.fillGroupObj()

    if (!this.isSceneActive())
      return

    if (!::checkIsInQueue() && !this.shopResearchMode)
      this.onTake(unit, {isNewUnit = true})
    else if (this.shopResearchMode)
      this.selectRequiredUnit()
  }

  function onEventDebugUnlockEnabled(_params)
  {
    this.doWhenActiveOnce("fullReloadAircraftsList")
  }

  function onEventUnitRented(params)
  {
    this.onEventUnitBought(params)
  }

  function showUnitInShop(unitId)
  {
    if (!this.isSceneActive() || ::checkIsInQueue() || this.shopResearchMode)
      return

    this.highlightUnitsClear()
    if (unitId == null)
      return

    let unit = ::getAircraftByName(unitId)
    if (!unit || !unit.isVisibleInShop())
      return

    this.curAirName = unitId
    this.setUnitType(unit.unitType)
    switchProfileCountry(::getUnitCountry(unit))
    this.searchBoxWeak?.searchCancel()
    this.selectCellByUnitName(unitId)
    // In mouse mode, mouse pointer don't move to slot, so we need a highlight.
    if (!::show_console_buttons || ::is_mouse_last_time_used())
      this.doWhenActive(@() this.highlightUnitsInTree([ unitId ]))
  }

  function selectCellByUnitName(unitName)
  {
    if (!unitName || unitName == "")
      return false

    if (!checkObj(this.scene))
      return false

    let tableObj = this.scene.findObject("shop_items_list")
    if (!checkObj(tableObj))
      return false

    let tree = this.getCurTreeData().tree
    local idx = -1
    foreach(_rowIdx, row in tree)
      foreach(_colIdx, item in row) {
        if (item == null)
          continue
        idx++
        if (::isUnitGroup(item))
        {
          foreach(groupItemIdx, groupItem in item.airsGroup)
            if (groupItem.name == unitName)
            {
              let obj = this.getCellObjByValue(idx)
              if (!obj?.isValid())
                return false

              obj.scrollToView()
              tableObj.setValue(idx)
              obj.setMouseCursorOnObject()
              if (checkObj(this.groupChooseObj))
                this.groupChooseObj.findObject("airs_table").setValue(groupItemIdx)
              return true
            }
        }
        else if (item.name == unitName) {
          let obj = this.getCellObjByValue(idx)
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
      unitObj = this.getAirObj(unit.name)
      cellClass = "shopClone"
      isNewUnit = false
      getEdiffFunc = this.getCurrentEdiff.bindenv(this)
    }.__merge(params))
  }

  function onEventExpConvert(_params)
  {
    this.doWhenActiveOnce("fullReloadAircraftsList")
    this.fillGroupObj()
  }

  function onEventCrewTakeUnit(params)
  {
    foreach(param in ["unit", "prevUnit"])
    {
      let unit = getTblValue(param, params)
      if (!unit)
        continue

      this.checkUnitItemAndUpdate(unit)
    }

    this.destroyGroupChoose()
  }

  function onBack(_obj)
  {
    this.save(false)
  }
  function afterSave()
  {
    this.goBack()
  }

  function onUnitMainFunc(obj)
  {
    if (::show_console_buttons) { // open vehicle menu on slot button click
      this.onAircraftClick(obj, true)
      return
    }

    this.selectCell(obj)
    let unit = ::getAircraftByName(obj?.holderId) ?? this.getCurAircraft()
    if (!unit)
      return

    slotActions.slotMainAction(unit, {
      onSpendExcessExp = Callback(this.onSpendExcessExp, this)
      onTakeParams = {
        unitObj = this.getAirObj(unit.name)
        cellClass = "shopClone"
        isNewUnit = false
        getEdiffFunc = this.getCurrentEdiff.bindenv(this)
      }
      curEdiff = this.getCurrentEdiff()
      setResearchManually = this.setResearchManually
      availableFlushExp = this.availableFlushExp
    })
  }

  function onUnitMainFuncBtnUnHover(_obj) {
    if (!::show_console_buttons)
      return

    let unitObj = unitContextMenuState.value?.unitObj
    if (!unitObj?.isValid())
      return

    let actionListObj = unitObj.findObject("actions_list")
    if (actionListObj?.isValid())
      actionListObj.closeOnUnhover = "yes"
  }

  function onModifications(_obj)
  {
    this.msgBox("not_available", loc("msgbox/notAvailbleYet"), [["ok", function() {} ]], "ok", { cancel_fn = function() {}})
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

    this.forceUnitType = unitType
    this.doWhenActiveOnce("fillPagesListBoxNoOpenGroup")
  }

  function onEventCountryChanged(_p)
  {
    let country = profileCountrySq.value
    if (country == this.curCountry)
      return

    this.curCountry = country
    this.doWhenActiveOnce("fillPagesListBoxNoOpenGroup")
  }

  hasModeList = @() (this.showModeList?.len() ?? 0) > 2

  function initShowMode(tgtNavBar)
  {
    let obj = tgtNavBar.findObject("show_mode")
    if (!::g_login.isProfileReceived() || !checkObj(obj))
      return

    let storedMode = getShopDiffMode()
    local curMode = -1
    this.showModeList = []
    foreach(diff in ::g_difficulty.types)
      if (diff.diffCode == -1 || (!this.shopResearchMode && diff.isAvailable()))
      {
        this.showModeList.append({
          text = diff.diffCode == -1 ? loc("options/auto") : colorize("warningTextColor", diff.getLocName())
          diffCode = diff.diffCode
          enabled = true
          textStyle = "textStyle:t='textarea';"
        })
        if (storedMode == diff.diffCode)
          curMode = storedMode
      }

    if (!this.hasModeList()) {
      obj.show(false)
      obj.enable(false)
      return
    }

    storeShopDiffMode(curMode)

    foreach (item in this.showModeList)
      item.selected <- item.diffCode == curMode

    let view = {
      id = "show_mode"
      optionTag = "option"
      cb = "onChangeShowMode"
      options= this.showModeList
    }
    let data = ::handyman.renderCached("%gui/options/spinnerOptions.tpl", view)
    this.guiScene.replaceContentFromText(obj, data, data.len(), this)
    this.updateShowModeTooltip(obj)
  }

  function updateShowModeTooltip(obj)
  {
    if (!checkObj(obj))
      return
    local adviceText = loc(isAutoDiff() ? "mainmenu/showModesInfo/advice" : "mainmenu/showModesInfo/warning", { automatic = loc("options/auto") })
    adviceText = colorize(isAutoDiff() ? "goodTextColor" : "warningTextColor", adviceText)
    obj["tooltip"] = loc("mainmenu/showModesInfo/tooltip") + "\n" + adviceText
  }

  _isShowModeInChange = false
  function onChangeShowMode(obj)
  {
    if (this._isShowModeInChange)
      return
    if (!checkObj(obj))
      return

    let value = obj.getValue()
    let item = getTblValue(value, this.showModeList)
    if (!item)
      return

    this._isShowModeInChange = true
    let prevEdiff = this.getCurrentEdiff()
    storeShopDiffMode(item.diffCode)

    foreach(tgtNavBar in [this.navBarObj, this.navBarGroupObj])
    {
      if (!checkObj(tgtNavBar))
        continue

      let listObj = tgtNavBar.findObject("show_mode")
      if (!checkObj(listObj))
        continue

      if (listObj.getValue() != value)
        listObj.setValue(value)
      this.updateShowModeTooltip(listObj)
    }

    if (prevEdiff != this.getCurrentEdiff())
    {
      this.updateSlotbarDifficulty()
      this.updateTreeDifficulty()
      this.fillGroupObj()
    }
    this._isShowModeInChange = false
  }

  function getCurrentEdiff()
  {
    return this.hasModeList() ? getShopDiffCode() : ::get_current_ediff()
  }

  function updateSlotbarDifficulty()
  {

    let slotbar = topMenuHandler.value?.getSlotbar()
    if (slotbar)
      slotbar.updateDifficulty()
  }

  function updateTreeDifficulty()
  {
    if (!hasFeature("GlobalShowBattleRating"))
      return
    let curEdiff = this.getCurrentEdiff()
    let tree = this.getCurTreeData().tree
    foreach(row in tree)
      foreach(unit in row)
      {
        let unitObj = unit ? this.getUnitCellObj(unit.name) : null
        if (checkObj(unitObj))
        {
          let obj = unitObj.findObject("rankText")
          if (checkObj(obj))
            obj.setValue(::get_unit_rank_text(unit, null, true, curEdiff))

          if (!this.shopResearchMode) {
            let hasObjective = ::isUnitGroup(unit)
              ? unit.airsGroup.findindex((@(u) hasMarkerByUnitName(u.name, curEdiff))) != null
              : ::u.isUnit(unit) && hasMarkerByUnitName(unit.name, curEdiff)
            ::show_obj(unitObj.findObject("unlockMarker"), hasObjective)
          }
        }
      }
  }

  function onShopShow(show)
  {
    this.onSceneActivate(show)
    if (!show && checkObj(this.groupChooseObj))
      this.destroyGroupChoose()
    if (show)
      this.popDelayedActions()
  }

  function onEventShopWndAnimation(p)
  {
    if (!(p?.isVisible ?? false))
      return
    this.shouldBlurSceneBg = p?.isShow ?? false
    ::handlersManager.updateSceneBgBlur()
  }

  function onEventCurrentGameModeIdChanged(_params)
  {
    if (!isAutoDiff())
      return

    this.doWhenActiveOnce("updateTreeDifficulty")
  }

  function onUnitSelect() {}
  function selectRequiredUnit() {}
  function onSpendExcessExp() {}
  function updateResearchVariables() {}

  function onEventClanChanged(_params)
  {
    this.doWhenActiveOnce("fullReloadAircraftsList")
  }

  function onEventSquadronExpChanged(_params)
  {
    this.checkUnitItemAndUpdate(::getAircraftByName(::clan_get_researching_unit()))
  }

  function onEventFlushSquadronExp(params)
  {
    this.fillAircraftsList(params?.unit?.name)
  }

  getResearchingSquadronVehicle = function()
  {
    if (::clan_get_exp() <= 0)
      return null

    let unit = ::getAircraftByName(::clan_get_researching_unit())
    if(!unit)
      return null

    if (unit.shopCountry != this.curCountry || unit.unitType != lastUnitType)
      return null

    return unit
  }

  getParamsForActionsList = @() {
    setResearchManually = this.setResearchManually
    shopResearchMode = this.shopResearchMode
    onSpendExcessExp = Callback(this.onSpendExcessExp, this)
    onCloseShop = Callback(this.onCloseShop, this)
  }

  checkAirShopReq = @(air) air?.shopReq ?? true
}
