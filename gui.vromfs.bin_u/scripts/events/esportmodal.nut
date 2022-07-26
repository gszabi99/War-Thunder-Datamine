let { setBreadcrumbGoBackParams } = require("%scripts/breadcrumb.nut")
let { buildDateTimeStr, getTimestampFromStringUtc } = require("%scripts/time.nut")
let { RESET_ID, openPopupFilter } = require("%scripts/popups/popupFilter.nut")
let unitTypesList = require("%scripts/unit/unitTypesList.nut")
let eSportTournamentModal = require("%scripts/events/eSportTournamentModal.nut")
let { TOURNAMENT_TYPES, getCurrentSeason, checkByFilter, getMatchingEventId,
  getTourListViewData, getTourById, removeItemFromList, getEventByDay, getOverlayTextColor,
  isTourStateChanged, getTourParams, getTourCommonViewParams, isTournamentWndAvailable,
  setSchedulerTimeColor, hasAnyTickets } = require("%scripts/events/eSport.nut")

const MY_FILTERS = "tournaments/filters"

let FILTER_CHAPTERS = ["tour", "unit"]

local ESportList = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType         = handlerType.BASE
  sceneBlkName    = "%gui/events/eSportModal.blk"
  sceneTplName    = "%gui/events/eSportContent"
  eventTplName    = "%gui/events/eSportItem"

  currSeason      = null
  tournamentList  = null
  // Filter params
  filterObj       = null
  eventListObj    = null
  filter          = {
    unitStates    = []
    tourStates    = []
  }
  unitTypes       = null
  tourTypes       = null
  tourStatesList  = {}

  getSceneTplContainerObj = @() scene.findObject("eSport_container")

  function getSceneTplView() {
    initIncomingParams()
    if (!currSeason)
      return {}

    return {
      seasonHeader = "\n".join([::g_string.utf8ToUpper(::loc("mainmenu/btnTournament")),
        $"{::loc("tournaments/season")} {currSeason.competitiveSeason}"])
      seasonDate = "".concat(
        buildDateTimeStr(getTimestampFromStringUtc(currSeason.beginDate), false, false),
        ::loc("ui/mdash"),
        buildDateTimeStr(getTimestampFromStringUtc(currSeason.endDate), false, false))
      items = getTourListViewData(tournamentList, filter)
    }
  }

  function initScreen() {
    if (!currSeason)
      return

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
    if (::g_login.isProfileReceived()) {
      let myFilters = ::load_local_account_settings(MY_FILTERS, ::DataBlock())
      filter.__update({
        tourStates = myFilters?.tourStates ? myFilters.tourStates % "array" : []
        unitStates = myFilters?.unitStates ? myFilters.unitStates % "array" : []
      })
    }
    fillUnitTypesList()
    fillTournamentTypesList()
  }

  function updateTourView(tObj, tour, tourParams) {
    let { isSesActive, isTraining, dayNum } = tourParams
    let { battleDay, isFinished, battlesNum, curSesTime,
      isMyTournament } = getTourCommonViewParams(tour, tourParams)
    let prevState = clone tourStatesList?[tour.id]
    let timeTxtObj = tObj.findObject("time_txt")
    tourStatesList[tour.id] <- tourParams
    if (!timeTxtObj?.isValid())
      return

    if (!isTourStateChanged(prevState, tourParams)) {
      if (curSesTime)
        timeTxtObj.setValue(curSesTime)

      return
    }

    if (isFinished) {
      let bgrObj = tObj.findObject("item_bgr")
      if (bgrObj?.isValid())
        bgrObj["background-saturate"] = 0
    }

    tObj.findObject("battle_day").setValue(battleDay)
    let isTourWndAvailable = isTournamentWndAvailable(dayNum)
    let battlesObj = ::showBtn("battle_nest", isTourWndAvailable, tObj)
    let sesObj = ::showBtn("session_obj", isTourWndAvailable, tObj)
    ::showBtn("leaderboard_obj", isFinished, tObj)
    ::showBtn("my_tournament_img", isMyTournament, tObj)

    if (!isTourWndAvailable)
      return

    let txtColor = getOverlayTextColor(isSesActive)
    battlesObj.findObject("battle_num").setValue(battlesNum)
    timeTxtObj.overlayTextColor = txtColor
    let iconImg = $"#ui/gameuiskin#{isSesActive ? "play_tour" : "clock_tour"}.svg"
    sesObj.findObject("session_ico")["background-image"] = iconImg
    setSchedulerTimeColor(sesObj, isTraining, txtColor)
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
        updateTourView(tObj, tour, getTourParams(tour))
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
        text      = ::loc("mainmenu/mix_battles")
      }
  }

  function fillTournamentTypesList() {
    tourTypes = {}
    foreach (idx, tType in TOURNAMENT_TYPES)
      tourTypes[tType] <- {
        id        = $"tour_{tType}"
        sortId    = idx
        isDisable = tType != "my" ? !isTournamentTypeInEvents(tType) : !hasAnyTickets()
        text  = ::loc($"tournaments/{tType}")
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
    if (curEvent != null && isTournamentWndAvailable(curTourParams.dayNum))
      eSportTournamentModal({ tournament, curTourParams, curEvent })
  }

  function onLeaderboard(obj) {
    // No matters for which day event gotten. All essential for leaderboard request params are identical for any day.
    if (obj?.eventId != null)
      ::gui_modal_event_leaderboards(getMatchingEventId(obj.eventId, 1, false))
  }

  onTimer = @(obj, dt) (scene.getModalCounter() != 0) ? null : updateAllEventsByFilters()
}

::gui_handlers.ESportList <- ESportList

return {
  openESportListWnd = @() ::handlersManager.loadHandler(ESportList)
}
