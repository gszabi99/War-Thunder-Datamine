from "%scripts/dagui_library.nut" import *

let unitTypes = require("%scripts/unit/unitTypesList.nut")
let DataBlock  = require("DataBlock")
let { g_difficulty } = require("%scripts/difficulty.nut")

function getClanRequirementsText(membershipRequirements) {
  if (!membershipRequirements)
    return ""

  let rawRanksCond = membershipRequirements.getBlockByName("ranks") || DataBlock();
  let ranksConditionTypeText = (rawRanksCond?.type == "or")
    ? loc("clan/rankReqInfoCondType_or")
    : loc("clan/rankReqInfoCondType_and")

  let ranksReqTextArray = []
  foreach (unitType in unitTypes.types) {
    let req = rawRanksCond.getBlockByName($"rank_{unitType.name}")
    if (req?.type != "rank" || req?.unitType != unitType.name)
      continue

    let ranksRequired = req.getInt("rank", 0)
    if (ranksRequired > 0)
      ranksReqTextArray.append("".concat(loc("clan/rankReqInfoRank", unitType.name), " ",
        colorize("activeTextColor", get_roman_numeral(ranksRequired))))
  }

  local ranksReqText = ""
  if (ranksReqTextArray.len()) {
    ranksReqText = $" {ranksConditionTypeText } ".join(ranksReqTextArray, true)
    ranksReqText = "".concat(loc("clan/rankReqInfoHead"), loc("ui/colon"), ranksReqText)
  }

  local battlesReqText = ""
  local haveBattlesReq = false
  foreach (diff in g_difficulty.types)
    if (diff.egdCode != EGD_NONE) {
      let modeName = diff.getEgdName(false) // arcade, historical, simulation
      let req = membershipRequirements.getBlockByName($"battles_{modeName}");
      if (req?.type == "battles" && req?.difficulty == modeName) {
        let battlesRequired = req.getInt("count", 0);
        if (battlesRequired > 0) {
          if (!haveBattlesReq)
            battlesReqText = loc("clan/battlesReqInfoHead");
          else
            battlesReqText = "".concat(battlesReqText, " ", ranksConditionTypeText)

          haveBattlesReq = true;
          battlesReqText = "".concat( battlesReqText, " ", loc($"clan/battlesReqInfoMode_{modeName}"), " ",
            colorize("activeTextColor", battlesRequired.tostring()))
        }
      }
    }

  return "\n".join([ranksReqText, battlesReqText], true)
}

return {
  getClanRequirementsText = getClanRequirementsText
}