local function get_blk_by_path_array(path, blk, defaultValue = null) {
  local currentBlk = blk
  foreach (p in path) {
    if (!(currentBlk instanceof ::DataBlock))
      return defaultValue
    currentBlk = currentBlk?[p]
  }
  return currentBlk ?? defaultValue
}

local function get_blk_value_by_path(blk, path, defVal=null) {
  if (!blk || !path)
    return defVal

  local nodes = ::split(path, "/")
  local key = nodes.len() ? nodes.pop() : null
  if (!key || !key.len())
    return defVal

  blk = get_blk_by_path_array(nodes, blk, defVal)
  if (blk == defVal || !::u.isDataBlock(blk))
    return defVal
  local val = blk?[key]
  val = (val!=null && (defVal == null || type(val) == type(defVal))) ? val : defVal
  return val
}

 //blk in path shoud exist and be correct
local function blkFromPath(path){
  local blk = ::DataBlock()
  blk.load(path)
  return blk
}

//blk in path be correct or should not be existing
local function blkOptFromPath(path) {
  local blk = ::DataBlock()
  if (path != null && path != ""){
    if (!blk.tryLoad(path, true))
      ::dagor.debug($"no file on filePath = {path}, skipping blk load")
  }
  return blk
}

return {
  blkOptFromPath, blkFromPath, get_blk_value_by_path, get_blk_by_path_array
}