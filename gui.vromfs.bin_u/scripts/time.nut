//-file:plus-string
from "%scripts/dagui_natives.nut" import get_charserver_time_millisec
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

let { format, split_by_chars } = require("string")
let regexp2 = require("regexp2")
let math = require("math")
let timeBase = require("%appGlobals/timeLoc.nut")
let dagor_iso8601 = require("dagor.iso8601")
let { get_local_unixtime, unixtime_to_local_timetbl, local_timetbl_to_unixtime,
  unixtime_to_utc_timetbl, utc_timetbl_to_unixtime
} = require("dagor.time")
let { get_charserver_time_sec } = require("chard")

/**
 * Native API:
 * int get_charserver_time_sec() - gets UTC_posix_timestamp from char server clock.
 * int utc_timetbl_to_unixtime(timeTbl) - converts UTC_timeTable to UTC_posix_timestamp.
 * timeTbl unixtime_to_utc_timetbl(int) - converts UTC_posix_timestamp to UTC_timeTable.
 * int (get_local_unixtime() - charToLocalUtcDiff()) - gets UTC_posix_timestamp from client machine clock.
 * int (local_timetbl_to_unixtime(timeTbl) - charToLocalUtcDiff()) - converts local_timeTable to UTC_posix_timestamp.
 * timeTbl unixtime_to_local_timetbl(int + charToLocalUtcDiff()) - converts UTC_posix_timestamp to local_timeTable.
 */

let timeOrder = ["year", "month", "day", "hour", "min", "sec"]

let getCurrentYear = function() {
  let date = unixtime_to_local_timetbl(get_local_unixtime())
  return date.year
}

let charToLocalUtcDiff = function() {
  return get_local_unixtime() - get_charserver_time_sec()
}


local getFullTimeTable = function(time, fillMissedByTimeTable = null) {
  foreach (p in timeOrder) {
    if (!(p in time)) {
      time[p] <- getTblValue(p, fillMissedByTimeTable)
    }
    else {
      fillMissedByTimeTable = null  //only higher part from utc
    }
  }
  return time
}

let getUtcDays = @() timeBase.DAYS_TO_YEAR_1970 + get_charserver_time_sec() / timeBase.TIME_DAY_IN_SECONDS

let buildTabularDateTimeStr = function(t, showSeconds = false) {
  let tm = unixtime_to_local_timetbl(t + charToLocalUtcDiff())
  return showSeconds ?
    format("%04d-%02d-%02d %02d:%02d:%02d", tm.year, tm.month + 1, tm.day, tm.hour, tm.min, tm.sec) :
    format("%04d-%02d-%02d %02d:%02d", tm.year, tm.month + 1, tm.day, tm.hour, tm.min)
}


function getLocTimeTable(t) {
  let timeTable = unixtime_to_local_timetbl(t + charToLocalUtcDiff())
  timeTable.month = loc($"sm_month_{timeTable.month + 1}")
  return timeTable
}

let buildDateStrShort = @(t) loc("date_format_short", getLocTimeTable(t))

let buildDateStr = function(t) {
  let timeTable = getLocTimeTable(t)
  return loc(timeTable.year > 0 ? "date_format" : "date_format_short", timeTable)
}

let buildTimeStr = function(t, showZeroSeconds = false, showSeconds = true) {
  let timeTable = unixtime_to_local_timetbl(t + charToLocalUtcDiff())
  if (showSeconds && (showZeroSeconds || timeTable.sec > 0))
    return format("%d:%02d:%02d", timeTable.hour, timeTable.min, timeTable.sec)
  else
    return format("%d:%02d", timeTable.hour, timeTable.min)
}


let buildDateTimeStr = function (t, showZeroSeconds = false, showSeconds = true) {
  let timeTbl = unixtime_to_local_timetbl(t + charToLocalUtcDiff())
  let localTbl = unixtime_to_local_timetbl(get_local_unixtime())
  let timeStr = buildTimeStr(t, showZeroSeconds, showSeconds)
  return (localTbl.year == timeTbl.year && localTbl.month == timeTbl.month && localTbl.day == timeTbl.day)
    ? timeStr
    : " ".concat(buildDateStr(t), timeStr)
}

let getCurTimeMillisecStr = function() {
  let tMs = get_charserver_time_millisec()
  let timeTbl = unixtime_to_local_timetbl(tMs / 1000 + charToLocalUtcDiff())
  return format("%02d:%02d:%02d.%03d", timeTbl.hour, timeTbl.min, timeTbl.sec, tMs % 1000)
}


let getUtcMidnight = function() {
  return get_charserver_time_sec() / timeBase.TIME_DAY_IN_SECONDS * timeBase.TIME_DAY_IN_SECONDS
}


let validateTime = function (timeTbl) {
  timeTbl.year = clamp(timeTbl.year, 1970, 2037)
  timeTbl.month = clamp(timeTbl.month, 0, 11)
  timeTbl.day = clamp(timeTbl.day, 1, 31)
  timeTbl.hour = clamp(timeTbl.hour, 0, 23)
  timeTbl.min = clamp(timeTbl.min, 0, 59)
  timeTbl.sec = clamp(timeTbl.sec, 0, 59)
  let check = unixtime_to_utc_timetbl(utc_timetbl_to_unixtime(timeTbl))
  timeTbl.day -= (timeTbl.day == check.day) ? 0 : check.day
}

let reDateYmdAtStart = regexp2(@"^\d+-\d+-\d+")
let reTimeHmsAtEnd = regexp2(@"\d+:\d+:\d+$")
let reNotNumeric = regexp2(@"\D+")

function getTimeTblFromStringImpl(str) {
  let timeOrderLen = timeOrder.len()
  let timeArray = split_by_chars(str, ":- ").filter(@(v) v != "")
  if (timeArray.len() < timeOrderLen) {
    if (reDateYmdAtStart.match(str))
      timeArray.resize(timeOrderLen, "0")
    else if (!reTimeHmsAtEnd.match(str))
      timeArray.append("0")
  }

  let res = {}
  let lenDiff = min(0, timeArray.len() - timeOrderLen)
  for (local p = timeOrderLen - 1; p >= 0; --p) {
    let i = p + lenDiff
    if (i < 0) {
      break
    }

    if (! reNotNumeric.match(timeArray[i])) {
      res[timeOrder[p]] <- timeArray[i].tointeger()
    }
    else {
      return null
    }
  }

  if ("month" in res)
    res.month -= 1
 return res
}

let strToTimeCache = {}
function getTimeTblFromString(str) {
  if (str not in strToTimeCache)
    strToTimeCache[str] <- getTimeTblFromStringImpl(str)
  return strToTimeCache[str]
}

function getTimeFromString(str, fillMissedByTimeTable = null) {
  local timeTbl = getTimeTblFromString(str)
  if (timeTbl == null)
    return null

  timeTbl = getFullTimeTable(timeTbl, fillMissedByTimeTable)
  if (fillMissedByTimeTable) {
    validateTime(timeTbl)
  }
  return timeTbl
}

function getTimestampFromStringUtc(str) {
  return utc_timetbl_to_unixtime(getTimeFromString(str, unixtime_to_utc_timetbl(get_charserver_time_sec())))
}

function getTimestampFromStringLocal(str, fillMissedByTimestamp) {
  let fillMissedTimeTbl = unixtime_to_local_timetbl(fillMissedByTimestamp + charToLocalUtcDiff())
  return local_timetbl_to_unixtime(getTimeFromString(str, fillMissedTimeTbl)) - charToLocalUtcDiff()
}


function isInTimerangeByUtcStrings(beginDateStr, endDateStr) {
  if (!u.isEmpty(beginDateStr) &&
    getTimestampFromStringUtc(beginDateStr) > get_charserver_time_sec())
    return false
  if (!u.isEmpty(endDateStr) &&
    getTimestampFromStringUtc(endDateStr) < get_charserver_time_sec())
    return false
  return true
}

// For convenience, time periods may be specified without a year.
// In such cases, it is necessary to correctly determine the start and end times of the period,
// as they may be in different years.
function calculateCorrectTimePeriodYears(startTime, endTime) {
  // time period is within the current year
  if (startTime < endTime)
    return { startTime, endTime }

  // time period starts in the prev year
  if (get_charserver_time_sec() <= endTime) {
    let date = unixtime_to_utc_timetbl(startTime)
    --date.year
    startTime = utc_timetbl_to_unixtime(date)
  }
  // time period ends in the next year
  else {
    let date = unixtime_to_utc_timetbl(endTime)
    ++date.year
    endTime = utc_timetbl_to_unixtime(date)
  }

  return { startTime, endTime }
}

local function processTimeStamps(text) {
  foreach (_idx, time in ["{time=", "{time_countdown="]) {
    local startPos = 0
    let startTime = time
    let endTime = "}"

    while (true) {
      local startIdx = text.indexof(startTime, startPos)
      if (startIdx == null)
        break

      startIdx += startTime.len()
      let endIdx = text.indexof(endTime, startIdx)
      if (endIdx == null) {
        break
      }

      startPos++
      let t = getTimestampFromStringUtc(text.slice(startIdx, endIdx))
      if (t < 0)
        continue

      local textTime = ""
      if (time == "{time_countdown=") {
        textTime = timeBase.hoursToString(max(0, t - get_charserver_time_sec()) / timeBase.TIME_HOUR_IN_SECONDS_F, true, true)
      }
      else {
        textTime = buildDateTimeStr(t)
      }
      text = text.slice(0, startIdx - startTime.len()) + textTime + text.slice(endIdx + 1)
    }
  }

  return text
}


local function preciseSecondsToString(value, canShowZeroMinutes = true) {
  value = value != null ? value.tofloat() : 0.0
  let sign = value >= 0 ? "" : loc("ui/minus")
  local ms = (math.fabs(value) * 1000.0 + 0.5).tointeger()
  let mm = ms / 60000
  let ss = ms % 60000 / 1000
  ms = ms % 1000

  if (!canShowZeroMinutes && mm == 0)
    return format("%s%02d.%03d", sign, ss, ms)

  return format("%s%d:%02d.%03d", sign, mm, ss, ms)
}


function getRaceTimeFromSeconds(value, zeroIsValid = false) {
  if (type(value) != "float" && type(value) != "integer")
    return ""
  if (value < 0 || (!zeroIsValid && value == 0))
    return loc("leaderboards/notAvailable")
  return preciseSecondsToString(value)
}


function getExpireText(expireMin) {
  if (expireMin < timeBase.TIME_MINUTE_IN_SECONDS)
    return expireMin + loc("measureUnits/minutes")

  let showMin = expireMin < 3 * timeBase.TIME_MINUTE_IN_SECONDS
  let expireHours = math.floor(expireMin / timeBase.TIME_MINUTE_IN_SECONDS_F + (showMin ? 0.0 : 0.5))
  if (expireHours < 24)
    return expireHours + loc("measureUnits/hours") +
           (showMin ? " " + (expireMin - timeBase.TIME_MINUTE_IN_SECONDS * expireHours) + loc("measureUnits/minutes") : "")

  let showHours = expireHours < 3 * 24
  let expireDays = math.floor(expireHours / 24.0 + (showHours ? 0.0 : 0.5))
  return expireDays + loc("measureUnits/days") +
         (showHours ? " " + (expireHours - 24 * expireDays) + loc("measureUnits/hours") : "")
}


return timeBase.__merge({
  calculateCorrectTimePeriodYears
  getUtcDays = getUtcDays
  buildDateTimeStr = buildDateTimeStr
  buildDateStr
  buildDateStrShort
  buildTimeStr = buildTimeStr
  getCurTimeMillisecStr = getCurTimeMillisecStr
  buildTabularDateTimeStr = buildTabularDateTimeStr
  getUtcMidnight = getUtcMidnight
  getTimestampFromStringUtc = getTimestampFromStringUtc
  getTimestampFromStringLocal = getTimestampFromStringLocal
  isInTimerangeByUtcStrings = isInTimerangeByUtcStrings
  processTimeStamps = processTimeStamps
  getExpireText = getExpireText
  getCurrentYear = getCurrentYear

  preciseSecondsToString = preciseSecondsToString
  getRaceTimeFromSeconds = getRaceTimeFromSeconds

  getIso8601FromTimestamp = dagor_iso8601.format_unix_time
  getTimestampFromIso8601 = dagor_iso8601.parse_unix_time
})
