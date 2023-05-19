#no-root-fallback
#explicit-this

const PERSISTENT_DATA_PARAMS = "PERSISTENT_DATA_PARAMS"

let { file_exists } = require("dagor.fs")
let { ScriptReloaderStorage } = require("%sqStdLibs/scriptReloader/scriptReloaderStorage.nut")

let g_script_reloader = persist("g_script_reloader", @() {
    USED_SCRIPTS = ["%sqStdLibs/scriptReloader/scriptReloaderStorage.nut"]
    isInReloading = false

    storagesList = {}
    loadedScripts = {} //table only for faster search

    modifyPath = "script_reloader_modify_path" in getroottable()
                   ? getroottable()["script_reloader_modify_path"]
                   : function(path) { return path }

    function _runScript(scriptPath) {
      this.loadedScripts[scriptPath] <- true
      local res = false
      try {
        require(this.modifyPath(scriptPath))
        res = true
      }
      catch (e) {
      }
      assert(res, $"Scripts reloader: failed to load script {scriptPath}")
      return res
    }

    function loadOnce(scriptPath) {
      if (scriptPath in this.loadedScripts)
        return false
      return this._runScript(scriptPath)
    }

    function loadIfExist(scriptPath) {
      if (scriptPath in this.loadedScripts)
        return false
      let isExist = file_exists(scriptPath)
      this.loadedScripts[scriptPath] <- isExist
      if (isExist)
        return this._runScript(scriptPath)
      return false
    }

    //all persistent data will restore after reload script on call this function
    //storageId - uniq id where to save storage. you can use here handler or file name to avoid same id from other structures
    //context - structure to save/load data from
    //paramsArray - array of params id to take/set to current context
    function registerPersistentData(storageId, context, paramsArray) {
      if (storageId in this.storagesList)
        this.storagesList[storageId].switchToNewContext(context, paramsArray)
      else
        this.storagesList[storageId] <- ScriptReloaderStorage(context, paramsArray)
    }

    //structureId - context will be taken from root table by structure id
    //              storageid = structureId
    //ParamsArrayId - will be takenFromContext
    function registerPersistentDataFromRoot(structureId, paramsArrayId = PERSISTENT_DATA_PARAMS) {
      if (!(structureId in getroottable()))
        return assert(false, $"g_script_reloader: not found structure {structureId} in root table to register data")

      local context = getroottable()[structureId]
      if (!(paramsArrayId in context))
        return assert(false, $"g_script_reloader: not found paramsArray {paramsArrayId} in {structureId}")

      this.registerPersistentData(structureId, context, context[paramsArrayId])
    }

    function reload(scriptPathOrStartFunc) {
      this.isInReloading = true
      this.saveAllDataToStorages()
      this.loadedScripts.clear()

      if (type(scriptPathOrStartFunc) == "function")
        scriptPathOrStartFunc()
      else if (type(scriptPathOrStartFunc) == "string")
        this.loadOnce(scriptPathOrStartFunc)
      else
        assert(false, $"Scripts reloader: bad reload param type {scriptPathOrStartFunc}")

      getroottable()?["broadcastEvent"]("ScriptsReloaded")
      this.isInReloading = false
      return "Reload success" //for feedback on console command
    }

    function saveAllDataToStorages() {
      foreach(storage in this.storagesList)
        storage.saveDataToStorage()
    }
  }
)



foreach(scriptPath in g_script_reloader.USED_SCRIPTS)
  g_script_reloader.loadOnce(scriptPath)


return {
  g_script_reloader
  PERSISTENT_DATA_PARAMS
}