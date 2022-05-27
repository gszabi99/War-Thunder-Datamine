global const PERSISTENT_DATA_PARAMS = "PERSISTENT_DATA_PARAMS"

if (!("g_script_reloader" in getroottable()))
  ::g_script_reloader <- {
    USED_SCRIPTS = ["%sqStdLibs/scriptReloader/scriptReloaderStorage.nut"]
    isInReloading = false

    storagesList = {}
    loadedScripts = {} //table only for faster search

    modifyPath = ("script_reloader_modify_path" in getroottable())
                 ? ::script_reloader_modify_path
                 : function(path) { return path }
  }

::g_script_reloader.loadOnce <- function loadOnce(scriptPath)
{
  if (scriptPath in this.loadedScripts)
    return false
  return this._runScript(scriptPath)
}

::g_script_reloader.loadIfExist <- function loadIfExist(scriptPath)
{
  if (scriptPath in this.loadedScripts)
    return false
  local isExist = ::dd_file_exist(scriptPath)
  this.loadedScripts[scriptPath] <- isExist
  if (isExist)
    return this._runScript(scriptPath)
  return false
}

::g_script_reloader._runScript <- function _runScript(scriptPath)
{
  this.loadedScripts[scriptPath] <- true
  local res = false
  try {
    require(this.modifyPath(scriptPath))
    res = true
  } catch (e) {
  }
  ::dagor.assertf(res, "Scripts reloader: failed to load script " + scriptPath)
  return res
}

foreach(scriptPath in ::g_script_reloader.USED_SCRIPTS)
  ::g_script_reloader.loadOnce(scriptPath)

//all persistent data will restore after reload script on call this function
//storageId - uniq id where to save storage. you can use here handler or file name to avoid same id from other structures
//context - structure to save/load data from
//paramsArray - array of params id to take/set to current context
::g_script_reloader.registerPersistentData <- function registerPersistentData(storageId, context, paramsArray)
{
  if (storageId in this.storagesList)
    this.storagesList[storageId].switchToNewContext(context, paramsArray)
  else
    this.storagesList[storageId] <- ::ScriptReloaderStorage(context, paramsArray)
}

//structureId - context will be taken from root table by structure id
//              storageid = structureId
//ParamsArrayId - will be takenFromContext
::g_script_reloader.registerPersistentDataFromRoot <- function registerPersistentDataFromRoot(structureId, paramsArrayId = PERSISTENT_DATA_PARAMS)
{
  if (!(structureId in ::getroottable()))
    return ::dagor.assertf(false, $"g_script_reloader: not found structure {structureId} in root table to register data")

  local context = ::getroottable()[structureId]
  if (!(paramsArrayId in context))
    return ::dagor.assertf(false, $"g_script_reloader: not found paramsArray {paramsArrayId} in {structureId}")

  this.registerPersistentData(structureId, context, context[paramsArrayId])
}

::g_script_reloader.reload <- function reload(scriptPathOrStartFunc) {
  this.isInReloading = true
  this.saveAllDataToStorages()
  this.loadedScripts.clear()

  if (typeof(scriptPathOrStartFunc) == "function")
    scriptPathOrStartFunc()
  else if (typeof(scriptPathOrStartFunc) == "string")
    this.loadOnce(scriptPathOrStartFunc)
  else
    ::dagor.assertf(false, $"Scripts reloader: bad reload param type {scriptPathOrStartFunc}")

  if ("broadcastEvent" in ::getroottable())
    ::broadcastEvent("ScriptsReloaded")
  this.isInReloading = false
  return "Reload success" //for feedbek on console command
}

::g_script_reloader.saveAllDataToStorages <- function saveAllDataToStorages()
{
  foreach(storage in this.storagesList)
    storage.saveDataToStorage()
}