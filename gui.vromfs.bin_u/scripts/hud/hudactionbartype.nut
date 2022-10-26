from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let enums = require("%sqStdLibs/helpers/enums.nut")
let time = require("%scripts/time.nut")
let actionBarInfo = require("%scripts/hud/hudActionBarInfo.nut")
let { getModificationByName } = require("%scripts/weaponry/modificationInfo.nut")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { getActionShortcutIndexByType, getActionBarUnitName, getOwnerUnitName, getForceWeapTriggerGroup,
  getAiGunnersState, getAutoturretState, getCurrentTriggerGroup, singleTorpedoSelected, getGuidanceLeadMode
} = require_native("hudActionBar")
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
  GUIDANCE_LEAD_MODE_OFF, GUIDANCE_LEAD_MODE_ON
  //


} = require_native("hudActionBarConst")
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
  canSwitchAutomaticMode =@() false

  _name = ""
  _icon = ""
  _title = ""
  needAnimOnIncrementCount = false

  getName        = @(_actionItem, _killStreakTag = null) this._name
  getIcon        = @(_actionItem, _killStreakTag = null, _unit = null, _hudUnitType = null) this._icon
  getTitle       = @(_actionItem, _killStreakTag = null) this._title
  getTooltipText = function(actionItem = null) {
    local res = loc("actionBarItem/" + this.getName(actionItem, actionItem?.killStreakUnitTag))
    let cooldownTime = getTblValue("cooldownTime", actionItem)
    if (cooldownTime)
      res += "\n" + loc("shop/reloadTime") + " " + time.secondsToString(cooldownTime, true, true)
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
    _icon = "#ui/gameuiskin#torpedo_sight.png"
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_SHIP_TORPEDO_SIGHT"
  }

  HULL_AIMING = {
    code = EII_HULL_AIMING
    _name = "hull_aiming"
    _icon = "#ui/gameuiskin#hull_aiming_mode.png"
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_ENABLE_GM_HULL_AIMING"
  }

  TORPEDO = {
    code = EII_TORPEDO
    _name = "torpedo"
    _icon = "#ui/gameuiskin#torpedo_multiple.png"
    getShortcut = @(_actionItem, hudUnitType = null)
      hudUnitType == HUD_UNIT_TYPE.SHIP_EX ? "ID_SUBMARINE_WEAPON_TORPEDOES"
        : "ID_SHIP_WEAPON_TORPEDOES"
    getIcon = function (_actionItem, _killStreakTag = null, _unit = null, _hudUnitType = null) {
      return singleTorpedoSelected() ?  "#ui/gameuiskin#torpedo.png" : this._icon
    }
    getTooltipText = @(actionItem = null) getActionDescByWeaponTriggerGroup(actionItem, "torpedoes")
  }

  DEPTH_CHARGE = {
    code = EII_DEPTH_CHARGE
    _name = "depth_charge"
    _icon = "#ui/gameuiskin#depth_charge.png"
    getShortcut = @(_actionItem, hudUnitType = null)
      hudUnitType == HUD_UNIT_TYPE.SHIP_EX ? "ID_SUBMARINE_WEAPON_DEPTH_CHARGE"
        : "ID_SHIP_WEAPON_DEPTH_CHARGE"
    getTooltipText = @(actionItem = null) getActionDescByWeaponTriggerGroup(actionItem, "bombs")
  }

  MINE = {
    code = EII_MINE
    _name = "mine"
    _icon = "#ui/gameuiskin#naval_mine.png"
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_SHIP_WEAPON_MINE"
    getTooltipText = @(actionItem = null) getActionDescByWeaponTriggerGroup(actionItem, "mines")
  }

  MORTAR = {
    code = EII_MORTAR
    _name = "mortar"
    _icon = "#ui/gameuiskin#ship_mortar_bomb.png"
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_SHIP_WEAPON_MORTAR"
  }

  ROCKET = {
    code = EII_ROCKET
    _name = "rocket"
    _icon = "#ui/gameuiskin#rocket.png"
    getShortcut = function(_actionItem, hudUnitType = null) {
      if (hudUnitType == HUD_UNIT_TYPE.SHIP_EX)
        return "ID_SUBMARINE_WEAPON_ROCKETS"
      if (hudUnitType == HUD_UNIT_TYPE.SHIP)
        return "ID_SHIP_WEAPON_ROCKETS"
      if (hudUnitType == HUD_UNIT_TYPE.TANK)
        return "ID_FIRE_GM_SPECIAL_GUN"
      return "ID_ROCKETS"
    }
    getTooltipText = @(actionItem = null) getActionDescByWeaponTriggerGroup(actionItem, "rockets")
  }

  GRENADE = {
    code = EII_GRENADE
    _name = "grenade"
    _icon = "#ui/gameuiskin#vog_ship.png"
    getShortcut = @(_actionItem, hudUnitType = null) hudUnitType == HUD_UNIT_TYPE.TANK
      ? "ID_FIRE_GM_SPECIAL_GUN"
      : "ID_ROCKETS"
    getTooltipText = @(actionItem = null) getActionDescByWeaponTriggerGroup(actionItem, "rockets")
  }

  SMOKE_GRENADE = {
    code = EII_SMOKE_GRENADE
    _name = "smoke_screen"
    isForWheelMenu = @() true
    _icon = "#ui/gameuiskin#smoke_screen.png"
    getTitle = @(_actionItem, _killStreakTag = null) getHudUnitType() == HUD_UNIT_TYPE.SHIP
      ? loc("hotkeys/ID_SHIP_SMOKE_GRENADE")
      : loc("hotkeys/ID_SMOKE_SCREEN")
    getShortcut = @(_actionItem, hudUnitType = null)
      hudUnitType == HUD_UNIT_TYPE.SHIP ? "ID_SHIP_SMOKE_GRENADE" : "ID_SMOKE_SCREEN"
  }

  SMOKE_SCREEN = {
    code = EII_SMOKE_SCREEN
    _name = "engine_smoke_screen_system"
    isForWheelMenu = @() true
    _icon = "#ui/gameuiskin#engine_smoke_screen_system.png"
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
        ? "#ui/gameuiskin#acoustic_countermeasures.png"
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
    _icon = "#ui/gameuiskin#scouting.png"
    _title = loc("hotkeys/ID_SCOUT")
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_SCOUT"
  }

  SONAR = {
    code = EII_SUBMARINE_SONAR
    isForWheelMenu = @() true
    _name = "sonar_active"
    _icon = "#ui/gameuiskin#sonar_indicator.png"
    _title = loc("hotkeys/ID_SUBMARINE_SWITCH_ACTIVE_SONAR")
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_SUBMARINE_SWITCH_ACTIVE_SONAR"
  }

  TORPEDO_SENSOR = {
    code = EII_TORPEDO_SENSOR
    isForWheelMenu = @() true
    _name = "torpedo_sensor"
    _icon = "#ui/gameuiskin#torpedo_active_sonar.png"
    _title = loc("hotkeys/ID_SUBMARINE_WEAPON_TOGGLE_ACTIVE_SENSOR")
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_SUBMARINE_WEAPON_TOGGLE_ACTIVE_SENSOR"
  }

  ARTILLERY_TARGET = {
    code = EII_ARTILLERY_TARGET
    _name = "artillery_target"
    isForWheelMenu = @() true
    _icon = "#ui/gameuiskin#artillery_fire.png"
    _title = loc("hotkeys/ID_ACTION_BAR_ITEM_5")
    needAnimOnIncrementCount = true
    getIcon = function (_actionItem, _killStreakTag = null, _unit = null, _hudUnitType = null) {
      local mis = ::get_current_mission_info_cached()
      if ((mis?.customArtilleryImage ?? "") != "")
        return mis.customArtilleryImage
      return mis?.useCustomSuperArtillery ? "#ui/gameuiskin#artillery_fire_on_target.png" : this._icon
    }
  }

  EXTINGUISHER = {
    code = EII_EXTINGUISHER
    isForWheelMenu = @() getHudUnitType() == HUD_UNIT_TYPE.SHIP
    canSwitchAutomaticMode = @() getHudUnitType() == HUD_UNIT_TYPE.SHIP
    _name = "extinguisher"
    _icon = "#ui/gameuiskin#extinguisher.png"
    _title = loc("hotkeys/ID_ACTION_BAR_ITEM_6")
    needAnimOnIncrementCount = true
    getIcon = function(_actionItem, _killStreakTag = null, _unit = null, hudUnitType = null) {
      hudUnitType = hudUnitType ?? getHudUnitType()
      return hudUnitType == HUD_UNIT_TYPE.SHIP
        ? "#ui/gameuiskin#manual_ship_extinguisher.png"
        : "#ui/gameuiskin#extinguisher.png"
    }
  }

  TOOLKIT = {
    code = EII_TOOLKIT
    isForWheelMenu = @() getHudUnitType() == HUD_UNIT_TYPE.SHIP
    canSwitchAutomaticMode = @() getHudUnitType() == HUD_UNIT_TYPE.SHIP
    _name = "toolkit"
    _icon = "#ui/gameuiskin#tank_tool_kit.png"
    _title = loc("hotkeys/ID_SHIP_ACTION_BAR_ITEM_11")
    getIcon = function(_actionItem, _killStreakTag = null, _unit = null, hudUnitType = null) {
      hudUnitType = hudUnitType ?? getHudUnitType()
      return hudUnitType == HUD_UNIT_TYPE.SHIP
        ? "#ui/gameuiskin#ship_tool_kit.png"
        : "#ui/gameuiskin#tank_tool_kit.png"
    }
  }

  MEDICALKIT = {
    code = EII_MEDICALKIT
    isForWheelMenu = @() true
    _name = "medicalkit"
    _icon = "#ui/gameuiskin#tank_medkit.png"
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
    _icon = "" //"#ui/gameuiskin#anti_air_target.png" //there is no such icon now
                                                  //commented for avoid crash
    _title = "" //loc("encyclopedia/anti_air")
  }

  SPECIAL_UNIT = {
    code = EII_SPECIAL_UNIT
    _name = "special_unit"
    isForWheelMenu = @() true

    getName = function (_actionItem, killStreakTag = null){
      if (::u.isString(killStreakTag))
        return this._name + "_" + killStreakTag
      return ""
    }

    getIcon = function (_actionItem, killStreakTag = null, _unit = null, _hudUnitType = null) {
      // killStreakTag is expected to be "bomber", "attacker" or "fighter".
      if (::u.isString(killStreakTag))
        return $"#ui/gameuiskin#{killStreakTag}_streak.png"
      return ""
    }

    getTitle = function (_actionItem, killStreakTag = null)
    {
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
    backgroundImage = "#ui/gameuiskin#winch_request.png"
    isForWheelMenu = @() true
    _name = "winch"
    _icon = "#ui/gameuiskin#winch_request.png"
    _title = loc("hints/winch_request")
  }

  WINCH_DETACH = {
    code = EII_WINCH_DETACH
    backgroundImage = "#ui/gameuiskin#winch_request_off.png"
    isForWheelMenu = @() true
    _name = "winch_detach"
    _icon = "#ui/gameuiskin#winch_request_off.png"
    _title = loc("hints/winch_detach")
  }

  WINCH_ATTACH = {
    code = EII_WINCH_ATTACH
    backgroundImage = "#ui/gameuiskin#winch_request_deploy.png"
    isForWheelMenu = @() true
    _name = "winch_attach"
    _icon = "#ui/gameuiskin#winch_request_deploy.png"
    _title = loc("hints/winch_use")
  }

  REPAIR_BREACHES = {
    code = EII_REPAIR_BREACHES
    isForWheelMenu = @() true
    canSwitchAutomaticMode = @() true
    _name = "repair_breaches"
    _icon = "#ui/gameuiskin#unwatering.png"
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
      return "#ui/gameuiskin#ship_damage_control_" + (actionItem.userHandle & 7).tostring() + ".png"
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
    getIcon = function (_actionItem, _killStreakTag = null, _unit = null, _hudUnitType = null) {
      let currentTrigger = getCurrentTriggerGroup()
      switch (currentTrigger)
      {
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
    getTitle = function(_actionItem, _killStreakTag = null) {
      let forceTrigger = getForceWeapTriggerGroup()
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
    getShortcut = function(_actionItem, _hudUnitType = null) {
      local forceTrigger = getForceWeapTriggerGroup()
      switch (forceTrigger) {
        case TRIGGER_GROUP_PRIMARY:
          return "ID_FIRE_GM"
        case TRIGGER_GROUP_SECONDARY:
          return "ID_FIRE_GM_SECONDARY_GUN"
        case TRIGGER_GROUP_MACHINE_GUN:
          return "ID_FIRE_GM_MACHINE_GUN"
      }
      return null
    }
  }

  AI_GUNNERS_STATE = {
    code = EII_AI_GUNNERS
    _name = "ai_gunners"
    _icon = "#ui/gameuiskin#ship_gunner_state_hold_fire.svg"
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_SHIP_TOGGLE_GUNNERS"
    getIcon = function (_actionItem, _killStreakTag = null, _unit = null, _hudUnitType = null) {
      switch (getAiGunnersState()) {
        case AI_GUNNERS_DISABLED:
          return "#ui/gameuiskin#ship_gunner_state_hold_fire.svg"
        case AI_GUNNERS_ALL_TARGETS:
          return "#ui/gameuiskin#ship_gunner_state_fire_at_will.svg"
        case AI_GUNNERS_AIR_TARGETS:
          return "#ui/gameuiskin#ship_gunner_state_air_targets.svg"
        case AI_GUNNERS_GROUND_TARGETS:
          return "#ui/gameuiskin#ship_gunner_state_naval_targets.svg"
        case AI_GUNNERS_SHELL:
          return "#ui/gameuiskin#bomb_mark.png"
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
    getIcon = function (_actionItem, _killStreakTag = null, _unit = null, _hudUnitType = null) {
      switch (getAutoturretState())
      {
        case AI_GUNNERS_DISABLED:
          return "#ui/gameuiskin#ship_gunner_state_hold_fire.svg"
        case AI_GUNNERS_ALL_TARGETS:
          return "#ui/gameuiskin#autogun_state_fire_at_will.png"
        case AI_GUNNERS_AIR_TARGETS:
          return "#ui/gameuiskin#autogun_state_air_targets.png"
        case AI_GUNNERS_GROUND_TARGETS:
          return "#ui/gameuiskin#ship_gunner_state_naval_targets.svg"
        case AI_GUNNERS_SHELL:
          return "#ui/gameuiskin#autogun_state_rocket_targets.png"
      }
      return this._icon
    }
  }

  SUPPORT_PLANE = {
    code = EII_SUPPORT_PLANE
    _name = "support_plane"
    _icon = "#ui/gameuiskin#scout_streak.png"
    _title = loc("hotkeys/ID_START_SUPPORT_PLANE")
    isForWheelMenu = @() true
    getShortcut = @(_actionItem, hudUnitType = null)
      (hudUnitType == HUD_UNIT_TYPE.TANK
          || (hudUnitType == HUD_UNIT_TYPE.AIRCRAFT && getOwnerUnit()?.isTank()))
        ? "ID_START_SUPPORT_PLANE"
        : "ID_START_SUPPORT_PLANE_SHIP"
    getName = function(_actionItem, _killStreakTag = null) {
      let hudUnitType = getHudUnitType()
      return hudUnitType == HUD_UNIT_TYPE.TANK ? this._name
        : hudUnitType != HUD_UNIT_TYPE.AIRCRAFT ? "support_plane_ship"
        : getOwnerUnit()?.isShipOrBoat() ? "switch_to_ship"
        : "switch_to_tank"
    }
    getIcon = function(_actionItem, _killStreakTag = null, _unit = null, hudUnitType = null) {
      hudUnitType = hudUnitType ?? getHudUnitType()
      return hudUnitType == HUD_UNIT_TYPE.TANK ? "#ui/gameuiskin#scout_streak.png"
        : hudUnitType != HUD_UNIT_TYPE.AIRCRAFT ?  "#ui/gameuiskin#shipSupportPlane.png"
        : getOwnerUnit()?.isShipOrBoat() ? "#ui/gameuiskin#supportPlane_to_ship_controls.png"
        : "#ui/gameuiskin#supportPlane_to_tank_controls.png"
    }
    getTitle = function(_actionItem, _killStreakTag = null) {
      let hudUnitType = getHudUnitType()
      return hudUnitType == HUD_UNIT_TYPE.TANK ? this._title
        : hudUnitType != HUD_UNIT_TYPE.AIRCRAFT ? loc("hotkeys/ID_START_SUPPORT_PLANE_SHIP")
        : getOwnerUnit()?.isShipOrBoat() ? loc("actionBarItem/switch_to_ship")
        : loc("actionBarItem/switch_to_tank")
    }
  }

  SUPPORT_PLANE_2 = {
    code = EII_SUPPORT_PLANE_2
    _name = "support_plane_2"
    _icon = "#ui/gameuiskin#scout_streak.png"
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
      return hudUnitType == HUD_UNIT_TYPE.TANK ? "#ui/gameuiskin#scout_streak.png"
        : hudUnitType == HUD_UNIT_TYPE.AIRCRAFT ? "#ui/gameuiskin#supportPlane_to_ship_controls.png"
        : "#ui/gameuiskin#shipSupportPlane.png"
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
    _icon = "#ui/gameuiskin#uav_orbiting.png"
    _title = loc("hotkeys/ID_SUPPORT_PLANE_ORBITING")
    isForWheelMenu = @() true
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_SUPPORT_PLANE_ORBITING"
  }

  SUPPORT_PLANE_CHANGE = {
    code = EII_SUPPORT_PLANE_CHANGE
    _name = "support_plane_change"
    _icon = "#ui/gameuiskin#scout_streak.png"
    _title = loc("hotkeys/ID_SUPPORT_PLANE_CHANGE")
    isForWheelMenu = @() true
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_SUPPORT_PLANE_CHANGE"
  }

  SUPPORT_PLANE_GROUP_ATTACK = {
    code = EII_SUPPORT_PLANE_GROUP_ATTACK
    _name = "support_plane_change"
    _icon = "#ui/gameuiskin#artillery_fire.png"
    _title = loc("hotkeys/ID_SUPPORT_PLANE_GROUP_ATTACK")
    isForWheelMenu = @() true
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_SUPPORT_PLANE_GROUP_ATTACK"
  }

  NIGHT_VISION = {
    code = EII_NIGHT_VISION,
    _name = "night_vision"
    _icon = "#ui/gameuiskin#supportPlane_night_vision.png"
    _title = loc("hotkeys/ID_PLANE_NIGHT_VISION")
    isForWheelMenu = @() true
    getShortcut = @(_actionItem, hudUnitType = null)
      hudUnitType == HUD_UNIT_TYPE.HELICOPTER
        ? "ID_HELI_GUNNER_NIGHT_VISION"
        : "ID_PLANE_NIGHT_VISION"
  }

  SIGHT_STABILIZATION = {
    code = EII_SIGHT_STABILIZATION,
    _name = "sight_stabilization"
    _icon = "#ui/gameuiskin#supportPlane_sight_stabilization.png"
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
    _icon = "#ui/gameuiskin#stealth_camo.png"
    _title = loc("hotkeys/ID_TOGGLE_STEALTH")
    isForWheelMenu = @() true
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_TOGGLE_STEALTH"
  }

  WEAPON_LOCK = {
    code = EII_LOCK
    _name = "weapon_lock"
    _icon = "#ui/gameuiskin#torpedo_active_sonar.png"
    _title = loc("hotkeys/ID_WEAPON_LOCK_TANK")
    isForWheelMenu = @() true
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_WEAPON_LOCK_TANK"
  }

  WEAPON_LEAD = {
    code = EII_WEAPON_LEAD
    _name = "weapon_lead"
    _icon = "#ui/gameuiskin#torpedo_active_sonar.png"
    _title = loc("hotkeys/ID_WEAPON_LEAD_TANK")
    isForWheelMenu = @() true
    getShortcut = @(_actionItem, _hudUnitType = null) "ID_WEAPON_LEAD_TANK"
    function getIcon(_actionItem, _killStreakTag = null, _unit = null, _hudUnitType = null) {
      local guidanceLeadMode = getGuidanceLeadMode()
      if (guidanceLeadMode == GUIDANCE_LEAD_MODE_OFF)
        return "#ui/gameuiskin#hover_mode_los.png"
      else if (guidanceLeadMode == GUIDANCE_LEAD_MODE_ON)
        return "#ui/gameuiskin#hover_mode_lead.png"
      else
        return "#ui/gameuiskin#hover_mode_auto.png"
    }
  }

  TANK_TERRAFORM = {
    code = EII_TERRAFORM
    _name = "tank_terraform"
    _icon = "#ui/gameuiskin#dozer_blade.png"
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

  //


















})

::g_hud_action_bar_type.getTypeByCode <- function getTypeByCode(code) {
  return enums.getCachedType("code", code, this.cache.byCode, this, this.UNKNOWN)
}

::g_hud_action_bar_type.getByActionItem <- function getByActionItem(actionItem) {
  return this.getTypeByCode(actionItem.type)
}
