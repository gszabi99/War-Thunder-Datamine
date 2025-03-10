





let DataBlock = require("DataBlock")
let dagorMath = require("dagor.math")
let underscore = require("%sqstd/underscore.nut")
let functools = require("%sqstd/functools.nut")
let {isTable, isArray, isDataBlock } = underscore
let { dynamic_content } = require("%sqstd/analyzer.nut")

let rnd = require_optional("dagor.random")?.rnd
  ?? require("math")?.rand
  ?? function() {
       throw("no math library exist")
     }





function mapAdvanced(list, iteratee) {
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




function keys(data) {
  if (type(data) == "array"){
    let res = array(data.len())
    foreach (i, _k in res)
      res[i]=i
    return res
  }
  return data.keys()
}




function values(data) {
  if (type(data) == "array")
    return clone data
  return data.values()
}





let customIsEqual = {}
let customIsEmpty = {}


function registerIsEqual(classRef, isEqualFunc){
  customIsEqual[classRef] <- isEqualFunc
}







function isEmpty(val) {
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




function registerClass(className, classRef, isEqualFunc = null, isEmptyFunc = null) {
  let funcName = $"is{className.slice(0, 1).toupper()}{className.slice(1)}"
  this[funcName] <- @(value) type(value) == "instance" && (value instanceof classRef)

  if (isEqualFunc != null)
    registerIsEqual(classRef, isEqualFunc)
  if (isEmptyFunc != null)
    customIsEmpty[classRef] <- isEmptyFunc
}

let uIsEqual = underscore.isEqual
function isEqual(val1, val2){
  return uIsEqual(val1, val2, customIsEqual)
}




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








function extend(destination, ... ) {
  for (local i = 0; i < vargv.len(); i++)
    foreach (key, val in vargv[i]) {
      local v = val
      if (isArray(val) || isTable(val))
        v = extend(isArray(val) ? [] : {}, val)

      if (isArray(destination))
        destination.append(v) 
      else
        destination[key] <- v
    }

  return destination
}





function copy(obj) {
  if (obj == null)
    return null

  if (isArray(obj) || isTable(obj))
    return extend(isArray(obj) ? [] : {}, obj)

  
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





function removeFrom(data, value) {
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
        data.$rawdelete(key)
        return true
      }
  }
  return false
}





function keysReplace(tbl, keysEqual, deepLevel = -1) {
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







function getMax(arr, iteratee = null) {
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

function getMin(arr, iteratee = null) {
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

function appendOnce(v, arr, skipNull = false, customIsEqualFunc = null) {
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

function shuffle(arr) {
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

function chooseRandomNoRepeat(arr, prevIdx) {
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






function wrapIdxInArrayLen(index, length) {
  return length > 0 ? (((index % length) + length) % length) : -1
}








function search(data, predicate, reverseOrder = false) {
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


function find_in_array(arr, val, def = -1) {
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

  keys
  values
  find_in_array

}, functools)




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

return dynamic_content(export)
