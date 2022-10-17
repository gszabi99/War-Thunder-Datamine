from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let wwLeaderboardData = require("%scripts/worldWar/operations/model/wwLeaderboardData.nut")
let { addTooltipTypes } = require("%scripts/utils/genericTooltipTypes.nut")

let wwTooltipTypes = {
  WW_MAP_TOOLTIP_TYPE_ARMY = { //by crewId, unitName, specTypeCode
    getTooltipContent = function(id, params)
    {
      if (!::is_worldwar_enabled())
        return ""

      let army = ::g_world_war.getArmyByName(params.currentId)
      if (army)
        return ::handyman.renderCached("%gui/worldWar/worldWarMapArmyInfo", army.getView())
      return ""
    }
  }

  WW_MAP_TOOLTIP_TYPE_BATTLE = {
    getTooltipContent = function(id, params)
    {
      if (!::is_worldwar_enabled())
        return ""

      let battle = ::g_world_war.getBattleById(params.currentId)
      if (!battle.isValid())
        return ""

      let view = battle.getView()
      view.defineTeamBlock(::g_world_war.getSidesOrder())
      view.showBattleStatus = true
      view.hideDesc = true
      return ::handyman.renderCached("%gui/worldWar/battleDescription", view)
    }
  }

  WW_LOG_BATTLE_TOOLTIP = {
    getTooltipContent = function(id, params)
    {
      let battle = ::g_world_war.getBattleById(params.currentId)
      let battleView = battle.isValid() ? battle.getView() : ::WwBattleView()
      return ::handyman.renderCached("%gui/worldWar/wwControlHelp", battleView)
    }
  }

  WW_MAP_TOOLTIP_TYPE_GROUP = {
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, id, params)
    {
      if (!::is_worldwar_enabled())
        return false

      let group = ::u.search(::g_world_war.getArmyGroups(), (@(id) function(group) { return group.clanId == id})(id))
      if (!group)
        return false

      let clanId = group.clanId
      let clanTag = group.name
      let afterUpdate = function(updatedClanInfo){
        if (!checkObj(obj))
          return
        let content = ::handyman.renderCached("%gui/worldWar/worldWarClanTooltip", updatedClanInfo)
        obj.getScene().replaceContentFromText(obj, content, content.len(), handler)
      }

      if (::is_in_clan() &&
          (::clan_get_my_clan_id() == clanId
          || ::clan_get_my_clan_tag() == clanTag)
         )
      {
        ::requestMyClanData()
        if (!::my_clan_info)
          return false

        wwLeaderboardData.updateClanByWWLBAndDo(::my_clan_info, afterUpdate)
        return true
      }

      let taskId = ::clan_request_info(clanId, "", "")
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

        let content = ::handyman.renderCached("%gui/commonParts/errorFrame", {errorNum = errorCode})
        obj.getScene().replaceContentFromText(obj, content, content.len(), handler)
      }
      ::g_tasker.addTask(taskId, {showProgressBox = false}, onTaskSuccess, onTaskError)

      let content = ::handyman.renderCached("%gui/worldWar/worldWarClanTooltip",
        { isLoading = true })
      obj.getScene().replaceContentFromText(obj, content, content.len(), handler)
      return true
    }
  }
}

return addTooltipTypes(wwTooltipTypes)
