local time = require("scripts/time.nut")
local { boosterEffectType, getActiveBoostersArray } = require("scripts/items/boosterEffect.nut")
local { getActiveBoostersDescription } = require("scripts/items/itemVisual.nut")

class ::items_classes.Booster extends ::BaseItem
{
  static iType = itemType.BOOSTER
  static defaultLocId = "rateBooster"
  static defaultIcon = "#ui/gameuiskin#items_booster_shape1"
  static typeIcon = "#ui/gameuiskin#item_type_boosters"
  canBuy = true
  allowBigPicture = false

  xpRate = 0 //percent
  wpRate = 0
  sortOrder = 0
  personal = true

  static mulIconSymbolsOffsetYMul = -0.017
  static mulIconSymbolsSpacing    = -0.025

  eventTypeData = {}
  static eventTypesTable = [{
                              name = null,
                              iconImg = "#ui/gameuiskin#item_type_boosters"
                            },
                            {
                              name = "kill",
                              iconImg = "#ui/gameuiskin#booster_event_kill"
                            },
                            {
                              name = "kill_ground",
                              iconImg = "#ui/gameuiskin#booster_event_kill_ground"
                            },
                            {
                              name = "assist",
                              iconImg = "#ui/gameuiskin#booster_event_assist"
                            }]

  eventType = null
  conditions = null

  stopData = null
  stopConditions = null
  eventConditions = null
  stopProgress = null

  constructor(blk, invBlk = null, slotData = null)
  {
    base.constructor(blk, invBlk, slotData)
    _initBoosterParams(blk?.rateBoosterParams)
    if (isActive())
      stopProgress = ::getTblValue("progress", invBlk, 0)
  }

  function _initBoosterParams(blk)
  {
    if (!blk)
      return

    xpRate = blk?.xpRate ?? 0
    wpRate = blk?.wpRate ?? 0
    personal = blk?.personal ?? true

    spentInSessionTimeMin = blk?.spentInSessionTimeMin ?? 0

    local event = blk?.event
    if (event != null)
    {
      eventType = event?.type
      foreach(cond in event % "conditon")
        if (typeof(cond)=="instance" && (cond instanceof ::DataBlock))
          conditions.append(::buildTableFromBlk(cond))
      eventConditions = ::UnlockConditions.loadConditionsFromBlk(event)
    }

    foreach(idx, block in eventTypesTable)
      if (block.name == eventType)
      {
        sortOrder = idx
        eventTypeData = block
        break
      }

    if (blk?.stop != null)
    {
      stopData = ::buildTableFromBlk(blk.stop)
      stopConditions = ::UnlockConditions.loadConditionsFromBlk(blk.stop)
    }
  }

  function getBoostersEffectsDiffByItem()
  {
    local effects = getEffectTypes()
    if (!effects.len())
      return 0

    local effectsArray = []
    local items = getAllActiveSameBoosters()
    local effect = effects[0] //!!we do not cmpare boosters with multieffects atm.

    foreach(item in items)
    {
      local value = effect.getValue(item)
      if (value <= 0)
        continue
      local amount = item.getAmount()
      if (amount > 1)
        effectsArray.extend(array(amount, value))
      else
        effectsArray.append(value)
    }

    effectsArray.sort(@(a, b) a <=> b)
    local effectsVal = getDiffEffect(effectsArray)
    effectsArray.append(effect.getValue(this))
    effectsArray.sort(@(a, b) a <=> b)
    local newEffectsVal = getDiffEffect(effectsArray)

    return newEffectsVal - effectsVal
  }

  function getDiffEffect(effectsArray)
  {
    if (personal)
      return ::calc_personal_boost(effectsArray)
    else
      return ::calc_public_boost(effectsArray)
  }

  function getDiffEffectText(diffResult)
  {
    return getEffectText(wpRate > 0? diffResult : 0, xpRate > 0? diffResult : 0)
  }

  function isActive(checkFlightProgress = false)
  {
    if (!uids || !isInventoryItem)
      return false

    local res = false
    local total = ::get_current_booster_count(INVALID_USER_ID)
    for (local i = 0; i < total; i++)
      if (::isInArray(::get_current_booster_uid(INVALID_USER_ID, i), uids))
      {
        res = true
        break
      }

    if (res && checkFlightProgress && ::is_in_flight())
      res = getLeftStopSessions() > 0

    return res
  }

  function getMainActionData(isShort = false, params = {})
  {
    local res = base.getMainActionData(isShort, params)
    if (res)
      return res
    if (isInventoryItem && amount && !isActive())
      return {
        btnName = ::loc("item/activate")
      }

    return null
  }

  function doMainAction(cb, handler, params = null)
  {
    local baseResult = base.doMainAction(cb, handler, params)
    if (!baseResult)
      return activate(cb, handler)
    return false
  }

  function _requestActivate()
  {
    if (!uids || !uids.len())
      return -1

    local blk = ::DataBlock()
    blk.setStr("name", uids[0])

    return ::char_send_blk("cln_set_current_booster", blk)
  }

  function activate(cb, handler = null)
  {
    local checkParams = {
      checkActive = true // Check if player already has active booster.
      checkIsInFlight = true // Check if player is in flight and booster will take effect in next battle.
    }
    return _activate((@(cb, handler) function (result) {
      if (!result.success)
      {
        // Trying to activate with one less check.
        result.checkParams[result.failedCheck] <- false
        if (result.failedCheck == "checkActive")
          showPenaltyBoosterMessageBox(handler, result.checkParams)
        else if (result.failedCheck == "checkIsInFlight")
          showIsInFlightAlertMessageBox(handler, result.checkParams)
      }
      cb(result)
    })(cb, handler).bindenv(this), handler, checkParams)
  }

  function showPenaltyBoosterMessageBox(handler, checkParams = null)
  {
    local effectsDiff = getBoostersEffectsDiffByItem()
    local bodyText = ::loc("msgbox/existingBoosters", {
                        newBooster = getName(),
                        newBoosterEffect = getDiffEffectText(::format("%.02f", effectsDiff).tofloat())
                      })
    local savedThis = this
    handler.msgBox("activate_additional_booster", bodyText, [
      [
        "yes", (@(handler, savedThis, checkParams) function () {
          savedThis._activate(null, handler, checkParams)
        })(handler, savedThis, checkParams).bindenv(this)
      ], [
        "no", function () {}
      ]], "no", { cancel_fn = function() {}})
  }

  function showIsInFlightAlertMessageBox(handler, checkParams = null)
  {
    local bodyText = ::loc("msgbox/isInFlightBooster")
    local savedThis = this
    handler.msgBox("activate_in_flight_booster", bodyText, [[
      "yes", (@(handler, savedThis, checkParams) function () {
          savedThis._activate(null, handler, checkParams)
        })(handler, savedThis, checkParams).bindenv(this)
    ], [
        "no", function () {}
    ]], "no", { cancel_fn = function() {}})
  }

  function getBoosterDescriptionForMessageBox(booster)
  {
    local result = booster.getName()
    if (hasTimer())
      result += " - " + booster.getTimeLeftText()
    return result
  }

  function _activate(cb, handler = null, checkParams = null) //handler need only because of char operations are based on gui_handlers.BaseGuiHandlerWT.
                                   //remove it after slotOpCb will be refactored
  {
    if (isActive() || !isInventoryItem)
      return false

    if (!handler)
      handler = ::get_cur_base_gui_handler()

    local checkIsInFlight = ::getTblValue("checkIsInFlight", checkParams, false)
    if (checkIsInFlight && ::is_in_flight())
    {
      if (cb)
      {
        cb({
          success = false
          failedCheck = "checkIsInFlight"
          checkParams = checkParams
        })
      }
      return false
    }

    local checkActive = ::getTblValue("checkActive", checkParams, false)
    if (checkActive && haveActiveBoosters())
    {
      if (cb)
      {
        cb({
          success = false
          failedCheck = "checkActive"
          checkParams = checkParams
        })
      }
      return false
    }

    handler.taskId = _requestActivate()
    if (handler.taskId >= 0)
    {
      ::set_char_cb(handler, handler.slotOpCb)
      handler.showTaskProgressBox.call(handler)
      handler.afterSlotOp = (@(cb) function() {
        ::update_gamercards()
        if (cb)
          cb({ success = true })
      })(cb)
      return true
    }
    return false
  }

  function haveActiveBoosters()
  {
    return getAllActiveSameBoosters().len() > 0
  }

  function getAllActiveSameBoosters()
  {
    local effects = getEffectTypes()
    return ::ItemsManager.getInventoryList(itemType.BOOSTER,
             (@(effects) function (_item) {
               if (!_item.isActive(true) || _item.personal != personal)
                 return false
               foreach(e in effects)
                 if (e.checkBooster(_item))
                   return true
               return false
             })(effects).bindenv(this))
  }

  function getIcon(addItemName = true)
  {
    local res = ::LayersIcon.genDataFromLayer(_getBaseIconCfg())
    res += ::LayersIcon.genInsertedDataFromLayer({w="0", h="0"}, _getMulIconCfg())
    res += ::LayersIcon.genDataFromLayer(_getModifiersIconCfgs())

    return res
  }

  function _getBaseIconCfg()
  {
    local layerId = "booster_common"
    if (personal)
      layerId = "booster_personal"

    return ::LayersIcon.findLayerCfg(layerId)
  }

  function _getModifiersIconCfgs()
  {
    local layerId = ""
    if (wpRate > 0 && xpRate > 0)
      layerId = "booster_wp_exp_rate"
    else if (wpRate > 0)
      layerId = "booster_wp_rate"
    else if (xpRate > 0)
      layerId = "booster_exp_rate"

    return ::LayersIcon.findLayerCfg(layerId)
  }

  function _getMulIconCfg()
  {
    local layersArray = []
    local mul = ::max(wpRate, xpRate)
    local numsArray = ::getArrayFromInt(mul)
    if (numsArray.len() > 0)
    {
      local plusLayer = ::LayersIcon.findLayerCfg("item_plus")
      if (plusLayer)
        layersArray.append(clone plusLayer)

      foreach(idx, int in numsArray)
      {
        local layer = ::LayersIcon.findLayerCfg("item_num_" + int)
        if (!layer)
          continue
        layersArray.append(clone layer)
      }

      local percentLayer = ::LayersIcon.findLayerCfg("item_percent")
      if (percentLayer)
        layersArray.append(clone percentLayer)

      foreach(idx, layerCfg in layersArray)
      {
        layersArray[idx].offsetY <- ::format("%.3fp.p.h * %d", mulIconSymbolsOffsetYMul, idx)
        layersArray[idx].x <- ::format("%.3fp.p.h", mulIconSymbolsSpacing)
        layersArray[idx].position <- "relative"
      }
    }

    return layersArray
  }

  function getEffectDesc(colored = true, effectType = null)
  {
    local desc = getEffectText(wpRate, xpRate, colored)

    if (!personal)
      desc += ::format(" (%s)", ::loc("boostEffect/group"))
    return desc
  }

  function _formatEffectText(value, currencyMark)
  {
    return ::colorize("activeTextColor", "+" + value + "%") + currencyMark
  }

  function getEffectText(wpRateNum = 0, xpRateNum = 0, colored = true)
  {
    local text = []
    if (wpRateNum > 0.0)
      if (colored)
        text.append(_formatEffectText(wpRateNum, ::loc("warpoints/short/colored")))
      else
        text.append("+" + wpRateNum + "%" + ::loc("warpoints/short/colored"))

    if (xpRateNum > 0.0)
      if (colored)
        text.append(_formatEffectText(xpRateNum, ::loc("currency/researchPoints/sign/colored")))
      else
        text.append(::getRpPriceText("+" + xpRateNum + "%", true))

    return ::g_string.implode(text, ", ")
  }

  function getDescription()
  {
    local desc = ""
    local locString = eventConditions == null
      ? "items/booster/description/uponActivation/withoutConditions"
      : "items/booster/description/uponActivation/withConditions"
    local locParams = {
      effectDesc = getEffectDesc()
    }
    if (wpRate != 0 || xpRate != 0)
      desc += ::loc(locString, locParams)
    if (eventConditions != null)
      desc += " " + getEventConditionsText()

    desc += "\n"

    local expireText = getCurExpireTimeText()
    if (expireText != "")
      desc += "\n" + expireText
    if (stopConditions != null)
      desc += "\n" + getStopConditions()

    if (isActive(true))
    {
      local effectTypes = getEffectTypes()
      foreach(t in effectTypes)
      {
        local usingBoostersArray = getActiveBoostersArray(t)
        desc = $"{desc}\n\n{getActiveBoostersDescription(usingBoostersArray, t, this)}"
      }
    }
    return desc
  }

  function getName(colored = true)
  {
    return base.getName(colored) + " " + getEffectDesc()
  }

  function getShortDescription(colored = true)
  {
    local desc = getName(colored)
    if (eventConditions)
      desc += ::loc("ui/parentheses/space", { text = getEventConditionsText() })
    return desc
  }

  function getEventConditionsText()
  {
    if (!eventConditions)
      return ""
    return ::UnlockConditions.getConditionsText(eventConditions, null, null, { inlineText = true })
  }

  _totalStopSessions = -1
  function getTotalStopSessions()
  {
    if (_totalStopSessions < 0)
    {
      local mainCondition = ::UnlockConditions.getMainProgressCondition(stopConditions)
      _totalStopSessions = ::getTblValue("num", mainCondition, 0)
    }
    return _totalStopSessions
  }

  function getLeftStopSessions()
  {
    if (stopProgress == null)
      return null

    local res = getTotalStopSessions() - stopProgress
    if (spentInSessionTimeMin && ::is_in_flight())
      res -= (time.secondsToMinutes(::get_usefull_total_time()) / spentInSessionTimeMin).tointeger()
    return ::max(0, res)
  }

  function getExpireFlightTime()
  {
    if (stopProgress == null)
      return -1
    return spentInSessionTimeMin * time.minutesToSeconds(getTotalStopSessions() - stopProgress)
  }

  function getStopConditions()
  {
    if (!stopConditions)
      return ""

    local textsList = []
    // Shows progress as count down 6, 5, 4, ... instead of 0/6, 1/6, ...
    local curValue = getLeftStopSessions()
    local params = { locEnding = isActive() ? "/inverted" : "/activeFor" }
    textsList.append(::UnlockConditions.getConditionsText(stopConditions, null, curValue, params))

    if (spentInSessionTimeMin)
      textsList.append(::colorize("fadedTextColor", ::loc("booster/progressFrequency", { num = spentInSessionTimeMin })))

    return ::g_string.implode(textsList, "\n")
  }

  function getEffectTypes()
  {
    local effectTypes = []
    foreach (effectType in boosterEffectType)
    {
      if (effectType.checkBooster(this))
        effectTypes.append(effectType)
    }
    return effectTypes
  }

  function getContentIconData()
  {
    local icon = getEventTypeIcon()
    return icon ? { contentIcon = icon } : null
  }

  function getEventTypeIcon()
  {
    return ::getTblValue("iconImg", eventTypeData)
  }

  function canStack(item)
  {
    if (item.iType != iType || item.personal != personal)
      return false
    foreach (efType in boosterEffectType)
      if ((efType.getValue(this) > 0) != (efType.getValue(item) > 0))
        return false
    return (eventConditions == item.eventConditions) || ::u.isEqual(eventConditions, item.eventConditions)
  }

  function updateStackParams(stackParams)
  {
    foreach (efType in boosterEffectType)
    {
      local value = efType.getValue(this)
      if (!value)
        continue

      local efTypeName = efType.name
      local valTbl = ::getTblValue(efTypeName, stackParams, {})
      local minVal = ::getTblValue("min", valTbl)
      valTbl.min <- minVal ? ::min(minVal, value) : value
      local maxVal = ::getTblValue("max", valTbl)
      valTbl.max <- maxVal ? ::max(maxVal, value) : value
      stackParams[efTypeName] <- valTbl
    }
  }

  function getStackName(stackParams)
  {
    local res = ::colorize("activeTextColor", ::loc("item/" + defaultLocId))
    local effects = []
    foreach (efType in boosterEffectType)
    {
      local valTbl = ::getTblValue(efType.name, stackParams)
      if (!valTbl || (!("min" in valTbl)))
        continue

      local minText = _formatEffectText(valTbl.min, efType.currencyMark)
      if (valTbl.min == valTbl.max)
        effects.append(minText)
      else
        effects.append(::loc("item/effect/from_to", {
                         min = minText
                         max = _formatEffectText(valTbl.max, efType.currencyMark)
                       }))
    }
    if (effects.len())
      res += " (" + ::g_string.implode(effects, ", ") + ")"
    if (eventConditions)
      res += " (" + getEventConditionsText() + ")"
    return res
  }
}

class ::items_classes.FakeBooster extends ::items_classes.Booster
{
  static iType = itemType.FAKE_BOOSTER
  showBoosterInSeparateList = true

  constructor(blk, invBlk = null, slotData = null)
  {
    base.constructor(blk, invBlk, slotData)
    iconStyle = blk?.iconStyle ?? id
  }

  function getIcon(addItemName = true)
  {
    return base.getIcon(addItemName)
  }

  function getName(colored = true)
  {
    return base.getName(colored)
  }

  function getDescription()
  {
    local desc = base.getDescription() + ::loc("ui/colon") + getEffectDesc()
    if (!isInventoryItem)
      return desc

    local bonusArray = []
    foreach(effect in boosterEffectType)
    {
      local value = ::get_squad_bonus_for_same_cyber_cafe(effect)
      if (value <= 0)
        continue
      local percent = ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(value, false)
      bonusArray.append(effect.getText(_formatEffectText(percent, ""), true, false))
    }

    if (bonusArray.len())
    {
      desc += "\n"
      desc += ::loc("item/FakeBoosterForNetCafeLevel/squad", {num = ::g_squad_manager.getSameCyberCafeMembersNum()}) + ::loc("ui/colon")
      desc += ::g_string.implode(bonusArray, ", ")
    }

    return desc
  }

  function getEffectDesc(colored = true, effectType = null)
  {
    local desc = ""
    if (effectType == boosterEffectType.WP)
      desc = getEffectText(wpRate, 0, colored)
    else if (effectType == boosterEffectType.RP)
      desc = getEffectText(0, xpRate, colored)
    else
      desc = getEffectText(wpRate, xpRate, colored)

    if (!personal)
      desc += ::format(" (%s)", ::loc("boostEffect/group"))
    return desc
  }

  function isActive(...) { return true }
}
