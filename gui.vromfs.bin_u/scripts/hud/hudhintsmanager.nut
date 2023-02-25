//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let DataBlock = require("DataBlock")
let { get_time_msec } = require("dagor.time")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let DaguiSceneTimers = require("%sqDagui/timer/daguiSceneTimers.nut")
let { PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")

const TIMERS_CHECK_INTEVAL = 0.25

enum HintShowState {
  NOT_MATCH = 0
  SHOW_HINT = 1
  DISABLE   = 2
}

::g_hud_hints_manager <- {
  [PERSISTENT_DATA_PARAMS] = ["activeHints"]

  nest = null
  scene = null
  guiScene = null

  activeHints = []
  animatedRemovedHints = [] //hints set to remove animation. to be able instant finish them

  timers = DaguiSceneTimers(TIMERS_CHECK_INTEVAL, "hudHintsTimers")

  hintIdx = 0 //used only for unique hint id

  lastShowedTimeDict = {} // key = maskId, value = lastShowedTime

  delayedShowTimers = {} // key = hint.name, value = timer

  function init(v_nest) {
    this.subscribe()

    if (!checkObj(v_nest))
      return
    this.nest = v_nest

    if (!this.findSceneObjects())
      return
    this.restoreAllHints()
  }


  function reinit() {
    if (!this.findSceneObjects())
      return
    this.restoreAllHints()
  }


  function onEventLoadingStateChange(_p) {
    if (!::is_in_flight()) {
      this.activeHints.clear()
      this.timers.reset()
    }
    else {
      let hintOptionsBlk = DataBlock()
      foreach (hint in ::g_hud_hints.types)
        hint.updateHintOptionsBlk(hintOptionsBlk)
      ::set_hint_options_by_blk(hintOptionsBlk)
    }
    this.animatedRemovedHints.clear()
  }

  function removeAllHints(hintFilterField = "isHideOnDeath") {
    let hints = ::u.filter(this.activeHints, @(hintData) hintData.hint[hintFilterField])
    foreach (hintData in hints)
      this.removeHint(hintData, true)
  }

  function onLocalPlayerDead() {
    this.removeAllHints()
  }

  function onWatchedHeroChanged() {
    this.removeAllHints("isHideOnWatchedHeroChanged")
  }

  //return false if can't
  function findSceneObjects() {
    this.scene = this.nest.findObject("hud_hints_nest")
    if (!checkObj(this.scene))
      return false

    this.guiScene = this.scene.getScene()
    this.timers.setUpdaterObj(this.scene)
    return true
  }


  function restoreAllHints() {
    foreach (hintData in this.activeHints)
      this.updateHint(hintData)
  }


  function subscribe() {
    ::g_hud_event_manager.subscribe("LocalPlayerDead", function (_eventData) {
      this.onLocalPlayerDead()
    }, this)

    ::g_hud_event_manager.subscribe("WatchedHeroChanged", function (_eventData) {
      this.onWatchedHeroChanged()
    }, this)

    foreach (hint in ::g_hud_hints.types) {
      if (!hint.isEnabled() || this.isHintShowCountExceeded(hint)) {
        log("Hints: " + (hint?.showEvent ?? "_") + " is disabled")
        continue
      }

      if (!::u.isNull(hint.showEvent))
        ::g_hud_event_manager.subscribe(hint.showEvent, (@(hint) function (eventData) {
          if (this.isHintShowCountExceeded(hint))
            return

          if (hint.delayTime > 0)
            this.showDelayed(hint, eventData)
          else
            this.onShowEvent(hint, eventData)
        })(hint), this)

      if (!::u.isNull(hint.hideEvent))
        ::g_hud_event_manager.subscribe(hint.hideEvent, (@(hint) function (eventData) {
          if (!hint.isCurrent(eventData, true))
            return

          this.removeDelayedShowTimer(hint)

          let hintData = this.findActiveHintFromSameGroup(hint)
          if (!hintData)
            return
          this.removeHint(hintData, hintData.hint.isInstantHide(eventData))
        })(hint), this)

      if (hint.updateCbs)
        foreach (eventName, func in hint.updateCbs)
          ::g_hud_event_manager.subscribe(eventName, (@(hint, func) function (eventData) {
            if (!hint.isCurrent(eventData, false))
              return

            let hintData = this.findActiveHintFromSameGroup(hint)
            let needUpdate = func.call(hint, hintData, eventData)
            if (hintData && needUpdate)
              this.updateHint(hintData)
          })(hint, func), this)
    }
  }

  function findActiveHintFromSameGroup(hint) {
    return ::u.search(this.activeHints, (@(hint) function (hintData) {
      return hint.hintType.isSameReplaceGroup(hintData.hint, hint)
    })(hint))
  }

  function addToList(hint, eventData) {
    this.activeHints.append({
      hint = hint
      hintObj = null
      addTime = get_time_msec()
      eventData = eventData
      lifeTimerWeak = null
    })

    let addedHint = this.activeHints?[this.activeHints.len() - 1]
    return addedHint
  }

  function updateRemoveTimer(hintData) {
    if (!hintData.hint.selfRemove)
      return

    let lifeTime = hintData.hint.getLifeTime(hintData.eventData)
    if (hintData.lifeTimerWeak) {
      if (lifeTime <= 0)
        this.timers.removeTimer(hintData.lifeTimerWeak)
      else
        this.timers.setTimerTime(hintData.lifeTimerWeak, lifeTime)
      return
    }

    if (lifeTime <= 0)
      return

    hintData.lifeTimerWeak = this.timers.addTimer(lifeTime, Callback(function () {
      this.hideHint(hintData, false)
      this.removeFromList(hintData)
      this.removeDelayedShowTimer(hintData.hint)
    }, this)).weakref()
  }

  function removeDelayedShowTimer(hint) {
    if (this.delayedShowTimers?[hint.name]) {
      this.timers.removeTimer(this.delayedShowTimers[hint.name])
      delete this.delayedShowTimers[hint.name]
    }
  }

  function updateHintInList(hintData, eventData) {
    hintData.eventData = eventData
    hintData.addTime = get_time_msec()
  }

  function removeFromList(hintData) {
    let idx = this.activeHints.findindex(@(item) item == hintData)
    if (idx != null)
      this.activeHints.remove(idx)
  }

  function onShowEvent(hint, eventData) {
    if (!hint.isCurrent(eventData, false))
      return

    let res = this.checkHintInterval(hint)
    if (res == HintShowState.DISABLE) {
      ::disable_hint(hint.mask)
      return
    }
    else if (res == HintShowState.NOT_MATCH)
      return

    if (hint.isSingleInNest && !this.isHintNestEmpty(hint))
      return

    local hintData = this.findActiveHintFromSameGroup(hint)

    if (hintData)
      if (!hint.hintType.isReplaceable(hint, eventData, hintData.hint, hintData.eventData))
        return
      else if (hint == hintData.hint) {
        this.hideHint(hintData, true)
        this.updateHintInList(hintData, eventData)
      }
      else {
        this.removeHint(hintData, true)
        hintData = null
      }

    if (!hintData)
      hintData = this.addToList(hint, eventData)

    this.showHint(hintData)
    this.updateHint(hintData)
  }



  function isHintNestEmpty(hint) {
    return !::u.search(this.activeHints, @(hintData)
      hintData.hint != hint && hintData.hint.hintType == hint.hintType)
  }

  function showHint(hintData) {
    if (!checkObj(this.nest))
      return

    let hintNestObj = this.nest.findObject(hintData.hint.getHintNestId())
    if (!checkObj(hintNestObj))
      return

    this.checkRemovedHints(hintData.hint) //remove hints with not finished animation if needed
    this.removeSingleInNestHints(hintData.hint)

    let id = hintData.hint.name + (++this.hintIdx)
    let markup = hintData.hint.buildMarkup(hintData.eventData, id)
    this.guiScene.appendWithBlk(hintNestObj, markup, markup.len(), null)
    hintData.hintObj = hintNestObj.findObject(id)
    this.setCoutdownTimer(hintData)

    this.lastShowedTimeDict[hintData.hint.maskId] <- get_time_msec()
    ::increase_hint_show_count(hintData.hint.maskId)
  }

  function setCoutdownTimer(hintData) {
    if (!hintData.hint.selfRemove)
      return

    let hintObj = hintData.hintObj
    if (!checkObj(hintObj))
      return

    hintData.secondsUpdater <- SecondsUpdater(hintObj, (@(hintData) function (obj, _params) {
      let textObj = obj.findObject("time_text")
      if (!checkObj(textObj))
        return false

      let lifeTime = hintData.hint.getTimerTotalTimeSec(hintData.eventData)
      let offset = hintData.hint.getTimerCurrentTimeSec(hintData.eventData, hintData.addTime)
      let timeLeft = (lifeTime - offset + 0.5).tointeger()

      if (timeLeft < 0)
        return true

      textObj.setValue(timeLeft.tostring())
      return false
    })(hintData))
  }

  function hideHint(hintData, isInstant) {
    let hintObject = hintData.hintObj
    if (!checkObj(hintObject))
      return

    let needFinalizeRemove = hintData.hint.hideHint(hintObject, isInstant)
    if (needFinalizeRemove)
      this.animatedRemovedHints.append(clone hintData)
  }

  function removeHint(hintData, isInstant) {
    this.hideHint(hintData, isInstant)
    if (hintData.hint.selfRemove && hintData.lifeTimerWeak)
      this.timers.removeTimer(hintData.lifeTimerWeak)
    this.removeFromList(hintData)
  }

  function checkRemovedHints(hint) {
    for (local i = this.animatedRemovedHints.len() - 1; i >= 0; i--) {
      let hintData = this.animatedRemovedHints[i]
      if (checkObj(hintData.hintObj)) {
        if (!hint.hintType.isSameReplaceGroup(hintData.hint, hint))
          continue
        hintData.hint.hideHint(hintData.hintObj, true)
      }
      this.animatedRemovedHints.remove(i)
    }
  }

  function removeSingleInNestHints(hint) {
    foreach (hintData in this.activeHints)
      if (hintData.hint != hint &&
          hintData.hint.hintType == hint.hintType &&
          hintData.hint.isSingleInNest)
        this.removeHint(hintData, true)
  }

  function updateHint(hintData) {
    this.updateRemoveTimer(hintData)

    let hintObj = hintData.hintObj
    if (!checkObj(hintObj))
      return this.showHint(hintData)

    this.setCoutdownTimer(hintData)

    let timeBarObj = hintObj.findObject("time_bar")
    if (checkObj(timeBarObj)) {
      let totaltime = hintData.hint.getTimerTotalTimeSec(hintData.eventData)
      let currentTime = hintData.hint.getTimerCurrentTimeSec(hintData.eventData, hintData.addTime)
      ::g_time_bar.setPeriod(timeBarObj, totaltime)
      ::g_time_bar.setCurrentTime(timeBarObj, currentTime)
    }
  }

  function onEventScriptsReloaded(_p) {
    foreach (hintData in this.activeHints)
      hintData.hint = ::g_hud_hints.getByName(hintData.hint.name)
  }


  function checkHintInterval(hint) {
    let interval = hint.getTimeInterval()
    if (interval == HINT_INTERVAL.ALWAYS_VISIBLE)
      return HintShowState.SHOW_HINT
    else if (interval == HINT_INTERVAL.HIDDEN)
      return HintShowState.DISABLE

    if (!(hint.maskId in this.lastShowedTimeDict)) {
      return HintShowState.SHOW_HINT
    }
    else {
      let ageSec = (get_time_msec() - this.lastShowedTimeDict[hint.maskId]) * 0.001
      return ageSec >= interval ? HintShowState.SHOW_HINT : HintShowState.NOT_MATCH
    }

    return HintShowState.NOT_MATCH
  }

  function isHintShowCountExceeded(hint) {
    if (hint.maskId >= 0 || (hint?.totalCount ?? 0) > 0)
      log("Hints: " + (hint?.showEvent ?? "_")
      + " maskId = " + hint.maskId
      + " totalCount = " + (hint?.totalCount ?? "_")
      + " showedCount = " + ::get_hint_seen_count(hint.maskId))

    return (hint.totalCount > 0
      && ::get_hint_seen_count(hint.maskId) > hint.totalCount)
  }

  function showDelayed(hint, eventData) {
    if (hint.delayTime <= 0)
      return
    if (this.delayedShowTimers?[hint.name])
      return

    this.delayedShowTimers[hint.name] <- this.timers.addTimer(hint.delayTime, Callback(function () {
      if (this.delayedShowTimers?[hint.name])
        this.onShowEvent(hint, eventData)
    }, this)).weakref()
  }
}

::g_script_reloader.registerPersistentDataFromRoot("g_hud_hints_manager")
::subscribe_handler(::g_hud_hints_manager, ::g_listener_priority.DEFAULT_HANDLER)
