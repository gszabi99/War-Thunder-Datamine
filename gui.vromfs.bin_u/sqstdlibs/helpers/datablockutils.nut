local {isArray, isTable, isDataBlock, isInstance, isEqual, isFunction} = require("u.nut")
local { DataBlock } = require("datablockWrapper.nut")

//Recursive translator to DataBlock data.
//More conviniet to store, search and use data in DataBlock.
// It saves order of items in tables as an array,
// and block can easily be found by header as in table.

local function fillBlock(id, block, data, arrayKey = "array") {
  if (isArray(data)) {
    local newBl = id == arrayKey? block.addNewBlock(id) : block.addBlock(id)
    foreach (idx, v in data)
      fillBlock(v?.label ?? arrayKey, newBl, v)
  }
  else if (isTable(data)) {
    local newBl = id == arrayKey? block.addNewBlock(id) : block.addBlock(id)
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


local function get_blk_by_path_array(path, blk, defaultValue = null) {
  local currentBlk = blk
  foreach (p in path) {
    if (!(currentBlk instanceof DataBlock))
      return defaultValue
    currentBlk = currentBlk?[p]
  }
  return currentBlk ?? defaultValue
}

local function get_blk_value_by_path(blk, path, defVal=null) {
  if (!blk || !path)
    return defVal

  local nodes = path.split("/")
  local key = nodes.len() ? nodes.pop() : null
  if (!key || !key.len())
    return defVal

  blk = get_blk_by_path_array(nodes, blk, defVal)
  if (blk == defVal || !isDataBlock(blk))
    return defVal
  local val = blk?[key]
  val = (val!=null && (defVal == null || type(val) == type(defVal))) ? val : defVal
  return val
}

 //blk in path shoud exist and be correct
local function blkFromPath(path){
  local blk = DataBlock()
  blk.load(path)
  return blk
}

//blk in path be correct or should not be existing
local function blkOptFromPath(path) {
  local blk = DataBlock()
  if (path != null && path != ""){
    if (!blk.tryLoad(path, true))
      print($"no file on filePath = {path}, skipping blk load")
  }
  return blk
}

local blkTypes = [ "string", "bool", "float", "integer", "int64", "instance", "null"]

/**
 * Set val to slot, specified by path.
 * Checks for identity before save.
 * If value in specified slot was changed returns true. Otherwise return false.
 */

local function set_blk_value_by_path(blk, path, val) {
  if (!blk || !path)
    return false

  local nodes = path.split("/")
  local key = nodes.len() ? nodes.pop() : null

  if (!key || !key.len())
    return false

  foreach (dir in nodes) {
    if (blk?[dir] != null && type(blk[dir]) != "instance")
      blk[dir] = null
    blk = blk.addBlock(dir)
  }

  //If current value is equal to existent in DataBlock don't override it
  if (isEqual(blk?[key], val))
    return isInstance(val) //If the same instance was changed, then need to save

  //Remove DataBlock slot if it contains an instance or if it has different type
  //from new value
  local destType = type(blk?[key])
  if (destType == "instance")
    blk[key] <- null
  else if (blk?[key] != null && destType != type(val))
    blk[key] = null

  if (blkTypes.contains(type(val)))
    blk[key] = val
  else if (isTable(val)) {
    blk = blk.addBlock(key)
    foreach(k,v in val)
      set_blk_value_by_path(blk, k, v)
  }
  else {
    assert(false, $"Data type not suitable for writing to blk: {type(val)}")
    return false
  }

  return true
}

local function setFuncBlkByArrayPath(blk, path, func){
  assert(isFunction(func))
  if (::type(path) != "array")
    path = [path]
  assert(path.len()>0)
  local valForSet = path[path.len()-1]
  assert(::type(valForSet)=="string")

  local got = blk
  foreach (p in path.slice(-1)){
    assert(::type(p) == "string")
    if (got?[p] != null)
      got = got[p]
    else
      got[p] = DataBlock()
  }
  got[valForSet]=func(got?[valForSet])
  return got
}

local function copyFromDataBlock(fromDataBlock, toDataBlock, override = true) {
  if (!fromDataBlock || !toDataBlock) {
    print("ERROR: copyFromDataBlock: fromDataBlock or toDataBlock doesn't exist")
    return
  }
  for (local i = 0; i < fromDataBlock.blockCount(); i++) {
    local block = fromDataBlock.getBlock(i)
    local blockName = block.getBlockName()
    if (!toDataBlock?[blockName])
      toDataBlock[blockName] <- block
    else if (override)
      toDataBlock[blockName].setFrom(block)
  }
  for (local i = 0; i < fromDataBlock.paramCount(); i++) {
    local paramName = fromDataBlock.getParamName(i)
    if (!toDataBlock?[paramName])
      toDataBlock[paramName] <- fromDataBlock[paramName]
    else if (override)
      toDataBlock[paramName] = fromDataBlock[paramName]
  }
}

return {
  copyFromDataBlock, blkOptFromPath, blkFromPath,
  set_blk_value_by_path, get_blk_value_by_path, get_blk_by_path_array,
  fillBlock, isDataBlock, DataBlock, setFuncBlkByArrayPath
}