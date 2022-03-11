local QUEUE_TYPE_BIT = require("scripts/queue/queueTypeBit.nut")
local { getCustomViewCountryData } = require("scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")

class ::gui_handlers.WwQueueInfo extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  sceneTplName = "gui/worldWar/wwQueueInfo"

  static sidesList = [
    {id = "player_side_info"}
    {id = "enemy_side_info"}
  ]

  function getSceneTplView()
  {
    return {side = sidesList}
  }

  function initScreen()
  {
    scene.setUserData(this)
    local timerObj = scene.findObject("ww_queue_update_timer")

    if (::checkObj(timerObj))
      timerObj.setUserData(this)
  }

  function onTimerUpdate(obj, dt)
  {
    local currentBattleQueue = ::queues.getActiveQueueWithType(QUEUE_TYPE_BIT.WW_BATTLE)
    if (!currentBattleQueue)
      return

    ::queues.updateQueueInfoByType(::g_queue_type.WW_BATTLE,
      function(queueInfo) {
        ::broadcastEvent("QueueInfoRecived", {queue_info = queueInfo})
      })
  }

  function onEventQueueInfoRecived(params)
  {
    local queueInfo = params?.queue_info
    if (!queueInfo || !::queues.isAnyQueuesActive(QUEUE_TYPE_BIT.WW_BATTLE))
      return

    foreach (battleInfo in queueInfo)
    {
      if (!("battleId" in battleInfo))
        continue
      local wwBattle = ::g_world_war.getBattleById(battleInfo?.battleId)
      foreach (idx, sideInfo in getSidesInfo(wwBattle))
      {
        local sideObj = scene.findObject(getSidesObjName(idx))
        if (!::check_obj(sideObj))
          continue

        if (!sideObj.isVisible())
          sideObj.show(true)

        fillBattleSideInfo(sideObj, sideInfo)
        fillQueueSideInfo(sideObj, battleInfo, wwBattle, sideInfo.side)
      }
      break
    }
  }

  function hideQueueInfoObj()
  {
    foreach (sideData in sidesList)
      showSceneBtn(sideData.id, false)
  }

  function getSidesInfo(battle)
  {
    local playerCountry = ::get_profile_country_sq()
    local sidesInfo = []
    foreach (team in battle.teams)
    {
      local sideInfo = {
        side = team.side
        country = team.country
        maxPlayers = team.maxPlayers
      }
      if (team.country == playerCountry)
        sidesInfo.insert(0, sideInfo)
      else
        sidesInfo.append(sideInfo)
    }

    return sidesInfo
  }

  function getSidesObjName(idx)
  {
    return sidesList[idx == 0 ? 0 : 1].id
  }

  function fillBattleSideInfo(containerObj, sideInfo)
  {
    local countryObj = containerObj.findObject("country")
    if (!::check_obj(countryObj))
      return

    countryObj["background-image"] = getCustomViewCountryData(sideInfo.country).icon

    local maxPlayersTextObj = containerObj.findObject("max_players_text")
    if (!::check_obj(maxPlayersTextObj))
      return

    maxPlayersTextObj.setValue(sideInfo.maxPlayers.tostring())
  }

  function fillQueueSideInfo(containerObj, battleQueueInfo, battle, side)
  {
    local teamName = "team" + battle.getTeamNameBySide(side)

    local sideInfoClanPlayers = containerObj.findObject("players_in_clans_count")
    sideInfoClanPlayers.setValue(
      getPlayersCountFromBattleQueueInfo(battleQueueInfo, teamName, "playersInClans"))

    local sideInfoOtherPlayers = containerObj.findObject("other_players_count")
    sideInfoOtherPlayers.setValue(
      getPlayersCountFromBattleQueueInfo(battleQueueInfo, teamName, "playersOther"))
  }

  function getPlayersCountFromBattleQueueInfo(battleQueueInfo, teamName, field)
  {
    if (!battleQueueInfo)
      return ::loc("ui/hyphen")

    local teamData = ::getTblValue(teamName, battleQueueInfo, null)
    if (field == "playersInClans")
    {
      local clanPlayerCount = 0
      local clanPlayers = ::getTblValue(field, teamData, [])
      foreach(clanPlayerData in clanPlayers)
        clanPlayerCount += ::getTblValue("count", clanPlayerData, 0)

      return clanPlayerCount.tostring()
    }
    else if (field == "playersOther")
    {
      local count = ::getTblValue(field, teamData, 0)
      return count.tostring()
    }

    return 0
  }
}
