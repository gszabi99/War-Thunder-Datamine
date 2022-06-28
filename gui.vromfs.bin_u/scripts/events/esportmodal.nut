let { setBreadcrumbGoBackParams } = require("%scripts/breadcrumb.nut")
let { buildDateTimeStr, getTimestampFromStringUtc } = require("%scripts/time.nut")
let { RESET_ID, openPopupFilter } = require("%scripts/popups/popupFilter.nut")
let unitTypesList = require("%scripts/unit/unitTypesList.nut")
let eSportTournamentModal = require("%scripts/events/eSportTournamentModal.nut")
let { MY_FILTERS, TOURNAMENT_TYPES, getTourUserData, getCurrentSeason, checkByFilter,
  getTourListViewData, updateTourView, getTourById, removeItemFromList, getEventByDay,
  getTourParams, isTournamentWndAvailable, hasAnyTickets } = require("%scripts/events/eSport.nut")

let FILTER_CHAPTERS = ["tour", "unit"]

local ESportList = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType         = handlerType.BASE
  sceneBlkName    = "%gui/events/eSportModal.blk"
  sceneTplName    = "%gui/events/eSportContent"
  eventTplName    = "%gui/events/eSportItem"

  seasonHeader    = ""
  currSeason      = null
  tournamentList  = null
  // Filter params
  filterObj       = null
  eventListObj    = null
  filter          = {
    unitStates    = null
    tourStates    = null
  }
  unitTypes       = null
  tourTypes       = null
  tourStatesList  = {}

  getSceneTplContainerObj = @() scene.findObject("eSport_container")

  function getSceneTplView() {
    initIncomingParams()
    if (!currSeason)
      return {}

    seasonHeader = $"{::loc("tournaments/season")} {::loc("ui/mdash")} {currSeason.competitiveSeason}"

    return {
      seasonDate = "".concat(
        buildDateTimeStr(getTimestampFromStringUtc(currSeason.beginDate), false, false),
        ::loc("ui/mdash"),
        buildDateTimeStr(getTimestampFromStringUtc(currSeason.endDate), false, false))
      tabs = [
        {
          tabName = "TOURNAMENTS"
          navImagesText = ""
          selected = true
        }
      ]
      items = getTourListViewData(tournamentList, filter)
    }
  }

  function initScreen() {
    if (!currSeason)
      return
    scene.findObject("header_txt")?.setValue(seasonHeader)
    scene.findObject("update_timer").setUserData(this)
    setBreadcrumbGoBackParams(this)
    eventListObj = scene.findObject("events_list")
    filterObj = scene.findObject("filter_nest")

    openPopupFilter({
      scene = scene.findObject("filter_nest")
      onChangeFn = onFilterCbChange.bindenv(this)
      filterTypes = getFiltersView()
      visualStyle = "tournament"
    })
  }

  function initIncomingParams() {
    currSeason = getCurrentSeason()
    if (!currSeason)
      return

    tournamentList = currSeason.tournamentList
    let myFilters = getTourUserData()?.myFilters
    filter = {
      tourStates = myFilters?.tourStates ? myFilters.tourStates % "array" : []
      unitStates = myFilters?.unitStates ? myFilters.unitStates % "array" : []
    }
    fillUnitTypesList()
    fillTournamentTypesList()
  }

  function updateAllEventsByFilters() {
    if (!tournamentList || !eventListObj?.isValid())
      return

    for (local i = 0; i < eventListObj.childrenCount(); i++) {
      let tObj = eventListObj.getChild(i)
      if (!tObj?.isValid())
        continue

      let tour = getTourById(tObj.id)
      if (!tour)
        continue

      let isVisible = checkByFilter(tour, filter)
      tObj.show(isVisible)
      if (isVisible)
        updateTourView(tObj, tour, tourStatesList, getTourParams(tour))
    }
  }

  isUnitTypeInEvents = @(typeName) tournamentList.findindex(@(p) p.armyId == typeName) != null
  isTournamentTypeInEvents = @(typeName)
    tournamentList.findindex(@(p) p.competitive_type == typeName) != null

  function getFiltersView() {
    let res = []
    foreach (i, tName in FILTER_CHAPTERS) {
      let selectedArr = filter[$"{tName}States"]
      let referenceArr = this[$"{tName}Types"]

      let view = {checkbox = []}
      foreach(idx, inst in referenceArr)
        view.checkbox.append({
          id        = inst.id
          sortId    = inst.sortId
          image     = inst?.image
          text      = inst.text
          isDisable = inst.isDisable
          value     = !inst.isDisable && selectedArr.findindex(@(v) v == idx) != null
        })

      view.checkbox.sort(@(a,b) a.sortId <=> b.sortId)
      res.append(view)
    }

    return res
  }

  function fillUnitTypesList() {
    unitTypes = {}

    foreach(unitType in unitTypesList.types) {
      if (!unitType.isAvailable())
        continue

      let armyId = unitType.armyId
      let typeIdx = unitType.esUnitType
      unitTypes[armyId] <- {
        id        = $"unit_{typeIdx}"
        sortId    = typeIdx
        image     = unitType.testFlightIcon
        isDisable = !isUnitTypeInEvents(armyId)
        text      = unitType.getArmyLocName()
      }
    }
    unitTypes.mix <- {
        id        = "unit_mix"
        sortId    = unitTypes.len()
        image     = "#ui/gameuiskin#all_unit_types.svg"
        isDisable = !isUnitTypeInEvents("mix")
        text      = ::loc($"Mix battle")
      }
  }

  function fillTournamentTypesList() {
    tourTypes = {}
    foreach (idx, tType in TOURNAMENT_TYPES)
      tourTypes[tType] <- {
        id        = $"tour_{tType}"
        sortId    = idx
        isDisable = tType != "my_only" ? !isTournamentTypeInEvents(tType) : !hasAnyTickets()
        text  = ::loc(tType)
      }
  }

  function onFilterCbChange(objId, tName, value) {
    let selectedArr = filter[$"{tName}States"]
    let referenceArr = this[$"{tName}Types"]
    let isReset = objId == RESET_ID

    foreach (idx, inst in referenceArr) {
      if (!isReset && inst.id != objId)
        continue

      if (value)
        ::u.appendOnce(idx, selectedArr)
      else
        removeItemFromList(idx, selectedArr)
    }

    updateAllEventsByFilters()
    ::save_local_account_settings(MY_FILTERS, ::build_blk_from_container(filter))
  }

  function onEvent(obj) {
    let tournament = getTourById(obj.id)
    if (!tournament)
      return

    let curTourParams = getTourParams(tournament)
    let curEvent = getEventByDay(tournament.id, curTourParams.dayNum, curTourParams.isTraining)
    if (curEvent != null && isTournamentWndAvailable(tournament))
      eSportTournamentModal({ tournament, curTourParams, curEvent })
  }

  function onLeaderboard() {
  }

  function onTabChange(obj) {
  }

  onTimer = @(obj, dt) (scene.getModalCounter() != 0) ? null : updateAllEventsByFilters()
}

::gui_handlers.ESportList <- ESportList

return {
  openESportListWnd = @() ::handlersManager.loadHandler(ESportList)
}
