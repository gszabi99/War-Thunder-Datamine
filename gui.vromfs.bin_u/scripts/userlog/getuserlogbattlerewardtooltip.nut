from "%scripts/dagui_library.nut" import *
let { secondsToString } = require("%scripts/time.nut")
let { sourcesConfig } = require("%scripts/debriefing/rewardSources.nut")
let { getUnlockNameText } = require("%scripts/unlocks/unlocksViewModule.nut")
let { doesLocTextExist } = require("dagor.localize")
let { getClearUnitName } = require("%scripts/userLog/unitNameSymbolRestrictions.nut")

enum UnitControl {
  UNIT_CONTROL_BOT = 1
  UNIT_CONTROL_AI = 2
}

let unitControlToLocIdMap = {
  [UnitControl.UNIT_CONTROL_BOT] = "multiplayer/state/bot_ready",
  [UnitControl.UNIT_CONTROL_AI] = "targetIsPlayer/includeAI"
}

let function getRewardFormulaConfig(values, isPlainText = false) {
  let { noBonus, premAcc, booster, premMod = 0, currencySign } = values
  let delimiter = isPlainText ? " " : ""
  if (!noBonus)
    return []

  if (premAcc + booster + premMod == 0)
    return [
      {
        text = $"{noBonus}{delimiter}{currencySign}"
        regularFont = true
        textColor = "@activeTextColor"
      }
    ]

  return [
    {
      text = noBonus
      regularFont = true
    }
    {
      text = premAcc
      prefix = "money/premiumText"
      regularFont = true
    }.__update(sourcesConfig.premAcc)
    {
      text = booster
      prefix = "item/rateBooster"
      regularFont = true
    }.__update(sourcesConfig.booster)
    {
      text = premMod
      prefix = "multiAward/type/premExpMul"
      regularFont = true
    }.__update(sourcesConfig.premMod)
    {
      text = $"{delimiter}={delimiter}{noBonus + premAcc + booster + premMod}{delimiter}{currencySign}"
      regularFont = true
      textColor = "@activeTextColor"
    }
  ].filter(@(c) !!c.text)
}

let tableColumns = [
  {
    id = "timeFromMissionStart"
    titleLocId = "icon/timer"
    cellTransformFn = @(cellValue, _reward) { text = secondsToString(cellValue, false, false) }
  }
  {
    id = "unit"
    titleLocId = "options/unit"
    cellTransformFn = @(cellValue, reward) { text = reward.isPlainText ? getClearUnitName(cellValue)
      : loc($"{cellValue}_shop") }
  }
  {
    id = "activity"
    titleLocId = "currency/squadronActivity"
    cellTransformFn = @(cellValue, _) { text = $"{cellValue}%"}
  }
  {
    id = "lifetime"
    titleLocId = "icon/hourglass"
    cellTransformFn = @(cellValue, _) { text = secondsToString(cellValue, false, false)}
  }
  {
    id = "offenderUnit"
    titleLocId = "options/unit"
    cellTransformFn = function(_, reward) {
      let unitName = loc($"{reward?.offenderUnit}_shop")
      let offenderUnitLoc = reward.isPlainText ? getClearUnitName(reward?.offenderUnit) : unitName
      if (reward?.offenderOwnedUnit) {
        let offenderOwnedUnitName = loc($"{reward?.offenderOwnedUnit}_shop")
        let offenderOwnedUnitLoc = reward.isPlainText ? getClearUnitName(reward?.offenderOwnedUnit) : offenderOwnedUnitName
        return { text = $"{offenderUnitLoc} ({offenderOwnedUnitLoc})" }
      }
      return { text = offenderUnitLoc }
    }
  }
  {
    id = "victimUnit"
    titleLocId = "hud/iconOrderTarget"
    cellTransformFn = function(cellValue, reward) {
      let unitLocId = doesLocTextExist($"{cellValue}_shop") ? $"{cellValue}_shop"
        : doesLocTextExist($"{cellValue}_0") ? $"{cellValue}_0"
        : reward?.victimUnitFileName ? $"{reward.victimUnitFileName}_0"
        : cellValue

      if (!doesLocTextExist(unitLocId))
        log($"[UserlogReward]No localization for unit name {cellValue}")

      let foundUnitControl = unitControlToLocIdMap?[reward?.victimUnitControl]
      let postfix = foundUnitControl ? $"({loc(foundUnitControl)})" : ""
      let unitName = loc(unitLocId)
      return { text = " ".concat(reward.isPlainText ? getClearUnitName(unitLocId, true) : unitName, postfix) }
    }
  }
  {
    id = "timeToReward"
    titleLocId = "icon/hourglass"
    cellTransformFn = @(cellValue, _reward) { text = secondsToString(cellValue, false, false) }
  }
  {
    id = "scoreToReward"
    titleLocId = "icon/mpstats/score"
    cellTransformFn = @(cellValue, _reward) { text = cellValue.tostring() }
  }
  {
    id = "capturePartPercent"
    titleLocId = "icon/mpstats/captureZone"
    cellTransformFn = @(cellValue, _) { text = $"{cellValue}%"}
  }
  {
    id = "explTNT"
    titleLocId = "userlog/award_tip_col/damage_tnt"
    cellTransformFn = @(cellValue, _reward) { text = cellValue.tostring() }
  }
  {
    id = "zoneDamage"
    titleLocId = "userlog/award_tip_col/damage_zone"
    cellTransformFn = @(cellValue, _reward) { text = cellValue.tostring() }
  }
  {
    id = "streak"
    titleLocId = "reward"
    cellTransformFn = @(cellValue, _) { text = getUnlockNameText(UNLOCKABLE_STREAK, cellValue) }
  }
  {
    id = "unknown"
    titleLocId = "hud/iconBinocular"
    cellTransformFn = @(cellValue, reward) reward.isPlainText ? { text = cellValue ? "\u00d7" : "\u2713" }
      : {
          image = cellValue ? { src = "#ui/gameuiskin#btn_close.svg" size = "1@cIco, 1@cIco" }
            : { src = "#ui/gameuiskin#check.svg" }
        }
  }
  {
    id = "earnedWp"
    titleLocId = "warpoints/short"
    cellTransformFn = @(_, reward) {
      sources = getRewardFormulaConfig({
        noBonus = reward?.wpNoBonus ?? 0
        premAcc = reward?.wpPremAcc ?? 0
        booster = reward?.wpBooster ?? 0
        currencySign = reward.isPlainText ? loc("money/wpText") : colorize("@currencyWpColor", loc("warpoints/short"))
      }, reward.isPlainText)
      hasFormula = true
    }
  }
  {
    id = "earnedExp"
    titleLocId =  "experience/short"
    cellTransformFn = @(_, reward) {
      sources = getRewardFormulaConfig({
        noBonus = reward?.expNoBonus ?? 0
        premAcc = reward?.expPremAcc ?? 0
        booster = reward?.expBooster ?? 0
        premMod = reward?.expPremMod ?? 0
        currencySign = reward.isPlainText ? loc("money/rpText") : colorize("@currencyRpColor", loc("experience/short"))
      }, reward.isPlainText)
      hasFormula = true
    }
  }
]
let function getVisibleTableColumns(rows) {
  return tableColumns.filter(function(row) {
    if (row.id == "earnedWp")
      return rows.findindex(@(row) !!row?.wpNoBonus) != null
    if (row.id == "earnedExp")
      return rows.findindex(@(row) !!row?.expNoBonus) != null

    return rows.findindex(@(r) r?[row.id] != null) != null
  })
}

return function (rewardDetails, eventName, isPlainText = false) {
  let tableRows = rewardDetails
    .map(function(reward) {
      let row = reward.__merge({
        earnedWp = null // values will be setted in cellTransformFn
        earnedExp = null
        isPlainText
      })
    if (eventName == "eventScoutKill")
      row.__update({ unknown = !isPlainText ? !!reward?.unknown
        : reward?.unknown ? loc("options/no")
        : loc("options/yes") })

    return row
  })
  let visibleColumns = getVisibleTableColumns(tableRows)

  return {
    columns = visibleColumns
    rows = tableRows.map(@(reward, i) {
      isEven = i % 2 == 0
      cells = visibleColumns.map(function(col) {
        let cell = reward?[col.id] ?? ""
        return {
          cell = col?.cellTransformFn(cell, reward) ?? { text = cell }
        }
      })
    })
  }
}