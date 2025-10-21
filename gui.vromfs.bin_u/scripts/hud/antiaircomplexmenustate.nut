from "%scripts/dagui_library.nut" import *
let { convertBlk } = require("%sqstd/datablock.nut")
let { isEqual } = require("%sqStdLibs/helpers/u.nut")
let { aaComplexMenuFilters } = require("%appGlobals/hud/hudState.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")

let FILTER_SAVE_ID = "aaComplexMenuFilters"
local loadedFiltersData = {}

function loadFiltersData() {
  if (!isProfileReceived.get())
    return

  let filtersBlk = loadLocalAccountSettings(FILTER_SAVE_ID)
  loadedFiltersData = filtersBlk == null ? {} : convertBlk(filtersBlk)
  aaComplexMenuFilters.set(loadedFiltersData)
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

aaComplexMenuFilters.subscribe(saveFiltersData)