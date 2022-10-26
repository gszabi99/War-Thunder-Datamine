global const WW_SKIP_BATTLE_WARNINGS_SAVE_ID = "worldWar/skipBattleWarnings"

global enum WW_ARMY_ACTION_STATUS {
  IDLE = 0
  IN_MOVE = 1
  ENTRENCHED = 2
  IN_BATTLE = 3

  UNKNOWN = 100
}

global enum WW_ARMY_RELATION_ID {
  CLAN,
  ALLY
}

global enum WW_GLOBAL_STATUS_TYPE {
 //bit enum
  QUEUE              = 0x0001
  ACTIVE_OPERATIONS  = 0x0002
  MAPS               = 0x0004
  OPERATIONS_GROUPS  = 0x0008

  //masks
  ALL                = 0x000F
}

global enum WW_BATTLE_ACCESS {
  NONE     = 0
  OBSERVER = 0x0001
  MANAGER  = 0x0002

  SUPREME  = 0xFFFF
}

global enum WW_UNIT_CLASS {
  FIGHTER    = 0x0001
  BOMBER     = 0x0002
  ASSAULT    = 0x0004
  HELICOPTER = 0x0008
  UNKNOWN    = 0x0010

  NONE     = 0x0000
  COMBINED = 0x0003
}

global enum WW_BATTLE_UNITS_REQUIREMENTS {
  NO_REQUIREMENTS   = "allow"
  BATTLE_UNITS      = "battle"
  OPERATION_UNITS   = "global"
  NO_MATCHING_UNITS = "deny"
}

global enum WW_BATTLE_CANT_JOIN_REASON {
  CAN_JOIN
  NO_WW_ACCESS
  NOT_ACTIVE
  UNKNOWN_SIDE
  WRONG_SIDE
  EXCESS_PLAYERS
  NO_TEAM
  NO_COUNTRY_IN_TEAM
  NO_COUNTRY_BY_SIDE
  NO_TEAM_NAME_BY_SIDE
  NO_AVAILABLE_UNITS
  TEAM_FULL
  QUEUE_FULL
  UNITS_NOT_ENOUGH_AVAILABLE
  SQUAD_NOT_LEADER
  SQUAD_WRONG_SIDE
  SQUAD_TEAM_FULL
  SQUAD_QUEUE_FULL
  SQUAD_NOT_ALL_READY
  SQUAD_MEMBER_ERROR
  SQUAD_UNITS_NOT_ENOUGH_AVAILABLE
  SQUAD_HAVE_UNACCEPTED_INVITES
  SQUAD_NOT_ALL_CREWS_READY
  SQUAD_MEMBERS_NO_WW_ACCESS
}

global enum mapObjectSelect {
  NONE,
  ARMY,
  REINFORCEMENT,
  AIRFIELD,
  BATTLE,
  LOG_ARMY
}

global enum WW_ARMY_GROUP_ICON_SIZE {
  BASE   = "base",
  SMALL  = "small",
  MEDIUM = "medium"
}

global enum WW_MAP_HIGHLIGHT {
  LAYER_0,
  LAYER_1,
  LAYER_2,
  LAYER_3
}

global enum WW_UNIT_SORT_CODE {
  AIR,
  HELICOPTER,
  GROUND,
  WATER,
  ARTILLERY,
  INFANTRY,
  TRANSPORT,
  UNKNOWN
}

global enum WW_LOG_CATEGORIES {
  SYSTEM
  EXISTING_BATTLES
  FINISHED_BATTLES
  ARMY_ACTIVITY
  ZONE_CAPTURE
}

global enum WW_LOG_ICONS {
  SYSTEM = "icon_type_log_systems.png"
  EXISTING_BATTLES = "icon_type_log_battles.png"
  FINISHED_BATTLES = "icon_type_log_battles.png"
  ARMY_ACTIVITY = "icon_type_log_army.png"
  ZONE_CAPTURE = "icon_type_log_sectors.png"
}

global enum WW_LOG_COLORS {
  NEUTRAL_EVENT = "@commonTextColor"
  GOOD_EVENT = "@wwTeamAllyColor"
  BAD_EVENT = "@wwTeamEnemyColor"
  SYSTEM = "@operationLogSystemMessage"
  EXISTING_BATTLES = "@operationLogBattleInProgress"
  FINISHED_BATTLES = "@operationLogBattleCompleted"
  ARMY_ACTIVITY = "@operationLogArmyInfo"
  ZONE_CAPTURE = "@operationLogBattleCompleted"
}

global enum WW_LOG_TYPES {
  UNKNOWN = "UNKNOWN"
  OPERATION_CREATED = "operation_created"
  OPERATION_STARTED = "operation_started"
  OBJECTIVE_COMPLETED = "objective_completed"
  OPERATION_FINISHED = "operation_finished"
  BATTLE_STARTED = "battle_started"
  BATTLE_FINISHED = "battle_finished"
  BATTLE_JOIN = "battle_join"
  ZONE_CAPTURED = "zone_captured"
  ARMY_RETREAT = "army_retreat"
  ARMY_DIED = "army_died"
  ARMY_FLYOUT = "army_flyout"
  ARMY_LAND_ON_AIRFIELD = "army_landOnAirfield"
  ARTILLERY_STRIKE_DAMAGE = "artillery_strike_damage"
  REINFORCEMENT = "reinforcement"
}

global enum WW_LOG_BATTLE {
  DEFAULT_ARMY_INDEX = 0
  MIN_ARMIES_PER_SIDE = 1
  MAX_ARMIES_PER_SIDE = 2
  MAX_DAMAGED_ARMIES = 5
}

global const WW_LOG_REQUEST_DELAY = 1
global const WW_LOG_MAX_LOAD_AMOUNT = 20
global const WW_LOG_EVENT_LOAD_AMOUNT = 10
global const WW_LOG_MAX_DISPLAY_AMOUNT = 40
