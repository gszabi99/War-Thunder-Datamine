from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import buildTableRow
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { floor } = require("math")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { openPopupFilter } = require("%scripts/popups/popupFilterWidget.nut")
let { setTimeout, clearTimer } = require("dagor.workcycle")
let { utf8ToLower } = require("%sqstd/string.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")
let { getStats } = require("%scripts/myStats.nut")
let { getUnitsStatsFiltersView, applyUnitsStatsFilterChange,
  getUnitsStatsSelectedFilters } = require("%scripts/user/serviceRecords/serviceRecordsFilter.nut")
let { g_difficulty } = require("%scripts/difficulty.nut")
let { hasAllFeatures } = require("%scripts/user/features.nut")
let { getLbItemCell } = require("%scripts/leaderboard/leaderboardHelpers.nut")
let { getUnitClassIco } = require("%scripts/unit/unitInfoTexts.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { airStatsListConfig } = require("%scripts/user/userInfoStats.nut")
let { getEsUnitType } = require("%scripts/unit/unitParams.nut")
let { generatePaginator } = require("%scripts/viewUtils/paginator.nut")

const SELECTED_RECORD_SAVE_ID = "wnd/selectedRecord"

function filterListFunc(item, nameFilter) {
  if (nameFilter != "") {
    let hasSubstring = (item.searchId.indexof(nameFilter) != null) || (item.searchName.indexof(nameFilter) != null)
    if (!hasSubstring)
      return false
  }

  let selectedFilters = getUnitsStatsSelectedFilters()

  let country = selectedFilters.country
  if (country.len() > 0 && !country.contains(item.country))
    return false

  let unitType = selectedFilters.unitType
  if (unitType.len() > 0 && !unitType.contains(item.unitType))
    return false

  let ranks = selectedFilters.rank
  if (ranks.len() > 0 && !ranks.contains(item.rank))
    return false
  return true
}

local ServiceRecordsHandler = class (gui_handlers.BaseGuiHandlerWT) {
  wndType          = handlerType.CUSTOM
  sceneBlkName     = "%gui/profile/serviceRecordsPage.blk"

  parent = null
  modesListObj = null
  unitsStatsTableObj = null
  player = null
  isOwnStats = false
  paginatorHolder = null

  selectedMode = ""
  applyFilterTimer = null
  unitNameFilter = ""

  unitsCache = null
  unitsList = null

  statsSortBy = ""
  statsSortReverse = false
  currentPage = 0
  unitsPerPage = 0

  function initScreen() {
    this.unitsCache = {}
    this.unitsList = []

    this.loadSelectedMode()
    this.unitsStatsTableObj = this.scene.findObject("units_stats_table")
    this.modesListObj = this.scene.findObject("modes_list")

    openPopupFilter({
      scene = this.scene.findObject("filter_nest")
      onChangeFn = this.onFilterChange.bindenv(this)
      filterTypesFn = @() getUnitsStatsFiltersView()
      popupAlign = "bottom-center"
    })

    this.createUnitsCache()
    this.initUnitsPerPage()
    this.unitNameFilter = ""
    this.initModesList()
  }

  function createUnitsCache() {
    let unitsData = this.isOwnStats ? getStats()?.userstat : this.player?.userstat
    this.unitsCache.clear()
    if (unitsData == null)
      return
    foreach(mode in ["arcade", "historical", "simulation"]) {
      if (mode not in unitsData)
        continue
      this.unitsCache[mode] <- unitsData[mode]["total"].map(function(item) {
        let unit = getAircraftByName(item.name)
        let unitLocName = unit ? getUnitName(unit, true) : ""

        item.rank <- unit?.rank ?? 0
        item.country <- item?.country ?? unit?.shopCountry ?? ""
        item.locName <- item?.locName ?? unitLocName
        item.unitType <- getEsUnitType(unit)
        item.searchName <- utf8ToLower(unitLocName)
        item.searchId <- utf8ToLower(item.name)
        return item
      })
    }
  }

  function initModesList() {
    local selDiff = null
    local selIdx = -1
    let view = { items = [] }
    foreach (diff in g_difficulty.types) {
      if (!diff.isAvailable())
        continue
      view.items.append({
        id = diff.egdLowercaseName
        text = diff.getLocName()
      })
      if (!selDiff || this.selectedMode == diff.egdLowercaseName) {
        selDiff = diff
        selIdx = view.items.len() - 1
      }
    }

    let data = handyman.renderCached("%gui/commonParts/shopFilter.tpl", view)
    this.guiScene.replaceContentFromText(this.modesListObj, data, data.len(), this)
    this.modesListObj.setValue(selIdx)
  }

  function onStatsModeChange(obj) {
    let value = obj.getValue()
    this.selectedMode = this.modesListObj.getChild(value).id
    this.saveSelectedMode()

    this.prepareUnitsListData()
    this.updateUnitsList()
  }

  function prepareUnitsListData() {
    this.unitsList.clear()

    let modeUnitsList = this.unitsCache?[this.selectedMode] ?? []
    let searchNameFilter = utf8ToLower(this.unitNameFilter)
    foreach (item in modeUnitsList) {
      if (!filterListFunc(item, searchNameFilter))
        continue

      this.unitsList.append(item)
    }

    if (this.statsSortBy == "")
      this.statsSortBy = "victories"

    let sortBy = this.statsSortBy
    let sortReverse = this.statsSortReverse == (sortBy != "locName")
    this.unitsList.sort(function(a, b) {
      let res = b[sortBy] <=> a[sortBy]
      if (res != 0)
        return sortReverse ? -res : res
      return a.locName <=> b.locName || a.name <=> b.name
    })

    this.currentPage = 0
  }

  function initUnitsPerPage() {
    let size = this.unitsStatsTableObj.getSize()
    let rowsHeight = size[1] - this.guiScene.calcString("@leaderboardHeaderHeight", null)
    this.unitsPerPage = max(1, (rowsHeight / this.guiScene.calcString("@leaderboardTrHeight", null)).tointeger())
  }

  function updateUnitsList() {
    let data = []
    let posWidth = "0.05@scrn_tgt"
    let rcWidth = "0.04@scrn_tgt"
    let nameWidth = "0.2@scrn_tgt"
    let countryWidth = "0.08@scrn_tgt"
    let rankWidth = "70@sf/@pf"
    let headerRow = [
      { width = posWidth, text = "#", tdalign = "center"}
      { id = "country", width = countryWidth, text="#options/country", cellType = "splitLeft",
        tdalign = "center", callback = "onStatsCategory", active = this.statsSortBy == "country" }
      { id = "rank", width = rankWidth, text = "#sm_rank", tdalign = "center", callback = "onStatsCategory", active = this.statsSortBy == "rank" }
      { id = "locIcon", width = "0.05@scrn_tgt", cellType = "splitRight" }
      { id = "locName", width = nameWidth, text = "#options/unit", tdalign = "center", cellType = "splitLeft", callback = "onStatsCategory", active = this.statsSortBy == "locName" }
    ]
    foreach (item in airStatsListConfig) {
      if ("reqFeature" in item && !hasAllFeatures(item.reqFeature))
        continue
      if (this.isOwnStats || !("ownProfileOnly" in item) || !item.ownProfileOnly)
        headerRow.append({
          id = item.id
          image = "".concat("#ui/gameuiskin#", item?.icon ?? $"lb_{item.id}", ".svg")
          tooltip = loc(item?.text ?? $"multiplayer/{item.id}")
          callback = "onStatsCategory"
          active = this.statsSortBy == item.id
          needText = false
        })
    }
    data.append(buildTableRow("row_header", headerRow, null, "isLeaderBoardHeader:t='yes'"))

    let tooltips = {}
    let fromIdx = this.currentPage * this.unitsPerPage
    local toIdx = min(this.unitsList.len(), (this.currentPage + 1) * this.unitsPerPage)

    for (local idx = fromIdx; idx < toIdx; idx++) {
      let rowName = $"row_{idx}"
      local rowData = null
      let airData = this.unitsList[idx]
      let unitTooltipId = getTooltipType("UNIT").getTooltipId(airData.name)

      rowData = [
        { text = (idx + 1).tostring(), width = posWidth, tdalign = "center"}
        { id = "country", width = countryWidth, image = getCountryIcon(airData.country),
          imageRawParams = "left:t='0.5*(pw-w)'; isCountryIcon:t='yes'; background-svg-size:t='@cIco, 0.66@cIco';",
          tdalign = "center", cellType = "splitLeft", needText = false }
        { id = "rank", width = rankWidth, text = airData.rank.tostring(), tdalign = "center", cellType = "splitRight", active = this.statsSortBy == "rank" }
        {
          id = "unit",
          width = rcWidth,
          image = getUnitClassIco(airData.name),
          tooltipId = unitTooltipId,
          cellType = "splitRight",
          imageRawParams = "left:t='pw-w-2@sf/@pf';interactive:t='yes';",
          needText = false,
          tdalign = "right"
        }
        { id = "name", text = getUnitName(airData.name, true), tdalign = "left", active = this.statsSortBy == "name", cellType = "splitLeft", tooltipId = unitTooltipId }
      ]
      foreach (item in airStatsListConfig) {
        if ("reqFeature" in item && !hasAllFeatures(item.reqFeature))
          continue

        if (this.isOwnStats || !("ownProfileOnly" in item) || !item.ownProfileOnly) {
          let cell = getLbItemCell(item.id, airData[item.id], item.type)
          cell.active <- this.statsSortBy == item.id
          cell.tdalign <- "center"
          if ("tooltip" in cell) {
            if (!(rowName in tooltips))
              tooltips[rowName] <- {}
            tooltips[rowName][item.id] <- cell.$rawdelete("tooltip")
          }
          rowData.append(cell)
        }
      }
      data.append(buildTableRow(rowName, rowData ?? [], idx % 2 == 0))
    }

    let dataTxt = "".join(data)
    this.guiScene.replaceContentFromText(this.unitsStatsTableObj, dataTxt, dataTxt.len(), this)
    foreach (rowName, row in tooltips) {
      let rowObj = this.unitsStatsTableObj.findObject(rowName)
      if (rowObj)
        foreach (name, value in row)
          rowObj.findObject(name).tooltip = value
    }

    generatePaginator(this.paginatorHolder, this, this.currentPage, floor((this.unitsList.len() - 1) / this.unitsPerPage))
    this.updatePaginatorPlace(this.unitsList.len() > this.unitsPerPage)
  }

  function updatePaginatorPlace(value) {
    this.paginatorHolder?.show(value)
  }

  function onStatsCategory(obj) {
    if (!obj)
      return
    let value = obj.id
    if (this.statsSortBy == value)
      this.statsSortReverse = !this.statsSortReverse
    else {
      this.statsSortBy = value
      this.statsSortReverse = false
    }

    this.guiScene.performDelayed(this, function() {
      this.prepareUnitsListData()
      this.updateUnitsList()
     })
  }

  function goToPage(obj) {
    this.currentPage = obj.to_page.tointeger()
    this.updateUnitsList()
  }

  function applyServiceRecordsFilter(obj) {
    clearTimer(this.applyFilterTimer)
    this.unitNameFilter = obj.getValue()
    if(this.unitNameFilter == "") {
      this.prepareUnitsListData()
      this.updateUnitsList()
      return
    }

    let applyCallback = Callback(function() {
      this.prepareUnitsListData()
      this.updateUnitsList()
    }, this)
    this.applyFilterTimer = setTimeout(0.8, @() applyCallback())
  }

  function onFilterChange(objId, tName, value) {
    applyUnitsStatsFilterChange(objId, tName, value)
    this.prepareUnitsListData()
    this.updateUnitsList()
  }

  function onFilterCancel(filterObj) {
    if (filterObj.getValue() != "")
      filterObj.setValue("")
    else if (this.parent != null)
      this.guiScene.performDelayed(this.parent, this.parent.goBack)
  }

  function saveSelectedMode() {
    saveLocalAccountSettings(SELECTED_RECORD_SAVE_ID, this.selectedMode)
  }

  function loadSelectedMode() {
    this.selectedMode = loadLocalAccountSettings(SELECTED_RECORD_SAVE_ID) ?? ""
  }
}

gui_handlers.ServiceRecordsHandler <- ServiceRecordsHandler

return {
  openServiceRecordsPage = @(params = {}) handlersManager.loadHandler(ServiceRecordsHandler, params)
}
