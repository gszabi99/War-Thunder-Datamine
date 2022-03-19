local unitTypes = require("scripts/unit/unitTypesList.nut")

local function getClanRequirementsText(membershipRequirements)
{
  if (!membershipRequirements)
    return ""

  local rawRanksCond = membershipRequirements.getBlockByName("ranks") || ::DataBlock();
  local ranksConditionTypeText = (rawRanksCond?.type == "or")
    ? ::loc("clan/rankReqInfoCondType_or")
    : ::loc("clan/rankReqInfoCondType_and")

  local ranksReqTextArray = []
  foreach (unitType in unitTypes.types)
  {
    local req = rawRanksCond.getBlockByName("rank_" + unitType.name)
    if (req?.type != "rank" || req?.unitType != unitType.name)
      continue

    local ranksRequired = req.getInt("rank", 0)
    if (ranksRequired > 0)
      ranksReqTextArray.append(::loc("clan/rankReqInfoRank" + unitType.name) + " " +
        ::colorize("activeTextColor", ::get_roman_numeral(ranksRequired)))
  }

  local ranksReqText = ""
  if (ranksReqTextArray.len())
  {
    ranksReqText = ::g_string.implode(ranksReqTextArray, " " + ranksConditionTypeText + " ")
    ranksReqText = ::loc("clan/rankReqInfoHead") + ::loc("ui/colon") + ranksReqText
  }

  local battlesReqText = "";
  local haveBattlesReq = false;
  foreach(diff in ::g_difficulty.types)
    if (diff.egdCode != ::EGD_NONE)
    {
      local modeName = diff.getEgdName(false); // arcade, historical, simulation
      local req = membershipRequirements.getBlockByName("battles_"+modeName);
      if (req?.type == "battles" && req?.difficulty == modeName)
      {
        local battlesRequired = req.getInt("count", 0);
        if ( battlesRequired > 0 )
        {
          if ( !haveBattlesReq )
            battlesReqText = ::loc("clan/battlesReqInfoHead");
          else
            battlesReqText += " " + ranksConditionTypeText;

          haveBattlesReq = true;
          battlesReqText += ( " " + ::loc("clan/battlesReqInfoMode_"+modeName) + " " +
            ::colorize("activeTextColor", battlesRequired.tostring()) );
        }
      }
    }

  return ::g_string.implode([ranksReqText, battlesReqText], "\n")
}

return {
  getClanRequirementsText = getClanRequirementsText
}