from "%scripts/dagui_library.nut" import *

let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { Cost } = require("%scripts/money.nut")
let { roundToDigits } = require("%sqstd/math.nut")
let { format } = require("string")
let { getModificationName } = require("%scripts/weaponry/bulletsInfo.nut")
let { getActiveBoostersDescription } = require("%scripts/items/boosterEffect.nut")
let { boosterEffectType } = require("%scripts/items/boosterEffectTypes.nut")
let getBattleRewards = require("%scripts/userLog/getUserLogBattleRewardsTable.nut")
let getUserLogBattleRewardTooltip = require("%scripts/userLog/getUserLogBattleRewardTooltip.nut")
let { getClearUnitName } = require("%scripts/userLog/unitNameSymbolRestrictions.nut")
let { intToHexString } = require("%sqStdLibs/helpers/toString.nut")
let { eventsTableConfig } = require("%scripts/leaderboard/leaderboardCategoryType.nut")
let { findItemById } = require("%scripts/items/itemsManager.nut")
let { measureType } = require("%scripts/measureType.nut")
let { isMissionExtrByName } = require("%scripts/missions/missionsUtils.nut")
let { getMissionName } = require("%scripts/missions/missionsText.nut")
let { getLbDiff, getLeaderboardItemView, getLeaderboardItemWidgets
} = require("%scripts/leaderboard/leaderboardHelpers.nut")
let { getLogNameByType, updateRepairCost } = require("%scripts/userLog/userlogUtils.nut")

let tab = "    "

function getBonus(exp, wp) {
  exp = roundToDigits(exp, 2)
  wp = roundToDigits(wp, 2)
  let texts = []
  if(exp > 1.0)
    texts.append(format(loc("bonus/expMulPlainText"),$"x{exp}"))
  if (wp > 1.0)
    texts.append(format(loc("bonus/wpMulPlainText"),$"x{wp}"))
  return "\n".join(texts)
}

function resolveFormula(sources) {
  let formula = sources.map(function(v) {
    local res = ""
    let prefix = v?.prefix
    let hasPlus = v?.hasPlus ?? false
    if(hasPlus)
      res = " + "
    if(prefix != null)
      res = "".concat(res, "(", loc(prefix), ")")
    res = "".concat(res, v.text)
    return res
  })
  return "".join(formula)
}

function prepareTableForFormating(data) {
  let table = []
  foreach(row in data.rows) {
    let tableRow = []
    foreach(cell in row.cells) {
      let hasFormula = cell?.cell.hasFormula ?? false
      tableRow.append(hasFormula ? resolveFormula(cell.cell.sources) : cell.cell.text)
    }
    table.append(tableRow)
  }
  return table
}

function formatCell(text, width) {
  let spacesCount = width - utf8(text).charCount()
  if(spacesCount == 0)
    return text
  let spaces = "".join([].resize(spacesCount, " "))
  return "".concat(text, spaces)
}

function formatBattleRewardDetails(reward) {
  let data = getUserLogBattleRewardTooltip(reward.battleRewardDetails, reward.id, true)
  let rawTable = prepareTableForFormating(data)
  let colWidths = []
  foreach(row in rawTable)
    foreach(idx, cell in row) {
      if(colWidths.len() <= idx)
        colWidths.append(utf8(cell).charCount())
      else
        colWidths[idx] = max(colWidths[idx], utf8(cell).charCount())
    }

  let table = []
  foreach(row in rawTable) {
    let tableRow = []
    foreach(idx, cell in row)
      tableRow.append(formatCell(cell, colWidths[idx]))
    table.append("".concat(tab, tab.join(tableRow)))
  }
  return "\n".join(table)
}

function formatText(text, frm) {
  let { width, align } = frm
  let spacesCount = width - utf8(text).charCount()
  if(spacesCount == 0)
    return text
  let spaces = "".join([].resize(spacesCount, " "))
  return align == "left" ? "".concat(text, spaces) : "".concat(spaces, text)
}

function formatRewards(battleRewards) {
  if (battleRewards.len() == 0)
    return ""

  let hasAdditionalInfo = battleRewards.findvalue(@(r) r?.battleRewardDetails != null) != null
  if (!hasAdditionalInfo) {
    let rewardsStrs = battleRewards.map(function(r) {
      let name = r.name
      let rewards = ", ".join([r?.wp, r?.exp].filter(@(count) count != ""))
      return $"{name}: {rewards}"
    })
    return "".concat("\n\n", "\n".join(rewardsStrs))
  }

  let colWidths = [
    { key = "name", width = 0, align = "left" }
    { key = "count", width = 0, align = "right" }
    { key = "wp", width = 0, align = "right" }
    { key = "exp", width = 0, align = "right" }
  ]

  foreach(col in colWidths)
    foreach(reward in battleRewards)
      col.width = max(col.width, utf8(reward[col.key]).charCount())

  local res = ""
  foreach(reward in battleRewards) {
    local row = ""
    foreach(col in colWidths)
      row = "".concat(row, formatText(reward[col.key], col), tab)
    res = "\n\n".concat(res, row)
    if(reward.battleRewardDetails != null)
      res = "\n".concat(res, formatBattleRewardDetails(reward))
  }
  return res
}

function get_userlog_plain_text(logObj) {
  let colon = loc("ui/colon")
  let res = {
    name = ""
    logBonus = ""
    battleRewards = ""
    description = ""
  }

  local logName = getLogNameByType(logObj.type)
  let isMissionExtrLog = isMissionExtrByName(logObj?.mission ?? "")

  let eventId = logObj?.eventId
  local mission = getMissionName(logObj.mission, logObj)
  if (eventId != null && !events.isEventRandomBattlesById(eventId)) {
    local locName = ""

    if ("eventLocName" in logObj)
      locName = logObj.eventLocName
    else
      locName = $"events/{eventId}/name"
    logName = $"event/{logName}"
    mission = loc(locName, eventId)
  }

  local nameLoc = isMissionExtrLog
    ? "userLog/session_result_extr"
    : "".concat("userlog/", logName, "_plain")
  if (!isMissionExtrLog && logObj.type == EULT_SESSION_RESULT)
    nameLoc ="".concat(nameLoc, logObj.win ? "/win" : "/lose")
  res.name = format(loc(nameLoc), mission)

  local desc = ""
  local wp = getTblValue("wpEarned", logObj, 0) + getTblValue("baseTournamentWp", logObj, 0)
  local gold = getTblValue("goldEarned", logObj, 0) + getTblValue("baseTournamentGold", logObj, 0)
  let xp = getTblValue("xpEarned", logObj, 0)
  local earnedText = Cost(wp, gold, xp).toPlainText({ isWpAlwaysShown = true })
  if (!isMissionExtrLog && earnedText != "")
    desc = "".concat(desc, "\n", loc("userlog/earned"), colon, earnedText)

  if (!isMissionExtrLog && (logObj.type == EULT_SESSION_RESULT) && ("activity" in logObj)) {
    let activity = measureType.PERCENT_FLOAT.getMeasureUnitsText(logObj.activity)
    desc = "".concat(desc, "\n", loc("debriefing/Activity"), colon, activity)
  }

  if (("friendlyFirePenalty" in logObj) && logObj.friendlyFirePenalty != 0) {
    desc = "".concat(desc, "\n", loc("debriefing/FriendlyKills"), colon,
      Cost(logObj.friendlyFirePenalty).toPlainText({ isWpAlwaysShown = true }))
    wp += logObj.friendlyFirePenalty
  }

  if (("nRespawnsWp" in logObj) && logObj.nRespawnsWp != 0) {
    desc = "".concat(desc, "\n", loc("debriefing/MultiRespawns"), colon,
      Cost(logObj.nRespawnsWp).toPlainText({ isWpAlwaysShown = true }))
    wp += logObj.nRespawnsWp
  }

  if ("aircrafts" in logObj) {
    let aText = []
    foreach (air in logObj.aircrafts)
      if (air.value < 1.0)
        aText.append(getClearUnitName(air.name))
    if (aText.len() > 0)
      desc = "".concat(desc, "\n", loc("userlog/broken_airs"), colon, ", ".join(aText))
  }

  if ("spare" in logObj) {
    let aText = []
    foreach (air in logObj.spare) {
      if (air.value <= 0)
        continue

      aText.append("".concat(getClearUnitName(air.name),
        air.value > 1 ? format(" (%d)", air.value.tointeger()) : ""))
    }
    if (aText.len() > 0)
      desc = "".concat(desc, "\n", loc("userlog/used_spare"), colon, ", ".join(aText))
  }

  let containerLog = getTblValue("container", logObj)

  local freeRepair = ("aircrafts" in logObj) && logObj.aircrafts.len() > 0
  let repairCost = { rCost = 0, notEnoughCost = 0 }
  let aircraftsRepaired = getTblValue("aircraftsRepaired", containerLog)
  if (aircraftsRepaired)
    updateRepairCost(aircraftsRepaired, repairCost);

  let unitsRepairedManually = getTblValue("manuallySpentRepairCost", logObj)
  if (unitsRepairedManually)
    updateRepairCost(unitsRepairedManually, repairCost);

  if (repairCost.rCost > 0) {
    desc = "".concat(desc, "\n", loc("shop/auto_repair_cost"), colon,
      Cost(-repairCost.rCost).toPlainText({ isWpAlwaysShown = true }))
    wp -= repairCost.rCost
    freeRepair = false
  }
  if (repairCost.notEnoughCost != 0) {
    desc = "".concat(desc, "\n", loc("shop/auto_repair_failed"), colon,
      Cost(repairCost.notEnoughCost).toPlainText({ isWpAlwaysShown = true }))
    freeRepair = false
  }

  if (freeRepair && ("autoRepairWasOn" in logObj) && logObj.autoRepairWasOn) {
    desc = "".concat(desc, "\n", loc("shop/auto_repair_free_plain"))
  }

  let wRefillWp = getTblValue("wpCostWeaponRefill", containerLog, 0)
  let wRefillGold = getTblValue("goldCostWeaponRefill", containerLog, 0)
  if (wRefillWp || wRefillGold) {
    desc = "".concat(desc, "\n", loc("shop/auto_buy_weapons_cost"), colon,
      Cost(-wRefillWp, -wRefillGold).toPlainText())
    wp -= wRefillWp
    gold -= wRefillGold
  }

  let expensesCompensation = containerLog?.wpExpensesCompensation ?? 0
  if (expensesCompensation > 0) {
    desc = "".concat(desc, "\n", loc("userlog/expenses_compensation"), colon,
      Cost(expensesCompensation).toPlainText())
    wp += expensesCompensation
  }

  local rp = 0
  if ("rpEarned" in logObj) {
    local descUnits = ""
    local descMods = ""

    local idx = 0
    while (($"aname{idx}") in logObj.rpEarned) {
      let unitId = logObj.rpEarned[$"aname{idx}"]
      let modId = (($"mname{idx}") in logObj.rpEarned) ? logObj.rpEarned[$"mname{idx}"] : null
      let mrp = logObj.rpEarned[$"mrp{idx}"]

      let fromExcessRP = ($"merp{idx}") in logObj.rpEarned ? logObj.rpEarned[$"merp{idx}"] : 0
      rp += mrp + fromExcessRP

      local modText = ""
      if (modId)
        modText = $" - {getModificationName(getAircraftByName(unitId), modId)}"
      let title = $"{getClearUnitName(unitId)}{modText}"
      local item = "".concat("\n", title, colon, Cost().setRp(mrp).toPlainText())

      if (fromExcessRP > 0)
        item = "".concat(item, " + ", loc("userlog/excessExpEarned"), colon,
          Cost().setRp(fromExcessRP).toPlainText())
      if (!modId)
        descUnits = $"{descUnits}{item}"
      else
        descMods = $"{descMods}{item}"
      idx++
    }

    if (descUnits.len())
      desc = "".concat(desc, "\n\n", loc("debriefing/researched_unit"), colon, descUnits)
    if (descMods.len())
      desc = "".concat(desc, "\n\n", loc("debriefing/research_list"), colon, descMods)
  }

  if (getTblValue("haveTeamkills", logObj, false))
    desc = "".concat(desc, "\n\n", loc("debriefing/noAwardsCaption"))

  let usedItems = []

  if ("affectedBoosters" in logObj) {
    local affectedBoosters = logObj.affectedBoosters
    local activeBoosters = getTblValue("activeBooster", affectedBoosters, [])
    if (type(activeBoosters) == "table")
      activeBoosters = [ activeBoosters ]

    if (activeBoosters.len() > 0)
      foreach (effectType in boosterEffectType) {
        let boostersArray = []
        foreach (_idx, block in activeBoosters) {
          let item = findItemById(block.itemId)
          if (item && effectType.checkBooster(item))
            boostersArray.append(item)
        }

        if (boostersArray.len())
          usedItems.append(getActiveBoostersDescription(boostersArray, effectType, null, true))
      }

    if (usedItems.len())
      desc = "".concat(desc, "\n\n", loc("debriefing/used_items"), colon, "\n", "\n".join(usedItems, true))
  }

  if (("tournamentResult" in logObj) && (events.getEvent(eventId)?.leaderboardEventTable == null)) {
    let now = getTblValue("newStat", logObj.tournamentResult)
    let was = getTblValue("oldStat", logObj.tournamentResult)
    let lbDiff = getLbDiff(now, was)
    let items = []
    foreach (lbFieldsConfig in eventsTableConfig) {
      if (!(lbFieldsConfig.field in now)
        || !events.checkLbRowVisibility(lbFieldsConfig, { eventId }))
        continue

      items.append(getLeaderboardItemView(lbFieldsConfig,
        now[lbFieldsConfig.field],
        getTblValue(lbFieldsConfig.field, lbDiff, null)))
    }
    let lbStatsBlk = getLeaderboardItemWidgets({ items = items })
    if (!("descriptionBlk" in res))
      res.descriptionBlk <- ""
    res.descriptionBlk = "".concat(res.descriptionBlk, format("tdiv { width:t='pw'; flow:t='h-flow'; %s }", lbStatsBlk))
  }

  let roomId = logObj?.roomId ?? 0
  if (roomId > 0)
    desc = "".concat(desc, "\n\n", loc("options/session"), colon, intToHexString(roomId))

  if (!isMissionExtrLog) {
    let total = Cost(wp, gold, xp, rp).toPlainText({ isWpAlwaysShown = true })
    desc = "".concat(desc, "\n", loc("debriefing/total"), colon, total)
  }

  let ecSpawnScore = getTblValue("ecSpawnScore", logObj, 0)
  if (ecSpawnScore > 0)
    desc = "".concat(desc, "\n", loc("debriefing/total/ecSpawnScore"), colon, ecSpawnScore)
  let wwSpawnScore = logObj?.wwSpawnScore ?? 0
  if (wwSpawnScore > 0)
    desc = "".concat(desc, "\n", loc("debriefing/total/wwSpawnScore"), colon, wwSpawnScore)

  res.description = desc

  let expMul = logObj?.xpFirstWinInDayMul ?? 1.0
  let wpMul = logObj?.wpFirstWinInDayMul ?? 1.0
  if (expMul > 1.0 || wpMul > 1.0)
    res.logBonus = getBonus(expMul, wpMul)

  let battleRewards = logObj.type == EULT_SESSION_RESULT ? getBattleRewards(logObj) : []
  let rewards = battleRewards.map(@(reward) { name = reward.name, count = reward?.count.tostring() ?? "",
    wp = reward.wp.toPlainText(), exp = Cost().setRp(reward.totalRewardExp).toPlainText(),
    battleRewardDetails = reward?.battleRewardDetails, id = reward?.id })
  res.battleRewards = formatRewards(rewards)

  local resultText = res.name
  if(res.battleRewards != "")
    resultText = "".concat(resultText, res.battleRewards)
  if(res.description != "")
    resultText = "\n".concat(resultText, res.description)
  if(res.logBonus != "")
    resultText = "\n".concat(resultText, res.logBonus)

  return resultText
}

return {
  get_userlog_plain_text
}