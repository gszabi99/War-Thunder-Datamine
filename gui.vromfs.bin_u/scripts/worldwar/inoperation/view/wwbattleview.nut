from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *
from "%scripts/squads/squadsConsts.nut" import *

let time = require("%scripts/time.nut")
let wwActionsWithUnitsList = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")
let { wwGetOperationId } = require("worldwar")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let WwBattle = require("%scripts/worldWar/inOperation/model/wwBattle.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")


let WwBattleView = class  {
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
  playerSide = null 

  isControlHelpCentered = true

  controlHelpDesc = @() this.hasControlTooltip()
    ? loc("worldwar/battle_open_info") : this.getBattleStatusText()
  consoleButtonsIconName = @() showConsoleButtons.get() && this.hasControlTooltip()
    ? WW_MAP_CONSPLE_SHORTCUTS.LMB_IMITATION : null
  controlHelpText = @() !showConsoleButtons.get() && this.hasControlTooltip()
    ? loc("key/LMB") : null

  isStillInOperation = false
  isAutoBattle = false

  constructor(v_battle = null, params = {}) {
    this.battle = v_battle || WwBattle()

    this.playerSide = params?.side ?? this.battle.getSide(profileCountrySq.get())
    this.isStillInOperation = params?.isStillInOperation ?? false
    this.isAutoBattle = params?.isAutoBattle ?? false

    this.missionName = this.battle.getMissionName()
    this.name = this.battle.isStarted() ? this.battle.getLocName(this.playerSide) : ""
    this.desc = this.battle.getLocDesc()
    this.maxPlayersPerArmy = this.battle.maxPlayersPerArmy
  }

  getId = @() this.battle.id

  getMissionName = @() this.name

  getShortBattleName = @() loc("worldWar/shortBattleName", {
    number = this.battle.getOrdinalNumber()
  })

  getBattleName = @() this.battle.getBattleName()

  getFullBattleName = @()
    loc("ui/comma").join([this.getBattleName(), this.battle.getLocName(this.playerSide)], true)

  function defineTeamBlock(sides, params) {
    this.teamBlock = this.getTeamBlockByIconSize(sides, WW_ARMY_GROUP_ICON_SIZE.BASE, false, params)
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

      let mapName = getOperationById(wwGetOperationId())?.getMapId() ?? ""
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

      armies.armyViews = handyman.renderCached(this.sceneTplArmyViewsName, view)
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
    if (this.isAutoBattle)
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
    let view = {
      infoSections = [{
        columns = [{
          unitString = wwActionsWithUnitsList.getUnitsListViewParams({
            wwUnits = wwUnits
            params = { needShopInfo = true }
          })
        }]
        multipleColumns = false
        reflect = isReflected
        isShowTotalCount = true
        hasSpaceBetweenUnits = hasLineSpacing
      }]
    }
    return handyman.renderCached("%gui/worldWar/worldWarMapArmyInfoUnitsList.tpl", view)
  }

  isStarted = @() this.battle.isStarted()

  hasBattleDurationTime = @() this.battle.getBattleDurationTime() > 0

  hasBattleActivateLeftTime = @() this.battle.getBattleActivateLeftTime() > 0

  function getBattleDurationTime() {
    let durationTime = this.battle.getBattleDurationTime()
    return durationTime <= 0 ? ""
      : time.hoursToString(time.secondsToHours(durationTime), false, true)
  }

  function getBattleActivateLeftTime() {
    let durationTime = this.battle.getBattleActivateLeftTime()
    return durationTime <= 0 ? ""
      : time.hoursToString(time.secondsToHours(durationTime), false, true)
  }

  function getAutoBattleWinChancePercentText() {
    let percent = this.battle.getTeamBySide(this.playerSide)?.autoBattleWinChancePercent
    return percent != null ? $"{percent}{loc("measureUnits/percent")}" : ""
  }

  needShowWinChance = @() this.battle.isWaiting() || this.battle.status == EBS_ACTIVE_AUTO

  function getStatus() {
    if (!this.isStillInOperation || this.battle.isFinished())
      return "Finished"
    if (this.battle.isStarting())
      return "Active"
    if (this.battle.status == EBS_ACTIVE_AUTO || this.battle.status == EBS_ACTIVE_FAKE)
      return "Fake"
    if (this.battle.status == EBS_ACTIVE_CONFIRMED)
      return this.battle.isPlayerTeamFull() || !this.battle.hasAvailableUnits() ? "Full" : "OnServer"

    return "Inactive"
  }

  getIconImage = @() this.getStatus() == "Full" || this.battle.isFinished()
    ? "#ui/gameuiskin#battles_closed"
    : "#ui/gameuiskin#battles_open"

  getReplayBtnTooltip = @() loc("mainmenu/btnViewReplayTooltip", {
    sessionID = this.battle.getSessionId()
  })

  hasTeamsInfo = @() this.battle.isValid() && this.battle.isConfirmed()

  hasQueueInfo = @() this.battle.isValid() && this.battle.hasQueueInfo()

  getTotalPlayersInfoText = @()
    loc("ui/colon").concat(
      loc("worldwar/totalPlayers"),
      colorize("newTextColor", this.battle.getTotalPlayersInfo(this.playerSide))
    )

  getTotalQueuePlayersInfoText = @()
    loc("ui/colon").concat(
      loc("worldwar/totalInQueue"),
      colorize("newTextColor", this.battle.getTotalPlayersInQueueInfo(this.playerSide))
    )

  needShowTimer = @() !this.battle.isFinished()

  function getTimeStartAutoBattle() {
    if (!this.battle.isWaiting())
      return ""

    let durationTime = this.battle.getTimeStartAutoBattle()
    if (durationTime > 0)
      return time.hoursToString(time.secondsToHours(durationTime), false, true)

    return ""
  }

  getBattleStatusTextLocId = @()
    !this.isStillInOperation ? "worldwar/battle_finished"
      : this.battle.isWaiting() || this.battle.status == EBS_ACTIVE_STARTING ? "worldwar/battleNotActive"
      : this.battle.status == EBS_ACTIVE_MATCHING ? "worldwar/battleIsStarting"
      : this.isAutoBattle ? "worldwar/battleIsInAutoMode"
      : !this.battle.isConfirmed() ? "worldwar/battle_finished"
      : this.battle.isPlayerTeamFull() ? "worldwar/battleIsFull"
      : "worldwar/battleIsActive"

  getBattleStatusText = @() !this.battle.isValid() ? "" : loc(this.getBattleStatusTextLocId())

  function hasControlTooltip() {
    if (!this.isStillInOperation)
      return true

    let status = this.getStatus()
    return status == "Active" || status == "Full"
  }
}

return WwBattleView
