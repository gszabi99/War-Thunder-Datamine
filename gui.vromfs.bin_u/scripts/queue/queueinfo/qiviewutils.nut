from "%scripts/dagui_library.nut" import *

let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let time = require("%scripts/time.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { USEROPT_COUNTRY } = require("%scripts/options/optionsExtNames.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { MAX_COUNTRY_RANK } = require("%scripts/ranks.nut")
let { findQueue } = require("%scripts/queue/queueState.nut")
let { getQueueEvent, getQueueCountry, getMyRankInQueue } = require("%scripts/queue/queueInfo.nut")

function getQueueInfo(queue, txt = null) {
  if (!queue)
    return ""
  
  let addLine = txt ? $"\n{loc("yn1/waiting_time")}" : ""
  local msg = txt ? txt : loc("yn1/wait_for_session")
  let waitTime = queue ? queue.getActiveTime().tointeger() : 0
  if (waitTime > 0)
    msg = "".concat(msg, addLine, loc("ui/colon"), time.secondsToString(waitTime, false))
  return msg
}

function createQueueViewByCountries(nestObj, queue, event) {
  let needRankInfo = events.needRankInfoInQueue(event)
  let headerColumns = []
  let view = {
    rows = [
      {
        rowParam = "queueTableIconRow"
        columns = headerColumns
      }
      {
        rowParam = needRankInfo ? "queueTableTitleRow" : "queueTableBigTitleRow"
        columns = [{
          id = "total_in_queue"
          text = "#multiplayer/playersInQueue"
        }]
      }
    ]
  }

  
  foreach (_i, countryName in shopCountriesList)
    headerColumns.append({
      image = getCountryIcon(countryName)
      needShowLocked = !events.isCountryAvailable(event, countryName)
    })

  
  let myCountry = getQueueCountry(queue)
  let myRank = getMyRankInQueue(queue)
  let countriesSets = events.getAllCountriesSets(event)
  local canMeetCountries = {}
  foreach (cSet in countriesSets)
    if (myCountry in cSet.allCountries)
      canMeetCountries = u.tablesCombine(canMeetCountries, cSet.allCountries, function(_a, _b) { return true })

  if (needRankInfo) {
    headerColumns.insert(0, { text = "#sm_era" })
    for (local rank = 1; rank <= MAX_COUNTRY_RANK; ++rank) {
      let row = {
        rowParam = "queueTableRow"
        columns = [{ text = get_roman_numeral(rank) }]
        isEven = rank % 2 == 0
      }

      foreach (_i, country in shopCountriesList)
        row.columns.append({
          id = $"{country}_{rank}"
          text = events.isCountryAvailable(event, country) ? "0" : "-"
          overlayTextColor = (country == myCountry && rank == myRank) ? "mainPlayer"
                           : country in canMeetCountries ? null
                           : "minor"
        })

      view.rows.append(row)
    }
  }

  let markup = handyman.renderCached("%gui/queue/queueTableByCountries.tpl", view)
  nestObj.getScene().replaceContentFromText(nestObj, markup, markup.len(), {})
}

function updateQueueViewByCountries(nestObj, queue, curCluster) {
  let queueStats = queue && queue.queueStats
  if (!queueStats)
    return

  let event = getQueueEvent(queue)
  if (events.needRankInfoInQueue(event)) {
    let countriesQueueTable = queueStats.getCountriesQueueTable(curCluster)
    let countryOption = ::get_option(USEROPT_COUNTRY)
    foreach (countryName in countryOption.values) {
      if (!events.isCountryAvailable(event, countryName))
        continue

      let ranksQueueTable = countriesQueueTable?[countryName]
      for (local rank = 1; rank <= MAX_COUNTRY_RANK; ++rank) {
        let tdTextObj = nestObj.findObject($"{countryName}_{rank}")
        if (!checkObj(tdTextObj))
          continue
        let val = ranksQueueTable?[rank.tostring()] ?? 0
        tdTextObj.setValue(val.tostring())
      }
    }
  }
  else {
    let totalTextObj = nestObj.findObject("total_in_queue")
    if (checkObj(totalTextObj))
      totalTextObj.setValue("".concat(loc("multiplayer/playersInQueue"), loc("ui/colon"),
        queueStats.getPlayersCountOfAllRanks()))
  }
}


function updateShortQueueInfo(timerObj, textObj, iconObj, txt = null) {
  if (!checkObj(timerObj))
    return
  SecondsUpdater(timerObj,  function(_obj, _p) {
    let queue = findQueue({}) 
    if (checkObj(textObj))
      textObj.setValue(getQueueInfo(queue, txt))
    if (checkObj(iconObj))
      iconObj.show(!!queue)
    return !queue
  })
}

return {
  createQueueViewByCountries
  updateQueueViewByCountries
  updateShortQueueInfo
}
