from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")

enum CREWS_READY_STATUS
{
  HAS_ALLOWED              = 0x0001
  HAS_REQUIRED_AND_ALLOWED = 0x0002

  //mask
  READY                    = 0x0003
}

const CHOSEN_EVENT_MISSIONS_SAVE_ID = "events/chosenMissions/"
const CHOSEN_EVENT_MISSIONS_SAVE_KEY = "mission"

::EventRoomCreationContext <- class
{
  mGameMode = null
  onUnitAvailabilityChanged = null

  misListType = ::g_mislist_type.BASE
  fullMissionsList = null
  chosenMissionsList = null

  curBrRange = null
  curCountries = null

  isAllowCountriesSetsOnly = false

  constructor(sourceMGameMode, onUnitAvailabilityChangedCb = null)
  {
    mGameMode = sourceMGameMode
    isAllowCountriesSetsOnly = mGameMode?.allowCountriesSetsOnly ?? false
    onUnitAvailabilityChanged = onUnitAvailabilityChangedCb
    curCountries = {}
    initMissionsOnce()
  }

  /*************************************************************************************************/
  /*************************************PUBLIC FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function getOptionsList()
  {
    let options = [
      [::USEROPT_CLUSTER],
      [::USEROPT_RANK],
    ]

    if (isAllowCountriesSetsOnly)
      options.append([::USEROPT_COUNTRIES_SET])
    else
      options.append([::USEROPT_BIT_COUNTRIES_TEAM_A],
        [::USEROPT_BIT_COUNTRIES_TEAM_B])

    return options
  }

  _optionsConfig = null
  function getOptionsConfig()
  {
    if (_optionsConfig)
      return _optionsConfig

    _optionsConfig = {
      isEventRoom = true
      brRanges = mGameMode?.matchmaking.mmRanges
      countries = {}
      countriesSetList = []
      onChangeCb = Callback(onOptionChange, this)
    }
    if (isAllowCountriesSetsOnly)
      _optionsConfig.countriesSetList = ::events.getAllCountriesSets(mGameMode)
    else
      foreach(team in ::g_team.getTeams())
        _optionsConfig.countries[team.name] <- mGameMode?[team.name].countries

    return _optionsConfig
  }

  function isAllMissionsSelected()
  {
    return !chosenMissionsList.len() || chosenMissionsList.len() == fullMissionsList.len()
  }

  function createRoom()
  {
    let reasonData = getCantCreateReasonData({ isFullText = true })
    if (!reasonData.checkStatus)
      return reasonData.actionFunc(reasonData)

    ::SessionLobby.createEventRoom(mGameMode, getRoomCreateParams())
  }

  function isUnitAllowed(unit)
  {
    if (!::events.isUnitAllowedForEvent(mGameMode, unit))
      return false

    let brRange = getCurBrRange()
    if (brRange)
    {
      let ediff = ::events.getEDiffByEvent(mGameMode)
      let unitMRank = unit.getEconomicRank(ediff)
      if (unitMRank < getTblValue(0, brRange, 0) || getTblValue(1, brRange, ::max_country_rank) < unitMRank)
        return false
    }

    return isCountryAvailable(unit.shopCountry)
  }

  function isCountryAvailable(country)
  {
    foreach(team in ::g_team.getTeams())
      if (isInArray(country, getCurCountries(team)))
        return true
    return false
  }

  function getCurCrewsReadyStatus()
  {
    local res = 0
    let country = profileCountrySq.value
    let ediff = ::events.getEDiffByEvent(mGameMode)
    foreach (team in ::g_team.getTeams())
    {
      if (!isInArray(country, getCurCountries(team)))
       continue

      let teamData = ::events.getTeamData(mGameMode, team.code)
      let requiredCrafts = ::events.getRequiredCrafts(teamData)
      let crews = ::get_crews_list_by_country(country)
      foreach(crew in crews)
      {
        if (::is_crew_locked_by_prev_battle(crew))
          continue
        let unit = ::g_crew.getCrewUnit(crew)
        if (!unit)
          continue

        if (!isUnitAllowed(unit))
          continue
        res = res | CREWS_READY_STATUS.HAS_ALLOWED

        if (requiredCrafts.len() && !::events.isUnitMatchesRule(unit, requiredCrafts, true, ediff))
          continue
        res = res | CREWS_READY_STATUS.HAS_REQUIRED_AND_ALLOWED

        return res
      }
    }
    return res
  }

  //same format result as ::events.getCantJoinReasonData
  function getCantCreateReasonData(params = null)
  {
    params = params ? clone params : {}
    params.isCreationCheck <- true
    let res = ::events.getCantJoinReasonData(mGameMode, null, params)
    if (res.reasonText.len())
      return res

    if (!isCountryAvailable(profileCountrySq.value))
    {
      res.reasonText = loc("events/no_selected_country")
    }
    else
    {
      let crewsStatus = getCurCrewsReadyStatus()
      if (!(crewsStatus & CREWS_READY_STATUS.HAS_ALLOWED))
        res.reasonText = loc("events/no_allowed_crafts")
      else if (!(crewsStatus & CREWS_READY_STATUS.HAS_REQUIRED_AND_ALLOWED))
        res.reasonText = loc("events/no_required_crafts")
    }

    if (res.reasonText.len())
    {
      res.checkStatus = false
      res.activeJoinButton = false
      if (!res.actionFunc)
        res.actionFunc = function (reasonData)
        {
          ::showInfoMsgBox(reasonData.reasonText, "cant_create_event_room")
        }
    }
    return res
  }

  /*************************************************************************************************/
  /************************************PRIVATE FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function initMissionsOnce()
  {
    chosenMissionsList = []
    fullMissionsList = []

    let missionsTbl = mGameMode?.mission_decl.missions_list
    if (!missionsTbl)
      return

    let missionsNames = ::u.keys(missionsTbl)
    fullMissionsList = misListType.getMissionsListByNames(missionsNames)
    fullMissionsList = misListType.sortMissionsByName(fullMissionsList)
    loadChosenMissions()
  }

  function getMissionsSaveId()
  {
    return CHOSEN_EVENT_MISSIONS_SAVE_ID + ::events.getEventEconomicName(mGameMode)
  }

  function loadChosenMissions()
  {
    chosenMissionsList.clear()
    let blk = ::load_local_account_settings(getMissionsSaveId())
    if (!::u.isDataBlock(blk))
      return

    let chosenNames = blk % CHOSEN_EVENT_MISSIONS_SAVE_KEY
    foreach(mission in fullMissionsList)
      if (isInArray(mission.id, chosenNames))
        chosenMissionsList.append(mission)
  }

  function saveChosenMissions()
  {
    let names = ::u.map(chosenMissionsList, @(m) m.id)
    ::save_local_account_settings(getMissionsSaveId(), ::array_to_blk(names, CHOSEN_EVENT_MISSIONS_SAVE_KEY))
  }

  function setChosenMissions(missions)
  {
    chosenMissionsList = missions
    saveChosenMissions()
  }

  function getCurBrRange()
  {
    if (!getOptionsConfig().brRanges)
      return null
    if (!curBrRange)
      setCurBrRange(::get_option(::USEROPT_RANK, getOptionsConfig()).value)
    return curBrRange
  }

  function setCurBrRange(rangeIdx)
  {
    let brRanges = getOptionsConfig().brRanges
    if (rangeIdx in brRanges)
      curBrRange = brRanges[rangeIdx]
  }

  function getCurCountries(team)
  {
    if (team.id in curCountries)
      return curCountries[team.id]
    if (team.teamCountriesOption < 0)
      return []
    if (isAllowCountriesSetsOnly)
      setCurCountriesArray(team, ::get_gui_option(::USEROPT_COUNTRIES_SET))
    else {
      local curMask = ::get_gui_option(team.teamCountriesOption)
      if (curMask == null)
        curMask = -1
      setCurCountries(team,  curMask)
    }
    return curCountries[team.id]
  }

  function setCurCountries(team, countriesMask)
  {
    curCountries[team.id] <- ::get_array_by_bit_value(countriesMask, shopCountriesList)
  }

  function setCurCountriesArray(team, countriesSetIdx)
  {
    let countriesSet = getOptionsConfig().countriesSetList?[countriesSetIdx].countries
    curCountries[team.id] <- countriesSet?[team.code-1] ?? (clone shopCountriesList)
  }

  function onOptionChange(optionId, optionValue, controlValue)
  {
    if (optionId == ::USEROPT_RANK)
      setCurBrRange(controlValue)
    else if (optionId == ::USEROPT_BIT_COUNTRIES_TEAM_A || optionId == ::USEROPT_BIT_COUNTRIES_TEAM_B)
      setCurCountries(::g_team.getTeamByCountriesOption(optionId), optionValue)
    else if (optionId == ::USEROPT_COUNTRIES_SET)
      foreach(team in [::g_team.A, ::g_team.B])
        setCurCountriesArray(team, optionValue)
    else
      return

    if (onUnitAvailabilityChanged)
      ::get_cur_gui_scene().performDelayed(this, function() { onUnitAvailabilityChanged() })
  }

  function getRoomCreateParams()
  {
    let res = {
      ranks = [1, ::max_country_rank] //matching do nt allow to create session before ranks is set
    }

    foreach(team in ::g_team.getTeams())
      res[team.name] <- {
         countries = getCurCountries(team)
      }

    if (getCurBrRange())
      res.mranks <- getCurBrRange()

    let clusterOpt = ::get_option(::USEROPT_CLUSTER)
    res.cluster <- getTblValue(clusterOpt.value, clusterOpt.values, "")

    if (!isAllMissionsSelected())
      res.missions <- ::u.map(chosenMissionsList, @(m) m.id)

    return res
  }
}