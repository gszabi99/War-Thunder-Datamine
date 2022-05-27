let enums = require("%sqStdLibs/helpers/enums.nut")
let time = require("%scripts/time.nut")
let actionBarInfo = require("%scripts/hud/hudActionBarInfo.nut")
let { getModificationByName } = require("%scripts/weaponry/modificationInfo.nut")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { getActionShortcutIndexByType, getActionBarUnitName, getForceWeapTriggerGroup,
  getAiGunnersState, getAutoturretState, getCurrentTriggerGroup, singleTorpedoSelected
} = ::require_native("hudActionBar")
let { EII_BULLET, EII_ARTILLERY_TARGET, EII_ANTI_AIR_TARGET, EII_EXTINGUISHER,
  EII_SPECIAL_UNIT, EII_WINCH, EII_WINCH_DETACH, EII_WINCH_ATTACH, EII_TOOLKIT,
  EII_MEDICALKIT, EII_TORPEDO, EII_TORPEDO_SIGHT, EII_HULL_AIMING, EII_DEPTH_CHARGE,
  EII_MINE, EII_MORTAR, EII_ROCKET, EII_GRENADE, EII_SMOKE_GRENADE, EII_REPAIR_BREACHES,
  EII_SMOKE_SCREEN, EII_SCOUT, EII_SUBMARINE_SONAR, EII_TORPEDO_SENSOR, EII_SPEED_BOOSTER,
  EII_SHIP_CURRENT_TRIGGER_GROUP, EII_AI_GUNNERS, EII_AUTO_TURRET, EII_SUPPORT_PLANE, EII_SUPPORT_PLANE_2,
  EII_STEALTH, EII_LOCK, EII_FORCED_GUN, WEAPON_PRIMARY, WEAPON_SECONDARY, WEAPON_MACHINEGUN,
  AI_GUNNERS_DISABLED, AI_GUNNERS_ALL_TARGETS, AI_GUNNERS_AIR_TARGETS, AI_GUNNERS_GROUND_TARGETS,
  AI_GUNNERS_SHELL, EII_TERRAFORM
} = ::require_native("hudActionBarConst")

::g_hud_action_bar_type <- {
  types = []

  cache = { byCode = {} }
}

let getActionDescByWeaponTriggerGroup = function(actionItem, triggerGroup)
{
  local res = actionBarInfo.getActionDesc(getActionBarUnitName(), triggerGroup)
  let cooldownTime = actionItem?.cooldownTime
  if (cooldownTime)
    res += ("\n" + ::loc("shop/reloadTime") + " " + time.secondsToString(cooldownTime, true, true))
  return res
}

let getUnit = @() ::getAircraftByName(getActionBarUnitName())

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

  getName        = @(killStreakTag = null) _name
  getIcon        = @(killStreakTag = null, unit = null) _icon
  getTitle       = @(killStreakTag = null) _title
  getTooltipText = function(actionItem = null)
  {
    local res = ::loc("actionBarItem/" + getName(actionItem?.killStreakUnitTag))
    let cooldownTime = ::getTblValue("cooldownTime", actionItem)
    if (cooldownTime)
      res += "\n" + ::loc("shop/reloadTime") + " " + time.secondsToString(cooldownTime, true, true)
    if (actionItem?.automatic)
      res += "\n" + ::loc("actionBar/action/automatic")
    return res
  }

  getShortcut = function(actionItem = null, unit = null)
  {
    if (!unit)
      unit = getUnit()
    let shortcutIdx = actionItem?.shortcutIdx ?? getActionShortcutIndexByType(code)
    if (shortcutIdx < 0)
      return null

    if (unit?.isSubmarine())
      return "ID_SUBMARINE_ACTION_BAR_ITEM_" + (shortcutIdx + 1)
    if (unit?.isShipOrBoat())
      return "ID_SHIP_ACTION_BAR_ITEM_" + (shortcutIdx + 1)
    //



    return "ID_ACTION_BAR_ITEM_" + (shortcutIdx + 1)
  }

  getVisualShortcut = function(actionItem = null, unit = null)
  {
    if ((!isForWheelMenu() && !isForSelectWeaponMenu()) || !::is_xinput_device())
      return getShortcut(actionItem, unit)

    if (!unit)
      unit = getUnit()
    if (unit?.isSubmarine())
      return "ID_SUBMARINE_KILLSTREAK_WHEEL_MENU"
    if (unit?.isShipOrBoat())
      return "ID_SHIP_KILLSTREAK_WHEEL_MENU"
    if (unit?.isAir())
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
    _icon = "!ui/gameuiskin#artillery_weapon_state_indicator"
    _title = ::loc("hotkeys/ID_SHIP_WEAPON_PRIMARY")
    getShortcut = @(actionItem, unit = null) "ID_SHIP_WEAPON_PRIMARY"
  }

  WEAPON_SECONDARY = {
    code = WEAPON_SECONDARY
    isForSelectWeaponMenu = @() true
    _name = "weaponSecondary"
    _icon = "!ui/gameuiskin#artillery_secondary_weapon_state_indicator"
    _title = ::loc("hotkeys/ID_SHIP_WEAPON_SECONDARY")
    getShortcut = @(actionItem, unit = null) "ID_SHIP_WEAPON_SECONDARY"
  }

  WEAPON_MACHINEGUN = {
    code = WEAPON_MACHINEGUN
    isForSelectWeaponMenu = @() true
    _name = "weaponMachineGun"
    _icon = "!ui/gameuiskin#machine_gun_weapon_state_indicator"
    _title = ::loc("hotkeys/ID_SHIP_WEAPON_MACHINEGUN")
    getShortcut = @(actionItem, unit = null) "ID_SHIP_WEAPON_MACHINEGUN"
  }

  TORPEDO_SIGHT = {
    code = EII_TORPEDO_SIGHT
    _name = "torpedo_sight"
    _icon = "#ui/gameuiskin#torpedo_sight"
    getShortcut = @(actionItem, unit = null) "ID_SHIP_TORPEDO_SIGHT"
  }

  HULL_AIMING = {
    code = EII_HULL_AIMING
    _name = "hull_aiming"
    _icon = "#ui/gameuiskin#hull_aiming_mode"
    getShortcut = @(actionItem, unit = null) "ID_ENABLE_GM_HULL_AIMING"
  }

  TORPEDO = {
    code = EII_TORPEDO
    _name = "torpedo"
    _icon = "#ui/gameuiskin#torpedo_multiple"
    getShortcut = @(actionItem, unit = null)
      unit?.isSubmarine() ? "ID_SUBMARINE_WEAPON_TORPEDOES" : "ID_SHIP_WEAPON_TORPEDOES"
    getIcon = function (killStreakTag = null, unit = null) {
      return singleTorpedoSelected() ?  "#ui/gameuiskin#torpedo" : _icon
    }
    getTooltipText = @(actionItem = null) getActionDescByWeaponTriggerGroup(actionItem, "torpedoes")
  }

  DEPTH_CHARGE = {
    code = EII_DEPTH_CHARGE
    _name = "depth_charge"
    _icon = "#ui/gameuiskin#depth_charge"
    getShortcut = @(actionItem, unit = null)
      unit?.isSubmarine() ? "ID_SUBMARINE_WEAPON_DEPTH_CHARGE" : "ID_SHIP_WEAPON_DEPTH_CHARGE"
    getTooltipText = @(actionItem = null) getActionDescByWeaponTriggerGroup(actionItem, "bombs")
  }

  MINE = {
    code = EII_MINE
    _name = "mine"
    _icon = "#ui/gameuiskin#naval_mine"
    getShortcut = @(actionItem, unit = null) "ID_SHIP_WEAPON_MINE"
    getTooltipText = @(actionItem = null) getActionDescByWeaponTriggerGroup(actionItem, "mines")
  }

  MORTAR = {
    code = EII_MORTAR
    _name = "mortar"
    _icon = "#ui/gameuiskin#ship_mortar_bomb"
    getShortcut = @(actionItem, unit = null) "ID_SHIP_WEAPON_MORTAR"
  }

  ROCKET = {
    code = EII_ROCKET
    _name = "rocket"
    _icon = "#ui/gameuiskin#rocket"
    getShortcut = function(actionItem, unit = null)
    {
      if (unit?.isSubmarine())
        return "ID_SUBMARINE_WEAPON_ROCKETS"
      if (unit?.isShipOrBoat())
        return "ID_SHIP_WEAPON_ROCKETS"
      if (unit?.isTank())
        return "ID_FIRE_GM_SPECIAL_GUN"
      return "ID_ROCKETS"
    }
    getTooltipText = @(actionItem = null) getActionDescByWeaponTriggerGroup(actionItem, "rockets")
  }

  GRENADE = {
    code = EII_GRENADE
    _name = "grenade"
    _icon = "#ui/gameuiskin#vog_ship"
    getShortcut = function(actionItem, unit = null)
    {
      if (unit?.isTank())
        return "ID_FIRE_GM_SPECIAL_GUN"
      return "ID_ROCKETS"
    }
    getTooltipText = @(actionItem = null) getActionDescByWeaponTriggerGroup(actionItem, "rockets")
  }

  SMOKE_GRENADE = {
    code = EII_SMOKE_GRENADE
    _name = "smoke_screen"
    isForWheelMenu = @() true
    _icon = "#ui/gameuiskin#smoke_screen"
    getTitle = @(killStreakTag = null)
      !getUnit()?.isShipOrBoat()
        ? ::loc("hotkeys/ID_SMOKE_SCREEN")
        : ::loc("hotkeys/ID_SHIP_SMOKE_GRENADE")
    getShortcut = @(actionItem, unit = null)
      !unit?.isShipOrBoat()
        ? "ID_SMOKE_SCREEN"
        : "ID_SHIP_SMOKE_GRENADE"
  }

  SMOKE_SCREEN = {
    code = EII_SMOKE_SCREEN
    _name = "engine_smoke_screen_system"
    isForWheelMenu = @() true
    _icon = "#ui/gameuiskin#engine_smoke_screen_system"
    _title = ::loc("hotkeys/ID_SMOKE_SCREEN_GENERATOR")
    getShortcut = function(actionItem, unit = null)
    {
      if (unit?.isSubmarine())
        return "ID_SUBMARINE_ACOUSTIC_COUNTERMEASURES"
      if (unit?.isShipOrBoat())
        return "ID_SHIP_SMOKE_SCREEN_GENERATOR"
      if (unit?.isTank())
        return "ID_SMOKE_SCREEN_GENERATOR"
      return "ID_PLANE_SMOKE_SCREEN_GENERATOR"
    }
    getIcon = function(killStreakTag = null, unit = null) {
      unit = unit || getUnit()
      return unit?.isSubmarine() ? "#ui/gameuiskin#acoustic_countermeasures" : _icon
    }
    getTitle = @(killStreakTag = null)
      getUnit()?.isSubmarine()
        ? ::loc("hotkeys/ID_SUBMARINE_ACOUSTIC_COUNTERMEASURES")
        : _title
    getName = @(killStreakTag = null)
      getUnit()?.isSubmarine()
        ? "acoustic_countermeasure"
        : _name
  }

  SCOUT = {
    code = EII_SCOUT
    _name = "scout_active"
    _icon = "#ui/gameuiskin#scouting"
    _title = ::loc("hotkeys/ID_SCOUT")
    getShortcut = @(actionItem, unit = null) "ID_SCOUT"
  }

  SONAR = {
    code = EII_SUBMARINE_SONAR
    isForWheelMenu = @() true
    _name = "sonar_active"
    _icon = "#ui/gameuiskin#sonar_indicator"
    _title = ::loc("hotkeys/ID_SUBMARINE_SWITCH_ACTIVE_SONAR")
    getShortcut = @(actionItem, unit = null) "ID_SUBMARINE_SWITCH_ACTIVE_SONAR"
  }

  TORPEDO_SENSOR = {
    code = EII_TORPEDO_SENSOR
    isForWheelMenu = @() true
    _name = "torpedo_sensor"
    _icon = "#ui/gameuiskin#torpedo_active_sonar"
    _title = ::loc("hotkeys/ID_SUBMARINE_WEAPON_TOGGLE_ACTIVE_SENSOR")
    getShortcut = @(actionItem, unit = null) "ID_SUBMARINE_WEAPON_TOGGLE_ACTIVE_SENSOR"
  }

  ARTILLERY_TARGET = {
    code = EII_ARTILLERY_TARGET
    _name = "artillery_target"
    isForWheelMenu = @() true
    _icon = "#ui/gameuiskin#artillery_fire"
    _title = ::loc("hotkeys/ID_ACTION_BAR_ITEM_5")
    needAnimOnIncrementCount = true
    getIcon = function (killStreakTag = null, unit = null)
    {
      local mis = ::get_current_mission_info_cached()
      if (mis?.customArtilleryImage != "")
        return mis?.customArtilleryImage
      return mis?.useCustomSuperArtillery ? "#ui/gameuiskin#artillery_fire_on_target" : "#ui/gameuiskin#artillery_fire"
    }
  }

  EXTINGUISHER = {
    code = EII_EXTINGUISHER
    isForWheelMenu = @() getUnit()?.isShipOrBoat()
    canSwitchAutomaticMode = @() getUnit()?.isShipOrBoat()
    _name = "extinguisher"
    _icon = "#ui/gameuiskin#extinguisher"
    _title = ::loc("hotkeys/ID_ACTION_BAR_ITEM_6")
    needAnimOnIncrementCount = true
    getIcon = function(killStreakTag = null, unit = null) {
      unit = unit || getUnit()
      return unit?.isShipOrBoat() ? "#ui/gameuiskin#manual_ship_extinguisher" : "#ui/gameuiskin#extinguisher"
    }
  }

  TOOLKIT = {
    code = EII_TOOLKIT
    isForWheelMenu = @() getUnit()?.isShipOrBoat()
    canSwitchAutomaticMode = @() getUnit()?.isShipOrBoat()
    _name = "toolkit"
    _icon = "#ui/gameuiskin#tank_tool_kit"
    _title = ::loc("hotkeys/ID_SHIP_ACTION_BAR_ITEM_11")
    getIcon = function(killStreakTag = null, unit = null) {
      unit = unit || getUnit()
      return unit?.isShipOrBoat() ? "#ui/gameuiskin#ship_tool_kit" : "#ui/gameuiskin#tank_tool_kit"
    }
  }

  MEDICALKIT = {
    code = EII_MEDICALKIT
    isForWheelMenu = @() true
    _name = "medicalkit"
    _icon = "#ui/gameuiskin#tank_medkit"
    _title = ::loc("hints/tank_medkit")
    needAnimOnIncrementCount = true

    getIcon = function (killStreakTag = null, unit = null) {
      unit = unit || getUnit()
      let mod = getModificationByName(unit, "tank_medical_kit")
      return mod?.image ?? ""
    }
  }

  ANTI_AIR_TARGET = {
    code = EII_ANTI_AIR_TARGET
    _name = "anti_air_target"
    _icon = "" //"#ui/gameuiskin#anti_air_target" //there is no such icon now
                                                  //commented for avoid crash
    _title = "" //::loc("encyclopedia/anti_air")
  }

  SPECIAL_UNIT = {
    code = EII_SPECIAL_UNIT
    _name = "special_unit"
    isForWheelMenu = @() true

    getName = function (killStreakTag = null)
    {
      if (::u.isString(killStreakTag))
        return _name + "_" + killStreakTag
      return ""
    }

    getIcon = function (killStreakTag = null, unit = null)
    {
      // killStreakTag is expected to be "bomber", "attacker" or "fighter".
      if (::u.isString(killStreakTag))
        return ::format("#ui/gameuiskin#%s_streak", killStreakTag)
      return ""
    }

    getTitle = function (killStreakTag = null)
    {
      if (killStreakTag == "bomber")
        return ::loc("hotkeys/ID_ACTION_BAR_ITEM_9")
      if (killStreakTag == "attacker")
        return ::loc("hotkeys/ID_ACTION_BAR_ITEM_8")
      if (killStreakTag == "fighter")
        return ::loc("hotkeys/ID_ACTION_BAR_ITEM_7")
      return ""
    }
  }

  SPEED_BOOSTER = {
    code = EII_SPEED_BOOSTER
    isForWheelMenu = @() true
    _name = "speed_booster"
    _title = ::loc("hotkeys/ID_EVENT_ACTION")
    getShortcut = @(actionItem, unit = null) "ID_EVENT_ACTION"

    getIcon = function (killStreakTag = null, unit = null) {
      unit = unit || getUnit()
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
    _title = ::loc("hints/winch_request")
  }

  WINCH_DETACH = {
    code = EII_WINCH_DETACH
    backgroundImage = "#ui/gameuiskin#winch_request_off"
    isForWheelMenu = @() true
    _name = "winch_detach"
    _icon = "#ui/gameuiskin#winch_request_off"
    _title = ::loc("hints/winch_detach")
  }

  WINCH_ATTACH = {
    code = EII_WINCH_ATTACH
    backgroundImage = "#ui/gameuiskin#winch_request_deploy"
    isForWheelMenu = @() true
    _name = "winch_attach"
    _icon = "#ui/gameuiskin#winch_request_deploy"
    _title = ::loc("hints/winch_use")
  }

  REPAIR_BREACHES = {
    code = EII_REPAIR_BREACHES
    isForWheelMenu = @() true
    canSwitchAutomaticMode = @() true
    _name = "repair_breaches"
    _icon = "#ui/gameuiskin#unwatering"
    _title = ::loc("hotkeys/ID_REPAIR_BREACHES")
    getShortcut = @(actionItem, unit = null)
      unit?.isSubmarine() ? "ID_SUBMARINE_REPAIR_BREACHES" : "ID_REPAIR_BREACHES"
  }

  SHIP_CURRENT_TRIGGER_GROUP = {
    code = EII_SHIP_CURRENT_TRIGGER_GROUP
    _name = "ship_current_trigger_group"
    getShortcut = @(actionItem, unit = null)
      ::get_option(::USEROPT_WHEEL_CONTROL_SHIP)?.value
        && (::is_xinput_device() || isPlatformSony || isPlatformXboxOne)
          ? "ID_SHIP_SELECTWEAPON_WHEEL_MENU"
          : null
    getIcon = function (killStreakTag = null, unit = null) {
      let currentTrigger = getCurrentTriggerGroup()
      switch (currentTrigger)
      {
        case TRIGGER_GROUP_PRIMARY:
          return "!ui/gameuiskin#artillery_weapon_state_indicator"
        case TRIGGER_GROUP_SECONDARY:
          return "!ui/gameuiskin#artillery_secondary_weapon_state_indicator"
        case TRIGGER_GROUP_MACHINE_GUN:
          return "!ui/gameuiskin#machine_gun_weapon_state_indicator"
        case TRIGGER_GROUP_EXTRA_GUN_1:
          return "!ui/gameuiskin#artillery_weapon_state_indicator"
        case TRIGGER_GROUP_EXTRA_GUN_2:
          return "!ui/gameuiskin#artillery_weapon_state_indicator"
        case TRIGGER_GROUP_EXTRA_GUN_3:
          return "!ui/gameuiskin#artillery_weapon_state_indicator"
        case TRIGGER_GROUP_EXTRA_GUN_4:
          return "!ui/gameuiskin#artillery_weapon_state_indicator"
      }
      return "!ui/gameuiskin#artillery_weapon_state_indicator"
    }
  }

  FORCED_WEAPON = {
    code = EII_FORCED_GUN
    isForSelectWeaponMenu = @()
    getTitle = function(killStreakTag = null) {
      let forceTrigger = getForceWeapTriggerGroup()
      switch (forceTrigger)
      {
        case TRIGGER_GROUP_PRIMARY:
          return ::loc("hotkeys/ID_FIRE_GM")
        case TRIGGER_GROUP_SECONDARY:
          return ::loc("hotkeys/ID_FIRE_GM_SECONDARY_GUN")
        case TRIGGER_GROUP_MACHINE_GUN:
          return ::loc("hotkeys/ID_FIRE_GM_MACHINE_GUN")
      }
      return null
    }
    getShortcut = function(actionItem, unit = null) {
      local forceTrigger = getForceWeapTriggerGroup()
      switch (forceTrigger)
      {
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
    _icon = "#ui/gameuiskin#ship_gunner_state_hold_fire"
    getShortcut = @(actionItem, unit = null) "ID_SHIP_TOGGLE_GUNNERS"
    getIcon = function (killStreakTag = null, unit = null) {
      switch (getAiGunnersState())
      {
        case AI_GUNNERS_DISABLED:
          return "#ui/gameuiskin#ship_gunner_state_hold_fire"
        case AI_GUNNERS_ALL_TARGETS:
          return "#ui/gameuiskin#ship_gunner_state_fire_at_will"
        case AI_GUNNERS_AIR_TARGETS:
          return "#ui/gameuiskin#ship_gunner_state_air_targets"
        case AI_GUNNERS_GROUND_TARGETS:
          return "#ui/gameuiskin#ship_gunner_state_naval_targets"
        case AI_GUNNERS_SHELL:
          return "#ui/gameuiskin#bomb_mark"
      }
      return _icon
    }
  }

  AUTO_TURRET_STATE = {
    code = EII_AUTO_TURRET
    _name = "auto_turret"
    _icon = "#ui/gameuiskin#ship_gunner_state_hold_fire"
    _title = ::loc("hotkeys/ID_TOGGLE_AUTOTURRET_TARGETS")
    isForWheelMenu = @() true
    getShortcut = @(actionItem, unit = null) "ID_TOGGLE_AUTOTURRET_TARGETS"
    getIcon = function (killStreakTag = null, unit = null) {
      switch (getAutoturretState())
      {
        case AI_GUNNERS_DISABLED:
          return "#ui/gameuiskin#ship_gunner_state_hold_fire"
        case AI_GUNNERS_ALL_TARGETS:
          return "#ui/gameuiskin#autogun_state_fire_at_will"
        case AI_GUNNERS_AIR_TARGETS:
          return "#ui/gameuiskin#autogun_state_air_targets"
        case AI_GUNNERS_GROUND_TARGETS:
          return "#ui/gameuiskin#ship_gunner_state_naval_targets"
        case AI_GUNNERS_SHELL:
          return "#ui/gameuiskin#autogun_state_rocket_targets"
      }
      return _icon
    }
  }

  SUPPORT_PLANE = {
    code = EII_SUPPORT_PLANE
    _name = "support_plane"
    _icon = "#ui/gameuiskin#scout_streak"
    _title = ::loc("hotkeys/ID_START_SUPPORT_PLANE")
    isForWheelMenu = @() true
    getShortcut = @(actionItem, unit = null)
      unit?.isTank() ? "ID_START_SUPPORT_PLANE" : "ID_START_SUPPORT_PLANE_SHIP"
    getName = @(killStreakTag = null)
      getUnit()?.isTank() ? _name
        : getUnit()?.isAir() ? "switch_to_ship"
        : "support_plane_ship"
    getIcon = function(killStreakTag = null, unit = null) {
      unit = unit || getUnit()
      return unit?.isTank() ? "#ui/gameuiskin#scout_streak"
        : unit?.isAir() ? "#ui/gameuiskin#supportPlane_to_ship_controls"
        : "#ui/gameuiskin#shipSupportPlane"
    }
    getTitle = function(killStreakTag = null) {
      let unit = getUnit()
      return unit?.isTank() ? _title
        : unit?.isAir() ? ::loc("actionBarItem/switch_to_ship")
        : ::loc("hotkeys/ID_START_SUPPORT_PLANE_SHIP")
    }
  }

  SUPPORT_PLANE_2 = {
    code = EII_SUPPORT_PLANE_2
    _name = "support_plane_2"
    _icon = "#ui/gameuiskin#scout_streak"
    _title = ::loc("hotkeys/ID_START_SUPPORT_PLANE_2")
    isForWheelMenu = @() true
    getShortcut = @(actionItem, unit = null)
      unit?.isTank() ? "ID_START_SUPPORT_PLANE_2" : "ID_START_SUPPORT_PLANE_SHIP_2"
    getName = @(killStreakTag = null)
      getUnit()?.isTank() ? _name
        : getUnit()?.isAir() ? "switch_to_ship"
        : "support_plane_ship"
    getIcon = function(killStreakTag = null, unit = null) {
      unit = unit || getUnit()
      return unit?.isTank() ? "#ui/gameuiskin#scout_streak"
        : unit?.isAir() ? "#ui/gameuiskin#supportPlane_to_ship_controls"
        : "#ui/gameuiskin#shipSupportPlane"
    }
    getTitle = function(killStreakTag = null) {
      local unit = getUnit()
      return unit?.isTank() ? _title
        : unit?.isAir() ? ::loc("actionBarItem/switch_to_ship")
        : ::loc("hotkeys/ID_START_SUPPORT_PLANE_SHIP_2")
    }
  }

  STEALTH = {
    code = EII_STEALTH
    _name = "stealth_activate"
    _icon = "#ui/gameuiskin#stealth_camo"
    _title = ::loc("hotkeys/ID_TOGGLE_STEALTH")
    isForWheelMenu = @() true
    getShortcut = @(actionItem, unit = null) "ID_TOGGLE_STEALTH"
  }

  WEAPON_LOCK = {
    code = EII_LOCK
    _name = "weapon_lock"
    _icon = "#ui/gameuiskin#torpedo_active_sonar"
    _title = ::loc("hotkeys/ID_WEAPON_LOCK_TANK")
    isForWheelMenu = @() true
    getShortcut = @(actionItem, unit = null) "ID_WEAPON_LOCK_TANK"
  }

  TANK_TERRAFORM = {
    code = EII_TERRAFORM
    _name = "tank_terraform"
    _icon = "#ui/gameuiskin#dozer_blade"
    _title = ::loc("hotkeys/ID_GM_TERRAFORM_TOGGLE")
    isForWheelMenu = @() true
    getShortcut = @(actionItem, unit = null) "ID_GM_TERRAFORM_TOGGLE"
  }
})

g_hud_action_bar_type.getTypeByCode <- function getTypeByCode(code)
{
  return enums.getCachedType("code", code, cache.byCode, this, UNKNOWN)
}

g_hud_action_bar_type.getByActionItem <- function getByActionItem(actionItem)
{
  return getTypeByCode(actionItem.type)
}
