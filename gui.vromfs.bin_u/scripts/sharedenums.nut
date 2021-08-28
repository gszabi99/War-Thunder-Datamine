// Note:
// This enums is shared between squirrel and C++ code
// any change requires version.nut update.
// Also do not reorder mouse axes order in order to
// keep compatibility with old controls presets.
global enum MouseAxis
{
  MOUSE_X,
  MOUSE_Y,
  MOUSE_SCROLL,
  MOUSE_SCROLL_TANK,
  MOUSE_SCROLL_SHIP,
  MOUSE_SCROLL_SUBMARINE,
  MOUSE_SCROLL_HELICOPTER,
  NUM_MOUSE_AXIS_TOTAL
};

global enum CtrlsInGui
{
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

  //masks
  CTRL_ALLOW_NONE             = 0x00000000,
  CTRL_ALLOW_FULL             = 0x00000FFF,
  CTRL_WINDOWS_ALL            = 0x000FF000,

  CTRL_ALLOW_VEHICLE_FULL     = 0x0000000F
};

global enum AxisInvertOption
{
  INVERT_Y,
  INVERT_GUNNER_Y,
  INVERT_THROTTLE,
  INVERT_TANK_Y,
  INVERT_SHIP_Y,
  INVERT_HELICOPTER_Y,
  INVERT_HELICOPTER_GUNNER_Y,
  INVERT_EXT_TANK_Y,
  INVERT_SPECTATOR_Y,
  INVERT_SUBMARINE_Y,
};

global enum DargWidgets
{
   NONE = 0
  ,HUD
  ,SHIP_OBSTACLE_RF
  ,SCOREBOARD
  ,CHANGE_LOG
  ,DAMAGE_PANEL
};

global enum AirParamsMain
{
  RPM =               0,
  THROTTLE_1 =        1,
  THROTTLE_2 =        2,
  THROTTLE_3 =        3,
  THROTTLE_4 =        4,
  THROTTLE_5 =        5,
  THROTTLE_6 =        6,
  IAS_HUD =           7,
  SPEED =             8,
  MACH =              9,
  ALTITUDE =          10,
  CANNON_1 =          11,
  CANNON_2 =          12,
  CANNON_3 =          13,
  MACHINE_GUN =       14,
  CANNON_ADDITIONAL = 15,
  ROCKET =            16,
  AGM =               17,
  AAM =               18,
  GUIDED_BOMBS =      19,
  BOMBS =             20,
  FLARES =            21,
  CHAFFS =            22,
  IRCM =              23,
  RATE_OF_FIRE =      24
};

global enum AirParamsSecondary
{
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
  TRANSMISSION_1 = 18,
  TRANSMISSION_2 = 19,
  TRANSMISSION_3 = 20,
  TRANSMISSION_4 = 21,
  TRANSMISSION_5 = 22,
  TRANSMISSION_6 = 23,
  FUEL =           24,
  STAMINA =        25,
  INSTRUCTOR =     26
};

global enum TemperatureState
{
  DEFAULT_TEMPERATURE = 0,
  OVERHEAT = 1,
  EMPTY_TANK = 2,
  FUEL_LEAK = 3,
  FUEL_SEALING = 4,
  BLANK = 5
};

global enum AirThrottleMode
{
  DEFAULT_MODE = 0,
  BRAKE = 1,
  CLIMB = 2,
  WEP = 3,
  AIRCRAFT_DEFAULT_MODE = 4,
  AIRCRAFT_BRAKE = 5,
  AIRCRAFT_WEP = 6
};

global enum RadarViewMode
{
  B_SCOPE_ROUND = 0,
  B_SCOPE_SQUARE = 1,
  MODE_COUNT = 2
};

global enum CountermeasureMode
{
  PERIODIC_COUNTERMEASURE    = 1,
  MLWS_SLAVED_COUNTERMEASURE = 2
};

global enum WeaponMode
{
  CCIP_MODE = 1,
  CCRP_MODE = 2,
  BOMB_BAY_OPEN = 3,
  BOMB_BAY_CLOSED = 4,
  BOMB_BAY_OPENING = 5,
  BOMB_BAY_CLOSING = 6
};

global enum IRCMMode
{
  IRCM_ENABLED = 1,
  IRCM_DAMAGED = 2,
  IRCM_DISABLED = 3
};

global enum HudColorState
{
  ACTIV            = 0,
  PASSIV           = 1,
  LOW_ALERT        = 2,
  MEDIUM_ALERT     = 3,
  HIGH_ALERT       = 4
};

