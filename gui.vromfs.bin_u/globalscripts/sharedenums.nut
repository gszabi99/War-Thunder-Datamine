





enum MouseAxis {
  MOUSE_X,
  MOUSE_Y,
  MOUSE_SCROLL,
  MOUSE_SCROLL_TANK,
  MOUSE_SCROLL_SHIP,
  MOUSE_SCROLL_SUBMARINE,
  MOUSE_SCROLL_HELICOPTER,
  MOUSE_SCROLL_HUMAN,
  NUM_MOUSE_AXIS_TOTAL
};

enum CtrlsInGui {
  CTRL_ALLOW_VEHICLE_KEYBOARD = 0x00000001,
  CTRL_ALLOW_VEHICLE_XINPUT   = 0x00000002,
  CTRL_ALLOW_VEHICLE_JOY      = 0x00000004,
  CTRL_ALLOW_VEHICLE_MOUSE    = 0x00000008,

  CTRL_ALLOW_MP_STATISTICS    = 0x00000010,
  CTRL_ALLOW_MP_CHAT          = 0x00000020,
  CTRL_ALLOW_TACTICAL_MAP     = 0x00000040,
  CTRL_ALLOW_FLIGHT_MENU      = 0x00000080,
  CTRL_ALLOW_ARTILLERY        = 0x00000100,
  CTRL_ALLOW_WHEEL_MENU       = 0x00000200,
  CTRL_ALLOW_SPECTATOR        = 0x00000400,
  CTRL_ALLOW_ANSEL            = 0x00000800,

  CTRL_IN_MP_STATISTICS       = 0x00001000,
  CTRL_IN_MP_CHAT             = 0x00002000,
  CTRL_IN_TACTICAL_MAP        = 0x00004000,
  CTRL_IN_FLIGHT_MENU         = 0x00008000,
  CTRL_IN_MULTIFUNC_MENU      = 0x00010000,
  CTRL_IN_UNLIM_CTRL_MENU     = 0x00020000,
  CTRL_IN_AA_COMPLEX_MENU     = 0x00040000,

  
  CTRL_ALLOW_NONE             = 0x00000000,
  CTRL_ALLOW_FULL             = 0x00000FFF,
  CTRL_WINDOWS_ALL            = 0x000FF000,

  CTRL_ALLOW_VEHICLE_FULL     = 0x0000000F
};

enum AxisInvertOption {
  INVERT_Y,
  INVERT_GUNNER_Y,
  INVERT_THROTTLE,
  INVERT_TANK_Y,
  INVERT_HUMAN_Y,
  INVERT_SHIP_Y,
  INVERT_HELICOPTER_Y,
  INVERT_HELICOPTER_GUNNER_Y,
  INVERT_EXT_TANK_Y,
  INVERT_SPECTATOR_Y,
  INVERT_SUBMARINE_Y,
};

enum DargWidgets {
   NONE = 0
  , HUD
  , SHIP_OBSTACLE_RF
  , SCOREBOARD
  , CHANGE_LOG
  , HUD_TOUCH
  , RESPAWN
  , TANK_SIGHT_SETTINGS
  , WORLDWAR_MAP
  , BULLETS_GRAPH
};

enum AirParamsMain {
  RPM =               0,
  THROTTLE_1 =        1,
  THROTTLE_2 =        2,
  THROTTLE_3 =        3,
  THROTTLE_4 =        4,
  THROTTLE_5 =        5,
  THROTTLE_6 =        6,
  THROTTLE_7 =        7,
  THROTTLE_8 =        8,
  IAS_HUD =           9,
  SPEED =             10,
  MACH =              11,
  ALTITUDE =          12,
  RADAR_ALTITUDE =    13,
  ROCKET =            14,
  BOMBS =             15,
  TORPEDO =           16,
  AGM =               17,
  AAM =               18,
  GUIDED_BOMBS =      19,
  FLARES =            20,
  CHAFFS =            21,
  MACHINE_GUNS_1 =    22,
  MACHINE_GUNS_2 =    23,
  MACHINE_GUNS_3 =    24,
  CANNON_1 =          25,
  CANNON_2 =          26,
  CANNON_3 =          27,
  MACHINE_GUN =       28,
  CANNON_ADDITIONAL = 29,
  IRCM =              30,
  RATE_OF_FIRE =      31
};

enum AirParamsSecondary {
  OIL_1 =          0,
  WATER_1 =        1,
  ENGINE_1 =       2,
  OIL_2 =          3,
  WATER_2 =        4,
  ENGINE_2 =       5,
  OIL_3 =          6,
  WATER_3 =        7,
  ENGINE_3 =       8,
  OIL_4 =          9,
  WATER_4 =        10,
  ENGINE_4 =       11,
  OIL_5 =          12,
  WATER_5 =        13,
  ENGINE_5 =       14,
  OIL_6 =          15,
  WATER_6 =        16,
  ENGINE_6 =       17,
  OIL_7 =          18,
  WATER_7 =        19,
  ENGINE_7 =       20,
  OIL_8 =          21,
  WATER_8 =        22,
  ENGINE_8 =       23,
  TRANSMISSION_1 = 24,
  TRANSMISSION_2 = 25,
  TRANSMISSION_3 = 26,
  TRANSMISSION_4 = 27,
  TRANSMISSION_5 = 28,
  TRANSMISSION_6 = 29,
  TRANSMISSION_7 = 30,
  TRANSMISSION_8 = 31
};

enum AirParamsTertiary {
  FUEL =           0,
  STAMINA =        1,
  INSTRUCTOR =     2
};

enum TemperatureState {
  DEFAULT_TEMPERATURE = 0,
  OVERHEAT = 1,
  EMPTY_TANK = 2,
  FUEL_LEAK = 3,
  FUEL_SEALING = 4,
  BLANK = 5,
  FUEL_DUMPING = 6
};

enum AirThrottleMode {
  DEFAULT_MODE = 0,
  BRAKE = 1,
  CLIMB = 2,
  WEP = 3,
  AIRCRAFT_DEFAULT_MODE = 4,
  AIRCRAFT_BRAKE = 5,
  AIRCRAFT_WEP = 6
};

enum RadarViewMode {
  B_SCOPE_ROUND = 0,
  B_SCOPE_SQUARE = 1,
  MODE_COUNT = 2
};

enum CountermeasureMode {
  PERIODIC_COUNTERMEASURE    = 1,
  MLWS_SLAVED_COUNTERMEASURE = 2,
  FLARE_COUNTERMEASURES      = 4,
  CHAFF_COUNTERMEASURES      = 8
};

enum WeaponMode {
  CCIP_MODE = 1,
  CCRP_MODE = 2,
  BOMB_BAY_OPEN = 3,
  BOMB_BAY_CLOSED = 4,
  BOMB_BAY_OPENING = 5,
  BOMB_BAY_CLOSING = 6,
  GYRO_MODE = 7
};

enum IRCMMode {
  IRCM_ENABLED = 1,
  IRCM_DAMAGED = 2,
  IRCM_DISABLED = 3
};

enum HudColorState {
  ACTIV            = 0,
  PASSIV           = 1,
  LOW_ALERT        = 2,
  MEDIUM_ALERT     = 3,
  HIGH_ALERT       = 4
};

enum FCSShotState {
  SHOT_NONE   = 0,
  SHOT_OVER   = 1,
  SHOT_SHORT  = 2,
  SHOT_STRADLE = 3,
  SHOT_HIT    = 4,
  SHOT_LEFT   = 5,
  SHOT_RIGHT  = 6
};


enum WeaponMask {
  MACHINE_GUN_MASK      = 0x000001,
  CANNON_MASK           = 0x000002,
  GUNNER_MASK           = 0x000004,
  BOMB_MASK             = 0x000008,
  TORPEDO_MASK          = 0x000010,
  ROCKET_MASK           = 0x000020,
  ATGM_MASK             = 0x000040,
  AAM_MASK              = 0x000080,
  MINE_MASK             = 0x000100,
  GUIDED_BOMB_MASK      = 0x000200,
  ADDITIONAL_GUN_MASK   = 0x000400,
  HAND_GRENADE          = 0x000800,
  INF_SPECIAL_WEAPON    = 0x001000,

  ALL_BOMBS_MASK        = 0x000208,
  ALL_ROCKETS_MASK      = 0x0000E0
};

return({ MouseAxis, CtrlsInGui, AxisInvertOption, DargWidgets, AirParamsMain, AirParamsSecondary, AirParamsTertiary, TemperatureState, AirThrottleMode, RadarViewMode, CountermeasureMode, WeaponMode, IRCMMode, HudColorState, FCSShotState, WeaponMask});