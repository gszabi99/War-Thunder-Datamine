let { blkOptFromPath } = require("%sqStdLibs/helpers/datablockUtils.nut")
let enums = require("%sqStdLibs/helpers/enums.nut")
let { MISSION_GROUP } = require("%scripts/missions/missionsFilterData.nut")
let { MISSION_OBJECTIVE } = require("%scripts/missions/missionsUtilsModule.nut")

::g_mission_type <- {
  types = []
  _cacheByMissionName = {}
}

::g_mission_type.template <- {
  _typeName = "" //filled by type name
  reMisName = ::regexp2(@"^$")
  objectives   = MISSION_OBJECTIVE.KILLS_AIR_OR_TANK
  objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.KILLS_TOTAL_AI
  helpBlkPath = ""
  filterGroup = MISSION_GROUP.OTHER
  getObjectives = function(misInfoBlk) {
    return ::getTblValue("isWorldWar", misInfoBlk) ? objectivesWw : objectives
  }
}

enums.addTypesByGlobalName("g_mission_type", {
  UNKNOWN = {
  }

  A_AD = {  // Air: Air Domination
    reMisName = ::regexp2(@"_AD(n|to)?(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.ZONE_CAPTURE | MISSION_OBJECTIVE.KILLS_TOTAL_AI
    helpBlkPath = "%gui/help/missionAirDomination.blk"
    filterGroup = MISSION_GROUP.DOMINATION
  }

  A_AFD = {  // Air: Airfield Domination
    reMisName = ::regexp2(@"_AfD(n|to)?(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND_AI | MISSION_OBJECTIVE.KILLS_NAVAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    helpBlkPath = "%gui/help/missionAirfieldCapture.blk"
    filterGroup = MISSION_GROUP.DOMINATION
  }

  A_GS = {  // Air: Ground Strike
    reMisName = ::regexp2(@"_GS(n|to)?(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND_AI | MISSION_OBJECTIVE.KILLS_NAVAL_AI
                 | MISSION_OBJECTIVE.ZONE_BOMBING
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_BOMBING
    helpBlkPath = "%gui/help/missionGroundStrikeComplete.blk"
    filterGroup = MISSION_GROUP.GROUND_STRIKE
  }

  A_BFD = {  // Air: Battlefront Domination
    reMisName = ::regexp2(@"_BfD(n|to)?(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND_AI | MISSION_OBJECTIVE.KILLS_NAVAL_AI
                 | MISSION_OBJECTIVE.ZONE_BOMBING
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_BOMBING
    helpBlkPath = "%gui/help/missionGroundStrikeComplete.blk"
    filterGroup = MISSION_GROUP.DOMINATION
  }

  A_I2M = {  // Air: Enduring Confrontation
    reMisName = ::regexp2(@"_I2M(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_ANY_AI | MISSION_OBJECTIVE.ZONE_BOMBING
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_BOMBING
    helpBlkPath = "%gui/help/missionGroundStrikeComplete.blk"
    filterGroup = MISSION_GROUP.CONFRONTATION
  }

  A_DUEL = {  // Air: Duel
    reMisName = ::regexp2(@"_duel(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR
    filterGroup = MISSION_GROUP.DUEL
  }

  A_RACE = {  // Air: Race
    reMisName = ::regexp2(@"_race(_|$)")
    objectives = MISSION_OBJECTIVE.NONE
    objectivesWw = MISSION_OBJECTIVE.NONE
    filterGroup = MISSION_GROUP.RACE
  }

  H_GS = {  // Helicopter: Ground Strike
    reMisName = ::regexp2(@"_HS(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI
    filterGroup = MISSION_GROUP.GROUND_STRIKE
  }

  H_BFD = {  // Helicopter: Battlefront Domination
    reMisName = ::regexp2(@"_HfD(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    filterGroup = MISSION_GROUP.DOMINATION
  }

  H_H2M = {  // Helicopter: Enduring Confrontation
    reMisName = ::regexp2(@"_H2M(_|$)")
    filterGroup = MISSION_GROUP.CONFRONTATION
  }

  G_DOM = {  // Ground: Domination
    reMisName = ::regexp2(@"_Dom(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    helpBlkPath = "%gui/help/missionGroundCapture.blk"
    filterGroup = MISSION_GROUP.DOMINATION
  }

  G_CONQ = {  // Ground: Conquest
    reMisName = ::regexp2(@"_Conq\d*(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    helpBlkPath = "%gui/help/missionGroundCapture.blk"
    filterGroup = MISSION_GROUP.CONQUEST
  }

  G_BTTL = {  // Ground: Battle
    reMisName = ::regexp2(@"_Bttl(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    helpBlkPath = "%gui/help/missionGroundCapture.blk"
    filterGroup = MISSION_GROUP.BATTLE
  }

  G_BTO = {  // Ground: Break
    reMisName = ::regexp2(@"_Bto(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    helpBlkPath = "%gui/help/missionGroundCapture.blk"
    filterGroup = MISSION_GROUP.BATTLE
  }

  G_CNV = {  // Ground: Convoy
    reMisName = ::regexp2(@"_Cnv(A|B)(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.KILLS_TOTAL_AI
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.KILLS_TOTAL_AI
    filterGroup = MISSION_GROUP.CONVOY
  }

  G_BR = {  // Ground: Battle Royale
    reMisName = ::regexp2(@"_BR(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.ALIVE_TIME
    filterGroup = MISSION_GROUP.BATTLE_ROYALE
  }

  G_CTF = {  // Ground: Capture the Flag
    reMisName = ::regexp2(@"_ctf(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_GROUND
    objectivesWw = MISSION_OBJECTIVE.KILLS_GROUND
    filterGroup = MISSION_GROUP.CAPTURE_THE_FLAG
  }

  N_DOM = {  // Naval: Domination
    reMisName = ::regexp2(@"_NDom(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    filterGroup = MISSION_GROUP.DOMINATION
  }

  N_BTTL = {  // Naval: Battle
    reMisName = ::regexp2(@"_NBttl(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    filterGroup = MISSION_GROUP.BATTLE
  }

  N_CONQ = {  // Naval: Conquest
    reMisName = ::regexp2(@"_NConq(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    filterGroup = MISSION_GROUP.CONQUEST
  }

  N_CNV = {  // Naval: Convoy
    reMisName = ::regexp2(@"_NCnv(A|B|_|$)(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_NAVAL_AI
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_NAVAL_AI
    filterGroup = MISSION_GROUP.CONVOY
  }

  N_TDM = {  // Naval: Team Deathmatch
    reMisName = ::regexp2(@"_NTdm(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_NAVAL_AI
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_NAVAL_AI
    filterGroup = MISSION_GROUP.DEATHMATCH
  }

  N_CTF = {  // Naval: Capture the Flag
    reMisName = ::regexp2(@"_nctf(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_NAVAL
    objectivesWw = MISSION_OBJECTIVE.KILLS_NAVAL
    filterGroup = MISSION_GROUP.CAPTURE_THE_FLAG
  }

  N_N2M = {  // Naval: Enduring Confrontation
    reMisName = ::regexp2(@"_N2M(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_ANY_AI | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.ZONE_BOMBING
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_ANY_AI | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.ZONE_BOMBING
    filterGroup = MISSION_GROUP.CONFRONTATION
  }

  PVE_T = { // PvE co-op: Tank
    reMisName = ::regexp2(@"_pvet(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_GROUND_AI
    objectivesWw = MISSION_OBJECTIVE.KILLS_GROUND_AI
    filterGroup = MISSION_GROUP.OTHER
  }

  PvE = {
    reMisName = ::regexp2(@"_PvE")
    objectives = MISSION_OBJECTIVE.KILLS_ANY_AI
    objectivesWw = MISSION_OBJECTIVE.KILLS_ANY_AI
    filterGroup = MISSION_GROUP.OTHER
  }
}, null, "_typeName")

g_mission_type.getTypeByMissionName <- function getTypeByMissionName(misName)
{
  if (!misName)
    return UNKNOWN
  if (misName in _cacheByMissionName)
    return _cacheByMissionName[misName]

  local res = UNKNOWN
  foreach (val in types)
    if (val.reMisName.match(misName))
    {
      res = val
      break
    }
  if (res == UNKNOWN && ::is_mission_for_unittype(::get_mission_meta_info(misName), ::ES_UNIT_TYPE_TANK))
    res = G_DOM

  _cacheByMissionName[misName] <- res
  return res
}

g_mission_type.getCurrent <- function getCurrent()
{
  return getTypeByMissionName(::get_current_mission_name())
}

g_mission_type.getCurrentObjectives <- function getCurrentObjectives()
{
  return getCurrent().getObjectives(::get_current_mission_info_cached())
}

g_mission_type.getHelpPathForCurrentMission <- function getHelpPathForCurrentMission()
{
  let path = getCurrent().helpBlkPath
  if (path != "" && !::u.isEmpty(blkOptFromPath(path)))
    return path
  return null
}