from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let time = require("%scripts/time.nut")
let { GO_NONE, GO_WAITING_FOR_RESULT } = require_native("guiMission")
let { PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { MISSION_OBJECTIVE } = require("%scripts/missions/missionsUtilsModule.nut")

enum LIVE_STATS_MODE {
  WATCH
  SPAWN
  FINAL

  TOTAL
}

::g_hud_live_stats <- {
  [PERSISTENT_DATA_PARAMS] = ["spawnStartState"]

  scene     = null
  guiScene  = null
  parentObj = null
  nestObjId = ""

  isSelfTogglable = false
  isInitialized = false
  missionMode = GT_VERSUS
  missionObjectives = MISSION_OBJECTIVE.NONE
  isMissionTeamplay = false
  isMissionRace = false
  isMissionLastManStanding = false
  isAwaitingSpawn = false
  spawnStartState = null
  isMissionFinished = false
  missionResult = null
  gameType = 0

  hero = {
    streaks = []
    units   = []
  }

  curViewPlayerId = null
  curViewMode = LIVE_STATS_MODE.WATCH
  curColumnsOrder = []
  isActive = false
  visState  = null

  isSwitchScene = false

  columnsOrder = {
    [GT_VERSUS] = {
      [LIVE_STATS_MODE.SPAWN] = [ "captureZone", "damageZone", "missionAliveTime", "kills", "groundKills", "navalKills",
                                  "aiKills", "aiGroundKills", "aiNavalKills", "aiTotalKills", "assists", "score" ],
      [LIVE_STATS_MODE.FINAL] = [ "captureZone", "damageZone", "missionAliveTime", "kills", "groundKills", "navalKills",
                                  "aiKills", "aiGroundKills", "aiNavalKills", "aiTotalKills", "assists", "deaths", "score" ],
      [LIVE_STATS_MODE.WATCH] = [ "name", "score", "captureZone", "damageZone", "missionAliveTime", "kills", "groundKills", "navalKills",
                                  "aiKills", "aiGroundKills", "aiNavalKills", "aiTotalKills", "assists", "deaths" ],
    },
    [GT_RACE] = {
      [LIVE_STATS_MODE.SPAWN] = [ "rowNo", "raceFinishTime", "raceBestLapTime", "penaltyTime" ],
      [LIVE_STATS_MODE.FINAL] = [ "rowNo", "raceFinishTime", "raceBestLapTime", "penaltyTime", "deaths" ],
      [LIVE_STATS_MODE.WATCH] = [ "rowNo", "name", "raceFinishTime", "raceBestLapTime", "penaltyTime", "deaths" ],
    },
    [GT_FOOTBALL] = {
      [LIVE_STATS_MODE.SPAWN] = [ "footballGoals", "footballAssists", "footballScore" ],
      [LIVE_STATS_MODE.FINAL] = [ "footballGoals", "footballAssists", "footballScore" ],
      [LIVE_STATS_MODE.WATCH] = [ "name", "footballGoals", "footballAssists", "footballScore" ],
    },
  }
  function init(parent_obj, nest_obj_id, is_self_togglable)
  {
    if (!hasFeature("LiveStats"))
      return
    if (!checkObj(parent_obj))
      return
    this.parentObj = parent_obj
    this.nestObjId = nest_obj_id
    this.guiScene  = this.parentObj.getScene()

    this.isSelfTogglable = is_self_togglable
    this.gameType = ::get_game_type()
    this.missionMode =
        (this.gameType & GT_RACE) ? GT_RACE
      : (this.gameType & GT_FOOTBALL) ? GT_FOOTBALL
      : GT_VERSUS
    this.isMissionTeamplay = ::is_mode_with_teams(this.gameType)
    this.isMissionRace = !!(this.gameType & GT_RACE)
    this.isMissionFinished = false
    this.missionResult = null
    this.missionObjectives = ::g_mission_type.getCurrentObjectives()
    this.isMissionLastManStanding = !!(this.gameType & GT_LAST_MAN_STANDING)

    this.show(false)

    this.hero = {
      streaks = []
      units   = []
    }

    if (!this.isInitialized)
    {
      ::add_event_listener("StreakArrived", this.onEventStreakArrived, this)
      this.isInitialized = true
    }

    if (this.isSelfTogglable)
    {
      this.isAwaitingSpawn = true

      ::g_hud_event_manager.subscribe("MissionResult", this.onMissionResult, this)
      ::g_hud_event_manager.subscribe("LocalPlayerAlive", function (_data) {
        this.checkPlayerSpawned()
      }, this)
      ::g_hud_event_manager.subscribe("LocalPlayerDead", function (_data) {
        this.checkPlayerDead()
      }, this)
    }

    this.reinit()
  }

  function reinit()
  {
    let _scene = checkObj(this.parentObj) ? this.parentObj.findObject(this.nestObjId) : null
    if (!checkObj(_scene))
      return

    this.isSwitchScene = !::u.isEqual(this.scene, _scene)
    this.scene = _scene

    this.checkPlayerSpawned()
    this.checkPlayerDead()
  }

  function getState(playerId = null, diffState = null)
  {
    let now = ::get_usefull_total_time()
    let isHero = playerId == null
    let player = isHero ? ::get_local_mplayer() : ::get_mplayer_by_id(playerId)

    let state = {
      player    = player || {}
      streaks   = isHero ? (clone this.hero.streaks) : []
      timestamp = now
      lifetime  = 0.0
    }

    if (this.isMissionRace && this.missionResult != GO_WAITING_FOR_RESULT)
      state.player["rowNo"] <- this.getPlayerPlaceInTeam(state.player)

    foreach (id in this.curColumnsOrder)
      if (!(id in state.player))
        state.player[id] <- ::g_mplayer_param_type.getTypeById(id).getVal(state.player)

    if (diffState)
    {
      let p1 = diffState.player
      let p2 = state.player
      foreach (id in this.curColumnsOrder)
        if (id in p1)
          p2[id] = ::g_mplayer_param_type.getTypeById(id).diffFunc(p1[id], p2[id])

      if (diffState.streaks.len())
        state.streaks = state.streaks.slice(min(diffState.streaks.len(), state.streaks.len()))

      if (!diffState.lifetime)
        diffState.lifetime = now - diffState.timestamp
      state.lifetime = diffState.lifetime
    }

    return state
  }

  function isVisible()
  {
    return this.isSelfTogglable && this.isActive
  }

  function show(activate, viewMode = null, playerId = null)
  {
    let isSceneValid = checkObj(this.scene)
    activate = activate && isSceneValid
    let isVisibilityToggle = this.isSelfTogglable && this.isActive != activate
    this.isActive = activate

    if (isSceneValid)
    {
      this.scene.show(this.isActive)

      this.curViewPlayerId = playerId
      this.curViewMode = (viewMode != null && viewMode >= 0 && viewMode < LIVE_STATS_MODE.TOTAL) ?
        viewMode : LIVE_STATS_MODE.WATCH
      this.curColumnsOrder = getTblValue(this.curViewMode, getTblValue(this.missionMode, this.columnsOrder, {}), [])

      let misObjs = this.missionObjectives
      let gt = this.gameType
      this.curColumnsOrder = ::u.filter(this.curColumnsOrder, @(id)
        ::g_mplayer_param_type.getTypeById(id).isVisible(misObjs, gt, ::get_game_mode()))

      this.fill()
    }

    if (isVisibilityToggle)
      ::g_hud_event_manager.onHudEvent("LiveStatsVisibilityToggled", { visible = this.isActive })
  }

  function fill()
  {
    if (!checkObj(this.scene))
      return

    if (!this.isActive)
    {
      this.guiScene.replaceContentFromText(this.scene, "", 0, this)
      return
    }

    let isCompareStates = this.curViewMode == LIVE_STATS_MODE.SPAWN
    let state = this.getState(this.curViewPlayerId, isCompareStates ? this.spawnStartState : null)

    local title = ""
    if (this.curViewMode == LIVE_STATS_MODE.WATCH || this.missionResult == GO_WAITING_FOR_RESULT)
      title = ""
    else if (this.curViewMode == LIVE_STATS_MODE.SPAWN && !this.isMissionLastManStanding)
    {
      let txtUnitName = ::getUnitName(getTblValue("aircraftName", state.player, ""))
      let txtLifetime = time.secondsToString(state.lifetime, true)
      title = loc("multiplayer/lifetime") + loc("ui/parentheses/space", { text = txtUnitName }) + loc("ui/colon") + txtLifetime
    }
    else if (this.curViewMode == LIVE_STATS_MODE.FINAL || this.isMissionLastManStanding)
    {
      title = this.isMissionTeamplay ? loc("debriefing/placeInMyTeam") :
        (loc("mainmenu/btnMyPlace") + loc("ui/colon"))
      title += colorize("userlogColoredText", getTblValue("rowNo", state.player, this.getPlayerPlaceInTeam(state.player)))
    }

    let isHeader = this.curViewMode == LIVE_STATS_MODE.FINAL

    let view = {
      title = title
      isHeader = isHeader
      player = []
      lifetime = isCompareStates && !this.isMissionLastManStanding
    }

    foreach (id in this.curColumnsOrder)
    {
      let param = ::g_mplayer_param_type.getTypeById(id)
      let value = state.player?[id] ?? param.defVal
      let lableName = param.getName(value)
      view.player.append({
        id       = id
        fontIcon = param.fontIcon
        label    = lableName
        tooltip  = lableName
      })
    }

    if (this.curViewMode == LIVE_STATS_MODE.FINAL)
    {
      let unitNames = []
      foreach (unitId in this.hero.units)
        unitNames.append(::getUnitName(unitId))
      view["units"] <- loc("mainmenu/btnUnits") + loc("ui/colon") +
        ::g_string.implode(unitNames, loc("ui/comma"))
    }

    let template = this.isSelfTogglable ? "%gui/hud/hudLiveStats.tpl" : "%gui/hud/hudLiveStatsSpectator.tpl"
    let markup = ::handyman.renderCached(template, view)
    this.guiScene.replaceContentFromText(this.scene, markup, markup.len(), this)

    let timerObj = this.scene.findObject("update_timer")
    if (checkObj(timerObj))
      timerObj.setUserData(this)

    this.visState = null
    this.update(null, 0.0)
  }

  function update(_o = null, _dt = 0.0)
  {
    if (!this.isActive || !checkObj(this.scene))
      return

    let isCompareStates = this.curViewMode == LIVE_STATS_MODE.SPAWN
    let state = this.getState(this.curViewPlayerId, isCompareStates ? this.spawnStartState : null)

    foreach (id in this.curColumnsOrder)
    {
      let param = ::g_mplayer_param_type.getTypeById(id)

      let value = getTblValue(id, state.player, param.defVal)
      let visValue = this.visState ? getTblValue(id, this.visState.player, param.defVal) : param.defVal
      if (visValue == value && !param.isForceUpdate)
        continue

      let isValid = value != param.defVal || param.isForceUpdate
      let text = isValid ? param.printFunc(value, state.player) : ""
      let doShow = text != ""

      let plateObj = this.scene.findObject("plate_" + id)
      if (checkObj(plateObj) && plateObj.isVisible() != doShow)
        plateObj.show(doShow)

      local txtObj = this.scene.findObject("txt_" + id)
      if (checkObj(txtObj) && txtObj.getValue() != text)
        txtObj.setValue(text)

      let lableName = param.getName(value)
      plateObj["tooltip"] = lableName
      txtObj = this.scene.findObject($"lable_{id}")
      if (checkObj(txtObj) && txtObj.getValue() != lableName)
        txtObj.setValue(lableName)
    }

    if (isCompareStates && (!this.visState || this.visState.lifetime != state.lifetime) && !this.isMissionLastManStanding)
    {
      let text = time.secondsToString(state.lifetime, true)
      let obj = this.scene.findObject("txt_lifetime")
      if (checkObj(obj) && obj.getValue() != text)
        obj.setValue(text)
    }

    let visStreaksLen = this.visState ? this.visState.streaks.len() : 0
    if (state.streaks.len() != visStreaksLen)
    {
      let obj = this.scene.findObject("hero_streaks")
      if (checkObj(obj))
      {
        local awardsList = []
        foreach (id in state.streaks)
          awardsList.append({unlockType = UNLOCKABLE_STREAK, unlockId = id})
        awardsList = ::combineSimilarAwards(awardsList)

        let view = { awards = [] }
        foreach (award in awardsList)
          view.awards.append({
            iconLayers = ::LayersIcon.getIconData("streak_" + award.unlockId)
            amount = award.amount > 1 ? "x" + award.amount : null
          })
        let markup = ::handyman.renderCached(("%gui/statistics/statAwardIcon.tpl"), view)
        this.guiScene.replaceContentFromText(obj, markup, markup.len(), this)
      }
    }

    this.visState = state
  }

  function isValid()
  {
    return true
  }

  function getPlayerPlaceInTeam(player)
  {
    let playerId = getTblValue("id", player, -1)
    let teamId = this.isMissionTeamplay ? getTblValue("team", player, GET_MPLAYERS_LIST) : GET_MPLAYERS_LIST
    let players = ::get_mplayers_list(teamId, true)

    players.sort(::mpstat_get_sort_func(this.gameType))

    foreach (idx, p in players)
      if (getTblValue("id", p) == playerId)
        return idx + 1
    return 0
  }

  function checkPlayerSpawned()
  {
    if (!this.isAwaitingSpawn)
      return
    let player = ::get_local_mplayer()
    if (player.isDead || player.state != PLAYER_IN_FLIGHT)
      return
    let aircraftName = getTblValue("aircraftName", player, "")
    if (aircraftName == "" || aircraftName == "dummy_plane")
      return
    this.isAwaitingSpawn = false
    this.onPlayerSpawn()
  }

  function checkPlayerDead()
  {
    if (this.isAwaitingSpawn && !this.isSwitchScene)
      return
    if (!this.hero.units.len())
      return
    let player = ::get_local_mplayer()
    if (player.isTemporary)
      return
    if (!player.isDead)
      return
    this.isAwaitingSpawn = true
    this.onPlayerDeath()
  }

  function onEventStreakArrived(params)
  {
    this.hero.streaks.append(getTblValue("id", params))
  }

  function onMissionResult(eventData)
  {
    if (!this.isSelfTogglable || this.isMissionFinished)
      return
    this.isMissionFinished = true
    this.missionResult = eventData?.resultNum ?? GO_NONE
    this.show(true, LIVE_STATS_MODE.FINAL)
  }

  function onPlayerSpawn()
  {
    if (!this.isSelfTogglable || this.isMissionFinished)
      return
    this.spawnStartState = this.getState()
    ::u.appendOnce(getTblValue("aircraftName", this.spawnStartState.player), this.hero.units)
    this.show(false)
  }

  function onPlayerDeath()
  {
    if (!this.isSelfTogglable || this.isMissionFinished)
      return
    this.show(true, LIVE_STATS_MODE.SPAWN)
  }
}

::g_script_reloader.registerPersistentDataFromRoot("g_hud_live_stats")
