local chard = require("chard")
local { setShowUnit } = require("scripts/slotbar/playerCurUnit.nut")

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
::CrewTakeUnitProcess(crewOrCountry, unitToTake = null, callback = null)
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

class ::CrewTakeUnitProcess
{
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
    [CTU_PROGRESS.CHECK_QUEUE] = function()
    {
      if (crew || unit)
        ::queues.checkAndStart(nextStepCb, removeCb, "isCanModifyCrew")
      else
        nextStep() //we no need to check queue when only hire crew.
    },

    [CTU_PROGRESS.CHECK_AVAILABILITY] = function()
    {
      if (crew)
      {
        prevUnit = ::g_crew.getCrewUnit(crew)
        if (prevUnit == unit)
          return remove()
      }
      if (unit && !unit.isUsable())
        return remove() //rent expired

      //we cant make slotbar invalid by add crew to new hired crew
      local isInvalidCrewsAllowed = crew == null || ::SessionLobby.isInvalidCrewsAllowed()
      local isCurUnitAllowed = unit && ::SessionLobby.isUnitAllowed(unit) && !::isUnitBroken(unit)
      local needCheckAllowed = !isInvalidCrewsAllowed  && (!unit || !isCurUnitAllowed)
      local needCheckRequired = !isInvalidCrewsAllowed && ::SessionLobby.hasUnitRequirements()
        && (!isCurUnitAllowed || !::SessionLobby.isUnitRequired(unit))

      if (needCheckAllowed || needCheckRequired || (prevUnit && !unit))
      {
        local hasUnit = !!unit
        local hasAllowedUnit = !needCheckAllowed
        local hasRequiredUnit = !needCheckRequired
        local crews = ::g_crews_list.get()?[crew.idCountry]?.crews
        if (crews)
          foreach(c in crews)
          {
            if (crew.id == c.id)
              continue
            local cUnit =::g_crew.getCrewUnit(c)
            if (!cUnit)
              continue
            hasUnit = true
            local isAllowed = ::SessionLobby.isUnitAllowed(cUnit) && !::isUnitBroken(cUnit)
            hasAllowedUnit = hasAllowedUnit || isAllowed
            hasRequiredUnit = hasRequiredUnit || (isAllowed && ::SessionLobby.isUnitRequired(cUnit))
            if (hasRequiredUnit && hasAllowedUnit)
              break
          }

        if (!hasUnit)
          return remove()
        if (!hasAllowedUnit)
        {
          local msg = ""
          if (unit)
            msg = ::loc("msg/cantUseUnitInCurrentBattle",
              { unitName = ::colorize("userlogColoredText", ::getUnitName(unit)) })
          else
            msg = ::loc("msg/needAtLeastOneAvailableUnit")
          ::showInfoMsgBox(msg)
          return remove()
        }
        if (!hasRequiredUnit)
        {
          ::showInfoMsgBox(::loc("msg/needAtLeastOneRequiredUnit"))
          return remove()
        }
      }

      nextStep()
    },

    [CTU_PROGRESS.FULL_COST_MESSAGE] = function()
    {
      if (cost.isZero())
        return nextStep()

      local locId = "shop/needMoneyQuestion_retraining"
      if (!crew)
        locId = unit ? "shop/needMoneyQuestion_hireAndTrainCrew"
                     : "shop/needMoneyQuestion_purchaseCrew"
      local msgText = ::warningIfGold(::format(::loc(locId), cost.getTextAccordingToBalance()), cost)
      ::scene_msg_box("need_money", null, msgText,
        [ ["ok", nextStepCb],
          ["cancel", removeCb ]
        ], "ok")
    },

    [CTU_PROGRESS.CHECK_MONEY] = function()
    {
      if (::check_balance_msgBox(cost,
            ::Callback(function()
              {
                if (::check_balance_msgBox(cost, nextStepCb, true))
                  nextStep()
                else
                  remove()
              }, this))
         )
        nextStep()
    },

    [CTU_PROGRESS.HIRE_CREW] = function()
    {
      if (crew)
        return nextStep()
      local purchaseCb = ::Callback(function()
        {
          local crews = ::get_crews_list_by_country(country)
          if (!crews.len())
            return remove()

          crew = crews.top()
          nextStep()
        }, this)
      ::g_crew.purchaseNewSlot(country, purchaseCb, removeCb)
    },

    [CTU_PROGRESS.TAKE_UNIT] = function()
    {
      if (unit == prevUnit)
        return nextStep()
      if (unit && !unit.isUsable())
        return remove()

      local taskId = chard.trainCrewAircraft(crew.id, unit ? unit.name : "", false)
      local taskOptions = {
        showProgressBox = true
        progressBoxDelayedButtons = PROCESS_TIME_OUT
      }
      if (!::g_tasker.addTask(taskId, taskOptions, nextStepCb, removeCb))
        remove()
    },

    [CTU_PROGRESS.COMPLETE] = function()
    {
      onComplete()
    }
  }

  constructor(crewOrCountry, unitToTake = null, callback = null)
  {
    if (!unitToTake && !crewOrCountry)
      return remove()

    unit = unitToTake
    if (!crewOrCountry)
      country = ::getUnitCountry(unit)
    else if (::u.isString(crewOrCountry))
      country = crewOrCountry
    else
      crew = crewOrCountry

    if (!isReadyToStart())
      return remove()

    onFinish = callback
    activeProcesses.append(this)

    nextStepCb = ::Callback(nextStep, this)
    removeCb = ::Callback(remove, this)
    cost = getProcessCost(crew, unit, country)

    ::g_crews_list.suspendSlotbarUpdates()
    nextStep()

    ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
  }

  static function getProcessCost(crew, unit, country = null)
  {
    local resCost = ::g_crew.getCrewTrainCost(crew, unit)
    if (crew || (!unit && !country))
      return resCost

    local crewCostTbl = ::get_crew_slot_cost(country || ::getUnitCountry(unit))
    if (crewCostTbl)
    {
      resCost.wp += crewCostTbl.cost
      resCost.gold += crewCostTbl.costGold
    }
    return resCost
  }

  static function hasActiveProcess()
  {
    return activeProcesses.len() > 0 && !activeProcesses[0].isStuck()
  }

  static function safeInterrupt()
  {
    if (!hasActiveProcess())
      return true

    if (!activeProcesses[0].canBeInterrupted())
      return false

    activeProcesses[0].remove()
    return true
  }

  function isValid()
  {
    return ::getTblValue(0, activeProcesses) == this
  }

  function isEqual(process)
  {
    return crew == process.crew
           && unit == process.unit
           && country == process.country
  }

  function canBeInterrupted()
  {
    return curProgress != CTU_PROGRESS.HIRE_CREW && curProgress != CTU_PROGRESS.TAKE_UNIT
  }

  function isReadyToStart()
  {
    if (!activeProcesses.len())
      return true

    if (activeProcesses[0].isStuck())
    {
      activeProcesses[0].remove()
      return true
    }

    if (isEqual(activeProcesses[0]))
      return false

    local msg = ::format("Previous CrewTakeUnitProcess is not finished (progress = %s) ",
                         ::getEnumValName("CTU_PROGRESS", activeProcesses[0].curProgress))
    ::script_net_assert_once("can't start take crew", msg)
    return false
  }

  function isStuck()
  {
    return ::dagor.getCurTime() - lastUpdateTime > PROCESS_TIME_OUT
  }

  function refreshTimer()
  {
    lastUpdateTime = ::dagor.getCurTime()
  }

  function remove(...)
  {
    foreach(idx, process in activeProcesses)
      if (process == this)
      {
        activeProcesses.remove(idx)
        break
      }
    if (onFinish)
      onFinish(isSuccess)
    ::g_crews_list.flushSlotbarUpdate()
  }

  function nextStep()
  {
    curProgress++
    refreshTimer()

    local curStepFunc = ::getTblValue(curProgress, stepsList)
    if (!curStepFunc)
    {
      ::script_net_assert_once("missing take unit step", "Missing take unit step = " + curProgress)
      return remove()
    }

    curStepFunc.call(this)
  }

  function onEventQueueChangeState(p)
  {
    if (curProgress > CTU_PROGRESS.CHECK_QUEUE
        && (crew || unit)
        && !::queues.isCanModifyCrew())
      remove()
  }

  function onEventLoadingStateChange(p)
  {
    if (::is_in_flight())
      remove()
  }

  function onEventSignOut(p)
  {
    remove()
  }

  function onComplete()
  {
    isSuccess = true
    if (unit)
    {
      ::updateAirAfterSwitchMod(unit)
      ::select_crew(crew.idCountry, crew.idInCountry, true)
      setShowUnit(unit)
    }
    ::g_crews_list.flushSlotbarUpdate()
    ::broadcastEvent("CrewTakeUnit", { unit = unit, prevUnit = prevUnit })
    remove()
  }
}