from "%scripts/dagui_natives.nut" import is_hint_enabled, get_hint_seen_count
from "%scripts/dagui_library.nut" import *
from "%scripts/hud/hudConsts.nut" import HINT_INTERVAL
from "%scripts/viewUtils/hints.nut" import g_hints, g_hint_tag

let { g_hud_action_bar_type } = require("%scripts/hud/hudActionBarType.nut")
let { g_difficulty } = require("%scripts/difficulty.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { isXInputDevice } = require("controls")
let { get_time_msec } = require("dagor.time")
let { get_charserver_time_sec } = require("chard")
let { format } = require("string")
let enums = require("%sqStdLibs/helpers/enums.nut")
let time = require("%scripts/time.nut")
let { blk2SquirrelObjNoArrays } = require("%sqstd/datablock.nut")
let { is_stereo_mode } = require("vr")
let { getHudUnitType } = require("hudState")
let { HUD_UNIT_TYPE } = require("%scripts/hud/hudUnitType.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { startsWith } = require("%sqstd/string.nut")
let { get_mplayer_by_id } = require("mission")
let { get_mission_difficulty, OBJECTIVE_TYPE_PRIMARY, OBJECTIVE_TYPE_SECONDARY } = require("guiMission")
let { loadLocalAccountSettings, saveLocalAccountSettings} = require("%scripts/clientState/localProfile.nut")
let { register_command } = require("console")
let { isEqual } = require("%sqstd/underscore.nut")
let { g_hud_hint_types } = require("%scripts/hud/hudHintTypes.nut")
let { objectiveStatus } = require("%scripts/misObjectives/objectiveStatus.nut")

const DEFAULT_MISSION_HINT_PRIORITY = 100
const CATASTROPHIC_HINT_PRIORITY = 0
const HINT_UID_LIMIT = 16384

let animTimerPid = dagui_propid_add_name_id("_transp-timer")
local cachedHintsSeenData = null

enum MISSION_HINT_TYPE {
  STANDARD   = "standard"
  TUTORIAL   = "tutorialHint"
  BOTTOM     = "bottom"
}

local g_hud_hints

g_hud_hints = {
  types = []
  cache = {
    byName = {}
    byUid = {}
    byShowEvent = {}
  }
}

g_hud_hints._buildMarkup <- function _buildMarkup(eventData, hintObjId) {
  return g_hints.buildHintMarkup(this.buildText(eventData), this.getHintMarkupParams(eventData, hintObjId))
}

g_hud_hints._getHintMarkupParams <- function _getHintMarkupParams(eventData, hintObjId) {
  return {
    id = hintObjId || this.name
    style = this.getHintStyle()
    time = this.getTimerTotalTimeSec(eventData)
    timeoffset = this.getTimerCurrentTimeSec(eventData, get_time_msec()) //creation time right now
    animation = this.shouldBlink ? "wink" : this.shouldFadeOut ? "show" : null
    showKeyBoardShortcutsForMouseAim = eventData?.showKeyBoardShortcutsForMouseAim ?? false
    isVerticalAlignText = this.isVerticalAlignText
    isWrapInRowAllowed = this.isWrapInRowAllowed
  }
}

let getRawShortcutsArray = function(shortcuts) {
  if (!shortcuts)
    return []
  local rawShortcutsArray = u.isArray(shortcuts) ? clone shortcuts : [shortcuts]
  let shouldPickOne = g_hud_hints.shouldPickFirstValid(rawShortcutsArray)
  if (shouldPickOne) {
    let rawShortcut = g_hud_hints.pickFirstValidShortcut(rawShortcutsArray)
    rawShortcutsArray = rawShortcut != null ? [rawShortcut] : []
  }
  else
    rawShortcutsArray = g_hud_hints.removeUnmappedShortcuts(rawShortcutsArray)
  return rawShortcutsArray
}

function getUniqueShortcuts(shortcuts) {
  let preset = ::g_controls_manager.getCurPreset()
  let uniqHotkeys = [preset.getHotkey(shortcuts[0])]
  let uniqShortcuts = [shortcuts[0]]

  for (local i = 1; i < shortcuts.len(); ++i) {
    let shName = shortcuts[i]
    let hotkey = preset.getHotkey(shName)

    foreach (hk in uniqHotkeys)
      if (!isEqual(hotkey, hk))
        uniqShortcuts.append(shName)
  }

  return uniqShortcuts
}

g_hud_hints._buildText <- function _buildText(data) {
  local shortcuts = this.getShortcuts(data)

  if (shortcuts == null) {
    local res = loc(this.getLocId(data), this.getLocParams(data))
    if (this.image)
      res = "".concat(g_hint_tag.IMAGE.makeFullTag({ image = this.image }), res)
    return res
  }

  if (!u.isArray(shortcuts))
    shortcuts = [shortcuts]
  else if (shortcuts.len() > 1)
    shortcuts = getUniqueShortcuts(shortcuts)

  let rawShortcutsArray = getRawShortcutsArray(shortcuts)
  let assigned = rawShortcutsArray.len() > 0
  if (!assigned) {
    let noKeyLocId = this.getNoKeyLocId()
    if (noKeyLocId != "")
      return loc(noKeyLocId)
  }

  let expandedShortcutArray = ::g_shortcut_type.expandShortcuts(rawShortcutsArray)
  local shortcutTag = g_hud_hints._wrapShortsCutIdWithTags(expandedShortcutArray)

  let shortcut = shortcuts[0]
  let shortcutType = ::g_shortcut_type.getShortcutTypeByShortcutId(shortcut)
  if (shortcut != "" && shortcutTag == "" && shortcutType != null
    && !shortcutType.isAssigned(shortcut)
  ) {
    let shortcut_for_loc = shortcutType.typeName == "HALF_AXIS"
      ? shortcutType.transformHalfAxisToShortcuts(shortcut)
      : shortcut
    shortcutTag = loc("ui/quotes", { text = "".concat(
      loc($"hotkeys/{shortcut_for_loc}"),
      loc("ui/parentheses/space", { text = loc("hotkeys/shortcut_not_assigned") })) })
  }

  let locParams = this.getLocParams(data).__update({ shortcut = shortcutTag })
  local result = loc(this.getLocId(data), locParams)

  //If shortcut not specified in localization string it should
  //be placed at the beginig
  if (shortcutTag != "" && result.indexof(shortcutTag) == null)
    result = $"{shortcutTag} {result}"

  return result
}

/**
 * Return true if only one shortcut should be picked from @shortcutArray
 */
g_hud_hints.shouldPickFirstValid <- function shouldPickFirstValid(shortcutArray) {
  foreach (shortcutId in shortcutArray)
    if (startsWith(shortcutId, "@"))
      return true
  return false
}

g_hud_hints.pickFirstValidShortcut <- function pickFirstValidShortcut(shortcutArray) {
  foreach (shortcutId in shortcutArray) {
    local localShortcutId = shortcutId //to avoid changes in original array
    if (startsWith(localShortcutId, "@"))
      localShortcutId = localShortcutId.slice(1)
    let shortcutType = ::g_shortcut_type.getShortcutTypeByShortcutId(localShortcutId)
    if (shortcutType.isAssigned(localShortcutId))
      return localShortcutId
  }

  return null
}

g_hud_hints.removeUnmappedShortcuts <- function removeUnmappedShortcuts(shortcutArray) {
  for (local i = shortcutArray.len() - 1; i >= 0; --i) {
    let shortcutType = ::g_shortcut_type.getShortcutTypeByShortcutId(shortcutArray[i])
    if (!shortcutType.isAssigned(shortcutArray[i]))
      shortcutArray.remove(i)
  }

  return shortcutArray
}

g_hud_hints._getLocId <- function _getLocId(_data) {
  return this.locId
}

g_hud_hints._getNoKeyLocId <- function _getNoKeyLocId() {
  return this.noKeyLocId
}

g_hud_hints._getLifeTime <- function _getLifeTime(data) {
  return this.lifeTime || getTblValue("lifeTime", data, 0)
}

g_hud_hints._getShortcuts <- function _getShortcuts(_data) {
  return this.shortcuts
}

g_hud_hints._wrapShortsCutIdWithTags <- function _wrapShortsCutIdWithTags(shortNamesArray) {
  local result = ""
  let separator = loc("hints/shortcut_separator")
  foreach (shortcutName in shortNamesArray) {
    if (result.len())
      result = "".concat(result, separator)

    result = "".concat(result, g_hints.hintTags[0], shortcutName, g_hints.hintTags[1])
  }
  return result
}

g_hud_hints._getHintNestId <- function _getHintNestId() {
  return this.hintType.nestId
}

g_hud_hints._getHintStyle <- function _getHintStyle() {
  return this.hintType.hintStyle
}

//all obsolette hinttype names must work as standard mission hint
let isStandardMissionHint = @(hintTypeName)
  hintTypeName != MISSION_HINT_TYPE.TUTORIAL && hintTypeName != MISSION_HINT_TYPE.BOTTOM

let genMissionHint = @(hintType, checkHintTypeNameFunc) {
  hintType = hintType
  showEvent = "hint:missionHint:set"
  hideEvent = "hint:missionHint:remove"
  selfRemove = true
  isVerticalAlignText = true
  _missionTimerTotalMsec = 0
  _missionTimerStartMsec = 0

  updateCbs = {
    ["mission:timer:start"] = function(_hintData, eventData) {
      let totalSec = getTblValue("totalTime", eventData)
      if (!totalSec)
        return false

      this._missionTimerTotalMsec = 1000 * totalSec
      this._missionTimerStartMsec = get_time_msec()
      return true
    },
    ["mission:timer:stop"] = function(_hintData, _eventData) {
      this._missionTimerTotalMsec = 0
      return true
    }
  }

  isCurrent = function(eventData, isHideEvent) {
    if (isHideEvent && !("hintType" in eventData))
      return true
    return checkHintTypeNameFunc(getTblValue("hintType", eventData, MISSION_HINT_TYPE.STANDARD))
  }

  getLocId = function (hintData) {
    return getTblValue("locId", hintData, "")
  }

  getShortcuts = function (hintData) {
    return getTblValue("shortcuts", hintData)
  }

  buildText = function (hintData) {
    local res = g_hud_hints._buildText.call(this, hintData)
    local varValue = getTblValue("variable_value", hintData)
    if (varValue != null) {
      let varStyle = getTblValue("variable_style", hintData)
      if (varStyle == "playerId") {
        let player = get_mplayer_by_id(varValue)
        varValue = ::build_mplayer_name(player)
      }
      res = loc(res, { var = varValue })
    }
    if (!this.getShortcuts(hintData))
      return res
    return "".concat(g_hint_tag.TIMER.makeFullTag(), " ", res)
  }

  getHintMarkupParams = function(eventData, hintObjId) {
    let res = g_hud_hints._getHintMarkupParams.call(this, eventData, hintObjId)
    res.hideWhenStopped <- true
    res.timerOffsetX <- "-w" //to timer do not affect message position.
    res.isOrderPopup <- getTblValue("isOverFade", eventData, false)
    res.isVerticalAlignText = this.isVerticalAlignText && this.getTimerTotalTimeSec(eventData) != 0

    res.animation <- getTblValue("shouldBlink", eventData, false) ? "wink"
      : getTblValue("shouldFadeout", eventData, false) ? "show"
      : null
    return res
  }

  getTimerTotalTimeSec = function(_eventData) {
    if (this._missionTimerTotalMsec <= 0
        || (get_time_msec() > this._missionTimerTotalMsec + this._missionTimerStartMsec))
      return 0
    return time.millisecondsToSeconds(this._missionTimerTotalMsec)
  }
  getTimerCurrentTimeSec = function(_eventData, _hintAddTime) {
    return time.millisecondsToSeconds(get_time_msec() - this._missionTimerStartMsec)
  }

  getLifeTime = @(eventData) getTblValue("time", eventData, 0)

  isInstantHide = @(eventData) !getTblValue("shouldFadeout", eventData, true)
  hideHint = function(hintObject, isInstant) {
    if (isInstant)
      hintObject.getScene().destroyElement(hintObject)
    else {
      hintObject.animation = "hide"
      hintObject.selfRemoveOnFinish = "-1"
      hintObject.setFloatProp(animTimerPid, 1.0)
    }
    return !isInstant
  }
  isHideOnWatchedHeroChanged = false
  isShowedInVR = true
}

function saveHintSeenData(hintData, uid){
  saveLocalAccountSettings($"hintsSeenData/{uid}", hintData)
  if (cachedHintsSeenData)
    cachedHintsSeenData[uid] <- hintData
}


function getHintSeenData(uid) {
  if (uid < 0)
    return null
  if (cachedHintsSeenData == null) {
    let hintsSeenDataBlock = loadLocalAccountSettings("hintsSeenData")
    if (hintsSeenDataBlock == null) {
      cachedHintsSeenData = {}
    } else {
      cachedHintsSeenData = blk2SquirrelObjNoArrays(hintsSeenDataBlock)
    }
  }

  let hintIdString = uid.tostring()
  local hintSeenData = cachedHintsSeenData?[hintIdString]

  if (hintSeenData == null) {
    //get_hint_seen_count used for compability with 2.29.0.X
    let hint = g_hud_hints.getByUid(uid)
    let showedCount = hint ? get_hint_seen_count(hint.maskId) : 0
    hintSeenData = {
      seenTime = get_charserver_time_sec()
      seenCount = showedCount
    }
    cachedHintsSeenData[hintIdString] <- hintSeenData
    if (showedCount > 0)
      saveHintSeenData(hintSeenData, hintIdString)
  }

  return hintSeenData
}


function getHintSeenTime(uid) {
  return getHintSeenData(uid)?.seenTime ?? 0
}


function getHintSeenCount(uid){
  return getHintSeenData(uid)?.seenCount ?? 0
}


function resetHintShowCount(uid) {
  let hintSeenData = getHintSeenData(uid)
  if (hintSeenData == null)
    return
  hintSeenData.seenCount = 0
  saveHintSeenData(hintSeenData, uid)
}


function updateHintEventTime(uid) {
  let hintSeenData = getHintSeenData(uid)
  if (hintSeenData == null)
    return
  hintSeenData.seenTime = get_charserver_time_sec()
  saveHintSeenData(hintSeenData, uid)
}

function increaseHintShowCount(uid) {
  let hintSeenData = getHintSeenData(uid)
  if (hintSeenData == null)
    return
  hintSeenData.seenCount = hintSeenData.seenCount + 1
  hintSeenData.seenTime = get_charserver_time_sec()
  saveHintSeenData(hintSeenData, uid.tostring())
}


function logHintSeenState(hintData) {
  if (!hintData) {
    log("hint not found")
    return
  }
  let seenData = getHintSeenData(hintData.uid)
  if (!seenData) {
    log($"seenData for hint {hintData.name} is not found")
    return
  }
  log( $"Hint: {hintData.name}, uid = {hintData.uid}, totalCount = {hintData.totalCount}, showedCount = {seenData.seenCount}, seenTime = {seenData.seenTime}")
}


function logHintInformashionById(uid) {
  logHintSeenState(g_hud_hints.getByUid(uid))
}


function logHintInformashionByName(name) {
  logHintSeenState(g_hud_hints.getByName(name))
}


function getHintByShowEvent(showEvent) {
  return enums.getCachedType("showEvent", showEvent, g_hud_hints.cache.byShowEvent, g_hud_hints, null)
}


g_hud_hints.template <- {
  name = "" //generated by typeName. Used as id in hud scene.
  typeName = "" //filled by typeName
  locId = ""
  noKeyLocId = ""
  image = null //used only when no shortcuts
  hintType = g_hud_hint_types.COMMON
  uid = -1
  priority = 0
  //for long hints with shortcuts
  isWrapInRowAllowed = false

  getHintNestId = g_hud_hints._getHintNestId
  getHintStyle = g_hud_hints._getHintStyle

  getLocId = g_hud_hints._getLocId
  getNoKeyLocId = g_hud_hints._getNoKeyLocId

  getLocParams = @(_hintData) {}

  getPriority = function(eventData) { return getTblValue("priority", eventData, this.priority) }
  isCurrent = @(_eventData, _isHideEvent) true

  //Some hints contain shortcuts. If there is only one shortuc in hint (common case)
  //just put shirtcut id in shortcuts field.
  //If there is more then one shortuc, the should be representd as table.
  //shortcut table format: {
  //  locArgumentName = shortcutid
  //}
  //locArgument will be used as wildcard id for locization text
  shortcuts = null
  getShortcuts          = g_hud_hints._getShortcuts
  buildMarkup           = g_hud_hints._buildMarkup
  buildText             = g_hud_hints._buildText
  getHintMarkupParams   = g_hud_hints._getHintMarkupParams
  getLifeTime           = g_hud_hints._getLifeTime
  isEnabledByDifficulty = @() !this.isAllowedByDiff || (this.isAllowedByDiff?[get_mission_difficulty()] ?? true)

  selfRemove = false //will be true if lifeTime > 0
  lifeTime = 0.0
  secondsOfForgetting = 0 //seconds after which seenCount reset to zero
  getTimerTotalTimeSec    = function(eventData) { return this.getLifeTime(eventData) }
  getTimerCurrentTimeSec  = function(_eventData, hintAddTime) {
    return time.millisecondsToSeconds(get_time_msec() - hintAddTime)
  }

  isInstantHide = @(_eventData) true
  hideHint = function(hintObject, _isInstant) {  //return <need to instant hide when new hint appear>
    hintObject.getScene().destroyElement(hintObject)
    return false
  }
  isHideOnDeath = true
  isHideOnWatchedHeroChanged = true

  showEvent = ""
  hideEvent = null
  toggleHint = null
  updateCbs = null //{ <hudEventName> = function(hintData, eventData) { return <needUpdate (bool)>} } //hintData can be null

  countIntervals = null // for example [{count = 5, timeInterval = 60.0 }, { ... }, ...]
  delayTime = 0.0
  isAllowedByDiff  = null
  totalCount = -1
  totalCountByCondition = -1
  missionCount = -1
  mask = 0
  maskId = -1
  disabledByUnitTags = null

  isShowedInVR = false

  shouldBlink = false
  shouldFadeOut = false
  isSingleInNest = false
  isVerticalAlignText = false
  isEnabled = @() (this.isShowedInVR || !is_stereo_mode())
    && is_hint_enabled(this.mask)
    && this.isEnabledByDifficulty()

  getTimeInterval = function() {
    if (!this.countIntervals)
      return HINT_INTERVAL.ALWAYS_VISIBLE

    local interval = HINT_INTERVAL.HIDDEN
    let count = getHintSeenCount(this.uid)
    foreach (countInterval in this.countIntervals)
      if (!countInterval?.count || count < countInterval.count) {
        interval = countInterval.timeInterval
        break
      }
    return interval
  }

  updateHintOptionsBlk = function(_blk) {} //special options for native hints
}

enums.addTypes(g_hud_hints, {
  UNKNOWN = {}

  OFFER_BAILOUT = {
    getLocId = function(_hintData) {
      return getHudUnitType() == HUD_UNIT_TYPE.HELICOPTER
        ? "hints/ready_to_bailout_helicopter"
        : "hints/ready_to_bailout"
    }
    getNoKeyLocId = function() {
      return getHudUnitType() == HUD_UNIT_TYPE.HELICOPTER
        ? "hints/ready_to_bailout_helicopter_nokey"
        : "hints/ready_to_bailout_nokey"
    }
    shortcuts = "ID_BAILOUT"

    showEvent = "hint:bailout:offerBailout"
    hideEvent = ["hint:bailout:startBailout", "hint:bailout:notBailouts"]
  }

  START_BAILOUT = {
    nearestOffenderLocId = "HUD_AWARD_NEAREST"
    awardGiveForLocId = "HUD_AWARD_GIVEN_FOR"

    getLocId = function (_hintData) {
      let hudUnitType = getHudUnitType()
      return hudUnitType == HUD_UNIT_TYPE.HELICOPTER ? "hints/bailout_helicopter_in_progress"
        : hudUnitType == HUD_UNIT_TYPE.AIRCRAFT ? "hints/bailout_in_progress"
        : "hints/leaving_the_tank_in_progress" //this localization is more general, then the "air" one
    }

    showEvent = "hint:bailout:startBailout"
    hideEvent = ["hint:bailout:offerBailout", "hint:bailout:notBailouts"]

    selfRemove = true
    isVerticalAlignText = true
    function buildText(data) {
      local res = $"{g_hud_hints._buildText.call(this, data)} {g_hint_tag.TIMER.makeFullTag()}"
      let leaveKill = data?.leaveKill ?? false
      if (leaveKill)
        res = $"{res}\n{loc(this.nearestOffenderLocId)}"
      let offenderName = data?.offenderName ?? ""
      if (offenderName != "")
        res = $"{res}\n{loc(this.awardGiveForLocId)}{getPlayerName(offenderName)}"
      return res
    }
  }

  BAILOUT_CANT_REPAIR = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/bailout_cant_repair"
    showEvent = "hint:bailout:cantRepair"
    selfRemove = true
    lifeTime = 10.0
  }

  SKIP_XRAY_SHOT = {
    hintType = g_hud_hint_types.MINOR
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
    hintType = g_hud_hint_types.COMMON
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
    hintType = g_hud_hint_types.COMMON
    locId = "hints/extinguisher_is_ineffective"
    showEvent = "hint:extinguisher_ineffective:begin"
    hideEvent = "hint:extinguisher_ineffective:end"
  }


  TRACK_REPAIR_HINT = {
    hintType = g_hud_hint_types.REPAIR
    locId     = "hints/track_repair"
    showEvent = "hint:track_repair"
    lifeTime = 5.0
  }

  ACTION_NOT_AVAILABLE_HINT = {
    hintType = g_hud_hint_types.COMMON
    showEvent = "hint:action_not_available"
    lifeTime = 5.0
    priority = CATASTROPHIC_HINT_PRIORITY
    getLocId = @(data) loc($"hints/{data?.hintId ?? ""}")
  }

  INEFFECTIVE_HIT_HINT = {
    hintType = g_hud_hint_types.COMMON
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
    uid = 11
  }

  GUN_JAMMED_HINT = {
    hintType = g_hud_hint_types.COMMON
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
    uid = 26
  }

  ATGM_AIM_HINT = {
    hintType = g_hud_hint_types.ACTIONBAR
    locId = "hints/atgm_aim"
    showEvent = "hint:atgm_aim:show"
    lifeTime = 10.0
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 5
    maskId = 28
    uid = 28
  }

  ATGM_MANUAL_HINT = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/atgm_manual"
    showEvent = "hint:atgm_manual:show"
    lifeTime = 10.0
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 5
    maskId = 29
    uid = 29
  }

  ATGM_AIM_HINT_TORPEDO = {
    hintType = g_hud_hint_types.REPAIR
    locId = "hints/atgm_aim_torpedo"
    showEvent = "hint:atgm_aim_torpedo:show"
    lifeTime = 10.0
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 5
    maskId = 30
    uid = 30
  }

  BOMB_AIM_HINT = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/bomb_aim"
    showEvent = "hint:bomb_aim:show"
    lifeTime = 10.0
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 5
    maskId = 30
    uid = 30
  }

  BOMB_MANUAL_HINT = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/bomb_manual"
    showEvent = "hint:bomb_manual:show"
    lifeTime = 10.0
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 5
    maskId = 30
    uid = 30
  }

  DEAD_PILOT_HINT = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/dead_pilot"
    showEvent = "hint:dead_pilot:show"
    lifeTime = 5.0
    isHideOnDeath = false
    isHideOnWatchedHeroChanged = false
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 20
    maskId = 12
    uid = 12
  }

  HAVE_ART_SUPPORT_HINT = {
    hintType = g_hud_hint_types.ACTIONBAR
    locId = "hints/have_art_support"
    noKeyLocId = "hints/have_art_support_no_key"
    getShortcuts = @(_data) g_hud_action_bar_type.ARTILLERY_TARGET.getVisualShortcut()
    showEvent = "hint:have_art_support:show"
    hideEvent = "hint:have_art_support:hide"
    lifeTime = 5.0
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 5
    maskId = 27
    uid = 27
  }

  AUTO_REARM_HINT = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/auto_rearm"
    showEvent = "hint:auto_rearm:show"
    hideEvent = "hint:auto_rearm:hide"
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 1
    isAllowedByDiff  = {
      [g_difficulty.REALISTIC.name] = false,
      [g_difficulty.SIMULATOR.name] = false
    }
    maskId = 9
    uid = 9
  }

  WINCH_REQUEST_HINT = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/winch_request"
    noKeyLocId = "hints/winch_request_no_key"
    showEvent = "hint:winch_request:show"
    hideEvent = "hint:winch_request:hide"
    priority = DEFAULT_MISSION_HINT_PRIORITY
    getShortcuts = @(_data) g_hud_action_bar_type.WINCH.getVisualShortcut()
    lifeTime = 10.0
    delayTime = 4.0
  }

  FOOTBALL_JUMP_REQUEST = {
    hintType = g_hud_hint_types.COMMON
    locId = "HUD/TXT_FOOTBALL_JUMP_REQUEST"
    showEvent = "hint:football_jump_request:show"
    hideEvent = "hint:football_jump_request:hide"
    priority = DEFAULT_MISSION_HINT_PRIORITY
    shortcuts = "ID_FIRE_GM"
    lifeTime = 3.0
    delayTime = 2.0
  }

  WINCH_USE_HINT = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/winch_use"
    noKeyLocId = "hints/winch_use_no_key"
    showEvent = "hint:winch_use:show"
    hideEvent = "hint:winch_use:hide"
    priority = DEFAULT_MISSION_HINT_PRIORITY
    getShortcuts = @(_data) g_hud_action_bar_type.WINCH.getVisualShortcut()
    lifeTime = 10.0
    delayTime = 2.0
  }

  WINCH_USE_SHIP_HINT = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/winch_use_ship"
    noKeyLocId = "hints/winch_use_ship_no_key"
    showEvent = "hint:winch_use_ship:show"
    hideEvent = "hint:winch_use_ship:hide"
    priority = DEFAULT_MISSION_HINT_PRIORITY
    getShortcuts = @(_) isXInputDevice()
      ? "ID_SHOW_MULTIFUNC_WHEEL_MENU"
      : "ID_SHOW_VOICE_MESSAGE_LIST"
    lifeTime = 10.0
    delayTime = 1.0
  }

  WINCH_DETACH_HINT = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/winch_detach"
    noKeyLocId = "hints/winch_detach_no_key"
    showEvent = "hint:winch_detach:show"
    hideEvent = "hint:winch_detach:hide"
    priority = DEFAULT_MISSION_HINT_PRIORITY
    getShortcuts = @(_data) g_hud_action_bar_type.WINCH.getVisualShortcut()
    lifeTime = 10.0
    delayTime = 4.0
  }

  WINCH_DETACH_SHIP_HINT = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/winch_detach"
    noKeyLocId = "hints/winch_detach_no_key"
    showEvent = "hint:winch_detach_ship:show"
    hideEvent = "hint:winch_detach_ship:hide"
    priority = DEFAULT_MISSION_HINT_PRIORITY
    getShortcuts = @(_) isXInputDevice()
      ? "ID_SHOW_MULTIFUNC_WHEEL_MENU"
      : "ID_SHOW_VOICE_MESSAGE_LIST"
    delayTime = 2.0
  }

  F1_CONTROLS_HINT = {
    hintType = g_hud_hint_types.ACTIONBAR
    locId = "hints/f1_controls"
    showEvent = "hint:f1_controls:show"
    hideEvent = "helpOpened"
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 3
    lifeTime = 5.0
    delayTime = 10.0
    maskId = 0
    uid = 0
    disabledByUnitTags = ["type_robot"]
  }

  F1_CONTROLS_HINT_SCRIPTED = {
    uid = 1
    hintType = g_hud_hint_types.COMMON
    locId = "hints/help_controls"
    noKeyLocId = "hints/help_controls/nokey"
    shortcuts = "ID_HELP"
    showEvent = "hint:f1_controls_scripted:show"
    hideEvent = "helpOpened"
    lifeTime = 30.0
    totalCountByCondition = 3
    disabledByUnitTags = ["type_robot"]
  }

  FULL_THROTTLE_HINT = {
    hintType = g_hud_hint_types.COMMON
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
    uid = 7
  }

  DISCONNECT_HINT = {
    hintType = g_hud_hint_types.COMMON
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
    uid = 8
  }

  SHOT_TOO_FAR_HINT = {
    hintType = g_hud_hint_types.COMMON
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
    uid = 10

    updateHintOptionsBlk = function(blk) {
       //float params only.
       blk.shotTooFarMaxAngle = 5.0
       blk.shotTooFarDistanceFactor = 21.5
    }
  }

  SHOT_FORESTALL_HINT = {
    hintType = g_hud_hint_types.COMMON
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
      [g_difficulty.SIMULATOR.name] = false
    }
    lifeTime = 5.0
    delayTime = 5.0
    maskId = 10
    uid = 10

    updateHintOptionsBlk = function(blk) {
      //float params only
      blk.forestallMaxTargetAngle = 2.0
      blk.forestallMaxAngle = 4.0
    }
  }

  PARTIAL_DOWNLOAD = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/partial_download"
    showEvent = "hint:partial_download:show"
    priority = CATASTROPHIC_HINT_PRIORITY
    lifeTime = 5.0
  }

  EXTINGUISH_FIRE_HINT = {
    hintType = g_hud_hint_types.MISSION_ACTION_HINTS
    locId = "hints/extinguish_fire"
    noKeyLocId = "hints/extinguish_fire_nokey"
    getShortcuts = @(_data)
        getHudUnitType() == HUD_UNIT_TYPE.AIRCRAFT ? "ID_TOGGLE_EXTINGUISHER"
      : getHudUnitType() == HUD_UNIT_TYPE.HELICOPTER ? "ID_TOGGLE_EXTINGUISHER_HELICOPTER"
      : g_hud_action_bar_type.EXTINGUISHER.getVisualShortcut()
    showEvent = "hint:extinguish_fire:show"
    hideEvent = "hint:extinguish_fire:hide"
    shouldBlink = true
    selfRemove = true
    getLifeTime = @(_data) getHudUnitType() == HUD_UNIT_TYPE.SHIP ? 5.0 : 0
  }

  CRITICAL_BUOYANCY_HINT = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/critical_buoyancy"
    noKeyLocId = "hints/critical_buoyancy_nokey"
    showEvent = "hint:critical_buoyancy:show"
    hideEvent = "hint:critical_buoyancy:hide"
    shouldBlink = true
    getShortcuts = function(eventData) {
      if (eventData?.showRepairButton) {
        return "ID_REPAIR_BREACHES"
      }
      return null
    }
  }

  SHIP_BROKEN_GUNS_HINT = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/ship_broken_gun"
    showEvent = "hint:ship_broken_gun:show"
    hideEvent = "hint:ship_broken_gun:hide"
  }

  CRITICAL_HEALING_HINT = {
    hintType = g_hud_hint_types.MISSION_ACTION_HINTS
    locId = "hints/critical_heeling"
    noKeyLocId = "hints/critical_heeling_nokey"
    shortcuts = "ID_REPAIR_BREACHES"
    showEvent = "hint:critical_heeling:show"
    hideEvent = "hint:critical_heeling:hide"
    shouldBlink = true
  }

  MOVE_SUSPENSION_HINT = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/move_suspension"
    noKeyLocId = "hints/move_suspension_nokey"
    shortcuts = "ID_SUSPENSION_RESET"
    showEvent = "hint:move_suspension:show"
    hideEvent = "hint:move_suspension:hide"
    shouldBlink = true
  }

  MOVE_SUSPENSION_ZERO_VEL_HINT = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/move_suspension_zero_vel"
    noKeyLocId = "hints/move_suspension_zero_vel_nokey"
    shortcuts = "ID_SUSPENSION_RESET"
    showEvent = "hint:move_suspension_zero_vel:show"
    hideEvent = "hint:move_suspension_zero_vel:hide"
    shouldBlink = true
  }

  MOVE_SUSPENSION_BLOCKED_HINT = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/move_suspension_blocked"
    showEvent = "hint:move_suspension_blocked"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  YOU_CAN_EXIT_HINT = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/you_can_exit"
    noKeyLocId = "hints/you_can_exit_nokey"
    shortcuts = "ID_BAILOUT"
    showEvent = "hint:you_can_exit:show"
    hideEvent = "hint:you_can_exit:hide"
    shouldBlink = true
  }

  SAFELY_LEAVE_POSSIBLE_GM_HINT = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/safely_leave_possible_ground_model"
    noKeyLocId = "hints/safely_leave_possible_ground_model_nokey"
    shortcuts = "ID_BAILOUT"
    showEvent = "hint:safely_leave_possible_ground_model:show"
    hideEvent = "hint:safely_leave_possible_ground_model:hide"
    shouldBlink = true
  }

  ARTILLERY_MAP_HINT = {
    hintType = g_hud_hint_types.COMMON
    locId = "HUD/TXT_ARTILLERY_MAP"
    noKeyLocId = "HUD/TXT_ARTILLERY_MAP_NOKEY"
    shortcuts = "ID_CHANGE_ARTILLERY_TARGETING_MODE"
    showEvent = "hint:artillery_map:show"
    hideEvent = "hint:artillery_map:hide"
    shouldBlink = true
    delayTime = 1.0
  }

  USE_ARTILLERY_HINT = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/use_artillery"
    noKeyLocId = "hints/use_artillery_no_key"
    shortcuts = "ID_SHOOT_ARTILLERY"
    showEvent = "hint:artillery_map:show"
    hideEvent = "hint:artillery_map:hide"
    lifeTime = 5.0
    totalCount = 5
    maskId = 15
    uid = 15
  }

  PRESS_A_TO_CONTINUE_HINT = {
    hintType = g_hud_hint_types.COMMON
    locId = "HUD_PRESS_A_CNT"
    noKeyLocId = "HUD_PRESS_A_CNT"
    shortcuts = [
      "@ID_CONTINUE_SETUP"
      "@ID_CONTINUE"
      "@ID_FIRE"
    ]
    showEvent = "hint:press_a_continue:show"
    hideEvent = "hint:press_a_continue:hide"
    buildText = function(eventData) {
      local res = g_hud_hints._buildText.call(this, eventData)
      let timer = eventData?.timer
      if (timer)
        res = $"{res} ({timer})"
      return res
    }
    isShowedInVR = true
  }

  RELOAD_ON_AIRFIELD_HINT = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/reload_on_airfield"
    noKeyLocId = "hints/reload_on_airfield_nokey"
    shortcuts = "ID_RELOAD_GUNS"
    showEvent = "hint:reload_on_airfield:show"
    hideEvent = "hint:reload_on_airfield:hide"
    shouldBlink = true
  }

  EVENT_START_HINT = {
    hintType = g_hud_hint_types.ACTIONBAR
    showEvent = "hint:event_start_time:show"
    hideEvent = "hint:event_start_time:hide"
    getShortcuts = @(eventData) eventData?.shortcut

    makeSmallImageStr = @(image, color = null, sizeStyle = null) g_hint_tag.IMAGE.makeFullTag({
      image = image
      color = color
      sizeStyle = sizeStyle
    })

    buildText = function(eventData) {
      local res = g_hud_hints._buildText.call(this, eventData)
      let rawShortcutsArray = getRawShortcutsArray(this.getShortcuts(eventData))

      let player = "player" in eventData
          ? eventData.player
        : "playerId" in eventData
          ? get_mplayer_by_id(eventData.playerId)
        : null

      local locId = eventData?.locId ?? ""
      if (!rawShortcutsArray.len())
        locId = eventData?.noKeyLocId ?? locId

      res = "".concat(res,
        loc(locId, {
          player = player ? ::build_mplayer_name(player) : ""
          time = time.secondsToString(eventData?.timeSeconds ?? 0, true, true)
        })
      )

      local participantsAStr = ""
      local participantsBStr = ""
      local reservedSlotsCountA = 0
      local reservedSlotsCountB = 0
      let totalSlotsPerCommand = eventData?.slotsCount ?? 0
      let spaceStr = "          "

      local participantList = []
      if (eventData?.participant)
        participantList = u.isArray(eventData.participant) ? eventData.participant : [eventData.participant]

      let playerTeam = ::get_local_team_for_mpstats()
      foreach (participant in participantList) {
        let  participantPlayer = "player" in participant
            ? participant.player
          : (participant?.participantId ?? -1) >= 0
            ? get_mplayer_by_id(participant.participantId)
          : null
        if (!(participant?.image && participantPlayer))
          continue

        // Expected participant.image values are listed in "eventsIcons" block of hud.blk
        let icon = $"#ui/gameuiskin#{participant.image}"
        let color = $"@{::get_mplayer_color(participantPlayer)}"
        let pStr = this.makeSmallImageStr(icon, color)
        if (playerTeam == participantPlayer.team) {
          participantsAStr = "".concat(participantsAStr, pStr, " ")
          ++reservedSlotsCountA
        }
        else {
          participantsBStr = $" {pStr}{participantsBStr}"
          ++reservedSlotsCountB
        }
      }

      let freeSlotIconName = "#ui/gameuiskin#btn_help.svg"
      let freeSlotIconColor = "@minorTextColor"
      let freeSlotIconStr = this.makeSmallImageStr(freeSlotIconName, freeSlotIconColor, "small")
      for (local i = 0; i < totalSlotsPerCommand - reservedSlotsCountA; ++i)
        participantsAStr = "".concat(participantsAStr, freeSlotIconStr, " ")

      for (local i = 0; i < totalSlotsPerCommand - reservedSlotsCountB; ++i)
        participantsBStr = $" {freeSlotIconStr}{participantsBStr}"

      if (participantsAStr.len() > 0 && participantsBStr.len() > 0)
        res = "".concat(participantsAStr, spaceStr,
          loc("country/VS").tolower(), spaceStr, participantsBStr, "\n", res)

      return res
    }
  }

  UI_MESSAGE_HINT = {
    hintType = g_hud_hint_types.COMMON
    showEvent = "hint:ui_message:show"
    lifeTime = 3.0
    buildText = function(eventData) {
      local res = eventData?.locId
      if (!res)
        return ""
      res = loc(res)
      if (eventData?.param) {
        local param = eventData.param
        if (eventData?.paramTeamId)
          param = colorize(::get_team_color(eventData.paramTeamId), param)
        res = format(res, param)
      }
      if (eventData?.teamId && eventData.teamId > 0)
        res = colorize(::get_team_color(eventData.teamId), res)
      return res
    }
  }

  RESTORING_IN_HINT = {
    hintType = g_hud_hint_types.COMMON
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
    hintType = g_hud_hint_types.MISSION_ACTION_HINTS
    locId = "hints/torpedo_deadzone"
    showEvent = "hint:torpedo_deadzone:show"
    hideEvent = "hint:torpedo_deadzone:hide"
  }

  TORPEDO_BROKEN_HINT = {
    hintType = g_hud_hint_types.MISSION_ACTION_HINTS
    locId = "hints/torpedo_broken"
    showEvent = "hint:torpedo_broken:show"
    hideEvent = "hint:torpedo_broken:hide"
  }

  EXCEED_MAX_DEPTH_TO_LAUNCH = {
    hintType = g_hud_hint_types.COMMON
    showEvent = "hint:exceed_max_depth_to_launch"
    buildText = @(eventData) format(loc("hints/exceed_max_depth_to_launch"), eventData.maxDepth)
    totalCount = 2
    lifeTime = 5.0
  }

  SUBMARINE_DEPTH_CHANGE = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/submarine_depth_change"
    showEvent = "hint:submarine_depth_change"
    totalCount = 2
    lifeTime = 5.0
    shortcuts = [
      "submarine_depth_rangeMin"
      "submarine_depth_rangeMax"
    ]
  }

  SUBMARINE_PERISCOPE_DEPTH = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/submarine_periscope_depth"
    showEvent = "hint:submarine_periscope_depth"
    totalCount = 2
    getLocParams = @(hintData) { depth = hintData.depth }
    lifeTime = 5.0
    delayTime = 6.0
  }

  SUBMARINE_PERISCOPE_USE = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/submarine_periscope_use"
    showEvent = "hint:submarine_periscope_use"
    totalCount = 2
    lifeTime = 5.0
    delayTime = 12.0
  }

  SUBMARINE_TORPEDO_WRONG_DEPTH = {
    hintType = g_hud_hint_types.COMMON
    showEvent = "hint:submarine_torpedo_wrong_depth"
    buildText = @(eventData) format(loc("hints/submarine_torpedo_wrong_depth"), eventData.depth)
    lifeTime = 3.0
  }

  SUBMARINE_MINE_WRONG_DEPTH = {
    hintType = g_hud_hint_types.COMMON
    showEvent = "hint:submarine_torpedo_mine_depth"
    buildText = @(eventData) format(loc("hints/submarine_mine_wrong_depth"), eventData.depth)
    lifeTime = 3.0
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
    uid = 14
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

  REPLENISHMENT_IN_PROGRESS = {
    hintType = g_hud_hint_types.ACTIONBAR
    locId = "hints/replenishment_of_ammo_stowage"
    showEvent = "hint:replenishment_in_progress:show"
    hideEvent = "hint:replenishment_in_progress:hide"
    maskId = 13
    uid = 13
    totalCount = 5
    isSingleInNest = true
  }

  DROWNING_HINT = {
    hintType = g_hud_hint_types.COMMON
    showEvent = "hint:drowning:show"
    hideEvent = "hint:drowning:hide"
    buildText = function(eventData) {
      let res = " ".concat(loc("hints/drowning_in"), time.secondsToString(eventData?.timeTo ?? 0, false))
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
    buildText = function(eventData) {
      local res = g_hud_hints._buildText.call(this, eventData)
      if (eventData?.count)
        res = $"{res} {eventData.count}"
      return res
    }
  }

  MISFIRE_HINT = {
    hintType = g_hud_hint_types.ACTIONBAR
    locId = "hud_gun_breech_malfunction_misfire"
    showEvent = "hint:misfire:show"
    lifeTime = 5.0
  }

  MISSION_HINT            = genMissionHint(g_hud_hint_types.MISSION_STANDARD, isStandardMissionHint)
  MISSION_TUTORIAL_HINT   = genMissionHint(g_hud_hint_types.MISSION_TUTORIAL,
    @(hintTypeName) hintTypeName == MISSION_HINT_TYPE.TUTORIAL)
  MISSION_BOTTOM_HINT     = genMissionHint(g_hud_hint_types.MISSION_BOTTOM,
    @(hintTypeName) hintTypeName == MISSION_HINT_TYPE.BOTTOM)

  MISSION_BY_ID = {
    hintType = g_hud_hint_types.MISSION_STANDARD
    showEvent = "hint:missionHint:setById"
    hideEvent = "hint:missionHint:remove"
    lifeTime = 5.0
    priority = DEFAULT_MISSION_HINT_PRIORITY
    delayTime = 1.0

    isCurrent = @(eventData, _isHideEvent) !("hintType" in eventData) || isStandardMissionHint(eventData.hintType)
    getLocId = function(eventData) {
      return getTblValue("hintId", eventData, "hints/unknown")
    }
  }

  OBJECTIVE_ADDED = {
    hintType = g_hud_hint_types.MISSION_STANDARD
    showEvent = "hint:missionHint:objectiveAdded"
    hideEvent = "hint:missionHint:remove"
    locId = "hints/secondary_added"
    image = objectiveStatus.RUNNING.missionObjImg
    lifeTime = 5.0
    priority = DEFAULT_MISSION_HINT_PRIORITY

    isCurrent = @(eventData, _isHideEvent) !("hintType" in eventData) || isStandardMissionHint(eventData.hintType)
  }

  OBJECTIVE_SUCCESS = {
    hintType = g_hud_hint_types.MISSION_STANDARD
    showEvent = "hint:missionHint:objectiveSuccess"
    hideEvent = "hint:missionHint:remove"
    image = objectiveStatus.SUCCEED.missionObjImg
    lifeTime = 5.0
    priority = DEFAULT_MISSION_HINT_PRIORITY
    isShowedInVR = true

    isCurrent = @(eventData, _isHideEvent) !("hintType" in eventData) || isStandardMissionHint(eventData.hintType)

    getLocId = function(hintData) {
      let objType = getTblValue("objectiveType", hintData, OBJECTIVE_TYPE_SECONDARY)
      local result = ""
      if (objType == OBJECTIVE_TYPE_PRIMARY)
        result = "hints/objective_success"
      if (objType == OBJECTIVE_TYPE_SECONDARY)
        result = "hints/secondary_success"
      if (hintData.objectiveText != "")
        result = $"{result}_extended"
      return result
    }

    getLocParams = @(hintData) { missionObj = hintData.objectiveText }
  }

  OBJECTIVE_FAIL = {
    hintType = g_hud_hint_types.MISSION_STANDARD
    showEvent = "hint:missionHint:objectiveFail"
    hideEvent = "hint:missionHint:remove"
    image = objectiveStatus.FAILED.missionObjImg
    lifeTime = 5.0
    priority = DEFAULT_MISSION_HINT_PRIORITY
    isShowedInVR = true

    isCurrent = @(eventData, _isHideEvent) !("hintType" in eventData) || isStandardMissionHint(eventData.hintType)

    getLocId = function(hintData) {
      let objType = getTblValue("objectiveType", hintData, OBJECTIVE_TYPE_PRIMARY)
      local result = ""
      if (objType == OBJECTIVE_TYPE_PRIMARY)
        result = "hints/objective_fail"
      if (objType == OBJECTIVE_TYPE_SECONDARY)
        result = "hints/secondary_fail"
      if (hintData.objectiveText != "")
        result = $"{result}_extended"
      return result
    }

    getLocParams = @(hintData) { missionObj = hintData.objectiveText }
  }

  STOP_FOR_REPAIR = {
    hintType  = g_hud_hint_types.REPAIR
    locId     = "hints/stop_for_repair"
    showEvent = "hint:stop_for_repair"
    hideEvent = "hint:stop_for_repair_hide"
    lifeTime  = 5.0
  }

  REPAIR_BREACHES_OFFER = {
    hintType  = g_hud_hint_types.MISSION_ACTION_HINTS
    locId     = "hints/repair_breaches_offer"
    showEvent = "hint:repair_breaches_offer::show"
    hideEvent = "hint:repair_breaches_offer::hide"
    lifeTime  = 5.0
    shouldBlink = true
    getShortcuts = function(_data) {
      return g_hud_action_bar_type.REPAIR_BREACHES.getVisualShortcut()
    }
  }

  UNREPARIRABLE_BREACHES_WARNING = {
    hintType  = g_hud_hint_types.MISSION_ACTION_HINTS
    locId     = "hints/ship_unrepairable_breaches"
    showEvent = "hint:ship_unrepairable_breaches:show"
    hideEvent = "hint:ship_unrepairable_breaches:hide"
    lifeTime  = 15.0
    shouldBlink = true
    buildText = @(_data) colorize("@criticalTextColor", loc(this.locId))
  }

  UNDERWATERING_OFFER = {
    hintType  = g_hud_hint_types.MISSION_ACTION_HINTS
    locId     = "hints/underwatering_offer"
    showEvent = "hint:underwatering_offer::show"
    hideEvent = "hint:underwatering_offer::hide"
    lifeTime  = 5.0
    shouldBlink = true
    getShortcuts = function(_data) {
      return g_hud_action_bar_type.REPAIR_BREACHES.getVisualShortcut()
    }
  }

  SHIP_OFFER_REPAIR = {
    hintType  = g_hud_hint_types.MISSION_ACTION_HINTS
    locId     = "hints/ship_offer_repair"
    showEvent = "hint:ship_offer_repair::show"
    hideEvent = "hint:ship_offer_repair::hide"
    lifeTime  = 5.0
    shouldBlink = true
    getShortcuts = function(_data) {
      return g_hud_action_bar_type.TOOLKIT.getVisualShortcut()
    }
  }

  SHIP_OFFER_SHOW_HERO_MODULES = {
    hintType  = g_hud_hint_types.COMMON
    locId     = "hints/ship_offer_show_hero_modules"
    showEvent = "hint:ship_offer_show_hero_modules::show"
    hideEvent = "hint:ship_offer_show_hero_modules::hide"
    lifeTime  = 5.0
    totalCount = 3
  }

  SHIP_OFFER_SMOKE_SCREEN = {
    hintType  = g_hud_hint_types.COMMON
    locId     = "hints/ship_offer_smoke_screen"
    showEvent = "hint:ship_offer_smoke_screen::show"
    hideEvent = "hint:ship_offer_smoke_screen::hide"
    lifeTime  = 5.0
    totalCount = 3
  }

  SHIP_BRIDGE_DESTROYED = {
    hintType  = g_hud_hint_types.COMMON
    locId     = "hints/ship_bridge_destroyed"
    showEvent = "hint:ship_bridge_destroyed"
    lifeTime  = 5.0
    totalCount = 3
  }

  SHIP_TRIGGER_GROUP_IN_DEAD_ZONE = {
    hintType  = g_hud_hint_types.COMMON
    locId     = "hints/ship_trigger_group_in_dead_zone"
    showEvent = "hint:ship_trigger_group_in_dead_zone::show"
    hideEvent = "hint:ship_trigger_group_in_dead_zone::hide"
    lifeTime  = 5.0
    totalCount = 3
  }

  SHIP_SOME_WEAPONS_IN_DEAD_ZONE = {
    hintType  = g_hud_hint_types.COMMON
    locId     = "hints/ship_some_weapons_in_dead_zone"
    showEvent = "hint:ship_some_weapons_in_dead_zone::show"
    hideEvent = "hint:ship_some_weapons_in_dead_zone::hide"
    lifeTime  = 5.0
    totalCount = 3
  }

  BUILDING_EXIT_HINT = {
    hintType = g_hud_hint_types.COMMON
    locId = "HUD/TXT_BUILDING_EXIT"
    noKeyLocId = "HUD/TXT_BUILDING_EXIT_NOKEY"
    shortcuts = "ID_TOGGLE_CONSTRUCTION_MODE"
    showEvent = "hint:building_exit:show"
    hideEvent = "hint:building_exit:hide"
    shouldBlink = true
    delayTime = 1.0
  }

  BUILDING_FORBIDDEN_OBSTACLES = {
    hintType = g_hud_hint_types.COMMON
    locId = "HUD/TXT_BUILDING_FORBIDDEN_OBSTACLES"
    showEvent = "hint:building_forbidden_obstacles:show"
    shouldBlink = false
    lifeTime = 5.0
  }

  BUILDING_FORBIDDEN_SLOPE = {
    hintType = g_hud_hint_types.COMMON
    locId = "HUD/TXT_BUILDING_FORBIDDEN_SLOPE"
    showEvent = "hint:building_forbidden_slope:show"
    shouldBlink = false
    lifeTime = 5.0
  }

  BUILDING_FORBIDDEN_RANGE = {
    hintType = g_hud_hint_types.COMMON
    locId = "HUD/TXT_BUILDING_FORBIDDEN_RANGE"
    showEvent = "hint:building_forbidden_range:show"
    shouldBlink = false
    lifeTime = 5.0
  }

  OFFER_REPAIR = {
    hintType = g_hud_hint_types.REPAIR
    getLocId = function (data) {
      let hudUnitType = getHudUnitType()
      if (getTblValue("assist", data, false)) {
        if (hudUnitType == HUD_UNIT_TYPE.TANK)
          return "hints/repair_assist_tank_hold"
        if (hudUnitType == HUD_UNIT_TYPE.SHIP || hudUnitType == HUD_UNIT_TYPE.SHIP_EX)
          return "hints/repair_assist_ship_hold"
        return "hints/repair_assist_plane_hold"
      }
      if (getTblValue("request", data, false)) {
        return "hints/repair_request_assist_hold"
      }
      else if (getTblValue("cancelRequest", data, false)) {
        return "hints/repair_cancel_request_assist_hold"
      }
      if (hudUnitType == HUD_UNIT_TYPE.HUMAN)
        return "hints/repair_human_hold"
      return (hudUnitType == HUD_UNIT_TYPE.SHIP || hudUnitType == HUD_UNIT_TYPE.SHIP_EX)
        ? "hints/repair_ship" : "hints/repair_tank_hold"
    }

    noKeyLocId = "hints/repair_request_assist_hold_no_key"
    getShortcuts =  function(_data) {
      let hudUnitType = getHudUnitType()
      return hudUnitType == HUD_UNIT_TYPE.SHIP || hudUnitType == HUD_UNIT_TYPE.SHIP_EX
        ? g_hud_action_bar_type.TOOLKIT.getVisualShortcut()
        : hudUnitType == HUD_UNIT_TYPE.HUMAN ? "ID_REPAIR_HUMAN"
        //


        : "ID_REPAIR_TANK"
    }
    showEvent = "tankRepair:offerRepair"
    hideEvent = "tankRepair:cantRepair"
  }

  AMMO_DESTROYED = {
    hintType = g_hud_hint_types.MISSION_ACTION_HINTS
    locId = "hints/ammo_destroyed"
    showEvent = "hint:ammoDestroyed:show"
    priority = CATASTROPHIC_HINT_PRIORITY
    lifeTime = 5.0
  }

  WEAPON_TYPE_UNAVAILABLE = {
    hintType = g_hud_hint_types.MISSION_ACTION_HINTS
    locId = "hints/weapon_type_unavailable"
    showEvent = "hint:weaponTypeUnavailable:show"
    lifeTime = 3.0
  }

  NO_BULLETS = {
    hintType = g_hud_hint_types.MISSION_ACTION_HINTS
    locId = "hints/have_not_bullets"
    showEvent = "hint:no_bullets"
    lifeTime = 5.0
    priority = CATASTROPHIC_HINT_PRIORITY
  }

  SHIP_NO_ROCKETS = {
    hintType = g_hud_hint_types.MISSION_ACTION_HINTS
    locId = "hints/ship_has_no_rockets"
    showEvent = "hint:ship_no_rockets"
    lifeTime = 5.0
    priority = CATASTROPHIC_HINT_PRIORITY
  }

  REQUEST_REPAIR_HELP_HINT = {
    hintType = g_hud_hint_types.REPAIR
    locId     = "hints/request_repair_help"
    showEvent = "hint:request_repair_help"
    lifeTime = 5.0
  }

  NO_POTENTIAL_ASSISTANT = {
    hintType = g_hud_hint_types.REPAIR
    locId     = "hints/no_potential_assistant"
    showEvent = "hint:no_potential_assistant"
    lifeTime = 5.0
  }

  HAVE_POTENTIAL_ASSISTEE = {
    hintType = g_hud_hint_types.REPAIR
    locId     = "hints/have_potential_assistee"
    showEvent = "hint:have_potential_assistee"
    hideEvent = "hint:hide_potential_assistee_hint"
    lifeTime = 3.0
  }

  FRIENDLY_FIRE_WARNING = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/friendly_fire_warning"
    showEvent = "hint:friendly_fire_warning"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  NEED_STOP_FOR_FIRE = {
    hintType = g_hud_hint_types.COMMON
    locId     = "hints/need_stop_for_fire"
    showEvent = "hint:need_stop_for_fire"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  NEED_STOP_FOR_HULL_AIMING = {
    hintType = g_hud_hint_types.COMMON
    locId     = "hints/need_stop_for_hull_aiming"
    showEvent = "hint:need_stop_for_hull_aiming:show"
    hideEvent = "hint:need_stop_for_hull_aiming:hide"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  HULL_AIMING_WITH_CAMERA = {
    hintType = g_hud_hint_types.COMMON
    locId     = "hints/hull_aiming_with_camera"
    showEvent = "hint:hull_aiming_with_camera:show"
    hideEvent = "hint:hull_aiming_with_camera:hide"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  STOP_TERRAFORM_FOR_HULL_AIMING = {
    hintType = g_hud_hint_types.COMMON
    locId     = "hints/stop_terraform_for_hull_aiming"
    showEvent = "hint:stop_terraform_for_hull_aiming"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  NEED_STOP_FOR_TERRAFORM = {
    hintType = g_hud_hint_types.COMMON
    locId     = "hints/need_stop_for_terraform"
    showEvent = "hint:need_stop_for_terraform"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  WAIT_LAUNCHER = {
    hintType = g_hud_hint_types.COMMON
    locId     = "hints/wait_launcher_ready"
    showEvent = "hint:wait_launcher_ready"
    hideEvent = "hint:wait_launcher_ready_hide"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  FPS_TO_VIRTUAL_FPS_HINT = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/fps_to_virtual_fps"
    showEvent = "hint:fps_to_virtual_fps:show"
    hideEvent = "hint:fps_to_virtual_fps:hide"
    lifeTime = -1.0
  }

  ATGM_NO_LINE_OF_SIGHT = {
    hintType = g_hud_hint_types.ACTIONBAR
    locId = "hints/atgm_no_line_of_sight"
    showEvent = "hint:atgm_no_line_of_sight:show"
    hideEvent = "hint:atgm_no_line_of_sight:hide"
    shouldBlink = true
  }

  COMMANDER_VIEW_WITH_NV_ON = {
    hintType = g_hud_hint_types.ACTIONBAR
    locId     = "hints/commander_view_with_nv_on"
    showEvent = "hint:commander_view_with_nv_on:show"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  COMMANDER_IS_UNCONSCIOUS = {
    hintType = g_hud_hint_types.COMMON
    locId     = "hints/commander_is_unconscious"
    showEvent = "hint:commander_is_unconscious:show"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  VERY_FEW_CREW = {
    hintType = g_hud_hint_types.MISSION_ACTION_HINTS
    locId = "hints/is_very_few_crew"
    showEvent = "hint:very_few_crew:show"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  SUPPORT_PLANE_OFFER = {
    hintType = g_hud_hint_types.MISSION_ACTION_HINTS
    locId = "hints/support_plane_offer"
    showEvent = "hint:support_plane_offer:show"
    hideEvent = "hint:support_plane_offer:hide"
    lifeTime = 5.0
    totalCount = 3
    isHideOnDeath = true
  }

  SHOT_FREQUENCY_CHANGED = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/shot_frequency_changed"
    showEvent = "hint:shot_frequency_changed:show"
    lifeTime = 5.0
    isHideOnDeath = true
    getLocParams = @(hintData) { shotFreq = loc($"hints/shotFreq/{hintData.shotFreq}") }
  }

  CHANGE_BULLET_TYPE_FOR_SET = {
    hintType = g_hud_hint_types.ACTIONBAR
    locId = "hints/change_bullet_type_for_set"
    showEvent = "hint:change_bullet_type_for_set"
    totalCount = 8
    lifeTime = 4.0
    isHideOnDeath = true
  }

  IRCM_FAIL_GUIDANCE = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/ircm_fail_guidance"
    showEvent = "hint:ircm_fail_guidance:show"
    lifeTime = 1.0
    isHideOnDeath = true
  }

  NUCLEAR_KILLSTREAK_REACH_AREA = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/reach_battlearea_to_activate_the_bomb"
    showEvent = "hint:nuclear_killstreak_reach_area:show"
    hideEvent = "hint:nuclear_killstreak_reach_area:hide"
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
  }

  NUCLEAR_KILLSTREAK_DROP_BOMB = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/drop_the_bomb"
    showEvent = "hint:nuclear_killstreak_drop_the_bomb:show"
    hideEvent = "hint:nuclear_killstreak_drop_the_bomb:hide"
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
  }

  WAIT_FOR_AIMING = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/wait_for_aiming"
    showEvent = "hint:wait_for_aiming"
    lifeTime = 3.0
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
  }

  EXTINGUISH_ASSIST = {
    hintType = g_hud_hint_types.REPAIR
    locId = "hints/extinguish_assist"
    showEvent = "hint:have_potential_fire_assistee"
    hideEvent = "hint:hide_potential_fire_assistee_hint"
    getShortcuts =  function(_data) {
      return g_hud_action_bar_type.EXTINGUISHER.getVisualShortcut()
    }
  }

  NO_POTENTIAL_FIRE_ASSISTANT = {
    hintType = g_hud_hint_types.REPAIR
    locId     = "hints/no_potential_fire_assistant"
    showEvent = "hint:no_potential_fire_assistant"
    lifeTime = 5.0
  }

  REQUEST_EXTINGUISH_HELP_DONT_MOVE = {
    hintType = g_hud_hint_types.REPAIR
    locId     = "hints/request_extinguish_dont_move"
    showEvent = "hint:request_extinguish_dont_move"
    lifeTime = 5.0
  }

  REQUEST_EXTINGUISH_HELP_HINT = {
    hintType = g_hud_hint_types.REPAIR
    getLocId = function (data) {
      if (getTblValue("request", data, false)) {
        return "hints/request_extinguish_help"
      }
      else if (getTblValue("cancelRequest", data, false)) {
        return "hints/request_extinguish_help_cancel"
      }
      return ""
    }
    noKeyLocId = "hints/request_extinguish_help_no_key"
    showEvent = "hint:request_extinguish_help"
    hideEvent = "hint:request_extinguish_help_hide"
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
    getShortcuts =  function(_data) {
      return g_hud_action_bar_type.EXTINGUISHER.getVisualShortcut()
    }
  }

  SUPPORT_PLANE_IN_DEAD_ZONE = {
    hintType = g_hud_hint_types.MISSION_ACTION_HINTS
    locId     = "hints/support_plane_in_dead_zone"
    showEvent = "hint:support_plane_in_dead_zone"
    lifeTime = 3.0
  }

  OWNED_UNIT_DEAD = {

    locId = "hints/return_after_owned_unit_dead"
    showEvent = "hint:owned_unit_dead:show"

    selfRemove = true
    isVerticalAlignText = true
    buildText = function (data) {
      return " ".concat(g_hud_hints._buildText.call(this, data), g_hint_tag.TIMER.makeFullTag())
    }
  }

  OWNER_IN_FIRE = {
    hintType = g_hud_hint_types.COMMON
    getLocId = @(hintData)
      hintData?.isTank ? "hints/owner_tank_in_fire" : "hints/owner_ship_in_fire"
    showEvent = "hint:owner_in_fire:show"
    lifeTime = 5.0
  }

  OWNER_CRIT_BUOYANCY = {
    hintType = g_hud_hint_types.COMMON
    locId     = "hints/owner_critical_buoyancy"
    showEvent = "hint:owner_crit_buoyancy:show"
    lifeTime = 5.0
  }

  OWNER_TORPEDO_ALERT = {
    hintType = g_hud_hint_types.COMMON
    locId     = "hints/owner_torpedo_alert"
    showEvent = "hint:owner_torpedo_alert:show"
    hideEvent = "hint:owner_torpedo_alert:hide"
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
  }

  CATAPULT_BROKEN = {
    hintType = g_hud_hint_types.MISSION_ACTION_HINTS
    locId     = "my_dmg_msg/catapult"
    showEvent = "hint:catapult_is_broken:show"
    lifeTime = 5.0
  }

  SUPPORT_PLANE_BROKEN = {
    hintType = g_hud_hint_types.MISSION_ACTION_HINTS
    locId     = "my_dmg_msg/aircraft"
    showEvent = "hint:support_plane_is_broken:show"
    lifeTime = 5.0
  }

  UAV_LAUNCH_BLOCKED = {
    hintType = g_hud_hint_types.COMMON
    locId     = "hints/uav_launch_blocked"
    showEvent = "hint:uav_launch_blocked"
    lifeTime = 5.0
  }

  ALLOW_SMOKE_SCREEN = {
    hintType = g_hud_hint_types.COMMON
    locId     = "hints/allow_smoke_screen"
    noKeyLocId = "hints/allow_smoke_screen_nokey"
    showEvent = "hint:allow_smoke_screen:show"
    shortcuts = "ID_PLANE_SMOKE_SCREEN_GENERATOR"
    lifeTime = 10.0
    shouldBlink = true
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = false
    getLocParams = @(hintData) {
      minAlt = hintData.minAlt
      maxAlt = hintData.maxAlt
    }
  }

  SAY_THANKS_OFFER = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/say_thanks_offer"
    getNoKeyLocId = @() isXInputDevice()
      ? "hints/say_thanks_offer_nokey/xinput"
      : "hints/say_thanks_offer_nokey"
    showEvent = "hint:say_thanks_offer:show"
    hideEvent = "hint:say_thanks_offer:hide"
    getShortcuts = @(_) isXInputDevice()
      ? "ID_SHOW_MULTIFUNC_WHEEL_MENU"
      : "ID_SHOW_VOICE_MESSAGE_LIST"
    lifeTime = 5.0
  }

  SAY_SORRY_OFFER = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/say_sorry_offer"
    getNoKeyLocId = @() isXInputDevice()
      ? "hints/say_sorry_offer_nokey/xinput"
      : "hints/say_sorry_offer_nokey"
    showEvent = "hint:say_sorry_offer:show"
    hideEvent = "hint:say_sorry_offer:hide"
    getShortcuts = @(_) isXInputDevice()
      ? "ID_SHOW_MULTIFUNC_WHEEL_MENU"
      : "ID_SHOW_VOICE_MESSAGE_LIST"
    lifeTime = 5.0
  }

  ACCEPT_SORRY_OFFER = {
    hintType = g_hud_hint_types.REPAIR // must be visible in cutscene (killcam)
    locId = "hints/accept_sorry"
    getNoKeyLocId = @() isXInputDevice()
      ? "hints/accept_sorry_nokey/xinput"
      : "hints/accept_sorry_nokey"
    showEvent = "hint:accept_sorry:show"
    hideEvent = "hint:accept_sorry:hide"
    getShortcuts = @(_) isXInputDevice()
      ? "ID_SHOW_MULTIFUNC_WHEEL_MENU"
      : "ID_SHOW_VOICE_MESSAGE_LIST"
    isHideOnDeath = false
    isHideOnWatchedHeroChanged = false
    lifeTime = 5.0
    getLocParams = @(hintData) {
      killer = hintData.killerNick
    }
  }

  AWAIT_SORRY = {
    hintType = g_hud_hint_types.REPAIR // should be same as ACCEPT_SORRY_OFFER
    locId     = "hints/await_sorry"
    showEvent = "hint:await_sorry:show"
    hideEvent = "hint:await_sorry:hide"
    isHideOnDeath = false
    isHideOnWatchedHeroChanged = false
    lifeTime = 5.0
  }

  SHOT_FAILED_APS_WORKING = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/shot_failed_aps_working"
    showEvent = "hint:shot_failed_aps_working:show"
    lifeTime = 3.0
    isHideOnDeath = true
  }

  ALLOW_COMMANDER_AIM_MODE = {
    hintType = g_hud_hint_types.ACTIONBAR
    locId     = "hints/allow_commander_aim_mode"
    noKeyLocId = "hints/allow_commander_aim_mode_nokey"
    showEvent = "hint:allow_commander_aim_mode:show"
    shouldBlink = true
    lifeTime = 10.0
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
    shortcuts = "ID_COMMANDER_AIM_MODE"
  }

  CANT_SPAWN_UGV = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/cant_spawn_ugv"
    showEvent = "hint:cant_spawn_ugv:show"
    lifeTime = 3.0
    isHideOnDeath = true
  }

  CANT_SPAWN_UNLIM_CTRL = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/cant_spawn_unlim_ctrl"
    showEvent = "hint:cant_spawn_unlim_ctrl:show"
    lifeTime = 3.0
    isHideOnDeath = true
  }

  KILL_STREAK_FIGHTER_REVERTED = {
    hintType = g_hud_hint_types.MISSION_ACTION_HINTS
    locId = "hints/kill_streak_fighter_reverted"
    showEvent = "hint:kill_streak_fighter_reverted"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  NOT_IN_BURAV_CTRL_RADIUS = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/not_in_burav_ctrl_radius"
    showEvent = "hint:not_in_burav_ctrl_radius"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  BURAV_CTRL_BY_OTHER = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/burav_ctrl_by_other_player"
    showEvent = "hint:burav_ctrl_by_other_player"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  BURAV_TARGET_NOT_IN_BATTLE_AREA = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/burav_target_not_in_battle_area"
    showEvent = "hint:burav_target_not_in_battle_area"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  BURAV_TARGET_NOT_IN_CTRL_RADIUS = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/burav_target_not_ctrl_radius"
    showEvent = "hint:burav_target_not_ctrl_radius"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  ROCKET_LAUNCHER_IN_WATER = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/rocket_launcher_in_water"
    showEvent = "hint:rocket_launcher_in_water"
    lifeTime = 5.0
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
  }

  BURAV_IN_DELAY = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/burav_in_delay"
    showEvent = "hint:burav_in_delay:show"
    hideEvent = "hint:burav_in_delay:hide"
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
  }

  BURAV_ENEMY_CTRL = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/burav_ctrl_by_enemy"
    showEvent = "hint:burav_ctrl_by_enemy:show"
    lifeTime = 5.0
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
  }

  BURAV_ALLY_CTRL = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/burav_ctrl_by_ally"
    showEvent = "hint:burav_ctrl_by_ally:show"
    lifeTime = 5.0
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
  }

  BURAV_CONTROLING = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/burav_controlling"
    showEvent = "hint:burav_controlling:show"
    hideEvent = "hint:burav_controlling:hide"
    lifeTime = 5.0
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
  }

  BURAV_IN_DELAY_CLICK = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/burav_in_delay_click"
    showEvent = "hint:burav_in_delay_click"
    lifeTime = 5.0
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
  }

  PLANE_CAN_REPAIR_ASSIST = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/plane_can_repair_assist"
    showEvent = "hint:plane_can_repair_assist"
    lifeTime = 10.0
    totalCount = 5
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
  }

  PLANE_HAVE_POTENTIAL_ASSISTEE = {
    hintType = g_hud_hint_types.REPAIR
    locId     = "hints/plane_have_potential_assistee"
    showEvent = "hint:plane_have_potential_assistee"
    lifeTime = 3.0
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
  }

  TARGET_LOCK_SENSOR_DISABLED = {
    hintType = g_hud_hint_types.MISSION_ACTION_HINTS
    showEvent = "hint:target_lock_sensor_disabled"
    locId = "hints/target_lock_sensor_disabled"
    //noKeyLocId = "hints/target_lock_sensor_disabled_nokey"
    getShortcuts = @(_data)
        getHudUnitType() == HUD_UNIT_TYPE.AIRCRAFT ? "ID_SENSOR_SWITCH"
        : getHudUnitType() == HUD_UNIT_TYPE.TANK ? "ID_SENSOR_SWITCH_TANK"
        : getHudUnitType() == HUD_UNIT_TYPE.SHIP ? "ID_SENSOR_SWITCH_SHIP"
        : getHudUnitType() == HUD_UNIT_TYPE.HUMAN ? "ID_SENSOR_SWITCH_HUMAN"
        : getHudUnitType() == HUD_UNIT_TYPE.HELICOPTER ? "ID_SENSOR_SWITCH_HELICOPTER"
        : ""
    lifeTime = 5.0
    isHideOnDeath = true
  }

  TARGET_LOCK_SENSOR_DAMAGED = {
    hintType = g_hud_hint_types.REPAIR
    locId     = "hints/target_lock_sensor_damaged"
    showEvent = "hint:target_lock_sensor_damaged"
    lifeTime = 5.0
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
  }

  DISABLE_NIGHT_VISION_ON_DAYLIGHT = {
    hintType = g_hud_hint_types.COMMON
    locId = "hints/disable_night_vision_on_daylight"
    showEvent = "hint:disable_night_vision_on_daylight:show"
    hideEvent = "hint:disable_night_vision_on_daylight:hide"
    getShortcuts = @(_data)
      getHudUnitType() == HUD_UNIT_TYPE.TANK ? "ID_TANK_NIGHT_VISION"
      : getHudUnitType() == HUD_UNIT_TYPE.HUMAN ? "ID_HUMAN_NIGHT_VISION"
      : getHudUnitType() == HUD_UNIT_TYPE.HELICOPTER ? "ID_HELI_GUNNER_NIGHT_VISION"
      : "ID_PLANE_NIGHT_VISION"
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
  }

  HOW_TO_USE_BINOCULAR = {
    hintType = g_hud_hint_types.COMMON
    showEvent = "hint:how_to_use_binocular"
    hideEvent = "hint:how_to_use_binocular_2"
    locId = "hints/how_to_use_binocular"
    lifeTime = 8.0
    shortcuts = "ID_CAMERA_BINOCULARS"
    isWrapInRowAllowed = true
    uid = 11229
    totalCount=3
    secondsOfForgetting=90*(3600*24)
  }

  HOW_TO_USE_BINOCULAR_2 = {
    hintType = g_hud_hint_types.COMMON
    showEvent = "hint:how_to_use_binocular_2"
    locId = "hints/how_to_use_binocular_2"
    shortcuts = [
      "ID_FIRE_GM_MACHINE_GUN"
      "ID_FIRE_MGUNS"
    ]
    isWrapInRowAllowed = true
    lifeTime = 8.0
    delayTime = 0
  }
  HOW_TO_USE_RANGE_FINDER = {
    hintType = g_hud_hint_types.COMMON
    showEvent = "hint:how_to_use_range_finder"
    hideEvent = "hint:how_to_use_range_finder_2"
    locId = "hints/how_to_use_range_finder"
    lifeTime = 8.0
    shortcuts = "ID_RANGEFINDER"
    uid = 11231
    totalCount=3
    secondsOfForgetting=90*(3600*24)
  }
  HOW_TO_USE_RANGE_FINDER_2 = {
    hintType = g_hud_hint_types.COMMON
    showEvent = "hint:how_to_use_range_finder_2"
    locId = "hints/how_to_use_range_finder_2"
    lifeTime = 8.0
    shortcuts = ""
  }
  HOW_TO_USE_LASER_RANGE_FINDER = {
    hintType = g_hud_hint_types.COMMON
    showEvent = "hint:how_to_use_laser_range_finder"
    hideEvent = "hint:how_to_use_laser_range_finder_2"
    locId = "hints/how_to_use_laser_range_finder"
    lifeTime = 8.0
    shortcuts = "ID_RANGEFINDER"
    uid = 11233
    totalCount=3
    secondsOfForgetting=90*(3600*24)
  }
  HOW_TO_USE_LASER_RANGE_FINDER_2 = {
    hintType = g_hud_hint_types.COMMON
    showEvent = "hint:how_to_use_laser_range_finder_2"
    locId = "hints/how_to_use_laser_range_finder_2"
    lifeTime = 8.0
  }
  HOW_TO_TRACK_RADAR_TARGET_IN_TPS = {
    hintType = g_hud_hint_types.COMMON
    showEvent = "hint:how_to_track_radar_target_in_tps"
    hideEvent = "hint:how_to_track_radar_target_in_optic"
    locId = "hints/how_to_track_radar_target_in_tps"
    lifeTime = 5.0
    shortcuts = "ID_TOGGLE_VIEW_GM"
    uid = 11235
    totalCount=3
    secondsOfForgetting=90*(3600*24)
  }
  HOW_TO_TRACK_RADAR_TARGET_IN_OPTIC = {
    hintType = g_hud_hint_types.COMMON
    showEvent = "hint:how_to_track_radar_target_in_optic"
    locId = "hints/how_to_track_radar_target_in_optic"
    lifeTime = 5.0
    shortcuts = ""
    uid = 11236
    totalCount=3
    secondsOfForgetting=90*(3600*24)
  }
  HOW_TO_ENGINE_SMOKE_SCREEN_SYSTEM = {
    hintType = g_hud_hint_types.COMMON
    showEvent = "hint:how_to_engine_smoke_screen_system"
    hideEvent = "hint:how_to_engine_smoke_screen_system_2"
    locId = "hints/how_to_engine_smoke_screen_system"
    lifeTime = 7.0
    shortcuts = "ID_SMOKE_SCREEN_GENERATOR"
    uid = 11237
    totalCount=3
    secondsOfForgetting=90*(3600*24)
  }
  HOW_TO_ENGINE_SMOKE_SCREEN_SYSTEM_2 = {
    hintType = g_hud_hint_types.COMMON
    showEvent = "hint:how_to_engine_smoke_screen_system_2"
    locId = "hints/how_to_engine_smoke_screen_system_2"
    lifeTime = 7.0
    shortcuts = ""
  }
  HOW_TO_SMOKE_SCREEN_GRENADE = {
    hintType = g_hud_hint_types.COMMON
    showEvent = "hint:how_to_smoke_screen_grenade"
    hideEvent = "hint:how_to_smoke_screen_grenade_2"
    locId = "hints/how_to_smoke_screen_grenade"
    lifeTime = 7.0
    shortcuts = "ID_SMOKE_SCREEN"
    uid = 11239
    totalCount=3
    secondsOfForgetting=90*(3600*24)
  }
  HOW_TO_SMOKE_SCREEN_GRENADE_2 = {
    hintType = g_hud_hint_types.COMMON
    showEvent = "hint:how_to_smoke_screen_grenade_2"
    locId = "hints/how_to_smoke_screen_grenade_2"
    lifeTime = 7.0
    shortcuts = ""
  }
  HOW_TO_USE_TV_OPTICAL_GUIDED_AGM_1 = {
    hintType = g_hud_hint_types.COMMON
    showEvent = "hint:how_to_use_tv_optical_guided_agm_1"
    hideEvent = ["hint:how_to_use_tv_optical_guided_agm_2", "hint:how_to_use_tv_optical_guided_agm_3"]
    getLocId = @(hintData) hintData?.is_agm ? "hints/how_to_use_tv_optical_guided_agm_1" : "hints/how_to_use_tv_optical_guided_bomb_1"
    getLocParams = @(hintData) {
      fire_shortcut = hintData.fire_shortcut
      lock_shortcut = hintData.lock_shortcut
    }
    lifeTime = 8.0
    shortcuts = ""
    isWrapInRowAllowed = true
    uid = 11244
    totalCount=3
    secondsOfForgetting=90*(3600*24)
  }
  HOW_TO_USE_TV_OPTICAL_GUIDED_AGM_2 = {
    hintType = g_hud_hint_types.COMMON
    showEvent = "hint:how_to_use_tv_optical_guided_agm_2"
    hideEvent = "hint:how_to_use_tv_optical_guided_agm_3"
    getLocId = @(hintData) hintData?.is_agm ? "hints/how_to_use_tv_optical_guided_agm_2" : "hints/how_to_use_tv_optical_guided_bomb_2"
    getLocParams = @(hintData) {
      fire_shortcut = hintData.fire_shortcut
      lock_shortcut = hintData.lock_shortcut
    }
    lifeTime = 8.0
    shortcuts = ""
    isWrapInRowAllowed = true
    uid = 11245
    totalCount=3
    secondsOfForgetting=90*(3600*24)
  }
  HOW_TO_USE_TV_OPTICAL_GUIDED_AGM_3 = {
    hintType = g_hud_hint_types.COMMON
    showEvent = "hint:how_to_use_tv_optical_guided_agm_3"
    hideEvent = "hint:how_to_use_tv_optical_guided_agm_2"
    getLocId = @(hintData) hintData?.is_agm ? "hints/how_to_use_tv_optical_guided_agm_3" : "hints/how_to_use_tv_optical_guided_bomb_3"
    getLocParams = @(hintData) {
      fire_shortcut = hintData.fire_shortcut
      lock_shortcut = hintData.lock_shortcut
    }
    lifeTime = 8.0
    shortcuts = ""
    isWrapInRowAllowed = true
    uid = 11246
    totalCount=3
    secondsOfForgetting=90*(3600*24)
  }

  AUTO_EMERGENCY_SURFACING = {
    hintType = g_hud_hint_types.REPAIR
    locId     = "hints/auto_emergency_surfacing"
    showEvent = "hint:auto_emergency_surfacing"
    lifeTime = 5.0
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
    shouldBlink = true
  }

  SHIP_DEPTH_CHARGE_SALVO = {
    hintType = g_hud_hint_types.COMMON
    showEvent = "hint:ship_depth_charge_salvo"
    locId = "hints/ship_depth_charge_salvo"
    lifeTime = 5.0
    totalCount=2
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
  }


  SACLOS_GUIDANCE_MODE_AUTO = {
    hintType = g_hud_hint_types.COMMON
    showEvent = "hint:saclos_guidance_mode_auto"
    locId = "hints/saclos_guidance_mode_auto"
    hideEvent = "hint:saclos_guidance_mode_direct"
    lifeTime = 5.0
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
  }
  SACLOS_GUIDANCE_MODE_DIRECT = {
    hintType = g_hud_hint_types.COMMON
    showEvent = "hint:saclos_guidance_mode_direct"
    locId = "hints/saclos_guidance_mode_direct"
    hideEvent = "hint:saclos_guidance_mode_lead"
    lifeTime = 5.0
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
  }
  SACLOS_GUIDANCE_MODE_LEAD = {
    hintType = g_hud_hint_types.COMMON
    showEvent = "hint:saclos_guidance_mode_lead"
    locId = "hints/saclos_guidance_mode_lead"
    hideEvent = "hint:saclos_guidance_mode_auto"
    lifeTime = 5.0
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
  }


  SUBMARINE_CANT_DIVE = {
    hintType = g_hud_hint_types.REPAIR
    locId     = "hints/submarine_cant_dive"
    showEvent = "hint:submarine_cant_dive"
    lifeTime = 5.0
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
    shouldBlink = true
  }

  SUBMARINE_CANT_SURFACING = {
    hintType = g_hud_hint_types.REPAIR
    locId     = "hints/submarine_cant_surfacing"
    showEvent = "hint:submarine_cant_surfacing"
    lifeTime = 5.0
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
    shouldBlink = true
  }

  SUBMARINE_EMERGENCY_SURFACING = {
    hintType = g_hud_hint_types.COMMON
    locId     = "hints/submarine_emergency_sufracing"
    showEvent = "hint:submarine_emergency_sufracing"
    lifeTime = 5.0
    totalCount = 2
    isHideOnDeath = true
  }

  SUBMARINE_CANT_SUBMERGE_TANKS_DESTROYED = {
    hintType = g_hud_hint_types.COMMON
    locId     = "hints/submarine_cant_submerge_tanks_destroyed"
    showEvent = "hint:submarine_cant_submerge_tanks_destroyed"
    lifeTime = 5.0
    totalCount = 2
    isHideOnDeath = true
  }

  SUBMARINE_CANT_SURFACE_ONLY_EMERGENCY = {
    hintType = g_hud_hint_types.COMMON
    locId     = "hints/submarine_cant_surface_only_emergecy"
    showEvent = "hint:submarine_cant_surface_only_emergecy"
    lifeTime = 5.0
    totalCount = 2
    isHideOnDeath = true
  }

  SUBMARINE_FULL_REPAIR_ONLY_ON_SURFACE = {
    hintType = g_hud_hint_types.COMMON
    locId     = "hints/submarine_full_repair_only_on_surface"
    showEvent = "hint:submarine_full_repair_only_on_surface"
    lifeTime = 5.0
    totalCount = 2
    isHideOnDeath = true
  }

  SUBMARINE_NOISE_LEVEL = {
    hintType = g_hud_hint_types.COMMON
    locId     = "hints/submarine_noise_level"
    showEvent = "hint:submarine_noise_level"
    lifeTime = 15.0
    totalCount=2
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
  }

  RAGE_SCANNER_ACTIVE = {
    hintType = g_hud_hint_types.COMMON
    locId     = "hints/rage_scanner_active"
    showEvent = "hint:rage_scanner_active"
    lifeTime = 5.0
    totalCount=2
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
  }

  RANGEFINDER_DAMAGED = {
    hintType = g_hud_hint_types.COMMON
    locId     = "hints/rangefinder_damaged"
    showEvent = "hint:rangefinder_damaged"
    lifeTime = 5.0
  }

  NIGHT_VISION_DAMAGED = {
    hintType = g_hud_hint_types.COMMON
    locId     = "hints/night_vision_damaged"
    showEvent = "hint:night_vision_damaged"
    lifeTime = 5.0
  }

  AUTOLOADER_DAMAGED = {
    hintType = g_hud_hint_types.COMMON
    locId     = "hints/autoloader_damaged"
    showEvent = "hint:autoloader_damaged"
    lifeTime = 5.0
  }

  KILL_STREAK_SAFE_EXIT = {
    hintType = g_hud_hint_types.COMMON
    getLocId = function(_hintData) {
      return getHudUnitType() == HUD_UNIT_TYPE.HELICOPTER
        ? "hints/kill_streak_safe_exit_helicopter"
        : "hints/kill_streak_safe_exit"
    }
    showEvent = "hint:kill_streak_safe_exit"
  }

  KILL_STREAK_REWARD = {
    getHintNestId = @() "hud_messages_reward_messages"
    getLocId = @(hintData) $"hints/kill_streak_reward_{hintData.streakType}"
    getLocParams = @(hintData) { points = hintData.points }
    showEvent = "hint:kill_streak_reward"
    lifeTime = 5.0
    isHideOnDeath = false
    isHideOnWatchedHeroChanged = false
  }

  AIRCRAFT_HAS_BOOSTERS = {
    hintType = g_hud_hint_types.COMMON
    getLocId = @(hintData) hintData.isOnGround ? "hints/aircraft_has_boosters_ground" : "hints/aircraft_has_boosters_air"
    showEvent = "hint:aircraft_has_boosters"
    shortcuts = "ID_IGNITE_BOOSTERS"
    lifeTime = 15.0
    isHideOnDeath = true
  }

  SHIP_COVER_DESTROYED = {
    hintType = g_hud_hint_types.MISSION_ACTION_HINTS
    locId = "hints/cover_destroyed"
    showEvent = "hint:cover_destroyed:show"
    lifeTime = 5.0
    isHideOnDeath = true
  }

  AMMO_USED_EXIT_ZONE = {
    hintType = g_hud_hint_types.MISSION_ACTION_HINTS
    showEvent = "hint:ammo_used_exit_zone:show"
    locId = "hints/ammo_used_exit_zone"
    lifeTime = 15.0
    isHideOnDeath = true
    isHideOnWatchedHeroChanged = true
  }

  GENERAL_WARNING_HIT = {
    hintType = g_hud_hint_types.WARNING_HINTS
    getLocId = @(eventData) eventData.text
    toggleHint = [
      "warn:net_slow",
      "warn:net_unresponsive",
      "warn:crit_airbrake",
      "warn:crit_flutter",
      "warn:high_engine_rpm",
      "warn:low_main_rotor_rpm",
      "warn:main_rotor_vortex_ring",
      "warn:tail_rotor_vortex_ring",
      "warn:art_warning",
      "warn:missile_warning",
      "warn:gun_breech_malfunction",
      "warn:gun_barrel_malfunction",
      "warn:rocket_launcher_malfunction",
      "warn:too_heavy_for_vtol",
      "warn:laser_warning",
      "warn:owned_unit_dead",
      "warn:visible_by_zone",
      "warn:crit_speed",
      "warn:stamina_loose_control",
      "warn:follow_the_path"
    ]
    isHideOnDeath = false
    shouldBlink = true
  }

  WARNING_RETURN_TO_ZONE = {
    hintType = g_hud_hint_types.WARNING_HINTS
    getLocId = @(eventData) eventData.text
    toggleHint = ["warn:return_to_zone"]
    isHideOnDeath = false
    shouldBlink = true
  }

  WARNING_CUSTOM = {
    hintType = g_hud_hint_types.WARNING_HINTS
    getLocId = @(eventData) eventData.text
    toggleHint = ["warn:custom"]
    isHideOnDeath = false
    shouldBlink = true
  }

  WARNING_FLAPS = {
    hintType = g_hud_hint_types.WARNING_HINTS
    getLocId = @(eventData) eventData.text
    toggleHint = ["warn:crit_flaps"]
    shortcuts = "ID_FLAPS"
    isHideOnDeath = false
    shouldBlink = true
  }

  WARNING_GEAR = {
    hintType = g_hud_hint_types.WARNING_HINTS
    getLocId = @(eventData) eventData.text
    toggleHint = ["warn:crit_gears"]
    shortcuts = "ID_GEAR"
    isHideOnDeath = false
    shouldBlink = true
  }

  WARNING_FLAPS_TAKEOFF = {
    hintType = g_hud_hint_types.WARNING_HINTS
    getLocId = @(eventData) eventData.text
    toggleHint = ["warn:set_takeoff_flaps_for_takeoff"]
    shortcuts = "ID_FLAPS"
    isHideOnDeath = false
    shouldBlink = true
  }

  WARNING_COCKPIT_DOOR = {
    hintType = g_hud_hint_types.WARNING_HINTS
    getLocId = @(eventData) eventData.text
    toggleHint = ["warn:crit_cockpit_door"]
    shortcuts = "ID_TOGGLE_COCKPIT_DOOR"
    isHideOnDeath = false
    shouldBlink = true
  }

  WARNING_OVERLOAD = {
    hintType = g_hud_hint_types.WARNING_HINTS
    getLocId = @(eventData) "".concat(loc("HUD_DANGEROUS_OVERLOAD")," ", eventData?.val ?? "", loc("HUD_CRIT_OVERLOAD_G"))
    toggleHint = ["warn:danger_overload"]
    isHideOnDeath = false
    shouldBlink = true
  }

  WARNING_OVERLOAD_CRIT = {
    hintType = g_hud_hint_types.WARNING_HINTS
    getLocId = @(eventData) "".concat(loc("HUD_CRIT_OVERLOAD")," ", eventData?.val ?? "", loc("HUD_CRIT_OVERLOAD_G"))
    toggleHint = ["warn:crit_overload"]
    isHideOnDeath = false
    shouldBlink = true
  }

  WARNING_ROYAL_AREA = {
    hintType = g_hud_hint_types.WARNING_HINTS
    getLocId = @(eventData) eventData.text
    toggleHint = ["warn:royal_area"]
    isHideOnDeath = false
    buildText = @(data) data.isShrinkZone ? colorize("@red", data.text) : colorize("@white", data.text)
    shouldBlink = true
  }
},
function() {
  this.name = $"hint_{this.typeName.tolower()}"
  if (this.lifeTime > 0)
    this.selfRemove = true

  if (this.maskId >= 0)
    this.mask = 1 << this.maskId

  if (this.uid >= HINT_UID_LIMIT)
    log($"Hints: uid = {this.uid} has exceeded the uid limit {HINT_UID_LIMIT}.")
},
"typeName")

g_hud_hints.getByName <- function getByName(hintName) {
  return enums.getCachedType("name", hintName, this.cache.byName, this, this.UNKNOWN)
}

g_hud_hints.getByUid <- function getByUid(uid) {
  return enums.getCachedType("uid", uid, this.cache.byUid, this, this.UNKNOWN)
}


register_command(@(uid) resetHintShowCount(uid), "smart_hints.resetHintShowCount")
register_command(@(uid) logHintInformashionById(uid), "smart_hints.logHintByUid")
register_command(@(hintName) logHintInformashionByName(hintName), "smart_hints.logHintByName")

return {
  g_hud_hints
  getHintSeenCount
  getHintSeenTime
  increaseHintShowCount
  updateHintEventTime
  resetHintShowCount
  getHintByShowEvent
}