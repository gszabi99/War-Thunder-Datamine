//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let time = require("%scripts/time.nut")
let wwActionsWithUnitsList = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")
let { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")

::WwBattleView <- class {
  id = ""
  battle = null

  missionName = ""
  name = ""
  desc = ""
  maxPlayersPerArmy = -1

  teamBlock = null
  largeArmyGroupIconTeamBlock = null
  mediumArmyGroupIconTeamBlock = null

  showBattleStatus = false
  hideDesc = false

  sceneTplArmyViewsName = "%gui/worldWar/worldWarMapArmyItem.tpl"

  isControlHelpCentered = true
  controlHelpDesc = @() this.hasControlTooltip()
    ? loc("worldwar/battle_open_info") : this.getBattleStatusText()
  consoleButtonsIconName = @() ::show_console_buttons && this.hasControlTooltip()
    ? WW_MAP_CONSPLE_SHORTCUTS.LMB_IMITATION : null
  controlHelpText = @() !::show_console_buttons && this.hasControlTooltip()
    ? loc("key/LMB") : null

  playerSide = null // need for show view for global battle

  constructor(v_battle = null, customPlayerSide = null) {
    this.battle = v_battle || ::WwBattle()
    this.playerSide = customPlayerSide ?? this.battle.getSide(profileCountrySq.value)
    this.missionName = this.battle.getMissionName()
    this.name = this.battle.isStarted() ? this.battle.getLocName(this.playerSide) : ""
    this.desc = this.battle.getLocDesc()
    this.maxPlayersPerArmy = this.battle.maxPlayersPerArmy
  }

  function getId() {
    return this.battle.id
  }

  function getMissionName() {
    return this.name
  }

  function getShortBattleName() {
    return loc("worldWar/shortBattleName", { number = this.battle.getOrdinalNumber() })
  }

  function getBattleName() {
    if (!this.battle.isValid())
      return ""

    return loc("worldWar/battleName", { number = this.battle.getOrdinalNumber() })
  }

  function getFullBattleName() {
    return ::g_string.implode([this.getBattleName(), this.battle.getLocName(this.playerSide)], loc("ui/comma"))
  }

  function defineTeamBlock(sides) {
    this.teamBlock = this.getTeamBlockByIconSize(sides, WW_ARMY_GROUP_ICON_SIZE.BASE)
  }

  getTeamsDataBySides = @(sides) this.getTeamBlockByIconSize(sides, WW_ARMY_GROUP_ICON_SIZE.BASE, true)

  function getTeamBlockByIconSize(sides, iconSize, isInBattlePanel = false, param = null) {
    if (iconSize == WW_ARMY_GROUP_ICON_SIZE.MEDIUM) {
      if (this.largeArmyGroupIconTeamBlock == null)
        this.largeArmyGroupIconTeamBlock = this.getTeamsData(sides, iconSize, isInBattlePanel, param)

      return this.largeArmyGroupIconTeamBlock
    }
    else if (iconSize == WW_ARMY_GROUP_ICON_SIZE.SMALL) {
      if (this.mediumArmyGroupIconTeamBlock == null)
        this.mediumArmyGroupIconTeamBlock = this.getTeamsData(sides, iconSize, isInBattlePanel, param)

      return this.mediumArmyGroupIconTeamBlock
    }
    else {
      if (this.teamBlock == null)
        this.teamBlock = this.getTeamsData(sides, WW_ARMY_GROUP_ICON_SIZE.BASE, isInBattlePanel, param)

      return this.teamBlock
    }
  }

  function getTeamsData(sides, iconSize, isInBattlePanel, param) {
    let teams = []
    local maxSideArmiesNumber = 0
    local isVersusTextAdded = false
    let hasArmyInfo = getTblValue("hasArmyInfo", param, true)
    let hasVersusText = getTblValue("hasVersusText", param)
    let canAlignRight = getTblValue("canAlignRight", param, true)
    foreach (sideIdx, side in sides) {
      let team = this.battle.getTeamBySide(side)
      if (!team)
        continue

      let armies = {
        countryIcon = ""
        countryIconBig = ""
        armyViews = ""
        maxSideArmiesNumber = 0
      }

      let mapName = getOperationById(::ww_get_operation_id())?.getMapId() ?? ""
      let armyViews = []
      foreach (country, armiesArray in team.countries) {
        let countryIcon = getCustomViewCountryData(country, mapName).icon
        armies.countryIcon = countryIcon
        armies.countryIconBig = countryIcon
        foreach (army in armiesArray) {
          let armyView = army.getView()
          armyView.setSelectedSide(this.playerSide)
          armyViews.append(armyView)
        }
      }

      if (armyViews.len()) {
        if (hasVersusText && !isVersusTextAdded) {
          armyViews.top().setHasVersusText(true)
          isVersusTextAdded = true
        }
        else
          armyViews.top().setHasVersusText(false)
      }

      maxSideArmiesNumber = max(maxSideArmiesNumber, armyViews.len())

      let view = {
        army = armyViews
        delimetrRightPadding = hasArmyInfo ? "8*@sf/@pf_outdated" : 0
        reqUnitTypeIcon = true
        hideArrivalTime = true
        showArmyGroupText = false
        battleDescriptionIconSize = iconSize
        isArmyAlwaysUnhovered = true
        needShortInfoText = hasArmyInfo
        hasTextAfterIcon = hasArmyInfo
        isInvert = canAlignRight && sideIdx != 0
      }

      armies.armyViews = ::handyman.renderCached(this.sceneTplArmyViewsName, view)
      let invert = sideIdx != 0

      let avaliableUnits = []
      let aiUnits = []
      foreach (unit in team.unitsRemain)
        if (unit.isControlledByAI())
          aiUnits.append(unit)
        else
          avaliableUnits.append(unit)

      teams.append({
        invert = invert
        teamName = team.name
        armies = armies
        teamSizeText = this.getTeamSizeText(team)
        haveUnitsList = avaliableUnits.len()
        unitsList = this.unitsList(avaliableUnits, invert && isInBattlePanel, isInBattlePanel)
        haveAIUnitsList = aiUnits.len()
        aiUnitsList = this.unitsList(aiUnits, invert && isInBattlePanel, isInBattlePanel)
      })
    }

    foreach (team in teams)
      team.armies.maxSideArmiesNumber = maxSideArmiesNumber

    return teams
  }

  function getTeamSizeText(team) {
    if (this.battle.isAutoBattle())
      return loc("worldWar/unavailable_for_team")

    let maxPlayers = getTblValue("maxPlayers", team)
    if (!maxPlayers)
      return loc("worldWar/unavailable_for_team")

    let minPlayers = getTblValue("minPlayers", team)
    let curPlayers = getTblValue("players", team)
    return this.battle.isConfirmed() && this.battle.getMyAssignCountry() ?
      loc("worldwar/battle/playersCurMax", { cur = curPlayers, max = maxPlayers }) :
      loc("worldwar/battle/playersMinMax", { min = minPlayers, max = maxPlayers })
  }

  function unitsList(wwUnits, isReflected, hasLineSpacing) {
    let view = { infoSections = [{
      columns = [{ unitString = wwActionsWithUnitsList.getUnitsListViewParams({
        wwUnits = wwUnits
        params = { needShopInfo = true }
      }) }]
      multipleColumns = false
      reflect = isReflected
      isShowTotalCount = true
      hasSpaceBetweenUnits = hasLineSpacing
    }] }
    return ::handyman.renderCached("%gui/worldWar/worldWarMapArmyInfoUnitsList.tpl", view)
  }

  function isStarted() {
    return this.battle.isStarted()
  }

  function hasBattleDurationTime() {
    return this.battle.getBattleDurationTime() > 0
  }

  function hasBattleActivateLeftTime() {
    return this.battle.getBattleActivateLeftTime() > 0
  }

  function getBattleDurationTime() {
    let durationTime = this.battle.getBattleDurationTime()
    if (durationTime > 0)
      return time.hoursToString(time.secondsToHours(durationTime), false, true)

    return ""
  }

  function getBattleActivateLeftTime() {
    let durationTime = this.battle.getBattleActivateLeftTime()
    if (durationTime > 0)
      return time.hoursToString(time.secondsToHours(durationTime), false, true)

    return ""
  }

  function getBattleStatusTextLocId() {
    if (!this.battle.isStillInOperation())
      return "worldwar/battle_finished"

    if (this.battle.isWaiting() ||
        this.battle.status == EBS_ACTIVE_STARTING)
      return "worldwar/battleNotActive"

    if (this.battle.status == EBS_ACTIVE_MATCHING)
      return "worldwar/battleIsStarting"

    if (this.battle.isAutoBattle())
      return "worldwar/battleIsInAutoMode"

    if (this.battle.isConfirmed()) {
      if (this.battle.isPlayerTeamFull())
        return "worldwar/battleIsFull"
      else
        return "worldwar/battleIsActive"
    }

    return "worldwar/battle_finished"
  }

  function getAutoBattleWinChancePercentText() {
    let percent = this.battle.getTeamBySide(this.playerSide)?.autoBattleWinChancePercent
    return percent != null ? percent + loc("measureUnits/percent") : ""
  }

  function needShowWinChance() {
    return  this.battle.isWaiting() || this.battle.status == EBS_ACTIVE_AUTO
  }

  function getBattleStatusText() {
    return this.battle.isValid() ? loc(this.getBattleStatusTextLocId()) : ""
  }

  function getBattleStatusDescText() {
    return this.battle.isValid() ? loc(this.getBattleStatusTextLocId() + "/desc") : ""
  }

  function getCanJoinText() {
    if (this.playerSide == SIDE_NONE || ::g_squad_manager.isSquadMember())
      return ""

    let currentBattleQueue = ::queues.findQueueByName(this.battle.getQueueId(), true)
    local canJoinLocKey = ""
    if (currentBattleQueue != null)
      canJoinLocKey = "worldWar/canJoinStatus/in_queue"
    else if (this.battle.isStarted()) {
      let cantJoinReasonData = this.battle.getCantJoinReasonData(this.playerSide, false)
      if (cantJoinReasonData.canJoin)
        canJoinLocKey = this.battle.isPlayerTeamFull()
          ? "worldWar/canJoinStatus/no_free_places"
          : "worldWar/canJoinStatus/can_join"
      else
        canJoinLocKey = cantJoinReasonData.reasonText
    }

    return ::u.isEmpty(canJoinLocKey) ? "" : loc(canJoinLocKey)
  }

  function getBattleStatusWithTimeText() {
    local text = this.getBattleStatusText()
    let durationText = this.getBattleDurationTime()
    if (!::u.isEmpty(durationText))
      text += loc("ui/colon") + durationText

    return text
  }

  function getBattleStatusWithCanJoinText() {
    if (!this.battle.isValid())
      return ""

    local text = this.getBattleStatusText()
    let canJoinText = this.getCanJoinText()
    if (!::u.isEmpty(canJoinText))
      text += loc("ui/dot") + " " + canJoinText

    return text
  }

  function getStatus() {
    if (!this.battle.isStillInOperation() || this.battle.isFinished())
      return "Finished"
    if (this.battle.isStarting())
      return "Active"
    if (this.battle.status == EBS_ACTIVE_AUTO || this.battle.status == EBS_ACTIVE_FAKE)
      return "Fake"
    if (this.battle.status == EBS_ACTIVE_CONFIRMED)
      return this.battle.isPlayerTeamFull() || !this.battle.hasAvailableUnits() ? "Full" : "OnServer"

    return "Inactive"
  }

  function getIconImage() {
    return (this.getStatus() == "Full" || this.battle.isFinished()) ?
      "#ui/gameuiskin#battles_closed" : "#ui/gameuiskin#battles_open"
  }

  function hasControlTooltip() {
    if (this.battle.isStillInOperation()) {
      let status = this.getStatus()
      if (status == "Active" || status == "Full")
        return true
    }
    else
      return true

    return false
  }

  function getReplayBtnTooltip() {
    return loc("mainmenu/btnViewReplayTooltip", { sessionID = this.battle.getSessionId() })
  }

  function isAutoBattle() {
    return this.battle.isAutoBattle()
  }

  function hasTeamsInfo() {
    return this.battle.isValid() && this.battle.isConfirmed()
  }

  function hasQueueInfo() {
    return this.battle.isValid() && this.battle.hasQueueInfo()
  }

  function getTotalPlayersInfoText() {
    return loc("worldwar/totalPlayers") + loc("ui/colon") +
      colorize("newTextColor", this.battle.getTotalPlayersInfo(this.playerSide))
  }

  function getTotalQueuePlayersInfoText() {
    return loc("worldwar/totalInQueue") + loc("ui/colon") +
      colorize("newTextColor", this.battle.getTotalPlayersInQueueInfo(this.playerSide))
  }
  needShowTimer = @() !this.battle.isFinished()

  function getTimeStartAutoBattle() {
    if (!this.battle.isWaiting())
      return ""

    let durationTime = this.battle.getTimeStartAutoBattle()
    if (durationTime > 0)
      return time.hoursToString(time.secondsToHours(durationTime), false, true)

    return ""
  }
}
