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

::can_be_readed_as_datablock <- function can_be_readed_as_datablock(blk)
{
  return (typeof(blk) == "instance"
          && (blk instanceof ::DataBlock || blk instanceof ::DataBlockAdapter))
}

class DataBlockAdapter
{
  ___originData___ = null

  ___blockName___ = null
  ___blocksList___ = null
  ___paramsList___ = null
  ___paramsListNames___ = null

  constructor(tbl, name = null)
  {
    ___blockName___ = name
    ___originData___ = tbl
  }

  function getBlockName()
  {
    return ___blockName___
  }

  function ___checkReturn___(val, key)
  {
    if (typeof(val) == "table")
      return ::DataBlockAdapter(val, key)
    if (typeof(val) == "array")
      return ___checkReturn___(val[0], key)
    return val
  }

  function _nexti(prevKey)
  {
    local isFound = prevKey == null
    foreach (key, val in ___originData___)
    {
      if (isFound)
        return key
      isFound = prevKey == key
    }
    return null
  }

  function _get(key)
  {
    if (!(key in ___originData___))
      throw null
    return ___checkReturn___(___originData___[key], key)
  }

  function _modulo(key)
  {
    local res = []
    if (!(key in ___originData___))
      return res

    local valList = ___originData___[key]
    if (typeof(valList) != "array")
    {
      res.append(___checkReturn___(valList, key))
      return res
    }

    foreach(val in valList)
      res.append(___checkReturn___(val, key))
    return res
  }

  function getBlockByName(key)
  {
    if (!(key in ___originData___))
      return null
    local realVal = ___checkReturn___(___originData___[key], key)
    if (!::can_be_readed_as_datablock(realVal))
      return null
    return realVal
  }

  function ___addToParamsList___(val, key)
  {
    local realVal = ___checkReturn___(val, key)
    if (realVal == null)
      return

    if (::can_be_readed_as_datablock(realVal))
    {
      ___blocksList___.append(realVal)
      return
    }
    ___paramsList___.append(realVal)
    ___paramsListNames___.append(key)
  }

  function ___initCountsOnce___()
  {
    if (___paramsList___)
      return

    ___blocksList___ = []
    ___paramsList___ = []
    ___paramsListNames___ = []
    foreach(key, val in ___originData___)
    {
      if (typeof(val) != "array")
      {
        ___addToParamsList___(val, key)
        continue
      }
      foreach(v in val)
        ___addToParamsList___(v, key)
    }
  }

  function blockCount()
  {
    ___initCountsOnce___()
    return ___blocksList___.len()
  }

  function getBlock(i)
  {
    ___initCountsOnce___()
    return ___blocksList___[i]
  }

  function paramCount()
  {
    ___initCountsOnce___()
    return ___paramsList___.len()
  }

  function getParamValue(i)
  {
    ___initCountsOnce___()
    return ___paramsList___[i]
  }

  function getParamName(i)
  {
    ___initCountsOnce___()
    return ___paramsListNames___[i]
  }

  function addBlock(name)
  {
    local val = ::DataBlockAdapter({}, name)
    ___initCountsOnce___()
    ___blocksList___.append(val)
    return val
  }
}
