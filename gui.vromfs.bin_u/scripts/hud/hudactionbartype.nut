//-file:plus-string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let enums = require("%sqStdLibs/helpers/enums.nut")
let time = require("%scripts/time.nut")
let actionBarInfo = require("%scripts/hud/hudActionBarInfo.nut")
let { getModificationByName } = require("%scripts/weaponry/modificationInfo.nut")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { getActionShortcutIndexByType, getActionBarUnitName, getOwnerUnitName } = require("hudActionBar")
let { EII_BULLET, EII_ARTILLERY_TARGET, EII_ANTI_AIR_TARGET, EII_EXTINGUISHER,
  EII_SPECIAL_UNIT, EII_WINCH, EII_WINCH_DETACH, EII_WINCH_ATTACH, EII_TOOLKIT,
  EII_MEDICALKIT, EII_TORPEDO, EII_TORPEDO_SIGHT, EII_HULL_AIMING, EII_DEPTH_CHARGE,
  EII_MINE, EII_MORTAR, EII_ROCKET, EII_GRENADE, EII_SMOKE_GRENADE, EII_REPAIR_BREACHES,
  EII_SMOKE_SCREEN, EII_SCOUT, EII_SUBMARINE_SONAR, EII_TORPEDO_SENSOR, EII_SPEED_BOOSTER,
  EII_SHIP_CURRENT_TRIGGER_GROUP, EII_AI_GUNNERS, EII_AUTO_TURRET, EII_SUPPORT_PLANE, EII_SUPPORT_PLANE_2,
  EII_SUPPORT_PLANE_ORBITING, EII_SUPPORT_PLANE_CHANGE, EII_SUPPORT_PLANE_GROUP_ATTACK, EII_STEALTH, EII_LOCK,
  EII_WEAPON_LEAD, EII_FORCED_GUN,
  WEAPON_PRIMARY, WEAPON_SECONDARY, WEAPON_MACHINEGUN, AI_GUNNERS_DISABLED, AI_GUNNERS_ALL_TARGETS,
  AI_GUNNERS_AIR_TARGETS, AI_GUNNERS_GROUND_TARGETS, AI_GUNNERS_SHELL, EII_TERRAFORM, EII_DIVING_LOCK,
  EII_SHIP_DAMAGE_CONTROL, EII_NIGHT_VISION, EII_SIGHT_STABILIZATION,
  GUIDANCE_LEAD_MODE_OFF, GUIDANCE_LEAD_MODE_ON, EII_UGV, EII_MINE_DETONATION, EII_UNLIMITED_CONTROL, EII_DESIGNATE_TARGET,
  EII_ROCKET_AIR, EII_AGM_AIR, EII_AAM_AIR, EII_BOMB_AIR, EII_GUIDED_BOMB_AIR,
  EII_JUMP, EII_SPRINT, EII_TOGGLE_VIEW,
} = require("hudActionBarConst")
let { getHudUnitType } = require("hudState")
let { HUD_UNIT_TYPE } = require("%scripts/hud/hudUnitType.nut")

::g_hud_action_bar_type <- {
  types = []

  cache = { byCode = {} }
}

let getActionDescByWeaponTriggerGroup = function(actionItem, triggerGroup) {
  local res = actionBarInfo.getActionDesc(getActionBarUnitName(), triggerGroup)
  let cooldownTime = actionItem?.cooldownTime
  if (cooldownTime)
    res += ("\n" + loc("shop/reloadTime") + " " + time.secondsToString(cooldownTime, true, true))
  return res
}

let function getCooldownText(actionItem) {
  let cooldownTime = actionItem?.cooldownTime
  if (cooldownTime)
    return $"\n{loc("shop/reloadTime")} {time.secondsToString(cooldownTime, true, true)}"
  return ""
}

let getUnit = @() ::getAircraftByName(getActionBarUnitName())
let getOwnerUnit = @() ::getAircraftByName(getOwnerUnitName())

::g_hud_action_bar_type.template <- {
  code = -1
  backgroundImage = ""

  /**
   * For all items, which should be grouped
   * as stricks this field is true, even if
   * this item is not a kill streak reward.
   *
   * In present design this field is true for
   * artillery and special unit.
   */
  isForWheelMenu = @() false
  isForSelectWeaponMenu = @() false
  canSwitchAutomaticMode = @() false

  _name = ""
  _icon = ""
  _title = ""
  needAnimOnIncrementCount = false

  getName        = @(_actionItem, _killStreakTag = null) this._name
  getIcon        = @(_actionItem, _killStreakTag = null, _unit = null, _hudUnitType = null) this._icon
  getTitle       = @(_actionItem, _killStreakTag = null) this._title
  getTooltipText = function(actionItem = null) {
    local res = loc("actionBarItem/" + this.getName(actionItem, actionItem?.killStreakUnitTag))
    res = $"{res}{getCooldownText(actionItem)}"
    if (actionItem?.automatic)
      res += "\n" + loc("actionBar/action/automatic")
    return res
  }

  getShortcut = function(actionItem = null, hudUnitType = null) {
    hudUnitType = hudUnitType ?? getHudUnitType()
    let shortcutIdx = actionItem?.shortcutIdx ?? getActionShortcutIndexByType(this.code)
    if (shortcutIdx < 0)
      return null

    if (hudUnitType == HUD_UNIT_TYPE.SHIP_EX)
      return "ID_SUBMARINE_ACTION_BAR_ITEM_" + (shortcutIdx + 1)
    if (hudUnitType == HUD_UNIT_TYPE.SHIP)
      return "ID_SHIP_ACTION_BAR_ITEM_" + (shortcutIdx + 1)
    //



    return "ID_ACTION_BAR_ITEM_" + (shortcutIdx + 1)
  }

  getVisualShortcut = function(actionItem = null, hudUnitType = null) {
    hudUnitType = hudUnitType ?? getHudUnitType()
    let shortcut = this.getShortcut(actionItem, hudUnitType)
    let isBound = shortcut != null
      && ::g_shortcut_type.getShortcutTypeByShortcutId(shortcut).isAssigned(shortcut)
    if ((!this.isForWheelMenu() && !this.isForSelectWeaponMenu()) || isBound)
      return shortcut

    if (hudUnitType == HUD_UNIT_TYPE.SHIP_EX)
      return "ID_SUBMARINE_KILLSTREAK_WHEEL_MENU"
    if (hudUnitType == HUD_UNIT_TYPE.SHIP)
      return "ID_SHIP_KILLSTREAK_WHEEL_MENU"
    if (hudUnitType == HUD_UNIT_TYPE.AIRCRAFT)
      return "ID_PLANE_KILLSTREAK_WHEEL_MENU"
    //



    if (hudUnitType == HUD_UNIT_TYPE.HUMAN)
      return "ID_HUMAN_KILLSTREAK_WHEEL_MENU"
    return "ID_KILLSTREAK_WHEEL_MENU"
  }
}

enums.addTypesByGlobalName("g_hud_action_bar_type", {
  UNKNOWN = {
    _name = "unknown"
  }

  BULLET = {
    code = EII_BULLET
    _name = "bullet"
    needAnimOnIncrementCount = true
  }

  WEAPON_PRIMARY = {
    code = WEAPON_PRIMARY
    isForSelectWeaponMenu = @() true
    _name = "weaponPrimary"
    _icon = "!ui/gameuiskin#artillery_weapon_state_indicator.svg"
    _title = loc("hotkeys/ID_SHIP_WEAPON_PRIMARY")
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_SHIP_WEAPON_PRIMARY"
  }

  WEAPON_SECONDARY = {
    code = WEAPON_SECONDARY
    isForSelectWeaponMenu = @() true
    _name = "weaponSecondary"
    _icon = "!ui/gameuiskin#artillery_secondary_weapon_state_indicator.svg"
    _title = loc("hotkeys/ID_SHIP_WEAPON_SECONDARY")
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_SHIP_WEAPON_SECONDARY"
  }

  WEAPON_MACHINEGUN = {
    code = WEAPON_MACHINEGUN
    isForSelectWeaponMenu = @() true
    _name = "weaponMachineGun"
    _icon = "!ui/gameuiskin#machine_gun_weapon_state_indicator.svg"
    _title = loc("hotkeys/ID_SHIP_WEAPON_MACHINEGUN")
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_SHIP_WEAPON_MACHINEGUN"
  }

  TORPEDO_SIGHT = {
    code = EII_TORPEDO_SIGHT
    _name = "torpedo_sight"
    _icon = "#ui/gameuiskin#torpedo_sight"
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_SHIP_TORPEDO_SIGHT"
  }

  HULL_AIMING = {
    code = EII_HULL_AIMING
    _name = "hull_aiming"
    _icon = "#ui/gameuiskin#hull_aiming_mode"
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_ENABLE_GM_HULL_AIMING"
  }

  TORPEDO = {
    code = EII_TORPEDO
    _name = "torpedo"
    _icon = "#ui/gameuiskin#torpedo_multiple"
    getShortcut = @(_actionItem, hudUnitType = null)
      hudUnitType == HUD_UNIT_TYPE.SHIP_EX ? "ID_SUBMARINE_WEAPON_TORPEDOES"
        : "ID_SHIP_WEAPON_TORPEDOES"
    getIcon = function (actionItem, _killStreakTag = null, _unit = null, _hudUnitType = null) {
      let isSingleTorpedoSelected = (actionItem?.userHandle ?? 0) == 1
      return isSingleTorpedoSelected ?  "#ui/gameuiskin#torpedo" : this._icon
    }
    getTooltipText = @(actionItem = null) getActionDescByWeaponTriggerGroup(actionItem, "torpedoes")
  }

  DEPTH_CHARGE = {
    code = EII_DEPTH_CHARGE
    _name = "depth_charge"
    _icon = "#ui/gameuiskin#depth_charge"
    getShortcut = @(_actionItem, hudUnitType = null)
      hudUnitType == HUD_UNIT_TYPE.SHIP_EX ? "ID_SUBMARINE_WEAPON_DEPTH_CHARGE"
        : "ID_SHIP_WEAPON_DEPTH_CHARGE"
    getTooltipText = @(actionItem = null) getActionDescByWeaponTriggerGroup(actionItem, "bombs")
  }

  MINE = {
    code = EII_MINE
    _name = "mine"
    _icon = "#ui/gameuiskin#naval_mine"
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_SHIP_WEAPON_MINE"
    getTooltipText = @(actionItem = null) getActionDescByWeaponTriggerGroup(actionItem, "mines")
  }

  MORTAR = {
    code = EII_MORTAR
    _name = "mortar"
    _icon = "#ui/gameuiskin#ship_mortar_bomb"
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_SHIP_WEAPON_MORTAR"
  }

  ROCKET = {
    code = EII_ROCKET
    _name = "rocket"
    _icon = "#ui/gameuiskin#rocket"
    getShortcut = function(_actionItem, hudUnitType = null) {
      if (hudUnitType == HUD_UNIT_TYPE.SHIP_EX)
        return "ID_SUBMARINE_WEAPON_ROCKETS"
      if (hudUnitType == HUD_UNIT_TYPE.SHIP)
        return "ID_SHIP_WEAPON_ROCKETS"
      if (hudUnitType == HUD_UNIT_TYPE.TANK)
        return "ID_FIRE_GM_SPECIAL_GUN"
      if (hudUnitType == HUD_UNIT_TYPE.HUMAN)
        return "ID_FIRE_HUMAN_SPECIAL_GUN"
      return "ID_ROCKETS"
    }
    getTooltipText = @(actionItem = null) getActionDescByWeaponTriggerGroup(actionItem, "rockets")
  }

  ROCKET_AIR = {
    code = EII_ROCKET_AIR
    _name = "rocket_air"
    _icon = "#ui/gameuiskin#rocket"
    _title = loc("hotkeys/ID_ROCKETS")
    getShortcut = function(_actionItem, hudUnitType = null) {
      if (hudUnitType == HUD_UNIT_TYPE.HELICOPTER)
        return "ID_ROCKETS_HELICOPTER"
      return "ID_ROCKETS"
    }
    getTooltipText = @(actionItem = null) $"{this._title}{getCooldownText(actionItem)}"
  }

  AGM_AIR = {
    code = EII_AGM_AIR
    _name = "agm_air"
    _icon = "#ui/gameuiskin#atgm_heli_preset"
    _title = loc("hotkeys/ID_AGM")
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_AGM"
    getTooltipText = @(actionItem = null) $"{this._title}{getCooldownText(actionItem)}"
  }

  AAM_AIR = {
    code = EII_AAM_AIR
    _name = "aam_air"
    _icon = "#ui/gameuiskin#air_to_air_missile"
    _title = loc("hotkeys/ID_AAM")
    getShortcut = function(_actionItem, hudUnitType = null) {
      if (hudUnitType == HUD_UNIT_TYPE.HELICOPTER)
        return "ID_AAM_HELICOPTER"
      return "ID_AAM"
    }
    getTooltipText = @(actionItem = null) $"{this._title}{getCooldownText(actionItem)}"
  }

  BOMB_AIR = {
    code = EII_BOMB_AIR
    _name = "bomb_air"
    _icon = "#ui/gameuiskin#bomb_big_01"
    _title = loc("hotkeys/ID_BOMBS")
    getShortcut = function(_actionItem, hudUnitType = null) {
      if (hudUnitType == HUD_UNIT_TYPE.HELICOPTER)
        return "ID_BOMBS_HELICOPTER"
      return "ID_BOMBS"
    }
    getTooltipText = @(actionItem = null) $"{this._title}{getCooldownText(actionItem)}"
  }

  GUIDED_BOMB_AIR = {
    code = EII_GUIDED_BOMB_AIR
    _name = "guided_bomb_air"
    _icon = "#ui/gameuiskin#bomb_big_01"
    _title = loc("hotkeys/ID_GUIDED_BOMBS")
    getShortcut = function(_actionItem, hudUnitType = null) {
      if (hudUnitType == HUD_UNIT_TYPE.HELICOPTER)
        return "ID_GUIDED_BOMBS_HELICOPTER"
      return "ID_GUIDED_BOMBS"
    }
    getTooltipText = @(actionItem = null) $"{this._title}{getCooldownText(actionItem)}"
  }

  GRENADE = {
    code = EII_GRENADE
    _name = "grenade"
    _icon = "#ui/gameuiskin#vog_ship"
    getShortcut = @(_actionItem, hudUnitType = null) hudUnitType == HUD_UNIT_TYPE.TANK
      ? "ID_FIRE_GM_SPECIAL_GUN"
      : "ID_ROCKETS"
    getTooltipText = @(actionItem = null) getActionDescByWeaponTriggerGroup(actionItem, "rockets")
  }

  SMOKE_GRENADE = {
    code = EII_SMOKE_GRENADE
    _name = "smoke_screen"
    isForWheelMenu = @() true
    _icon = "#ui/gameuiskin#smoke_screen"
    getTitle = function(_actionItem, _killStreakTag = null) {
      if (getHudUnitType() == HUD_UNIT_TYPE.HUMAN)
        return loc("hotkeys/ID_HUMAN_SMOKE_GRENADE")
      return getHudUnitType() == HUD_UNIT_TYPE.SHIP
      ? loc("hotkeys/ID_SHIP_SMOKE_GRENADE")
      : loc("hotkeys/ID_SMOKE_SCREEN")
    }
    getShortcut = function(_actionItem, hudUnitType = null) {
      if (hudUnitType == HUD_UNIT_TYPE.HUMAN)
        return "ID_HUMAN_SMOKE_GRENADE"
      return hudUnitType == HUD_UNIT_TYPE.SHIP ? "ID_SHIP_SMOKE_GRENADE" : "ID_SMOKE_SCREEN"
    }
  }

  SMOKE_SCREEN = {
    code = EII_SMOKE_SCREEN
    _name = "engine_smoke_screen_system"
    isForWheelMenu = @() true
    _icon = "#ui/gameuiskin#engine_smoke_screen_system"
    _title = loc("hotkeys/ID_SMOKE_SCREEN_GENERATOR")
    getShortcut = function(_actionItem, hudUnitType = null) {
      if (hudUnitType == HUD_UNIT_TYPE.SHIP_EX)
        return "ID_SUBMARINE_ACOUSTIC_COUNTERMEASURES"
      if (hudUnitType == HUD_UNIT_TYPE.SHIP)
        return "ID_SHIP_SMOKE_SCREEN_GENERATOR"
      if (hudUnitType == HUD_UNIT_TYPE.TANK)
        return "ID_SMOKE_SCREEN_GENERATOR"
      return "ID_PLANE_SMOKE_SCREEN_GENERATOR"
    }
    getIcon = function(_actionItem, _killStreakTag = null, _unit = null, hudUnitType = null) {
      hudUnitType = hudUnitType ?? getHudUnitType()
      return hudUnitType == HUD_UNIT_TYPE.SHIP_EX
        ? "#ui/gameuiskin#acoustic_countermeasures"
        : this._icon
    }
    getTitle = @(_actionItem, _killStreakTag = null)
      getHudUnitType() == HUD_UNIT_TYPE.SHIP_EX
        ? loc("hotkeys/ID_SUBMARINE_ACOUSTIC_COUNTERMEASURES")
        : this._title
    getName = @(_actionItem, _killStreakTag = null)
      getHudUnitType() == HUD_UNIT_TYPE.SHIP_EX
        ? "acoustic_countermeasure"
        : this._name
  }

  SCOUT = {
    code = EII_SCOUT
    _name = "scout_active"
    _icon = "#ui/gameuiskin#scouting"
    _title = loc("hotkeys/ID_SCOUT")
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_SCOUT"
  }

  SONAR = {
    code = EII_SUBMARINE_SONAR
    isForWheelMenu = @() true
    _name = "sonar_active"
    _icon = "#ui/gameuiskin#sonar_indicator"
    _title = loc("hotkeys/ID_SUBMARINE_SWITCH_ACTIVE_SONAR")
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_SUBMARINE_SWITCH_ACTIVE_SONAR"
  }

  TORPEDO_SENSOR = {
    code = EII_TORPEDO_SENSOR
    isForWheelMenu = @() true
    _name = "torpedo_sensor"
    _icon = "#ui/gameuiskin#torpedo_active_sonar"
    _title = loc("hotkeys/ID_SUBMARINE_WEAPON_TOGGLE_ACTIVE_SENSOR")
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_SUBMARINE_WEAPON_TOGGLE_ACTIVE_SENSOR"
  }

  ARTILLERY_TARGET = {
    code = EII_ARTILLERY_TARGET
    _name = "artillery_target"
    isForWheelMenu = @() true
    _icon = "#ui/gameuiskin#artillery_fire"
    _title = loc("hotkeys/ID_ACTION_BAR_ITEM_5")
    needAnimOnIncrementCount = true
    getIcon = function (_actionItem, _killStreakTag = null, _unit = null, _hudUnitType = null) {
      local mis = ::get_current_mission_info_cached()
      if ((mis?.customArtilleryImage ?? "") != "")
        return mis.customArtilleryImage
      return mis?.useCustomSuperArtillery ? "#ui/gameuiskin#artillery_fire_on_target" : this._icon
    }
  }

  EXTINGUISHER = {
    code = EII_EXTINGUISHER
    isForWheelMenu = @() getHudUnitType() == HUD_UNIT_TYPE.SHIP
    canSwitchAutomaticMode = @() getHudUnitType() == HUD_UNIT_TYPE.SHIP
    _name = "extinguisher"
    _icon = "#ui/gameuiskin#extinguisher"
    _title = loc("hotkeys/ID_ACTION_BAR_ITEM_6")
    needAnimOnIncrementCount = true
    getIcon = function(_actionItem, _killStreakTag = null, _unit = null, hudUnitType = null) {
      hudUnitType = hudUnitType ?? getHudUnitType()
      return hudUnitType == HUD_UNIT_TYPE.SHIP
        ? "#ui/gameuiskin#manual_ship_extinguisher"
        : "#ui/gameuiskin#extinguisher"
    }
  }

  TOOLKIT = {
    code = EII_TOOLKIT
    isForWheelMenu = @() getHudUnitType() == HUD_UNIT_TYPE.SHIP
    canSwitchAutomaticMode = @() getHudUnitType() == HUD_UNIT_TYPE.SHIP
    _name = "toolkit"
    _icon = "#ui/gameuiskin#tank_tool_kit"
    _title = loc("hotkeys/ID_SHIP_ACTION_BAR_ITEM_11")
    getIcon = function(_actionItem, _killStreakTag = null, _unit = null, hudUnitType = null) {
      hudUnitType = hudUnitType ?? getHudUnitType()
      return hudUnitType == HUD_UNIT_TYPE.SHIP
        ? "#ui/gameuiskin#ship_tool_kit"
        : "#ui/gameuiskin#tank_tool_kit"
    }
  }

  MEDICALKIT = {
    code = EII_MEDICALKIT
    isForWheelMenu = @() true
    _name = "medicalkit"
    _icon = "#ui/gameuiskin#tank_medkit"
    _title = loc("hints/tank_medkit")
    needAnimOnIncrementCount = true

    getIcon = function (_actionItem, _killStreakTag = null, unit = null, _hudUnitType = null) {
      unit = unit ?? getUnit()
      let mod = getModificationByName(unit, "tank_medical_kit")
      return mod?.image ?? this._icon
    }
  }

  ANTI_AIR_TARGET = {
    code = EII_ANTI_AIR_TARGET
    _name = "anti_air_target"
    _icon = "" //"#ui/gameuiskin#anti_air_target" //there is no such icon now
                                                  //commented for avoid crash
    _title = "" //loc("encyclopedia/anti_air")
  }

  SPECIAL_UNIT = {
    code = EII_SPECIAL_UNIT
    _name = "special_unit"
    isForWheelMenu = @() true

    getName = function (_actionItem, killStreakTag = null) {
      if (::u.isString(killStreakTag))
        return this._name + "_" + killStreakTag
      return ""
    }

    getIcon = function (_actionItem, killStreakTag = null, _unit = null, _hudUnitType = null) {
      // killStreakTag is expected to be "bomber", "attacker" or "fighter".
      if (::u.isString(killStreakTag))
        return $"#ui/gameuiskin#{killStreakTag}_streak"
      return ""
    }

    getTitle = function (_actionItem, killStreakTag = null) {
      if (killStreakTag == "bomber")
        return loc("hotkeys/ID_ACTION_BAR_ITEM_9")
      if (killStreakTag == "attacker")
        return loc("hotkeys/ID_ACTION_BAR_ITEM_8")
      if (killStreakTag == "fighter")
        return loc("hotkeys/ID_ACTION_BAR_ITEM_7")
      return ""
    }
  }

  SPEED_BOOSTER = {
    code = EII_SPEED_BOOSTER
    isForWheelMenu = @() true
    _name = "speed_booster"
    _title = loc("hotkeys/ID_EVENT_ACTION")
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_EVENT_ACTION"

    getIcon = function (_actionItem, _killStreakTag = null, unit = null, _hudUnitType = null) {
      unit = unit ?? getUnit()
      let mod = getModificationByName(unit, "ship_race_speed_boost")
      return mod?.image ?? ""
    }
  }

  WINCH = {
    code = EII_WINCH
    backgroundImage = "#ui/gameuiskin#winch_request"
    isForWheelMenu = @() true
    _name = "winch"
    _icon = "#ui/gameuiskin#winch_request"
    _title = loc("hints/winch_request")
  }

  WINCH_DETACH = {
    code = EII_WINCH_DETACH
    backgroundImage = "#ui/gameuiskin#winch_request_off"
    isForWheelMenu = @() true
    _name = "winch_detach"
    _icon = "#ui/gameuiskin#winch_request_off"
    _title = loc("hints/winch_detach")
  }

  WINCH_ATTACH = {
    code = EII_WINCH_ATTACH
    backgroundImage = "#ui/gameuiskin#winch_request_deploy"
    isForWheelMenu = @() true
    _name = "winch_attach"
    _icon = "#ui/gameuiskin#winch_request_deploy"
    _title = loc("hints/winch_use")
  }

  REPAIR_BREACHES = {
    code = EII_REPAIR_BREACHES
    isForWheelMenu = @() true
    canSwitchAutomaticMode = @() true
    _name = "repair_breaches"
    _icon = "#ui/gameuiskin#unwatering"
    _title = loc("hotkeys/ID_REPAIR_BREACHES")
    getShortcut = @(_actionItem, hudUnitType = null)
      hudUnitType == HUD_UNIT_TYPE.SHIP_EX
        ? "ID_SUBMARINE_REPAIR_BREACHES"
        : "ID_REPAIR_BREACHES"
  }

  ACTIVATE_SHIP_DAMAGE_CONTROL = {
    code = EII_SHIP_DAMAGE_CONTROL
    isForWheelMenu = @() true
    canSwitchAutomaticMode = @() false
    getTitle = @(actionItem, _killStreakTag = null)
      loc("hotkeys/ID_SHIP_DAMAGE_CONTROL_PRESET_" + (actionItem.userHandle >> 3).tostring())
    getName = @(actionItem, _killStreakTag = null)
      "ship_damage_control" + (actionItem.userHandle >> 3).tostring()
    getShortcut = @(actionItem, _hudUnitType = null)
      "ID_SHIP_DAMAGE_CONTROL_PRESET_" + (actionItem.userHandle >> 3).tostring()
    getIcon = function (actionItem, _killStreakTag = null, _unit = null, _hudUnitType = null) {
      return "#ui/gameuiskin#ship_damage_control_" + (actionItem.userHandle & 7).tostring() + ""
    }
  }

  SHIP_CURRENT_TRIGGER_GROUP = {
    code = EII_SHIP_CURRENT_TRIGGER_GROUP
    _name = "ship_current_trigger_group"
    getShortcut = @(_actionItem, _hudUnitType = null)
      ::get_option(::USEROPT_WHEEL_CONTROL_SHIP)?.value
        && (::is_xinput_device() || isPlatformSony || isPlatformXboxOne)
          ? "ID_SHIP_SELECTWEAPON_WHEEL_MENU"
          : null
    getIcon = function (actionItem, _killStreakTag = null, _unit = null, _hudUnitType = null) {
      let currentTrigger = actionItem?.userHandle ?? TRIGGER_GROUP_PRIMARY
      switch (currentTrigger) {
        case TRIGGER_GROUP_PRIMARY:
          return "!ui/gameuiskin#artillery_weapon_state_indicator.svg"
        case TRIGGER_GROUP_SECONDARY:
          return "!ui/gameuiskin#artillery_secondary_weapon_state_indicator.svg"
        case TRIGGER_GROUP_MACHINE_GUN:
          return "!ui/gameuiskin#machine_gun_weapon_state_indicator.svg"
        case TRIGGER_GROUP_EXTRA_GUN_1:
          return "!ui/gameuiskin#artillery_weapon_state_indicator.svg"
        case TRIGGER_GROUP_EXTRA_GUN_2:
          return "!ui/gameuiskin#artillery_weapon_state_indicator.svg"
        case TRIGGER_GROUP_EXTRA_GUN_3:
          return "!ui/gameuiskin#artillery_weapon_state_indicator.svg"
        case TRIGGER_GROUP_EXTRA_GUN_4:
          return "!ui/gameuiskin#artillery_weapon_state_indicator.svg"
      }
      return "!ui/gameuiskin#artillery_weapon_state_indicator.svg"
    }
  }

  FORCED_WEAPON = {
    code = EII_FORCED_GUN
    isForSelectWeaponMenu = @() null
    getTitle = function(actionItem, _killStreakTag = null) {
      let forceTrigger = actionItem?.userHandle ?? -1
      switch (forceTrigger) {
        case TRIGGER_GROUP_PRIMARY:
          return loc("hotkeys/ID_FIRE_GM")
        case TRIGGER_GROUP_SECONDARY:
          return loc("hotkeys/ID_FIRE_GM_SECONDARY_GUN")
        case TRIGGER_GROUP_MACHINE_GUN:
          return loc("hotkeys/ID_FIRE_GM_MACHINE_GUN")
      }
      return null
    }
    getShortcut = function(actionItem, hudUnitType = null) {
      let forceTrigger = actionItem?.userHandle ?? -1
      switch (forceTrigger) {
        case TRIGGER_GROUP_PRIMARY:
          return hudUnitType == HUD_UNIT_TYPE.HUMAN ? "ID_FIRE_HUMAN" : "ID_FIRE_GM"
        case TRIGGER_GROUP_SECONDARY:
          return hudUnitType == HUD_UNIT_TYPE.HUMAN ? "ID_FIRE_HUMAN_SECONDARY_GUN" : "ID_FIRE_GM_SECONDARY_GUN"
        case TRIGGER_GROUP_MACHINE_GUN:
          return hudUnitType == HUD_UNIT_TYPE.HUMAN ? "ID_FIRE_HUMAN_MACHINE_GUN" : "ID_FIRE_GM_MACHINE_GUN"
      }
      return null
    }
  }

  AI_GUNNERS_STATE = {
    code = EII_AI_GUNNERS
    _name = "ai_gunners"
    _icon = "#ui/gameuiskin#ship_gunner_state_hold_fire.svg"
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_SHIP_TOGGLE_GUNNERS"
    getIcon = function (actionItem, _killStreakTag = null, _unit = null, _hudUnitType = null) {
      switch (actionItem?.userHandle ?? AI_GUNNERS_DISABLED) {
        case AI_GUNNERS_DISABLED:
          return "#ui/gameuiskin#ship_gunner_state_hold_fire.svg"
        case AI_GUNNERS_ALL_TARGETS:
          return "#ui/gameuiskin#ship_gunner_state_fire_at_will.svg"
        case AI_GUNNERS_AIR_TARGETS:
          return "#ui/gameuiskin#ship_gunner_state_air_targets.svg"
        case AI_GUNNERS_GROUND_TARGETS:
          return "#ui/gameuiskin#ship_gunner_state_naval_targets.svg"
        case AI_GUNNERS_SHELL:
          return "#ui/gameuiskin#bomb_mark"
      }
      return this._icon
    }
  }

  AUTO_TURRET_STATE = {
    code = EII_AUTO_TURRET
    _name = "auto_turret"
    _icon = "#ui/gameuiskin#ship_gunner_state_hold_fire.svg"
    _title = loc("hotkeys/ID_TOGGLE_AUTOTURRET_TARGETS")
    isForWheelMenu = @() true
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_TOGGLE_AUTOTURRET_TARGETS"
    getIcon = function (actionItem, _killStreakTag = null, _unit = null, _hudUnitType = null) {
      switch (actionItem?.userHandle ?? AI_GUNNERS_DISABLED) {
        case AI_GUNNERS_DISABLED:
          return "#ui/gameuiskin#ship_gunner_state_hold_fire.svg"
        case AI_GUNNERS_ALL_TARGETS:
          return "#ui/gameuiskin#autogun_state_fire_at_will"
        case AI_GUNNERS_AIR_TARGETS:
          return "#ui/gameuiskin#autogun_state_air_targets"
        case AI_GUNNERS_GROUND_TARGETS:
          return "#ui/gameuiskin#ship_gunner_state_naval_targets.svg"
        case AI_GUNNERS_SHELL:
          return "#ui/gameuiskin#autogun_state_rocket_targets"
      }
      return this._icon
    }
  }

  SUPPORT_PLANE = {
    code = EII_SUPPORT_PLANE
    _name = "support_plane"
    _icon = "#ui/gameuiskin#scout_streak"
    _title = loc("hotkeys/ID_START_SUPPORT_PLANE")
    isForWheelMenu = @() true
    getShortcut = function(_actionItem, hudUnitType = null) {
      let unit = getUnit()
      let ownerUnit = getOwnerUnit()
      return ((hudUnitType == HUD_UNIT_TYPE.TANK && unit == ownerUnit)
          || (hudUnitType == HUD_UNIT_TYPE.AIRCRAFT && getOwnerUnit()?.isTank()
           && !getOwnerUnit()?.isHuman()
          ))
        ? "ID_START_SUPPORT_PLANE"
        : ((hudUnitType == HUD_UNIT_TYPE.HUMAN && unit == ownerUnit)
        || (hudUnitType == HUD_UNIT_TYPE.AIRCRAFT && getOwnerUnit()?.isHuman()))
        ? "ID_START_SUPPORT_PLANE_HUMAN"
        : "ID_START_SUPPORT_PLANE_SHIP"
    }
    getName = function(_actionItem, _killStreakTag = null) {
      let hudUnitType = getHudUnitType()
      let unit = getUnit()
      let ownerUnit = getOwnerUnit()
      return hudUnitType == HUD_UNIT_TYPE.TANK && unit == ownerUnit ? this._name
        : hudUnitType != HUD_UNIT_TYPE.AIRCRAFT && unit == ownerUnit ? "support_plane_ship"
        : ownerUnit?.isHuman() ? "switch_to_human"
        : ownerUnit?.isShipOrBoat() ? "switch_to_ship"
        : "switch_to_tank"
    }
    getIcon = function(_actionItem, _killStreakTag = null, unit = null, hudUnitType = null) {
      hudUnitType = hudUnitType ?? getHudUnitType()
      unit = unit ?? getUnit()
      let ownerUnit = getOwnerUnit()
      return hudUnitType == HUD_UNIT_TYPE.TANK && unit == ownerUnit ? "#ui/gameuiskin#scout_streak"
        : hudUnitType == HUD_UNIT_TYPE.HUMAN && unit == ownerUnit ? "#ui/gameuiskin#quadrotor_streak"
        : hudUnitType != HUD_UNIT_TYPE.AIRCRAFT && unit == ownerUnit ?  "#ui/gameuiskin#shipSupportPlane"
        : ownerUnit?.isShipOrBoat() ? "#ui/gameuiskin#supportPlane_to_ship_controls"
        : ownerUnit?.isHuman() ? "#ui/gameuiskin#supportplane_to_exoskelet"
        : "#ui/gameuiskin#supportPlane_to_tank_controls"
    }
    getTitle = function(_actionItem, _killStreakTag = null) {
      let hudUnitType = getHudUnitType()
      let unit = getUnit()
      let ownerUnit = getOwnerUnit()
      return hudUnitType == HUD_UNIT_TYPE.TANK && unit == ownerUnit ? this._title
        : hudUnitType == HUD_UNIT_TYPE.HUMAN && unit == ownerUnit ? loc("hotkeys/ID_START_SUPPORT_PLANE_HUMAN")
        : hudUnitType != HUD_UNIT_TYPE.AIRCRAFT && unit == ownerUnit ? loc("hotkeys/ID_START_SUPPORT_PLANE_SHIP")
        : ownerUnit?.isShipOrBoat() ? loc("actionBarItem/switch_to_ship")
        : ownerUnit?.isHuman() ? loc("actionBarItem/switch_to_human")
        : loc("actionBarItem/switch_to_tank")
    }
  }

  SUPPORT_PLANE_2 = {
    code = EII_SUPPORT_PLANE_2
    _name = "support_plane_2"
    _icon = "#ui/gameuiskin#scout_streak"
    _title = loc("hotkeys/ID_START_SUPPORT_PLANE_2")
    isForWheelMenu = @() true
    getShortcut = @(_actionItem, hudUnitType = null)
      hudUnitType == HUD_UNIT_TYPE.TANK ? "ID_START_SUPPORT_PLANE_2"
        : "ID_START_SUPPORT_PLANE_SHIP_2"
    getName = function(_actionItem, _killStreakTag = null) {
      let hudUnitType = getHudUnitType()
      return hudUnitType == HUD_UNIT_TYPE.TANK ? this._name
        : hudUnitType == HUD_UNIT_TYPE.AIRCRAFT ? "switch_to_ship"
        : "support_plane_ship"
    }
    getIcon = function(_actionItem, _killStreakTag = null, _unit = null, hudUnitType = null) {
      hudUnitType = hudUnitType ?? getHudUnitType()
      return hudUnitType == HUD_UNIT_TYPE.TANK ? "#ui/gameuiskin#scout_streak"
        : hudUnitType == HUD_UNIT_TYPE.AIRCRAFT ? "#ui/gameuiskin#supportPlane_to_ship_controls"
        : "#ui/gameuiskin#shipSupportPlane"
    }
    getTitle = function(_actionItem, _killStreakTag = null) {
      let hudUnitType = getHudUnitType()
      return hudUnitType == HUD_UNIT_TYPE.TANK ? this._title
        : hudUnitType == HUD_UNIT_TYPE.AIRCRAFT ? loc("actionBarItem/switch_to_ship")
        : loc("hotkeys/ID_START_SUPPORT_PLANE_SHIP_2")
    }
  }

  SUPPORT_PLANE_ORBITING = {
    code = EII_SUPPORT_PLANE_ORBITING
    _name = "support_plane_orbiting"
    getIcon = function(_actionItem, _killStreakTag = null, _unit = null, _hudUnitType = null) {
      let ownerUnit = getOwnerUnit()
      return ownerUnit.isShipOrBoat() ? "#ui/gameuiskin#ship_support_plane_orbital" :
        ownerUnit?.isHuman() ? "#ui/gameuiskin#quadrotor_hovering"
        : "#ui/gameuiskin#uav_orbiting"
    }
    _title = loc("hotkeys/ID_SUPPORT_PLANE_ORBITING")
    isForWheelMenu = @() true
    getShortcut = function(_actionItem, _hudUnitType = null) {
      let ownerUnit = getOwnerUnit()
      return ownerUnit?.isShipOrBoat() ? "ID_SUPPORT_PLANE_ORBITING_SHIP"
        : ownerUnit?.isHuman() ? "ID_SUPPORT_PLANE_ORBITING_HUMAN"
        : "ID_SUPPORT_PLANE_ORBITING"
   }
  }

  SUPPORT_PLANE_CHANGE = {
    code = EII_SUPPORT_PLANE_CHANGE
    _name = "support_plane_change"
    _icon = "#ui/gameuiskin#scout_streak"
    _title = loc("hotkeys/ID_SUPPORT_PLANE_CHANGE")
    isForWheelMenu = @() true
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_SUPPORT_PLANE_CHANGE"
  }

  SUPPORT_PLANE_GROUP_ATTACK = {
    code = EII_SUPPORT_PLANE_GROUP_ATTACK
    _name = "support_plane_change"
    _icon = "#ui/gameuiskin#artillery_fire"
    _title = loc("hotkeys/ID_SUPPORT_PLANE_GROUP_ATTACK")
    isForWheelMenu = @() true
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_SUPPORT_PLANE_GROUP_ATTACK"
  }

  NIGHT_VISION = {
    code = EII_NIGHT_VISION,
    _name = "night_vision"
    _icon = "#ui/gameuiskin#supportPlane_night_vision"
    _title = loc("hotkeys/ID_PLANE_NIGHT_VISION")
    isForWheelMenu = @() true
    getShortcut = @(_actionItem, hudUnitType = null)
      hudUnitType == HUD_UNIT_TYPE.HUMAN ? "ID_HUMAN_NIGHT_VISION"
        : hudUnitType == HUD_UNIT_TYPE.HELICOPTER ? "ID_HELI_GUNNER_NIGHT_VISION"
        : "ID_PLANE_NIGHT_VISION"
  }

  SIGHT_STABILIZATION = {
    code = EII_SIGHT_STABILIZATION,
    _name = "sight_stabilization"
    _icon = "#ui/gameuiskin#supportPlane_sight_stabilization"
    _title = loc("hotkeys/ID_LOCK_TARGETING")
    isForWheelMenu = @() true
    getShortcut = @(_actionItem, hudUnitType = null)
      hudUnitType == HUD_UNIT_TYPE.HELICOPTER
        ? "ID_LOCK_TARGETING_AT_POINT_HELICOPTER"
        : "ID_LOCK_TARGETING"
  }

  STEALTH = {
    code = EII_STEALTH
    _name = "stealth_activate"
    _icon = "#ui/gameuiskin#stealth_camo"
    _title = loc("hotkeys/ID_TOGGLE_STEALTH")
    isForWheelMenu = @() true
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_TOGGLE_STEALTH"
  }

  WEAPON_LOCK = {
    code = EII_LOCK
    _name = "weapon_lock"
    _icon = "#ui/gameuiskin#torpedo_active_sonar"
    _title = loc("hotkeys/ID_WEAPON_LOCK_TANK")
    isForWheelMenu = @() true
    getShortcut = function(_actionItem, hudUnitType = null){
      if (hudUnitType == HUD_UNIT_TYPE.HUMAN)
        return "ID_WEAPON_LOCK_HUMAN"
      return "ID_WEAPON_LOCK_TANK"
    }
  }

  WEAPON_LEAD = {
    code = EII_WEAPON_LEAD
    _name = "weapon_lead"
    _icon = "#ui/gameuiskin#torpedo_active_sonar"
    _title = loc("hotkeys/ID_WEAPON_LEAD_TANK")
    isForWheelMenu = @() true
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_WEAPON_LEAD_TANK"
    function getIcon(actionItem, _killStreakTag = null, _unit = null, _hudUnitType = null) {
      let guidanceLeadMode = actionItem?.userHandle ?? -1
      if (guidanceLeadMode == GUIDANCE_LEAD_MODE_OFF)
        return "#ui/gameuiskin#hover_mode_los"
      if (guidanceLeadMode == GUIDANCE_LEAD_MODE_ON)
        return "#ui/gameuiskin#hover_mode_lead"
      return "#ui/gameuiskin#hover_mode_auto"
    }
    function getTooltipText(actionItem = null) {
      let guidanceLeadMode = actionItem?.userHandle ?? -1
      let mode = guidanceLeadMode == GUIDANCE_LEAD_MODE_OFF ? loc("guidance_method/los")
        : guidanceLeadMode == GUIDANCE_LEAD_MODE_ON ? loc("guidance_method/lead")
        : loc("guidance_method/auto")
      return loc($"actionBarItem/{this._name}", { mode })
    }
  }

  TANK_TERRAFORM = {
    code = EII_TERRAFORM
    _name = "tank_terraform"
    _icon = "#ui/gameuiskin#dozer_blade"
    _title = loc("hotkeys/ID_GM_TERRAFORM_TOGGLE")
    isForWheelMenu = @() true
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_GM_TERRAFORM_TOGGLE"
  }

  DIVING_LOCK = {
    code = EII_DIVING_LOCK
    _name = "diving_lock"
    _title = loc("hotkeys/ID_DIVING_LOCK")
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_DIVING_LOCK"
  }

  UNMANNED_GROUND_VEHICLE = {
    code = EII_UGV
    _name = "ugv"
    _icon = "#ui/gameuiskin#ugv_streak"
    _title = loc("hotkeys/ID_START_UGV")
    isForWheelMenu = @() true
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_START_UGV"
    getName = function(_actionItem, _killStreakTag = null) {
      let ownerUnit = getOwnerUnit()
      return getUnit() == ownerUnit ? this._name
        : ownerUnit?.isShipOrBoat() ? "switch_to_ship"
        : "switch_to_tank"
    }
    getIcon = function(_actionItem, _killStreakTag = null, unit = null, _hudUnitType = null) {
      let ownerUnit = getOwnerUnit()
      unit = unit ?? getUnit()
      return unit == ownerUnit ? this._icon
        : ownerUnit?.isShipOrBoat() ? "#ui/gameuiskin#supportPlane_to_ship_controls"
        : "#ui/gameuiskin#supportPlane_to_tank_controls"
    }
    getTitle = function(_actionItem, _killStreakTag = null) {
      let ownerUnit = getOwnerUnit()
      return getUnit() == ownerUnit ? this._title
        : ownerUnit?.isShipOrBoat() ? loc("actionBarItem/switch_to_ship")
        : loc("actionBarItem/switch_to_tank")
    }
  }

  MINE_DETONATION = {
    code = EII_MINE_DETONATION
    _name = "mine_detonation"
    _title = loc("hotkeys/ID_MINE_DETONATION")
    _icon = "#ui/gameuiskin#tracked_mine_detonation"
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_MINE_DETONATION"
  }

  UNLIMITED_CONTROL = {
    code = EII_UNLIMITED_CONTROL
    _name = "unlimited_control"
    _title = loc("hotkeys/ID_UNLIMITED_CONTROL")
    _icon = "#ui/gameuiskin#change_controlled_unit"
    isForWheelMenu = @() true
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_UNLIMITED_CONTROL"
  }

  DESIGNATE_TARGET = {
    code = EII_DESIGNATE_TARGET
    _name = "designate_target"
    _title = loc("hotkeys/ID_DESIGNATE_TARGET")
    _icon = "#ui/gameuiskin#designate_target"
    isForWheelMenu = @() true
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_DESIGNATE_TARGET"
  }

  JUMP = {
    code = EII_JUMP
    _name = "jump"
    _title = loc("hotkeys/ID_HUMAN_JUMP")
    _icon = "#ui/gameuiskin#exoskelet_jump"
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_HUMAN_JUMP"
  }

  SPRINT = {
    code = EII_SPRINT
    _name = "sprint"
    _title = loc("hotkeys/ID_HUMAN_SPRINT")
    _icon = "#ui/gameuiskin#exoskelet_run"
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_HUMAN_SPRINT"
  }

  TOGGLE_VIEW  = {
    code = EII_TOGGLE_VIEW
    _name = "toggle_view"
    _title = loc("hotkeys/ID_TOGGLE_VIEW_HUMAN")
    _icon = "#ui/gameuiskin#exoskelet_sight"
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_TOGGLE_VIEW_HUMAN"
  }
})

::g_hud_action_bar_type.getTypeByCode <- function getTypeByCode(code) {
  return enums.getCachedType("code", code, this.cache.byCode, this, this.UNKNOWN)
}

::g_hud_action_bar_type.getByActionItem <- function getByActionItem(actionItem) {
  return this.getTypeByCode(actionItem.type)
}
