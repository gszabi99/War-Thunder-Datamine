from "%scripts/dagui_natives.nut" import clan_get_exp, shop_repair_all, shop_get_researchable_unit_name, shop_get_aircraft_hp, wp_get_repair_cost, clan_get_researching_unit, is_era_available, set_char_cb, is_mouse_last_time_used
from "%scripts/mainConsts.nut" import SEEN
from "%scripts/dagui_library.nut" import *

let { defer } = require("dagor.workcycle")
let { g_difficulty } = require("%scripts/difficulty.nut")
let { isUnitSpecial } = require("%appGlobals/ranks_common_shared.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_time_msec } = require("dagor.time")
let { format, split_by_chars } = require("string")
let { ceil, floor, abs } = require("math")
let { hangar_get_current_unit_name } = require("hangar")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { findChildIndex, move_mouse_on_child, move_mouse_on_child_by_value } = require("%sqDagui/daguiUtil.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let shopTree = require("%scripts/shop/shopTree.nut")
let shopSearchBox = require("%scripts/shop/shopSearchBox.nut")
let slotActions = require("%scripts/slotbar/slotActions.nut")
let { buy, research, canSpendGoldOnUnitWithPopup, buyUnit } = require("%scripts/unit/unitActions.nut")
let { topMenuHandler, topMenuShopActive, unitToShowInShop } = require("%scripts/mainmenu/topMenuStates.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { getStatusTbl, getTimedStatusTbl, updateCellStatus, updateCellTimedStatus, initCell, getUnitRankText, expNewNationBonusDailyBattleCount
} = require("shopUnitCellFill.nut")
let { ShopLines } = require("shopLines.nut")
let unitContextMenuState = require("%scripts/unit/unitContextMenuState.nut")
let { hideWaitIcon } = require("%scripts/utils/delayedTooltip.nut")
let { isSmallScreen } = require("%scripts/clientState/touchScreen.nut")
let getShopBlkData = require("%scripts/shop/getShopBlkData.nut")
let { hasMarkerByUnitName, getUnlockIdByUnitName,
  getUnlockIdsByArmyId } = require("%scripts/unlocks/unlockMarkers.nut")
let { getShopDiffMode, storeShopDiffMode, isAutoDiff, getShopDiffCode
} = require("%scripts/shop/shopDifficulty.nut")
let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let seenList = require("%scripts/seen/seenList.nut").get(SEEN.UNLOCK_MARKERS)
let { switchProfileCountry, profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { cutPrefix } = require("%sqstd/string.nut")
let { getDestinationRPUnitType, charSendBlk, getTopUnitsInfo } = require("chard")
let DataBlock = require("DataBlock")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { getShopDevMode, setShopDevMode, getShopDevModeOptions } = require("%scripts/debugTools/dbgShop.nut")
let { getUnitCountry, getUnitsNeedBuyToOpenNextInEra,
  getUnitName, getPrevUnit
} = require("%scripts/unit/unitInfo.nut")
let { getEsUnitType } = require("%scripts/unit/unitParams.nut")
let { canResearchUnit, isUnitGroup, isGroupPart, isUnitBroken, isUnitResearched
} = require("%scripts/unit/unitStatus.nut")
let { isUnitGift, isUnitBought } = require("%scripts/unit/unitShopInfo.nut")
let { checkForResearch } = require("%scripts/unit/unitChecks.nut")
let { get_ranks_blk } = require("blkGetters")
let { addTask } = require("%scripts/tasker.nut")
let { showUnitGoods } = require("%scripts/onlineShop/onlineShopModel.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { guiStartProfile } = require("%scripts/user/profileHandler.nut")
let takeUnitInSlotbar = require("%scripts/unit/takeUnitInSlotbar.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")
let { MAX_COUNTRY_RANK } = require("%scripts/ranks.nut")
let { buildTimeStr, getUtcMidnight } = require("%scripts/time.nut")
let { getShopVisibleCountries } = require("%scripts/shop/shopCountriesList.nut")
let { get_units_count_at_rank } = require("%scripts/shop/shopCountryInfo.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { setNationBonusMarkState, getNationBonusMarkState } = require("%scripts/nationBonuses/nationBonuses.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { getBlockFromObjData, createHighlight } = require("%scripts/guiBox.nut")
let getNavigationImagesText = require("%scripts/utils/getNavigationImagesText.nut")
let { isAnyQueuesActive } = require("%scripts/queue/queueState.nut")
let { gui_modal_convertExp } = require("%scripts/convertExpHandler.nut")
let { haveAnyUnitDiscount, getUnitDiscount } = require("%scripts/discounts/discountsState.nut")
let { generateDiscountInfo } = require("%scripts/discounts/discountUtils.nut")
let { unitNews, openUnitNews, openUnitEventNews } = require("%scripts/changelog/changeLogState.nut")

local lastUnitType = null

const OPEN_RCLICK_UNIT_MENU_AFTER_SELECT_TIME = 500 
                                                    
const LOCAL_RANK_COLLAPSED_STATE_ID = "savedCollapsedRankState" 
const CONTAINER_COLLAPSE_BTN_COUNT = 1
const BONUS_TOP_UNITS_PLATE_PADDING = "0.75@shop_height"

let armyDataByPageName = {
  aviation = {
    id = ES_UNIT_TYPE_AIRCRAFT
    locString = "mainmenu/aviation"
  }
  army = {
    id = ES_UNIT_TYPE_TANK
    locString = "mainmenu/army"
  }
  ships = {
    id = ES_UNIT_TYPE_SHIP
    locString = "mainmenu/ships"
  }
  helicopters = {
    id = ES_UNIT_TYPE_HELICOPTER
    locString = "mainmenu/helicopters"
  }
  boats = {
    id = ES_UNIT_TYPE_BOAT
    locString = "mainmenu/boats"
  }






}





















gui_handlers.ShopMenuHandler <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/shop/shopInclude.blk"
  sceneNavBlkName = "%gui/shop/shopNav.blk"
  shouldBlurSceneBg = false
  needVoiceChat = false
  keepLoaded = true
  boughtVehiclesCount = null
  totalVehiclesCount = null

  closeShop = null 
  forceUnitType = null 

  curCountry = null
  curPage = ""
  curUnitsList = null
  unitsByRank = null
  maxRank = 0
  animData = {}
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
    "research", "researchCrossPromo", "find_in_market", "use_coupon", "buy", "go_to_event", "take", "add_to_wishlist", "go_to_wishlist", "sec_weapons", "weapons",
    "showroom",




    "testflight", "crew", "goto_unlock", "info", "repair"
  ]
  shopResearchMode = false
  setResearchManually = true

  showModeList = null

  navBarObj = null
  navBarGroupObj = null
  searchBoxWeak = null
  selCellOnSearchQuit = null

  unitActionsListTimer = null
  hasSpendExpProcess = false
  actionsListOpenTime = 0
  cachedTableObj = null
  cachedUnitsStatusByRanks = null
  cachedPremiumUnitsStatusByRanks = null
  cachedPremiumSectionPos = 0
  cachedRankCollapsedState = null
  linesGenerator = null
  extraWidth = 0
  cachedTopUnitsInfo = null
  isPageHasNationBonus = false

  function initScreen() {
    this.linesGenerator = ShopLines()
    let savedColalapsedData = loadLocalAccountSettings(LOCAL_RANK_COLLAPSED_STATE_ID)
    this.cachedRankCollapsedState = DataBlock()
    if (savedColalapsedData != null)
      this.cachedRankCollapsedState.setFrom(savedColalapsedData)

    if (!this.curAirName.len()) {
      this.curCountry = profileCountrySq.get()
      let unit = getAircraftByName(hangar_get_current_unit_name())
      if (unit && unit.shopCountry == this.curCountry)
        this.curAirName = unit.name
    }

    this.skipOpenGroup = true
    this.scene.findObject("shop_timer").setUserData(this)
    this.brokenList = []
    this.curUnitsList = []
    this.animData = {}
    this.unitsByRank = {}

    this.navBarObj = this.scene.findObject("nav-help")

    this.initDevModeOptions()
    this.initShowMode(this.navBarObj)
    this.loadFullAircraftsTable(this.curAirName)

    this.fillPagesListBox()
    this.initSearchBox()
    this.skipOpenGroup = false
  }

  function findTableCellData(handler) {
    let tableObj = this.getTableObj()
    let containersCount = tableObj.childrenCount()
    local tableIndex = 0
    local threeIndex = 0
    for (local i = 0; i < containersCount; i++) {
      let rankTable = this.getRankTable(tableObj, i)
      if (rankTable == null)
        return null
      if (!rankTable.isVisible())
        continue
      let cellsContainer = rankTable.findObject("cells_container")
      let cellsCount = cellsContainer.childrenCount()
      for ( local n = 0; n < cellsCount; n++) {
        let cellObj = cellsContainer.getChild(n)
        if (!cellObj.isVisible())
          break
        let data = {cellObj, threeIndex, tableIndex = tableIndex + n, container = rankTable, containerIndex = i}
        if (handler(data))
          return data
        threeIndex++
      }
      tableIndex += cellsCount + CONTAINER_COLLAPSE_BTN_COUNT
    }
    return null
  }

  function findTableIndexByHolderOrHover(holderId = null) {
    let { tableIndex = -1 } = holderId == null
      ? this.findTableCellData(@(data) data.cellObj.isHovered())
      : this.findTableCellData(@(data) data.cellObj?.holderId == holderId)
    return tableIndex
  }

  function isSceneActive() {
    return base.isSceneActive()
           && (this.wndType != handlerType.CUSTOM || topMenuShopActive.get())
  }

  function canResearchHelicoptersOfCurCountry() {
    foreach (unit in getAllUnits())
      if (unit.isHelicopter()
          && !unit.isSquadronVehicle()
          && getUnitCountry(unit) == this.curCountry
          && canResearchUnit(unit))
        return true
    return false
  }

  function isAllCurCountryHelicoptersResearched() {
    foreach (unit in getAllUnits())
      if (unit.isHelicopter()
          && unit.isVisibleInShop()
          && !unit.isSquadronVehicle()
          && getUnitCountry(unit) == this.curCountry
          && !isUnitGift(unit)
          && !isUnitSpecial(unit)
          && !isUnitResearched(unit))
        return false
    return true
  }

  function initMoveExpToHelicoptersCheckbox() {
    if (!hasFeature("ResearchHelicopterOnGroundVehicle"))
      return

    let checkBoxObj = this.scene.findObject("move_exp_to_helicopters")
    checkBoxObj.setValue(this.isMoveExpToHelicoptersEnabled())
    checkBoxObj.show(this.curPage == "army" || this.curPage == "helicopters")
    checkBoxObj.inactiveColor = this.canResearchHelicoptersOfCurCountry()
      ? "no"
      : "yes"
  }

  function loadFullAircraftsTable(selAirName = "") {
    let shopBlkData = getShopBlkData(selAirName)
    this.shopData = shopBlkData.shopData
    this.curCountry = shopBlkData.curCountry ?? this.curCountry
    this.curPage = shopBlkData.curPage ?? this.curPage
  }

  function getCurTreeData() {
    foreach (cData in this.shopData)
      if (cData.name == this.curCountry) {
        foreach (pageData in cData.pages)
          if (pageData.name == this.curPage)
            return shopTree.generateTreeData(pageData)
        if (cData.pages.len() > 0) {
          this.curPage = cData.pages[0].name
          return shopTree.generateTreeData(cData.pages[0])
        }
      }

    this.curCountry = this.shopData[0].name
    this.curPage = this.shopData[0].pages[0].name
    return shopTree.generateTreeData(this.shopData[0].pages[0])
  }

  function countFullRepairCost() {
    this.repairAllCost = 0
    foreach (cData in this.shopData)
      if (cData.name == this.curCountry)
        foreach (pageData in cData.pages) {
          let treeData = shopTree.generateTreeData(pageData)
          foreach (rowArr in treeData.tree)
            for (local col = 0; col < rowArr.len(); col++)
              if (rowArr[col]) {
                let air = rowArr[col]
                if (air?.isFakeUnit)
                  continue

                if (isUnitGroup(air)) {
                  foreach (gAir in air.airsGroup)
                    if (gAir.isUsable() && shop_get_aircraft_hp(gAir.name) < 1.0)
                      this.repairAllCost += wp_get_repair_cost(gAir.name)
                }
                else if (air.isUsable() && shop_get_aircraft_hp(air.name) < 1.0)
                  this.repairAllCost += wp_get_repair_cost(air.name)
              }
        }
  }

  function getItemStatusData(item, checkAir = "") {
    let res = {
      shopReq = this.checkAirShopReq(item)
      own = true
      partOwn = false
      broken = false
      checkAir = checkAir == item.name
    }
    if (isUnitGroup(item)) {
      foreach (air in item.airsGroup) {
        let isOwn = isUnitBought(air)
        res.own = res.own && isOwn
        res.partOwn = res.partOwn || isOwn
        res.broken = res.broken || isUnitBroken(air)
        res.checkAir = res.checkAir || checkAir == air.name
      }
    }
    else if (item?.isFakeUnit) {
      res.own = this.isUnlockedFakeUnit(item)
    }
    else {
      res.own = isUnitBought(item)
      res.partOwn = res.own
      res.broken = isUnitBroken(item)
    }
    return res
  }

  function initUnitCells(tableObj, totalWidth, premiumWidth) {
    let cellsByRanks = this.unitsByRank
    let cellHeight = to_pixels("@shop_height")
    let shInPixels = to_pixels("sh")

    let cellHeightInPersent = 100.0 * cellHeight / shInPixels
    this.animData = {ranksHeights = [], cellHeight = cellHeightInPersent}
    let extraLeft = $"{this.extraWidth} + 1@modBlockTierNumHeight"

    local tableIndex = 0
    local maxCellY = 0
    let hasNationBonusFeature = hasFeature("ExpNewNationBonus")
    for (local rank = 0; rank <= this.maxRank; rank++) {
      if (!(rank in cellsByRanks))
        continue
      let rankCells = cellsByRanks[rank]
      if (rankCells.len() == 0)
        continue

      let rankTable = this.getRankTable(tableObj, tableIndex) ?? this.createRankTable(tableObj, tableIndex)
      let cellsContainer = rankTable.findObject("cells_container")
      cellsContainer.size = $"{totalWidth}@shop_width, ph"
      cellsContainer.pos = $"{extraLeft}, 0"

      local count = cellsContainer.childrenCount()
      let needCount = rankCells.len()
      if (needCount > count)
        this.guiScene.createMultiElementsByObject(cellsContainer, "%gui/shop/shopUnitCell.blk", "unitCell", needCount - count, this)

      count = cellsContainer.childrenCount()
      let parentPosY = maxCellY > 0 ? maxCellY + 1 : 0
      for (local i = 0; i < count; i++) {
        let cellObj = cellsContainer.getChild(i)
        if (i not in rankCells) {
          cellObj.show(false)
          cellObj.enable(false)
        } else {
          cellObj.show(true)
          cellObj.enable(true)
          let cellData = rankCells[i]
          initCell(cellObj, cellData, parentPosY)
          if (maxCellY < cellData.posY)
            maxCellY = cellData?.posY
        }
      }

      local height = $"{(maxCellY - parentPosY + 1) * cellHeightInPersent}"
      rankTable.show(true)
      rankTable.enable(true)
      rankTable.findObject("bottom_horizontal_line").show(rank == this.maxRank)
      let containerSize = $"{totalWidth}@shop_width, ph"
      let containerPos = $"{extraLeft}, -{parentPosY}@shop_height"

      let topUnitsBonus = rankTable.findObject("top_units_bonus")
      let needShowTopUnitBonus = hasNationBonusFeature && rank == this.maxRank
      topUnitsBonus.show(needShowTopUnitBonus)
      if (needShowTopUnitBonus) {
        topUnitsBonus.top = $"{maxCellY - parentPosY + 1}@shop_height + {BONUS_TOP_UNITS_PLATE_PADDING}"
        topUnitsBonus.width = $"{totalWidth - premiumWidth}@shop_width + {extraLeft} - 1.5@modArrowWidth"
        topUnitsBonus.left = "0.75@modArrowWidth"
      }

      this.animData.ranksHeights.append(height)
      let arrowsContainer = rankTable.findObject("arrows_container")
      arrowsContainer.size = containerSize
      arrowsContainer.pos = containerPos
      let alarmIconsContainer = rankTable.findObject("alarm_icons_container")
      alarmIconsContainer.size = containerSize
      alarmIconsContainer.pos = containerPos

      tableIndex += 1
    }

    while (true) {
      let rankTable = this.getRankTable(tableObj, tableIndex)
      if (rankTable == null)
        break
      rankTable.show(false)
      rankTable.enable(false)
      tableIndex++
    }
  }

  function initUnitCellsGroup(tableObj, cellsList) {
    local count = tableObj.childrenCount()
    let needCount = cellsList.len()
    if (needCount > count)
      this.guiScene.createMultiElementsByObject(tableObj, "%gui/shop/shopUnitCell.blk", "unitCell", needCount - count, this)

    count = tableObj.childrenCount()
    for (local i = 0; i < count; i++) {
      let cellObj = tableObj.getChild(i)
      if (i not in cellsList) {
        cellObj.show(false)
        cellObj.enable(false)
      }
      else
        initCell(cellObj, cellsList[i], 0)
    }
  }

  function onUnitMarkerClick(obj) {
    let unitName = obj.holderId
    guiStartProfile({
      initialSheet = "UnlockAchievement"
      curAchievementGroupName = getUnlockIdByUnitName(unitName, this.getCurrentEdiff())
    })
  }

  function onNewsMarkerClick(obj) {
    let news = unitNews.get().findvalue(@(v) v.titleshort == obj["newsId"])
    if (news != null)
      this.guiScene.performDelayed(this, @() openUnitNews(news))
  }

  function onEventMarkerClick(obj) {
    let news = unitNews.get().findvalue(@(v) v.titleshort == obj["eventId"])
    if (news != null)
      this.guiScene.performDelayed(this, @() openUnitEventNews(news))
  }

  function updateUnitCell(cellObj, unit, params = null, statusTable = null) {
    if (params == null)
      params = this.getUnitItemParams(unit)
    if (statusTable == null)
      statusTable = getStatusTbl(unit, params)
    updateCellStatus(cellObj, statusTable)
    updateCellTimedStatus(cellObj, @() getTimedStatusTbl(unit, params))
  }


  function updateCurUnitsList() {
    let tableObj = this.getTableObj()
    local index = 0
    this.cachedUnitsStatusByRanks = {}
    this.cachedPremiumUnitsStatusByRanks = {}
    for (local rank = 0; rank <= this.maxRank; rank++) {
      let units = this.unitsByRank?[rank]
      if (units == null || units.len() == 0)
        continue
      let rankTable = this.getRankTable(tableObj, index)
      index++
      if (rankTable == null)
        continue
      let cellsContainer = rankTable.findObject("cells_container")
      let childCount = cellsContainer.childrenCount()
      foreach (idx, unit in units) {
        if (idx < childCount) {
          let params = this.getUnitItemParams(unit?.unitOrGroup)
          let statusTable = getStatusTbl(unit?.unitOrGroup, params)
          if (unit?.unitOrGroup.isFakeUnit || unit?.unitOrGroup.rank != null){
            let cachedStatuses = unit.posX >= this.cachedPremiumSectionPos
              ? this.cachedPremiumUnitsStatusByRanks
              : this.cachedUnitsStatusByRanks

            let rankNum = unit?.unitOrGroup.isFakeUnit ? 0 : unit.unitOrGroup.rank
            if (!cachedStatuses?[rankNum])
              cachedStatuses[rankNum] <- []
            cachedStatuses[rankNum].append(statusTable)
          }
          this.updateUnitCell(cellsContainer.getChild(idx), unit?.unitOrGroup, params, statusTable)
        }
        else
          script_net_assert_once("shop early update", "Try to update shop units before init")
      }
    }
  }

  function getTableObj() {
    if (!this.cachedTableObj || !this.cachedTableObj.isValid())
      this.cachedTableObj = this.scene.findObject("shop_items_list")
    return this.cachedTableObj
  }

  function createRankTable(ranksContainer, containerId) {
    let view = {containerId, hasHorizontalSeparator = containerId > 0}
    let rankTableBlk = handyman.renderCached("%gui/shop/treeCellsContainer.tpl", view)
    this.guiScene.appendWithBlk(ranksContainer, rankTableBlk, this)
    return ranksContainer.findObject($"rank_table_{containerId}")
  }

  function getRankTable(ranksContainer, rank) {
    return ranksContainer.findObject($"rank_table_{rank}")
  }

  function fillAircraftsList(curName = "") {
    if (!checkObj(this.scene))
      return
    let tableObj = this.getTableObj()
    if (!checkObj(tableObj))
      return

    this.cachedTopUnitsInfo = getTopUnitsInfo()
    this.updateBoughtVehiclesCount()
    lastUnitType = this.getCurPageUnitType()
    this.isPageHasNationBonus = this.isArmyHasNationBonus(this.curCountry, lastUnitType.esUnitType)

    if (curName == "")
      curName = this.getResearchingSquadronVehicle()?.name ?? this.curAirName

    let treeData = this.getCurTreeData()
    this.brokenList = []
    let cellsList = []
    local maxCols = -1
    foreach (row, rowArr in treeData.tree)
      for (local col = 0; col < rowArr.len(); col++)
        if (rowArr[col]) {
          maxCols = max(maxCols, col)
          let unitOrGroup = rowArr[col]
          cellsList.append({ unitOrGroup, id = unitOrGroup.name, posX = col, posY = row, position = "absolute" })
        }

    tableObj.isShopItemsWide = to_pixels("@is_shop_items_wide")

    this.unitsByRank = {}
    this.unitsByRank[0] <- []
    this.curUnitsList = cellsList.map(@(c) c.unitOrGroup)
    this.maxRank = 0
    foreach (cell in cellsList) {
      if (cell?.unitOrGroup.isFakeUnit) {
        this.unitsByRank[0].append(cell)
        continue
      }
      let cellRank = cell?.unitOrGroup.rank ?? cell?.unitOrGroup[0].rank ?? 1
      this.maxRank = this.maxRank < cellRank ? cellRank : this.maxRank
      if (this.unitsByRank?[cellRank])
        this.unitsByRank[cellRank].append(cell)
      else
        this.unitsByRank[cellRank] <- [cell]
    }

    let widthStr = isSmallScreen
      ? "1@maxWindowWidth -1@modBlockTierNumHeight -1@scrollBarSize"
      : "1@slotbarWidthFull -1@modBlockTierNumHeight -1@scrollBarSize"
    let totalWidth = this.guiScene.calcString(widthStr, null)
    let itemWidth = this.guiScene.calcString("@shop_width", null)
    this.extraWidth = max(0, totalWidth - (itemWidth * treeData.sectionsPos[treeData.sectionsPos.len() - 1])) / 2
    let containersWidth = treeData.sectionsPos[treeData.sectionsPos.len()-1] - treeData.sectionsPos[0]
    this.cachedPremiumSectionPos = treeData.sectionsPos?[1] ?? treeData.sectionsPos[treeData.sectionsPos.len()-1]

    this.guiScene.setUpdatesEnabled(false, false);
    this.initUnitCells(tableObj, containersWidth, treeData.sectionsPos[treeData.sectionsPos.len()-1]
      - treeData.sectionsPos[treeData.sectionsPos.len()-2])
    this.updateCurUnitsList()
    this.fillBGLines(treeData)
    this.generateTierCollapsedIcons()

    this.guiScene.setUpdatesEnabled(true, true)

    let armyRankCollapsedData = this.getRanksCollapsedDataForArmy(this.curCountry, this.curPage)
    this.guiScene.applyPendingChanges(true) 
    for (local i = 0; i < this.maxRank; i++) {
      let rankTable = this.getRankTable(tableObj, i)
      if (rankTable == null || !rankTable.isVisible())
        continue
      let isCollapsed = armyRankCollapsedData?[$"{i}"] ?? false
      let collapseParams = {needCollapse = isCollapsed,
        isInstant = true, needForceUpdate = true,
        containerIndex = i}

      this.collapseCellsContainer(collapseParams, rankTable)
    }
    this.updateExpandAllBtnsState()

    local curIdx = -1
    foreach (idx, unit in this.curUnitsList) {
      let config = this.getItemStatusData(unit, curName)
      if (config.checkAir || ((curIdx < 0) && !unit?.isFakeUnit))
        curIdx = idx
      if (config.broken)
        this.brokenList.append(unit) 
    }

    let cellData = this.getCellDataByThreeIdx(curIdx)
    if (cellData == null)
      return
    tableObj.setValue(cellData.tableIndex)

    this.updateButtons()
    broadcastEvent("ShopUnitTypeSwitched", { esUnitType = this.getCurPageEsUnitType() })
  }

  function fullReloadAircraftsList() {
    this.loadFullAircraftsTable()
    this.fillAircraftsList()
  }

  function onEventDiscountsDataUpdated(_params = {}) {
    this.updateDiscountIconsOnTabs()
    this.updateCurUnitsList()
    this.generateTierCollapsedIcons()
  }

  function onEventUnlockMarkersCacheInvalidate(_params = {}) {
    this.updateCurUnitsList()
    this.generateTierCollapsedIcons()
  }

  function onEventPromoteUnitsChanged(_params = {}) {
    this.doWhenActiveOnce("loadFullAircraftsTable")
    this.doWhenActiveOnce("fillPagesListBoxNoOpenGroup")
  }

  function updateButtons() {
    this.updateRepairAllButton()
  }

  function showNavButton(id, show) {
    showObjById(id, show, this.navBarObj)
    if (checkObj(this.navBarGroupObj))
      showObjById(id, show, this.navBarGroupObj)
  }

  function updateRepairAllButton() {
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

  function onEventOnlineShopPurchaseSuccessful(_params) {
    this.doWhenActiveOnce("fullReloadAircraftsList")
  }

  function onEventSlotbarPresetLoaded(_p) {
    this.doWhenActiveOnce("fillAircraftsList")
  }

  function onEventProfileUpdated(p) {
    if (p.transactionType == EATT_UPDATE_ENTITLEMENTS
        || p.transactionType == EATT_BUY_ENTITLEMENT
        || p.transactionType == EATT_BUYING_UNLOCK)
      this.doWhenActiveOnce("fullReloadAircraftsList")

    this.initMoveExpToHelicoptersCheckbox()
  }

  function onEventItemsShopUpdate(_p) {
    this.doWhenActiveOnce("fillAircraftsList")
  }

  function onUpdate(_obj, dt) {
    this._timer -= dt
    if (this._timer > 0)
      return
    this._timer += 1.0

    this.checkBrokenUnitsAndUpdateThem()
    this.updateRepairAllButton()
  }

  function checkBrokenUnitsAndUpdateThem() {
    for (local i = this.brokenList.len() - 1; i >= 0; i--) {
      if (i >= this.brokenList.len()) 
        continue

      let unit = this.brokenList[i]
      if (this.checkBrokenListStatus(unit))
        this.checkUnitItemAndUpdate(unit)
    }
  }

  function getLineStatus(lc) {
    let config = this.getItemStatusData(lc.air)
    let configReq = this.getItemStatusData(lc.reqAir)

    if (config.own || config.partOwn)
      return "owned"
    else if (!config.shopReq || !(configReq.own || configReq.partOwn))
      return "locked"
    return ""
  }

  function fillBGLines(treeData) {
    this.generateHeaders(treeData)
    this.generateBGPlates(treeData)
    this.generateTierArrows(treeData)
    this.generateAirAddictiveArrows(treeData)
  }

  function generateAirAddictiveArrows(treeData) {
    this.linesGenerator.prepareGenerateLines()

    let tableObj = this.getTableObj()

    local containerIndex = 0
    local rankTable = this.getRankTable(tableObj, containerIndex)

    local datasByRanks = {}
    datasByRanks[0] <- []

    foreach (lc in treeData.lines) {
      this.fillAirReq(lc.air, lc.reqAir)
      let startLineIndex = lc.reqAir?.isFakeUnit ? 0 : lc.reqAir.rank
      let endLineIndex = lc.air?.isFakeUnit ? 0 : lc.air.rank

      for ( local i = startLineIndex; i <= endLineIndex; i++) {
        let edge = abs(lc.line[0] - lc.line[2]) == 1
          ? i > startLineIndex
            ? "top"
            : i < endLineIndex ? "bottom" : "no"
          : "no"

        if (datasByRanks?[i] == null)
          datasByRanks[i] <- [{lc, edge}]
        else
          datasByRanks[i].append({lc, edge})
      }
    }

    containerIndex = 0
    local lastRankCells = 0
    local arrowsContainer = null
    local alarmIconsContainer = null
    for (local rank = 0; rank <= this.maxRank; rank++) {
      let units = this.unitsByRank?[rank]
      if (units == null || units.len() == 0)
        continue
      lastRankCells = this.unitsByRank[rank]
      if (datasByRanks?[rank] != null) {
        rankTable = this.getRankTable(tableObj, containerIndex)
        arrowsContainer = rankTable.findObject("arrows_container")
        alarmIconsContainer = rankTable.findObject("alarm_icons_container")

        let lineArr = datasByRanks[rank]
        foreach (data in lineArr)
          this.linesGenerator.modifyOrAddLine(this, arrowsContainer, alarmIconsContainer,
            containerIndex, data.lc, this.getLineStatus(data.lc), data.edge)
      }
      containerIndex++
    }

    if (!hasFeature("ExpNewNationBonus"))
      this.linesGenerator.completeGenerateLines(this.guiScene)
    else {
      local maxCellY = 0
      foreach (cell in lastRankCells)
        maxCellY = maxCellY < cell.posY ? cell.posY : maxCellY

      local hasUnitForNationBonus = false
      foreach (cell in lastRankCells) {
        let unit = cell.unitOrGroup?.airsGroup
          ? cell.unitOrGroup.airsGroup[0]
          : cell.unitOrGroup
        let doesItGiveNationBonus = unit.getUnitWpCostBlk()?.doesItGiveNationBonus == true
        if (!doesItGiveNationBonus)
          continue
        hasUnitForNationBonus = true
        let lc = {line = [cell.posY, cell.posX, maxCellY + 1.5, cell.posX]}
        let cellStatus = this.getItemStatusData(cell.unitOrGroup)
        let arrowStatus = cellStatus.own || cellStatus.partOwn ? "owned" : "locked"
        this.linesGenerator.modifyOrAddLine(this, arrowsContainer, alarmIconsContainer, containerIndex-1, lc, arrowStatus, "no")
      }
      this.linesGenerator.completeGenerateLines(this.guiScene)

      rankTable = this.getRankTable(tableObj, containerIndex-1)
      let topUnitBonusObj = rankTable.findObject("top_units_bonus")
      topUnitBonusObj.show(hasUnitForNationBonus)

      let isNationBonusPlateActive = this.isPageNationBonusPlateActive(this.curCountry, lastUnitType.esUnitType)
      let showNationBonusObj = topUnitBonusObj.findObject("show_nation_bonus_in_tab")
      showNationBonusObj.show(isNationBonusPlateActive && hasFeature("ExpNewNationBonus"))
      showNationBonusObj.setValue(getNationBonusMarkState(this.curCountry, this.curPage))

      if (hasUnitForNationBonus) {
        let heightForTopUnitsBonus =
          to_pixels($"({BONUS_TOP_UNITS_PLATE_PADDING} + @topUnitsBonusHeight + 0.75@modArrowWidth)*100/sh")
        let heightWithoutBonus = this.animData.ranksHeights[containerIndex-1].tofloat()
        this.animData.ranksHeights[containerIndex-1] = $"{heightForTopUnitsBonus + heightWithoutBonus}"

        topUnitBonusObj["isRed"] = isNationBonusPlateActive ? "no" : "yes"
        let topBonusLabel = topUnitBonusObj.findObject("top_units_bonus_label")
        let armyLoc = armyDataByPageName?[this.curPage] ? loc(armyDataByPageName[this.curPage].locString) : ""
        topBonusLabel.setValue(loc("shop/exp_top_units_bonus", {type = armyLoc}))

        local tooltipText = ""
        if (isNationBonusPlateActive) {
          let updateTime = buildTimeStr(getUtcMidnight(), false, false)
          local countriesBonusText = ""
          let countries = getShopVisibleCountries()
          foreach (countryName in countries) {
            let countryData = this.cachedTopUnitsInfo?[countryName]
            let battlesRemainCount = countryData?.battlesRemain[lastUnitType.esUnitType] ?? 0
            if (countryData && battlesRemainCount > 0 && countryData.unitTypeWithBonuses.contains(lastUnitType.esUnitType))
              countriesBonusText = "".concat(countriesBonusText, countriesBonusText.len() > 0 ? ", " : "",
                loc(countryName), "-", battlesRemainCount.tostring())
          }
          if (countriesBonusText == "")
            countriesBonusText = "0"
          tooltipText = loc("shop/top_units_bonus_on", {time = updateTime, countries = countriesBonusText})
        } else {
          let battlesCount = expNewNationBonusDailyBattleCount
          tooltipText = loc("shop/top_units_bonus_off", {battlesCount})
        }
        let tooltipPlace = topBonusLabel.getParent()
        if (tooltipPlace)
          tooltipPlace.tooltip = tooltipText
      }
    }

    foreach (_row, rowArr in treeData.tree) 
      for (local col = 0; col < rowArr.len(); col++)
        if (isUnitGroup(rowArr[col]))
          this.fillAirReq(rowArr[col])
  }

  function generateHeaders(treeData) {
    let obj = this.scene.findObject("tree_header_div")
    let view = {
      plates = [],
      separators = [],
    }

    let sectionsTotal = treeData.sectionsPos.len() - 1
    let extraLeft = $" + {this.extraWidth} + 1@modBlockTierNumHeight"
    let extraRight = $" + {this.extraWidth} + 1@scrollBarSize - 2@frameHeaderPad"

    for (local s = 0; s < sectionsTotal; s++) {
      let isLeft = s == 0
      let isRight = s == sectionsTotal - 1

      let x = "".concat($"{treeData.sectionsPos[s]}@shop_width", isLeft ? "" : extraLeft)
      let w = "".concat($"{treeData.sectionsPos[s + 1] - treeData.sectionsPos[s]}@shop_width", isLeft ? extraLeft : "", isRight ? extraRight : "")

      let isResearchable = getTblValue(s, treeData.sectionsResearchable)
      let title = isResearchable ? "#shop/section/researchable" : "#shop/section/premium"

      view.plates.append({ title = title, x = x, w = w, hasExpandBtn = s == 0 ? "yes" : null})
      if (!isLeft)
        view.separators.append({ x = x })
    }

    let data = handyman.renderCached("%gui/shop/treeHeadPlates.tpl", view)
    this.guiScene.replaceContentFromText(obj, data, data.len(), this)
  }

  function generateBGPlates(treeData) {
    local tiersTotal = treeData.ranksHeight.len() - 1
    for (local i = tiersTotal - 1; i >= 0; i--) {
      if (treeData.ranksHeight[i] != treeData.ranksHeight[tiersTotal])
        break
      tiersTotal = i
    }

    let sectionsTotal = treeData.sectionsPos.len() - 1
    let extraLeft = $"+ {this.extraWidth} + 1@modBlockTierNumHeight"

    let  tableObj = this.getTableObj()
    local containerIndex = 0
    local rankTable = this.getRankTable(tableObj, containerIndex)
    while (rankTable != null) {
      let containerBg = rankTable.findObject("backgrounds")
      this.guiScene.replaceContentFromText(containerBg, "", 0, this)
      containerIndex++
      rankTable = this.getRankTable(tableObj, containerIndex)
    }

    containerIndex = 0
    let vertSeparators = this.scene.findObject("vertSeparators")
    this.guiScene.replaceContentFromText(vertSeparators, "", 0, this)
    for (local s = 1; s < sectionsTotal; s++) {
      let x = $"{treeData.sectionsPos[s]}@shop_width {extraLeft}"
      let vertLineData = handyman.renderCached("%gui/shop/shopVerticalSeparator.tpl", {x})
      this.guiScene.appendWithBlk(vertSeparators, vertLineData, this)
    }

    let armyRankCollapsedData = this.getRanksCollapsedDataForArmy(this.curCountry, this.curPage)
    for (local i = 0; i < tiersTotal; i++) {
      let tierUnlocked = is_era_available(this.curCountry, i + 1, this.getCurPageEsUnitType())
      let fakeRowsCount = treeData.fakeRanksRowsCount[i + 1]

      let pY = treeData.ranksHeight[i] + fakeRowsCount
      let pH = treeData.ranksHeight[i + 1] - pY
      if (pH == 0 && fakeRowsCount <= 0)
        continue

      rankTable = this.getRankTable(tableObj, containerIndex)
      let containerBg = rankTable.findObject("backgrounds")
      let fadesContainer = rankTable.findObject("fades")
      this.guiScene.replaceContentFromText(fadesContainer, "", 0, this)
      let expandBtn = rankTable.findObject($"expandBtn_{containerIndex}")
      let collapsedIcons = rankTable.findObject("collapsed_icons")

      for (local s = 0; s < sectionsTotal; s++) {
        let pX = treeData.sectionsPos[s]
        let pW = treeData.sectionsPos[s + 1] - pX
        if (pW == 0)
          continue

        let isLeft = s == 0
        let isRight = s == sectionsTotal - 1
        let isResearchable = getTblValue(s, treeData.sectionsResearchable)
        let tierType = tierUnlocked || !isResearchable ? "unlocked" : "locked"
        let x = "".concat($"{pX}@shop_width", isLeft ? "" : extraLeft)
        let w = "".concat($"{pW}@shop_width", isLeft ? extraLeft : "", isRight ? $" + {this.extraWidth}" : "")

        if (tierType == "locked") {
          let bgData = "".concat( "tdiv { position:t='absolute' background-color:t='@shopFrameLockedColor' ",
            $" pos:t='{x}, 0' size:t='{w}, ph'", "}")
          this.guiScene.appendWithBlk(containerBg, bgData, this)
        }

        let isCollapsed = armyRankCollapsedData?[$"{containerIndex}"] ?? false
        let fade = handyman.renderCached("%gui/shop/shopFade.tpl", {posX = x, width = w,
          colorFactor = isCollapsed ? 255 : 0, isRed = tierType == "locked"})
        this.guiScene.appendWithBlk(fadesContainer, fade, this)

        if (isLeft)
          expandBtn.isRed = tierType == "locked" ? "yes" : "no"
        else if (s == sectionsTotal-1) {
          collapsedIcons.width = $"{x}"
        }
      }
      containerIndex++
    }
  }

  function getRankProgressTexts(rank, ranksBlk, isTreeReserchable) {
    if (!ranksBlk)
      ranksBlk = get_ranks_blk()

    let isEraAvailable = (rank in this.totalVehiclesCount)
      && (!isTreeReserchable || is_era_available(this.curCountry, rank, this.getCurPageEsUnitType()))
    local tooltipPlate = ""
    local tooltipRank = ""
    local tooltipReqCounter = ""
    local reqCounter = ""

    if (isEraAvailable) {
      let unitsCount = this.boughtVehiclesCount[rank]
      let unitsTotal = this.totalVehiclesCount[rank]
      tooltipRank = "".concat(loc("shop/age/tooltip"), loc("ui/colon"), colorize("userlogColoredText", get_roman_numeral(rank)),
        "\n", loc("shop/tier/unitsBought"), loc("ui/colon"), colorize("userlogColoredText", format("%d/%d", unitsCount, unitsTotal)))
    }
    else {
      let unitType = this.getCurPageEsUnitType()
      for (local prevRank = rank - 1; prevRank > 0; prevRank--) {
        let unitsCount = this.boughtVehiclesCount[prevRank]
        let unitsNeed = getUnitsNeedBuyToOpenNextInEra(this.curCountry, unitType, prevRank, ranksBlk)
        let unitsLeft = max(0, unitsNeed - unitsCount)

        if (unitsLeft > 0) {
          let txtThisRank = colorize("userlogColoredText", get_roman_numeral(rank))
          let txtPrevRank = colorize("userlogColoredText", get_roman_numeral(prevRank))
          let txtUnitsNeed = colorize("badTextColor", unitsNeed)
          let txtUnitsLeft = colorize("badTextColor", unitsLeft)
          let txtCounter = format("%d/%d", unitsCount, unitsNeed)
          let txtCounterColored = colorize("badTextColor", txtCounter)

          let txtRankIsLocked = loc("shop/unlockTier/locked", { rank = txtThisRank })
          let txtNeedUnits = loc("shop/unlockTier/reqBoughtUnitsPrevRank", { prevRank = txtPrevRank, amount = txtUnitsLeft })
          let txtRankLockedDesc = loc("shop/unlockTier/desc", { rank = txtThisRank, prevRank = txtPrevRank, amount = txtUnitsNeed })
          let txtRankProgress = loc("ui/colon").concat(loc("shop/unlockTier/progress", { rank = txtThisRank }), txtCounterColored)

          if (prevRank == rank - 1) {
            reqCounter = txtCounter
            tooltipReqCounter = "\n".concat(txtRankProgress, txtNeedUnits)
          }

          tooltipRank = "\n".concat(txtRankIsLocked, txtNeedUnits, txtRankLockedDesc)
          tooltipPlate = "\n".concat(txtRankProgress, txtNeedUnits)
          break
        }
      }
    }

    return { tooltipPlate = tooltipPlate, tooltipRank = tooltipRank, tooltipReqCounter = tooltipReqCounter, reqCounter = reqCounter }
  }


  function generateTierArrows(treeData) {
    let tableObj = this.getTableObj()
    let blk = get_ranks_blk()
    let pageUnitsType = this.getCurPageEsUnitType()

    let isTreeReserchable = treeData.sectionsResearchable.contains(true)
    let cellsByRanks = this.unitsByRank

    local containerIndex = 0
    for (local rank = 0; rank <= this.maxRank; rank++) {
      if (!(rank in cellsByRanks) || cellsByRanks[rank].len() == 0)
        continue

      local needDrawArrow = (rank > 0) && (rank < this.maxRank)
      local needDrawTier = rank > 0
      let rankTable = this.getRankTable(tableObj, containerIndex)
      let container = rankTable.findObject("others")
      let tierText = rankTable.findObject($"expandbtn_{containerIndex}")
      containerIndex++

      let arrow = container.findObject("shop_arrow")
      arrow.show(needDrawArrow)
      tierText.setValue(needDrawTier ? loc("shop/age/num", {num = get_roman_numeral(rank)}) : "")
      if (!needDrawArrow && !needDrawTier)
        continue

      let modArrowPlate = container.findObject("mod_arrow_plate")
      let isRankAvailable = !isTreeReserchable || is_era_available(this.curCountry, rank, pageUnitsType)
      let status =  isRankAvailable ?  "owned" : "locked"
      let texts = this.getRankProgressTexts(rank+1, blk, isTreeReserchable)

      arrow.shopStat = status
      tierText.isRed = isRankAvailable ? "no" : "yes"

      if (texts.reqCounter == "") {
        modArrowPlate.show(false)
        continue
      }
      modArrowPlate.show(true)
      modArrowPlate.findObject("label")?.setValue(texts.reqCounter)
      modArrowPlate.tooltip = texts.tooltipReqCounter
      modArrowPlate.isRed = isRankAvailable ? "no" : "yes"
    }
  }


  function calcRankCollapsedIconData(statuses, data) {
    if (statuses == null || statuses.len() == 0)
      return
    let discounts = data.discounts
    local unitInResearchStatus = null
    foreach (status in statuses) {
      if ((status?.discount ?? 0) > 0) {
        let len = discounts.len()
        local discountAdded = false
        for (local i = 0; i < len; i++)
          if (discounts[i].discount == status.discount) {
            discounts[i].count++
            discounts[i].unitsNames = "".concat(discounts[i].unitsNames, "\n* ", status.nameText)
            discountAdded = true
            break
          }
        if (!discountAdded)
          discounts.append({discount = status.discount, count = 1, unitsNames = $"{loc("discount/notification")}\n* {status.nameText}"})
      }

      if (status?.hasObjective) {
        data.objectivesCount++
        let unitName = status?.isGroup ? getUnitName(status.markerHolderId) : status.nameText
        data.objectivesUnits = data.objectivesCount == 1
          ? "".concat(loc("mainmenu/objectiveAvailable"), "\n* ", unitName)
          : $"{data.objectivesUnits}\n* {unitName}"
      }
      if (!unitInResearchStatus && status?.shopStatus == "research" && status?.rank)
        unitInResearchStatus = status
    }

    if (this.isPageHasNationBonus && unitInResearchStatus) {
      data.hasNationBonus = true
      let battlesRemain = this.cachedTopUnitsInfo?[this.curCountry].battlesRemain[lastUnitType.esUnitType] ?? 0
      data.battlesRemain <- $"{battlesRemain}/{expNewNationBonusDailyBattleCount}"
      let isNationBonusOver = battlesRemain == 0
      data.isNationBonusOver <- isNationBonusOver ? "yes" : "no"

      data.nationBonusTooltipId <- getTooltipType("SHOP_CELL_NATION_BONUS").getTooltipId("bonus", {
        unitName = $" ({unitInResearchStatus.nameText})"
        battlesRemain
        maxRank = this.maxRank
        rank = unitInResearchStatus.rank
        isOver = isNationBonusOver
        unitTypeName = unitInResearchStatus.unitTypeName
        isRecentlyReleased = unitInResearchStatus.isRecentlyReleased
      })
    }
  }

  function generateTierCollapsedIcons() {
    let tableObj = this.getTableObj()
    local index = 0
    for (local rank = 0; rank <= this.maxRank; rank++) {
      if (this.cachedUnitsStatusByRanks?[rank] == null)
        continue
      let rankTable = this.getRankTable(tableObj, index)
      if (rankTable == null)
        continue
      index++
      let icons = { discounts = [], objectivesCount = 0, objectivesUnits = "", hasNationBonus = false }
      this.calcRankCollapsedIconData(this.cachedUnitsStatusByRanks?[rank], icons)

      let premIcons = { discounts = [], objectivesCount = 0, objectivesUnits = "", hasNationBonus = false}
      this.calcRankCollapsedIconData(this.cachedPremiumUnitsStatusByRanks?[rank], premIcons)

      let viewData = {icons, premIcons, rank, armyId = this.curPage, country = this.curCountry, }
      let data = handyman.renderCached("%gui/shop/collapsedRankIcons.tpl", viewData)
      let iconsContainer = rankTable.findObject("collapsed_icons")
      this.guiScene.replaceContentFromText(iconsContainer, data, data.len(), this)
    }
  }


  function updateBoughtVehiclesCount() {
    let bought = array(MAX_COUNTRY_RANK + 1, 0)
    let total = array(MAX_COUNTRY_RANK + 1, 0)
    let pageUnitsType = this.getCurPageEsUnitType()

    foreach (unit in getAllUnits())
      if (unit.shopCountry == this.curCountry && pageUnitsType == getEsUnitType(unit)) {
        let isOwn = isUnitBought(unit)
        if (isOwn)
          bought[unit.rank]++
        if (isOwn || unit.isVisibleInShop())
          total[unit.rank]++
      }

    this.boughtVehiclesCount = bought
    this.totalVehiclesCount = total
  }

  function fillAirReq(item, reqUnit = null) {
    local req = true
    if (item?.reqAir)
      req = isUnitBought(getAircraftByName(item.reqAir))
    if (req && reqUnit?.isFakeUnit)
      req = this.isUnlockedFakeUnit(reqUnit)
    if (isUnitGroup(item)) {
      foreach (_idx, air in item.airsGroup)
        air.shopReq = req
      item.shopReq <- req
    }
    else if (item?.isFakeUnit)
      item.shopReq <- req
    else
      item.shopReq = req
  }

  function isUnlockedFakeUnit(unit) {
    return get_units_count_at_rank(unit?.rank,
      unitTypes.getByName(unit?.isReqForFakeUnit ? split_by_chars(unit.name, "_")?[0] : unit.name,
        false).esUnitType,
      unit.country, true)
      >= (((split_by_chars(unit.name, "_"))?[1] ?? "0").tointeger() + 1)
  }

  function getCurPageEsUnitType() {
    return this.getCurPageUnitType().esUnitType
  }

  function getCurPageUnitType() {
    return unitTypes.getByArmyId(this.curPage)
  }

  function findUnitInGroupTableById(id) {
    if (checkObj(this.groupChooseObj))
      return this.groupChooseObj.findObject("airs_table").findObject(id)

    return null
  }

  function findCloneGroupObjById(id) {
    if (checkObj(this.groupChooseObj))
      return this.groupChooseObj.findObject($"clone_td_{id}")

    return null
  }

  function findAirTableObjById(id) {
    if (checkObj(this.scene))
      return this.getTableObj().findObject(id)

    return null
  }

  function getAirObj(unitName) {
    let airObj = this.findUnitInGroupTableById(unitName)
    if (checkObj(airObj))
      return airObj

    return this.findAirTableObjById(unitName)
  }

  function getUnitCellObj(unitName) {
    let cellObj = this.findUnitInGroupTableById($"unitCell_{unitName}")
    if (checkObj(cellObj))
      return cellObj

    return this.findAirTableObjById($"unitCell_{unitName}")
  }

  function checkUnitItemAndUpdate(unit) {
    if (!unit || unit?.isFakeUnit)
      return

    let unitObj = this.getUnitCellObj(unit.name)
    if ((unitObj?.isValid() ?? false) && unitObj.isVisible()) 
      this.updateUnitItem(unit, unitObj)

    ::updateAirAfterSwitchMod(unit)

    if (!isUnitGroup(unit) && isGroupPart(unit))
      this.updateGroupItem(unit.group)
  }

  function updateUnitItem(unit, cellObj) {
    if (cellObj?.isValid())
      this.updateUnitCell(cellObj, unit)
  }

  function updateGroupItem(groupName) {
    let block = this.getItemBlockFromShopTree(groupName)
    if (!block)
      return

    this.updateUnitItem(block, this.findCloneGroupObjById(groupName))
    this.updateUnitItem(block, this.findAirTableObjById($"unitCell_{groupName}"))
  }

  function checkBrokenListStatus(unit) {
    if (!unit)
      return false

    let posNum = u.find_in_array(this.brokenList, unit)
    if (!this.getItemStatusData(unit).broken && posNum >= 0) {
      this.brokenList.remove(posNum)
      return true
    }

    return false
  }

  function getUnitItemParams(unit) {
    if (!unit)
      return {}

    let is_unit = !isUnitGroup(unit) && !unit?.isFakeUnit
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
      unitTypeName = unit?.unitType.name ?? unit?.airsGroup[0].unitType.name
      hasNationBonus = this.isPageHasNationBonus
      maxRank = this.maxRank
      nationBonusBattlesRemain = this.isPageHasNationBonus
        ? this.cachedTopUnitsInfo?[this.curCountry].battlesRemain[lastUnitType.esUnitType] ?? 0
        : 0
    }
  }

  function findUnitInTree(isFits) {
    let tree = this.getCurTreeData().tree
    local idx = -1
    foreach (row, rowArr in tree)
      foreach (col, unit in rowArr)
        if (unit != null && isFits(unit, ++idx))
          return { unit = unit, row = row, col = col, idx = idx }
    return { unit = null, row = -1, col = -1, idx = -1 }
  }


  function getCellDataByThreeIdx(threeIndex) {
    return this.findTableCellData(@(data) data.threeIndex == threeIndex)
  }

  function getCellDataByTableIdx(tableIndex) {
    return this.findTableCellData(@(data) data.tableIndex == tableIndex)
  }

  getUnitByIdx = @(curIdx) this.findUnitInTree(@(_unit, idx) idx == curIdx)

  function getCurAircraft(checkGroups = true, returnDefaultUnitForGroups = false) {
    if (!checkObj(this.scene))
      return null

    local tableObj = this.getTableObj()
    let curIdx = tableObj.getValue()
    if (curIdx < 0)
      return null

    let cellData = this.getCellDataByTableIdx(curIdx)
    if (cellData == null)
      return null

    let mainTblUnit = this.getUnitByIdx(cellData.threeIndex).unit
    if (!isUnitGroup(mainTblUnit))
      return mainTblUnit

    if (checkGroups && checkObj(this.groupChooseObj)) {
      tableObj = this.groupChooseObj.findObject("airs_table")
      let idx = tableObj.getValue()
      if (idx in mainTblUnit.airsGroup)
        return mainTblUnit.airsGroup[idx]
    }

    if (returnDefaultUnitForGroups)
      return this.getDefaultUnitInGroup(mainTblUnit)

    return mainTblUnit
  }

  function getDefaultUnitInGroup(unitGroup) {
    let airsList = getTblValue("airsGroup", unitGroup)
    return getTblValue(0, airsList)
  }

  function getItemBlockFromShopTree(itemName) {
    let tree = this.getCurTreeData().tree
    for (local i = 0; i < tree.len(); ++i)
      for (local j = 0; j < tree[i].len(); ++j) {
        let name = getTblValue("name", tree[i][j])
        if (!name)
          continue

        if (itemName == name)
          return tree[i][j]
      }

    return null
  }

  function onAircraftsPage() {
    let pagesObj = this.scene.findObject("shop_pages_list")
    if (pagesObj) {
      let pageIdx = pagesObj.getValue()
      if (pageIdx < 0 || pageIdx >= pagesObj.childrenCount())
        return
      this.curPage = pagesObj.getChild(pageIdx).id
    }
    this.fillAircraftsList()
    this.initMoveExpToHelicoptersCheckbox()
  }

  function goBack() {
    if (this.closeShop)
      this.closeShop()
  }

  onCloseShop = @() this.goBack()

  function fillPagesListBoxNoOpenGroup() {
    this.skipOpenGroup = true
    this.fillPagesListBox()
    this.skipOpenGroup = false
  }

  function fillPagesListBox() {
    if (this.shopResearchMode) {
      this.fillAircraftsList()
      return
    }

    let pagesObj = this.scene.findObject("shop_pages_list")
    if (!checkObj(pagesObj))
      return

    let unitType = this.forceUnitType
      ?? lastUnitType
      ?? getAircraftByName(this.curAirName)?.unitType
      ?? unitTypes.INVALID

    this.forceUnitType = null 

    local data = ""
    local curIdx = 0
    let countryData = u.search(this.shopData, (@(curCountry) function(country) { return country.name == curCountry })(this.curCountry)) 
    if (countryData) {
      let ediff = this.getCurrentEdiff()
      let view = { tabs = [] }
      foreach (idx, page in countryData.pages) {
        let name = page.name
        view.tabs.append({
          id = name
          tabName = $"#mainmenu/{name}"
          discount = {
            discountId = this.getDiscountIconTabId(countryData.name, name)
          }
          seenIconCfg = bhvUnseen.makeConfigStr(seenList.id,
            getUnlockIdsByArmyId(this.curCountry, name, ediff))
          navImagesText = getNavigationImagesText(idx, countryData.pages.len())
          countryId = countryData.name
          armyId = name
        })

        if (name == unitType.armyId)
          curIdx = view.tabs.len() - 1
      }

      let tabCount = view.tabs.len()
      foreach (idx, tab in view.tabs)
        tab.navImagesText = getNavigationImagesText(idx, tabCount)

      data = handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
    }
    this.guiScene.replaceContentFromText(pagesObj, data, data.len(), this)

    this.updateDiscountIconsOnTabs()

    pagesObj.setValue(curIdx)
  }

  function getDiscountIconTabId(country, unitType) {
    return $"{country}_{unitType}_discount"
  }

  function updateDiscountIconsOnTabs() {
    let pagesObj = this.scene.findObject("shop_pages_list")
    if (!checkObj(pagesObj))
      return

    foreach (country in this.shopData) {
      if (country.name != this.curCountry)
        continue

      foreach (_idx, page in country.pages) {
        let tabObj = pagesObj.findObject(page.name)
        if (!checkObj(tabObj))
          continue

        let discountObj = tabObj.findObject(this.getDiscountIconTabId(this.curCountry, page.name))
        if (!checkObj(discountObj))
          continue

        let discountData = this.getDiscountByCountryAndArmyId(this.curCountry, page.name)

        let maxDiscount = discountData?.maxDiscount ?? 0
        discountObj.setValue(maxDiscount > 0 ? ($"-{maxDiscount}%") : "")
      }
      break
    }
  }

  function getDiscountByCountryAndArmyId(country, armyId) {
    if (!haveAnyUnitDiscount())
      return null

    let unitType = unitTypes.getByArmyId(armyId)
    let discountsList = {}
    foreach (unit in getAllUnits())
      if (unit.unitType == unitType
          && unit.shopCountry == country) {
        let discount = getUnitDiscount(unit)
        if (discount > 0)
          discountsList[$"{unit.name}_shop"] <- discount
      }

    return generateDiscountInfo(discountsList)
  }

  function initSearchBox() {
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

  function searchHighlight(units, isClear) {
    if (isClear)
      return this.highlightUnitsClear()
    let slots = this.highlightUnitsInTree(units.map(@(unit) unit.name))
    let tableObj = this.getTableObj()
    if (!checkObj(tableObj))
      return
    foreach (value in [ slots.valueLast, slots.valueFirst ]) {
      let cellObj = value != null ? this.getCellDataByThreeIdx(value)?.cellObj : null
      if (checkObj(cellObj))
        cellObj.scrollToView()
    }
    this.selCellOnSearchQuit = slots.valueFirst
  }

  function highlightUnitsInTree(units) {
    let shadingObj = this.scene.findObject("shop_dark_screen")
    shadingObj.show(true)
    this.guiScene.applyPendingChanges(true)

    let res = { valueFirst = null, valueLast = null }
    let highlightList = []
    let tree = this.getCurTreeData().tree
    let tableObj = this.getTableObj()
    local slotIdx = -1
    foreach (_row, rowArr in tree)
      foreach (_col, cell in rowArr) {
        if (!cell)
          continue
        slotIdx++
        let isGroup = isUnitGroup(cell)
        local isHighlight = !cell?.isFakeUnit && !isGroup && isInArray(cell?.name, units)
        if (isGroup)
          foreach (unit in cell.airsGroup)
            isHighlight = isHighlight || isInArray(unit?.name, units)
        if (!isHighlight)
          continue
        res.valueFirst = res.valueFirst ?? slotIdx
        res.valueLast  = slotIdx

        let cellData = this.getCellDataByThreeIdx(slotIdx)
        if (cellData?.container) {
          let collapseParams = {needCollapse = false, isInstant = true, containerIndex = cellData.containerIndex}
          this.collapseCellsContainer(collapseParams, cellData.container)
          this.saveRankCollapsedToData(this.curCountry, this.curPage, $"{cellData.containerIndex}", false)
          this.saveAllRankCollapsedStates()
          this.updateExpandAllBtnsState()
        }

        let objData  = {
          obj = cellData?.cellObj
          id = $"high_{slotIdx}"
          onClick = "onHighlightedCellClick"
          onDragStart = "onHighlightedCellDragStart"
          isNoDelayOnClick = true
        }
        highlightList.append(getBlockFromObjData(objData, tableObj))
      }

    createHighlight(shadingObj, highlightList, this, {
      onClick = "onShadedCellClick"
      lightBlock = "tdiv"
      sizeIncAdd = 0
      isFullscreen = false
    })

    return res
  }

  function searchCancel() {
    this.highlightUnitsClear()

    if (this.selCellOnSearchQuit != null) {
      let tableObj = this.getTableObj()
      if (checkObj(tableObj)) {
        let cellData = this.getCellDataByThreeIdx(this.selCellOnSearchQuit)
        if (cellData == null)
          return
        this.skipOpenGroup = true
        tableObj.setValue(cellData.tableIndex)
        let obj = cellData.cellObj
        if (obj)
          obj.setMouseCursorOnObject()
        this.skipOpenGroup = false
      }
      this.selCellOnSearchQuit = null
    }
  }

  function highlightUnitsClear() {
    let shadingObj = this.scene.findObject("shop_dark_screen")
    if (checkObj(shadingObj))
      shadingObj.show(false)
  }

  function onHighlightedCellDragStart(obj) {
    let value = to_integer_safe(cutPrefix(obj?.id, "high_"), -1, false)
    if (value < 0)
      return

    let cellData = this.getCellDataByThreeIdx(value)
    if (cellData == null)
      return

    let unit = getAircraftByName(cellData?.cellObj.holderId)
    if (!unit)
      return

    takeUnitInSlotbar(unit, this.getOnTakeUnitParams(unit, { dragAndDropMode = true }))

    this.highlightUnitsClear()
  }

  function onHighlightedCellClick(obj) {
    let value = to_integer_safe(cutPrefix(obj?.id, "high_") ?? "-1", -1, false)
    if (value >= 0)
      this.selCellOnSearchQuit = value
    this.guiScene.performDelayed(this, function() {
      if (this.isValid())
        this.searchBoxWeak?.searchCancel()
    })
  }

  function onShadedCellClick(_obj) {
    if (this.searchBoxWeak)
      this.searchBoxWeak.searchCancel()
  }

  function openMenuForUnit(unit, ignoreMenuHover = false) {
    if ("name" not in unit)
      return
    local curAirObj = this.scene.findObject(unit.name)
    if (curAirObj == null && this.groupChooseObj?.isValid())
      curAirObj = this.groupChooseObj.findObject(unit.name)
    if (curAirObj?.isValid())
      this.openUnitActionsList(curAirObj, false, ignoreMenuHover)
  }


  function selectCell(obj) {
    let tableObj = this.getTableObj()
    let holderId = obj?.holderId

    if (!this.groupChooseObj?.isValid()) {
      let childIndex = this.findTableIndexByHolderOrHover(holderId)
      if (childIndex >= 0 && tableObj.getValue() != childIndex)
        tableObj.setValue(childIndex)
      return
    }

    local listObj = this.groupChooseObj.findObject("airs_table")
    let idx = findChildIndex(listObj, holderId == null
      ? @(c) c.isHovered()
      : @(c) c?.holderId == holderId)

    if (idx < 0 || idx == listObj.getValue())
      return
    listObj.setValue(idx)
  }

  function getCurListObj() {
    if (this.groupChooseObj?.isValid())
      return this.groupChooseObj.findObject("airs_table")
    else
      return this.getTableObj()
  }

  function onUnitActivate(obj) {
    if (findChildIndex(obj, @(c) c.isHovered()) == -1)
      return

    hideWaitIcon()
    this.onAircraftClick(obj)
  }

  function onAircraftClick(obj, ignoreMenuHover = false) {
    this.selectCell(obj)
    let unit = this.getCurAircraft()
    this.curAirName = unit?.name ?? ""
    this.checkSelectAirGroup(unit)
    this.openMenuForUnit(unit, ignoreMenuHover)
  }

  function onUnitDblClick(obj) {
    if (!showConsoleButtons.get()) 
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

  getOnTakeUnitParams = @(unit, ovr = {}) {
    unitObj = this.getAirObj(unit.name)
    cellClass = "shopClone"
    isNewUnit = false
    getEdiffFunc = this.getCurrentEdiff.bindenv(this)
  }.__update(ovr)

  function onUnitCellDragStart(obj) {
    let unit = getAircraftByName(obj?.id)
    if (!unit)
      return
    takeUnitInSlotbar(unit, this.getOnTakeUnitParams(unit, { dragAndDropMode = true }))
  }

  onUnitCellDrop = @() null

  function checkSelectAirGroup(item, selectUnitName = "") {
    if (this.skipOpenGroup || this.groupChooseObj || !item || !isUnitGroup(item))
      return
    let silObj = this.getTableObj()
    if (!checkObj(silObj))
      return
    let grObj = silObj.findObject(item.name)
    if (!checkObj(grObj))
      return

    this.skipOpenGroup = true
    
    let tdObj = grObj.getParent()
    let tdPos = tdObj.getPosRC()
    let tdSize = tdObj.getSize()
    let leftPos = $"{tdPos[0] + tdSize[0] / 2} -50%w"

    let cellHeight = tdSize[1] ?? 86 
    let screenHeight = screen_height()
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

  function fillGroupObjAnimParams(tdSize, tdPos) {
    let animObj = this.groupChooseObj.findObject("tablePlace")
    if (!animObj)
      return
    let size = animObj.getSize()
    if (!size[1])
      return

    animObj["height-base"] = tdSize[1].tostring()
    animObj["height-end"] = size[1].tostring()

    
    let heightDiff = size[1] - tdSize[1]
    if (heightDiff <= 0)
      return

    let pos = animObj.getPosRC()
    let topPart = (tdPos[1] - pos[1]).tofloat() / heightDiff
    let animFixedY = tdPos[1] + topPart * tdSize[1]
    animObj.top = format("%d - %fh", animFixedY.tointeger(), topPart)
  }

  function updateGroupObjNavBar() {
    this.navBarGroupObj = this.groupChooseObj.findObject("nav-help-group")
    this.navBarGroupObj.hasMaxWindowSize = isSmallScreen ? "yes" : "no"
    this.initShowMode(this.navBarGroupObj)
    this.updateButtons()
  }

  function fillGroupObjArrows(group) {
    local unitPosNum = 0
    local prevGroupUnit = null
    let lines = []
    foreach (unit in group) {
      if (!unit || unit.isSlave())
        continue
      let reqUnit = getPrevUnit(unit)
      if (reqUnit  && prevGroupUnit
          && reqUnit.name == prevGroupUnit.name) {
        local status = isUnitBought(prevGroupUnit) || isUnitBought(unit)
                       ? ""
                       : "locked"
        lines.append(this.linesGenerator.createLine("", unitPosNum - 1, 0, unitPosNum, 0, status))
      }
      prevGroupUnit = unit
      unitPosNum++
    }
    return "".join(lines)
  }

  function fillGroupObj(selectUnitName = "") {
    if (!checkObj(this.scene) || !checkObj(this.groupChooseObj))
      return

    let item = this.getCurAircraft(false)
    if (!item || !isUnitGroup(item))
      return

    let gTblObj = this.groupChooseObj.findObject("airs_table")
    if (!checkObj(gTblObj))
      return

    if (selectUnitName == "") {
      let groupUnit = this.getDefaultUnitInGroup(item)
      if (groupUnit)
        selectUnitName = groupUnit.name
    }
    this.fillUnitsInGroup(gTblObj, item.airsGroup, selectUnitName)

    let lines = this.fillGroupObjArrows(item.airsGroup)
    this.guiScene.appendWithBlk(this.groupChooseObj.findObject("arrows_nest"), lines, this)

    foreach (unit in item.airsGroup)
      if (isUnitBroken(unit))
        u.appendOnce(unit, this.brokenList)
  }

  function fillUnitsInGroup(tblObj, unitList, selectUnitName = "") {
    let selected = unitList.findindex(@(unit) selectUnitName == unit.name) ?? tblObj.getValue()
    this.initUnitCellsGroup(tblObj, unitList.map(@(unit) { id = unit.name, position = "relative" }))
    foreach (idx, unit in unitList)
      this.updateUnitCell(tblObj.getChild(idx), unit)

    tblObj.setValue(selected)
    move_mouse_on_child(tblObj, selected)
  }

  function onSceneActivate(show) {
    this.scene.enable(show)
    base.onSceneActivate(show)
    if (!show)
      this.destroyGroupChoose()
  }

  function onDestroy() {
    this.destroyGroupChoose()
  }

  function destroyGroupChoose(destroySpecGroupName = "") {
    if (!checkObj(this.groupChooseObj)
        || (destroySpecGroupName != "" &&
            destroySpecGroupName == this.groupChooseObj.group))
      return

    this.guiScene.destroyElement(this.groupChooseObj)
    this.groupChooseObj = null
    this.updateButtons()
    broadcastEvent("ModalWndDestroy")
    move_mouse_on_child_by_value(this.getTableObj())
  }

  function destroyGroupChooseDelayed() {
    this.guiScene.performDelayed(this, this.destroyGroupChoose)
  }

  function onCancelSlotChoose(_obj) {
    if (checkObj(this.groupChooseObj))
      this.destroyGroupChooseDelayed()
  }

  function onRepairAll(_obj) {
    let cost = Cost()
    cost.wp = this.repairAllCost

    if (!checkBalanceMsgBox(cost))
      return

    this.taskId = shop_repair_all(this.curCountry, false)
    if (this.taskId < 0)
      return

    set_char_cb(this, this.slotOpCb)
    this.showTaskProgressBox()

    this.afterSlotOp = function() {
      this.showTaskProgressBox()
      this.checkBrokenUnitsAndUpdateThem()
      broadcastEvent("UnitRepaired")
      this.destroyProgressBox()
    }
  }

  function onEventUnitRepaired(params) {
    let unit = getTblValue("unit", params)

    if (this.checkBrokenListStatus(unit))
      this.checkUnitItemAndUpdate(unit)

    this.updateRepairAllButton()
  }

  function onEventSparePurchased(params) {
    if (!this.scene.isEnabled() || !this.scene.isVisible())
      return
    this.checkUnitItemAndUpdate(getTblValue("unit", params))
  }

  function onEventModificationPurchased(params) {
    if (!this.scene.isEnabled() || !this.scene.isVisible())
      return
    this.checkUnitItemAndUpdate(getTblValue("unit", params))
  }

  function onEventAllModificationsPurchased(params) {
    if (!this.scene.isEnabled() || !this.scene.isVisible())
      return
    this.checkUnitItemAndUpdate(getTblValue("unit", params))
  }

  function onEventUpdateResearchingUnit(params) {
    let unitName = getTblValue("unitName", params, shop_get_researchable_unit_name(this.curCountry, this.getCurPageEsUnitType()))
    this.checkUnitItemAndUpdate(getAircraftByName(unitName))
  }

  function onOpenOnlineShop(_obj) {
    showUnitGoods(this.getCurAircraft().name, "shop")
  }

  function onBuy() {
    buy(this.getCurAircraft(true, true), "shop")
  }

  function onResearch(_obj) {
    let unit = this.getCurAircraft()
    if (!unit || isUnitGroup(unit) || unit?.isFakeUnit || !checkForResearch(unit))
      return

    research(unit)
  }

  function onConvert(_obj) {
    let unit = this.getCurAircraft()
    if (!unit || !canSpendGoldOnUnitWithPopup(unit))
      return

    let unitName = unit.name
    this.selectCellByUnitName(unitName)
    gui_modal_convertExp(unit)
  }

  function onEventUnitResearch(params) {
    if (!checkObj(this.scene))
      return

    let prevUnitName = getTblValue("prevUnitName", params)
    let unitName = getTblValue("unitName", params)

    if (prevUnitName && prevUnitName != unitName)
      this.checkUnitItemAndUpdate(getAircraftByName(prevUnitName))

    let unit = getAircraftByName(unitName)
    this.updateResearchVariables()
    this.checkUnitItemAndUpdate(unit)

    this.selectCellByUnitName(unit)

    if (this.shopResearchMode && this.availableFlushExp <= 0) {
      buyUnit(unit)
      this.onCloseShop()
    }
  }

  function onEventUnitBought(params) {
    let { unitName = null, needSelectCrew = true } = params
    let unit = unitName ? getAircraftByName(unitName) : null
    if (!unit)
      return

    if (getTblValue("receivedFromTrophy", params, false) && unit.isVisibleInShop()) {
      this.doWhenActiveOnce("fullReloadAircraftsList")
      return
    }

    this.updateResearchVariables()
    this.fillAircraftsList(unitName)
    this.fillGroupObj()

    if (!this.isSceneActive())
      return

    if (needSelectCrew && !isAnyQueuesActive())
      takeUnitInSlotbar(unit, {
        unitObj = this.getAirObj(unit.name)
        cellClass = "shopClone"
        isNewUnit = true
        getEdiffFunc = this.getCurrentEdiff.bindenv(this)
        afterSuccessFunc = this.shopResearchMode ? Callback(@() this.selectRequiredUnit(), this) : null
      })
    else if (this.shopResearchMode)
      this.selectRequiredUnit()
  }

  function onEventDebugUnlockEnabled(_params) {
    this.doWhenActiveOnce("fullReloadAircraftsList")
  }

  function onEventUnitRented(params) {
    this.onEventUnitBought(params)
  }

  function showUnitInShop(unitId) {
    if (!this.isSceneActive() || isAnyQueuesActive() || this.shopResearchMode)
      return

    this.highlightUnitsClear()
    if (unitId == null)
      return

    let unit = getAircraftByName(unitId)
    if (!unit || !unit.isVisibleInShop())
      return

    this.curAirName = unitId
    this.setUnitType(unit.unitType)
    switchProfileCountry(getUnitCountry(unit))
    this.searchBoxWeak?.searchCancel()
    this.selectCellByUnitName(unitId)
    
    if (!showConsoleButtons.get() || is_mouse_last_time_used())
      this.doWhenActive(@() this.highlightUnitsInTree([ unitId ]))
    unitToShowInShop.set(null)
  }

  function selectCellByUnitName(unitName) {
    if (!unitName || unitName == "")
      return false

    if (!checkObj(this.scene))
      return false

    let tableObj = this.getTableObj()
    if (!checkObj(tableObj))
      return false

    let tree = this.getCurTreeData().tree
    local idx = -1
    foreach (_rowIdx, row in tree)
      foreach (_colIdx, item in row) {
        if (item == null)
          continue
        idx++
        if (isUnitGroup(item)) {
          foreach (groupItemIdx, groupItem in item.airsGroup)
            if (groupItem.name == unitName) {
              let cellData = this.getCellDataByThreeIdx(idx)
              if (cellData == null)
                return false
              let obj = cellData.cellObj
              if (!obj?.isValid())
                return false

              defer(@() obj?.isValid() ? obj.scrollToView() : null)
              tableObj.setValue(cellData.tableIndex)
              obj.setMouseCursorOnObject()
              if (checkObj(this.groupChooseObj))
                this.groupChooseObj.findObject("airs_table").setValue(groupItemIdx)
              return true
            }
        }
        else if (item.name == unitName) {
          let cellData = this.getCellDataByThreeIdx(idx)
          let obj = cellData?.cellObj
          if (!obj?.isValid())
            return false

          defer(@() obj?.isValid() ? obj.scrollToView() : null)
          tableObj.setValue(cellData.tableIndex)
          obj.setMouseCursorOnObject()
          return true
        }
      }
    return false
  }

  function onEventExpConvert(_params) {
    this.doWhenActiveOnce("fillAircraftsList")
    this.fillGroupObj()
  }

  function onEventCrewTakeUnit(params) {
    foreach (param in ["unit", "prevUnit"]) {
      let unit = getTblValue(param, params)
      if (!unit)
        continue
      this.doWhenActive(@() this.checkUnitItemAndUpdate(unit))
    }

    this.destroyGroupChoose()
  }

  function onBack(_obj) {
    this.save(false)
  }
  function afterSave() {
    base.goBack()
  }

  function onUnitMainFunc(obj) {
    if (showConsoleButtons.get()) { 
      this.onAircraftClick(obj, true)
      return
    }

    this.selectCell(obj)
    let unit = getAircraftByName(obj?.holderId) ?? this.getCurAircraft()
    if (!unit)
      return
    this.curAirName = unit.name

    slotActions.slotMainAction(unit, {
      onSpendExcessExp = Callback(this.onSpendExcessExp, this)
      onTakeParams = this.getOnTakeUnitParams(unit)
      curEdiff = this.getCurrentEdiff()
      setResearchManually = this.setResearchManually
      availableFlushExp = this.availableFlushExp
    })
  }

  function onUnitMainFuncBtnUnHover(_obj) {
    if (!showConsoleButtons.get())
      return

    let unitObj = unitContextMenuState.value?.unitObj
    if (!unitObj?.isValid() || unitContextMenuState.value?.needClose)
      return

    let actionListObj = unitObj.findObject("actions_list")
    if (actionListObj?.isValid())
      actionListObj.closeOnUnhover = "yes"
  }

  function onModifications(_obj) {
    this.msgBox("not_available", loc("msgbox/notAvailbleYet"), [["ok", function() {} ]], "ok", { cancel_fn = function() {} })
  }

  function checkTag(aircraft, tag) {
    if (!tag)
      return true
    return isInArray(tag, aircraft.tags)
  }

  function setUnitType(unitType) {
    if (unitType == lastUnitType)
      return

    this.forceUnitType = unitType
    this.doWhenActiveOnce("fillPagesListBoxNoOpenGroup")
  }

  function onEventCountryChanged(_p) {
    let country = profileCountrySq.get()
    if (country == this.curCountry)
      return

    this.curCountry = country
    this.doWhenActiveOnce("fillPagesListBoxNoOpenGroup")
  }

  function onMoveExpToHelicoptersChange(checkBoxObj) {
    let isCheckboxSelected = checkBoxObj.getValue()
    if (isCheckboxSelected == this.isMoveExpToHelicoptersEnabled())
      return

    if (isCheckboxSelected && !this.canResearchHelicoptersOfCurCountry()) {
      checkBoxObj.setValue(false)
      let cannotResearchReason = this.isAllCurCountryHelicoptersResearched()
        ? loc("shop/all_helicopters_researched")
        : loc("shop/no_helicopters_to_research")

      this.msgBox(
        "cannot_research_helicopters",
        cannotResearchReason,
        [["ok", function() {} ]],
        "ok",
        { cancel_fn = function() {} }
      )
      return
    }

    if (isCheckboxSelected)
      this.msgBox("move_exp_to_heli_confirm",
      loc("shop/research_helicopters_by_ground_vehicles_confirm"),
      [
        ["yes", Callback(@() this.moveExpToHeli(true), this)],
        ["no", Callback(@() checkBoxObj.setValue(false), this)]
      ], "yes", { cancel_fn = Callback(@() checkBoxObj.setValue(false), this) })
    else
      this.moveExpToHeli(false)
  }

  function moveExpToHeli(isSelected) {
    let destType = isSelected ? ES_UNIT_TYPE_HELICOPTER : ES_UNIT_TYPE_INVALID
    let blk = DataBlock()
    blk.addStr("country", this.curCountry);
    blk.setInt("destType", destType);
    blk.setInt("srcType", ES_UNIT_TYPE_TANK);
    addTask(charSendBlk("cln_set_dest_rp_unit_type", blk), { showProgressBox = true })
  }

  hasModeList = @() (this.showModeList?.len() ?? 0) > 2

  function isMoveExpToHelicoptersEnabled() {
    return getDestinationRPUnitType(this.curCountry, ES_UNIT_TYPE_TANK) == ES_UNIT_TYPE_HELICOPTER
  }

  function initShowMode(tgtNavBar) {
    let obj = tgtNavBar.findObject("show_mode")
    if (!isProfileReceived.get() || !checkObj(obj))
      return

    let storedMode = getShopDiffMode()
    local curMode = -1
    this.showModeList = []
    foreach (diff in g_difficulty.types)
      if (diff.diffCode == -1 || (!this.shopResearchMode && diff.isAvailable())) {
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
      options = this.showModeList
    }
    let data = handyman.renderCached("%gui/options/spinnerOptions.tpl", view)
    this.guiScene.replaceContentFromText(obj, data, data.len(), this)
    this.updateShowModeTooltip(obj)
  }

  function initDevModeOptions() {
    let mode = getShopDevMode()
    let obj = showObjById("dev_options_select", mode != null, this.navBarObj)
    if (!mode)
      return

    let devModOptionsView = {
      optionTag = "option"
      options = getShopDevModeOptions()
    }
    let data = handyman.renderCached("%gui/options/spinnerOptions.tpl", devModOptionsView)

    this.guiScene.replaceContentFromText(obj, data, data.len(), this)
  }

  function updateShowModeTooltip(obj) {
    if (!checkObj(obj))
      return
    local adviceText = loc(isAutoDiff() ? "mainmenu/showModesInfo/advice" : "mainmenu/showModesInfo/warning", { automatic = loc("options/auto") })
    adviceText = colorize(isAutoDiff() ? "goodTextColor" : "warningTextColor", adviceText)
    obj["tooltip"] = "\n".concat(loc("mainmenu/showModesInfo/tooltip"), adviceText)
  }

  _isShowModeInChange = false
  function onChangeShowMode(obj) {
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

    foreach (tgtNavBar in [this.navBarObj, this.navBarGroupObj]) {
      if (!checkObj(tgtNavBar))
        continue

      let listObj = tgtNavBar.findObject("show_mode")
      if (!checkObj(listObj))
        continue

      if (listObj.getValue() != value)
        listObj.setValue(value)
      this.updateShowModeTooltip(listObj)
    }

    if (prevEdiff != this.getCurrentEdiff()) {
      this.updateSlotbarDifficulty()
      this.updateTreeDifficulty()
      this.fillGroupObj()
    }
    this._isShowModeInChange = false
  }

  function onChangeDevMode(obj) {
    let { value } = getShopDevModeOptions()[obj.getValue()]
    setShopDevMode(value)
  }

  function onEventShopDevModeChange(_p) {
    this.initDevModeOptions()
    this.doWhenActiveOnce("fillAircraftsList")
  }

  function getCurrentEdiff() {
    return this.hasModeList() ? getShopDiffCode() : getCurrentGameModeEdiff()
  }

  function updateSlotbarDifficulty() {

    let slotbar = topMenuHandler.get()?.getSlotbar()
    if (slotbar)
      slotbar.updateDifficulty()
  }

  function updateTreeDifficulty() {
    if (!hasFeature("GlobalShowBattleRating"))
      return
    let curEdiff = this.getCurrentEdiff()
    let tree = this.getCurTreeData().tree
    foreach (row in tree)
      foreach (unit in row) {
        let unitObj = unit ? this.getUnitCellObj(unit.name) : null
        if (checkObj(unitObj)) {
          let obj = unitObj.findObject("rankText")
          if (checkObj(obj))
            obj.setValue(getUnitRankText(unit, true, curEdiff))

          if (!this.shopResearchMode) {
            let hasObjective = isUnitGroup(unit)
              ? unit.airsGroup.findindex((@(groupUnit) hasMarkerByUnitName(groupUnit.name, curEdiff))) != null
              : u.isUnit(unit) && hasMarkerByUnitName(unit.name, curEdiff)
            unitObj.findObject("unlockMarker")["isActive"] = hasObjective ? "yes" : "no"
          }
        }
      }
  }

  function onShopShow(show) {
    if (!show && checkObj(this.groupChooseObj))
      this.destroyGroupChoose()
  }

  function onExpandBtnClick(obj) {
    let containerIndex = obj.id.slice(10).tointeger() 
    this.toggleCellsContainer(containerIndex)
  }

  function onExpandAllBtn(obj) {
    let needCollapse = obj.isCollapsed == "no"
    this.collapseAllCellsContainers(needCollapse)
  }

  function setExpandAllBtnState(needCollapse) {
    let expandAllBtn = this.scene.findObject("title_expand_btn")
    if (expandAllBtn) {
      expandAllBtn.isCollapsed = needCollapse ? "yes" : "no"
      expandAllBtn["tooltip"] = loc(needCollapse ? "mainmenu/btnExpandAll" : "mainmenu/btnCollapseAll")
    }
  }

  function collapseAllCellsContainers(needCollapse, params = null) {
    let {needInstantAnim = false} = params
    let tableObj = this.getTableObj()
    local containerIndex = 0
    local rankTable = this.getRankTable(tableObj, containerIndex)
    while (rankTable != null) {
      if (rankTable.isVisible() && (needCollapse != (rankTable.isCollapsed == "yes"))) {
        let collapsParams = {needCollapse, isInstant = needInstantAnim, containerIndex}
        this.collapseCellsContainer(collapsParams, rankTable)
        this.saveRankCollapsedToData(this.curCountry, this.curPage, $"{containerIndex}", needCollapse)
      }
      containerIndex++
      rankTable = this.getRankTable(tableObj, containerIndex)
    }
    this.setExpandAllBtnState(needCollapse)
    this.saveAllRankCollapsedStates()
  }


  function toggleCellsContainer(containerIndex, table = null) {
    local rankTable = table
    if (rankTable == null) {
      let tableObj = this.getTableObj()
      rankTable = this.getRankTable(tableObj, containerIndex)
    }
    let needCollapse = rankTable.isCollapsed == "no"
    this.collapseCellsContainer({needCollapse, isInstant = false, containerIndex}, rankTable)
    this.saveRankCollapsedToData(this.curCountry, this.curPage, $"{containerIndex}", needCollapse)
    this.saveAllRankCollapsedStates()
    this.updateExpandAllBtnsState()
  }


  function collapseCellsContainer(params, table = null) {
    let {needCollapse = false, isInstant = false,
      containerIndex = -1, needForceUpdate = false} = params

    local rankTable = table
    if (rankTable == null) {
      let tableObj = this.getTableObj()
      rankTable = this.getRankTable(tableObj, containerIndex)
    }

    let isCollapsed = rankTable.isCollapsed == "yes"
    if (!needForceUpdate && isCollapsed == needCollapse)
      return

    rankTable.isCollapsed = needCollapse ? "yes" : "no"
    let expandBtn = rankTable.findObject($"expandbtn_{containerIndex}")
    expandBtn["tooltip"] = loc(needCollapse ? "mainmenu/btnExpand" : "mainmenu/btnCollapse")

    let height = this.animData.ranksHeights[containerIndex]
    let collapseHeight = floor(this.animData.cellHeight*0.75).tostring()

    expandBtn.isCollapsed = needCollapse ? "yes" : "no"

    rankTable["height-base"] = needCollapse ? height : collapseHeight
    rankTable["height-end"] = needCollapse ? collapseHeight : height
    rankTable.findObject("collapsed_icons").show(needCollapse)

    if (isInstant)
      rankTable.height = $"{needCollapse ? collapseHeight : height }*sh/100.0"
    else {
      rankTable["_size-timer"] = 0
      rankTable.setFloatProp(dagui_propid_add_name_id("_size-timer"), 0)
    }

    let cellsContainer = rankTable.findObject("cells_container")
    let cellsCount = cellsContainer.childrenCount()
    for (local i = 0; i < cellsCount; i++)
      cellsContainer.getChild(i).interactive = needCollapse ? "no" : "yes"

    let fadesContainer = rankTable.findObject("fades")
    fadesContainer.show(needCollapse || !isInstant)

    let arrowPlateCircle = rankTable.findObject("arrow_plate_circle")
    arrowPlateCircle["height-base"] = needCollapse ? 100 : 0
    arrowPlateCircle["height-end"] = needCollapse ? 0 : 100
    if (isInstant)
      arrowPlateCircle["height"] = needCollapse ? 0 : "pw"
    else {
      arrowPlateCircle["_size-timer"] = 0
      arrowPlateCircle.setFloatProp(dagui_propid_add_name_id("_size-timer"), 0)
    }

    for (local i = 0; i < fadesContainer.childrenCount(); i++) {
      let fadeObj = fadesContainer.getChild(i)
      fadeObj["transp-base"] = needCollapse ? 0 : 255
      fadeObj["transp-end"] = needCollapse ? 255 : 0
      if (isInstant)
        fadeObj["color-factor"] = $"{needCollapse ? 255 : 0 }"
      else {
        fadeObj["_transp-timer"] = 0
        fadeObj.setFloatProp(dagui_propid_add_name_id("_transp-timer"), 0)
      }
    }

    local alarmsIcons = this.linesGenerator.getAddedLinesByType(containerIndex, "alarmIcon_vertical")
    foreach (data in alarmsIcons) {
      let alarmIcon = data.obj
      if (alarmIcon.onEdge == "bottom")
        alarmIcon.show(!needCollapse)
    }

    if (needCollapse || isInstant || needForceUpdate)
      this.updateNextRankAlarmIcons(containerIndex, needCollapse)
  }

  function updateNextRankAlarmIcons(containerIndex, isCollapsed) {
    let nextRanTable = this.getRankTable(this.getTableObj(), containerIndex + 1)
    if (nextRanTable != null) {
      let alarmsIcons = this.linesGenerator.getAddedLinesByType(containerIndex + 1, "alarmIcon_vertical")
      foreach (data in alarmsIcons) {
        let alarmIcon = data.obj
        if (alarmIcon.onEdge == "top")
          alarmIcon.show(!isCollapsed)
      }
    }
  }

  function updateExpandAllBtnsState() {
    let tableObj = this.getTableObj()
    let armyData = this.getRanksCollapsedDataForArmy(this.curCountry, this.curPage)
    local isAllCollapsed = true
    local isAllExpanded = true
    for (local i = 0; i < this.maxRank; i++) {
      let rankTable = this.getRankTable(tableObj, i)
      if (rankTable == null || !rankTable.isVisible())
        break
      let rankIsCollapsed = armyData?[$"{i}"] ?? false
      isAllExpanded = isAllExpanded && !rankIsCollapsed
      isAllCollapsed = isAllCollapsed && rankIsCollapsed
    }
    if (isAllCollapsed || isAllExpanded)
      this.setExpandAllBtnState(isAllCollapsed)
  }

  function onRankAnimFinish(rankTable) {
    let isCollapseAnim = rankTable.isCollapsed == "yes"
    if (!isCollapseAnim) {
      let fadesContainer = rankTable.findObject("fades")
      fadesContainer.show(false)
      this.updateNextRankAlarmIcons(to_integer_safe(rankTable.containerIndex), isCollapseAnim)
    }
  }

  function onEventShopWndAnimation(p) {
    if (!(p?.isVisible ?? false))
      return
    this.shouldBlurSceneBg = p?.isShow ?? false
    this.onSceneActivate(p?.isShow ?? false)
    handlersManager.updateSceneBgBlur()
  }

  function onEventCurrentGameModeIdChanged(_params) {
    if (!isAutoDiff())
      return

    this.doWhenActiveOnce("updateTreeDifficulty")
  }

  function saveAllRankCollapsedStates() {
    saveLocalAccountSettings(LOCAL_RANK_COLLAPSED_STATE_ID, this.cachedRankCollapsedState)
  }

  function getRanksCollapsedDataForArmy(country, army,) {
    if (this.cachedRankCollapsedState?[country] == null)
      return null
    let countryData = this.cachedRankCollapsedState[country]
    return countryData?[army]
  }

  function saveRankCollapsedToData(country, army, rank, isCollapsed) {
    local armyData = this.getRanksCollapsedDataForArmy(country, army)
    if (armyData == null) {
      if (this.cachedRankCollapsedState?[country] == null)
        this.cachedRankCollapsedState[country] <- DataBlock()
      let countryData = this.cachedRankCollapsedState[country]

      if (countryData?[army] == null)
        countryData[army] <- DataBlock()
      armyData = countryData[army]
    }

    if (armyData?[rank] == null)
      armyData[rank] <- isCollapsed
    else
      armyData[rank] = isCollapsed
  }


  function onUnitSelect() {}
  function selectRequiredUnit() {}
  function onSpendExcessExp() {}
  function updateResearchVariables() {}

  function onEventClanChanged(_params) {
    this.doWhenActiveOnce("fillAircraftsList")
  }

  function onEventSquadronExpChanged(_params) {
    this.checkUnitItemAndUpdate(getAircraftByName(clan_get_researching_unit()))
  }

  function onEventFlushSquadronExp(params) {
    this.fillAircraftsList(params?.unit.name)
  }

  getResearchingSquadronVehicle = function() {
    if (clan_get_exp() <= 0)
      return null

    let unit = getAircraftByName(clan_get_researching_unit())
    if (!unit)
      return null

    if (unit.shopCountry != this.curCountry || unit.unitType != lastUnitType)
      return null

    return unit
  }

  function getNationBonusData(country) {
    return this.cachedTopUnitsInfo?[country]
  }

  function isPageNationBonusPlateActive(country, armyIndex) {
    let bonus = this.getNationBonusData(country)
    return bonus != null && (bonus.ownTopUnitTypes.contains(armyIndex)
      || bonus.unitTypeWithBonuses.contains(armyIndex))
  }

  function isArmyHasNationBonus(country, armyIndex) {
    if (!hasFeature("ExpNewNationBonus"))
      return false
    let bonus = this.getNationBonusData(country)
    return bonus != null && bonus.unitTypeWithBonuses.contains(armyIndex)
  }

  getParamsForActionsList = @() {
    setResearchManually = this.setResearchManually
    shopResearchMode = this.shopResearchMode
    onSpendExcessExp = Callback(this.onSpendExcessExp, this)
    onCloseShop = Callback(this.onCloseShop, this)
    cellClass = "shopClone"
  }

  checkAirShopReq = @(air) air?.shopReq ?? true

  function onShowNationBonusChange(obj) {
    setNationBonusMarkState(this.curCountry, this.curPage, obj.getValue())
  }
}