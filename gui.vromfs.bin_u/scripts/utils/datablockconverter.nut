//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")
//checked for explicitness
#no-root-fallback
#explicit-this

/**
 *  dataToBlk(data)
 *    Serializes data of any supported type to data type prepared for
 *    writing to DataBlock. Adds some extra metadata for deserialization when needed.
 *    Supports procesing of any combination of squirrel variable types and DataBlock instances.
 *      @param {null|bool|integer|float|string|array|table|DataBlock} data - Data
 *        to be prepared for writing to DataBlock.
 *      @return {bool|integer|float|string|DataBlock} - Data
 *        prepared for writing to DataBlock.
 *
 *  blkToData(blk)
 *    Desrializes data read from DataBlock back to its original data type.
 *    Restores all original data types (arrays, tables, datablocks, etc).
 *      @param {bool|integer|float|string|DataBlock} blk - Data
 *        read from DataBlock. Strips metadata added during serialization.
 *      @return {null|bool|integer|float|string|array|table|DataBlock} -
 *        Data in its original state.
 */
let { isDataBlock } = require("%sqstd/datablock.nut")
let DataBlock = require("DataBlock")
let { startsWith, slice } = require("%sqstd/string.nut")

let keyToStr = function(key) {
  let t = type(key)
  return t == "string" ? key
    : t == "integer"   ? "__int_"   + key
    : t == "float"     ? "__float_" + key
    : t == "bool"      ? "__bool_"  + (key ? 1 : 0)
    : "__unsupported"
}

let strToKey = function(str) {
  return !startsWith(str, "__")   ? str
    : startsWith(str, "__int_")   ? slice(str, 6).tointeger()
    : startsWith(str, "__float_") ? slice(str, 8).tofloat()
    : startsWith(str, "__bool_")  ? slice(str, 7) == "1"
    : "__unsupported"
}

let function dataToBlk(data) {
  let dataType = isDataBlock(data) ? "DataBlock" : type(data)
  switch (dataType) {
    case "null":
      return "__null"
    case "bool":
    case "integer":
    case "float":
    case "string":
      return data
    case "array":
    case "table":
      let blk = DataBlock()
      let isArray = u.isArray(data)
      if (isArray)
        blk.__array <- true
      foreach (key, value in data)
        blk[isArray ? ("array" + key) : keyToStr(key)] = dataToBlk(value)
      return blk
    case "DataBlock":
      let blk = DataBlock()
      blk.setFrom(data)
      blk.__datablock <- true
      return blk
    default:
      return "__unsupported " + toString(data)
  }
}

let function blkToData(blk) {
  if (u.isString(blk) && startsWith(blk, "__unsupported")) {
    return null
  }
  if (!isDataBlock(blk)) {
    return blk == "__null" ? null : blk
  }
  if (blk?.__datablock) {
    let res = DataBlock()
    res.setFrom(blk)
    res.__datablock = null
    return res
  }
  if (blk?.__array) {
    let res = []
    for (local i = 0; i < blk.blockCount() + blk.paramCount() - 1; i++)
      res.append(blkToData(blk["array" + i]))
    return res
  }
  let res = {}
  for (local b = 0; b < blk.blockCount(); b++) {
    let block = blk.getBlock(b)
    res[strToKey(block.getBlockName())] <- blkToData(block)
  }
  for (local p = 0; p < blk.paramCount(); p++)
    res[strToKey(blk.getParamName(p))] <- blkToData(blk.getParamValue(p))
  return res
}

return {
  dataToBlk
  blkToData
  keyToStr
  strToKey
}