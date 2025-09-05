from "app" import get_config_name

let { is_pc, is_android, is_ios } = require("%sqstd/platform.nut")
let { setBlkValueByPath, getBlkValueByPath, blkOptFromPath } = require("%globalScripts/dataBlockExt.nut")

function getConfigBlkPaths() {
  
  return {
    read  = (is_pc || is_android || is_ios) ? get_config_name() : null
    write = (is_pc) ? get_config_name() : null
  }
}

function getSystemConfigOption(path, defVal = null) {
  let filename = getConfigBlkPaths().read
  if (!filename)
    return defVal
  let blk = blkOptFromPath(filename)
  let val = getBlkValueByPath(blk, path)
  return (val != null) ? val : defVal
}

function setSystemConfigOption(path, val) {
  let filename = getConfigBlkPaths().write
  if (!filename)
    return
  let blk = blkOptFromPath(filename)
  if (setBlkValueByPath(blk, path, val))
    blk.saveToTextFile(filename)
}

return {
  getSystemConfigOption
  setSystemConfigOption
}
