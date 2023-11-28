enum ps4_activity_feed {
  MISSION_SUCCESS,
  PURCHASE_UNIT,
  CLAN_DUEL_REWARD,
  RESEARCHED_UNIT,
  MISSION_SUCCESS_AFTER_UPDATE,
  MAJOR_UPDATE
}

enum bit_activity {
  NONE              = 0,
  PS4_ACTIVITY_FEED = 1
}

return {
  bit_activity
  ps4_activity_feed
}