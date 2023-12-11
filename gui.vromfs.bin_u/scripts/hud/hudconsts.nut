enum HINT_INTERVAL {
  ALWAYS_VISIBLE = 0
  HIDDEN = -1
}

enum REWARD_PRIORITY {
  noPriority, //for null message. any real type priority is higher
  common,
  scout,
  scout_hit,
  scout_kill_unknown,
  scout_kill,
  hit,
  critical,
  severe,
  assist,
  kill,
  timed_award
}


enum HUD_VIS_PART { //bit enum
  DMG_PANEL           = 0x0001
  MAP                 = 0x0002
  CAPTURE_ZONE_INFO   = 0x0004
  KILLCAMERA          = 0x0020
  RACE_INFO           = 0x0200

  //masks
  ALL                 = 0xFFFF
  NONE                = 0x0000
}


enum HUD_TYPE {
  CUTSCENE,
  SPECTATOR,
  BENCHMARK,
  AIR,
  TANK,
  SHIP,
  HELICOPTER,
  FREECAM,

  NONE
}

return {
  HINT_INTERVAL
  REWARD_PRIORITY
  HUD_VIS_PART
  HUD_TYPE
}