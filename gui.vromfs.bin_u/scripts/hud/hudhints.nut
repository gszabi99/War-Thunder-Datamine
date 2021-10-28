local enums = require("sqStdLibs/helpers/enums.nut")
local time = require("scripts/time.nut")
local { is_stereo_mode } = ::require_native("vr")
local { getPlayerCurUnit } = require("scripts/slotbar/playerCurUnit.nut")

const DEFAULT_MISSION_HINT_PRIORITY = 100
const CATASTROPHIC_HINT_PRIORITY = 0

local animTimerPid = ::dagui_propid.add_name_id("_transp-timer")

enum MISSION_HINT_TYPE {
  STANDARD   = "standard"
  TUTORIAL   = "tutorialHint"
  BOTTOM     = "bottom"
}

global enum HINT_INTERVAL {
  ALWAYS_VISIBLE = 0
  HIDDEN = -1
}

::g_hud_hints <- {
  types = []
  cache = { byName = {} }
}

g_hud_hints._buildMarkup <- function _buildMarkup(eventData, hintObjId)
{
  return ::g_hints.buildHintMarkup(buildText(eventData), getHintMarkupParams(eventData, hintObjId))
}

g_hud_hints._getHintMarkupParams <- function _getHintMarkupParams(eventData, hintObjId)
{
  return {
    id = hintObjId || name
    style = getHintStyle()
    time = getTimerTotalTimeSec(eventData)
    timeoffset = getTimerCurrentTimeSec(eventData, ::dagor.getCurTime()) //creation time right now
    animation = shouldBlink ? "wink" : shouldFadeOut ? "show" : null
    showKeyBoardShortcutsForMouseAim = eventData?.showKeyBoardShortcutsForMouseAim ?? false
  }
}

local getRawShortcutsArray = function(shortcuts)
{
  if(!shortcuts)
    return []
  local rawShortcutsArray = ::u.isArray(shortcuts) ? shortcuts : [shortcuts]
  local shouldPickOne = ::g_hud_hints.shouldPickFirstValid(rawShortcutsArray)
  if (shouldPickOne)
  {
    local rawShortcut = ::g_hud_hints.pickFirstValidShortcut(rawShortcutsArray)
    rawShortcutsArray = rawShortcut != null ? [rawShortcut] : []
  }
  else
    rawShortcutsArray = ::g_hud_hints.removeUnmappedShortcuts(rawShortcutsArray)
  return rawShortcutsArray
}

g_hud_hints._buildText <- function _buildText(data)
{
  local shortcuts = getShortcuts(data)
  if (shortcuts == null)
  {
    local res = ::loc(getLocId(data), getLocParams(data))
    if (image)
      res = ::g_hint_tag.IMAGE.makeFullTag({ image = image }) + res
    return res
  }

  local rawShortcutsArray = getRawShortcutsArray(shortcuts)
  local assigned = rawShortcutsArray.len() > 0
  if (!assigned)
  {
    local noKeyLocId = getNoKeyLocId()
    if (noKeyLocId != "")
      return ::loc(noKeyLocId)
  }

  local expandedShortcutArray = ::g_shortcut_type.expandShortcuts(rawShortcutsArray)
  local shortcutTag = ::g_hud_hints._wrapShortsCutIdWithTags(expandedShortcutArray)
  local locParams = getLocParams(data).__update({shortcut = shortcutTag})
  local result = ::loc(getLocId(data), locParams)

  //If shortcut not specified in localization string it should
  //be placed at the beginig
  if (shortcutTag != "" && result.indexof(shortcutTag) == null)
    result = $"{shortcutTag} {result}"

  return result
}

/**
 * Return true if only one shortcut should be picked from @shortcutArray
 */
g_hud_hints.shouldPickFirstValid <- function shouldPickFirstValid(shortcutArray)
{
  foreach (shortcutId in shortcutArray)
    if (::g_string.startsWith(shortcutId, "@"))
      return true
  return false
}

g_hud_hints.pickFirstValidShortcut <- function pickFirstValidShortcut(shortcutArray)
{
  foreach (shortcutId in shortcutArray)
  {
    local localShortcutId = shortcutId //to avoid changes in original array
    if (::g_string.startsWith(localShortcutId, "@"))
      localShortcutId = localShortcutId.slice(1)
    local shortcutType = ::g_shortcut_type.getShortcutTypeByShortcutId(localShortcutId)
    if (shortcutType.isAssigned(localShortcutId))
      return localShortcutId
  }

  return null
}

g_hud_hints.removeUnmappedShortcuts <- function removeUnmappedShortcuts(shortcutArray)
{
  for (local i = shortcutArray.len() - 1; i >= 0; --i)
  {
    local shortcutType = ::g_shortcut_type.getShortcutTypeByShortcutId(shortcutArray[i])
    if (!shortcutType.isAssigned(shortcutArray[i]))
      shortcutArray.remove(i)
  }

  return shortcutArray
}

g_hud_hints._getLocId <- function _getLocId(data)
{
  return locId
}

g_hud_hints._getNoKeyLocId <- function _getNoKeyLocId()
{
  return noKeyLocId
}

g_hud_hints._getLifeTime <- function _getLifeTime(data)
{
  return lifeTime || ::getTblValue("lifeTime", data, 0)
}

g_hud_hints._getShortcuts <- function _getShortcuts(data)
{
  return shortcuts
}

g_hud_hints._wrapShortsCutIdWithTags <- function _wrapShortsCutIdWithTags(shortNamesArray)
{
  local result = ""
  local separator = ::loc("hints/shortcut_separator")
  foreach (shortcutName in shortNamesArray)
  {
    if (result.len())
      result += separator

    result += ::g_hints.hintTags[0] + shortcutName + ::g_hints.hintTags[1]
  }
  return result
}

g_hud_hints._getHintNestId <- function _getHintNestId()
{
  return hintType.nestId
}

g_hud_hints._getHintStyle <- function _getHintStyle()
{
  return hintType.hintStyle
}

//all obsolette hinttype names must work as standard mission hint
local isStandardMissionHint = @(hintTypeName)
  hintTypeName != MISSION_HINT_TYPE.TUTORIAL && hintTypeName != MISSION_HINT_TYPE.BOTTOM

local genMissionHint = @(hintType, checkHintTypeNameFunc)
{
  hintType = hintType
  showEvent = "hint:missionHint:set"
  hideEvent = "hint:missionHint:remove"
  selfRemove = true

  _missionTimerTotalMsec = 0
  _missionTimerStartMsec = 0

  updateCbs = {
    ["mission:timer:start"] = function(hintData, eventData)
    {
      local totalSec = ::getTblValue("totalTime", eventData)
      if (!totalSec)
        return false

      _missionTimerTotalMsec = 1000 * totalSec
      _missionTimerStartMsec = ::dagor.getCurTime()
      return true
    },
    ["mission:timer:stop"] = function(hintData, eventData) {
      _missionTimerTotalMsec = 0
      return true
    }
  }

  isCurrent = function(eventData, isHideEvent)
  {
    if (isHideEvent && !("hintType" in eventData))
      return true
    return checkHintTypeNameFunc(::getTblValue("hintType", eventData, MISSION_HINT_TYPE.STANDARD))
  }

  getLocId = function (hintData)
  {
    return ::getTblValue("locId", hintData, "")
  }

  getShortcuts = function (hintData)
  {
    return ::getTblValue("shortcuts", hintData)
  }

  buildText = function (hintData) {
    local res = ::g_hud_hints._buildText.call(this, hintData)
    local varValue = ::getTblValue("variable_value", hintData)
    if (varValue != null)
    {
      local varStyle = ::getTblValue("variable_style", hintData)
      if (varStyle == "playerId")
      {
        local player = ::get_mplayer_by_id(varValue)
        varValue = ::build_mplayer_name(player)
      }
      res = ::loc(res, {var = varValue})
    }
    if (!getShortcuts(hintData))
      return res
    res = ::g_hint_tag.TIMER.makeFullTag() + " " + res
    return res
  }

  getHintMarkupParams = function(eventData, hintObjId)
  {
    local res = ::g_hud_hints._getHintMarkupParams.call(this, eventData, hintObjId)
    res.hideWhenStopped <- true
    res.timerOffsetX <- "-w" //to timer do not affect message position.
    res.isOrderPopup <- ::getTblValue("isOverFade", eventData, false)

    res.animation <- ::getTblValue("shouldBlink", eventData, false) ? "wink"
      : ::getTblValue("shouldFadeout", eventData, false) ? "show"
      : null
    return res
  }

  getTimerTotalTimeSec = function(eventData)
  {
    if (_missionTimerTotalMsec <= 0
        || (::dagor.getCurTime() > _missionTimerTotalMsec + _missionTimerStartMsec))
      return 0
    return time.millisecondsToSeconds(_missionTimerTotalMsec)
  }
  getTimerCurrentTimeSec = function(eventData, hintAddTime)
  {
    return time.millisecondsToSeconds(::dagor.getCurTime() - _missionTimerStartMsec)
  }

  getLifeTime = @(eventData) ::getTblValue("time", eventData, 0)

  isInstantHide = @(eventData) !::getTblValue("shouldFadeout", eventData, true)
  hideHint = function(hintObject, isInstant)
  {
    if (isInstant)
      hintObject.getScene().destroyElement(hintObject)
    else
    {
      hintObject.animation = "hide"
      hintObject.selfRemoveOnFinish = "-1"
      hintObject.setFloatProp(animTimerPid, 1.0)
    }
    return !isInstant
  }
  isHideOnWatchedHeroChanged = false
  isShowedInVR = true
}

::g_hud_hints.template <- {
  name = "" //generated by typeName. Used as id in hud scene.
  typeName = "" //filled by typeName
  locId = ""
  noKeyLocId = ""
  image = null //used only when no shortcuts
  hintType = ::g_hud_hint_types.COMMON
  priority = 0

  getHintNestId = ::g_hud_hints._getHintNestId
  getHintStyle = ::g_hud_hints._getHintStyle

  getLocId = ::g_hud_hints._getLocId
  getNoKeyLocId = ::g_hud_hints._getNoKeyLocId

  getLocParams = @(hintData) {}

  getPriority = function(eventData) { return ::getTblValue("priority", eventData, priority) }
  isCurrent = @(eventData, isHideEvent) true

  //Some hints contain shortcuts. If there is only one shortuc in hint (common case)
  //just put shirtcut id in shortcuts field.
  //If there is more then one shortuc, the should be representd as table.
  //shortcut table format: {
  //  locArgumentName = shortcutid
  //}
  //locArgument will be used as wildcard id for locization text
  shortcuts = null
  getShortcuts          = ::g_hud_hints._getShortcuts
  buildMarkup           = ::g_hud_hints._buildMarkup
  buildText             = ::g_hud_hints._buildText
  getHintMarkupParams   = ::g_hud_hints._getHintMarkupParams
  getLifeTime           = ::g_hud_hints._getLifeTime
  isEnabledByDifficulty = @() !isAllowedByDiff || (isAllowedByDiff?[::get_mission_difficulty()] ?? true)

  selfRemove = false //will be true if lifeTime > 0
  lifeTime = 0.0
  getTimerTotalTimeSec    = function(eventData) { return getLifeTime(eventData) }
  getTimerCurrentTimeSec  = function(eventData, hintAddTime)
  {
    return time.millisecondsToSeconds(::dagor.getCurTime() - hintAddTime)
  }

  isInstantHide = @(eventData) true
  hideHint = function(hintObject, isInstant)  //return <need to instant hide when new hint appear>
  {
    hintObject.getScene().destroyElement(hintObject)
    return false
  }
  isHideOnDeath = true
  isHideOnWatchedHeroChanged = true

  showEvent = null
  hideEvent = null
  updateCbs = null //{ <hudEventName> = function(hintData, eventData) { return <needUpdate (bool)>} } //hintData can be null

  countIntervals = null // for example [{count = 5, timeInterval = 60.0 }, { ... }, ...]
  delayTime = 0.0
  isAllowedByDiff  = null
  totalCount = -1
  missionCount = -1
  maskId = -1
  mask = 0

  isShowedInVR = false

  shouldBlink = false
  shouldFadeOut = false
  isSingleInNest = false

  isEnabled = @() (isShowedInVR || !is_stereo_mode())
    && ::is_hint_enabled(mask)
    && isEnabledByDifficulty()

  getTimeInterval = function()
  {
    if (!countIntervals)
      return HINT_INTERVAL.ALWAYS_VISIBLE

    local interval = HINT_INTERVAL.HIDDEN
    local count = ::get_hint_seen_count(maskId)
    foreach(countInterval in countIntervals)
      if (!countInterval?.count || count < countInterval.count)
      {
        interval = countInterval.timeInterval
        break
      }
    return interval
  }

  updateHintOptionsBlk = function(blk) {} //special options for native hints
}

enums.addTypesByGlobalName("g_hud_hints", {
  UNKNOWN = {}

  OFFER_BAILOUT = {
    getLocId = function(hintData)
    {
      local curUnit = getPlayerCurUnit()
      return curUnit?.isHelicopter?() ? "hints/ready_to_bailout_helicopter"
      : "hints/ready_to_bailout"
    }
    getNoKeyLocId = function()
    {
      local curUnit = getPlayerCurUnit()
      return curUnit?.isHelicopter?() ? "hints/ready_to_bailout_helicopter_nokey"
      : "hints/ready_to_bailout_nokey"
    }
    shortcuts = "ID_BAILOUT"

    showEvent = "hint:bailout:offerBailout"
    hideEvent = ["hint:bailout:startBailout", "hint:bailout:notBailouts"]
  }

  START_BAILOUT = {
    nearestOffenderLocId = "HUD_AWARD_NEAREST"
    awardGiveForLocId = "HUD_AWARD_GIVEN_FOR"

    getLocId = function (hintData)
    {
      local curUnit = getPlayerCurUnit()
      return curUnit?.isHelicopter?() ? "hints/bailout_helicopter_in_progress"
        : curUnit?.isAir?() ? "hints/bailout_in_progress"
        : "hints/leaving_the_tank_in_progress" //this localization is more general, then the "air" one
    }

    showEvent = "hint:bailout:startBailout"
    hideEvent = ["hint:bailout:offerBailout", "hint:bailout:notBailouts"]

    selfRemove = true
    buildText = function (data) {
      local res = ::g_hud_hints._buildText.call(this, data)
      res += " " + ::g_hint_tag.TIMER.makeFullTag()
      local leaveKill = ::getTblValue("leaveKill", data, false)
      if (leaveKill)
        res +=  "\n" + ::loc(nearestOffenderLocId)
      local offenderName = ::getTblValue("offenderName", data, "")
      if (offenderName != "")
        res +=  "\n" + ::loc(awardGiveForLocId) + offenderName
      return res
    }
  }

  SKIP_XRAY_SHOT = {
    hintType = ::g_hud_hint_types.MINOR
    locId = "hints/skip"
    shortcuts = [
      "@ID_CONTINUE_SETUP"
      "@ID_CONTINUE"
    ]
    showEvent = "hint:xrayCamera:showSkipHint"
    hideEvent = "hint:xrayCamera:hideSkipHint"
    isHideOnDeath = false
    isHideOnWatchedHeroChanged = false
  }

  BLOCK_X_RAY_CAMERA = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/x_ray_unavailable"
    showEvent = "hint:xrayCamera:showBlockHint"
    lifeTime = 1.0
    isHideOnDeath = false
    isHideOnWatchedHeroChanged = false
  }


  CREW_BUSY_EXTINGUISHING_HINT = {
    locId      = "hints/crew_busy_extinguishing"
    noKeyLocId = "hints/crew_busy_extinguishing_no_key"
    showEvent = "hint:crew_busy_extinguishing:begin"
    hideEvent = "hint:crew_busy_extinguishing:end"
  }


  EXTINGUISHER_IS_INEFFECTIVE_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/extinguisher_is_ineffective"
    showEvent = "hint:extinguisher_ineffective:show"
    lifeTime = 3.0
  }


  TRACK_REPAIR_HINT = {
    hintType = ::g_hud_hint_types.REPAIR
    locId     = "hints/track_repair"
    showEvent = "hint:track_repair"
    lifeTime = 5.0
  }

  ACTION_NOT_AVAILABLE_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    showEvent = [ "hint:action_not_available",
      //events below are compatibility with 1_75_0_X
      "hint:more_kills_for_kill_streak:show", "hint:needs_kills_streak_event:show", "hint:active_event:show",
      "hint:already_participating:show", "hint:no_event_slots:show"]
    lifeTime = 5.0
    priority = CATASTROPHIC_HINT_PRIORITY

    eventToLocId = { //this table only compatibility with 1_75_0_X
      ["hint:more_kills_for_kill_streak:show"]   = "hints/more_kills_for_kill_streak",
      ["hint:needs_kills_streak_event:show"]     = "hints/needs_kills_streak_event",
      ["hint:active_event:show"]                 = "hints/active_event",
      ["hint:already_participating:show"]        = "hints/already_participating",
      ["hint:no_event_slots:show"]               = "hints/no_event_slots"
    }

    getLocId = @(data) "hintId" in data ? ::loc("hints/" + data.hintId)
      : eventToLocId?[::g_hud_event_manager.getCurHudEventName()] ?? "" //compatibility with 1_75_0_X
  }

  INEFFECTIVE_HIT_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/ineffective_hit"
    showEvent = "hint:ineffective_hit:show"
    lifeTime = 5.0
    priority = CATASTROPHIC_HINT_PRIORITY
    countIntervals = [
      {
        count = 5
        timeInterval = 60.0
      }
      {
        count = 10
        timeInterval = 100000.0 //once per mission
      }
    ]
    maskId = 11
  }

  GUN_JAMMED_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/gun_jammed"
    showEvent = "hint:gun_jammed:show"
    lifeTime = 2.0
    priority = CATASTROPHIC_HINT_PRIORITY
  }

  AUTOTHROTTLE_HINT = {
    locId = "hints/autothrottle"
    showEvent = "hint:autothrottle:show"
    lifeTime = 10.0
    priority = CATASTROPHIC_HINT_PRIORITY
  }

  PILOT_LOSE_CONTROL_HINT = {
    locId = "hints/pilot_lose_control"
    showEvent = "hint:pilot_lose_control:show"
    lifeTime = 10.0
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 20
    maskId = 26
  }

  ATGM_AIM_HINT = {
    hintType = ::g_hud_hint_types.ACTIONBAR
    locId = "hints/atgm_aim"
    showEvent = "hint:atgm_aim:show"
    lifeTime = 10.0
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 5
    maskId = 28
  }

  ATGM_MANUAL_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/atgm_manual"
    showEvent = "hint:atgm_manual:show"
    lifeTime = 10.0
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 5
    maskId = 29
  }

  ATGM_AIM_HINT_TORPEDO = {
    hintType = ::g_hud_hint_types.REPAIR
    locId = "hints/atgm_aim_torpedo"
    showEvent = "hint:atgm_aim_torpedo:show"
    lifeTime = 10.0
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 5
    maskId = 30
  }

  BOMB_AIM_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/bomb_aim"
    showEvent = "hint:bomb_aim:show"
    lifeTime = 10.0
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 5
    maskId = 30
  }

  BOMB_MANUAL_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/bomb_manual"
    showEvent = "hint:bomb_manual:show"
    lifeTime = 10.0
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 5
    maskId = 30
  }

  DEAD_PILOT_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/dead_pilot"
    showEvent = "hint:dead_pilot:show"
    lifeTime = 5.0
    isHideOnDeath = false
    isHideOnWatchedHeroChanged = false
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 20
    maskId = 12
  }

  HAVE_ART_SUPPORT_HINT = {
    hintType = ::g_hud_hint_types.ACTIONBAR
    locId = "hints/have_art_support"
    noKeyLocId = "hints/have_art_support_no_key"
    getShortcuts = @(data) ::g_hud_action_bar_type.ARTILLERY_TARGET.getVisualShortcut()
    showEvent = "hint:have_art_support:show"
    hideEvent = "hint:have_art_support:hide"
    lifeTime = 5.0
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 5
    maskId = 27
  }

  AUTO_REARM_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/auto_rearm"
    showEvent = "hint:auto_rearm:show"
    hideEvent = "hint:auto_rearm:hide"
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 1
    isAllowedByDiff  = {
      [::g_difficulty.REALISTIC.name] = false,
      [::g_difficulty.SIMULATOR.name] = false
    }
    maskId = 9
  }

  WINCH_REQUEST_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/winch_request"
    noKeyLocId = "hints/winch_request_no_key"
    showEvent = "hint:winch_request:show"
    hideEvent = "hint:winch_request:hide"
    priority = DEFAULT_MISSION_HINT_PRIORITY
    getShortcuts = @(data) ::g_hud_action_bar_type.WINCH.getVisualShortcut()
    lifeTime = 10.0
    delayTime = 4.0
  }

  FOOTBALL_JUMP_REQUEST = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "HUD/TXT_FOOTBALL_JUMP_REQUEST"
    showEvent = "hint:football_jump_request:show"
    hideEvent = "hint:football_jump_request:hide"
    priority = DEFAULT_MISSION_HINT_PRIORITY
    shortcuts = "ID_FIRE_GM"
    lifeTime = 3.0
    delayTime = 2.0
  }

  WINCH_USE_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/winch_use"
    noKeyLocId = "hints/winch_use_no_key"
    showEvent = "hint:winch_use:show"
    hideEvent = "hint:winch_use:hide"
    priority = DEFAULT_MISSION_HINT_PRIORITY
    getShortcuts = @(data) ::g_hud_action_bar_type.WINCH_ATTACH.getVisualShortcut()
    lifeTime = 10.0
    delayTime = 2.0
  }

  WINCH_DETACH_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/winch_detach"
    noKeyLocId = "hints/winch_detach_no_key"
    showEvent = "hint:winch_detach:show"
    hideEvent = "hint:winch_detach:hide"
    priority = DEFAULT_MISSION_HINT_PRIORITY
    getShortcuts = @(data) ::g_hud_action_bar_type.WINCH_DETACH.getVisualShortcut()
    lifeTime = 10.0
    delayTime = 4.0
  }

  F1_CONTROLS_HINT = {
    hintType = ::g_hud_hint_types.ACTIONBAR
    locId = "hints/f1_controls"
    showEvent = "hint:f1_controls:show"
    hideEvent = "helpOpened"
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 3
    lifeTime = 5.0
    delayTime = 10.0
    maskId = 0
  }

  F1_CONTROLS_HINT_SCRIPTED = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/help_controls"
    noKeyLocId = "hints/help_controls/nokey"
    shortcuts = "ID_HELP"
    showEvent = "hint:f1_controls_scripted:show"
    hideEvent = "helpOpened"
    lifeTime = 30.0
  }

  FULL_THROTTLE_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/full_throttle"
    showEvent = "hint:full_throttle:show"
    hideEvent = "hint:full_throttle:hide"
    priority = CATASTROPHIC_HINT_PRIORITY
    lifeTime = 5.0
    delayTime = 10.0
    countIntervals = [{
      timeInterval = 30.0
    }]
    maskId = 7
  }

  DISCONNECT_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/disconnect"
    showEvent = "hint:disconnect:show"
    hideEvent = "hint:disconnect:hide"
    priority = CATASTROPHIC_HINT_PRIORITY
    lifeTime = 5.0
    delayTime = 3600.0
    countIntervals = [{
      timeInterval = 20.0
    }]
    maskId = 8
  }

  SHOT_TOO_FAR_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/shot_too_far"
    showEvent = "hint:shot_too_far:show"
    hideEvent = "hint:shot_too_far:hide"
    priority = CATASTROPHIC_HINT_PRIORITY
    countIntervals = [
      {
        count = 5
        timeInterval = 60.0
      }
      {
        count = 10
        timeInterval = 100000.0 //once per mission
      }
    ]
    lifeTime = 5.0
    delayTime = 5.0
    maskId = 10

    updateHintOptionsBlk = function(blk) {
       //float params only.
       blk.shotTooFarMaxAngle = 5.0
       blk.shotTooFarDistanceFactor = 21.5
    }
  }

  SHOT_FORESTALL_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/shot_forestall"
    showEvent = "hint:shot_forestall:show"
    hideEvent = "hint:shot_forestall:hide"
    priority = CATASTROPHIC_HINT_PRIORITY
    countIntervals = [
      {
        count = 5
        timeInterval = 60.0
      }
      {
        count = 10
        timeInterval = 100000.0 //once per mission
      }
    ]
    isAllowedByDiff  = {
      [::g_difficulty.SIMULATOR.name] = false
    }
    lifeTime = 5.0
    delayTime = 5.0
    maskId = 10

    updateHintOptionsBlk = function(blk) {
      //float params only
      blk.forestallMaxTargetAngle = 2.0
      blk.forestallMaxAngle = 4.0
    }
  }

  PARTIAL_DOWNLOAD = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/partial_download"
    showEvent = "hint:partial_download:show"
    priority = CATASTROPHIC_HINT_PRIORITY
    lifeTime = 5.0
  }

  EXTINGUISH_FIRE_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/extinguish_fire"
    noKeyLocId = "hints/extinguish_fire_nokey"
    getShortcuts = @(data) ::g_hud_action_bar_type.EXTINGUISHER.getVisualShortcut()
    showEvent = "hint:extinguish_fire:show"
    hideEvent = "hint:extinguish_fire:hide"
    shouldBlink = true
  }

  CRITICAL_BUOYANCY_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/critical_buoyancy"
    noKeyLocId = "hints/critical_buoyancy_nokey"
    shortcuts = "ID_REPAIR_BREACHES"
    showEvent = "hint:critical_buoyancy:show"
    hideEvent = "hint:critical_buoyancy:hide"
    shouldBlink = true
  }

  SHIP_BROKEN_GUNS_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/ship_broken_gun"
    showEvent = "hint:ship_broken_gun:show"
    hideEvent = "hint:ship_broken_gun:hide"
  }

  CRITICAL_HEALING_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/critical_heeling"
    noKeyLocId = "hints/critical_heeling_nokey"
    shortcuts = "ID_REPAIR_BREACHES"
    showEvent = "hint:critical_heeling:show"
    hideEvent = "hint:critical_heeling:hide"
    shouldBlink = true
  }

  MOVE_SUSPENSION_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/move_suspension"
    noKeyLocId = "hints/move_suspension_nokey"
    shortcuts = "ID_SUSPENSION_RESET"
    showEvent = "hint:move_suspension:show"
    hideEvent = "hint:move_suspension:hide"
    shouldBlink = true
  }

  MOVE_SUSPENSION_ZERO_VEL_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/move_suspension_zero_vel"
    noKeyLocId = "hints/move_suspension_zero_vel_nokey"
    shortcuts = "ID_SUSPENSION_RESET"
    showEvent = "hint:move_suspension_zero_vel:show"
    hideEvent = "hint:move_suspension_zero_vel:hide"
    shouldBlink = true
  }

  MOVE_SUSPENSION_BLOCKED_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/move_suspension_blocked"
    showEvent = "hint:move_suspension_blocked"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  YOU_CAN_EXIT_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/you_can_exit"
    noKeyLocId = "hints/you_can_exit_nokey"
    shortcuts = "ID_BAILOUT"
    showEvent = "hint:you_can_exit:show"
    hideEvent = "hint:you_can_exit:hide"
    shouldBlink = true
  }

  ARTILLERY_MAP_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "HUD/TXT_ARTILLERY_MAP"
    noKeyLocId = "HUD/TXT_ARTILLERY_MAP_NOKEY"
    shortcuts = "ID_CHANGE_ARTILLERY_TARGETING_MODE"
    showEvent = "hint:artillery_map:show"
    hideEvent = "hint:artillery_map:hide"
    shouldBlink = true
    delayTime = 1.0
  }

  USE_ARTILLERY_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/use_artillery"
    noKeyLocId = "hints/use_artillery_no_key"
    shortcuts = "ID_SHOOT_ARTILLERY"
    showEvent = "hint:artillery_map:show"
    hideEvent = "hint:artillery_map:hide"
    lifeTime = 5.0
    totalCount = 5
    maskId = 15
  }

  PRESS_A_TO_CONTINUE_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "HUD_PRESS_A_CNT"
    noKeyLocId = "HUD_PRESS_A_CNT"
    shortcuts = [
      "@ID_CONTINUE_SETUP"
      "@ID_CONTINUE"
      "@ID_FIRE"
    ]
    showEvent = "hint:press_a_continue:show"
    hideEvent = "hint:press_a_continue:hide"
    buildText = function(eventData)
    {
      local res = ::g_hud_hints._buildText.call(this, eventData)
      local timer = eventData?.timer
      if (timer)
        res += " (" + timer + ")"
      return res
    }
  }

  RELOAD_ON_AIRFIELD_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/reload_on_airfield"
    noKeyLocId = "hints/reload_on_airfield_nokey"
    shortcuts = "ID_RELOAD_GUNS"
    showEvent = "hint:reload_on_airfield:show"
    hideEvent = "hint:reload_on_airfield:hide"
    shouldBlink = true
  }

  EVENT_START_HINT = {
    hintType = ::g_hud_hint_types.ACTIONBAR
    showEvent = "hint:event_start_time:show"
    hideEvent = "hint:event_start_time:hide"
    getShortcuts = @(eventData) eventData?.shortcut

    makeSmallImageStr = @(image, color = null, sizeStyle = null) ::g_hint_tag.IMAGE.makeFullTag({
      image = image
      color = color
      sizeStyle = sizeStyle
    })

    buildText = function(eventData)
    {
      local res = ::g_hud_hints._buildText.call(this, eventData)
      local rawShortcutsArray = getRawShortcutsArray(getShortcuts(eventData))
      local player = "playerId" in eventData ? ::get_mplayer_by_id(eventData.playerId) : null
      local locId = eventData?.locId ?? ""
      if (!rawShortcutsArray.len())
        locId = eventData?.noKeyLocId ?? locId

      res += ::loc(locId, {
        player = player ? ::build_mplayer_name(player) : ""
        time = time.secondsToString(eventData?.timeSeconds ?? 0, true, true)
      })

      local participantsAStr = ""
      local participantsBStr = ""
      local reservedSlotsCountA = 0
      local reservedSlotsCountB = 0
      local totalSlotsPerCommand = eventData?.slotsCount ?? 0
      local spaceStr = "          "

      local participantList = []
      if(eventData?.participant)
        participantList = ::u.isArray(eventData.participant) ? eventData.participant : [eventData.participant]

      local playerTeam = ::get_local_team_for_mpstats()
      foreach (participant in participantList)
      {
        local  participantPlayer = (participant?.participantId ?? -1) >= 0 ? ::get_mplayer_by_id(participant.participantId) : null
        if (!(participant?.image && participantPlayer))
          continue

        local icon = "#ui/gameuiskin#" + participant.image
        local color = "@" + ::get_mplayer_color(participantPlayer)
        local pStr = makeSmallImageStr(icon, color)
        if (playerTeam == participantPlayer.team)
        {
          participantsAStr += pStr + " "
          ++reservedSlotsCountA
        }
        else
        {
          participantsBStr = " " + pStr + participantsBStr
          ++reservedSlotsCountB
        }
      }

      local freeSlotIconName = "#ui/gameuiskin#btn_help.svg"
      local freeSlotIconColor = "@minorTextColor"
      local freeSlotIconStr = makeSmallImageStr(freeSlotIconName, freeSlotIconColor, "small")
      for(local i = 0; i < totalSlotsPerCommand - reservedSlotsCountA; ++i)
        participantsAStr += freeSlotIconStr + " "

      for(local i = 0; i < totalSlotsPerCommand - reservedSlotsCountB; ++i)
        participantsBStr = " " + freeSlotIconStr + participantsBStr

      if (participantsAStr.len() > 0 && participantsBStr.len() > 0)
        res = participantsAStr
        + spaceStr + ::loc("country/VS").tolower() + spaceStr
        + participantsBStr
        + "\n" + res

      return res
    }
  }

  UI_MESSAGE_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    showEvent = "hint:ui_message:show"
    lifeTime = 3.0
    buildText = function(eventData)
    {
      local res = eventData?.locId
      if (!res)
        return ""
      res = ::loc(res)
      if (eventData?.param)
      {
        local param = eventData.param
        if (eventData?.paramTeamId)
          param = ::colorize(::get_team_color(eventData.paramTeamId), param)
        res = ::format(res, param)
      }
      if (eventData?.teamId && eventData.teamId > 0)
        res = ::colorize(::get_team_color(eventData.teamId), res)
      return res
    }
  }

  RESTORING_IN_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    showEvent = "hint:restoring_in:show"
    hideEvent = "hint:restoring_in:hide"
    buildText = @(eventData) eventData?.text ?? ""
  }

  AVAILABLE_GUNNER_HINT = {
    locId = "hints/manual_change_crew_available_gunner"
    showEvent = "hint:available_gunner:show"
    hideEvent = "hint:available_gunner:hide"
  }

  AVAILABLE_DRIVER_HINT = {
    locId = "hints/manual_change_crew_available_driver"
    showEvent = "hint:available_driver:show"
    hideEvent = "hint:available_driver:hide"
  }

  NECESSARY_GUNNER_HINT = {
    locId = "hints/manual_change_crew_necessary_gunner"
    showEvent = "hint:necessary_gunner:show"
    hideEvent = "hint:necessary_gunner:hide"
  }

  NECESSARY_DRIVER_HINT = {
    locId = "hints/manual_change_crew_necessary_driver"
    showEvent = "hint:necessary_driver:show"
    hideEvent = "hint:necessary_driver:hide"
  }

  DIED_FROM_AMMO_EXPLOSION_HINT = {
    locId = "HUD/TXT_DIED_FROM_AMMO_EXPLOSION"
    showEvent = "hint:died_from_ammo_explosion:show"
    hideEvent = "hint:died_from_ammo_explosion:hide"
    lifeTime = 5.0
  }

  TORPEDO_DEADZONE_HINT = {
    locId = "hints/torpedo_deadzone"
    showEvent = "hint:torpedo_deadzone:show"
    hideEvent = "hint:torpedo_deadzone:hide"
  }

  TORPEDO_BROKEN_HINT = {
    locId = "hints/torpedo_broken"
    showEvent = "hint:torpedo_broken:show"
    hideEvent = "hint:torpedo_broken:hide"
  }

  CRITICAL_LEVEL = {
    locId = "hints/critical_level"
    showEvent = "hint:critical_level:show"
    hideEvent = "hint:critical_level:hide"
  }

  USE_BINOCULAR_SCOUTING = {
    locId = "HUD/TXT_USE_BINOCULAR_SCOUTING"
    showEvent = "hint:use_binocular_scouting"
    lifeTime = 3.0
  }

  FOOTBALL_LOCK_TARGET = {
    locId = "HUD/TXT_FOOTBALL_LOCK_TARGET"
    showEvent = "hint:football_lock_target"
    shortcuts = "ID_TARGETING_HOLD_GM"
    lifeTime = 3.0
  }

  TARGET_BINOCULAR_FOR_SCOUTING = {
    locId = "HUD/TXT_TARGET_BINOCULAR_FOR_SCOUTING"
    showEvent = "hint:target_binocular_for_scouting"
    lifeTime = 3.0
  }

  CHOOSE_TARGET_FOR_SCOUTING = {
    locId = "HUD/TXT_CHOOSE_TARGET_FOR_SCOUTING"
    showEvent = "hint:choose_target_for_scouting"
    lifeTime = 3.0
    shortcuts = "ID_LOCK_TARGET"
    maskId = 14
    totalCount = 10
  }

  CHOOSE_GROUND_TARGET_FOR_SCOUTING = {
    locId = "HUD/TXT_CHOOSE_GROUND_TARGET_FOR_SCOUTING"
    showEvent = "hint:choose_ground_target_for_scouting"
    lifeTime = 3.0
  }

  CHOOSE_ALIVE_TARGET_FOR_SCOUTING = {
    locId = "HUD/TXT_CHOOSE_ALIVE_TARGET_FOR_SCOUTING"
    showEvent = "hint:choose_alive_target_for_scouting"
    lifeTime = 3.0
  }

  TARGET_ALREADY_SCOUTED = {
    locId = "HUD/TXT_TARGET_ALREADY_SCOUTED"
    showEvent = "hint:target_already_scouted"
    lifeTime = 3.0
  }

  MUST_SEE_SCOUTING_TARGET = {
    locId = "HUD/TXT_MUST_SEE_SCOUTING_TARGET"
    showEvent = "hint:must_see_scouting_target"
    lifeTime = 3.0
  }


  FUNNEL_DAMAGED = {
    locId = "HUD/TXT_FUNNEL_DAMAGED"
    showEvent = "hint:funnel_damaged"
    lifeTime = 3.0
  }

  REPLENISHMENT_IN_PROGRESS = {
    hintType = ::g_hud_hint_types.ACTIONBAR
    locId = "hints/replenishment_of_ammo_stowage"
    showEvent = "hint:replenishment_in_progress:show"
    hideEvent = "hint:replenishment_in_progress:hide"
    maskId = 13
    totalCount = 5
    isSingleInNest = true
  }

  DROWNING_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    showEvent = "hint:drowning:show"
    hideEvent = "hint:drowning:hide"
    buildText = function(eventData)
    {
      local res = ::loc("hints/drowning_in") + " "
      + time.secondsToString(eventData?.timeTo ?? 0, false)
      return res
    }
  }

  MISSION_COMPLETE_HINT = {
    locId = "HUD_MISSION_COMPLETE_HDR"
    showEvent = "hint:mission_complete:show"
    hideEvent = "hint:mission_complete:hide"
    shortcuts = [
      "@ID_CONTINUE_SETUP"
      "@ID_CONTINUE"
    ]
    buildText = function(eventData)
    {
      local res = ::g_hud_hints._buildText.call(this, eventData)
      res += eventData?.count ? " " + eventData.count : ""
      return res
    }
  }

  MISFIRE_HINT = {
    hintType = ::g_hud_hint_types.ACTIONBAR
    locId = "hud_gun_breech_malfunction_misfire"
    showEvent = "hint:misfire:show"
    lifeTime = 5.0
  }

  MISSION_HINT            = genMissionHint(::g_hud_hint_types.MISSION_STANDARD, isStandardMissionHint)
  MISSION_TUTORIAL_HINT   = genMissionHint(::g_hud_hint_types.MISSION_TUTORIAL,
    @(hintTypeName) hintTypeName == MISSION_HINT_TYPE.TUTORIAL)
  MISSION_BOTTOM_HINT     = genMissionHint(::g_hud_hint_types.MISSION_BOTTOM,
    @(hintTypeName) hintTypeName == MISSION_HINT_TYPE.BOTTOM)

  MISSION_BY_ID = {
    hintType = ::g_hud_hint_types.MISSION_STANDARD
    showEvent = "hint:missionHint:setById"
    hideEvent = "hint:missionHint:remove"
    lifeTime = 5.0
    priority = DEFAULT_MISSION_HINT_PRIORITY
    delayTime = 1.0

    isCurrent = @(eventData, isHideEvent) !("hintType" in eventData) || isStandardMissionHint(eventData.hintType)
    getLocId = function(eventData)
    {
      return ::getTblValue("hintId", eventData, "hints/unknown")
    }
  }

  OBJECTIVE_ADDED = {
    hintType = ::g_hud_hint_types.MISSION_STANDARD
    showEvent = "hint:missionHint:objectiveAdded"
    hideEvent = "hint:missionHint:remove"
    locId = "hints/secondary_added"
    image = ::g_objective_status.RUNNING.missionObjImg
    lifeTime = 5.0
    priority = DEFAULT_MISSION_HINT_PRIORITY

    isCurrent = @(eventData, isHideEvent) !("hintType" in eventData) || isStandardMissionHint(eventData.hintType)
  }

  OBJECTIVE_SUCCESS = {
    hintType = ::g_hud_hint_types.MISSION_STANDARD
    showEvent = "hint:missionHint:objectiveSuccess"
    hideEvent = "hint:missionHint:remove"
    image = ::g_objective_status.SUCCEED.missionObjImg
    lifeTime = 5.0
    priority = DEFAULT_MISSION_HINT_PRIORITY
    isShowedInVR = true

    isCurrent = @(eventData, isHideEvent) !("hintType" in eventData) || isStandardMissionHint(eventData.hintType)

    getLocId = function(hintData)
    {
      local objType = ::getTblValue("objectiveType", hintData, ::OBJECTIVE_TYPE_SECONDARY)
      local result = ""
      if (objType == ::OBJECTIVE_TYPE_PRIMARY)
        result = "hints/objective_success"
      if (objType == ::OBJECTIVE_TYPE_SECONDARY)
        result = "hints/secondary_success"
      if (hintData.objectiveText != "")
        result += "_extended"
      return result
    }

    getLocParams = @(hintData) { missionObj = hintData.objectiveText }
  }

  OBJECTIVE_FAIL = {
    hintType = ::g_hud_hint_types.MISSION_STANDARD
    showEvent = "hint:missionHint:objectiveFail"
    hideEvent = "hint:missionHint:remove"
    image = ::g_objective_status.FAILED.missionObjImg
    lifeTime = 5.0
    priority = DEFAULT_MISSION_HINT_PRIORITY
    isShowedInVR = true

    isCurrent = @(eventData, isHideEvent) !("hintType" in eventData) || isStandardMissionHint(eventData.hintType)

    getLocId = function(hintData)
    {
      local objType = ::getTblValue("objectiveType", hintData, ::OBJECTIVE_TYPE_PRIMARY)
      local result = ""
      if (objType == ::OBJECTIVE_TYPE_PRIMARY)
        result = "hints/objective_fail"
      if (objType == ::OBJECTIVE_TYPE_SECONDARY)
        result = "hints/secondary_fail"
      if (hintData.objectiveText != "")
        result += "_extended"
      return result
    }

    getLocParams = @(hintData) { missionObj = hintData.objectiveText }
  }

  OFFER_REPAIR = {
    hintType = ::g_hud_hint_types.REPAIR
    getLocId = function (data) {
      local unitType = ::get_es_unit_type(getPlayerCurUnit())
      if (::getTblValue("assist", data, false))
      {
        if (unitType == ::ES_UNIT_TYPE_TANK)
          return "hints/repair_assist_tank_hold"
        if (unitType == ::ES_UNIT_TYPE_SHIP || unitType == ::ES_UNIT_TYPE_BOAT)
          return "hints/repair_assist_ship_hold"
        return "hints/repair_assist_plane_hold"
      }
      if (::getTblValue("request", data, false))
      {
        return "hints/repair_request_assist_hold"
      }
      else if (::getTblValue("cancelRequest", data, false))
      {
        return "hints/repair_cancel_request_assist_hold"
      }
      return (unitType == ::ES_UNIT_TYPE_SHIP || unitType == ::ES_UNIT_TYPE_BOAT) ?
        "hints/repair_ship" : "hints/repair_tank_hold"
    }

    noKeyLocId = "hints/ready_to_bailout_nokey"
    getShortcuts =  function(data)
    {
      local curUnit = getPlayerCurUnit()
      return curUnit?.isShipOrBoat() ?
        ::g_hud_action_bar_type.TOOLKIT.getVisualShortcut()
        //


        : "ID_REPAIR_TANK"
    }
    showEvent = "tankRepair:offerRepair"
    hideEvent = "tankRepair:cantRepair"
  }

  AMMO_DESTROYED = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/ammo_destroyed"
    showEvent = "hint:ammoDestroyed:show"
    priority = CATASTROPHIC_HINT_PRIORITY
    lifeTime = 5.0
  }

  WEAPON_TYPE_UNAVAILABLE = {
    locId = "hints/weapon_type_unavailable"
    showEvent = "hint:weaponTypeUnavailable:show"
    lifeTime = 3.0
  }

  NO_BULLETS = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/have_not_bullets"
    showEvent = "hint:no_bullets"
    lifeTime = 5.0
    priority = CATASTROPHIC_HINT_PRIORITY
  }

  REQUEST_REPAIR_HELP_HINT = {
    hintType = ::g_hud_hint_types.REPAIR
    locId     = "hints/request_repair_help"
    showEvent = "hint:request_repair_help"
    lifeTime = 5.0
  }

  NO_POTENTIAL_ASSISTANT = {
    hintType = ::g_hud_hint_types.REPAIR
    locId     = "hints/no_potential_assistant"
    showEvent = "hint:no_potential_assistant"
    lifeTime = 5.0
  }

  HAVE_POTENTIAL_ASSISTEE = {
    hintType = ::g_hud_hint_types.REPAIR
    locId     = "hints/have_potential_assistee"
    showEvent = "hint:have_potential_assistee"
    hideEvent = "hint:hide_potential_assistee_hint"
    lifeTime = 3.0
  }

  FRIENDLY_FIRE_WARNING = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/friendly_fire_warning"
    showEvent = "hint:friendly_fire_warning"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  NEED_STOP_FOR_FIRE = {
    hintType = ::g_hud_hint_types.COMMON
    locId     = "hints/need_stop_for_fire"
    showEvent = "hint:need_stop_for_fire"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  NEED_STOP_FOR_HULL_AIMING = {
    hintType = ::g_hud_hint_types.COMMON
    locId     = "hints/need_stop_for_hull_aiming"
    showEvent = "hint:need_stop_for_hull_aiming:show"
    hideEvent = "hint:need_stop_for_hull_aiming:hide"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  STOP_TERRAFORM_FOR_HULL_AIMING = {
    hintType = ::g_hud_hint_types.COMMON
    locId     = "hints/stop_terraform_for_hull_aiming"
    showEvent = "hint:stop_terraform_for_hull_aiming"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  NEED_STOP_FOR_TERRAFORM = {
    hintType = ::g_hud_hint_types.COMMON
    locId     = "hints/need_stop_for_terraform"
    showEvent = "hint:need_stop_for_terraform"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  WAIT_LAUNCHER = {
    hintType = ::g_hud_hint_types.COMMON
    locId     = "hints/wait_launcher_ready"
    showEvent = "hint:wait_launcher_ready"
    hideEvent = "hint:wait_launcher_ready_hide"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  FPS_TO_VIRTUAL_FPS_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/fps_to_virtual_fps"
    showEvent = "hint:fps_to_virtual_fps:show"
    hideEvent = "hint:fps_to_virtual_fps:hide"
    lifeTime = -1.0
  }

  ATGM_NO_LINE_OF_SIGHT = {
    hintType = ::g_hud_hint_types.ACTIONBAR
    locId = "hints/atgm_no_line_of_sight"
    showEvent = "hint:atgm_no_line_of_sight:show"
    hideEvent = "hint:atgm_no_line_of_sight:hide"
    shouldBlink = true
  }

  COMMANDER_VIEW_WITH_NV_ON = {
    hintType = ::g_hud_hint_types.ACTIONBAR
    locId     = "hints/commander_view_with_nv_on"
    showEvent = "hint:commander_view_with_nv_on:show"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  COMMANDER_IS_UNCONSCIOUS = {
    hintType = ::g_hud_hint_types.COMMON
    locId     = "hints/commander_is_unconscious"
    showEvent = "hint:commander_is_unconscious:show"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  VERY_FEW_CREW = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/is_very_few_crew"
    showEvent = "hint:very_few_crew:show"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  SHOT_FREQUENCY_CHANGED = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/shot_frequency_changed"
    showEvent = "hint:shot_frequency_changed:show"
    lifeTime = 5.0
    isHideOnDeath = true
    getLocParams = @(hintData) { shotFreq = ::loc($"hints/shotFreq/{hintData.shotFreq}") }
  }

  CHANGE_BULLET_TYPE_FOR_SET = {
    hintType = ::g_hud_hint_types.ACTIONBAR
    locId = "hints/change_bullet_type_for_set"
    showEvent = "hint:change_bullet_type_for_set"
    totalCount = 8
    lifeTime = 4.0
    isHideOnDeath = true
  }

  IRCM_FAIL_GUIDANCE = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/ircm_fail_guidance"
    showEvent = "hint:ircm_fail_guidance:show"
    lifeTime = 1.0
    isHideOnDeath = true
  }

  NUCLEAR_KILLSTREAK_REACH_AREA = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/reach_battlearea_to_activate_the_bomb"
    showEvent = "hint:nuclear_killstreak_reach_area:show"
    hideEvent = "hint:nuclear_killstreak_reach_area:hide"
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
  }

  NUCLEAR_KILLSTREAK_DROP_BOMB = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/drop_the_bomb"
    showEvent = "hint:nuclear_killstreak_drop_the_bomb:show"
    hideEvent = "hint:nuclear_killstreak_drop_the_bomb:hide"
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
  }

  EXTINGUISH_ASSIST = {
    hintType = ::g_hud_hint_types.REPAIR
    locId = "hints/extinguish_assist"
    showEvent = "hint:have_potential_fire_assistee"
    hideEvent = "hint:hide_potential_fire_assistee_hint"
    getShortcuts =  function(data)
    {
      return ::g_hud_action_bar_type.EXTINGUISHER.getVisualShortcut()
    }
  }

  NO_POTENTIAL_FIRE_ASSISTANT = {
    hintType = ::g_hud_hint_types.REPAIR
    locId     = "hints/no_potential_fire_assistant"
    showEvent = "hint:no_potential_fire_assistant"
    lifeTime = 5.0
  }

  REQUEST_EXTINGUISH_HELP_DONT_MOVE = {
    hintType = ::g_hud_hint_types.REPAIR
    locId     = "hints/request_extinguish_dont_move"
    showEvent = "hint:request_extinguish_dont_move"
    lifeTime = 5.0
  }

  REQUEST_EXTINGUISH_HELP_HINT = {
    hintType = ::g_hud_hint_types.REPAIR
    getLocId = function (data) {
      if (::getTblValue("request", data, false))
      {
        return "hints/request_extinguish_help"
      }
      else if (::getTblValue("cancelRequest", data, false))
      {
        return "hints/request_extinguish_help_cancel"
      }
      return ""
    }
    noKeyLocId = "hints/ready_to_bailout_nokey"
    showEvent = "hint:request_extinguish_help"
    hideEvent = "hint:request_extinguish_help_hide"
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
    getShortcuts =  function(data)
    {
      return ::g_hud_action_bar_type.EXTINGUISHER.getVisualShortcut()
    }
  }
  //







},
function() {
  name = "hint_" + typeName.tolower()
  if (lifeTime > 0)
    selfRemove = true

  if(maskId >= 0)
    mask = 1 << maskId
},
"typeName")

g_hud_hints.getByName <- function getByName(hintName)
{
  return enums.getCachedType("name", hintName, cache.byName, this, UNKNOWN)
}
