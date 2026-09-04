from "%sqStdLibs/helpers/u.nut" import isEqual
from "%appGlobals/hud/hudState.nut" import savedRadarFilters, AAComplexRadarFiltersSaveSlotName
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "%appGlobals/login/loginState.nut" import isProfileReceived
from "%sqstd/datablock.nut" import convertBlk
from "%scripts/dagui_library.nut" import *
from "types" import Table

let { saveLocalAccountSettings, loadLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")

const FILTER_SAVE_ID_DEPRICATED = "aaComplexMenuFilters"
const FILTER_SAVE_ID = "savedRadarFilters"
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
    if (!(slot instanceof Table))
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