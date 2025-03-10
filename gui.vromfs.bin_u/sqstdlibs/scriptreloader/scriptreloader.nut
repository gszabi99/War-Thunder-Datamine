let { ScriptReloaderStorage } = require("%sqStdLibs/scriptReloader/scriptReloaderStorage.nut")

let isInReloading = persist("isInReloading", @() { value = false })
let storagesList = persist("storagesList", @() {})
let loadedScripts = persist("loadedScripts", @() {}) 

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

  require("%sqStdLibs/helpers/subscriptions.nut").broadcastEvent("ScriptsReloaded")
  isInReloading.value = false
  return "Reload success" 
}

return {
  loadOnce
  registerPersistentData
  reload
  isInReloading = @() isInReloading.value
}