from "%scripts/dagui_natives.nut" import clan_get_my_clan_tag, clan_request_info, clan_get_my_clan_id
from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let wwLeaderboardData = require("%scripts/worldWar/operations/model/wwLeaderboardData.nut")
let { addTooltipTypes } = require("%scripts/utils/genericTooltipTypes.nut")
let { addTask } = require("%scripts/tasker.nut")
let { WwBattleView } = require("%scripts/worldWar/inOperation/model/wwBattle.nut")

let wwTooltipTypes = {
  WW_MAP_TOOLTIP_TYPE_ARMY = { //by crewId, unitName, specTypeCode
    getTooltipContent = function(_id, params) {
      if (!::is_worldwar_enabled())
        return ""

      let army = ::g_world_war.getArmyByName(params.currentId)
      if (army)
        return handyman.renderCached("%gui/worldWar/worldWarMapArmyInfo.tpl", army.getView())
      return ""
    }
  }

  WW_MAP_TOOLTIP_TYPE_BATTLE = {
    getTooltipContent = function(_id, params) {
      if (!::is_worldwar_enabled())
        return ""

      let battle = ::g_world_war.getBattleById(params.currentId)
      if (!battle.isValid())
        return ""

      let view = battle.getView()
      view.defineTeamBlock(::g_world_war.getSidesOrder())
      view.showBattleStatus = true
      view.hideDesc = true
      return handyman.renderCached("%gui/worldWar/battleDescription.tpl", view)
    }
  }

  WW_LOG_BATTLE_TOOLTIP = {
    getTooltipContent = function(_id, params) {
      let battle = ::g_world_war.getBattleById(params.currentId)
      let battleView = battle.isValid() ? battle.getView() : WwBattleView()
      return handyman.renderCached("%gui/worldWar/wwControlHelp.tpl", battleView)
    }
  }

  WW_MAP_TOOLTIP_TYPE_GROUP = {
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, id, _params) {
      if (!::is_worldwar_enabled())
        return false

      let group = u.search(::g_world_war.getArmyGroups(),  function(group) { return group.clanId == id })
      if (!group)
        return false

      let clanId = group.clanId
      let clanTag = group.name
      let afterUpdate = function(updatedClanInfo) {
        if (!checkObj(obj))
          return
        let content = handyman.renderCached("%gui/worldWar/worldWarClanTooltip.tpl", updatedClanInfo)
        obj.getScene().replaceContentFromText(obj, content, content.len(), handler)
      }

      if (::is_in_clan() &&
          (clan_get_my_clan_id() == clanId
          || clan_get_my_clan_tag() == clanTag)
         ) {
        ::requestMyClanData()
        if (!::my_clan_info)
          return false

        wwLeaderboardData.updateClanByWWLBAndDo(::my_clan_info, afterUpdate)
        return true
      }

      let taskId = clan_request_info(clanId, "", "")
      let onTaskSuccess = function() {
        if (!checkObj(obj))
          return

        let clanInfo = ::get_clan_info_table()
        if (!clanInfo)
          return

        wwLeaderboardData.updateClanByWWLBAndDo(clanInfo, afterUpdate)
      }

      let onTaskError = function(errorCode) {
        if (!checkObj(obj))
          return

        let content = handyman.renderCached("%gui/commonParts/errorFrame.tpl", { errorNum = errorCode })
        obj.getScene().replaceContentFromText(obj, content, content.len(), handler)
      }
      addTask(taskId, { showProgressBox = false }, onTaskSuccess, onTaskError)

      let content = handyman.renderCached("%gui/worldWar/worldWarClanTooltip.tpl",
        { isLoading = true })
      obj.getScene().replaceContentFromText(obj, content, content.len(), handler)
      return true
    }
  }
}

return addTooltipTypes(wwTooltipTypes)
