let { eachBlock, eachParam } = require("%sqstd/datablock.nut")
let { buildTimeStr,  buildDateStrShort, isInTimerangeByUtcStrings,
  getTimestampFromStringUtc } = require("%scripts/time.nut")
let { secondsToString } = require("%scripts/timeLoc.nut")
let { secondsToDays } = require("%sqstd/time.nut")

const MY_TOURNAMENTS = "tournaments/favorites"
const MY_FILTERS = "tournaments/filters"
const NEXT_DAYS = 14

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
local tournamentUserData = {}

let function getTourUserData() {
  if (::g_login.isProfileReceived() && ::u.isEmpty(tournamentUserData))
    tournamentUserData = {
      myTournaments = ::load_local_account_settings(MY_TOURNAMENTS)
      myFilters = ::load_local_account_settings(MY_FILTERS)
    }

  return tournamentUserData
}

let function getTourDay(tour) {
  let now = ::get_charserver_time_sec()
  if (now > getTimestampFromStringUtc(tour.tickets[tour.tickets.len() - 1].stopActiveTime))
    return DAY.FINISH

  let activeDay = tour.tickets.findindex(@(t) now >= getTimestampFromStringUtc(t.startActiveTime)
    && now <= getTimestampFromStringUtc(t.stopActiveTime))
  if (activeDay != null)
    return activeDay

  if (tour.tickets.findindex(@(t) secondsToDays(
    getTimestampFromStringUtc(t.startActiveTime) - now) < NEXT_DAYS) != null)
      return DAY.NEXT

  return DAY.SOON
}

let function isTournamentWndAvailable(tour) {
  let dayNum = getTourDay(tour)
  return dayNum != DAY.FINISH && dayNum != DAY.SOON
}

let function getSessionParams(tour) {
  let dayNum = getTourDay(tour)
  let res = {
    dayNum      = dayNum
    sesIdx      = -1
    sesTime     = -1
    sesLen      = 0
    isTraining  = false
    isSesActive = false
  }

  if (dayNum < DAY.NEXT)
    return res

  let now = ::get_charserver_time_sec()
  let sList = tour.scheduler[dayNum != DAY.NEXT ? dayNum : 0]
  local sTime
  local trainingTime
  res.sesLen = sList.len()
  //Session is going now
  foreach(idx, inst in sList) {
    trainingTime = getTimestampFromStringUtc(inst.train.end) - now
    sTime = isInTimerangeByUtcStrings(inst.train.start, inst.train.end)
        ? trainingTime
      : isInTimerangeByUtcStrings(inst.battle.start, inst.battle.end)
        ? getTimestampFromStringUtc(inst.battle.end) - now
      : -1
    if(sTime >= 0) {
      res.sesTime = sTime
      res.isSesActive = true
      res.sesIdx = idx
      res.isTraining = trainingTime > 0
      return res
    }
  }
  //Nearest coming session
  foreach(idx, inst in sList){
    trainingTime = (!::u.isEmpty(inst.train.start)
        ? getTimestampFromStringUtc(inst.train.start)
        : 0)
      - now
    sTime = trainingTime > 0 ? trainingTime
      : !::u.isEmpty(inst.battle.start) ? getTimestampFromStringUtc(inst.battle.start) - now
      : -1
    if (sTime >= 0) {
      res.sesTime = sTime
      res.sesIdx = idx
      res.isTraining = trainingTime > 0
      return res
    }
  }
  return res
}

let getSessionTimeIntervalStr = @(schedule) "".concat(
  buildTimeStr(getTimestampFromStringUtc(schedule.start), false, false),
  ::loc("ui/hyphen"),
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
    $"{buildDateStrShort(beginTS)}{::loc("ui/comma")}{buildTimeStr(beginTS, false, false)}",
    ::loc("ui/mdash"),
    $"{buildDateStrShort(endTS)}{::loc("ui/comma")}{buildTimeStr(endTS, false, false)}")
}

let function checkByFilter(tour, filter) {
  if (!filter)
    return true

  return (filter.tourStates.len() == 0
      || filter.tourStates.findindex(@(v) v == tour.competitive_type) != null)
    && (filter.unitStates.len() == 0
      || filter.unitStates.findindex(@(v) v == tour.armyId) != null)
}

let getOverlayTextColor = @(isSesActive) isSesActive ? "sPlay" : "sSelected"

let function getTourCommonViewParams(tour, sesParams, reverseCountries = false) {
  let cType = tour.competitive_type
  let teamSizes = cType.split("x")
  let armyId = tour.armyId
  let { dayNum, sesIdx, sesTime, isSesActive, isTraining } = sesParams
  let isActive = dayNum >= 0
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
    armyId = armyId
    countries = countries
    headerImg = isFinished || isSoon ? "#ui/gameuiskin#tournament_finished_header.png"
      : $"#ui/gameuiskin#tournament_{armyId}_header.png"
    itemBgr =  $"#ui/images/tournament_{armyId}.jpg"
    tournamentName = ::loc(tour.sharedeconomicName)
    vehicleType = ::loc($"tournaments/battle_{armyId}")
    rank = $"{::g_string.utf8ToUpper(::loc("shop/age"))} {::get_roman_numeral(tour.rank)}"
    tournamentType = ::loc("country/VS").join(teamSizes)
    divisionImg = "#ui/gameuiskin#icon_progress_bar_stage_07.png"//!!!FIX IMG PATH
    battleDate = getBattleDateStr(tour)
    battleDay = isFinished ? ::loc("items/craft_process/finished")
      : isActive ? ::loc("tournaments/enumerated_day", {num = day + 1})
      : ::loc("tournaments/coming_soon")
    battlesNum = isActive ? tour.tickets[day].battleLimit : ""
    eventId = tour.id
    isMyTournament = tour.id in getTourUserData()?.myTournaments
    isFinished = isFinished
    isActive = isActive
    isNext = isNext
    sessions = getSessionsView(sesIdx, tour.scheduler?[day] ?? [])
    isSesActive = isSesActive
    isTraining = isTraining
    curSesTime = sesTime <  0 ? null : secondsToString(sesTime)
    curTrainingTime = sesIdx < 0 ? null
      : getSessionTimeIntervalStr(tour.scheduler[day][sesIdx].train)
    curStartTime = sesIdx < 0 ? null
      : getSessionTimeIntervalStr(tour.scheduler[day][sesIdx].battle)
    overlayTextColor = getOverlayTextColor(isSesActive)
  }
}

let function isTourStateChanged(prevState, sesParams) {
  let { dayNum, isTraining, isSesActive } = sesParams
  return prevState != null
    && (prevState.isTraining != isTraining
      || prevState.isSesActive != isSesActive
      || prevState.dayNum != dayNum)
}

let function updateTourView(tObj, tour, tourStatesList, sesParams) {
  let { sesIdx, sesLen, isSesActive, isTraining } = sesParams
  let { battleDay, isFinished, battlesNum, curSesTime, isActive,
    curTrainingTime, curStartTime } = getTourCommonViewParams(tour, sesParams)
  let prevState = clone tourStatesList?[tour.id]
  let timeTxtObj = tObj.findObject("time_txt")
  tourStatesList[tour.id] <- sesParams
  if (!timeTxtObj?.isValid())
    return

  if (!isTourStateChanged(prevState, sesParams)) {
    if (curSesTime)
      timeTxtObj.setValue(curSesTime)

    return
  }

  let bgrObj = tObj.findObject("item_bgr")
  if (bgrObj?.isValid())
    bgrObj["background-saturate"] = isFinished ? 0 : 1
  ::showBtn("leaderboard_img", isFinished, tObj)
  ::showBtn("leaderboard_btn", isFinished, tObj)
  tObj.findObject("battle_day").setValue(battleDay)
  if (isFinished)
    return

  let battlesObj = ::showBtn("battle_nest", isActive, tObj)
  let sessionObj = ::showBtn("session_nest", isActive, tObj)
  let trainingObj = ::showBtn("training_nest", isActive, tObj)
  let startObj = ::showBtn("start_nest", isActive, tObj)
  if (!isActive)
    return

  let iconImg = $"#ui/gameuiskin#{isSesActive ? "play_tour" : "clock_tour"}.svg"
  battlesObj.findObject("battle_num").setValue(battlesNum)
  timeTxtObj.setValue(curSesTime)
  timeTxtObj.overlayTextColor = getOverlayTextColor(isSesActive)
  sessionObj.findObject("session_ico")["background-image"] = iconImg
  let tTimeObj = trainingObj.findObject("training_time")
  let sTimeObj = startObj.findObject("start_time")
  if (tTimeObj?.isValid()) {
    tTimeObj.setValue(curTrainingTime)
    tTimeObj.overlayTextColor = isTraining ? getOverlayTextColor(isSesActive) : ""
  }
  if (sTimeObj?.isValid()) {
    sTimeObj.setValue(curStartTime)
    sTimeObj.overlayTextColor = isTraining ? "" : getOverlayTextColor(isSesActive)
  }
  for (local i = 0; i < sesLen; i++)
    sessionObj.findObject($"session_{i}").visualStyle = i == sesIdx ? "sessionSelected" : ""
}

let function getTourListViewData(eList, filter) {
  let res = []
  foreach (tour in eList)
    res.append(getTourCommonViewParams(tour, getSessionParams(tour)).__merge({
      isVisible = checkByFilter(tour, filter)
    }))

  return res
}

let function removeItemFromList(value, list) {
  let idx = list.findindex(@(v) v == value)
  if (idx != null)
    list.remove(idx)
}

let getMatchingEventId = @(eventId, day, isTraining)
  $"{eventId}{day ? "_day" : ""}{day ?? ""}{isTraining ? "_train" : ""}"

let function getSeasonsList() {
  if (seasonsList.len() > 0)
    return seasonsList

  foreach (s in ::get_tournaments_blk() % "season") {
    let season = {tournamentList = []}
    eachParam(s, @(p, id) season[id] <- p)
    eachBlock(s, function(evnBlk, evnId){
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
      foreach (idx, ticket in tour.tickets) {
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

let getCurrentSeason = @() getSeasonsList()?[0]

let getTourById = @(id) getCurrentSeason()?.tournamentList.findvalue(@(v) v.id == id)

return {
  DAY
  getSessionParams
  checkByFilter
  getTourCommonViewParams
  getTourListViewData
  removeItemFromList
  getMatchingEventId
  isTourStateChanged
  getCurrentSeason
  getTourById
  updateTourView
  MY_FILTERS
  getTourUserData
  isTournamentWndAvailable
}
