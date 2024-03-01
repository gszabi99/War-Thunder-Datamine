let { ScriptReloaderStorage } = require("%sqStdLibs/scriptReloader/scriptReloaderStorage.nut")

let isInReloading = persist("isInReloading", @() { value = false })
let storagesList = persist("storagesList", @() {})
let loadedScripts = persist("loadedScripts", @() {}) //table only for faster search

function _runScript(scriptPath) {
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

function loadOnce(scriptPath) {
  if (scriptPath in loadedScripts)
    return false
  return _runScript(scriptPath)
}


//all persistent data will restore after reload script on call this function
//storageId - uniq id where to save storage. you can use here handler or file name to avoid same id from other structures
//context - structure to save/load data from
//paramsArray - array of params id to take/set to current context
function registerPersistentData(storageId, context, paramsArray) {
  if (storageId in storagesList)
    storagesList[storageId].switchToNewContext(context, paramsArray)
  else
    storagesList[storageId] <- ScriptReloaderStorage(context, paramsArray)
}

function saveAllDataToStorages() {
  foreach(storage in storagesList)
    storage.saveDataToStorage()
}

function reload(scriptPathOrStartFunc) {
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
  registerPersistentData
  reload
  isInReloading = @() isInReloading.value
}