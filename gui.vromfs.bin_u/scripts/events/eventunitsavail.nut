from "dagor.random" import rnd
from "%scripts/dagui_library.nut" import *
from "%scripts/squads/squadsConsts.nut" import squadMemberState, memberStatus

let antiCheat = require("%scripts/penitentiary/antiCheat.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { isInSquad, isSquadLeader, getMembers, getPlayerStatusInMySquad } = require("%scripts/squads/squadState.nut")
let { isEventMultiSlotEnabled } = require("%scripts/events/eventsState.nut")
let { canJoinWithoutRequireCrafts } = require("%scripts/events/eventInfo.nut")
let { getSidesList, getTeamData, getCountries, getRequiredCrafts, getEDiffByEvent, getMinCraftsToPlay,
  isAirRequiredAndAllowedByTeamData, isUnitMatchesRule, isUnitAllowedByTeamData
} = require("%scripts/events/eventTeamsInfo.nut")
let { getRoomMGameMode, getRoomSpecialRules, getRoomTeamData } = require("%scripts/matchingRooms/sessionLobbyInfo.nut")
let { getAllCountriesSets, getModeById } = require("%scripts/matching/matchingGameModes.nut")
let { getCrewsListByCountry } = require("%scripts/slotbar/crewsList.nut")
let { isCrewLockedByPrevBattle } = require("%scripts/crew/crewInfo.nut")
let { getCrewUnit } = require("%scripts/crew/crew.nut")
let { getBrokenAirsInfo } = require("%scripts/unit/brokenAirsInfo.nut")





function getSquadMembersFlyoutData(teamData, event) {
  let res = {
    canFlyout = true,
    haveRestrictions = false
    members = []
  }

  if (!isInSquad() || !teamData)
    return res

  let ediff = getEDiffByEvent(event)
  let respawn = isEventMultiSlotEnabled(event)
  let shouldUseEac = antiCheat.shouldUseEac(event)
  let minCraftsToPlay = getMinCraftsToPlay(event)
  let squadMembers = getMembers()
  foreach (uid, memberData in squadMembers) {
    if (!memberData.online || getPlayerStatusInMySquad(uid) == squadMemberState.SQUAD_LEADER)
      continue

    if (memberData.country == "")
      continue

    let mData = {
            uid = memberData.uid
            name = memberData.name
            status = memberStatus.READY
            countries = []
            selAirs = memberData.selAirs
            selSlots = memberData.selSlots
            dislikedMissions = memberData?.dislikedMissions ?? []
            bannedMissions = memberData?.bannedMissions ?? []
            fakeName = memberData?.fakeName ?? false
            hideClan = memberData?.hideClan ?? false
            queueProfileJwt = memberData?.queueProfileJwt ?? ""
          }

    local haveAvailCountries = false
    local isAnyRequiredAndAvailableFound = false

    let brokenUnits = []
    let { country } = memberData
    let isForceAvailable = canJoinWithoutRequireCrafts(event)
    let needCheckRequired = !isForceAvailable && getRequiredCrafts(teamData).len() > 0
    local haveNotBroken = isForceAvailable
    local isValidCountry = true
    local availableUnitsCount = 0
    if (isInArray(country, teamData.countries)) {
      local haveAvailable = isForceAvailable
      local haveRequired  = !needCheckRequired

      if (!haveAvailable) {
        if (!respawn) {
          let unitName = memberData.selAirs?[country] ?? ""
          if (unitName == "")
            continue

          haveAvailable = isUnitAllowedByTeamData(teamData, unitName, ediff)
          let isBroken = isInArray(unitName, memberData.brokenAirs)
          if (isBroken)
            brokenUnits.append(unitName)
          haveNotBroken = haveAvailable && !isBroken
          if (haveNotBroken)
            availableUnitsCount++
          haveRequired  = haveRequired || isAirRequiredAndAllowedByTeamData(teamData, unitName, ediff)
        }
        else {
          if ((memberData.crewAirs?[country] ?? []).len() == 0)
            continue

          foreach (unitName in memberData.crewAirs[country]) {
            let isAvailable = isUnitAllowedByTeamData(teamData, unitName, ediff)
            haveAvailable = haveAvailable || isAvailable
            let isBroken = isInArray(unitName, memberData.brokenAirs)
            if (isBroken)
              brokenUnits.append(unitName)
            let isNotBroken = isAvailable && !isBroken
            haveNotBroken = haveNotBroken || isNotBroken
            if (isNotBroken)
              availableUnitsCount++
            haveRequired  = haveRequired  || isAirRequiredAndAllowedByTeamData(teamData, unitName, ediff)
          }
        }
      }

      haveAvailCountries = haveAvailCountries || haveAvailable
      isAnyRequiredAndAvailableFound = isAnyRequiredAndAvailableFound || (haveAvailable && haveRequired)
      if (haveAvailable && haveNotBroken && haveRequired)
        mData.countries.append(country)
    }
    else {
      isValidCountry = false
    }

    if (shouldUseEac && !(memberData?.isEacInited ?? false))
      mData.status = memberStatus.EAC_NOT_INITED
    else if (!haveAvailCountries)
      mData.status = !isValidCountry ? memberStatus.SELECTED_COUNTRY_NOT_AVAILABLE
      : respawn ? memberStatus.AIRS_NOT_AVAILABLE
      : memberStatus.SELECTED_AIRS_NOT_AVAILABLE
    else if (!isAnyRequiredAndAvailableFound)
      mData.status = memberStatus.NO_REQUIRED_UNITS
    else if (!mData.countries.len())
      mData.status = respawn ? memberStatus.ALL_AVAILABLE_AIRS_BROKEN : memberStatus.SELECTED_AIRS_BROKEN
    else if (minCraftsToPlay > 1 && availableUnitsCount < minCraftsToPlay) {
      mData.status = memberStatus.NOT_ENOUGH_SUITABLE_UNITS
      mData.statusLocParams <- { count = minCraftsToPlay }
    }
    else if (brokenUnits.len() && haveNotBroken)
      mData.status = memberStatus.PARTLY_AVAILABLE_AIRS_BROKEN

    res.canFlyout = res.canFlyout && (mData.status == memberStatus.READY || mData.status == memberStatus.PARTLY_AVAILABLE_AIRS_BROKEN)
    res.haveRestrictions = res.haveRestrictions || mData.status == memberStatus.PARTLY_AVAILABLE_AIRS_BROKEN
    res.members.append(mData)
  }

  return res
}

function getMGameMode(event, room) {
  return (room && getRoomMGameMode(room)) || event
}

function isLobbyGameMode(mGameMode) {
  return mGameMode?.withLobby ?? false
}

function getTeamDataWithRoom(event, team, room) {
  if (room)
    return getRoomTeamData(team, room)
  return getTeamData(event, team)
}

function getAvailableTeams(event, room = null) {
  let availableTeams = []
  if (!event)
    return availableTeams
  let playersCurCountry = profileCountrySq.get()
  if (!playersCurCountry || playersCurCountry.len() <= 0)
    return availableTeams

  let mgm = getMGameMode(event, room)
  foreach (team in getSidesList(isLobbyGameMode(mgm) ? null : mgm)) {
    let teamData = getTeamDataWithRoom(event, team, room)
    if (isInArray(playersCurCountry, getCountries(teamData)))
      availableTeams.append(team)
  }
  return availableTeams
}

function getTeamWithUnitsReq(event, room = null, country = null) {
  let playersCurCountry = country ?? profileCountrySq.get()
  foreach (team in getSidesList(event)) {
    let teamData = getTeamDataWithRoom(event, team, room)
    if (!getRequiredCrafts(teamData).len()
        || !isInArray(playersCurCountry, teamData.countries))
      continue
    return teamData
  }
  return null
}

function getValidUnitsListForTeam(event, teamData, country, params = null) {
  let playersCurCountry = country ?? profileCountrySq.get()
  let ediff = getEDiffByEvent(event)

  let crews = getCrewsListByCountry(playersCurCountry)
  let validUnits = []
  foreach (crew in crews) {
    if (isCrewLockedByPrevBattle(crew))
      continue

    let unit = getCrewUnit(crew)
    if (unit && (teamData == null || isAirRequiredAndAllowedByTeamData(teamData, unit.name, ediff))) {
      validUnits.append(unit)
      if (params?.isOneEnough)
        return validUnits
    }
  }
  return validUnits
}

function checkRequiredUnits(event, room = null, country = null) {
  if (!event)
    return false

  if (canJoinWithoutRequireCrafts(event))
    return true

  let teamData = getTeamWithUnitsReq(event, room, country)
  if (teamData == null)
    return true
  let validUnits = getValidUnitsListForTeam(event, teamData, country, {isOneEnough = true})
  return validUnits.len() > 0
}

function getCountryRepairInfo(event, room = null, country = null) {
  let playersCurCountry = country ?? profileCountrySq.get()
  let mGameMode = getMGameMode(event, room)
  let roomSpecialRules = room && getRoomSpecialRules(room)
  let teams = getAvailableTeams(mGameMode)
  let ediff = getEDiffByEvent(event)
  let teamsData = []
  foreach (t in teams)
    teamsData.append(getTeamData(mGameMode, t))

  return getBrokenAirsInfo([playersCurCountry], isEventMultiSlotEnabled(event),
    function(unit) {
      if (roomSpecialRules
          && !isUnitMatchesRule(unit, roomSpecialRules, true, ediff))
        return false
      foreach (td in teamsData)
        if (isUnitAllowedByTeamData(td, unit.name, ediff))
          return true
      return false
    })
}

function getMembersFlyoutEventData(event, room, team) {
  let mGameMode = getMGameMode(event, room)
  let teamData = getTeamDataWithRoom(mGameMode, team, room)
  return getSquadMembersFlyoutData(teamData, event)
}

function getMembersFlyoutEventDataImpl(roomMgm, room, teams) {
  let res = {
    teamsData = []
    cantFlyData = []
    canFlyout = false
    haveRestrictions = true
  }
  foreach (team in teams) {
    let data = getMembersFlyoutEventData(roomMgm, room, team)
    data.team <- team

    if (data.canFlyout) {
      res.teamsData.append(data)
      res.canFlyout = true
      res.haveRestrictions = res.haveRestrictions && data.haveRestrictions
      if (data.haveRestrictions)
        res.cantFlyData.append(data)
    }
    else
      res.cantFlyData.append(data)
  }
  return res
}

function getMembersTeamsData(event, room, teams) {
  if (!isSquadLeader())
    return null

  local bestTeamsData = null
  if (room)
    bestTeamsData = getMembersFlyoutEventDataImpl(event, room, teams)
  else {
    let myCountry = profileCountrySq.get()
    let allSets = getAllCountriesSets(event)
    foreach (countrySet in allSets) {
      let mgmTeams = []
      foreach (idx, countries in countrySet.countries)
        if (isInArray(myCountry, countries))
          mgmTeams.append(idx + 1) 
      if (!mgmTeams.len())
        continue

      foreach (gameModeId in countrySet.gameModeIds) {
        let mgm = getModeById(gameModeId)
        if (!mgm)
          continue
        let teamsData = getMembersFlyoutEventDataImpl(mgm, null, mgmTeams)

        local compareTeamData = !!teamsData <=> !!bestTeamsData
          || !teamsData.haveRestrictions <=> !bestTeamsData.haveRestrictions
        if (compareTeamData == 0 && teamsData.haveRestrictions)
          compareTeamData = bestTeamsData.cantFlyData.len() <=> teamsData.cantFlyData.len()

        if (compareTeamData > 0) {
          bestTeamsData = teamsData
          if (!bestTeamsData.haveRestrictions)
            break
        }
      }
      if (bestTeamsData && !bestTeamsData.haveRestrictions)
        break
    }
  }

  return bestTeamsData
}

function prepareMembersForQueue(membersData) {
  let membersQuery = {}
  let leaderCountry = profileCountrySq.get()
  foreach (m in membersData.members) {
    local country = leaderCountry
    if (m.countries.len() && !isInArray(leaderCountry, m.countries))
      country = m.countries[rnd() % m.countries.len()]  
    let slot = (country in m.selSlots) ? m.selSlots[country] : 0

    membersQuery[m.uid] <- {
      queueProfileJwt = m?.queueProfileJwt ?? ""
      country = country
      slots = {
        [country] = slot
      }
      dislikedMissions = m?.dislikedMissions ?? []
      bannedMissions = m?.bannedMissions ?? []
      fakeName = m?.fakeName ?? false
      hideClan = m?.hideClan ?? false
    }
  }
  return membersQuery
}

function getMembersInfo(membersTeams) {
  let teamsData = membersTeams.teamsData
  if (teamsData.len() == 0)
    return null

  let notRestrictionsTeamsData = teamsData.filter(@(v) !v.haveRestrictions)
  let membersData = notRestrictionsTeamsData.len() > 0
    ? notRestrictionsTeamsData[rnd() % notRestrictionsTeamsData.len()]
    : teamsData[rnd() % teamsData.len()]
  let membersQuery = prepareMembersForQueue(membersData)
  return membersQuery
}


return {
  getMGameMode
  getTeamDataWithRoom
  getAvailableTeams
  checkRequiredUnits
  getCountryRepairInfo
  getMembersTeamsData
  getMembersInfo
}
