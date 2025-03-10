from "%scripts/dagui_natives.nut" import clan_get_role_rank, clan_get_role_rights, clan_get_my_clan_type, ps4_is_ugc_enabled
from "%scripts/dagui_library.nut" import *

let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { isNamePassing, checkName } = require("%scripts/dirtyWordsFilter.nut")
let time = require("%scripts/time.nut")
let { format } = require("string")
let { get_game_settings_blk } = require("blkGetters")
let { g_clan_type } = require("%scripts/clans/clanType.nut")
let regexp2 = require("regexp2")
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
      let modeName = diff.getEgdName(false) 
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

function checkClanTagForDirtyWords(clanTag, returnString = true) {
  if (isPlatformSony)
    return returnString ? checkName(clanTag) : isNamePassing(clanTag)
  return returnString ? clanTag : true
}

function getClanCreationDateText(clanData) {
  return time.buildDateStr(clanData.cdate)
}

function getClanInfoChangeDateText(clanData) {
  return time.buildDateTimeStr(clanData.changedTime, false, false)
}

function getClanMembersCountText(clanData) {
  if (clanData.mlimit)
    return format("%d/%d", clanData.members.len(), clanData.mlimit)

  return format("%d", clanData.members.len())
}

function getClanMemberRank(clanData, name) {
  foreach (member in (clanData?.members ?? []))
    if (member.nick == name)
      return clan_get_role_rank(member.role)

  return 0
}

function getLeadersCount(clanData) {
  local count = 0
  foreach (member in clanData.members) {
    let rights = clan_get_role_rights(member.role)
    if (isInArray("LEADER", rights) ||
        isInArray("DEPUTY", rights))
      count++
  }
  return count
}

function stripClanTagDecorators(clanTag) {
  let uftClanTag = utf8(clanTag)
  let length = uftClanTag.charCount()
  return length > 2 ? uftClanTag.slice(1, length - 1) : clanTag
}





let getRegionUpdateCooldownTime =@() get_game_settings_blk()?.clansChangeRegionPeriodSeconds ?? time.daysToSeconds(1)

function getMyClanType() {
  let code = clan_get_my_clan_type()
  return g_clan_type.getTypeByCode(code)
}

let ps4ContentDisabledRegExp = regexp2("[^ ]")

function ps4CheckAndReplaceContentDisabledText(processingString, forceReplace = false) {
  if (!ps4_is_ugc_enabled() || forceReplace)
    processingString = ps4ContentDisabledRegExp.replace("*", processingString)
  return processingString
}

return {
  getClanRequirementsText
  checkClanTagForDirtyWords
  getClanCreationDateText
  getClanInfoChangeDateText
  getClanMembersCountText
  getClanMemberRank
  getLeadersCount
  stripClanTagDecorators
  getRegionUpdateCooldownTime
  getMyClanType
  ps4CheckAndReplaceContentDisabledText
}