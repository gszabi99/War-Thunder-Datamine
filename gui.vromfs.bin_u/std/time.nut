/*
  bad module - it depends on localization
  consider to get table of localizations instead in parameter - or move it out std.lib - or split it into two modules
*/
local stdStr = require("string")
local math = require("math")


const TIME_SECOND_IN_MSEC = 1000
const TIME_SECOND_IN_MSEC_F = 1000.0
const TIME_MINUTE_IN_SECONDS = 60
const TIME_MINUTE_IN_SECONDS_F = 60.0
const TIME_HOUR_IN_SECONDS = 3600
const TIME_HOUR_IN_SECONDS_F = 3600.0
const TIME_DAY_IN_HOURS = 24
const TIME_DAY_IN_SECONDS = 86400
const TIME_DAY_IN_SECONDS_F = 86400.0
const TIME_WEEK_IN_SECONDS = 604800
const TIME_WEEK_IN_SECONDS_F = 604800.0
const DAYS_TO_YEAR_1970 = 719528


local millisecondsToSeconds = @(time) time / TIME_SECOND_IN_MSEC_F
local secondsToMilliseconds = @(time) time * TIME_SECOND_IN_MSEC_F
local millisecondsToSecondsInt = @(time) time / TIME_SECOND_IN_MSEC
local secondsToMinutes = @(time) time / TIME_MINUTE_IN_SECONDS_F
local minutesToSeconds = @(time) time * TIME_MINUTE_IN_SECONDS_F
local secondsToHours = @(seconds) seconds / TIME_HOUR_IN_SECONDS_F
local hoursToSeconds = @(seconds) seconds * TIME_HOUR_IN_SECONDS_F
local daysToSeconds = @(days) days * TIME_DAY_IN_SECONDS_F

local function hoursToString(time, full = true, useSeconds = false, dontShowZeroParam = false, fullUnits = false, i18n = ::loc) {
  local res = []
  local sign = time >= 0 ? "" : i18n("ui/minus")
  time = math.fabs(time.tofloat())

  local dd = (time / 24).tointeger()
  local hh = (time % 24).tointeger()
  local mm = (time * TIME_MINUTE_IN_SECONDS % TIME_MINUTE_IN_SECONDS).tointeger()
  local ss = (time * TIME_HOUR_IN_SECONDS % TIME_MINUTE_IN_SECONDS).tointeger()

  if (dd>0) {
    res.append(fullUnits ? i18n("measureUnits/full/days", { n = dd }) :
      "{0}{1}".subst(dd,i18n("measureUnits/days")))
    if (dontShowZeroParam && hh == 0) {
      return "".join([sign].extend(res))
    }
  }

  if (hh && (full || time<24*7)) {
    if (res.len()>0)
      res.append(" ")
    res.append(fullUnits ? i18n("measureUnits/full/hours", { n = hh }) :
      stdStr.format((time >= 24)? "%02d%s" : "%d%s", hh, i18n("measureUnits/hours")))
    if (dontShowZeroParam && mm == 0) {
      return "".join([sign].extend(res))
    }
  }

  if ((mm || (!res.len() && !useSeconds)) && (full || time<24)) {
    if (res.len()>0)
      res.append(" ")
    res.append(fullUnits ? i18n("measureUnits/full/minutes", { n = mm }) :
      stdStr.format((time >= 1)? "%02d%s" : "%d%s", mm, i18n("measureUnits/minutes")))
  }

  if (((ss && useSeconds) || res.len()==0) && (time < 1.0 / 6)) { // < 10min
    if (res.len()>0)
      res.append(" ")
    res.append(fullUnits ? i18n("measureUnits/full/seconds", { n = ss }) :
      stdStr.format("%02d%s", ss, i18n("measureUnits/seconds")))
  }

  if (res.len()==0)
    return ""
  return "".join([sign].extend(res))
}


local function secondsToString(value, useAbbreviations = true, dontShowZeroParam = false, secondsFraction = 0, i18n = ::loc) {
  value = value != null ? value.tofloat() : 0.0
  local s = (math.fabs(value) + 0.5).tointeger()
  local res = []
  local separator = useAbbreviations ? " " : ":"
  local sign = value >= 0 ? "" : i18n("ui/minus")

  local hoursNum = s / TIME_HOUR_IN_SECONDS
  local minutesNum = (s % TIME_HOUR_IN_SECONDS) / TIME_MINUTE_IN_SECONDS
  local secondsNum = (secondsFraction > 0 ? value : s) % TIME_MINUTE_IN_SECONDS

  if (hoursNum != 0) {
    res.append(stdStr.format("%d%s", hoursNum, useAbbreviations ? i18n("measureUnits/hours") : ""))
  }

  if (!dontShowZeroParam || minutesNum != 0) {
    local fStr = res.len() > 0 ? "%02d%s" : "%d%s"
    if (res.len()>0)
      res.append(separator)
    res.append(
      stdStr.format(fStr, minutesNum, useAbbreviations ? i18n("measureUnits/minutes") : "")
    )
  }

  if (!dontShowZeroParam || secondsNum != 0 || res.len()==0) {
    local symbolsNum = res.len() ? 2 : 1
    local fStr = secondsFraction > 0
      ? $"%0{secondsFraction + 1 + symbolsNum}.{secondsFraction}f%s"
      : $"%0{symbolsNum}d%s"
    if (res.len()>0)
      res.append(separator)
    res.append(
      stdStr.format(fStr, secondsNum, useAbbreviations ? i18n("measureUnits/seconds") : "")
    )
  }

  if (res.len()==0)
    return ""
  return "".join([sign].extend(res))
}


local timeTbl = {
  s = 1
  m = TIME_MINUTE_IN_SECONDS
  h = TIME_HOUR_IN_SECONDS
  d = TIME_DAY_IN_SECONDS
  w = TIME_WEEK_IN_SECONDS
}

local function getSecondsFromTemplate (str, errorValue = null) {
 // "1w 1d 1h 1m 1s"
  if (!str.len())
    return errorValue

  local seconds = 0
  foreach (val in ::split(str, " ")) {
    local key = val.slice(val.len() - 1)
    if (!(key in timeTbl))
      return errorValue

    local timeVal = val.slice(0, val.len() - 1)
    if (!::g_string.isStringInteger(timeVal))
      return errorValue

    seconds += timeVal.tointeger() * timeTbl[key]
  }

  return seconds
}


local export = {
  millisecondsToSeconds = millisecondsToSeconds
  secondsToMilliseconds = secondsToMilliseconds
  millisecondsToSecondsInt = millisecondsToSecondsInt
  secondsToMinutes = secondsToMinutes
  minutesToSeconds = minutesToSeconds
  secondsToHours = secondsToHours
  hoursToSeconds = hoursToSeconds
  daysToSeconds = daysToSeconds

  hoursToString = hoursToString
  secondsToString = secondsToString
  getSecondsFromTemplate = getSecondsFromTemplate

  TIME_SECOND_IN_MSEC = TIME_SECOND_IN_MSEC
  TIME_SECOND_IN_MSEC_F = TIME_SECOND_IN_MSEC_F
  TIME_MINUTE_IN_SECONDS = TIME_MINUTE_IN_SECONDS
  TIME_MINUTE_IN_SECONDS_F = TIME_MINUTE_IN_SECONDS_F
  TIME_HOUR_IN_SECONDS = TIME_HOUR_IN_SECONDS
  TIME_HOUR_IN_SECONDS_F = TIME_HOUR_IN_SECONDS_F
  TIME_DAY_IN_HOURS = TIME_DAY_IN_HOURS
  TIME_DAY_IN_SECONDS = TIME_DAY_IN_SECONDS
  TIME_DAY_IN_SECONDS_F = TIME_DAY_IN_SECONDS_F
  TIME_WEEK_IN_SECONDS = TIME_WEEK_IN_SECONDS
  TIME_WEEK_IN_SECONDS_F = TIME_WEEK_IN_SECONDS_F
  DAYS_TO_YEAR_1970 = DAYS_TO_YEAR_1970
}


return export
