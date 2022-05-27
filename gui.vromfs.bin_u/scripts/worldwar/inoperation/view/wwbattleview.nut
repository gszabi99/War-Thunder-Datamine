let time = require("%scripts/time.nut")
let wwActionsWithUnitsList = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")
let { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")

::WwBattleView <- class
{
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

  sceneTplArmyViewsName = "%gui/worldWar/worldWarMapArmyItem"

  isControlHelpCentered = true
  controlHelpDesc = @() hasControlTooltip()
    ? ::loc("worldwar/battle_open_info") : getBattleStatusText()
  consoleButtonsIconName = @() ::show_console_buttons && hasControlTooltip()
    ? WW_MAP_CONSPLE_SHORTCUTS.LMB_IMITATION : null
  controlHelpText = @() !::show_console_buttons && hasControlTooltip()
    ? ::loc("key/LMB") : null

  playerSide = null // need for show view for global battle

  constructor(v_battle = null, customPlayerSide = null)
  {
    battle = v_battle || ::WwBattle()
    playerSide = customPlayerSide ?? battle.getSide(::get_profile_country_sq())
    missionName = battle.getMissionName()
    name = battle.isStarted() ? battle.getLocName(playerSide) : ""
    desc = battle.getLocDesc()
    maxPlayersPerArmy = battle.maxPlayersPerArmy
  }

  function getId()
  {
    return battle.id
  }

  function getMissionName()
  {
    return name
  }

  function getShortBattleName()
  {
    return ::loc("worldWar/shortBattleName", {number = battle.getOrdinalNumber()})
  }

  function getBattleName()
  {
    if (!battle.isValid())
      return ""

    return ::loc("worldWar/battleName", {number = battle.getOrdinalNumber()})
  }

  function getFullBattleName()
  {
    return ::g_string.implode([getBattleName(), battle.getLocName(playerSide)], ::loc("ui/comma"))
  }

  function defineTeamBlock(sides)
  {
    teamBlock = getTeamBlockByIconSize(sides, WW_ARMY_GROUP_ICON_SIZE.BASE)
  }

  getTeamsDataBySides = @(sides) getTeamBlockByIconSize(sides, WW_ARMY_GROUP_ICON_SIZE.BASE, true)

  function getTeamBlockByIconSize(sides, iconSize, isInBattlePanel = false, param = null)
  {
    if (iconSize == WW_ARMY_GROUP_ICON_SIZE.MEDIUM)
    {
      if (largeArmyGroupIconTeamBlock == null)
        largeArmyGroupIconTeamBlock = getTeamsData(sides, iconSize, isInBattlePanel, param)

      return largeArmyGroupIconTeamBlock
    }
    else if (iconSize == WW_ARMY_GROUP_ICON_SIZE.SMALL)
    {
      if (mediumArmyGroupIconTeamBlock == null)
        mediumArmyGroupIconTeamBlock = getTeamsData(sides, iconSize, isInBattlePanel, param)

      return mediumArmyGroupIconTeamBlock
    }
    else
    {
      if (teamBlock == null)
        teamBlock = getTeamsData(sides, WW_ARMY_GROUP_ICON_SIZE.BASE, isInBattlePanel, param)

      return teamBlock
    }
  }

  function getTeamsData(sides, iconSize, isInBattlePanel, param)
  {
    let teams = []
    local maxSideArmiesNumber = 0
    local isVersusTextAdded = false
    let hasArmyInfo = ::getTblValue("hasArmyInfo", param, true)
    let hasVersusText = ::getTblValue("hasVersusText", param)
    let canAlignRight = ::getTblValue("canAlignRight", param, true)
    foreach(sideIdx, side in sides)
    {
      let team = battle.getTeamBySide(side)
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
      foreach (country, armiesArray in team.countries)
      {
        let countryIcon = getCustomViewCountryData(country, mapName).icon
        armies.countryIcon = countryIcon
        armies.countryIconBig = countryIcon
        foreach(army in armiesArray)
        {
          let armyView = army.getView()
          armyView.setSelectedSide(playerSide)
          armyViews.append(armyView)
        }
      }

      if (armyViews.len())
      {
        if (hasVersusText && !isVersusTextAdded)
        {
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

      armies.armyViews = ::handyman.renderCached(sceneTplArmyViewsName, view)
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
        teamSizeText = getTeamSizeText(team)
        haveUnitsList = avaliableUnits.len()
        unitsList = unitsList(avaliableUnits, invert && isInBattlePanel, isInBattlePanel)
        haveAIUnitsList = aiUnits.len()
        aiUnitsList = unitsList(aiUnits, invert && isInBattlePanel, isInBattlePanel)
      })
    }

    foreach (team in teams)
      team.armies.maxSideArmiesNumber = maxSideArmiesNumber

    return teams
  }

  function getTeamSizeText(team)
  {
    if (battle.isAutoBattle())
      return ::loc("worldWar/unavailable_for_team")

    let maxPlayers = ::getTblValue("maxPlayers", team)
    if (!maxPlayers)
      return ::loc("worldWar/unavailable_for_team")

    let minPlayers = ::getTblValue("minPlayers", team)
    let curPlayers = ::getTblValue("players", team)
    return battle.isConfirmed() && battle.getMyAssignCountry() ?
      ::loc("worldwar/battle/playersCurMax", { cur = curPlayers, max = maxPlayers }) :
      ::loc("worldwar/battle/playersMinMax", { min = minPlayers, max = maxPlayers })
  }

  function unitsList(wwUnits, isReflected, hasLineSpacing)
  {
    let view = { infoSections = [{
      columns = [{unitString = wwActionsWithUnitsList.getUnitsListViewParams({
        wwUnits = wwUnits
        params = { needShopInfo = true }
      })}]
      multipleColumns = false
      reflect = isReflected
      isShowTotalCount = true
      hasSpaceBetweenUnits = hasLineSpacing
    }]}
    return ::handyman.renderCached("%gui/worldWar/worldWarMapArmyInfoUnitsList", view)
  }

  function isStarted()
  {
    return battle.isStarted()
  }

  function hasBattleDurationTime()
  {
    return battle.getBattleDurationTime() > 0
  }

  function hasBattleActivateLeftTime()
  {
    return battle.getBattleActivateLeftTime() > 0
  }

  function getBattleDurationTime()
  {
    let durationTime = battle.getBattleDurationTime()
    if (durationTime > 0)
      return time.hoursToString(time.secondsToHours(durationTime), false, true)

    return ""
  }

  function getBattleActivateLeftTime()
  {
    let durationTime = battle.getBattleActivateLeftTime()
    if (durationTime > 0)
      return time.hoursToString(time.secondsToHours(durationTime), false, true)

    return ""
  }

  function getBattleStatusTextLocId()
  {
    if (!battle.isStillInOperation())
      return "worldwar/battle_finished"

    if (battle.isWaiting() ||
        battle.status == ::EBS_ACTIVE_STARTING)
      return "worldwar/battleNotActive"

    if (battle.status == ::EBS_ACTIVE_MATCHING)
      return "worldwar/battleIsStarting"

    if (battle.isAutoBattle())
      return "worldwar/battleIsInAutoMode"

    if (battle.isConfirmed())
    {
      if (battle.isPlayerTeamFull())
        return "worldwar/battleIsFull"
      else
        return "worldwar/battleIsActive"
    }

    return "worldwar/battle_finished"
  }

  function getAutoBattleWinChancePercentText()
  {
    let percent = battle.getTeamBySide(playerSide)?.autoBattleWinChancePercent
    return percent != null ? percent + ::loc("measureUnits/percent") : ""
  }

  function needShowWinChance()
  {
    return  battle.isWaiting() || battle.status == ::EBS_ACTIVE_AUTO
  }

  function getBattleStatusText()
  {
    return battle.isValid() ? ::loc(getBattleStatusTextLocId()) : ""
  }

  function getBattleStatusDescText()
  {
    return battle.isValid() ? ::loc(getBattleStatusTextLocId() + "/desc") : ""
  }

  function getCanJoinText()
  {
    if (playerSide == ::SIDE_NONE || ::g_squad_manager.isSquadMember())
      return ""

    let currentBattleQueue = ::queues.findQueueByName(battle.getQueueId(), true)
    local canJoinLocKey = ""
    if (currentBattleQueue != null)
      canJoinLocKey = "worldWar/canJoinStatus/in_queue"
    else if (battle.isStarted())
    {
      let cantJoinReasonData = battle.getCantJoinReasonData(playerSide, false)
      if (cantJoinReasonData.canJoin)
        canJoinLocKey = battle.isPlayerTeamFull()
          ? "worldWar/canJoinStatus/no_free_places"
          : "worldWar/canJoinStatus/can_join"
      else
        canJoinLocKey = cantJoinReasonData.reasonText
    }

    return ::u.isEmpty(canJoinLocKey) ? "" : ::loc(canJoinLocKey)
  }

  function getBattleStatusWithTimeText()
  {
    local text = getBattleStatusText()
    let durationText = getBattleDurationTime()
    if (!::u.isEmpty(durationText))
      text += ::loc("ui/colon") + durationText

    return text
  }

  function getBattleStatusWithCanJoinText()
  {
    if (!battle.isValid())
      return ""

    local text = getBattleStatusText()
    let canJoinText = getCanJoinText()
    if (!::u.isEmpty(canJoinText))
      text += ::loc("ui/dot") + " " + canJoinText

    return text
  }

  function getStatus()
  {
    if (!battle.isStillInOperation() || battle.isFinished())
      return "Finished"
    if (battle.isStarting())
      return "Active"
    if (battle.status == ::EBS_ACTIVE_AUTO || battle.status == ::EBS_ACTIVE_FAKE)
      return "Fake"
    if (battle.status == ::EBS_ACTIVE_CONFIRMED)
      return battle.isPlayerTeamFull() || !battle.hasAvailableUnits() ? "Full" : "OnServer"

    return "Inactive"
  }

  function getIconImage()
  {
    return (getStatus() == "Full" || battle.isFinished()) ?
      "#ui/gameuiskin#battles_closed" : "#ui/gameuiskin#battles_open"
  }

  function hasControlTooltip()
  {
    if (battle.isStillInOperation())
    {
      let status = getStatus()
      if (status == "Active" || status == "Full")
        return true
    }
    else
      return true

    return false
  }

  function getReplayBtnTooltip()
  {
    return ::loc("mainmenu/btnViewReplayTooltip", {sessionID = battle.getSessionId()})
  }

  function isAutoBattle()
  {
    return battle.isAutoBattle()
  }

  function hasTeamsInfo()
  {
    return battle.isValid() && battle.isConfirmed()
  }

  function hasQueueInfo()
  {
    return battle.isValid() && battle.hasQueueInfo()
  }

  function getTotalPlayersInfoText()
  {
    return ::loc("worldwar/totalPlayers") + ::loc("ui/colon") +
      ::colorize("newTextColor", battle.getTotalPlayersInfo(playerSide))
  }

  function getTotalQueuePlayersInfoText()
  {
    return ::loc("worldwar/totalInQueue") + ::loc("ui/colon") +
      ::colorize("newTextColor", battle.getTotalPlayersInQueueInfo(playerSide))
  }
  needShowTimer = @() !battle.isFinished()

  function getTimeStartAutoBattle()
  {
    if (!battle.isWaiting())
      return ""

    let durationTime = battle.getTimeStartAutoBattle()
    if (durationTime > 0)
      return time.hoursToString(time.secondsToHours(durationTime), false, true)

    return ""
  }
}
