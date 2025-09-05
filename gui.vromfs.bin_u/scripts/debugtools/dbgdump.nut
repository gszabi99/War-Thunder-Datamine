from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

let DataBlock  = require("DataBlock")
let { split_by_chars } = require("string")
let datablockConverter = require("%scripts/utils/datablockConverter.nut")













































































let persistent = persist("persistent", @() { backup = null })

function isLoaded() {
  return persistent.backup != null
}

function getOriginal(id) {
  if (persistent.backup && (id in persistent.backup))
    return (persistent.backup[id] != "__destroy") ? persistent.backup[id] : null
  return (id in getroottable()) ? getroottable()[id] : null
}

function getFuncResult(func, a = null) {
  return func.acall([null].extend(a ?? []))
}

function pathGet(env, path, defVal, debug=false) {
  let keys = split_by_chars(path, ".")
  foreach (key in keys)
    if (key in env)
      env = env[key]
    else {
      if (debug)
        print($"[DEBUGDUMP] {path} not found")
      return defVal
    }
  return env
}

function pathSet(env, path, val) {
  let keys = split_by_chars(path, ".")
  let lastIdx = keys.len() - 1
  foreach (idx, key in keys) {
    if (idx == lastIdx || !(key in env))
      env[key] <- idx == lastIdx ? val : {}
    env = env[key]
  }
}

function pathDelete(env, path) {
  let keys = split_by_chars(path, ".")
  let lastIdx = keys.len() - 1
  foreach (idx, key in keys) {
    if (!(key in env))
      return
    if (idx == lastIdx)
      return env.$rawdelete(key) 
    env = env[key]
  }
}

function save(filename, list) {
  let rootTable = getroottable()
  let blk = DataBlock()
  foreach (itemSrc in list) {
    let item = u.isString(itemSrc) ? { id = itemSrc } : itemSrc
    let id = item.id
    let hasValue = ("value" in item)
    let subject = pathGet(rootTable, id, null, !hasValue)
    let isFunction = u.isFunction(subject)
    let args = item?.args ?? []
    local value = (isFunction && !hasValue)
      ? getFuncResult(subject, args)
      : hasValue
        ? item.value
        : subject
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

function unload() {
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


function load(filename) {
  unload()
  persistent.backup = persistent.backup ?? {}

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

function loadFuncs(functions, needUnloadPrev = true) {
  if (needUnloadPrev)
    unload()
  persistent.backup = persistent.backup ?? {}

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
