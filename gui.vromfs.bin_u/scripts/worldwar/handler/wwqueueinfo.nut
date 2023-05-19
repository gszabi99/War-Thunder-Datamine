//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")

::gui_handlers.WwQueueInfo <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  sceneTplName = "%gui/worldWar/wwQueueInfo.tpl"

  static sidesList = [
    { id = "player_side_info" }
    { id = "enemy_side_info" }
  ]

  function getSceneTplView() {
    return { side = this.sidesList }
  }

  function initScreen() {
    this.scene.setUserData(this)
    let timerObj = this.scene.findObject("ww_queue_update_timer")

    if (checkObj(timerObj))
      timerObj.setUserData(this)
  }

  function onTimerUpdate(_obj, _dt) {
    let currentBattleQueue = ::queues.getActiveQueueWithType(QUEUE_TYPE_BIT.WW_BATTLE)
    if (!currentBattleQueue)
      return

    ::queues.updateQueueInfoByType(::g_queue_type.WW_BATTLE,
      function(queueInfo) {
        broadcastEvent("QueueInfoRecived", { queue_info = queueInfo })
      })
  }

  function onEventQueueInfoRecived(params) {
    let queueInfo = params?.queue_info
    if (!queueInfo || !::queues.isAnyQueuesActive(QUEUE_TYPE_BIT.WW_BATTLE))
      return

    foreach (battleInfo in queueInfo) {
      if (!("battleId" in battleInfo))
        continue
      let wwBattle = ::g_world_war.getBattleById(battleInfo?.battleId)
      foreach (idx, sideInfo in this.getSidesInfo(wwBattle)) {
        let sideObj = this.scene.findObject(this.getSidesObjName(idx))
        if (!checkObj(sideObj))
          continue

        if (!sideObj.isVisible())
          sideObj.show(true)

        this.fillBattleSideInfo(sideObj, sideInfo)
        this.fillQueueSideInfo(sideObj, battleInfo, wwBattle, sideInfo.side)
      }
      break
    }
  }

  function hideQueueInfoObj() {
    foreach (sideData in this.sidesList)
      this.showSceneBtn(sideData.id, false)
  }

  function getSidesInfo(battle) {
    let playerCountry = profileCountrySq.value
    let sidesInfo = []
    foreach (team in battle.teams) {
      let sideInfo = {
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

  function getSidesObjName(idx) {
    return this.sidesList[idx == 0 ? 0 : 1].id
  }

  function fillBattleSideInfo(containerObj, sideInfo) {
    let countryObj = containerObj.findObject("country")
    if (!checkObj(countryObj))
      return

    countryObj["background-image"] = getCustomViewCountryData(sideInfo.country).icon

    let maxPlayersTextObj = containerObj.findObject("max_players_text")
    if (!checkObj(maxPlayersTextObj))
      return

    maxPlayersTextObj.setValue(sideInfo.maxPlayers.tostring())
  }

  function fillQueueSideInfo(containerObj, battleQueueInfo, battle, side) {
    let teamName = "team" + battle.getTeamNameBySide(side)

    let sideInfoClanPlayers = containerObj.findObject("players_in_clans_count")
    sideInfoClanPlayers.setValue(
      this.getPlayersCountFromBattleQueueInfo(battleQueueInfo, teamName, "playersInClans"))

    let sideInfoOtherPlayers = containerObj.findObject("other_players_count")
    sideInfoOtherPlayers.setValue(
      this.getPlayersCountFromBattleQueueInfo(battleQueueInfo, teamName, "playersOther"))
  }

  function getPlayersCountFromBattleQueueInfo(battleQueueInfo, teamName, field) {
    if (!battleQueueInfo)
      return loc("ui/hyphen")

    let teamData = getTblValue(teamName, battleQueueInfo, null)
    if (field == "playersInClans") {
      local clanPlayerCount = 0
      let clanPlayers = getTblValue(field, teamData, [])
      foreach (clanPlayerData in clanPlayers)
        clanPlayerCount += getTblValue("count", clanPlayerData, 0)

      return clanPlayerCount.tostring()
    }
    else if (field == "playersOther") {
      let count = getTblValue(field, teamData, 0)
      return count.tostring()
    }

    return 0
  }
}
