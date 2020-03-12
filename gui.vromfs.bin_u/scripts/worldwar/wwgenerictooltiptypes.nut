local wwLeaderboardData = require("scripts/worldWar/operations/model/wwLeaderboardData.nut")
local wwTooltipTypes = {
  WW_MAP_TOOLTIP_TYPE_ARMY = { //by crewId, unitName, specTypeCode
    getTooltipContent = function(id, params)
    {
      if (!::is_worldwar_enabled())
        return ""

      local army = ::g_world_war.getArmyByName(params.currentId)
      if (army)
        return ::handyman.renderCached("gui/worldWar/worldWarMapArmyInfo", army.getView())
      return ""
    }
  }

  WW_MAP_TOOLTIP_TYPE_BATTLE = {
    getTooltipContent = function(id, params)
    {
      if (!::is_worldwar_enabled())
        return ""

      local battle = ::g_world_war.getBattleById(params.currentId)
      if (!battle.isValid())
        return ""

      local battleSides = ::g_world_war.getSidesOrder()
      local view = battle.getView()
      view.defineTeamBlock(::ww_get_player_side(), battleSides)
      view.showBattleStatus = true
      view.hideDesc = true
      return ::handyman.renderCached("gui/worldWar/battleDescription", view)
    }
  }

  WW_LOG_BATTLE_TOOLTIP = {
    getTooltipContent = function(id, params)
    {
      local battle = ::g_world_war.getBattleById(params.currentId)
      local battleView = battle.isValid() ? battle.getView() : ::WwBattleView()
      return ::handyman.renderCached("gui/worldWar/wwControlHelp", battleView)
    }
  }

  WW_MAP_TOOLTIP_TYPE_GROUP = {
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, id, params)
    {
      if (!::is_worldwar_enabled())
        return false

      local group = ::u.search(::g_world_war.getArmyGroups(), (@(id) function(group) { return group.clanId == id})(id))
      if (!group)
        return false

      local clanId = group.clanId
      local clanTag = group.name
      local afterUpdate = function(updatedClanInfo){
        if (!::check_obj(obj))
          return
        local content = ::handyman.renderCached("gui/worldWar/worldWarClanTooltip", updatedClanInfo)
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

      local taskId = ::clan_request_info(clanId, "", "")
      local onTaskSuccess = function() {
        if (!::check_obj(obj))
          return

        local clanInfo = ::get_clan_info_table()
        if (!clanInfo)
          return

        wwLeaderboardData.updateClanByWWLBAndDo(clanInfo, afterUpdate)
      }

      local onTaskError = function(errorCode) {
        if (!::check_obj(obj))
          return

        local content = ::handyman.renderCached("gui/commonParts/errorFrame", {errorNum = errorCode})
        obj.getScene().replaceContentFromText(obj, content, content.len(), handler)
      }
      ::g_tasker.addTask(taskId, {showProgressBox = false}, onTaskSuccess, onTaskError)

      local content = ::handyman.renderCached("gui/worldWar/worldWarClanTooltip",
        { isLoading = true })
      obj.getScene().replaceContentFromText(obj, content, content.len(), handler)
      return true
    }
  }
}

::g_tooltip_type.addTooltipType(wwTooltipTypes)
