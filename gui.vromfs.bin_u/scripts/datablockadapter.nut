from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { isDataBlock } = require("%sqstd/underscore.nut")

//to use table by DataBlock api
//Only get Data from table, not set.
//
//supported operators:
// _get             ( blk.key,  blk[key] )
// _modulo          ( blk % "key" )
// getBlockByName(key)
// getBlockName
// blockCount
// getBlock(i)
// paramCount
// getParamValue(i)
// getParamName(i)

::DataBlockAdapter <- class
{
  ___originData___ = null

  ___blockName___ = null
  ___blocksList___ = null
  ___paramsList___ = null
  ___paramsListNames___ = null

  constructor(tbl, name = null)
  {
    this.___blockName___ = name
    this.___originData___ = tbl
  }

  function getBlockName()
  {
    return this.___blockName___
  }

  function ___checkReturn___(val, key)
  {
    if (typeof(val) == "table")
      return ::DataBlockAdapter(val, key)
    if (typeof(val) == "array")
      return this.___checkReturn___(val[0], key)
    return val
  }

  function _nexti(prevKey)
  {
    local isFound = prevKey == null
    foreach (key, _val in this.___originData___)
    {
      if (isFound)
        return key
      isFound = prevKey == key
    }
    return null
  }

  function _get(key)
  {
    if (!(key in this.___originData___))
      throw null
    return this.___checkReturn___(this.___originData___[key], key)
  }

  function _modulo(key)
  {
    let res = []
    if (!(key in this.___originData___))
      return res

    let valList = this.___originData___[key]
    if (typeof(valList) != "array")
    {
      res.append(this.___checkReturn___(valList, key))
      return res
    }

    foreach(val in valList)
      res.append(this.___checkReturn___(val, key))
    return res
  }

  function getBlockByName(key)
  {
    if (!(key in this.___originData___))
      return null
    let realVal = this.___checkReturn___(this.___originData___[key], key)
    if (!isDataBlock(realVal))
      return null
    return realVal
  }

  function ___addToParamsList___(val, key)
  {
    let realVal = this.___checkReturn___(val, key)
    if (realVal == null)
      return

    if (isDataBlock(realVal))
    {
      this.___blocksList___.append(realVal)
      return
    }
    this.___paramsList___.append(realVal)
    this.___paramsListNames___.append(key)
  }

  function ___initCountsOnce___()
  {
    if (this.___paramsList___)
      return

    this.___blocksList___ = []
    this.___paramsList___ = []
    this.___paramsListNames___ = []
    foreach(key, val in this.___originData___)
    {
      if (typeof(val) != "array")
      {
        this.___addToParamsList___(val, key)
        continue
      }
      foreach(v in val)
        this.___addToParamsList___(v, key)
    }
  }

  function blockCount()
  {
    this.___initCountsOnce___()
    return this.___blocksList___.len()
  }

  function getBlock(i)
  {
    this.___initCountsOnce___()
    return this.___blocksList___[i]
  }

  function paramCount()
  {
    this.___initCountsOnce___()
    return this.___paramsList___.len()
  }

  function getParamValue(i)
  {
    this.___initCountsOnce___()
    return this.___paramsList___[i]
  }

  function getParamName(i)
  {
    this.___initCountsOnce___()
    return this.___paramsListNames___[i]
  }

  function addBlock(name)
  {
    let val = ::DataBlockAdapter({}, name)
    this.___initCountsOnce___()
    this.___blocksList___.append(val)
    return val
  }

  function formatAsString()
  {
    let res = []
    debugTableData(this.___originData___, {
      recursionLevel = 4,
      showBlockBrackets = true,
      silentMode = true,
      printFn = @(str) res.append(str)
    })
    return "".concat($"{this.getBlockName()} = DataBlockAdapter ", "\n".join(res))
  }
}
