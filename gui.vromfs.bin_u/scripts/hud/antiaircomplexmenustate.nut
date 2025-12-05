from "%scripts/dagui_library.nut" import *
let { convertBlk } = require("%sqstd/datablock.nut")
let { isEqual } = require("%sqStdLibs/helpers/u.nut")
let { savedRadarFilters, AAComplexRadarFiltersSaveSlotName } = require("%appGlobals/hud/hudState.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")

let FILTER_SAVE_ID_DEPRICATED = "aaComplexMenuFilters"
let FILTER_SAVE_ID = "savedRadarFilters"
local loadedFiltersData = {}

function loadAccountFilters(){
  local filtersBlk = loadLocalAccountSettings(FILTER_SAVE_ID_DEPRICATED) 
  if (filtersBlk != null) {
    let aaFilters = convertBlk(filtersBlk)
    loadedFiltersData[AAComplexRadarFiltersSaveSlotName] <- aaFilters
    saveLocalAccountSettings(FILTER_SAVE_ID_DEPRICATED, null)
    return
  }

  filtersBlk = loadLocalAccountSettings(FILTER_SAVE_ID)
  loadedFiltersData = filtersBlk == null ? {} : convertBlk(filtersBlk)
  return
}

function loadFiltersData() {
  if (!isProfileReceived.get())
    return

  loadAccountFilters()
  savedRadarFilters.set(loadedFiltersData)
}

function saveFiltersData(data) {
  if (isEqual(loadedFiltersData, data))
    return

  loadedFiltersData = clone data
  saveLocalAccountSettings(FILTER_SAVE_ID, loadedFiltersData)
}

addListenersWithoutEnv({
  ProfileReceived = @(_) loadFiltersData()
})

loadFiltersData()

savedRadarFilters.subscribe(saveFiltersData)