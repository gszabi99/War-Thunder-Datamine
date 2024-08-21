from "%scripts/dagui_library.nut" import *
let { floor } = require("math")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { secondsToString } = require("%scripts/time.nut")
let { toPixels } = require("%sqDagui/daguiUtil.nut")
let { getRewardSources } = require("%scripts/debriefing/rewardSources.nut")
let { getUnlockNameText } = require("%scripts/unlocks/unlocksViewModule.nut")
let { doesLocTextExist } = require("dagor.localize")
let { getClearUnitName } = require("%scripts/userLog/unitNameSymbolRestrictions.nut")
let { addTooltipTypes } = require("%scripts/utils/genericTooltipTypes.nut")
let { getBattleRewardDetails, getBattleRewardTable } = require("%scripts/userLog/userlogUtils.nut")
let { Cost } = require("%scripts/money.nut")
let { getRomanNumeralRankByUnitName } = require("%scripts/unit/unitInfo.nut")
let { getBulletBeltShortLocId } = require("%scripts/weaponry/weaponryVisual.nut")

enum UnitControl {
  UNIT_CONTROL_BOT = 1
  UNIT_CONTROL_AI = 2
}

let unitControlToLocIdMap = {
  [UnitControl.UNIT_CONTROL_BOT] = "multiplayer/state/bot_ready",
  [UnitControl.UNIT_CONTROL_AI] = "targetIsPlayer/includeAI"
}

let validateEmptyCellValueInt = @(v) v == "" ? 0 : v

let cellNoValSymbol = loc("ui/mdash")

let tableColumns = [
  {
    id = "timeFromMissionStart"
    titleLocId = "icon/timer"
    cellTransformFn = @(cellValue, _reward) { text = secondsToString(validateEmptyCellValueInt(cellValue), false, false) }
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
    cellTransformFn = @(cellValue, _) { text = $"{validateEmptyCellValueInt(cellValue)}%"}
  }
  {
    id = "lifetime"
    titleLocId = "icon/hourglass"
    cellTransformFn = @(cellValue, _) { text = secondsToString(validateEmptyCellValueInt(cellValue), false, false)}
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
    id = "weaponName"
    titleLocId = "logs/ammunition"
    cellTransformFn = function(cellValue, reward) {
      if (doesLocTextExist(cellValue))
        return {text = loc(cellValue)}

      let weaponShortName = $"weapons/{cellValue}/short"
      if (doesLocTextExist(weaponShortName))
        return {text = loc(weaponShortName)}

      let bulletBeltLocId = getBulletBeltShortLocId(cellValue)
      if (doesLocTextExist(bulletBeltLocId))
        return {text = reward?.weaponCaliber == null
          ? loc(bulletBeltLocId)
          : "".concat(loc(bulletBeltLocId),
            loc("ui/parentheses/space", {
              text = "".concat(reward.weaponCaliber * 1000, loc("measureUnits/mm"))
            }))
        }

      if (reward?.bulletType != null) {
        let locId = $"{reward.bulletType}/name/short"
        if (doesLocTextExist(locId))
          return {text = loc(locId)}
      }

      return cellValue
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
    cellTransformFn = @(cellValue, _reward) { text = secondsToString(validateEmptyCellValueInt(cellValue), false, false) }
  }
  {
    id = "scoreToReward"
    titleLocId = "icon/mpstats/score"
    cellTransformFn = @(cellValue, _reward) { text = cellValue.tostring() }
  }
  {
    id = "capturePartPercent"
    titleLocId = "icon/mpstats/captureZone"
    cellTransformFn = @(cellValue, _) { text = $"{validateEmptyCellValueInt(cellValue)}%"}
  }
  {
    id = "explTNT"
    titleLocId = "userlog/award_tip_col/damage_tnt"
    cellTransformFn = @(cellValue, reward) { text = reward.isPlainText
      ? "".concat(cellValue.tostring(), " ", loc("measureUnits/kg"))
      : cellValue.tostring()
    }
  }
  {
    id = "zoneDamage"
    titleLocId = "userlog/award_tip_col/damage_zone"
    cellTransformFn = @(cellValue, reward) { text = reward.isPlainText
      ? "".concat(cellValue.tostring(), " ", loc("logs/damage"))
      : cellValue.tostring()
    }
  }
  {
    id = "score"
    titleLocId = "icon/mpstats/score"
    cellTransformFn = @(cellValue, reward) { text = reward.isPlainText
      ? loc("logs/mission_points", {num = cellValue})
      : cellValue.tostring()
    }
  }
  {
    id = "streak"
    titleLocId = "reward"
    cellTransformFn = @(cellValue, _) { text = getUnlockNameText(UNLOCKABLE_STREAK, cellValue) }
  }
  {
    id = "bonusLevel"
    titleLocId = "expSkillBonusLevel"
    cellTransformFn = @(cellValue, _reward) {
      text = get_roman_numeral(validateEmptyCellValueInt(cellValue))
      isAlignCenter = true
    }
  }
  {
    id = "exp"
    titleLocId = "experience/short"
    cellTransformFn = @(cellValue, reward) {
      text = reward.isPlainText
        ? $"{cellValue.tostring()} {loc("money/rpText")}"
        : $"{cellValue.tostring()}{colorize("@currencyRpColor", loc("experience/short"))}"
      cellType = "tdRight"
      parseTags = true
    }
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
    id = "finishingType"
    titleLocId = "userlog/finishing_type"
    cellTransformFn = @(cellValue, _reward) { text = loc($"userlog/finishing_type/{cellValue}") }
  }
  {
    id = "noBonusExpTotal"
    titleLocId = "debriefing/basicRp"
    cellTransformFn = @(cellValue, reward) {
      text = reward.isPlainText
        ? $"{cellValue.tostring()} {loc("money/rpText")}"
        : $"{cellValue.tostring()}{colorize("@currencyRpColor", loc("experience/short"))}"
      cellType = "tdRight"
      parseTags = true
    }
  }
  {
    id = "invUnitName"
    titleLocId = "debriefing/researched_unit"
    cellTransformFn = @(cellValue, reward) {
      text = (!cellValue || cellValue == "") ? cellNoValSymbol
        : reward.isPlainText ? getClearUnitName(cellValue)
        : loc($"{cellValue}_shop")
    }
  }
  {
    id = "invUnitRank"
    titleLocId = "multiplayer/unitRank"
    cellTransformFn = @(cellValue, _reward) {
      text = cellValue
      isAlignCenter = true
    }
  }
  {
    id = "newNationBonusExp"
    titleLocId = "experience/short"
    cellTransformFn = function(cellValue, reward) {
      return {
        cellType = "tdRight"
        parseTags = true
        text = "".concat(
          reward.noBonusExpTotal, loc("ui/multiply"), reward.newNationBonusPercent, loc("measureUnits/percent"),
          "=",
          reward.isPlainText ? $"{cellValue} {loc("money/rpText")}" : Cost().setRp(cellValue)
        )
      }
    }
  }
  {
    id = "earnedWp"
    titleLocId = "warpoints/short"
    cellTransformFn = @(_, reward) {
      sources = getRewardSources({
        noBonus = reward?.wpNoBonus ?? 0
        premAcc = reward?.wpPremAcc ?? 0
        booster = reward?.wpBooster ?? 0
        currencySign = reward.isPlainText ? loc("money/wpText") : colorize("@currencyWpColor", loc("warpoints/short"))
      }, { isPlainText = reward.isPlainText, regularFont = true })
      hasFormula = true
    }
  }
  {
    id = "earnedExp"
    titleLocId =  "experience/short"
    cellTransformFn = @(_, reward) {
      sources = getRewardSources({
        noBonus = reward?.expNoBonus ?? 0
        premAcc = reward?.expPremAcc ?? 0
        booster = reward?.expBooster ?? 0
        premMod = reward?.expPremMod ?? 0
        currencySign = reward.isPlainText ? loc("money/rpText") : colorize("@currencyRpColor", loc("experience/short"))
      }, { isPlainText = reward.isPlainText, regularFont = true })
      hasFormula = true
    }
  }
]
function getVisibleTableColumns(rows) {
  return tableColumns.filter(function(row) {
    if (row.id == "earnedWp")
      return rows.findindex(@(r) !!r?.wpNoBonus) != null
    if (row.id == "earnedExp")
      return rows.findindex(@(r) !!r?.expNoBonus) != null

    return rows.findindex(@(r) r?[row.id] != null) != null
  })
}

function getUserLogBattleRewardTooltip(rewardDetails, eventName, isPlainText = false) {
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

      if (eventName == "researchPoints") {
        if (!reward?.newNationBonusExp)
          return null
        row.__update({
          exp = null  // for hiding exp column in the tooltip
          invUnitRank = getRomanNumeralRankByUnitName(reward?.invUnitName) ?? cellNoValSymbol
        })
      }
      return row
    })
    .filter(@(row) row)
  let visibleColumns = getVisibleTableColumns(tableRows)
  visibleColumns[0].isFirstCol <- true

  return {
    columns = visibleColumns
    rows = tableRows.map(@(reward, i) {
      isEven = i % 2 == 0
      cells = visibleColumns.map(function(col, colIdx) {
        let cell = reward?[col.id] ?? ""
        return {
          cell = col?.cellTransformFn(cell, reward) ?? { text = cell }
          isFirstCol = colIdx == 0
        }
      })
    })
  }
}

addTooltipTypes({
  USER_LOG_REWARD = {
    isCustomTooltipFill = true
    getTooltipId = function(logIdx, rewardId) {
      return this._buildId($"{logIdx}_{rewardId}", {logIdx, rewardId})
    }
    fillTooltip = function(obj, handler, _id, params) {
      if (!obj?.isValid())
        return false

      let { logIdx, rewardId } = params
      let foundReward = getBattleRewardTable(handler.logs.findvalue(@(l) l.idx == logIdx.tointeger())?.container[rewardId])
      if (foundReward == null)
        return false
      let view = getUserLogBattleRewardTooltip(getBattleRewardDetails(foundReward), rewardId)
      local blk = handyman.renderCached("%gui/userLog/userLogBattleRewardTooltip.tpl", view)
      obj.getScene().replaceContentFromText(obj, blk, blk.len(), handler)
      let objHeight = obj.getSize()[1]
      let rh = toPixels(obj.getScene(), "1@rh")
      if(objHeight > rh) {
        let k = 1.0 * objHeight / rh
        view.rows.resize(floor(view.rows.len() / k) - 3)
        view.isLongTooltip <- true
        view.allowToCopy <- is_platform_pc
        blk = handyman.renderCached("%gui/userLog/userLogBattleRewardTooltip.tpl", view)
        obj.getScene().replaceContentFromText(obj, blk, blk.len(), handler)
      }
      return true
    }
  }
})

return getUserLogBattleRewardTooltip
