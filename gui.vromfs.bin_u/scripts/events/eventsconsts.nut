global enum EVENT_TYPE { //bit values for easy multi-type search
  UNKNOWN         = 0
  SINGLE          = 1,
  CLAN            = 2,
  TOURNAMENT      = 4,
  NEWBIE_BATTLES  = 8,

  //basic filters
  ANY             = 15,
  ANY_BASE_EVENTS = 5,
}

enum UnitRelevance {
  NONE,
  MEDIUM,
  BEST,
}

enum GAME_EVENT_TYPE {
  // Used for events that are neither race nor tournament.
  TM_NONE = "TM_NONE"

  // Race events.
  TM_NONE_RACE = "TM_NONE_RACE"

  // Different tournament events.
  TM_ELO_PERSONAL = "TM_ELO_PERSONAL"
  TM_ELO_GROUP = "TM_ELO_GROUP"
  TM_ELO_GROUP_DETAIL = "TM_ELO_GROUP_DETAIL"
  TM_DOUBLE_ELIMINATION = "TM_DOUBLE_ELIMINATION"
}


return {
  UnitRelevance
  EVENT_TYPE
  EVENTS_SHORT_LB_VISIBLE_ROWS = 3
  GAME_EVENT_TYPE
}