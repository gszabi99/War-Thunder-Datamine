from "%scripts/dagui_natives.nut" import get_crew_slot_cost
from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { format } = require("string")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_time_msec } = require("dagor.time")
let chard = require("chard")
let { setShowUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { hasDefaultUnitsInCountry } = require("%scripts/shop/shopUnitsInfo.nut")
let { getEnumValName } = require("%scripts/debugTools/dbgEnum.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { getUnitName, getUnitCountry } = require("%scripts/unit/unitInfo.nut")
let { isUnitBroken } = require("%scripts/unit/unitStatus.nut")
let { isInFlight } = require("gameplayBinding")
let { addTask } = require("%scripts/tasker.nut")
let { warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { getCrewsListByCountry, selectCrew } = require("%scripts/slotbar/slotbarState.nut")
let { getCrewUnit, purchaseNewCrewSlot, getCrewTrainCost } = require("%scripts/crew/crew.nut")
let { flushSlotbarUpdate, suspendSlotbarUpdates, getCrewsList
} = require("%scripts/slotbar/crewsList.nut")
let { isCrewLockedByPrevBattle, getCrewByAir } = require("%scripts/crew/crewInfo.nut")

enum CTU_PROGRESS {
  NOT_STARTED
  CHECK_QUEUE
  CHECK_AVAILABILITY
  FULL_COST_MESSAGE
  CHECK_MONEY
  HIRE_CREW
  TAKE_UNIT
  COMPLETE
}

/* API:
CrewTakeUnitProcess(crewOrCountry, unitToTake = null, callback = null)
    crewOrCountry - can be:
       * crew table. If crew table not set, new crew will be trained by chosen country or unit
       * country name string
       * null   //country will be taken from unit
    unitToTake - unit to train. if null - remove cur unit from crew
    calback - function(isSuccess) on finish process

  static function getProcessCost(crew, unit, country = null)
    return cost of full CrewTakeUnitProcess

  static function safeInterrupt()
    interrupt process when it in the safe state for interruption
    return false if process still exist.
*/

let CrewTakeUnitProcess = class {
  crew = null
  country = null //used only when crew not unlocked
  unit = null
  prevUnit = null
  onFinish = null
  isSuccess = false

  static PROCESS_TIME_OUT = 45000
  static activeProcesses = []
  lastUpdateTime = -1

  curProgress = CTU_PROGRESS.NOT_STARTED
  cost = null
  nextStepCb = null
  removeCb = null

  stepsList = {
    [CTU_PROGRESS.CHECK_QUEUE] = function() {
      if (this.crew || this.unit)
        ::queues.checkAndStart(this.nextStepCb, this.removeCb, "isCanModifyCrew")
      else
        this.nextStep() //we no need to check queue when only hire crew.
    },

    [CTU_PROGRESS.CHECK_AVAILABILITY] = function() {
      if (this.crew) {
        this.prevUnit = getCrewUnit(this.crew)
        if (this.prevUnit == this.unit)
          return this.remove()

        if (isCrewLockedByPrevBattle(this.crew)) {
          showInfoMsgBox(loc("charServer/updateError/52"), "crew_forbidden_for_take_unit")
          return this.remove()
        }
      }

      if (this.unit && !this.unit.isUsable())
        return this.remove() //rent expired

      let unitCrew = this.unit != null ? getCrewByAir(this.unit) : null
      if (unitCrew != null && isCrewLockedByPrevBattle(unitCrew)) {
        showInfoMsgBox(loc("charServer/updateError/52"), "unit_crew_forbidden_for_move_unit")
        return this.remove()
      }

      //we cant make slotbar invalid by add crew to new hired crew
      let isInvalidCrewsAllowed = this.crew == null || ::SessionLobby.isInvalidCrewsAllowed()
      let isCurUnitAllowed = this.unit && ::SessionLobby.isUnitAllowed(this.unit) && !isUnitBroken(this.unit)
      let needCheckAllowed = !isInvalidCrewsAllowed  && (!this.unit || !isCurUnitAllowed)
      let needCheckRequired = !isInvalidCrewsAllowed && ::SessionLobby.hasUnitRequirements()
        && (!isCurUnitAllowed || !::SessionLobby.isUnitRequired(this.unit))

      if (needCheckAllowed || needCheckRequired || (this.prevUnit && !this.unit)) {
        local hasUnit = !!this.unit
        local hasAllowedUnit = !needCheckAllowed
        local hasRequiredUnit = !needCheckRequired
        let crews = getCrewsList()?[this.crew.idCountry]?.crews
        if (crews)
          foreach (c in crews) {
            if (this.crew.id == c.id)
              continue
            let cUnit = getCrewUnit(c)
            if (!cUnit)
              continue
            hasUnit = true
            let isAllowed = ::SessionLobby.isUnitAllowed(cUnit) && !isUnitBroken(cUnit)
            hasAllowedUnit = hasAllowedUnit || isAllowed
            hasRequiredUnit = hasRequiredUnit || (isAllowed && ::SessionLobby.isUnitRequired(cUnit))
            if (hasRequiredUnit && hasAllowedUnit)
              break
          }

        if (!hasUnit && hasDefaultUnitsInCountry(this.crew.country))
          return this.remove()
        if (!hasAllowedUnit) {
          local msg = ""
          if (this.unit)
            msg = loc("msg/cantUseUnitInCurrentBattle",
              { unitName = colorize("userlogColoredText", getUnitName(this.unit)) })
          else
            msg = loc("msg/needAtLeastOneAvailableUnit")
          showInfoMsgBox(msg)
          return this.remove()
        }
        if (!hasRequiredUnit) {
          showInfoMsgBox(loc("msg/needAtLeastOneRequiredUnit"))
          return this.remove()
        }
      }

      this.nextStep()
    },

    [CTU_PROGRESS.FULL_COST_MESSAGE] = function() {
      if (this.cost.isZero())
        return this.nextStep()

      local locId = "shop/needMoneyQuestion_retraining"
      if (!this.crew)
        locId = this.unit ? "shop/needMoneyQuestion_hireAndTrainCrew"
                     : "shop/needMoneyQuestion_purchaseCrew"
      let msgText = warningIfGold(format(loc(locId), this.cost.getTextAccordingToBalance()), this.cost)
      scene_msg_box("need_money", null, msgText,
        [ ["ok", this.nextStepCb],
          ["cancel", this.removeCb ]
        ], "ok")
    },

    [CTU_PROGRESS.CHECK_MONEY] = function() {
      if (checkBalanceMsgBox(this.cost,
            Callback(function() {
                if (checkBalanceMsgBox(this.cost, this.nextStepCb, true))
                  this.nextStep()
                else
                  this.remove()
              }, this))
         )
        this.nextStep()
    },

    [CTU_PROGRESS.HIRE_CREW] = function() {
      if (this.crew)
        return this.nextStep()
      let purchaseCb = Callback(function() {
          let crews = getCrewsListByCountry(this.country)
          if (!crews.len())
            return this.remove()

          this.crew = crews.top()
          this.nextStep()
        }, this)
      purchaseNewCrewSlot(this.country, purchaseCb, this.removeCb)
    },

    [CTU_PROGRESS.TAKE_UNIT] = function() {
      if (this.unit == this.prevUnit)
        return this.nextStep()
      if (this.unit && !this.unit.isUsable())
        return this.remove()

      let taskId = chard.trainCrewAircraft(this.crew.id, this.unit ? this.unit.name : "", false)
      let taskOptions = {
        showProgressBox = true
        progressBoxDelayedButtons = this.PROCESS_TIME_OUT
      }
      if (!addTask(taskId, taskOptions, this.nextStepCb, this.removeCb))
        this.remove()
    },

    [CTU_PROGRESS.COMPLETE] = function() {
      this.onComplete()
    }
  }

  constructor(crewOrCountry, unitToTake = null, callback = null) {
    if (!unitToTake && !crewOrCountry)
      return this.remove()

    this.unit = unitToTake
    if (!crewOrCountry)
      this.country = getUnitCountry(this.unit)
    else if (u.isString(crewOrCountry))
      this.country = crewOrCountry
    else
      this.crew = crewOrCountry

    if (!this.isReadyToStart())
      return this.remove()

    this.onFinish = callback
    this.activeProcesses.append(this)

    this.nextStepCb = Callback(this.nextStep, this)
    this.removeCb = Callback(this.remove, this)
    this.cost = this.getProcessCost(this.crew, this.unit, this.country)

    suspendSlotbarUpdates()
    this.nextStep()

    subscribe_handler(this, g_listener_priority.DEFAULT_HANDLER)
  }

  static function getProcessCost(crew, unit, country = null) {
    let resCost = getCrewTrainCost(crew, unit)
    if (crew || (!unit && !country))
      return resCost

    let crewCostTbl = get_crew_slot_cost(country || getUnitCountry(unit))
    if (crewCostTbl) {
      resCost.wp += crewCostTbl.cost
      resCost.gold += crewCostTbl.costGold
    }
    return resCost
  }

  static function hasActiveProcess() {
    return this.activeProcesses.len() > 0 && !this.activeProcesses[0].isStuck()
  }

  static function safeInterrupt() {
    if (!this.hasActiveProcess())
      return true

    if (!this.activeProcesses[0].canBeInterrupted())
      return false

    this.activeProcesses[0].remove()
    return true
  }

  function isValid() {
    return getTblValue(0, this.activeProcesses) == this
  }

  function isEqual(process) {
    return this.crew == process.crew
           && this.unit == process.unit
           && this.country == process.country
  }

  function canBeInterrupted() {
    return this.curProgress != CTU_PROGRESS.HIRE_CREW && this.curProgress != CTU_PROGRESS.TAKE_UNIT
  }

  function isReadyToStart() {
    if (!this.activeProcesses.len())
      return true

    if (this.activeProcesses[0].isStuck()) {
      this.activeProcesses[0].remove()
      return true
    }

    if (this.isEqual(this.activeProcesses[0]))
      return false

    let msg = format("Previous CrewTakeUnitProcess is not finished (progress = %s) ",
      getEnumValName("CTU_PROGRESS", CTU_PROGRESS, this.activeProcesses[0].curProgress))
    script_net_assert_once("can't start take crew", msg)
    return false
  }

  function isStuck() {
    return get_time_msec() - this.lastUpdateTime > this.PROCESS_TIME_OUT
  }

  function refreshTimer() {
    this.lastUpdateTime = get_time_msec()
  }

  function remove(...) {
    foreach (idx, process in this.activeProcesses)
      if (process == this) {
        this.activeProcesses.remove(idx)
        break
      }
    if (this.onFinish)
      this.onFinish(this.isSuccess)
    flushSlotbarUpdate()
  }

  function nextStep() {
    this.curProgress++
    this.refreshTimer()

    let curStepFunc = getTblValue(this.curProgress, this.stepsList)
    if (!curStepFunc) {
      script_net_assert_once("missing take unit step", $"Missing take unit step = {this.curProgress}")
      return this.remove()
    }

    curStepFunc.call(this)
  }

  function onEventQueueChangeState(_p) {
    if (this.curProgress > CTU_PROGRESS.CHECK_QUEUE
        && (this.crew || this.unit)
        && !::queues.isCanModifyCrew())
      this.remove()
  }

  function onEventLoadingStateChange(_p) {
    if (isInFlight())
      this.remove()
  }

  function onEventSignOut(_p) {
    this.remove()
  }

  function onComplete() {
    this.isSuccess = true
    if (this.unit) {
      ::updateAirAfterSwitchMod(this.unit)
      selectCrew(this.crew.idCountry, this.crew.idInCountry, true)
      setShowUnit(this.unit)
    }
    flushSlotbarUpdate()
    broadcastEvent("CrewTakeUnit", { unit = this.unit, prevUnit = this.prevUnit })
    this.remove()
  }
}
return {
  CrewTakeUnitProcess
}