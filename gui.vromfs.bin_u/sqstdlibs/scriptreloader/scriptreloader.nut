#no-root-fallback
#explicit-this

const PERSISTENT_DATA_PARAMS = "PERSISTENT_DATA_PARAMS"

let { file_exists } = require("dagor.fs")
let { ScriptReloaderStorage } = require("%sqStdLibs/scriptReloader/scriptReloaderStorage.nut")

let isInReloading = persist("isInReloading", @() { value = false })
let storagesList = persist("storagesList", @() {})
let loadedScripts = persist("loadedScripts", @() {}) //table only for faster search

let function _runScript(scriptPath) {
  loadedScripts[scriptPath] <- true
  local res = false
  try {
    require(scriptPath)
    res = true
  }
  catch (e) {
  }
  assert(res, $"Scripts reloader: failed to load script {scriptPath}")
  return res
}

let function loadOnce(scriptPath) {
  if (scriptPath in loadedScripts)
    return false
  return _runScript(scriptPath)
}

let function loadIfExist(scriptPath) {
  if (scriptPath in loadedScripts)
    return false
  let isExist = file_exists(scriptPath)
  loadedScripts[scriptPath] <- isExist
  if (isExist)
    return _runScript(scriptPath)
  return false
}

//all persistent data will restore after reload script on call this function
//storageId - uniq id where to save storage. you can use here handler or file name to avoid same id from other structures
//context - structure to save/load data from
//paramsArray - array of params id to take/set to current context
let function registerPersistentData(storageId, context, paramsArray) {
  if (storageId in storagesList)
    storagesList[storageId].switchToNewContext(context, paramsArray)
  else
    storagesList[storageId] <- ScriptReloaderStorage(context, paramsArray)
  }

//structureId - context will be taken from root table by structure id
//              storageid = structureId
//ParamsArrayId - will be takenFromContext
let function registerPersistentDataFromRoot(structureId, paramsArrayId = PERSISTENT_DATA_PARAMS) {
  if (!(structureId in getroottable()))
    return assert(false, $"scriptReloader: not found structure {structureId} in root table to register data")

  local context = getroottable()[structureId]
  if (!(paramsArrayId in context))
    return assert(false, $"scriptReloader: not found paramsArray {paramsArrayId} in {structureId}")

  registerPersistentData(structureId, context, context[paramsArrayId])
}

let function saveAllDataToStorages() {
  foreach(storage in storagesList)
    storage.saveDataToStorage()
}

let function reload(scriptPathOrStartFunc) {
  isInReloading.value = true
  saveAllDataToStorages()
  loadedScripts.clear()

  if (type(scriptPathOrStartFunc) == "function")
    scriptPathOrStartFunc()
  else if (type(scriptPathOrStartFunc) == "string")
    loadOnce(scriptPathOrStartFunc)
  else
    assert(false, $"Scripts reloader: bad reload param type {scriptPathOrStartFunc}")

  require("%sqStdLibs/helpers/subscriptions.nut").broadcastEvent("ScriptsReloaded")//Need this require in function for correct call broadcast event for new loaded scripts
  isInReloading.value = false
  return "Reload success" //for feedback on console command
}

return {
  loadOnce
  loadIfExist
  registerPersistentData
  registerPersistentDataFromRoot
  reload
  isInReloading = @() isInReloading.value
  PERSISTENT_DATA_PARAMS
}