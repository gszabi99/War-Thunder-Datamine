let DataBlock = require("DataBlock")
let { isFunction, isDataBlock } = require("underscore.nut")





function fillBlock(id, block, data, arrayKey = "array") {
  if (type(data) == "array") {
    let newBl = id == arrayKey? block.addNewBlock(id) : block.addBlock(id)
    foreach (v in data)
      fillBlock(v?.label ?? arrayKey, newBl, v)
  }
  else if (type(data) == "table") {
    let newBl = id == arrayKey? block.addNewBlock(id) : block.addBlock(id)
    foreach (key, val in data)
      fillBlock(key, newBl, val)
  }
  else {
    if (id == arrayKey)
      block[id] <- data
    else
      block[id] = data
  }
}


function eachBlock(db, callback, thisArg = null) {
  if (db == null)
    return

  assert(isDataBlock(db))
  assert(isFunction(callback))
  let numArgs = callback.getfuncinfos().parameters.len() - 1
  assert(numArgs >= 1 && numArgs <= 3)

  let l = db.blockCount()
  for (local i = 0; i < l; i++) {
    let b = db.getBlock(i)
    if (numArgs == 1)
      callback.call(thisArg, b)
    else if (numArgs == 2)
      callback.call(thisArg, b, b.getBlockName())
    else
      callback.call(thisArg, b, b.getBlockName(), i)
  }
}


function eachParam(db, callback, thisArg = null) {
  if (db == null)
    return

  assert(isDataBlock(db))
  assert(isFunction(callback))
  let numArgs = callback.getfuncinfos().parameters.len() - 1
  assert(numArgs >= 1 && numArgs <= 3)

  let l = db.paramCount()
  for (local i = 0; i < l; i++)
    if (numArgs == 2)
      callback.call(thisArg, db.getParamValue(i), db.getParamName(i))
    else if (numArgs == 1)
      callback.call(thisArg, db.getParamValue(i))
    else
      callback.call(thisArg, db.getParamValue(i), db.getParamName(i), i)
}

function copyParamsToTable(db, table = null) {
  table = table ?? {}
  eachParam(db, @(v, n) table[n] <- v)
  return table
}

function blk2SquirrelObjNoArrays(blk){
  let res = {}
  for (local i=0; i<blk.paramCount(); i++){
    let paramName = blk.getParamName(i)
    let paramValue = blk.getParamValue(i)
    if (paramName not in res)
      res[paramName] <- paramValue
  }
  for (local i=0; i<blk.blockCount(); i++){
    let block = blk.getBlock(i)
    let blockName = block.getBlockName()
    if (blockName not in res)
      res[blockName] <- blk2SquirrelObjNoArrays(block)
  }
  return res
}


function blk2SquirrelObj(blk){
  let res = {}
  for (local i=0; i<blk.blockCount(); i++){
    let block = blk.getBlock(i)
    let blockName = block.getBlockName()
    if (blockName not in res)
      res[blockName] <- []
    res[blockName].append(blk2SquirrelObj(block))
  }
  for (local i=0; i<blk.paramCount(); i++){
    let paramName = blk.getParamName(i)
    let paramValue = blk.getParamValue(i)
    if (paramName not in res)
      res[paramName] <- []
    res[paramName].append(paramValue)
  }
  return res
}

local normalizeConvertedBlk
normalizeConvertedBlk = function(obj){
  let t = type(obj)
  if (t == "array" && obj.len()==1) {
    return normalizeConvertedBlk(obj[0])
  }
  else if (t == "table") {
    let r = {}
    foreach(k, v in obj)
      r[k] <- normalizeConvertedBlk(v)
    return r
  }
  else if (t=="array") {
    return obj.map(normalizeConvertedBlk)
  }
  return obj
}

function normalizeAndFlattenConvertedBlk(obj){
  let t = type(obj)
  if (t == "array" && obj.len()==1) {
    let el = obj[0]
    if (type(el)=="table" && el.len()==1){
      foreach(v in el){
        return (type(v)=="array") 
          ? v.map(normalizeAndFlattenConvertedBlk)
          : el.map(normalizeAndFlattenConvertedBlk)
      }
    }
    else
      return normalizeAndFlattenConvertedBlk(el)
  }
  else if (t == "table") {
    let r = {}
    foreach(k, v in obj)
      r[k] <- normalizeConvertedBlk(v)
    return r
  }
  else if (t=="array") {
    return obj.map(normalizeAndFlattenConvertedBlk)
  }
  return obj
}

let convertBlkFlat = @(blk) normalizeAndFlattenConvertedBlk(blk2SquirrelObj(blk))
let convertBlk = @(blk) normalizeConvertedBlk(blk2SquirrelObj(blk))

function getParamsListByName(blk, name){
  let res = []
  for (local j = 0; j < blk.paramCount(); j++) {
    if (blk.getParamName(j)!=name)
      continue
    res.append(blk.getParamValue(j))
  }
  return res
}


function getBlkByPathArray(path, blk, defaultValue = null) {
  local currentBlk = blk
  foreach (p in path) {
    if (!isDataBlock(currentBlk))
      return defaultValue
    currentBlk = currentBlk?[p]
  }
  return currentBlk ?? defaultValue
}

function getBlkValueByPath(blk, path, defVal=null) {
  if (!blk || !path)
    return defVal

  let nodes = path.split("/")
  let key = nodes.len() ? nodes.pop() : null
  if (!key || !key.len())
    return defVal

  blk = getBlkByPathArray(nodes, blk, defVal)
  if (blk == defVal || !isDataBlock(blk))
    return defVal
  local val = blk?[key]
  val = (val!=null && (defVal == null || type(val) == type(defVal))) ? val : defVal
  return val
}

 
function blkFromPath(path){
  local blk = DataBlock()
  blk.load(path)
  return blk
}


function blkOptFromPath(path) {
  local blk = DataBlock()
  if (path != null && path != ""){
    if (!blk.tryLoad(path, true))
      println($"no file on filePath = {path}, skipping blk load")
  }
  return blk
}

return {
  isDataBlock
  blkFromPath
  blkOptFromPath
  fillBlock
  eachBlock
  eachParam
  copyParamsToTable
  getBlkByPathArray
  getBlkValueByPath














  blk2SquirrelObjNoArrays 
  blk2SquirrelObj 
  normalizeConvertedBlk
  normalizeAndFlattenConvertedBlk
  convertBlk 
  convertBlkFlat 

  getParamsListByName
}