//checked for plus_string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

let { registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let DataBlock  = require("DataBlock")
let { split_by_chars } = require("string")
/**
 *  dbg_dump is a tool for debugging complex scripts, which have
 *  a lot of different states, which takes a lot of time and
 *  efforts to achieve.
 *  It makes it easy to create and restore environment state
 *  dumps (selected global functions and global variables).
 *  Dumps are stored in BLK files (one file per state), so can be
 *  easily loaded at any time. And can be edited manually, if needed.
 *
 *  API
 *
 *  save(filename, list)
 *    Dumps a list of global functions (args and return values)
 *    and global variables into a BLK dump file.
 *      @param {string} filename - Blk filename for dump. The file
 *        is stored in gameOnline directory.
 *      @param {array}  list - An array of global functions and
 *        global variables to be stored in dump.
 *    Supported 'list' array elements format:
 *      @example "name"
 *      @example { id = "name" }
 *        If "name" is global variable, will store its value to file.
 *        If "name" is global function, will call it, and store
 *        its return value as return value for empty args set.
 *      @example { id = "name", value = anything }
 *        If 'value' is defined, it will be stored as 'id' variable
 *        value (or as 'id' function return value, if 'id' is existing
 *        global function).
 *        No function call will be made if 'value' is defined.
 *        Also, if 'value' is function itself, it will be called without params
 *        to get its return result as 'value'.
 *      @example { id = "name", args = [array, of, args] }
 *        If 'args' is defined and 'id' is function, 'args' will be
 *        stored as (one of possible) function args set.
 *        Function will be called with given 'args' and its return
 *        value will be stored as return value for given args set.
 *      @example { id = "name", args = [array, of, args], value = anything }
 *        Same as above, but without function call, because 'value'
 *        will be stored as return value for given args set.
 *
 *  load(filename, needUnloadPrev)
 *    Applies global functions and global variables from the dump file.
 *    Global variables in environment are replaced by its state from dump.
 *    Global functions in environment are replaced by fake functions,
 *    which acts like this:
 *    If it gets (one of the) exactly same input args set, as stored
 *    in dump, it returns corresponding return value from dump.
 *    Else it calls the original function, and returns what it have returned.
 *      @param {string} filename - Blk file name of saved dump.
 *      @param {bool}   needUnloadPrev (true) - Call unload() before
 *        loading, to revert all environment changes of previuos load() calls.
 *
 *  loadFuncs(functions, needUnloadPrev)
 *    Acts like load(), but loads global functions from the given table.
 *    This method should be used in combination with load(), for overriding some
 *    global functions with custom functions, in cases, when saving those functions
 *    in a dump file is too expensive or impossible.
 *      @param {table} functions - Table of functions, where keys are global function names.
 *      @param {bool}   needUnloadPrev (true) - Same meaning as in load() params.
 *
 *  unload()
 *    Reverts all environment changes made by load() calls, by restoring
 *    the original global functions and global variables.
 *
 *  isLoaded()
 *    Tells if there are environment changes made by load() calls.
 *      @return {bool}
 *
 *  getOriginal(id)
 *    Returns an original (not overridden) value of global function or global variable.
 *    Primarily for getting access to an original functions from within fake functions
 *    loaded via loadFuncs().
 *      @param {string} id - Name of global function or variable.
 *      @return {anything} - The original global function or variable.
 */

let datablockConverter = require("%scripts/utils/datablockConverter.nut")

let persistent = {
  backup = null
}

registerPersistentData("dbgDump", persistent, [ "backup" ])

let function isLoaded() {
  return persistent.backup != null
}

let function getOriginal(id) {
  if (persistent.backup && (id in persistent.backup))
    return (persistent.backup[id] != "__destroy") ? persistent.backup[id] : null
  return (id in getroottable()) ? getroottable()[id] : null
}

let function getFuncResult(func, a = []) {
  return func.acall([null].extend(a))
}

local function pathGet(env, path, defVal) {
  let keys = split_by_chars(path, ".")
  foreach (key in keys)
    if (key in env)
      env = env[key]
    else
      return defVal
  return env
}

local function pathSet(env, path, val) {
  let keys = split_by_chars(path, ".")
  let lastIdx = keys.len() - 1
  foreach (idx, key in keys) {
    if (idx == lastIdx || !(key in env))
      env[key] <- idx == lastIdx ? val : {}
    env = env[key]
  }
}

local function pathDelete(env, path) {
  let keys = split_by_chars(path, ".")
  let lastIdx = keys.len() - 1
  foreach (idx, key in keys) {
    if (!(key in env))
      return
    if (idx == lastIdx)
      return env.$rawdelete(key) //warning disable: -unwanted-modification
    env = env[key]
  }
}

let function save(filename, list) {
  let rootTable = getroottable()
  let blk = DataBlock()
  foreach (itemSrc in list) {
    let item = u.isString(itemSrc) ? { id = itemSrc } : itemSrc
    let id = item.id
    let hasValue = ("value" in item)
    let subject = pathGet(rootTable, id, null)
    let isFunction = u.isFunction(subject)
    let args = item?.args ?? []
    local value = (isFunction && !hasValue) ? getFuncResult(subject, args) :
      hasValue ? item.value :
      subject
    if (u.isFunction(value))
      value = value()
    if (isFunction) {
      let caseBlk = datablockConverter.dataToBlk({ result = value })
      if (args.len())
        caseBlk["args"] <- datablockConverter.dataToBlk(args)
      if (!blk?[id])
        blk[id] <- datablockConverter.dataToBlk({ __function = true })
      blk[id]["case"] <- caseBlk
    }
    else
      blk[id] <- datablockConverter.dataToBlk(value)
  }
  return blk.saveToTextFile(filename)
}

let function unload() {
  if (!isLoaded())
    return false
  let rootTable = getroottable()
  foreach (id, v in persistent.backup) {
    if (v == "__destroy")
      pathDelete(rootTable, id)
    else
      pathSet(rootTable, id, v)
  }
  persistent.backup = null
  return true
}


let function load(filename, needUnloadPrev = true) {
  if (needUnloadPrev)
    unload()
  persistent.backup = persistent.backup || {}

  let rootTable = getroottable()
  let blk = DataBlock()
  if (!blk.tryLoad(filename))
    return false
  for (local b = 0; b < blk.blockCount(); b++) {
    let data = blk.getBlock(b)
    let id = datablockConverter.strToKey(data.getBlockName())
    if (!(id in persistent.backup))
      persistent.backup[id] <- pathGet(rootTable, id, "__destroy")
    if (data?.__function) {
      let cases = []
      foreach (c in (data % "case"))
        cases.append({
          args = datablockConverter.blkToData(c?.args ?? []),
          result = datablockConverter.blkToData(c.result)
        })
      let origFunc = u.isFunction(persistent.backup[id]) ? persistent.backup[id] : null

      pathSet(rootTable, id, function(...) {
        let args = []
        for (local i = 0; i < vargv.len(); i++)
          args.append(vargv[i])
        foreach (c in cases)
          if (u.isEqual(args, c.args))
            return c.result
        return origFunc ? getFuncResult(origFunc, args) : null
      })
    }
    else
      pathSet(rootTable, id, datablockConverter.blkToData(data))
  }
  for (local p = 0; p < blk.paramCount(); p++) {
    let data = blk.getParamValue(p)
    let id = datablockConverter.strToKey(blk.getParamName(p))
    if (!(id in persistent.backup))
      persistent.backup[id] <- pathGet(rootTable, id, "__destroy")
    pathSet(rootTable, id, datablockConverter.blkToData(data))
  }
  return true
}

let function loadFuncs(functions, needUnloadPrev = true) {
  if (needUnloadPrev)
    unload()
  persistent.backup = persistent.backup || {}

  let rootTable = getroottable()
  foreach (id, func in functions) {
    if (!(id in persistent.backup))
      persistent.backup[id] <- pathGet(rootTable, id, "__destroy")
    pathSet(rootTable, id, func)
  }
  return true
}

return {
  save
  load
  loadFuncs
  unload
  isLoaded
  getOriginal
}
