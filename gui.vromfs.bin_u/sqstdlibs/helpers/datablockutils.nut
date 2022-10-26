#no-root-fallback
#explicit-this

let {isTable, isDataBlock, isInstance, isEqual} = require("u.nut")
local {  getBlkByPathArray,
  getBlkValueByPath,
  setFuncBlkByArrayPath
} = require("%sqstd/datablock.nut")
let { DataBlock } = require("datablockWrapper.nut")

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


local function setBlkValueByPath(blk, path, val) {
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
    blk.removeBlock(key)
  else if (blk?[key] != null && destType != type(val))
    blk[key] = null

  if (blkTypes.contains(type(val)))
    blk[key] = val
  else if (isTable(val)) {
    blk = blk.addBlock(key)
    foreach(k,v in val)
      setBlkValueByPath(blk, k, v)
  }
  else {
    assert(false, $"Data type not suitable for writing to blk: {type(val)}")
    return false
  }

  return true
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
    if (toDataBlock?[paramName] == null)
      toDataBlock[paramName] <- fromDataBlock[paramName]
    else if (override)
      toDataBlock[paramName] = fromDataBlock[paramName]
  }
}

return {
  copyFromDataBlock, blkOptFromPath, blkFromPath,
  set_blk_value_by_path = setBlkValueByPath,
  get_blk_value_by_path = getBlkValueByPath,
  get_blk_by_path_array = getBlkByPathArray,
  isDataBlock,
  DataBlock,
  setFuncBlkByArrayPath
}