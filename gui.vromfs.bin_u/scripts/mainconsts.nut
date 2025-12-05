



enum HELP_CONTENT_SET {
  MISSION
  LOADING
  CONTROLS
  MISSION_WINDOW
}

enum SEEN {
  TITLES = "titles"
  AVATARS = "avatars"
  EVENTS = "events"
  WW_MAPS_AVAILABLE = "wwMapsAvailable"
  WW_MAPS_OBJECTIVE = "wwMapsObjective"
  WW_OPERATION_AVAILABLE = "wwOperationAvailable"
  INVENTORY = "inventory"
  ITEMS_SHOP = "items_shop"
  WORKSHOP = "workshop"
  RECYCLING = "recycling"
  WARBONDS_SHOP = "warbondsShop"
  EXT_XBOX_SHOP = "ext_xbox_shop"
  EXT_PS4_SHOP  = "ext_ps4_shop"
  EXT_EPIC_SHOP = "ext_epic_shop"
  BATTLE_PASS_SHOP = "battle_pass_shop"
  UNLOCK_MARKERS = "unlock_markers"
  MANUAL_UNLOCKS = "manual_unlocks"
  REGIONAL_PROMO = "regional_unlocks"
  DECORATORS = "decorators"
  DECALS = "decals"
  INFANTRY_CAMOUFLAGE = "infantry_camouflage"

  
  S_EVENTS_WINDOW = "##events_window##"
}

enum COLOR_TAG {
  ACTIVE = "av"
  USERLOG = "ul"
  TEAM_BLUE = "tb"
  TEAM_RED = "tr"
}

const global_max_players_versus = 64

return {
  COLOR_TAG
  HELP_CONTENT_SET
  SEEN
  LOST_DELAYED_ACTION_MSEC = 500
  global_max_players_versus
}