local stdStr = require("string")

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
local secondsToMilliseconds = @(time) time * TIME_SECOND_IN_MSEC
local millisecondsToSecondsInt = @(time) time / TIME_SECOND_IN_MSEC
local secondsToMinutes = @(time) time / TIME_MINUTE_IN_SECONDS_F
local minutesToSeconds = @(time) time * TIME_MINUTE_IN_SECONDS
local secondsToHours = @(seconds) seconds / TIME_HOUR_IN_SECONDS_F
local hoursToSeconds = @(seconds) seconds * TIME_HOUR_IN_SECONDS
local daysToSeconds = @(days) days * TIME_DAY_IN_SECONDS

local function secondsToTime(time){
  if(::type(time)=="table" && "seconds" in time)
    return time
  local s = time.tointeger()
  local milliseconds = ((time-s)*1000).tointeger()
  local hoursNum = (s / TIME_HOUR_IN_SECONDS) % 24
  local minutesNum = (s % TIME_HOUR_IN_SECONDS) / TIME_MINUTE_IN_SECONDS
  local secondsNum = s % TIME_MINUTE_IN_SECONDS
  local days = (s / TIME_DAY_IN_SECONDS)
  if (days<2){
    hoursNum = hoursNum + days*24
    days = 0
  }
  return {days=days, hours = hoursNum, minutes = minutesNum, seconds = secondsNum, milliseconds=milliseconds}
}

local function secondsToTimeSimpleString(time) {
  local {hours=0, minutes=0, seconds=0} = secondsToTime(time)
  local minuteStr = hours > 0 ? stdStr.format("%02d", minutes) : minutes.tostring()
  local hoursStr = hours > 0 ? hours.tostring() : null
  local secondsStr = stdStr.format("%02d", seconds)//minutes+hours > 0 ? stdStr.format("%02d", seconds) : seconds.tostring()
  local res = ":".join([hoursStr,minuteStr,secondsStr].filter(@(v) v != null))
  return time < 0 ? $"-{res}" : $"{res}"
}

local function roundTime(time){
  local t = (::type(time)=="table" && "seconds" in time) ? clone time : secondsToTime(time)
  if (t.days > 0 || t.hours > 24) {
    t.minutes = 0
    t.seconds = 0
  }
  if (t.minutes > 10 || t.hours > 1 || t.days > 0) {
    t.seconds = 0
  }
  return t
}

local timeTbl = {
  s = 1
  m = TIME_MINUTE_IN_SECONDS
  h = TIME_HOUR_IN_SECONDS
  d = TIME_DAY_IN_SECONDS
  w = TIME_WEEK_IN_SECONDS
}

local function getSecondsFromTemplate(str, errorValue = null) {
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

local function secondsToTimeFormatString(time) {
  local {days=0, hours=0, minutes=0, seconds=0} = secondsToTime(time)
  local res = []
  if (days>0)
    res.append(days, "{days}", " ")//warning disable: -forgot-subst
  if (hours>0)
    res.append(hours, "{hours}", " ")//warning disable: -forgot-subst
  if (minutes>0)
    res.append(minutes,"{minutes}" ," ")//warning disable: -forgot-subst
  if (seconds>0)
    res.append(minutes+hours > 0 ? stdStr.format("%02d", seconds) : seconds.tostring(),"{seconds}")//warning disable: -forgot-subst
  return "".join(res)
}

return {
  millisecondsToSeconds
  secondsToMilliseconds
  millisecondsToSecondsInt
  secondsToMinutes
  minutesToSeconds
  secondsToHours
  hoursToSeconds
  daysToSeconds

  secondsToTimeFormatString
  secondsToTimeSimpleString
  secondsToTime
  roundTime
  getSecondsFromTemplate

  TIME_SECOND_IN_MSEC
  TIME_SECOND_IN_MSEC_F
  TIME_MINUTE_IN_SECONDS
  TIME_MINUTE_IN_SECONDS_F
  TIME_HOUR_IN_SECONDS
  TIME_HOUR_IN_SECONDS_F
  TIME_DAY_IN_HOURS
  TIME_DAY_IN_SECONDS
  TIME_DAY_IN_SECONDS_F
  TIME_WEEK_IN_SECONDS
  TIME_WEEK_IN_SECONDS_F
  DAYS_TO_YEAR_1970
}
