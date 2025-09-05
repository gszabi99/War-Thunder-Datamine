from "%scripts/dagui_library.nut" import *

let { g_difficulty } = require("%scripts/difficulty.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { floor } = require("%sqstd/math.nut")
let { getUnitRarity } = require("%scripts/unit/unitInfoTexts.nut")
let { getUnitRole, getUnitRoleIcon } = require("%scripts/unit/unitInfoRoles.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { image_for_air, getUnitName } = require("%scripts/unit/unitInfo.nut")
let { generatePaginator } = require("%scripts/viewUtils/paginator.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { getUnitRankText } = require("%scripts/shop/shopUnitCellFill.nut")
let vehiclesModal = require("%scripts/unit/vehiclesModal.nut")
let shopSearchCore = require("%scripts/shop/shopSearchCore.nut")
let { getObjValidIndex } = require("%sqDagui/daguiUtil.nut")

let setBool = @(obj, prop, val) obj[prop] = val ? "yes" : "no"

local handlerClass = class (vehiclesModal.handlerClass) {
  pageItemsCount = 0
  curPage = 0
  pagesCount = 0
  onUnitSelectFunction = null
  diffsForSort = null
  searchString = ""
  searchUnits = null
  userstat = null
  recordTableUnits = null

  function getSceneTplView() {
    this.collectUnitData()
    this.pageItemsCount = this.maxSlotCountX * this.maxSlotCountY

    return {
      slotCountX = this.maxSlotCountX
      slotCountY = this.maxSlotCountY
      hasScrollBar = false
      wndTitle = this.getWndTitle()
      needCloseBtn = true
      navBar = this.getNavBarView()
      hasSearchBox = true
      isOnlyClick = true
    }
  }

  function initScreen() {
    if (this.userstat) {
      this.recordTableUnits = {}
      foreach (diff in g_difficulty.types) {
        if (this.diffsForSort && !this.diffsForSort.contains(diff.egdLowercaseName))
          continue

        let stats = this.userstat?[diff.egdLowercaseName].total
        if (stats && stats.len() > 0)
          foreach (record in stats)
            this.recordTableUnits[record.name] <- (this.recordTableUnits?[record.name] ?? 0) + record.flyouts
      }
    }

    let listObj = this.scene.findObject("units_list")
    this.initPopupFilter()
    this.guiScene.createMultiElementsByObject(listObj, "%gui/unit/unitCell.blk", "tdiv", this.pageItemsCount, this)
    this.fillUnitsList()
    if (listObj.childrenCount() > 0)
      listObj.setValue(0)
  }

  function calcPagesCount() {
    this.pagesCount = floor(this.filteredUnits.len() / this.pageItemsCount)
  }

  function updatePaginator() {
    let nestObj = this.scene.findObject("paginator_place")
    generatePaginator(nestObj, this, this.curPage, this.pagesCount)
  }

  function setPage(pageIndex) {
    this.curPage = clamp(pageIndex, 0, this.pagesCount)
    this.updatePage()
    this.updatePaginator()
  }

  function fillUnitsList(page = 0) {
    this.filterUnits(this.searchUnits ?? this.units)
    this.calcPagesCount()
    this.setPage(page)
  }

  function unitSortFunction(a, b, recordTable) {
    let flyA = recordTable?[a.name] ?? 0
    let flyB = recordTable?[b.name] ?? 0
    return flyB <=> flyA
  }

  function filterUnits(units) {
    base.filterUnits(units)
    let {unitSortFunction, recordTableUnits} = this
    this.filteredUnits.sort(@(a, b) unitSortFunction(a, b, recordTableUnits))
  }

  function updatePage() {
    let cellsContainer = this.scene.findObject("units_list")
    let startIndex = this.curPage * this.pageItemsCount
    let unitsCount = min(this.filteredUnits.len() - startIndex, this.pageItemsCount)

    for (local i = 0; i < this.pageItemsCount; i++) {
      let unitCell = cellsContainer.getChild(i)
      if (i < unitsCount)
        this.updateUnitCell(unitCell, this.filteredUnits[startIndex + i])
      else
        unitCell.show(false)
    }
  }

  function updateUnitCell(obj, unit) {
    if (!obj?.isValid())
      return
    obj.show(true)
    this.updateCardStatus(obj, this.getUnitFixedParams(unit))
  }

  function updateCardStatus(obj, statusTbl) {
    let {
      unitName                  = "",
      unitImage                 = "",
      nameText                  = "",
      unitRarity                = "",
      unitClassIcon             = "",
      unitClass                 = "",
      isPkgDev                  = false,
      isRecentlyReleased        = false,
      tooltipId                 = "",
      unitRankText              = ""
    } = statusTbl

    obj.id = $"unit_{unitName}"
    obj.unit_name = unitName
    obj.unitRarity = unitRarity

    setBool(obj, "isPkgDev", isPkgDev)
    setBool(obj, "isRecentlyReleased", isRecentlyReleased)

    obj.findObject("unitImage")["foreground-image"] = unitImage
    obj.findObject("unitTooltip").tooltipId = tooltipId
    if (showConsoleButtons.get())
      obj.tooltipId = tooltipId

    let nameObj = obj.findObject("nameText")
    nameObj.setValue(nameText)

    let classPlace = showObjById("classIconPlace", unitClassIcon != "", obj)
    if (unitClassIcon != "") {
      let classObj = classPlace.findObject("classIcon")
      classObj.setValue(unitClassIcon)
      classObj.shopItemType = unitClass
    }

    let rankObj = obj.findObject("rankText")
    rankObj.setValue(unitRankText)
    setBool(rankObj, "tinyFont", false)
  }

  function getUnitFixedParams(unit) {
    return {
      unitName            = unit.name
      unitImage           = image_for_air(unit)
      nameText            = getUnitName(unit)
      unitRarity          = getUnitRarity(unit)
      unitClassIcon       = getUnitRoleIcon(unit)
      unitClass           = getUnitRole(unit)
      isPkgDev            = unit.isPkgDev
      unitRankText        = getUnitRankText(unit, false, getCurrentGameModeEdiff())
      isRecentlyReleased  = unit.isRecentlyReleased()
    }
  }

  function checkUnitItemAndUpdate(_unit) {}

  function getCurSlotObj() {
    let listObj = this.scene.findObject("units_list")
    let idx = getObjValidIndex(listObj)
    if (idx < 0)
      return null

    return listObj.getChild(idx)
  }

  function onUnitAction(_) {
    this.selectCell()
    let unitName = this.getCurSlotObj()?.unit_name
    let unit = getAircraftByName(unitName)
    if (this?.onUnitSelectFunction) {
      this.onUnitSelectFunction(unit)
      this.goBack()
    }
  }

  function onEventUnitResearch(_p) {}

  function onEventUnitBought(_p) {
    this.collectUnitData()
    this.fillUnitsList(this.curPage)
  }

  function onEventFlushSquadronExp(_p) {}
  function onEventModificationPurchased(_p) {}
  function onEventUnitRepaired(_p) {}

  function goToPage(obj) {
    let pageIndex = to_integer_safe(obj["to_page"])
    this.setPage(pageIndex)
  }

  function getNavBarView() {
    return { middleId = "paginator_place" }
  }

  function onSearchEditBoxChangeValue(obj) {
    this.searchString = obj.getValue()
    if (this.searchString == "")
      this.searchUnits = null
    else {
      this.searchUnits = shopSearchCore.findUnitsByLocName(this.searchString)
      if (this.unitsFilter) {
        let filterFn = this.unitsFilter
        this.searchUnits = this.searchUnits.filter(filterFn)
      }
    }
    this.fillUnitsList()
  }

  function onSearchCancelClick(_obj) {
    this.searchCancel()
  }

  function onSearchEditBoxCancelEdit(_obj) {
    this.searchCancel()
  }

  function searchCancel() {
    if (this.searchUnits != null) {
      this.searchUnits = null
      this.fillUnitsList()
    }
    this.searchString = ""
    let obj = this.scene.findObject("search_edit_box")
    if (obj.isValid()) {
      obj.setValue("")
      
      obj.enable(false)
      obj.enable(true)
    }
  }

}

gui_handlers.selectUnitModal <- handlerClass

return {
  openSelectUnitWnd = function(params = {}) {
    handlersManager.loadHandler(handlerClass, params)
  }
}
