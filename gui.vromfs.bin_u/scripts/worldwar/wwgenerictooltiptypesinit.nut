import "%sqStdLibs/helpers/u.nut" as u
from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%scripts/utils/genericTooltipTypes.nut" import addTooltipTypes
from "%scripts/tasker.nut" import addTask
from "%scripts/worldWar/worldWarGlobalStates.nut" import isWorldWarEnabled
from "%scripts/clans/clanInfoTable.nut" import get_clan_info_table
from "%scripts/worldWar/inOperation/model/wwArmy.nut" import getArmyByName
from "%scripts/worldWar/wwGenericTooltipTypes.nut" import setWwTooltipTypes
from "%scripts/clans/clanActions.nut" import requestMyClanData
from "%scripts/worldWar/worldWarState.nut" import getArmyGroups, getBattleById
from "%scripts/worldWar/inOperation/wwOperationStates.nut" import getSidesOrder
from "%scripts/worldWar/inOperation/model/wwAirfield.nut" import WwAirfield
from "%scripts/worldWar/inOperation/model/wwBattlesState.nut" import isStillInOperation, isAutoBattle
from "%scripts/dagui_natives.nut" import clan_get_my_clan_tag, clan_request_info, clan_get_my_clan_id
from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *
from "%scripts/clans/clanState.nut" import is_in_clan, myClanInfo

let wwLeaderboardData = require("%scripts/worldWar/operations/model/wwLeaderboardData.nut")
let WwBattleView = require("%scripts/worldWar/inOperation/view/wwBattleView.nut")


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

      let airfield = WwAirfield(params.currentId)
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

      let battle = getBattleById(params.currentId)
      if (!battle.isValid())
        return ""

      let battleView = WwBattleView(battle, {
        isStillInOperation = isStillInOperation(battle)
        isAutoBattle = isAutoBattle(battle)
      })
      battleView.defineTeamBlock(getSidesOrder(), { canAlignRight = false })
      battleView.showBattleStatus = true
      battleView.hideDesc = true
      return handyman.renderCached("%gui/worldWar/battleDescription.tpl", battleView)
    }
  }

  WW_LOG_BATTLE_TOOLTIP = {
    getTooltipContent = function(_id, params) {
      let battle = getBattleById(params.currentId)
      let battleView = WwBattleView(battle, {
        isStillInOperation = isStillInOperation(battle)
        isAutoBattle = isAutoBattle(battle)
      })
      return handyman.renderCached("%gui/worldWar/wwControlHelp.tpl", battleView)
    }
  }

  WW_MAP_TOOLTIP_TYPE_GROUP = {
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, id, _params) {
      if (!isWorldWarEnabled())
        return false

      let group = u.search(getArmyGroups(),  function(group) { return group.clanId == id })
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
        requestMyClanData()
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
