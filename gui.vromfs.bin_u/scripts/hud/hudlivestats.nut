let time = require("scripts/time.nut")
let { GO_NONE, GO_WAITING_FOR_RESULT } = require_native("guiMission")
let { MISSION_OBJECTIVE } = require("scripts/missions/missionsUtilsModule.nut")

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
  missionMode = ::GT_VERSUS
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
    [::GT_VERSUS] = {
      [LIVE_STATS_MODE.SPAWN] = [ "captureZone", "damageZone", "missionAliveTime", "kills", "groundKills", "navalKills",
                                  "aiKills", "aiGroundKills", "aiNavalKills", "aiTotalKills", "assists", "score" ],
      [LIVE_STATS_MODE.FINAL] = [ "captureZone", "damageZone", "missionAliveTime", "kills", "groundKills", "navalKills",
                                  "aiKills", "aiGroundKills", "aiNavalKills", "aiTotalKills", "assists", "deaths", "score" ],
      [LIVE_STATS_MODE.WATCH] = [ "name", "score", "captureZone", "damageZone", "missionAliveTime", "kills", "groundKills", "navalKills",
                                  "aiKills", "aiGroundKills", "aiNavalKills", "aiTotalKills", "assists", "deaths" ],
    },
    [::GT_RACE] = {
      [LIVE_STATS_MODE.SPAWN] = [ "rowNo", "raceFinishTime", "raceBestLapTime", "penaltyTime" ],
      [LIVE_STATS_MODE.FINAL] = [ "rowNo", "raceFinishTime", "raceBestLapTime", "penaltyTime", "deaths" ],
      [LIVE_STATS_MODE.WATCH] = [ "rowNo", "name", "raceFinishTime", "raceBestLapTime", "penaltyTime", "deaths" ],
    },
    [::GT_FOOTBALL] = {
      [LIVE_STATS_MODE.SPAWN] = [ "footballGoals", "footballAssists", "footballScore" ],
      [LIVE_STATS_MODE.FINAL] = [ "footballGoals", "footballAssists", "footballScore" ],
      [LIVE_STATS_MODE.WATCH] = [ "name", "footballGoals", "footballAssists", "footballScore" ],
    },
  }
  function init(_parentObj, _nestObjId, _isSelfTogglable)
  {
    if (!::has_feature("LiveStats"))
      return
    if (!::checkObj(_parentObj))
      return
    parentObj = _parentObj
    nestObjId = _nestObjId
    guiScene  = parentObj.getScene()

    isSelfTogglable = _isSelfTogglable
    gameType = ::get_game_type()
    missionMode =
        (gameType & ::GT_RACE) ? ::GT_RACE
      : (gameType & ::GT_FOOTBALL) ? ::GT_FOOTBALL
      : ::GT_VERSUS
    isMissionTeamplay = ::is_mode_with_teams(gameType)
    isMissionRace = !!(gameType & ::GT_RACE)
    isMissionFinished = false
    missionResult = null
    missionObjectives = ::g_mission_type.getCurrentObjectives()
    isMissionLastManStanding = !!(gameType & ::GT_LAST_MAN_STANDING)

    show(false)

    hero = {
      streaks = []
      units   = []
    }

    if (!isInitialized)
    {
      ::add_event_listener("StreakArrived", onEventStreakArrived, this)
      isInitialized = true
    }

    if (isSelfTogglable)
    {
      isAwaitingSpawn = true

      ::g_hud_event_manager.subscribe("MissionResult", onMissionResult, this)
      ::g_hud_event_manager.subscribe("LocalPlayerAlive", function (data) {
        checkPlayerSpawned()
      }, this)
      ::g_hud_event_manager.subscribe("LocalPlayerDead", function (data) {
        checkPlayerDead()
      }, this)
    }

    reinit()
  }

  function reinit()
  {
    let _scene = ::checkObj(parentObj) ? parentObj.findObject(nestObjId) : null
    if (!::checkObj(_scene))
      return

    isSwitchScene = !::u.isEqual(scene, _scene)
    scene = _scene

    checkPlayerSpawned()
    checkPlayerDead()
  }

  function getState(playerId = null, diffState = null)
  {
    let now = ::get_usefull_total_time()
    let isHero = playerId == null
    let player = isHero ? ::get_local_mplayer() : ::get_mplayer_by_id(playerId)

    let state = {
      player    = player || {}
      streaks   = isHero ? (clone hero.streaks) : []
      timestamp = now
      lifetime  = 0.0
    }

    if (isMissionRace && missionResult != GO_WAITING_FOR_RESULT)
      state.player["rowNo"] <- getPlayerPlaceInTeam(state.player)

    foreach (id in curColumnsOrder)
      if (!(id in state.player))
        state.player[id] <- ::g_mplayer_param_type.getTypeById(id).getVal(state.player)

    if (diffState)
    {
      let p1 = diffState.player
      let p2 = state.player
      foreach (id in curColumnsOrder)
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
    return isSelfTogglable && isActive
  }

  function show(activate, viewMode = null, playerId = null)
  {
    let isSceneValid = ::check_obj(scene)
    activate = activate && isSceneValid
    let isVisibilityToggle = isSelfTogglable && isActive != activate
    isActive = activate

    if (isSceneValid)
    {
      scene.show(isActive)

      curViewPlayerId = playerId
      curViewMode = (viewMode != null && viewMode >= 0 && viewMode < LIVE_STATS_MODE.TOTAL) ?
        viewMode : LIVE_STATS_MODE.WATCH
      curColumnsOrder = ::getTblValue(curViewMode, ::getTblValue(missionMode, columnsOrder, {}), [])

      let misObjs = missionObjectives
      let gt = gameType
      curColumnsOrder = ::u.filter(curColumnsOrder, @(id)
        ::g_mplayer_param_type.getTypeById(id).isVisible(misObjs, gt, ::get_game_mode()))

      fill()
    }

    if (isVisibilityToggle)
      ::g_hud_event_manager.onHudEvent("LiveStatsVisibilityToggled", { visible = isActive })
  }

  function fill()
  {
    if (!::checkObj(scene))
      return

    if (!isActive)
    {
      guiScene.replaceContentFromText(scene, "", 0, this)
      return
    }

    let isCompareStates = curViewMode == LIVE_STATS_MODE.SPAWN
    let state = getState(curViewPlayerId, isCompareStates ? spawnStartState : null)

    local title = ""
    if (curViewMode == LIVE_STATS_MODE.WATCH || missionResult == GO_WAITING_FOR_RESULT)
      title = ""
    else if (curViewMode == LIVE_STATS_MODE.SPAWN && !isMissionLastManStanding)
    {
      let txtUnitName = ::getUnitName(::getTblValue("aircraftName", state.player, ""))
      let txtLifetime = time.secondsToString(state.lifetime, true)
      title = ::loc("multiplayer/lifetime") + ::loc("ui/parentheses/space", { text = txtUnitName }) + ::loc("ui/colon") + txtLifetime
    }
    else if (curViewMode == LIVE_STATS_MODE.FINAL || isMissionLastManStanding)
    {
      title = isMissionTeamplay ? ::loc("debriefing/placeInMyTeam") :
        (::loc("mainmenu/btnMyPlace") + ::loc("ui/colon"))
      title += ::colorize("userlogColoredText", ::getTblValue("rowNo", state.player, getPlayerPlaceInTeam(state.player)))
    }

    let isHeader = curViewMode == LIVE_STATS_MODE.FINAL

    let view = {
      title = title
      isHeader = isHeader
      player = []
      lifetime = isCompareStates && !isMissionLastManStanding
    }

    foreach (id in curColumnsOrder)
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

    if (curViewMode == LIVE_STATS_MODE.FINAL)
    {
      let unitNames = []
      foreach (unitId in hero.units)
        unitNames.append(::getUnitName(unitId))
      view["units"] <- ::loc("mainmenu/btnUnits") + ::loc("ui/colon") +
        ::g_string.implode(unitNames, ::loc("ui/comma"))
    }

    let template = isSelfTogglable ? "%gui/hud/hudLiveStats" : "%gui/hud/hudLiveStatsSpectator"
    let markup = ::handyman.renderCached(template, view)
    guiScene.replaceContentFromText(scene, markup, markup.len(), this)

    let timerObj = scene.findObject("update_timer")
    if (::checkObj(timerObj))
      timerObj.setUserData(this)

    visState = null
    update(null, 0.0)
  }

  function update(o = null, dt = 0.0)
  {
    if (!isActive || !::checkObj(scene))
      return

    let isCompareStates = curViewMode == LIVE_STATS_MODE.SPAWN
    let state = getState(curViewPlayerId, isCompareStates ? spawnStartState : null)

    foreach (id in curColumnsOrder)
    {
      let param = ::g_mplayer_param_type.getTypeById(id)

      let value = ::getTblValue(id, state.player, param.defVal)
      let visValue = visState ? ::getTblValue(id, visState.player, param.defVal) : param.defVal
      if (visValue == value && !param.isForceUpdate)
        continue

      let isValid = value != param.defVal || param.isForceUpdate
      let text = isValid ? param.printFunc(value, state.player) : ""
      let doShow = text != ""

      let plateObj = scene.findObject("plate_" + id)
      if (::checkObj(plateObj) && plateObj.isVisible() != doShow)
        plateObj.show(doShow)

      local txtObj = scene.findObject("txt_" + id)
      if (::checkObj(txtObj) && txtObj.getValue() != text)
        txtObj.setValue(text)

      let lableName = param.getName(value)
      plateObj["tooltip"] = lableName
      txtObj = scene.findObject($"lable_{id}")
      if (::checkObj(txtObj) && txtObj.getValue() != lableName)
        txtObj.setValue(lableName)
    }

    if (isCompareStates && (!visState || visState.lifetime != state.lifetime) && !isMissionLastManStanding)
    {
      let text = time.secondsToString(state.lifetime, true)
      let obj = scene.findObject("txt_lifetime")
      if (::checkObj(obj) && obj.getValue() != text)
        obj.setValue(text)
    }

    let visStreaksLen = visState ? visState.streaks.len() : 0
    if (state.streaks.len() != visStreaksLen)
    {
      let obj = scene.findObject("hero_streaks")
      if (::checkObj(obj))
      {
        local awardsList = []
        foreach (id in state.streaks)
          awardsList.append({unlockType = ::UNLOCKABLE_STREAK, unlockId = id})
        awardsList = ::combineSimilarAwards(awardsList)

        let view = { awards = [] }
        foreach (award in awardsList)
          view.awards.append({
            iconLayers = ::LayersIcon.getIconData("streak_" + award.unlockId)
            amount = award.amount > 1 ? "x" + award.amount : null
          })
        let markup = ::handyman.renderCached(("%gui/statistics/statAwardIcon"), view)
        guiScene.replaceContentFromText(obj, markup, markup.len(), this)
      }
    }

    visState = state
  }

  function isValid()
  {
    return true
  }

  function getPlayerPlaceInTeam(player)
  {
    let playerId = ::getTblValue("id", player, -1)
    let teamId = isMissionTeamplay ? ::getTblValue("team", player, ::GET_MPLAYERS_LIST) : ::GET_MPLAYERS_LIST
    let players = ::get_mplayers_list(teamId, true)

    players.sort(::mpstat_get_sort_func(gameType))

    foreach (idx, p in players)
      if (::getTblValue("id", p) == playerId)
        return idx + 1
    return 0
  }

  function checkPlayerSpawned()
  {
    if (!isAwaitingSpawn)
      return
    let player = ::get_local_mplayer()
    if (player.isDead || player.state != ::PLAYER_IN_FLIGHT)
      return
    let aircraftName = ::getTblValue("aircraftName", player, "")
    if (aircraftName == "" || aircraftName == "dummy_plane")
      return
    isAwaitingSpawn = false
    onPlayerSpawn()
  }

  function checkPlayerDead()
  {
    if (isAwaitingSpawn && !isSwitchScene)
      return
    if (!hero.units.len())
      return
    let player = ::get_local_mplayer()
    if (player.isTemporary)
      return
    if (!player.isDead)
      return
    isAwaitingSpawn = true
    onPlayerDeath()
  }

  function onEventStreakArrived(params)
  {
    hero.streaks.append(::getTblValue("id", params))
  }

  function onMissionResult(eventData)
  {
    if (!isSelfTogglable || isMissionFinished)
      return
    isMissionFinished = true
    missionResult = eventData?.resultNum ?? GO_NONE
    show(true, LIVE_STATS_MODE.FINAL)
  }

  function onPlayerSpawn()
  {
    if (!isSelfTogglable || isMissionFinished)
      return
    spawnStartState = getState()
    ::u.appendOnce(::getTblValue("aircraftName", spawnStartState.player), hero.units)
    show(false)
  }

  function onPlayerDeath()
  {
    if (!isSelfTogglable || isMissionFinished)
      return
    show(true, LIVE_STATS_MODE.SPAWN)
  }
}

::g_script_reloader.registerPersistentDataFromRoot("g_hud_live_stats")
