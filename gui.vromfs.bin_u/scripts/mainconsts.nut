///!!!!!
// !! THIS IS AUWFUL TRASHBIN. MOVE from here to proper places (and remove globals)
//!!!!!!

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

  //sublists
  S_EVENTS_WINDOW = "##events_window##"
}

enum COLOR_TAG {
  ACTIVE = "av"
  USERLOG = "ul"
  TEAM_BLUE = "tb"
  TEAM_RED = "tr"
}

return {
  COLOR_TAG
  HELP_CONTENT_SET
  SEEN
  LOST_DELAYED_ACTION_MSEC = 500
}