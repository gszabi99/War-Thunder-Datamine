#no-root-fallback
#explicit-this

/**
 * u is a set of utility functions, trashbin
  it also provide export for underscore.nut for legacy reasons
 */

let DataBlock = require("DataBlock")
let dagorMath = require("dagor.math")
let underscore = require("%sqstd/underscore.nut")
let functools = require("%sqstd/functools.nut")
let {isTable, isArray, isDataBlock } = underscore

let rnd = require_optional("dagor.random")?.rnd
  ?? require("math")?.rand
  ?? function() {
       throw("no math library exist")
     }

/**
 * Looks through each value in the list, returning an array of all the values
 * that pass a truth test (predicate).
 */
let function filter(list, predicate) {
  let res = []
  foreach (element in list)
    if (predicate(element))
      res.append(element)
  return res
}

/**
 * Produces a new array of values by mapping each value in list through a
 * transformation function (iteratee(value, key, list)).
 */
let function mapAdvanced(list, iteratee) {
  let t = type(list)
  if (t == "array") {
    local res = []
    foreach (idx, val in list)
      res.append(iteratee(val, idx, list))
    return res
  }
  if (t == "table" || isDataBlock(list)) {
    let res = {}
    foreach (key, val in list)
      res[key] <- iteratee(val, key, list)
    return res
  }
  return []
}

let function map(list, func) {
  return mapAdvanced(list, (@(func) function(val, ...) { return func(val) })(func))
}



/**
 * keys return an array of keys of specified table
 */
let function keys(data) {
  if (type(data) == "array"){
    let res = array(data.len())
    foreach (i, _k in res)
      res[i]=i
    return res
  }
  return data.keys()
}

/**
 * Return all of the values of the table's properties.
 */
let function values(data) {
  if (type(data) == "array")
    return clone data
  return data.values()
}

/*******************************************************************************
 **************************** Custom Classes register **************************
 ******************************************************************************/

let customIsEqual = {}
let customIsEmpty = {}


let function registerIsEqual(classRef, isEqualFunc){
  customIsEqual[classRef] <- isEqualFunc
}

/**
 * Return true if specified obj (@table, @array, @string, @datablock) is empty
 * for integer: return true for 0, and false for other
 * return true for null
 */

let function isEmpty(val) {
  if (!val)
    return true

  if (["string", "table", "array"].indexof(type(val)) != null)
    return val.len() == 0

  if (type(val)=="instance") {
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
let function registerClass(className, classRef, isEqualFunc = null, isEmptyFunc = null) {
  let funcName = $"is{className.slice(0, 1).toupper()}{className.slice(1)}"
  this[funcName] <- @(value) type(value) == "instance" && (value instanceof classRef)

  if (isEqualFunc != null)
    registerIsEqual(classRef, isEqualFunc)
  if (isEmptyFunc != null)
    customIsEmpty[classRef] <- isEmptyFunc
}

let uIsEqual = underscore.isEqual
let function isEqual(val1, val2){
  return uIsEqual(val1, val2, customIsEqual)
}

/*
  try to register standard dagor classes
*/
let dagorClasses = {
  DataBlock = {
    classRef = DataBlock
    isEmpty = @(val) !val.paramCount() && !val.blockCount()
    isEqual = function(val1, val2) {
      if (val1.paramCount() != val2.paramCount() || val1.blockCount() != val2.blockCount())
        return false

      for (local i = 0; i < val1.paramCount(); i++)
        if (val1.getParamName(i) != val2.getParamName(i) || ! isEqual(val1.getParamValue(i), val2.getParamValue(i)))
          return false
      for (local i = 0; i < val1.blockCount(); i++) {
        let b1 = val1.getBlock(i)
        let b2 = val2.getBlock(i)
        if (b1.getBlockName() != b2.getBlockName() || !isEqual(b1, b2))
          return false
      }
      return true
    }
  }
  Point2 = {
    classRef = dagorMath.Point2
    isEqual = @(val1, val2) val1.x == val2.x && val1.y == val2.y
    isEmpty = @(val) !val.x && !val.y
  }
  IPoint2 = {
    classRef = dagorMath.IPoint2
    isEqual = @(val1, val2) val1.x == val2.x && val1.y == val2.y
    isEmpty = @(val) !val.x && !val.y
  }
  Point3 = {
    classRef = dagorMath.Point3
    isEqual = @(val1, val2) val1.x == val2.x && val1.y == val2.y && val1.z == val2.z
    isEmpty = @(val) !val.x && !val.y && !val.z
  }
  IPoint3 = {
    classRef = dagorMath.IPoint3
    isEqual = @(val1, val2) val1.x == val2.x && val1.y == val2.y && val1.z == val2.z
    isEmpty = @(val) !val.x && !val.y && !val.z
  }
  Point4 = {
    classRef = dagorMath.Point4
    isEqual = @(val1, val2) val1.x == val2.x && val1.y == val2.y && val1.z == val2.z && val1.w == val2.w
    isEmpty = @(val) !val.x && !val.y && !val.z && !val.w
  }
  Color4 = {
    classRef = dagorMath.Color4
    isEqual = @(val1, val2) val1.r == val2.r && val1.g == val2.g && val1.b == val2.b && val1.a == val2.a
  }
  Color3 = {
    classRef = dagorMath.Color3
    isEqual = @(val1, val2) val1.r == val2.r && val1.g == val2.g && val1.b == val2.b
  }
  TMatrix = {
    classRef = dagorMath.TMatrix
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
let function extend(destination, ... /*sources*/) {
  for (local i = 0; i < vargv.len(); i++)
    foreach (key, val in vargv[i]) {
      local v = val
      if (isArray(val) || isTable(val))
        v = extend(isArray(val) ? [] : {}, val)

      if (isArray(destination))
        destination.append(v) // warning disable: -unwanted-modification
      else
        destination[key] <- v
    }

  return destination
}

/**
 * Recursevly copy all fields of obj to the new instance of same type and
 * returns it.
 */
let function copy(obj) {
  if (obj == null)
    return null

  if (isArray(obj) || isTable(obj))
    return extend(isArray(obj) ? [] : {}, obj)

  //!!FIX ME: Better to make clone method work with datablocks, or move it to custom methods same as isEqual
  if ("isDataBlock" in this && isDataBlock(obj)) {
    let res = DataBlock()
    res.setFrom(obj)
    let name = obj.getBlockName()
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
let function removeFrom(data, value) {
  if (isArray(data)) {
    let idx = data.indexof(value)
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
let function keysReplace(tbl, keysEqual, deepLevel = -1) {
  let res = {}
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


/*******************************************************************************
 ****************************** Array handling *********************************
 ******************************************************************************/


let function getMax(arr, iteratee = null) {
  local result = null
  if (!arr)
    return result

  if (!iteratee)
    iteratee = @(val) (type(val) == "integer" || type(val) == "float") ? val : null

  local lastMaxValue = null
  foreach (data in arr) {
    let value = iteratee(data)
    if (lastMaxValue != null && value <= lastMaxValue)
      continue

    lastMaxValue = value
    result = data
  }

  return result
}

let function getMin(arr, iteratee = null) {
  local newIteratee = null
  if (!iteratee)
    newIteratee = @(val) (type(val) == "integer" || type(val) == "float") ? -val : null
  else {
    newIteratee = function(val) {
      let value = iteratee(val)
      return value != null ? -value : null
    }
  }

  return getMax(arr, newIteratee)
}

let function appendOnce(v, arr, skipNull = false, customIsEqualFunc = null) {
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

let chooseRandom = @(arr) arr.len() ?
  arr[rnd() % arr.len()] :
  null

let function shuffle(arr) {
  let res = clone arr
  let size = res.len()
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

let function chooseRandomNoRepeat(arr, prevIdx) {
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
let function wrapIdxInArrayLen(index, length) {
  return length > 0 ? (((index % length) + length) % length) : -1
}

/**
 * Looks through each value in the @data, returning the first one that passes
 * a truth test @predicate, or null if no value passes the test. The function
 * returns as soon as it finds an acceptable element, and doesn't traverse
 * the entire data.
 * @reverseOrder work only with arrays.
 */
let function search(data, predicate, reverseOrder = false) {
  if (!reverseOrder || type(data) != "array") {
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


let function find_in_array(arr, val, def = -1) {
  if (type(arr) != "array" && type(arr) != "table")
    return def

  return arr.findindex(@(v) v==val) ?? def
}


local export = underscore.__merge({
  appendOnce
  chooseRandom
  chooseRandomNoRepeat
  wrapIdxInArrayLen
  shuffle
  min = getMin
  max = getMax
  mapAdvanced
  removeFrom
  extend
  registerClass
  registerIsEqual
  keysReplace
  copy
  search
  isEmpty
  isEqual
//obsolete
  map
  filter
  keys
  values
  find_in_array

}, functools)

/**
 * Add type checking functions such as isFloat()
 */
let internalTypes = ["integer", "int64", "float", "null",
                      "bool",
                      "class", "instance", "generator",
                      "userdata", "thread", "weakref"]
foreach (typeName in internalTypes) {
  local funcName = $"is{typeName.slice(0, 1).toupper()}{typeName.slice(1)}"
  export[funcName] <- (@(val) @(arg) type(arg) == val)(typeName)
}

foreach (className, config in dagorClasses)
  if (type(config?.classRef) == "class")
    export.registerClass(className, config.classRef, config?.isEqual, config?.isEmpty)

return export
