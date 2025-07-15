from "%scripts/dagui_natives.nut" import clan_get_my_clan_tag, clan_request_info, clan_get_my_clan_id
from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *
from "%scripts/clans/clanState.nut" import is_in_clan, myClanInfo

let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let wwLeaderboardData = require("%scripts/worldWar/operations/model/wwLeaderboardData.nut")
let { addTooltipTypes } = require("%scripts/utils/genericTooltipTypes.nut")
let { addTask } = require("%scripts/tasker.nut")
let { WwBattleView } = require("%scripts/worldWar/inOperation/model/wwBattle.nut")
let { isWorldWarEnabled } = require("%scripts/worldWar/worldWarGlobalStates.nut")
let { get_clan_info_table } = require("%scripts/clans/clanInfoTable.nut")
let { getArmyByName } = require("%scripts/worldWar/inOperation/model/wwArmy.nut")
let { setWwTooltipTypes } = require("%scripts/worldWar/wwGenericTooltipTypes.nut")

let wwTooltipTypes = {
  WW_MAP_TOOLTIP_TYPE_ARMY = { 
    getTooltipContent = function(_id, params) {
      if (!isWorldWarEnabled())
        return ""

      let army = getArmyByName(params.currentId)
      if (army) {
        let view = army.getView()
        return handyman.renderCached("%gui/worldWar/worldWarMapArmyTooltip.tpl", { view, tooltipWidth = view.getTooltipWidth() })
      }
      return ""
    }
  }

  WW_MAP_TOOLTIP_TYPE_AIRFIELD = {
    getTooltipContent = function(_id, params) {
      if (!isWorldWarEnabled())
        return ""

      let airfield = ::g_world_war.getAirfieldByIndex(params.currentId)
      if (airfield) {
        let view = airfield.getView()
        return handyman.renderCached("%gui/worldWar/worldWarMapArmyTooltip.tpl", { view, tooltipWidth = view.getTooltipWidth() })
      }
      return ""
    }
  }

  WW_MAP_TOOLTIP_TYPE_BATTLE = {
    getTooltipContent = function(_id, params) {
      if (!isWorldWarEnabled())
        return ""

      let battle = ::g_world_war.getBattleById(params.currentId)
      if (!battle.isValid())
        return ""

      let view = battle.getView()
      view.defineTeamBlock(::g_world_war.getSidesOrder(), { canAlignRight = false })
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
      if (!isWorldWarEnabled())
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

      if (is_in_clan() &&
          (clan_get_my_clan_id() == clanId
          || clan_get_my_clan_tag() == clanTag)
         ) {
        ::requestMyClanData()
        let myClanInfoV = myClanInfo.get()
        if (!myClanInfoV)
          return false

        wwLeaderboardData.updateClanByWWLBAndDo(myClanInfoV, afterUpdate)
        return true
      }

      let taskId = clan_request_info(clanId, "", "")
      let onTaskSuccess = function() {
        if (!checkObj(obj))
          return

        let clanInfo = get_clan_info_table(true) 
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

setWwTooltipTypes(addTooltipTypes(wwTooltipTypes))
