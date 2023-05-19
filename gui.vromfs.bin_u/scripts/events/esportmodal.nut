//checked for plus_string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

//checked for explicitness
#no-root-fallback
#explicit-this

let DataBlock = require("DataBlock")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { setBreadcrumbGoBackParams } = require("%scripts/breadcrumb.nut")
let { buildDateTimeStr, getTimestampFromStringUtc } = require("%scripts/time.nut")
let { RESET_ID, openPopupFilter } = require("%scripts/popups/popupFilter.nut")
let unitTypesList = require("%scripts/unit/unitTypesList.nut")
let eSportTournamentModal = require("%scripts/events/eSportTournamentModal.nut")
let { TOURNAMENT_TYPES, getCurrentSeason, checkByFilter, getMatchingEventId, fetchLbData,
  getTourListViewData, getTourById, removeItemFromList, getEventByDay, getOverlayTextColor,
  isTourStateChanged, getTourParams, getTourCommonViewParams, isTournamentWndAvailable,
  setSchedulerTimeColor, hasAnyTickets, getTourDay } = require("%scripts/events/eSport.nut")
let stdMath = require("%sqstd/math.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { utf8ToUpper } = require("%sqstd/string.nut")

const MY_FILTERS = "tournaments/filters"

let FILTER_CHAPTERS = ["tour", "unit"]

local ESportList = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType         = handlerType.BASE
  sceneBlkName    = "%gui/events/eSportModal.blk"
  sceneTplName    = "%gui/events/eSportContent.tpl"
  eventTplName    = "%gui/events/eSportItem.tpl"
  handlerLocId    = "mainmenu/btnTournament"

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
  ratingByTournaments = null

  getSceneTplContainerObj = @() this.scene.findObject("eSport_container")

  function getSceneTplView() {
    this.initIncomingParams()
    if (!this.currSeason)
      return {}

    return {
      seasonHeader = "\n".join([utf8ToUpper(loc("mainmenu/btnTournament")),
        $"{loc("tournaments/season")} {this.currSeason.competitiveSeason}"])
      seasonDate = "".concat(
        buildDateTimeStr(getTimestampFromStringUtc(this.currSeason.beginDate), false, false),
        loc("ui/mdash"),
        buildDateTimeStr(getTimestampFromStringUtc(this.currSeason.endDate), false, false))
      items = getTourListViewData(this.tournamentList, this.filter)
    }
  }

  function initScreen() {
    if (!this.currSeason)
      return

    this.ratingByTournaments = {}
    this.scene.findObject("update_timer").setUserData(this)
    setBreadcrumbGoBackParams(this)
    this.eventListObj = this.scene.findObject("events_list")
    this.updateRatingByTournaments()
    this.selectActiveTournament()
    this.filterObj = this.scene.findObject("filter_nest")

    openPopupFilter({
      scene = this.scene.findObject("filter_nest")
      onChangeFn = this.onFilterCbChange.bindenv(this)
      filterTypes = this.getFiltersView()
      popupAlign = "top-center"
      visualStyle = "tournament"
    })
  }

  function initIncomingParams() {
    this.currSeason = getCurrentSeason()
    if (!this.currSeason)
      return

    this.tournamentList = this.currSeason.tournamentList
    if (::g_login.isProfileReceived()) {
      let myFilters = ::load_local_account_settings(MY_FILTERS, DataBlock())
      this.filter.__update({
        tourStates = myFilters?.tourStates ? myFilters.tourStates % "array" : []
        unitStates = myFilters?.unitStates ? myFilters.unitStates % "array" : []
      })
    }
    this.fillUnitTypesList()
    this.fillTournamentTypesList()
  }

  function updateRatingByTournaments() {
    foreach (tour in this.tournamentList) {
      let curTourParams = getTourParams(tour)
      let id = tour.id
      if (id in this.ratingByTournaments)
        continue

      let { beginDate = "" } = tour
      if (beginDate != "" && getTimestampFromStringUtc(beginDate) > ::get_charserver_time_sec())
        continue
      let event = getEventByDay(tour.id, curTourParams.dayNum, false)
      if (event == null)
        continue
      fetchLbData(event, function(lbData) {
        this.ratingByTournaments[id] <- stdMath.round(lbData.rows.findvalue(
          @(row) row._id == ::my_user_id_str)?.rating ?? 0)
      }, this)
    }
  }

  function selectActiveTournament() {
    if (!this.eventListObj?.isValid())
      return

    let idx = this.tournamentList.findindex(@(tour) getTourDay(tour) >= 0)
    if (idx == null)
      return

    let tObj = this.eventListObj.getChild(idx)
    if (!(tObj?.isValid() ?? false))
      return
    tObj.scrollToView(true)
  }

  function updateTourView(tObj, tour, tourParams) {
    let { isSesActive, isTraining, dayNum } = tourParams
    let { battleDay, isFinished, battlesNum, curSesTime,
      isMyTournament } = getTourCommonViewParams(tour, tourParams)
    let rating = this.ratingByTournaments?[tour.id] ?? 0
    let prevState = clone this.tourStatesList?[tour.id]
    let timeTxtObj = tObj.findObject("time_txt")
    this.tourStatesList[tour.id] <- tourParams
    let ratingObj = ::showBtn("rating_nest", rating > 0, tObj)
    if (rating > 0)
      ratingObj.findObject("rating_txt")?.setValue(rating.tostring())
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
    if (!this.tournamentList || !this.eventListObj?.isValid())
      return

    for (local i = 0; i < this.eventListObj.childrenCount(); i++) {
      let tObj = this.eventListObj.getChild(i)
      if (!tObj?.isValid())
        continue

      let tour = getTourById(tObj.id)
      if (!tour)
        continue

      let isVisible = checkByFilter(tour, this.filter)
      tObj.show(isVisible)
      if (isVisible)
        this.updateTourView(tObj, tour, getTourParams(tour))
    }
  }

  isUnitTypeInEvents = @(typeName) this.tournamentList.findindex(@(p) p.armyId == typeName) != null
  isTournamentTypeInEvents = @(typeName)
    this.tournamentList.findindex(@(p) p.competitive_type == typeName) != null

  function getFiltersView() {
    let res = []
    foreach (_i, tName in FILTER_CHAPTERS) {
      let selectedArr = this.filter[$"{tName}States"]
      let referenceArr = this[$"{tName}Types"]

      let view = { checkbox = [] }
      foreach (idx, inst in referenceArr)
        view.checkbox.append({
          id        = inst.id
          sortId    = inst.sortId
          image     = inst?.image
          text      = inst.text
          isDisable = inst.isDisable
          value     = !inst.isDisable && selectedArr.findindex(@(v) v == idx) != null
        })

      view.checkbox.sort(@(a, b) a.sortId <=> b.sortId)
      res.append(view)
    }

    return res
  }

  function fillUnitTypesList() {
    this.unitTypes = {}

    foreach (unitType in unitTypesList.types) {
      if (!unitType.isAvailable())
        continue

      let armyId = unitType.armyId
      let typeIdx = unitType.esUnitType
      this.unitTypes[armyId] <- {
        id        = $"unit_{typeIdx}"
        sortId    = typeIdx
        image     = unitType.testFlightIcon
        isDisable = !this.isUnitTypeInEvents(armyId)
        text      = unitType.getArmyLocName()
      }
    }
    this.unitTypes.mix <- {
        id        = "unit_mix"
        sortId    = this.unitTypes.len()
        image     = "#ui/gameuiskin#all_unit_types.svg"
        isDisable = !this.isUnitTypeInEvents("mix")
        text      = loc("mainmenu/mix_battles")
      }
  }

  function fillTournamentTypesList() {
    this.tourTypes = {}
    foreach (idx, tType in TOURNAMENT_TYPES)
      this.tourTypes[tType] <- {
        id        = $"tour_{tType}"
        sortId    = idx
        isDisable = tType != "my" ? !this.isTournamentTypeInEvents(tType) : !hasAnyTickets()
        text  = loc($"tournaments/{tType}")
      }
  }

  function onFilterCbChange(objId, tName, value) {
    let selectedArr = this.filter[$"{tName}States"]
    let referenceArr = this[$"{tName}Types"]
    let isReset = objId == RESET_ID

    foreach (idx, inst in referenceArr) {
      if (!isReset && inst.id != objId)
        continue

      if (value)
        u.appendOnce(idx, selectedArr)
      else
        removeItemFromList(idx, selectedArr)
    }

    this.updateAllEventsByFilters()
    ::save_local_account_settings(MY_FILTERS, ::build_blk_from_container(this.filter))
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
    let tournament = getTourById(obj.eventId)
    if (tournament)
      ::gui_modal_event_leaderboards({ // No matters for which day event gotten. All essential for leaderboard request params are identical for any day.
        eventId = getMatchingEventId(tournament.id, 0, false)
        sharedEconomicName = tournament.sharedEconomicName
      })
  }

  onTimer = @(_obj, _dt) (this.scene.getModalCounter() != 0) ? null : this.updateAllEventsByFilters()

  onEventGameModesUpdated = @(_) this.updateRatingByTournaments()
}

::gui_handlers.ESportList <- ESportList

let openESportListWnd = @() ::handlersManager.loadHandler(ESportList)

addPromoAction("open_rating_battles", @(_handler, _params, _obj) openESportListWnd())

return {
  openESportListWnd
}
