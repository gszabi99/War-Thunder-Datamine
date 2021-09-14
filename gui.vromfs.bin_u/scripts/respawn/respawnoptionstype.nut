local enums = require("sqStdlibs/helpers/enums.nut")
local { DECORATION } = require("scripts/utils/genericTooltipTypes.nut")
local { bombNbr, hasCountermeasures } = require("scripts/unit/unitStatus.nut")
local { isTripleColorSmokeAvailable } = require("scripts/options/optionsManager.nut")

local options = {
  types = []
  cache = {
    bySortId = {}
  }
}

local _isVisible = @(p) p.unit != null
  && isAvailableInMission()
  && (!p.isRandomUnit || isShowForRandomUnit)
  && isShowForUnit(p)

local _isNeedUpdateByTrigger = @(trigger) isAvailableInMission() && (trigger & triggerUpdateBitMask) != 0
local _isNeedUpdContentByTrigger = @(trigger, p) (trigger & triggerUpdContentBitMask) != 0

local function _update(p, trigger, isAlreadyFilled) {
  if (!isNeedUpdateByTrigger(trigger))
    return false

  local isShow = isVisible(p)
  local isEnable = isShow && p.canChangeAircraft
  local isNeedUpdateContent = !isAlreadyFilled || isNeedUpdContentByTrigger(trigger, p)
  local isFilled = false

  local obj = p.handler.scene.findObject(id)
  if (obj?.isValid()) {
    obj.enable(isEnable)
    if (isShow && isNeedUpdateContent) {
      local opt = getUseropt(p)
      if (cType == optionControlType.LIST) {
        local markup = ::create_option_list(null, opt.items, opt.value, null, false)
        p.handler.guiScene.replaceContentFromText(obj, markup, markup.len(), p.handler)
      }
      else if (cType == optionControlType.CHECKBOX)
        if (obj.getValue() != opt.value)
          obj.setValue(opt.value)
      isFilled = true
      if (needCallCbOnContentUpdate)
        p.handler?[cb].call(p.handler, obj)
    }
  }

  local rowObj = p.handler.scene.findObject($"{id}_tr")
  if (rowObj?.isValid()) {
    rowObj.show(isShow)
  }
  return isFilled
}

options.template <- {
  id = "" // Generated from type name
  sortId = 0
  getLabelText = @() ::loc($"options/{id}")
  userOption = -1
  triggerUpdateBitMask = 0
  triggerUpdContentBitMask = 0
  cType = optionControlType.LIST
  needSetToReqData = false
  cb = "checkReady"
  needCallCbOnContentUpdate = false
  isShowForRandomUnit = true

  isAvailableInMission = @() true
  isShowForUnit = @(p) false
  isVisible = _isVisible
  getUseropt = @(p) ::get_option(userOption)
  isNeedUpdateByTrigger = _isNeedUpdateByTrigger
  isNeedUpdContentByTrigger = _isNeedUpdContentByTrigger
  update = _update
}

options.addTypes <- function(typesTable) {
  enums.addTypes(this, typesTable, null, "id")
  types.sort(@(a, b) a.sortIdx <=> b.sortIdx)
}

local idx = -1
options.addTypes({
  unknown = {
    sortIdx = idx++
    userOption = -1
    isShowForRandomUnit = false
    isAvailableInMission = @() false
  }
  skin = {
    sortIdx = idx++
    userOption = ::USEROPT_SKIN
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    isShowForRandomUnit = false
    isShowForUnit = @(p) true
    getUseropt = function(p) {
      local skinsOpt = ::g_decorator.getSkinsOption(p.unit?.name ?? "")
      skinsOpt.items = skinsOpt.items.map(@(v, idx) v.__merge({
        tooltipObj = { id = DECORATION.getTooltipId(skinsOpt.decorators[idx].id, ::UNLOCKABLE_SKIN) }
      }))
      return skinsOpt
    }
  }
  user_skins = {
    sortIdx = idx++
    userOption = ::USEROPT_USER_SKIN
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    isShowForRandomUnit = false
    isAvailableInMission = @() ::has_feature("UserSkins")
    isShowForUnit = @(p) true
  }
  gun_target_dist = {
    sortIdx = idx++
    userOption = ::USEROPT_GUN_TARGET_DISTANCE
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID
    triggerUpdContentBitMask = RespawnOptUpdBit.NEVER
    needSetToReqData = true
    isShowForUnit = @(p) (p.unit.isAir() || p.unit.isHelicopter())
  }
  gun_vertical_targeting = {
    sortIdx = idx++
    userOption = ::USEROPT_GUN_VERTICAL_TARGETING
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID
    triggerUpdContentBitMask = RespawnOptUpdBit.NEVER
    cType = optionControlType.CHECKBOX
    needSetToReqData = true
    isAvailableInMission = @() ::is_gun_vertical_convergence_allowed()
    isShowForUnit = @(p) (p.unit.isAir() || p.unit.isHelicopter())
  }
  bomb_activation_time = {
    sortIdx = idx++
    userOption = ::USEROPT_BOMB_ACTIVATION_TIME
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    needSetToReqData = true
    isShowForRandomUnit = false
    isShowForUnit = @(p) (p.unit.isAir() || p.unit.isHelicopter()) && p.unit.getAvailableSecondaryWeapons().hasBombs
  }
  bomb_series = {
    sortIdx = idx++
    userOption = ::USEROPT_BOMB_SERIES
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    isShowForRandomUnit = false
    isShowForUnit = @(p) (p.unit.isAir() || p.unit.isHelicopter()) && bombNbr(p.unit) > 1
  }
  depthcharge_activation_time = {
    sortIdx = idx++
    userOption = ::USEROPT_DEPTHCHARGE_ACTIVATION_TIME
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    needSetToReqData = true
    isShowForRandomUnit = false
    isShowForUnit = @(p) p.unit.isShipOrBoat()
      && p.unit.isDepthChargeAvailable() && p.unit.getAvailableSecondaryWeapons().hasDepthCharges
  }
  rocket_fuse_dist = {
    sortIdx = idx++
    userOption = ::USEROPT_ROCKET_FUSE_DIST
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    needSetToReqData = true
    isShowForRandomUnit = false
    isShowForUnit = @(p) (p.unit.isAir() || p.unit.isHelicopter())
      && p.unit.getAvailableSecondaryWeapons().hasRocketDistanceFuse
  }
  torpedo_dive_depth = {
    sortIdx = idx++
    userOption = ::USEROPT_TORPEDO_DIVE_DEPTH
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    needSetToReqData = true
    isShowForRandomUnit = false
    isAvailableInMission = @() !::get_option_torpedo_dive_depth_auto()
    isShowForUnit = @(p) p.unit.isShipOrBoat() && p.unit.getAvailableSecondaryWeapons().hasTorpedoes
  }
  fuel_amount = {
    sortIdx = idx++
    userOption = ::USEROPT_LOAD_FUEL_AMOUNT
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    needSetToReqData = true
    isShowForRandomUnit = false
    isShowForUnit = @(p) (p.unit.isAir() || p.unit.isHelicopter())
  }
  countermeasures_periods = {
    sortIdx = idx++
    userOption = ::USEROPT_COUNTERMEASURES_PERIODS
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    isShowForRandomUnit = false
    isShowForUnit = @(p) (p.unit.isAir() || p.unit.isHelicopter()) && hasCountermeasures(p.unit)
  }
  countermeasures_series_periods = {
    sortIdx = idx++
    userOption = ::USEROPT_COUNTERMEASURES_SERIES_PERIODS
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    isShowForRandomUnit = false
    isShowForUnit = @(p) (p.unit.isAir() || p.unit.isHelicopter()) && hasCountermeasures(p.unit)
  }
  countermeasures_series = {
    sortIdx = idx++
    userOption = ::USEROPT_COUNTERMEASURES_SERIES
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    isShowForRandomUnit = false
    isShowForUnit = @(p) (p.unit.isAir() || p.unit.isHelicopter()) && hasCountermeasures(p.unit)
  }
  respawn_base = {
    sortIdx = idx++
    userOption = -1
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.RESPAWN_BASES
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.RESPAWN_BASES
    cb = "onRespawnbaseOptionUpdate"
    needCallCbOnContentUpdate = true
    isShowForUnit = @(p) p.haveRespawnBases
    getUseropt = @(p) {
      items = p.respawnBasesList.map(@(spawn) { text = spawn.getTitle() })
      value = p.respawnBasesList.indexof(p.curRespawnBase) ?? -1
    }
    isNeedUpdContentByTrigger = @(trigger, p) _isNeedUpdContentByTrigger(trigger, p) && p.isRespawnBasesChanged
  }
  aerobatics_smoke_type = {
    sortIdx = idx++
    userOption = ::USEROPT_AEROBATICS_SMOKE_TYPE
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID
    triggerUpdContentBitMask = RespawnOptUpdBit.NEVER
    cb = "onSmokeTypeUpdate"
    isShowForUnit = @(p) p.unit.isAir()
  }
  aerobatics_smoke_left_color = {
    sortIdx = idx++
    userOption = ::USEROPT_AEROBATICS_SMOKE_LEFT_COLOR
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.SMOKE_TYPE
    triggerUpdContentBitMask = RespawnOptUpdBit.NEVER
    isShowForUnit = @(p) p.unit.isAir() && isTripleColorSmokeAvailable()
  }
  aerobatics_smoke_right_color = {
    sortIdx = idx++
    userOption = ::USEROPT_AEROBATICS_SMOKE_RIGHT_COLOR
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.SMOKE_TYPE
    triggerUpdContentBitMask = RespawnOptUpdBit.NEVER
    isShowForUnit = @(p) p.unit.isAir() && isTripleColorSmokeAvailable()
  }
  aerobatics_smoke_tail_color = {
    sortIdx = idx++
    userOption = ::USEROPT_AEROBATICS_SMOKE_TAIL_COLOR
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.SMOKE_TYPE
    triggerUpdContentBitMask = RespawnOptUpdBit.NEVER
    isShowForUnit = @(p) p.unit.isAir() && isTripleColorSmokeAvailable()
  }
})

options.get <- @(id) this?[id] ?? unknown

return options
