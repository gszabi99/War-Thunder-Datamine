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

let radarFilterSaveMigrations = [
  { oldId = "typeIcon", newId = "DefaultModeComposite", convert = function(old) { 
      return {
        JETS        = (old & (1 << 1)) != 0,  HELICOPTERS = (old & (1 << 2)) != 0,
        ROCKETS     = (old & (1 << 3)) != 0,  SMALL       = (old & (1 << 4)) != 0,
        MEDIUM      = (old & (1 << 5)) != 0,  LARGE       = (old & (1 << 6)) != 0,
      }
    }
  },
  { oldId = "ESMModeType", newId = "ESMModeComposite", convert = function(old) { 
      return {
        SHORT_RANGE_SPAA = (old & (1 << 7)) != 0, MEDIUM_RANGE_SPAA = (old & (1 << 8)) != 0,
        LONG_RANGE_SPAA  = (old & (1 << 9)) != 0,
      }
    }
  },
]

function migrateSavedRadarFilters(data) {
  foreach (slot in data) {
    if (type(slot) != "table")
      continue
    foreach (m in radarFilterSaveMigrations)
      if (m.oldId in slot) {
        slot[m.newId] <- m.convert(slot[m.oldId])
        slot.rawdelete(m.oldId)
      }
  }
}

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
  migrateSavedRadarFilters(loadedFiltersData)
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