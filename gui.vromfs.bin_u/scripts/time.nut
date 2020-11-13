local math = require("math")
local timeBase = require("std/timeLoc.nut")
local dagor_iso8601 = require("dagor.iso8601")
local { get_local_unixtime, unixtime_to_local_timetbl, local_timetbl_to_unixtime,
  unixtime_to_utc_timetbl, utc_timetbl_to_unixtime
} = ::require_native("dagor.time")

/**
 * Native API:
 * int ::get_charserver_time_sec() - gets UTC_posix_timestamp from char server clock.
 * int utc_timetbl_to_unixtime(timeTbl) - converts UTC_timeTable to UTC_posix_timestamp.
 * timeTbl unixtime_to_utc_timetbl(int) - converts UTC_posix_timestamp to UTC_timeTable.
 * int (get_local_unixtime() - charToLocalUtcDiff()) - gets UTC_posix_timestamp from client machine clock.
 * int (local_timetbl_to_unixtime(timeTbl) - charToLocalUtcDiff()) - converts local_timeTable to UTC_posix_timestamp.
 * timeTbl unixtime_to_local_timetbl(int + charToLocalUtcDiff()) - converts UTC_posix_timestamp to local_timeTable.
 */

local timeOrder = ["year", "month", "day", "hour", "min", "sec"]


local charToLocalUtcDiff = function() {
  return get_local_unixtime() - ::get_charserver_time_sec()
}


local getFullTimeTable = function(time, fillMissedByTimeTable = null) {
  foreach(p in timeOrder) {
    if (!(p in time)) {
      time[p] <- ::getTblValue(p, fillMissedByTimeTable)
    } else {
      fillMissedByTimeTable = null  //only higher part from utc
    }
  }
  return time
}

local getUtcDays = @() timeBase.DAYS_TO_YEAR_1970 + ::get_charserver_time_sec() / timeBase.TIME_DAY_IN_SECONDS

local buildTabularDateTimeStr = function(t, showSeconds = false)
{
  local tm = unixtime_to_local_timetbl(t + charToLocalUtcDiff())
  return showSeconds ?
    ::format("%04d-%02d-%02d %02d:%02d:%02d", tm.year, tm.month+1, tm.day, tm.hour, tm.min, tm.sec) :
    ::format("%04d-%02d-%02d %02d:%02d", tm.year, tm.month+1, tm.day, tm.hour, tm.min)
}


local buildDateStr = function(t) {
  local timeTable = unixtime_to_local_timetbl(t + charToLocalUtcDiff())
  local date_str = ""

  local year = ::getTblValue("year", timeTable, -1)
  local month = ::getTblValue("month", timeTable, -1)
  local day = ::getTblValue("day", timeTable, -1)

  local monthLoc = ::loc("sm_month_" + (month+1))

  if (year > 0)
    date_str = ::format(::loc("date_format", {year = year, day = day, month = monthLoc}))
  else
    date_str = ::format(::loc("date_format_short", {day = day, month = monthLoc}))

  return date_str
}


local buildTimeStr = function(t, showZeroSeconds = false, showSeconds = true) {
  local timeTable = unixtime_to_local_timetbl(t + charToLocalUtcDiff())
  local sec = timeTable?.sec ?? -1
  if (showSeconds && (sec > 0 || (showZeroSeconds && sec == 0)))
    return ::format("%d:%02d:%02d", timeTable.hour, timeTable.min, timeTable.sec)
  else
    return ::format("%d:%02d", timeTable.hour, timeTable.min)
}


local buildDateTimeStr = function (t, showZeroSeconds = false, showSeconds = true) {
  local timeTable = unixtime_to_local_timetbl(t + charToLocalUtcDiff())
  local time_str = buildTimeStr(t, showZeroSeconds, showSeconds)
  local localTime = unixtime_to_local_timetbl(get_local_unixtime())
  local year = ::getTblValue("year", timeTable, -1)
  local month = ::getTblValue("month", timeTable, -1)
  local day = ::getTblValue("day", timeTable, -1)

  if ((localTime.year == year && localTime.month == month && localTime.day == day)
      || (day <= 0 && month < 0))
    return time_str

  return buildDateStr(t) + " " + time_str
}

local getUtcMidnight = function() {
  return ::get_charserver_time_sec() / timeBase.TIME_DAY_IN_SECONDS * timeBase.TIME_DAY_IN_SECONDS
}


local validateTime = function (timeTbl) {
  timeTbl.year = ::clamp(timeTbl.year, 1970, 2037)
  timeTbl.month = ::clamp(timeTbl.month, 0, 11)
  timeTbl.day = ::clamp(timeTbl.day, 1, 31)
  timeTbl.hour = ::clamp(timeTbl.hour, 0, 23)
  timeTbl.min = ::clamp(timeTbl.min, 0, 59)
  timeTbl.sec = ::clamp(timeTbl.sec, 0, 59)
  local check = unixtime_to_utc_timetbl(utc_timetbl_to_unixtime(timeTbl))
  timeTbl.day -= (timeTbl.day == check.day) ? 0 : check.day
}

local reDateYmdAtStart = regexp2(@"^\d+-\d+-\d+")
local reTimeHmsAtEnd = regexp2(@"\d+:\d+:\d+$")
local reNotNumeric = regexp2(@"\D+")

local getTimeFromString = function(str, fillMissedByTimeTable = null) {
  local timeOrderLen = timeOrder.len()
  local timeArray = ::split(str, ":- ").filter(@(v) v != "")
  if (timeArray.len() < timeOrderLen)
  {
    if (reDateYmdAtStart.match(str))
      timeArray.resize(timeOrderLen, "0")
    else if (!reTimeHmsAtEnd.match(str))
      timeArray.append("0")
  }

  local res = {}
  local lenDiff = ::min(0, timeArray.len() - timeOrderLen)
  for(local p = timeOrderLen - 1; p >= 0; --p) {
    local i = p + lenDiff
    if (i < 0) {
      break
    }

    if (! reNotNumeric.match(timeArray[i])) {
      res[timeOrder[p]] <- timeArray[i].tointeger()
    } else {
      return null
    }
  }

  if ("month" in res) {
    res.month -= 1
  }

  local timeTbl = getFullTimeTable(res, fillMissedByTimeTable)
  if (fillMissedByTimeTable) {
    validateTime(timeTbl)
  }
  return timeTbl
}


local getTimestampFromStringUtc = function(str) {
  return utc_timetbl_to_unixtime(getTimeFromString(str, unixtime_to_utc_timetbl(::get_charserver_time_sec())))
}

local getTimestampFromStringLocal = function(str, fillMissedByTimestamp) {
  local fillMissedTimeTbl = unixtime_to_local_timetbl(fillMissedByTimestamp + charToLocalUtcDiff())
  return local_timetbl_to_unixtime(getTimeFromString(str, fillMissedTimeTbl)) - charToLocalUtcDiff()
}


local isInTimerangeByUtcStrings = function(beginDateStr, endDateStr) {
  if (!::u.isEmpty(beginDateStr) &&
    getTimestampFromStringUtc(beginDateStr) > ::get_charserver_time_sec())
    return false
  if (!::u.isEmpty(endDateStr) &&
    getTimestampFromStringUtc(endDateStr) < ::get_charserver_time_sec())
    return false
  return true
}


local processTimeStamps = function(text) {
  foreach (idx, time in ["{time=", "{time_countdown="]) {
    local startPos = 0
    local startTime = time
    local endTime = "}"

    local continueSearch = true
    do {
      local startIdx = text.indexof(startTime, startPos)
      continueSearch = (startIdx != null)
      if (!continueSearch) {
        break
      }

      startIdx += startTime.len()
      local endIdx = text.indexof(endTime, startIdx)
      if (endIdx == null) {
        break
      }

      startPos++
      local t = getTimestampFromStringUtc(text.slice(startIdx, endIdx))
      if (t < 0)
        continue

      local textTime = ""
      if (time == "{time_countdown=") {
        textTime = timeBase.hoursToString(::max( 0, t - ::get_charserver_time_sec() ) / timeBase.TIME_HOUR_IN_SECONDS_F, true, true)
      } else {
        textTime = buildDateTimeStr(t)
      }
      text = text.slice(0, startIdx - startTime.len()) + textTime + text.slice(endIdx+1)
    } while(continueSearch)
  }

  return text
}


local function preciseSecondsToString(value, canShowZeroMinutes = true) {
  value = value != null ? value.tofloat() : 0.0
  local sign = value >= 0 ? "" : ::loc("ui/minus")
  local ms = (math.fabs(value) * 1000.0 + 0.5).tointeger()
  local mm = ms / 60000
  local ss = ms % 60000 / 1000
  ms = ms % 1000

  if (!canShowZeroMinutes && mm == 0)
    return ::format("%s%02d.%03d", sign, ss, ms)

  return ::format("%s%d:%02d.%03d", sign, mm, ss, ms)
}


local function getRaceTimeFromSeconds(value, zeroIsValid = false) {
  if (typeof value != "float" && typeof value != "integer")
    return ""
  if (value < 0 || (!zeroIsValid && value == 0))
    return ::loc("leaderboards/notAvailable")
  return preciseSecondsToString(value)
}


local function getExpireText(expireMin) {
  if (expireMin < timeBase.TIME_MINUTE_IN_SECONDS)
    return expireMin + ::loc("measureUnits/minutes")

  local showMin = expireMin < 3 * timeBase.TIME_MINUTE_IN_SECONDS
  local expireHours = math.floor(expireMin / timeBase.TIME_MINUTE_IN_SECONDS_F + (showMin? 0.0 : 0.5))
  if (expireHours < 24)
    return expireHours + ::loc("measureUnits/hours") +
           (showMin? " " + (expireMin - timeBase.TIME_MINUTE_IN_SECONDS * expireHours) + ::loc("measureUnits/minutes") : "")

  local showHours = expireHours < 3*24
  local expireDays = math.floor(expireHours / 24.0 + (showHours? 0.0 : 0.5))
  return expireDays + ::loc("measureUnits/days") +
         (showHours? " " + (expireHours - 24*expireDays) + ::loc("measureUnits/hours") : "")
}


return timeBase.__merge({
  getUtcDays = getUtcDays
  buildDateTimeStr = buildDateTimeStr
  buildDateStr = buildDateStr
  buildTimeStr = buildTimeStr
  buildTabularDateTimeStr = buildTabularDateTimeStr
  getUtcMidnight = getUtcMidnight
  getTimestampFromStringUtc = getTimestampFromStringUtc
  getTimestampFromStringLocal = getTimestampFromStringLocal
  isInTimerangeByUtcStrings = isInTimerangeByUtcStrings
  processTimeStamps = processTimeStamps
  getExpireText = getExpireText

  preciseSecondsToString = preciseSecondsToString
  getRaceTimeFromSeconds = getRaceTimeFromSeconds

  getIso8601FromTimestamp = dagor_iso8601.format_unix_time
  getTimestampFromIso8601 = dagor_iso8601.parse_unix_time
})
