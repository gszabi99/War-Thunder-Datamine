from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { eachBlock, eachParam } = require("%sqstd/datablock.nut")
let { buildTimeStr,  buildDateStrShort, isInTimerangeByUtcStrings,
  getTimestampFromStringUtc } = require("%scripts/time.nut")
let { secondsToString } = require("%scripts/timeLoc.nut")
let { secondsToDays } = require("%sqstd/time.nut")

const NEXT_DAYS = 14

let TOURNAMENT_TYPES = ["1x1", "2x2", "3x3", "4x4", "5x5", "spec", "my"]

let DAY = {
  NEXT   = -1
  SOON   = -2
  FINISH = -3
}

let TOUR_PARAM_NAMES = {
  TICKETS = "tickets"
  SCHEDULER = "scheduler"
  AWARDS = "awards"
}

local seasonsList = []

let function getTourDay(tour) {
  let now = ::get_charserver_time_sec()
  if (now > getTimestampFromStringUtc(tour.tickets[tour.tickets.len() - 1].stopActiveTime))
    return DAY.FINISH

  // Tournament is active
  if (isInTimerangeByUtcStrings(tour.beginDate, tour.endDate)) {
    let nearestDays = []
    return tour.tickets.findindex(function(t){
          let dTime = now - getTimestampFromStringUtc(t.stopActiveTime)
          nearestDays.append(dTime)
          return now >= getTimestampFromStringUtc(t.startActiveTime) && dTime <= 0 // Session is going now
        })
      ?? nearestDays.findindex(@(t) t < 0) // Nearest session. First negative value is nearest because of tickets already sorted
  }

  if (tour.tickets.findindex(@(t) secondsToDays(
    getTimestampFromStringUtc(t.startActiveTime) - now) < NEXT_DAYS) != null)
      return DAY.NEXT

  return DAY.SOON
}

let isTournamentWndAvailable = @(dayNum) dayNum != DAY.FINISH && dayNum != DAY.SOON
let getMatchingEventId = @(tourId, dayNum, isTraining)
  $"{tourId}_day{max(0, dayNum) + 1}{isTraining ? "_train" : ""}"
let getSharedTourNameByEvent = @(economicName) economicName.split("_day")[0]

let function getEventByDay(tourId, dayNum, isTraining = false){
 let matchingEventId = getMatchingEventId(tourId, dayNum, isTraining)
 return ::events.getEvent(matchingEventId)
}

let function getTourParams(tour) {
  let dayNum = getTourDay(tour)
  let res = {
    dayNum      = dayNum
    sesIdx      = -1
    sesTime     = -1
    sesLen      = 0
    isTraining  = false
    isSesActive = false
    isMyTournament = false
  }

  if (dayNum < DAY.NEXT)
    return res

  let now = ::get_charserver_time_sec()
  let sList = tour.scheduler[dayNum != DAY.NEXT ? dayNum : 0]
  local sTime
  local trainingTime
  local isTraining
  res.sesLen = sList.len()
  //Session is going now
  foreach(idx, inst in sList) {
    trainingTime = getTimestampFromStringUtc(inst.train.end) - now
    isTraining = trainingTime > 0
    sTime = isInTimerangeByUtcStrings(inst.train.start, inst.train.end)
        ? trainingTime
      : isInTimerangeByUtcStrings(inst.battle.start, inst.battle.end)
        ? getTimestampFromStringUtc(inst.battle.end) - now
      : -1
    if(sTime >= 0) {
      res.sesTime = sTime
      res.isSesActive = true
      res.sesIdx = idx
      res.isTraining = isTraining
      res.isMyTournament = ::is_subscribed_for_tournament(tour.id)
      return res
    }
  }
  //Nearest coming session
  foreach(idx, inst in sList){
    trainingTime = (!::u.isEmpty(inst.train.start)
        ? getTimestampFromStringUtc(inst.train.start)
        : 0)
      - now
    isTraining = trainingTime > 0
    sTime = trainingTime > 0 ? trainingTime
      : !::u.isEmpty(inst.battle.start) ? getTimestampFromStringUtc(inst.battle.start) - now
      : -1
    if (sTime >= 0) {
      res.sesTime = sTime
      res.sesIdx = idx
      res.isTraining = isTraining
      res.isMyTournament = ::is_subscribed_for_tournament(tour.id)
      return res
    }
  }
  return res
}

let getSessionTimeIntervalStr = @(schedule) "".concat(
  buildTimeStr(getTimestampFromStringUtc(schedule.start), false, false),
  loc("ui/hyphen"),
  buildTimeStr(getTimestampFromStringUtc(schedule.end), false, false))

let function getSessionsView(curSesIdx, scheduler) {
  if (curSesIdx < 0 || scheduler.len() == 0)
    return ""

  return scheduler.map(@(v, idx) {
    sesId = $"session_{idx}"
    sesNum = $" {idx + 1} "
    isSelected = idx == curSesIdx
    trainingTime = getSessionTimeIntervalStr(v.train)
    startTime = getSessionTimeIntervalStr(v.battle)
  })
}

let function getBattleDateStr(tour) {
  let beginTS = getTimestampFromStringUtc(tour.beginDate)
  let endTS = getTimestampFromStringUtc(tour.endDate)
  return "".concat(
    $"{buildDateStrShort(beginTS)}{loc("ui/comma")}{buildTimeStr(beginTS, false, false)}",
    loc("ui/mdash"),
    $"{buildDateStrShort(endTS)}{loc("ui/comma")}{buildTimeStr(endTS, false, false)}")
}

let function checkByFilter(tour, filter) {
  if (!filter)
    return true

  return (filter.tourStates.len() == 0
      || (filter.tourStates.findindex(@(v) v == "my") != null
        && ::is_subscribed_for_tournament(tour.id))
      || filter.tourStates.findindex(@(v) v == tour.competitive_type) != null)
    && (filter.unitStates.len() == 0
      || filter.unitStates.findindex(@(v) v == tour.armyId) != null)
}

let getOverlayTextColor = @(isSesActive) isSesActive ? "sPlay" : "sSelected"

let function getBattlesNum(event) {
  if (!event)
    return null

  let ticket = ::events.getEventActiveTicket(event)
  if (!ticket)
    return null

  let battleCount = event?.economicName
    ? (ticket.getTicketTournamentData(event.economicName)?.battleCount ?? 0)
    : 0

  return ticket.battleLimit - battleCount
}

let function fetchLbData(event, cb, context) {
  let newSelfRowRequest = ::events.getMainLbRequest(event)
  ::events.requestSelfRow(
    newSelfRowRequest,
    "mini_lb_self",
    function (_self_row) {
      ::events.requestLeaderboard(::events.getMainLbRequest(event),
      "mini_lb_self", cb, context)
    }, this)
}

let function getTourCommonViewParams(tour, tourParams, reverseCountries = false) {
  let cType = tour.competitive_type
  let teamSizes = cType.split("x")
  let armyId = tour.armyId
  let { dayNum, sesIdx, sesTime, isSesActive, isTraining, isMyTournament } = tourParams
  let isTourWndAvailable = isTournamentWndAvailable(dayNum)
  let isNext = dayNum == DAY.NEXT
  let isFinished = dayNum == DAY.FINISH
  let isSoon = dayNum == DAY.SOON
  let day = isNext ? 0 : dayNum
  let cNames = tour.country.split(",")
  let countries = []
  for (local i = 0; i < cNames.len() ; i++) {
    // Need to reverse icon order to get shadow matched to mockup
    let idx = reverseCountries ? cNames.len() - 1 - i : i
    countries.append({
      icon = ::get_country_icon($"{::g_string.trim(cNames[idx])}_round")
      xPos = idx
      halfLen = 0.5*cNames.len()
    })
  }
  return {
    armyId
    countries
    isTraining
    isFinished
    isSesActive
    isMyTournament
    isTourWndAvailable
    eventId = tour.id
    headerImg = isFinished || isSoon ? "#ui/gameuiskin#tournament_finished_header.png"
      : $"#ui/gameuiskin#tournament_{armyId}_header.png"
    itemBgr =  $"#ui/images/tournament_{armyId}.jpg"
    tournamentName = loc($"tournament/{tour.id}")
    vehicleType = loc($"tournaments/battle_{armyId}")
    rank = $"{::g_string.utf8ToUpper(loc("shop/age"))} {::get_roman_numeral(tour.rank)}"
    tournamentType = $" {loc("country/VS")} ".join(teamSizes)
    divisionImg = "#ui/gameuiskin#icon_progress_bar_stage_07.png"//!!!FIX IMG PATH
    battleDate = getBattleDateStr(tour)
    battleDay = isFinished ? loc("items/craft_process/finished")
      : isTourWndAvailable ? loc("tournaments/enumerated_day", {num = day + 1})
      : loc("tournaments/coming_soon")
    battlesNum = isTourWndAvailable
      ? (getBattlesNum(getEventByDay(tour.id, dayNum, isTraining)) ?? tour.tickets[day].battleLimit)
      : ""
    sessions = getSessionsView(sesIdx, tour.scheduler?[day] ?? [])
    curSesTime = sesTime <  0 ? null : secondsToString(sesTime)
    curTrainingTime = sesIdx < 0 ? null
      : getSessionTimeIntervalStr(tour.scheduler[day][sesIdx].train)
    curStartTime = sesIdx < 0 ? null
      : getSessionTimeIntervalStr(tour.scheduler[day][sesIdx].battle)
    overlayTextColor = getOverlayTextColor(isSesActive)
    lbBtnTxt = ::g_string.utf8ToUpper(loc("tournaments/leaderboard"))
  }
}

let function isTourStateChanged(prevState, tourParams) {
  let { dayNum, isTraining, isSesActive, isMyTournament } = tourParams
  return prevState != null
    && (prevState.isTraining != isTraining
      || prevState.isSesActive != isSesActive
      || prevState.dayNum != dayNum
      || prevState.isMyTournament != isMyTournament)
}

let function setSchedulerTimeColor(nestObj, isTraining, txtColor){
  let tTimeObj = nestObj.findObject("training_time")
  if (tTimeObj?.isValid())
    tTimeObj.overlayTextColor = isTraining ? txtColor : ""

  let sTimeObj = nestObj.findObject("start_time")
  if (sTimeObj?.isValid())
    sTimeObj.overlayTextColor = isTraining ? "" : txtColor
}

let function getTourListViewData(eList, filter) {
  let res = []
  foreach (tour in eList)
    res.append(getTourCommonViewParams(tour, getTourParams(tour)).__merge({
      isVisible = checkByFilter(tour, filter)
    }))

  return res
}

let function removeItemFromList(value, list) {
  let idx = list.findindex(@(v) v == value)
  if (idx != null)
    list.remove(idx)
}

let function getSeasonsList() {
  if (seasonsList.len() > 0)
    return seasonsList

  foreach (s in ::get_tournaments_blk() % "season") {
    let season = {tournamentList = []}
    eachParam(s, @(p, id) season[id] <- p)
    eachBlock(s, function(evnBlk, evnId){
      // Tournament ID means matching event economicName. It's the same as tournament LEADERBOARD id
      // Tournament sharedEconomicName means season id and tha same as SEASON LEADERBOARD id.
      let tour = {id = evnId}
      eachParam(evnBlk, @(p, id) tour[id] <- p)
      foreach (pName in TOUR_PARAM_NAMES) {
        let key = pName
        let curBlk = evnBlk?[key]
        tour[key] <- []
        let curParam = tour[key]
        if (!curBlk)
          continue

        eachBlock(curBlk, function(paramBlk, paramId){
          let data = {}
          eachParam(paramBlk, @(p, id) data[id] <- p)
          eachBlock(paramBlk, function(blk, pId){
            if (key == TOUR_PARAM_NAMES.TICKETS) {
              data.id <- paramId
              // Some ticket parameters are in separate block by design,
              // but they are ticket parameters anyway.
              eachParam(blk, @(p, id) data[id] <- p)
            }
            if (key == TOUR_PARAM_NAMES.SCHEDULER) {
              data[pId] <- {}
              eachParam(blk, @(p, id) data[pId][id] <- p)
            }
          })
          curParam.append(data)
        })
      }

      tour.tickets.sort(@(a, b)
        getTimestampFromStringUtc(a.startActiveTime)
          <=> getTimestampFromStringUtc(b.startActiveTime))

      // Reorder tournament scheduler by days
      let scheduler = []
      foreach (_idx, ticket in tour.tickets) {
        let day = []
        let sTime = getTimestampFromStringUtc(ticket.startActiveTime)
        let eTime = getTimestampFromStringUtc(ticket.stopActiveTime)
        foreach (session in tour.scheduler) {
          let curTime = getTimestampFromStringUtc(session.train.start)
          if ( curTime >= sTime && curTime <= eTime)
            day.append(session)
        }

        scheduler.append(day.sort(@(a, b)
          getTimestampFromStringUtc(a.train.start) <=> getTimestampFromStringUtc(b.train.start)))
      }

      tour.scheduler = scheduler
      tour.beginDate <- tour.tickets[0].startActiveTime
      tour.endDate <- tour.tickets[tour.tickets.len() - 1].stopActiveTime
      season.tournamentList.append(tour)
    })

    season.tournamentList.sort(@(a, b) a.beginDate <=> b.beginDate)
    seasonsList.append(season)
  }

  return seasonsList.sort(@(a, b) a.competitiveSeason <=> b.competitiveSeason)
}

let function getTourActiveTicket(eName, tourId) {
  if (!::have_you_valid_tournament_ticket(eName))
    return null
  let tickets = ::ItemsManager.getInventoryList(itemType.TICKET, (@(tourId) function (item) {
    return item.isForEvent(tourId) && item.isActive()
  })(tourId))
  return tickets.len() > 0 ? tickets[0] : null
}

let function getEventMission(curEvent) {
  let list = curEvent?.mission_decl.missions_list ?? {}
  foreach(key, _val in list)
    if (type(key) == "string")
      return key

  return ""
}

let getCurrentSeason = @() getSeasonsList()?[0]
let isRewardsAvailable = @(tournament) (tournament?.awards.len() ?? 0) > 0

let function getTourById(id) {
  let tourList = getCurrentSeason()?.tournamentList
  if (tourList != null)
    return tourList.findvalue(@(v) v.id == id)

  return null
}

let function hasAnyTickets() {
  let tourList = getCurrentSeason()?.tournamentList
  return tourList != null
    && tourList.findindex(@(tour) ::is_subscribed_for_tournament(tour.id)) != null
}

return {
  DAY
  TOURNAMENT_TYPES
  getTourDay
  getTourParams
  checkByFilter
  getTourCommonViewParams
  getTourListViewData
  removeItemFromList
  getMatchingEventId
  isTourStateChanged
  getCurrentSeason
  getTourById
  hasAnyTickets
  getEventByDay
  getTourActiveTicket
  getOverlayTextColor
  getEventMission
  isRewardsAvailable
  isTournamentWndAvailable
  setSchedulerTimeColor
  getSharedTourNameByEvent
  fetchLbData
}
