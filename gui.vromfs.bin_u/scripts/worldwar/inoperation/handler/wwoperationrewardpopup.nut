//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { rnd } = require("dagor.random")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getMapByName } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { getClansInfoByClanIds } = require("%scripts/clans/clansListShortInfo.nut")
let { register_command } = require("console")
let { round_by_value } = require("%sqstd/math.nut")
let { deep_clone } = require("%sqstd/underscore.nut")
let { disableSeenUserlogs } = require("%scripts/userLog/userlogUtils.nut")

let STATS_FIELDS = [
  ::g_lb_category.PLAYER_KILLS
  ::g_lb_category.AI_KILLS
  ::g_lb_category.FLYOUTS
  ::g_lb_category.DEATHS
  ::g_lb_category.MISSION_SCORE
  ::g_lb_category.WP_EARNED
]

let MANAGER_STATS_FIELDS = [
  ::g_lb_category.TOTAL_SCORE
  ::g_lb_category.ACTIVITY
]

local WwOperationRewardPopup = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType      = handlerType.MODAL
  sceneTplName = "%gui/worldWar/wwOperationRewardPopup.tpl"
  logObj       = null
  logId        = null
  myClanId     = null
  opClanId     = null
  isMeWinner   = null

  function getSceneTplView() {
    if (this.logObj == null)
      return {}

    let uLog = deep_clone(this.logObj)
    let operationId = uLog.operationId ?? -1
    let mySide = ::ww_side_name_to_val(uLog.side)
    this.isMeWinner = uLog?.winner ?? false
    this.myClanId = uLog?[$"side{mySide}Clan0"].tostring()
    this.opClanId = uLog?[$"side{::g_world_war.getOppositeSide(mySide)}Clan0"].tostring()
    let clansInfo = getClansInfoByClanIds([this.myClanId, this.opClanId])
    let myClanTag = clansInfo?[this.myClanId].tag ?? ""
    let opClanTag = clansInfo?[this.opClanId].tag ?? ""
    let statsList = []
    foreach (category in STATS_FIELDS)
      statsList.append({
        statIcon = category.headerImage
        statVal = category.lbDataType.getShortTextByValue(uLog?.userStats[category.field] ?? 0)
        tooltip = category.headerTooltip
      })

    let hasManager = uLog?.managerStats == null ? false : true
    let rewardsList = [{
      icon = "#ui/gameuiskin#medal_bonus.png"
      name = $"{loc("worldWar/endOperation/reward")}{loc("ui/colon")}"
      earnedText = ::Cost((uLog?.wp ?? 0) - (uLog?.managerStats.wpManager ?? 0)).toStringWithParams({
        isWpAlwaysShown = true })
      last = !hasManager
    }]
    if (hasManager) {
      let { actionsCount = 0, totalActionsCount = 0 } = uLog?.managerStats

      let activity = totalActionsCount > 0
        ? round_by_value(actionsCount.tofloat() / totalActionsCount.tofloat(), 0.01)
        : 0

      uLog.managerStats.activity <- activity
      statsList.append({ isDividingLine = true })
      foreach (category in MANAGER_STATS_FIELDS)
        statsList.append({
          statIcon = category.headerImage
          statVal = category.lbDataType.getShortTextByValue(uLog?.managerStats[category.field] ?? 0)
          tooltip = category.headerTooltip
        })

      rewardsList.append({
        icon = "#ui/gameuiskin#card_medal.png"
        name = $"{loc("worldWar/endOperation/manager_reward")}{loc("ui/colon")}"
        earnedText = ::Cost(uLog?.managerStats.wpManager ?? 0).toStringWithParams({
          isWpAlwaysShown = true })
        last = true
      })
    }

    let textLocId =  loc($"worldWar/endOperation/{this.isMeWinner ? "win" : "lose"}")
    return {
      headerText = $"{textLocId} {loc("ui/number_sign")}{operationId}"
      backgroundImg = getMapByName(uLog?.mapName)?.data.backgroundImage
        ?? "#ui/images/worldwar_window_bg_image?P1"
      winClanTag = colorize("userlogColoredText", this.isMeWinner ? myClanTag : opClanTag)
      vs = colorize("userlogColoredText", loc("country/VS").tolower())
      loseClanTag = colorize("userlogColoredText", this.isMeWinner ? opClanTag : myClanTag)
      profileIco = ::get_profile_info().icon
      statsList
      rewardsList
      hasManager
    }
  }

  initScreen = @() disableSeenUserlogs([this.logId])

  function onEventUpdateClansInfoList(p) {
    let myClanTag = p.clansInfoList?[this.myClanId].tag ?? ""
    let opClanTag = p.clansInfoList?[this.opClanId].tag ?? ""
    this.scene.findObject("win_tag")?.setValue(
      colorize("userlogColoredText", this.isMeWinner ? myClanTag : opClanTag))
    this.scene.findObject("lose_tag")?.setValue(
      colorize("userlogColoredText", this.isMeWinner ? opClanTag : myClanTag))
  }
}

::gui_handlers.WwOperationRewardPopup <- WwOperationRewardPopup
let openWwOperationRewardPopup = @(p)
  ::handlersManager.loadHandler(WwOperationRewardPopup, { logObj = p.body, logId = p.id })

register_command(
  function() {
    local uLogObj = ::getUserLogsList({
      show = [ EULT_WW_END_OPERATION ]
      checkFunc = @(userlog) userlog.body.wp != 0
    })?[0]

    //uses dummy data when no actual one in user log
    if (!uLogObj) {
      let operationId = ::g_world_war.lastPlayedOperationId
      uLogObj = operationId ? {
          operationId = operationId
          mapName = ::g_ww_global_status_type.MAPS.getList()?.keys()[0] ?? ""
          winner = true
          wp = rnd() % 10000
          side = "SIDE_1"
          side1Clan0 = ::clan_get_my_clan_id().tointeger()
          side2Clan0 = ::clan_get_my_clan_id().tointeger()

          userStats = {
            wpEarned = rnd() % 100000
            flyouts = rnd() % 100
            score = rnd() % 1000
            playerKills = rnd() % 10
            deaths = rnd() % 10
            aiKills = rnd() % 100
          }

          managerStats = {
            actionsCount = 1
            totalActionsCount = 5
            wpManager = 4000
            totalScore = 5000
          }
      } : null
    }
    openWwOperationRewardPopup(uLogObj)
    console_print("Done")
  }
  , "debug.ww_operation_rewards_popup")

return {
  openWwOperationRewardPopup
}
