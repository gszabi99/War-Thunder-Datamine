/**
 * u is a set of utility functions, trashbin
  it also provide export for underscore.nut for legacy reasons
 */
local { DataBlock } = require("datablockWrapper.nut")
local underscore = require("std/underscore.nut")
local functools = require("std/functools.nut")
local isTable = @(v) typeof(v)=="table"
local isArray = @(v) typeof(v)=="array"
local isString = @(v) typeof(v)=="string"
local isFunction = @(v) typeof(v)=="function"
local isDataBlock = @(v) v instanceof DataBlock

local rootTable = ::getroottable()
local rnd = rootTable?.math?.rnd
  ?? require("math")?.rand
  ?? function() {
       throw("no math library exist")
       return 0
     }

/**
 * Looks through each value in the list, returning an array of all the values
 * that pass a truth test (predicate).
 */
local function filter(list, predicate) {
  local res = []
  foreach (element in list)
    if (predicate(element))
      res.append(element)
  return res
}

/**
 * Produces a new array of values by mapping each value in list through a
 * transformation function (iteratee(value, key, list)).
 */
local function mapAdvanced(list, iteratee) {
  if (typeof(list) == "array") {
    local res = []
    for (local i = 0; i < list.len(); ++i)
      res.append(iteratee(list[i], i, list))
    return res
  }
  if (typeof(list) == "table" || isDataBlock(list)) {
    local res = {}
    foreach (key, val in list)
      res[key] <- iteratee(val, key, list)
    return res
  }
  return []
}

local function map(list, func) {
  return mapAdvanced(list, (@(func) function(val, ...) { return func(val) })(func))
}



/**
 * keys return an array of keys of specified table
 */
local function keys(data) {
  if (typeof data == "array"){
    local res = ::array(data.len())
    foreach (i, k in res)
      res[i]=i
    return res
  }
  return data.keys()
}

/**
 * Return all of the values of the table's properties.
 */
local function values(data) {
  if (typeof data == "array")
    return clone data
  return data.values()
}

/*******************************************************************************
 **************************** Custom Classes register **************************
 ******************************************************************************/

local customIsEqual = {}
local customIsEmpty = {}


local function registerIsEqual(classRef, isEqualFunc){
  customIsEqual[classRef] <- isEqualFunc
}

/**
 * Return true if specified obj (@table, @array, @string, @datablock) is empty
 * for integer: return true for 0, and false for other
 * return true for null
 */

local function isEmpty(val) {
  if (!val)
    return true

  if (["string", "table", "array"].indexof(typeof val) != null)
    return val.len() == 0

  if (typeof(val)=="instance") {
    foreach(classRef, func in customIsEmpty)
      if (val instanceof classRef)
        return func(val)
    return false
  }

  return false
}

/*
  register instance class to work with u.is<className>, u.isEqual,  u.isEmpty
*/
local function registerClass(className, classRef, isEqualFunc = null, isEmptyFunc = null) {
  local funcName = "is" + className.slice(0, 1).toupper() + className.slice(1)
  this[funcName] <- function(value) {
    if (value instanceof classRef)
      return true
    if ("dagor2" in rootTable && className in ::dagor2)
      return value instanceof ::dagor2[className]
    return false
  }

  if (isEqualFunc != null)
    registerIsEqual(classRef, isEqualFunc)
  if (isEmptyFunc != null)
    customIsEmpty[classRef] <- isEmptyFunc
}

local uIsEqual = underscore.isEqual
local function isEqual(val1, val2){
  return uIsEqual(val1, val2, customIsEqual)
}

/*
  try to register standard dagor classes
*/
local dagorClasses = {
  DataBlock = {
    isEmpty = @(val) !val.paramCount() && !val.blockCount()
    isEqual = function(val1, val2) {
      if (val1.paramCount() != val2.paramCount() || val1.blockCount() != val2.blockCount())
        return false

      for (local i = 0; i < val1.paramCount(); i++)
        if (val1.getParamName(i) != val2.getParamName(i) || ! isEqual(val1.getParamValue(i), val2.getParamValue(i)))
          return false
      for (local i = 0; i < val1.blockCount(); i++) {
        local b1 = val1.getBlock(i)
        local b2 = val2.getBlock(i)
        if (b1.getBlockName() != b2.getBlockName() || !isEqual(b1, b2))
          return false
      }
      return true
    }
  }
  Point2 = {
    isEqual = @(val1, val2) val1.x == val2.x && val1.y == val2.y
    isEmpty = @(val) !val.x && !val.y
  }
  IPoint2 = {
    isEqual = @(val1, val2) val1.x == val2.x && val1.y == val2.y
    isEmpty = @(val) !val.x && !val.y
  }
  Point3 = {
    isEqual = @(val1, val2) val1.x == val2.x && val1.y == val2.y && val1.z == val2.z
    isEmpty = @(val) !val.x && !val.y && !val.z
  }
  IPoint3 = {
    isEqual = @(val1, val2) val1.x == val2.x && val1.y == val2.y && val1.z == val2.z
    isEmpty = @(val) !val.x && !val.y && !val.z
  }
  Point4 = {
    isEqual = @(val1, val2) val1.x == val2.x && val1.y == val2.y && val1.z == val2.z && val1.w == val2.w
    isEmpty = @(val) !val.x && !val.y && !val.z && !val.w
  }
  Color4 = {
    isEqual = @(val1, val2) val1.r == val2.r && val1.g == val2.g && val1.b == val2.b && val1.a == val2.a
  }
  Color3 = {
    isEqual = @(val1, val2) val1.r == val2.r && val1.g == val2.g && val1.b == val2.b
  }
  TMatrix = {
    isEqual = function(val1, val2) {
      for (local i = 0; i < 4; i++)
        if (!isEqual(val1[i], val2[i]))
          return false
      return true
    }
  }
}



/**
 * Copy all of the properties in the source objects over to the destination
 * object, and return the destination object. It's in-order, so the last source
 * will override properties of the same name in previous arguments.
 */
local function extend(destination, ... /*sources*/) {
  for (local i = 0; i < vargv.len(); i++)
    foreach (key, val in vargv[i]) {
      local v = val
      if (isArray(val) || isTable(val))
        v = extend(isArray(val) ? [] : {}, val)

      isArray(destination)
        ? destination.append(v) // warning disable: -unwanted-modification
        : destination[key] <- v
    }

  return destination
}

/**
 * Recursevly copy all fields of obj to the new instance of same type and
 * returns it.
 */
local function copy(obj) {
  if (obj == null)
    return null

  if (isArray(obj) || isTable(obj))
    return extend(isArray(obj) ? [] : {}, obj)

  //!!FIX ME: Better to make clone method work with datablocks, or move it to custom methods same as isEqual
  if ("isDataBlock" in this && isDataBlock(obj)) {
    local res = DataBlock()
    res.setFrom(obj)
    local name = obj.getBlockName()
    if (name)
      res.changeBlockName(name)
    return res
  }

  return clone obj
}

/*
  * Find and remove {value} from {data} (table/array) once
  * return true if found
*/
local function removeFrom(data, value) {
  if (isArray(data)) {
    local idx = data.indexof(value)
    if (idx != null) {
      data.remove(idx)
      return true
    }
  }
  else if (isTable(data)) {
    foreach(key, val in data)
      if (val == value) {
        delete data[key]
        return true
      }
  }
  return false
}

/**
 * Create new table which have keys, replaced from keysEqual table.
 * deepLevel param set deep of recursion for replace keys in tbl childs
*/
local function keysReplace(tbl, keysEqual, deepLevel = -1) {
  local res = {}
  local newValue = null
  foreach(key, value in tbl) {
    if (isTable(value) && deepLevel != 0)
      newValue = keysReplace(value, keysEqual, deepLevel - 1)
    else
      newValue = value

    if (key in keysEqual)
      res[keysEqual[key]] <- newValue
    else
      res[key] <- newValue
  }

  return res
}

/**
 * Given a array, and an iteratee function that returns a key for each
 * element in the array (or a property name), returns an object with an index
 * of each item.
 */
local function indexBy(list, iteratee) {
  local res = {}
  if (isString(iteratee)){
    foreach (idx, val in list)
      res[val[iteratee]] <- val
  }
  else if (isFunction(iteratee)){
    foreach (idx, val in list)
      res[iteratee(val, idx, list)] <- val
  }

  return res
}

/*******************************************************************************
 ****************************** Array handling *********************************
 ******************************************************************************/


local function getMax(arr, iteratee = null) {
  local result = null
  if (!arr)
    return result

  if (!iteratee)
    iteratee = @(val) (typeof(val) == "integer" || typeof(val) == "float") ? val : null

  local lastMaxValue = null
  foreach (data in arr) {
    local value = iteratee(data)
    if (lastMaxValue != null && value <= lastMaxValue)
      continue

    lastMaxValue = value
    result = data
  }

  return result
}

local function getMin(arr, iteratee = null) {
  local newIteratee = null
  if (!iteratee)
    newIteratee = @(val) (typeof(val) == "integer" || typeof(val) == "float") ? -val : null
  else {
    newIteratee = function(val) {
      local value = iteratee(val)
      return value != null ? -value : null
    }
  }

  return getMax(arr, newIteratee)
}

local function appendOnce(v, arr, skipNull = false, customIsEqualFunc = null) {
  if(skipNull && v == null)
    return

  if (customIsEqualFunc) {
    foreach (obj in arr)
      if (customIsEqualFunc(obj, v))
        return
  }
  else if (arr.indexof(v) != null)
    return

  arr.append(v)
}

local chooseRandom = @(arr) arr.len() ?
  arr[rnd() % arr.len()] :
  null

local function shuffle(arr) {
  local res = clone arr
  local size = res.len()
  local j
  local v
  for (local i = size - 1; i > 0; i--) {
    j = rnd() % (i + 1)
    v = res[j]
    res[j] = res[i]
    res[i] = v
  }
  return res
}

local function chooseRandomNoRepeat(arr, prevIdx) {
  if (prevIdx < 0)
    return chooseRandom(arr)
  if (!arr.len())
    return null
  if (arr.len() == 1)
    return arr[0]

  local nextIdx = rnd() % (arr.len() - 1)
  if (nextIdx >= prevIdx)
    nextIdx++
  return arr[nextIdx]
}

/**
*  Wraps the @index (any integer number) in the @length of the array.
*  Returns the adjusted index in array range, keeping its offset.
*  In case of zero @length returns -1
*/
local function wrapIdxInArrayLen(index, length) {
  return length > 0 ? (((index % length) + length) % length) : -1
}

/**
 * Looks through each value in the @data, returning the first one that passes
 * a truth test @predicate, or null if no value passes the test. The function
 * returns as soon as it finds an acceptable element, and doesn't traverse
 * the entire data.
 * @reverseOrder work only with arrays.
 */
local function search(data, predicate, reverseOrder = false) {
  if (!reverseOrder || ::type(data) != "array") {
    foreach(value in data)
      if (predicate(value))
        return value
    return null
  }

  for (local i = data.len() - 1; i >= 0; i--)
    if (predicate(data[i]))
      return data[i]
  return null
}


local export = underscore.__merge({
  isTable = isTable
  isArray = isArray
  isFunction = isFunction
  isString = isString
  isDataBlock = isDataBlock
  appendOnce = appendOnce
  chooseRandom = chooseRandom
  chooseRandomNoRepeat = chooseRandomNoRepeat
  wrapIdxInArrayLen = wrapIdxInArrayLen
  shuffle = shuffle
  min = getMin
  max = getMax
  mapAdvanced = mapAdvanced
  indexBy = indexBy
  removeFrom = removeFrom
  extend = extend
  registerClass = registerClass
  registerIsEqual = registerIsEqual
  keysReplace = keysReplace
  copy = copy
  search = search
  isEmpty = isEmpty
  isEqual = isEqual
//obsolete
  map = map
  filter = filter
  keys = keys
  values = values

}, functools)

/**
 * Add type checking functions such as isArray()
 */
local internalTypes = ["integer", "int64", "float", "null",
                      "bool",
                      "class", "instance", "generator",
                      "userdata", "thread", "weakref"]
foreach (typeName in internalTypes) {
  local funcName = "is" + typeName.slice(0, 1).toupper() + typeName.slice(1)
  export[funcName] <- (@(val) @(arg) typeof arg == val)(typeName)
}

foreach (className, config in dagorClasses)
  if (className in rootTable)
    export.registerClass(className, rootTable[className], config?.isEqual, config?.isEmpty)

return export
