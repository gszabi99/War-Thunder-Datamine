from "%scripts/dagui_library.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let { blkOptFromPath } = require("%sqstd/datablock.nut")
let regexp2 = require("regexp2")
let { get_current_mission_name, get_game_mode } = require("mission")
let { enumsAddTypes } = require("%sqStdLibs/helpers/enums.nut")
let { MISSION_GROUP, chapterToGroup, missionGroupToLocKey } = require("%scripts/missions/missionsFilterData.nut")
let { MISSION_OBJECTIVE, getUrlOrFileMissionMetaInfo } = require("%scripts/missions/missionsUtilsModule.nut")
let { get_current_mission_info_cached } = require("blkGetters")
let { isMissionForUnitType } = require("%scripts/missions/missionsUtils.nut")

let g_mission_type = {
  types = []
  _cacheByMissionName = {}
}

g_mission_type.template <- {
  _typeName = "" 
  reMisName = regexp2(@"^$")
  objectives   = MISSION_OBJECTIVE.KILLS_AIR_OR_TANK
  objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.KILLS_TOTAL_AI
  helpBlkPath = ""
  isShipMission = false
  filterGroup = MISSION_GROUP.OTHER
  getObjectives = function(misInfoBlk) {
    return getTblValue("isWorldWar", misInfoBlk) ? this.objectivesWw : this.objectives
  }
}

enumsAddTypes(g_mission_type, {
  UNKNOWN = {
  }

  A_AD = {  
    reMisName = regexp2(@"_AD(n|to)?(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.ZONE_CAPTURE | MISSION_OBJECTIVE.KILLS_TOTAL_AI
    helpBlkPath = "%gui/help/missionAirDomination.blk"
    filterGroup = MISSION_GROUP.DOMINATION
  }

  A_AFD = {  
    reMisName = regexp2(@"_AfD(n|to)?(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    helpBlkPath = "%gui/help/missionAirfieldCapture.blk"
    filterGroup = MISSION_GROUP.DOMINATION
  }

  A_GS = {  
    reMisName = regexp2(@"_GS(n|to)?(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_BOMBING
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_BOMBING
    helpBlkPath = "%gui/help/missionGroundStrikeComplete.blk"
    filterGroup = MISSION_GROUP.GROUND_STRIKE
  }

  A_BFD = {  
    reMisName = regexp2(@"_BfD(n|to)?(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_BOMBING
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_BOMBING
    helpBlkPath = "%gui/help/missionGroundStrikeComplete.blk"
    filterGroup = MISSION_GROUP.DOMINATION
  }

  A_ACONQ = {  
    reMisName = regexp2(@"_aconq?(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE | MISSION_OBJECTIVE.ZONE_BOMBING
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE | MISSION_OBJECTIVE.ZONE_BOMBING
    helpBlkPath = "%gui/help/missionAirfieldCapture.blk"
    filterGroup = MISSION_GROUP.DOMINATION
  }

  A_I2M = {  
    reMisName = regexp2(@"_I2M(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_ANY_AI | MISSION_OBJECTIVE.ZONE_BOMBING
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_BOMBING
    helpBlkPath = "%gui/help/missionGroundStrikeComplete.blk"
    filterGroup = MISSION_GROUP.CONFRONTATION
  }

  A_DUEL = {  
    reMisName = regexp2(@"_duel(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR
    filterGroup = MISSION_GROUP.DUEL
  }

  A_RACE = {  
    reMisName = regexp2(@"_race(_|$)")
    objectives = MISSION_OBJECTIVE.NONE
    objectivesWw = MISSION_OBJECTIVE.NONE
    filterGroup = MISSION_GROUP.RACE
  }

  H_GS = {  
    reMisName = regexp2(@"_HS(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI
    filterGroup = MISSION_GROUP.GROUND_STRIKE
  }

  H_BFD = {  
    reMisName = regexp2(@"_HfD(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    filterGroup = MISSION_GROUP.DOMINATION
  }

  H_H2M = {  
    reMisName = regexp2(@"_H2M(_|$)")
    filterGroup = MISSION_GROUP.CONFRONTATION
  }

  G_DOM = {  
    reMisName = regexp2(@"_Dom(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    helpBlkPath = "%gui/help/missionGroundCapture.blk"
    filterGroup = MISSION_GROUP.DOMINATION
  }

  G_CONQ = {  
    reMisName = regexp2(@"_Conq\d*(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    helpBlkPath = "%gui/help/missionGroundCapture.blk"
    filterGroup = MISSION_GROUP.CONQUEST
  }

  G_BTTL = {  
    reMisName = regexp2(@"_Bttl(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    helpBlkPath = "%gui/help/missionGroundCapture.blk"
    filterGroup = MISSION_GROUP.BATTLE
  }

  G_BTO = {  
    reMisName = regexp2(@"_Bto(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    helpBlkPath = "%gui/help/missionGroundCapture.blk"
    filterGroup = MISSION_GROUP.BATTLE
  }

  G_CNV = {  
    reMisName = regexp2(@"_Cnv(A|B)(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.KILLS_TOTAL_AI
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.KILLS_TOTAL_AI
    filterGroup = MISSION_GROUP.CONVOY
  }

  G_BR = {  
    reMisName = regexp2(@"_BR(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.ALIVE_TIME
    filterGroup = MISSION_GROUP.BATTLE_ROYALE
  }

  G_CTF = {  
    reMisName = regexp2(@"_ctf(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_GROUND
    objectivesWw = MISSION_OBJECTIVE.KILLS_GROUND
    filterGroup = MISSION_GROUP.CAPTURE_THE_FLAG
  }

  G_EXTR = {  
    reMisName = regexp2(@"_extr$")
    objectives = MISSION_OBJECTIVE.WITHOUT_SCORE
    filterGroup = MISSION_GROUP.BATTLE_ROYALE
    helpBlkPath = "%gui/help/missionGroundExtraction.blk"
  }

  









  N_DOM = {  
    reMisName = regexp2(@"_NDom(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    filterGroup = MISSION_GROUP.DOMINATION
    helpBlkPath = "%gui/help/missionNavalDomination.blk"
    isShipMission = true
  }

  N_BTTL = {  
    reMisName = regexp2(@"_NBttl(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    filterGroup = MISSION_GROUP.BATTLE
    helpBlkPath = "%gui/help/missionNavalDomination.blk"
    isShipMission = true
  }

  N_CONQ = {  
    reMisName = regexp2(@"_NConq(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    filterGroup = MISSION_GROUP.CONQUEST
    helpBlkPath = "%gui/help/missionNavalDomination.blk"
    isShipMission = true
  }

  N_ANNIVERSARY_EVENT = {  
    reMisName = regexp2(@"submarine_convoy_hunting_NCnv")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_NAVAL_AI
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_NAVAL_AI
    filterGroup = MISSION_GROUP.CONVOY
    useControlsHelp = "IMAGE_SUBMARINE"
    isShipMission = true
  }

  N_CNV = {  
    reMisName = regexp2(@"_NCnv(A|B|_|$)(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_NAVAL_AI
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_NAVAL_AI
    filterGroup = MISSION_GROUP.CONVOY
    isShipMission = true
  }

  N_TDM = {  
    reMisName = regexp2(@"_NTdm(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_NAVAL_AI
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_NAVAL_AI
    filterGroup = MISSION_GROUP.DEATHMATCH
    isShipMission = true
  }

  N_CTF = {  
    reMisName = regexp2(@"_nctf(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_NAVAL
    objectivesWw = MISSION_OBJECTIVE.KILLS_NAVAL
    filterGroup = MISSION_GROUP.CAPTURE_THE_FLAG
    isShipMission = true
  }

  N_N2M = {  
    reMisName = regexp2(@"_N2M(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_ANY_AI | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.ZONE_BOMBING
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_ANY_AI | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.ZONE_BOMBING
    filterGroup = MISSION_GROUP.CONFRONTATION
    isShipMission = true
  }

  PVE_T = { 
    reMisName = regexp2(@"_pvet(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_GROUND_AI
    objectivesWw = MISSION_OBJECTIVE.KILLS_GROUND_AI
    filterGroup = MISSION_GROUP.OTHER
  }

  PvE = {
    reMisName = regexp2(@"_PvE")
    objectives = MISSION_OBJECTIVE.KILLS_ANY_AI
    objectivesWw = MISSION_OBJECTIVE.KILLS_ANY_AI
    filterGroup = MISSION_GROUP.OTHER
  }
}, null, "_typeName")

g_mission_type.getTypeByMissionName <- function getTypeByMissionName(misName, gm = null) {
  if (!misName)
    return this.UNKNOWN
  if (misName in this._cacheByMissionName)
    return this._cacheByMissionName[misName]

  local res = this.UNKNOWN
  foreach (val in this.types)
    if (val.reMisName.match(misName)) {
      res = val
      break
    }
  if (res == this.UNKNOWN && isMissionForUnitType(getUrlOrFileMissionMetaInfo(misName, gm), ES_UNIT_TYPE_TANK))
    res = this.G_DOM

  this._cacheByMissionName[misName] <- res
  return res
}

g_mission_type.getCurrent <- function getCurrent() {
  return this.getTypeByMissionName(get_current_mission_name(), get_game_mode())
}

g_mission_type.getCurrentObjectives <- function getCurrentObjectives() {
  return this.getCurrent().getObjectives(get_current_mission_info_cached())
}

g_mission_type.getHelpPathForCurrentMission <- function getHelpPathForCurrentMission() {
  let path = this.getCurrent().helpBlkPath
  if (path != "" && !u.isEmpty(blkOptFromPath(path)))
    return path
  return null
}

g_mission_type.getControlHelpName <- function getControlHelpName() {
  return this.getCurrent()?.useControlsHelp
}

let getMissionGroupByChapter = @(missionChapter) chapterToGroup?[missionChapter] ?? MISSION_GROUP.OTHER
let getMissionGroupName = @(missionGroup) loc($"chapters/{missionGroupToLocKey[missionGroup]}")

function getMissionGroup(mission) {
  let group = getMissionGroupByChapter(mission.chapter)
  if (group != MISSION_GROUP.OTHER)
    return group

  return g_mission_type.getTypeByMissionName(mission.id).filterGroup
}

let isShipBattle = @() g_mission_type.getCurrent()?.isShipMission

function isGroundAndAirMission() {
  let objectives = g_mission_type.getCurrentObjectives()
  return !!(objectives & MISSION_OBJECTIVE.KILLS_AIR) && !!(objectives & MISSION_OBJECTIVE.KILLS_GROUND)
}









return { g_mission_type, getMissionGroup, getMissionGroupName, isShipBattle, isGroundAndAirMission




}