from "%scripts/dagui_natives.nut" import set_char_cb, get_current_booster_count, char_send_blk, get_current_booster_uid
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let { get_mission_time } = require("mission")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { calc_personal_boost, calc_public_boost } = require("%appGlobals/ranks_common_shared.nut")
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { get_cur_base_gui_handler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { format } = require("string")
let DataBlock  = require("DataBlock")
let time = require("%scripts/time.nut")
let { boosterEffectType, getActiveBoostersArray } = require("%scripts/items/boosterEffect.nut")
let { getActiveBoostersDescription } = require("%scripts/items/itemVisual.nut")
let { loadConditionsFromBlk, getMainProgressCondition } = require("%scripts/unlocks/unlocksConditions.nut")
let { getFullUnlockCondsDesc,
  getFullUnlockCondsDescInline } = require("%scripts/unlocks/unlocksViewModule.nut")
let { isInFlight } = require("gameplayBinding")
let { BaseItem } = require("%scripts/items/itemsClasses/itemsBase.nut")
let { measureType } = require("%scripts/measureType.nut")
let { floor } = require("math")

function getArrayFromInt(intNum) {
  let arr = []
  do {
    let div = intNum % 10
    arr.append(div)
    intNum = floor(intNum / 10).tointeger()
  } while (intNum != 0)

  arr.reverse()
  return arr
}

let Booster = class (BaseItem) {
  static name = "Booster"
  static iType = itemType.BOOSTER
  static defaultLocId = "rateBooster"
  static defaultIcon = "#ui/gameuiskin#items_booster_shape1"
  static typeIcon = "#ui/gameuiskin#item_type_boosters.svg"
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
                              iconImg = "#ui/gameuiskin#item_type_boosters.svg"
                            },
                            {
                              name = "kill",
                              iconImg = "#ui/gameuiskin#item_type_booster_event_kill.svg"
                            },
                            {
                              name = "kill_ground",
                              iconImg = "#ui/gameuiskin#item_type_booster_event_kill_ground.svg"
                            },
                            {
                              name = "assist",
                              iconImg = "#ui/gameuiskin#item_type_booster_event_assist.svg"
                            }]

  stopConditions = null
  eventConditions = null
  stopProgress = null

  constructor(blk, invBlk = null, slotData = null) {
    base.constructor(blk, invBlk, slotData)
    this._initBoosterParams(blk?.rateBoosterParams)
    if (this.isActive())
      this.stopProgress = getTblValue("progress", invBlk, 0)
  }

  function _initBoosterParams(blk) {
    if (!blk)
      return

    this.xpRate = blk?.xpRate ?? 0
    this.wpRate = blk?.wpRate ?? 0
    this.personal = blk?.personal ?? true

    this.spentInSessionTimeMin = blk?.spentInSessionTimeMin ?? 0

    let event = blk?.event
    if (event != null)
      this.eventConditions = loadConditionsFromBlk(event)

    let eventType = event?.type
    foreach (idx, block in this.eventTypesTable)
      if (block.name == eventType) {
        this.sortOrder = idx
        this.eventTypeData = block
        break
      }

    if (blk?.stop != null)
      this.stopConditions = loadConditionsFromBlk(blk.stop)
  }

  function getBoostersEffectsDiffByItem() {
    let effects = this.getEffectTypes()
    if (!effects.len())
      return 0

    let effectsArray = []
    let items = this.getAllActiveSameBoosters()
    let effect = effects[0] //!!we do not cmpare boosters with multieffects atm.

    foreach (item in items) {
      let value = effect.getValue(item)
      if (value <= 0)
        continue
      let amount = item.getAmount()
      if (amount > 1)
        effectsArray.extend(array(amount, value))
      else
        effectsArray.append(value)
    }

    effectsArray.sort(@(a, b) b <=> a)
    let effectsVal = this.getDiffEffect(effectsArray)
    effectsArray.append(effect.getValue(this))
    effectsArray.sort(@(a, b) b <=> a)
    let newEffectsVal = this.getDiffEffect(effectsArray)

    return newEffectsVal - effectsVal
  }

  function getDiffEffect(effectsArray) {
    if (this.personal)
      return calc_personal_boost(effectsArray)
    else
      return calc_public_boost(effectsArray)
  }

  function getDiffEffectText(diffResult) {
    return this.getEffectText(this.wpRate > 0 ? diffResult : 0, this.xpRate > 0 ? diffResult : 0)
  }

  function isActive(checkFlightProgress = false) {
    if (!this.uids || !this.isInventoryItem)
      return false

    local res = false
    let total = get_current_booster_count(::INVALID_USER_ID)
    for (local i = 0; i < total; i++)
      if (isInArray(get_current_booster_uid(::INVALID_USER_ID, i), this.uids)) {
        res = true
        break
      }

    if (res && checkFlightProgress && isInFlight())
      res = this.getLeftStopSessions() > 0

    return res
  }

  function getMainActionData(isShort = false, params = {}) {
    let res = base.getMainActionData(isShort, params)
    if (res)
      return res
    if (this.isInventoryItem && this.amount && !this.isActive())
      return {
        btnName = loc("item/activate")
      }

    return null
  }

  function doMainAction(cb, handler, params = null) {
    let baseResult = base.doMainAction(cb, handler, params)
    if (!baseResult)
      return this.activate(cb, handler)
    return false
  }

  function _requestActivate() {
    if (!this.uids || !this.uids.len())
      return -1

    let blk = DataBlock()
    blk.setStr("name", this.uids[0])

    return char_send_blk("cln_set_current_booster", blk)
  }

  function activate(cb, handler = null) {
    let checkParams = {
      checkActive = true // Check if player already has active booster.
      checkIsInFlight = true // Check if player is in flight and booster will take effect in next battle.
    }
    return this._activate(function (result) {
      if (!result.success) {
        // Trying to activate with one less check.
        result.checkParams[result.failedCheck] <- false
        if (result.failedCheck == "checkActive")
          this.showPenaltyBoosterMessageBox(handler, result.checkParams)
        else if (result.failedCheck == "checkIsInFlight")
          this.showIsInFlightAlertMessageBox(handler, result.checkParams)
      }
      cb(result)
    }.bindenv(this), handler, checkParams)
  }

  function showPenaltyBoosterMessageBox(handler, checkParams = null) {
    let effectsDiff = this.getBoostersEffectsDiffByItem()
    let bodyText = loc("msgbox/existingBoosters", {
                        newBooster = this.getName(),
                        newBoosterEffect = this.getDiffEffectText(format("%.02f", effectsDiff).tofloat())
                      })
    let savedThis = this
    handler.msgBox("activate_additional_booster", bodyText, [
      [
        "yes", @() savedThis._activate(null, handler, checkParams)
      ], [
        "no", function () {}
      ]], "no", { cancel_fn = function() {} })
  }

  function showIsInFlightAlertMessageBox(handler, checkParams = null) {
    let bodyText = loc("msgbox/isInFlightBooster")
    let savedThis = this
    handler.msgBox("activate_in_flight_booster", bodyText, [[
      "yes", @() savedThis._activate(null, handler, checkParams)
    ], [
        "no", function () {}
    ]], "no", { cancel_fn = function() {} })
  }

  function getBoosterDescriptionForMessageBox(booster) {
    local result = booster.getName()
    if (this.hasTimer())
      result = " - ".concat(result, booster.getTimeLeftText())
    return result
  }

  function _activate(cb, handler = null, checkParams = null) { //handler need only because of char operations are based on gui_handlers.BaseGuiHandlerWT.
                                   //remove it after slotOpCb will be refactored
    if (this.isActive() || !this.isInventoryItem)
      return false

    if (!handler)
      handler = get_cur_base_gui_handler()

    let checkIsInFlight = getTblValue("checkIsInFlight", checkParams, false)
    if (checkIsInFlight && isInFlight()) {
      if (cb) {
        cb({
          success = false
          failedCheck = "checkIsInFlight"
          checkParams = checkParams
        })
      }
      return false
    }

    let checkActive = getTblValue("checkActive", checkParams, false)
    if (checkActive && this.haveActiveBoosters()) {
      if (cb) {
        cb({
          success = false
          failedCheck = "checkActive"
          checkParams = checkParams
        })
      }
      return false
    }

    handler.taskId = this._requestActivate()
    if (handler.taskId >= 0) {
      set_char_cb(handler, handler.slotOpCb)
      handler.showTaskProgressBox.call(handler)
      handler.afterSlotOp =  function() {
        ::update_gamercards()
        if (cb)
          cb({ success = true })
      }
      return true
    }
    return false
  }

  function haveActiveBoosters() {
    return this.getAllActiveSameBoosters().len() > 0
  }

  function getAllActiveSameBoosters() {
    let effects = this.getEffectTypes()
    return ::ItemsManager.getInventoryList(itemType.BOOSTER,
             function (v_item) {
               if (!v_item.isActive(true) || v_item.personal != this.personal)
                 return false
               foreach (e in effects)
                 if (e.checkBooster(v_item))
                   return true
               return false
             }.bindenv(this))
  }

  function getIcon(_addItemName = true) {
    let res = "".concat(LayersIcon.genDataFromLayer(this._getBaseIconCfg()),
      LayersIcon.genInsertedDataFromLayer({ w = "0", h = "0" }, this._getMulIconCfg()),
      LayersIcon.genDataFromLayer(this._getModifiersIconCfgs()))

    return res
  }

  function _getBaseIconCfg() {
    local layerId = "booster_common"
    if (this.personal)
      layerId = "booster_personal"

    return LayersIcon.findLayerCfg(layerId)
  }

  function _getModifiersIconCfgs() {
    local layerId = ""
    if (this.wpRate > 0 && this.xpRate > 0)
      layerId = "booster_wp_exp_rate"
    else if (this.wpRate > 0)
      layerId = "booster_wp_rate"
    else if (this.xpRate > 0)
      layerId = "booster_exp_rate"

    return LayersIcon.findLayerCfg(layerId)
  }

  function _getMulIconCfg() {
    let layersArray = []
    let mul = max(this.wpRate, this.xpRate)
    let numsArray = getArrayFromInt(mul)
    if (numsArray.len() > 0) {
      let plusLayer = LayersIcon.findLayerCfg("item_plus")
      if (plusLayer)
        layersArray.append(clone plusLayer)

      foreach (_idx, int in numsArray) {
        let layer = LayersIcon.findLayerCfg($"item_num_{int}")
        if (!layer)
          continue
        layersArray.append(clone layer)
      }

      let percentLayer = LayersIcon.findLayerCfg("item_percent")
      if (percentLayer)
        layersArray.append(clone percentLayer)

      foreach (idx, _layerCfg in layersArray) {
        layersArray[idx].offsetY <- format("%.3fp.p.h * %d", this.mulIconSymbolsOffsetYMul, idx)
        layersArray[idx].x <- format("%.3fp.p.h", this.mulIconSymbolsSpacing)
        layersArray[idx].position <- "relative"
      }
    }

    return layersArray
  }

  function getEffectDesc(colored = true, _effectType = null, plainText = false) {
    local desc = plainText ? this.getEffectPlainText(this.wpRate, this.xpRate)
      : this.getEffectText(this.wpRate, this.xpRate, colored)

    if (!this.personal)
      desc = "".concat(desc, format(" (%s)", loc("boostEffect/group")))
    return desc
  }

  function _formatEffectText(value, currencyMark) {
    return "".concat(colorize("activeTextColor", $"+{value}%"), currencyMark)
  }

  function getEffectText(wpRateNum = 0, xpRateNum = 0, colored = true) {
    let text = []
    if (wpRateNum > 0.0)
      if (colored)
        text.append(this._formatEffectText(wpRateNum, loc("warpoints/short/colored")))
      else
        text.append($"+{wpRateNum}%{loc("warpoints/short/colored")}")

    if (xpRateNum > 0.0)
      if (colored)
        text.append(this._formatEffectText(xpRateNum, loc("currency/researchPoints/sign/colored")))
      else
        text.append($"+{xpRateNum}%{loc("currency/researchPoints/sign/colored")}")

    return ", ".join(text, true)
  }

  function getEffectPlainText(wpRateNum = 0, xpRateNum = 0) {
    let text = []
    if (wpRateNum > 0.0)
      text.append($"+{wpRateNum}%{loc("money/wpText")}")
    if (xpRateNum > 0.0)
      text.append($"+{xpRateNum}%{loc("money/rpText")}")
    return ", ".join(text, true)
  }

  function getDescription() {
    local desc = ""
    let locString = this.eventConditions == null
      ? "items/booster/description/uponActivation/withoutConditions"
      : "items/booster/description/uponActivation/withConditions"
    let locParams = {
      effectDesc = this.getEffectDesc()
    }
    if (this.wpRate != 0 || this.xpRate != 0)
      desc = "".concat(desc, loc(locString, locParams))
    if (this.eventConditions != null)
      desc = " ".concat(desc, this.getEventConditionsText())

    desc = "".concat(desc, "\n")

    let expireText = this.getCurExpireTimeText()
    if (expireText != "")
      desc = "\n".concat(desc, expireText)
    if (this.stopConditions != null)
      desc = "\n".concat(desc, this.getStopConditions())

    if (this.isActive(true)) {
      let effectTypes = this.getEffectTypes()
      foreach (t in effectTypes) {
        let usingBoostersArray = getActiveBoostersArray(t)
        desc = $"{desc}\n\n{getActiveBoostersDescription(usingBoostersArray, t, this)}"
      }
    }
    return desc
  }

  function getName(colored = true) {
    return  " ".concat(base.getName(colored), this.getEffectDesc())
  }

  function getShortDescription(colored = true) {
    local desc = this.getName(colored)
    if (this.eventConditions)
      desc = "".concat(desc, loc("ui/parentheses/space", { text = this.getEventConditionsText() }))
    return desc
  }

  function getEventConditionsText() {
    return getFullUnlockCondsDescInline(this.eventConditions)
  }

  _totalStopSessions = -1
  function getTotalStopSessions() {
    if (this._totalStopSessions < 0) {
      let mainCondition = getMainProgressCondition(this.stopConditions)
      this._totalStopSessions = getTblValue("num", mainCondition, 0)
    }
    return this._totalStopSessions
  }

  function getLeftStopSessions() {
    if (this.stopProgress == null)
      return null

    local res = this.getTotalStopSessions() - this.stopProgress
    if (this.spentInSessionTimeMin && isInFlight())
      res -= (time.secondsToMinutes(get_mission_time()) / this.spentInSessionTimeMin).tointeger()
    return max(0, res)
  }

  function getExpireFlightTime() {
    if (this.stopProgress == null)
      return -1
    return this.spentInSessionTimeMin * time.minutesToSeconds(this.getTotalStopSessions() - this.stopProgress)
  }

  function getStopConditions() {
    if (!this.stopConditions)
      return ""

    let textsList = []
    // Shows progress as count down 6, 5, 4, ... instead of 0/6, 1/6, ...
    let curValue = this.getLeftStopSessions()
    let params = { locEnding = this.isActive() ? "/inverted" : "/activeFor" }
    textsList.append(getFullUnlockCondsDesc(this.stopConditions, null, curValue, params))

    if (this.spentInSessionTimeMin)
      textsList.append(colorize("fadedTextColor", loc("booster/progressFrequency", { num = this.spentInSessionTimeMin })))

    return "\n".join(textsList, true)
  }

  function getEffectTypes() {
    let effectTypes = []
    foreach (effectType in boosterEffectType) {
      if (effectType.checkBooster(this))
        effectTypes.append(effectType)
    }
    return effectTypes
  }

  function getContentIconData() {
    let icon = this.getEventTypeIcon()
    return icon ? { contentIcon = icon } : null
  }

  function getEventTypeIcon() {
    return getTblValue("iconImg", this.eventTypeData)
  }

  function canStack(item) {
    if (item.iType != this.iType || item.personal != this.personal)
      return false
    foreach (efType in boosterEffectType)
      if ((efType.getValue(this) > 0) != (efType.getValue(item) > 0))
        return false
    return (this.eventConditions == item.eventConditions) || u.isEqual(this.eventConditions, item.eventConditions)
  }

  function updateStackParams(stackParams) {
    foreach (efType in boosterEffectType) {
      let value = efType.getValue(this)
      if (!value)
        continue

      let efTypeName = efType.name
      let valTbl = getTblValue(efTypeName, stackParams, {})
      let minVal = getTblValue("min", valTbl)
      valTbl.min <- minVal ? min(minVal, value) : value
      let maxVal = getTblValue("max", valTbl)
      valTbl.max <- maxVal ? max(maxVal, value) : value
      stackParams[efTypeName] <- valTbl
    }
  }

  function getStackName(stackParams) {
    local res = colorize("activeTextColor", loc($"item/{this.defaultLocId}"))
    let effects = []
    foreach (efType in boosterEffectType) {
      let valTbl = getTblValue(efType.name, stackParams)
      if (!valTbl || (!("min" in valTbl)))
        continue

      let minText = this._formatEffectText(valTbl.min, efType.currencyMark)
      if (valTbl.min == valTbl.max)
        effects.append(minText)
      else
        effects.append(loc("item/effect/from_to", {
                         min = minText
                         max = this._formatEffectText(valTbl.max, efType.currencyMark)
                       }))
    }
    if (effects.len())
      res = "".concat(res, " (", ", ".join(effects, true), ")")
    if (this.eventConditions)
      res = "".concat(res, " (", this.getEventConditionsText(), ")")
    return res
  }
}

let FakeBooster = class (Booster) {
  static name = "FakeBooster"
  static iType = itemType.FAKE_BOOSTER
  showBoosterInSeparateList = true

  constructor(blk, invBlk = null, slotData = null) {
    base.constructor(blk, invBlk, slotData)
    this.iconStyle = blk?.iconStyle ?? this.id
  }

  function getIcon(addItemName = true) {
    return base.getIcon(addItemName)
  }

  function getName(colored = true) {
    return base.getName(colored)
  }

  function getDescription() {
    local desc = "".concat(base.getDescription(), loc("ui/colon"), this.getEffectDesc())
    if (!this.isInventoryItem)
      return desc

    let bonusArray = []
    foreach (effect in boosterEffectType) {
      let value = ::get_squad_bonus_for_same_cyber_cafe(effect)
      if (value <= 0)
        continue
      let percent = measureType.PERCENT_FLOAT.getMeasureUnitsText(value, false)
      bonusArray.append(effect.getText(this._formatEffectText(percent, ""), true, false))
    }

    if (bonusArray.len()) {
      desc = "".concat(desc, "\n",
        loc("item/FakeBoosterForNetCafeLevel/squad", { num = g_squad_manager.getSameCyberCafeMembersNum() }),
        loc("ui/colon"), ", ".join(bonusArray, true))
    }

    return desc
  }

  function getEffectDesc(colored = true, effectType = null, plainText = false) {
    local desc = ""
    if (effectType == boosterEffectType.WP)
      desc = plainText ? this.getEffectPlainText(this.wpRate, 0)
        : this.getEffectText(this.wpRate, 0, colored)
    else if (effectType == boosterEffectType.RP)
      desc = plainText ? this.getEffectPlainText(0, this.xpRate)
        : this.getEffectText(0, this.xpRate, colored)
    else
      desc = plainText ? this.getEffectPlainText(this.wpRate, this.xpRate)
        : this.getEffectText(this.wpRate, this.xpRate, colored)

    if (!this.personal)
      desc = "".concat(desc, format(" (%s)", loc("boostEffect/group")))
    return desc
  }

  function isActive(...) { return true }
}

return { Booster, FakeBooster }