local MISSION_GROUP = {
  TOURNAMENT       = 0x00001
  DOMINATION       = 0x00002
  BATTLE           = 0x00004
  CONQUEST         = 0x00008
  OPERATION        = 0x00010
  ALT_HISTORY      = 0x00020
  GROUND_STRIKE    = 0x00040
  DUEL             = 0x00080
  DEATHMATCH       = 0x00100
  RACE             = 0x00200
  DEFENSE          = 0x00400
  CONVOY           = 0x00800
  CAPTURE_THE_FLAG = 0x01000
  BATTLE_ROYALE    = 0x02000
  CONFRONTATION    = 0x04000
  EVENT            = 0x08000
  BOMB_COVER       = 0x10000
  OTHER            = 0x20000
}

local chapterToGroup = {
  tournament           = MISSION_GROUP.TOURNAMENT
  airfield_dom         = MISSION_GROUP.DOMINATION
  air_ground_Dom       = MISSION_GROUP.DOMINATION
  air_dom              = MISSION_GROUP.DOMINATION
  air_naval_Dom        = MISSION_GROUP.DOMINATION
  air_ground_Bttl      = MISSION_GROUP.BATTLE
  air_naval_Bttl       = MISSION_GROUP.BATTLE
  air_ground_battles   = MISSION_GROUP.BATTLE
  air_ground_Conq      = MISSION_GROUP.CONQUEST
  air_naval_Conq       = MISSION_GROUP.CONQUEST
  base_dom             = MISSION_GROUP.OPERATION
  alt_dom              = MISSION_GROUP.ALT_HISTORY
  ground_strike        = MISSION_GROUP.GROUND_STRIKE
  duel                 = MISSION_GROUP.DUEL
  air_naval_Tdm        = MISSION_GROUP.DEATHMATCH
  ffa                  = MISSION_GROUP.RACE
  air_ground_DBttl     = MISSION_GROUP.DEFENSE
  air_ground_Cnv       = MISSION_GROUP.CONVOY
  air_naval_Cnv        = MISSION_GROUP.CONVOY
  ground_ctf           = MISSION_GROUP.CAPTURE_THE_FLAG
  naval_ctf            = MISSION_GROUP.CAPTURE_THE_FLAG
  ground_br            = MISSION_GROUP.BATTLE_ROYALE
  event                = MISSION_GROUP.EVENT
  bomb_cover           = MISSION_GROUP.BOMB_COVER
}

local missionGroupToLocKey =
{
  [MISSION_GROUP.TOURNAMENT]       = "tournament",
  [MISSION_GROUP.DOMINATION]       = "dom",
  [MISSION_GROUP.BATTLE]           = "air_ground_Bttl",
  [MISSION_GROUP.CONQUEST]         = "air_ground_Conq",
  [MISSION_GROUP.OPERATION]        = "base_dom",
  [MISSION_GROUP.ALT_HISTORY]      = "alt_dom",
  [MISSION_GROUP.GROUND_STRIKE]    = "ground_strike",
  [MISSION_GROUP.DUEL]             = "duel",
  [MISSION_GROUP.DEATHMATCH]       = "deathmatch",
  [MISSION_GROUP.RACE]             = "ffa",
  [MISSION_GROUP.DEFENSE]          = "air_ground_DBttl",
  [MISSION_GROUP.CONVOY]           = "air_ground_Cnv",
  [MISSION_GROUP.CAPTURE_THE_FLAG] = "capture_the_flag",
  [MISSION_GROUP.BATTLE_ROYALE]    = "battle_royale",
  [MISSION_GROUP.CONFRONTATION]    = "confrontation",
  [MISSION_GROUP.EVENT]            = "event",
  [MISSION_GROUP.BOMB_COVER]       = "bomb_cover",
  [MISSION_GROUP.OTHER]            = "other",
}

local getMissionGroupByChapter = @(missionChapter) chapterToGroup?[missionChapter] ?? MISSION_GROUP.OTHER
local getMissionGroupName = @(missionGroup) ::loc($"chapters/{missionGroupToLocKey[missionGroup]}")

local function getMissionGroup(mission) {
  local group = getMissionGroupByChapter(mission.chapter)
  if (group != MISSION_GROUP.OTHER)
    return group

  return ::g_mission_type.getTypeByMissionName(mission.id).filterGroup
}

return {
  getMissionGroup
  getMissionGroupName
  MISSION_GROUP
}