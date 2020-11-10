local { blkOptFromPath } = require("sqStdLibs/helpers/datablockUtils.nut")
local enums = require("sqStdLibs/helpers/enums.nut")
global enum MISSION_OBJECTIVE
{
  KILLS_AIR           = 0x0001
  KILLS_GROUND        = 0x0002
  KILLS_NAVAL         = 0x0004

  KILLS_AIR_AI        = 0x0010
  KILLS_GROUND_AI     = 0x0020
  KILLS_NAVAL_AI      = 0x0040

  KILLS_TOTAL_AI      = 0x0100

  ZONE_CAPTURE        = 0x0200
  ZONE_BOMBING        = 0x0400
  ALIVE_TIME          = 0x0800

  //masks
  NONE                = 0x0000
  ANY                 = 0xFFFF

  KILLS_ANY           = 0x0077
  KILLS_AIR_OR_TANK   = 0x0033
  KILLS_ANY_AI        = 0x0070
}

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
    helpBlkPath = "gui/help/missionAirDomination.blk"
  }

  A_AFD = {  // Air: Airfield Domination
    reMisName = ::regexp2(@"_AfD(n|to)?(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND_AI | MISSION_OBJECTIVE.KILLS_NAVAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    helpBlkPath = "gui/help/missionAirfieldCapture.blk"
  }

  A_GS = {  // Air: Ground Strike
    reMisName = ::regexp2(@"_GS(n|to)?(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND_AI | MISSION_OBJECTIVE.KILLS_NAVAL_AI
                 | MISSION_OBJECTIVE.ZONE_BOMBING
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_BOMBING
    helpBlkPath = "gui/help/missionGroundStrikeComplete.blk"
  }

  A_BFD = {  // Air: Battlefront Domination
    reMisName = ::regexp2(@"_BfD(n|to)?(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND_AI | MISSION_OBJECTIVE.KILLS_NAVAL_AI
                 | MISSION_OBJECTIVE.ZONE_BOMBING
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_BOMBING
    helpBlkPath = "gui/help/missionGroundStrikeComplete.blk"
  }

  A_I2M = {  // Air: Enduring Confrontation
    reMisName = ::regexp2(@"_I2M(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_ANY_AI | MISSION_OBJECTIVE.ZONE_BOMBING
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_BOMBING
    helpBlkPath = "gui/help/missionGroundStrikeComplete.blk"
  }

  A_DUEL = {  // Air: Duel
    reMisName = ::regexp2(@"_duel(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR
  }

  A_RACE = {  // Air: Race
    reMisName = ::regexp2(@"_race(_|$)")
    objectives = MISSION_OBJECTIVE.NONE
    objectivesWw = MISSION_OBJECTIVE.NONE
  }

  H_GS = {  // Helicopter: Ground Strike
    reMisName = ::regexp2(@"_HS(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI
  }

  H_BFD = {  // Helicopter: Battlefront Domination
    reMisName = ::regexp2(@"_HfD(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
  }

  G_DOM = {  // Ground: Domination
    reMisName = ::regexp2(@"_Dom(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    helpBlkPath = "gui/help/missionGroundCapture.blk"
  }

  G_CONQ = {  // Ground: Conquest
    reMisName = ::regexp2(@"_Conq\d*(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    helpBlkPath = "gui/help/missionGroundCapture.blk"
  }

  G_BTTL = {  // Ground: Battle
    reMisName = ::regexp2(@"_Bttl(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    helpBlkPath = "gui/help/missionGroundCapture.blk"
  }

  G_BTO = {  // Ground: Break
    reMisName = ::regexp2(@"_Bto(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    helpBlkPath = "gui/help/missionGroundCapture.blk"
  }

  G_CNV = {  // Ground: Convoy
    reMisName = ::regexp2(@"_Cnv(A|B)(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.KILLS_TOTAL_AI
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.KILLS_TOTAL_AI
  }

  G_BR = {  // Ground: Battle Royale
    reMisName = ::regexp2(@"_BR(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.ALIVE_TIME
  }

  G_CTF = {  // Ground: Capture the Flag
    reMisName = ::regexp2(@"_ctf(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_GROUND
    objectivesWw = MISSION_OBJECTIVE.KILLS_GROUND
  }

  N_DOM = {  // Naval: Domination
    reMisName = ::regexp2(@"_NDom(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
  }

  N_BTTL = {  // Naval: Battle
    reMisName = ::regexp2(@"_NBttl(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
  }

  N_CONQ = {  // Naval: Conquest
    reMisName = ::regexp2(@"_NConq(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
  }

  N_CNV = {  // Naval: Convoy
    reMisName = ::regexp2(@"_NCnv(A|B|_|$)(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_NAVAL_AI
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_NAVAL_AI
  }

  N_TDM = {  // Naval: Team Deathmatch
    reMisName = ::regexp2(@"_NTdm(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_NAVAL_AI
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_NAVAL_AI
  }

  N_CTF = {  // Naval: Capture the Flag
    reMisName = ::regexp2(@"_nctf(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_NAVAL
    objectivesWw = MISSION_OBJECTIVE.KILLS_NAVAL
  }

  N_N2M = {  // Naval: Enduring Confrontation
    reMisName = ::regexp2(@"_N2M(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_ANY_AI | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.ZONE_BOMBING
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_ANY_AI | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.ZONE_BOMBING
  }

  PvE = {
    reMisName = ::regexp2(@"_PvE")
    objectives = MISSION_OBJECTIVE.KILLS_ANY_AI
    objectivesWw = MISSION_OBJECTIVE.KILLS_ANY_AI
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
  local path = getCurrent().helpBlkPath
  if (path != "" && !::u.isEmpty(blkOptFromPath(path)))
    return path
  return null
}