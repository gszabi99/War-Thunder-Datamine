let { setBreadcrumbGoBackParams } = require("scripts/breadcrumb.nut")
let { buildTimeStr, buildDateTimeStr, buildDateStrShort,
  isInTimerangeByUtcStrings, getTimestampFromStringUtc } = require("scripts/time.nut")
let { secondsToString, millisecondsToSecondsInt } = require("scripts/timeLoc.nut")
let { eachBlock, eachParam } = require("std/datablock.nut")
let { RESET_ID, openPopupFilter } = require("scripts/popups/popupFilter.nut")
let unitTypesList = require("scripts/unit/unitTypesList.nut")

const MY_TOURNAMENTS = "tournaments/favorites"
const MY_FILTERS = "tournaments/filters"

let EVENT_PARAM_NAMES = {
  TICKETS = "tickets"
  SCHEDULER = "scheduler"
  AWARDS = "awards"
}
let DAY = {
  SOON     = -1
  FINISH   = -2
}
let FILTER_CHAPTERS = ["tour", "unit"]
let TOURNAMENT_TYPES = ["1x1", "2x2", "3x3", "4x4", "5x5", "spec", "my only"]
let seasonsList = persist("seasonsList", @() ::Watched([]))
let eventStatesList = {}
let initSeasonsList = function() {
  if (seasonsList.value.len() > 0)
    return
  let res = []
  foreach (s in ::get_tournaments_blk() % "season") {
    let season = {eventsList = []}
    eachParam(s, @(p, id) season[id] <- p)
    eachBlock(s, function(evnBlk, evnId){
      let event = {id = evnId}
      eachParam(evnBlk, @(p, id) event[id] <- p)
      foreach (pName in EVENT_PARAM_NAMES) {
        let key = pName
        let curBlk = evnBlk?[key]
        event[key] <- []
        let curParam = event[key]
        if (!curBlk)
          continue

        eachBlock(curBlk, function(paramBlk, paramId){
          let data = {}
          eachParam(paramBlk, @(p, id) data[id] <- p)
          eachBlock(paramBlk, function(blk, pId){
            if (key == EVENT_PARAM_NAMES.TICKETS) {
              data.id <- paramId
              // Some ticket parameters are in separate block by design,
              // but they are ticket parameters anyway.
              eachParam(blk, @(p, id) data[id] <- p)
            }
            if (key == EVENT_PARAM_NAMES.SCHEDULER) {
              data[pId] <- {}
              eachParam(blk, @(p, id) data[pId][id] <- p)
            }
          })
          curParam.append(data)
        })
      }

      event.tickets.sort(@(a, b)
        getTimestampFromStringUtc(a.startActiveTime)
          <=> getTimestampFromStringUtc(b.startActiveTime))

      // Reorder event scheduler by days
      let scheduler = []
      foreach (idx, ticket in event.tickets) {
        let day = []
        let sTime = getTimestampFromStringUtc(ticket.startActiveTime)
        let eTime = getTimestampFromStringUtc(ticket.stopActiveTime)
        foreach (session in event.scheduler) {
          let curTime = getTimestampFromStringUtc(session.train.start)
          if ( curTime >= sTime && curTime <= eTime)
            day.append(session)
        }

        scheduler.append(day.sort(@(a, b)
          getTimestampFromStringUtc(a.train.start) <=> getTimestampFromStringUtc(b.train.start)))
      }

      event.scheduler = scheduler
      event.beginDate <- event.tickets[0].startActiveTime
      event.endDate <- event.tickets[event.tickets.len() - 1].stopActiveTime
      season.eventsList.append(event)
    })

    season.eventsList.sort(@(a, b) a.beginDate <=> b.beginDate)
    res.append(season)
  }
  seasonsList(res.sort(@(a, b) a.competitiveSeason <=> b.competitiveSeason))
}

let getEventDay = function(event) {
  let now = millisecondsToSecondsInt(::get_charserver_time_millisec())
  return now > getTimestampFromStringUtc(event.tickets[event.tickets.len() - 1].stopActiveTime)
    ? DAY.FINISH : event.tickets.findindex(@(t) now >= getTimestampFromStringUtc(t.startActiveTime)
        && now <= getTimestampFromStringUtc(t.stopActiveTime)) ?? DAY.SOON
}

let getSessionParams = function(event) {
  let dayNum = getEventDay(event)
  let res = {
    dayNum      = dayNum
    sesIdx      = -1
    sesTime     = -1
    sesLen      = 0
    isTraining  = false
    isSesActive = false
  }
  if (dayNum < 0)
    return res

  let sList = event.scheduler[dayNum]
  let now = millisecondsToSecondsInt(::get_charserver_time_millisec())
  local sTime
  local trainingTime
  res.sesLen = sList.len()
  //Session is going now
  foreach(idx, inst in sList) {
    trainingTime = getTimestampFromStringUtc(inst.train.end) - now
    sTime = isInTimerangeByUtcStrings(inst.train.start, inst.train.end)
      ? trainingTime
        : isInTimerangeByUtcStrings(inst.battle.start, inst.battle.end)
          ? getTimestampFromStringUtc(inst.battle.end) - now : -1
    if(sTime >= 0) {
      res.sesTime = sTime
      res.isSesActive = true
      res.sesIdx = idx
      res.isTraining = trainingTime > 0
      return res
    }
  }
  //Nearest coming session
  for (local i = 0; i < sList.len(); i++) {
    let inst = sList[i]
    trainingTime = (!::u.isEmpty(inst.train.start)
      ? getTimestampFromStringUtc(inst.train.start) : 0) - now
    sTime = trainingTime > 0 ? trainingTime : !::u.isEmpty(inst.battle.start)
      ? getTimestampFromStringUtc(inst.battle.start) - now : -1
    if (sTime >= 0) {
      res.sesTime = sTime
      res.sesIdx = i
      res.isTraining = trainingTime > 0
      return res
    }
  }
  return res
}

let getSessionTimeIntervalStr = @(timeArr) "".concat(buildTimeStr(
  getTimestampFromStringUtc(timeArr.start), false, false),
    ::loc("ui/hyphen"), buildTimeStr(getTimestampFromStringUtc(timeArr.end), false, false))

let getSessionsView = function(sesLen, sesIdx) {
  if (sesIdx < 0 || sesLen == 0)
    return ""
  let res = []
  for (local i = 0; i < sesLen; i++)
    res.append({sesId = $"session_{i}", sesNum = $" {i + 1} ", isSelected = i == sesIdx})
  return res
}

let getBattleDateStr = function(event) {
  let beginTS = getTimestampFromStringUtc(event.beginDate)
  let endTS = getTimestampFromStringUtc(event.endDate)
  return "".concat(
    $"{buildDateStrShort(beginTS)}{::loc("ui/comma")}{buildTimeStr(beginTS, false, false)}",
      ::loc("ui/mdash"),
        $"{buildDateStrShort(endTS)}{::loc("ui/comma")}{buildTimeStr(endTS, false, false)}")
}

let checkByFilter = @(event, filter)
    (filter.tourStates.len() == 0
      || filter.tourStates.findindex(@(v) v == event.competitive_type) != null)
        && (filter.unitStates.len() == 0
          || filter.unitStates.findindex(@(v) v == event.armyId) != null)

let getEventViewParams = function(event, sesParams, filter) {
  let cType = event.competitive_type
  let teamSizes = cType.split("x")
  let armyId = event.armyId
  let { dayNum, sesIdx, sesTime, sesLen } = sesParams
  let isFinished = dayNum == DAY.FINISH
  let isSoon = dayNum == DAY.SOON
  return {
    countries = event.country.split(",").map(
      @(key, v) {icon = ::get_country_icon($"{::g_string.trim(key)}_round")})
    headerImg = $"#ui/gameuiskin#tournament_{isFinished ? "finished" : armyId}_header.png"
    itemBgr =  $"#ui/images/tournament_{armyId}.jpg"
    tournamentName = ::loc(event.sharedeconomicName)
    vehicleType = $"{armyId} Battle"
    rank = $"{::loc("shop/age").toupper()} {::get_roman_numeral(event.rank)}"
    tournamentType = ::loc("country/VS").join(teamSizes)
    divisionImg = "#ui/gameuiskin#icon_progress_bar_stage_07.png"
    battleDate = getBattleDateStr(event)
    battleDay = isFinished ? ::loc("items/craft_process/finished")
      : isSoon ? ::loc("tournaments/coming_soon")
      : ::loc("tournaments/enumerated_day", {num = dayNum + 1})
    battlesNum = event.tickets?[dayNum].battleLimit
    eventId = event.id
    isVisible = checkByFilter(event, filter)
    isMyTournament = event.id in myTournaments
    isFinished = isFinished
    isActive = !isFinished && !isSoon
    sessions = getSessionsView(sesLen, sesIdx)
    sessionTime = sesTime <  0 ? null : secondsToString(sesTime)
    trainingTime = sesIdx < 0
      ? null : getSessionTimeIntervalStr(event.scheduler[dayNum][sesIdx].train)
    startTime = sesIdx < 0
      ? null : getSessionTimeIntervalStr(event.scheduler[dayNum][sesIdx].battle)
  }
}

let getEventsListViewData = function(eList, filter) {
  let res = []
  foreach (event in eList)
    res.append(getEventViewParams(event, getSessionParams(event), filter))

  return res
}

let removeItemFromList = function(value, list) {
  let idx = list.findindex(@(v) v == value)
  if (idx != null)
    list.remove(idx)
}

let getMatchingEventId = @(eventId, day, isTraining)
  $"{eventId}{day ? "_day" : ""}{day ?? ""}{isTraining ? "_train" : ""}"

local ESportList = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType       = handlerType.BASE
  sceneBlkName  = "%gui/events/eSportModal.blk"
  sceneTplName  = "%gui/events/eSportContent"
  eventTplName  = "%gui/events/eSportItem"

  seasonHeader  = ""
  currSeason    = null
  eventsList    = null
  myTournaments = null
  // Filter params
  myFilters     = null
  filterObj     = null
  eventListObj  = null
  filter        = {
    unitStates  = null
    tourStates  = null
  }
  unitTypes     = null
  tourTypes     = null

  getSceneTplContainerObj = @() scene.findObject("eSport_container")
  getEventById = @(id) eventsList.findvalue(@(v) v.id == id)

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
      items = getEventsListViewData(eventsList, filter)
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
    initSeasonsList()
    if (!seasonsList.value?[0])
      return

    currSeason = seasonsList.value[0]
    eventsList = currSeason.eventsList
    myTournaments = ::load_local_account_settings(MY_TOURNAMENTS)
    myFilters = ::load_local_account_settings(MY_FILTERS) ?? ::DataBlock()
    filter = {
      tourStates = myFilters?.tourStates ? myFilters.tourStates % "array" : []
      unitStates = myFilters?.unitStates ? myFilters.unitStates % "array" : []
    }
    fillUnitTypesList()
    fillTournamentTypesList()
  }

  function updateEventView(eObj) {
    if (!eObj?.isValid())
      return

    let eventId = eObj.id
    let event = getEventById(eventId)
    if (!event)
      return

    let isVisible = checkByFilter(event, filter)
    eObj.show(isVisible)
    if (!isVisible)
      return

    let sesParams = getSessionParams(event)
    let eParams = getEventViewParams(event, sesParams, filter)
    let { dayNum, sesIdx, sesLen, isTraining, isSesActive } = sesParams
    let { battleDay, isFinished, battlesNum, sessionTime, isActive,
      trainingTime, startTime } = eParams

    let prevState = eventStatesList?[eventId]
    if (!prevState || (prevState.isTraining == isTraining
      && prevState.isSesActive == isSesActive && prevState.dayNum == dayNum)) {
        if (sessionTime)
          eObj.findObject("session_timer")?.setValue(sessionTime)
        eventStatesList[eventId] <- sesParams
        return
      }

    eventStatesList[eventId] = sesParams
    eObj.findObject("item_bgr")["background-saturate"] = isFinished ? 0 : 1
    ::showBtn("leaderboard_img", isFinished, eObj)
    ::showBtn("leaderboard_btn", isFinished, eObj)
    eObj.findObject("battle_day").setValue(battleDay)
    if (isFinished)
      return

    let battlesObj = ::showBtn("battle_nest", isActive, eObj)
    let sessionObj = ::showBtn("session_nest", isActive, eObj)
    let trainingObj = ::showBtn("training_nest", isActive, eObj)
    let startObj = ::showBtn("start_nest", isActive, eObj)
    if (!isActive)
      return

    let iconImg = $"#ui/gameuiskin#{isSesActive ? "play_tour" : "clock_tour"}.svg"
    battlesObj.findObject("battle_num").setValue(battlesNum)
    sessionObj.findObject("session_timer").setValue(sessionTime)
    sessionObj.findObject("session_ico")["background-image"] = iconImg
    trainingObj.findObject("training_time").setValue(trainingTime)
    startObj.findObject("start_time").setValue(startTime)
    for (local i = 0; i < sesLen; i++)
      sessionObj.findObject($"session_{i}").visualStyle = i == sesIdx ? "sessionSelected" : ""
  }

  function updateAllEventsByFilters() {
    if (!eventsList || !eventListObj?.isValid())
      return

    for (local i = 0; i < eventListObj.childrenCount(); i++)
      updateEventView(eventListObj.getChild(i))
  }

  isUnitTypeInEvents = @(typeName) eventsList.findindex(@(p) p.armyId == typeName) != null
  isTournamentTypeInEvents = @(typeName) eventsList.findindex(@(p) p.competitive_type == typeName) != null

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
        isDisable = !isTournamentTypeInEvents(tType)
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
    let event = getEventById(obj.id)
    if (!event)
      return

    let { dayNum, isTraining } = getSessionParams(event)
    let tournamentId = getMatchingEventId(event.id, dayNum >= 0 ? dayNum + 1 : 1, isTraining)
    ::gui_start_modal_events({ event = tournamentId })
  }

  function onMyTournaments() {
  }

  function onLeaderboard() {
  }

  function onTabChange(obj) {
  }

  function onItemHover(obj) {
  }

  onTimer = @(obj, dt) updateAllEventsByFilters()
}

::gui_handlers.ESportList <- ESportList

return {
  openESportListWnd = @() ::handlersManager.loadHandler(ESportList)
}
