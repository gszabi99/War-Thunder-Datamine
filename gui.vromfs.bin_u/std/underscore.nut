/*
     underscore.js inspired functional paradigm extensions for squirrel
     library is self contained - no extra dependecies, no any game or app specific dependencies
     ALL functions in this library do not mutate data
*/

/*******************************************************************************
 ******************** functions checks*******************
 ******************************************************************************/

/**
  make common iteratee function
*/
local function mkIteratee(func){
  local infos = func.getfuncinfos()
  local params = infos.parameters.len()-1
  ::assert(params>0 && params<3)
  if (params == 3)
    return func
  else if (params==2)
    return function(value, index, list) {return func.pcall(null, value, index)}
  else
    return function(value, index, list) {return func.pcall(null, value)}
}

/**
  Check for proper iteratee and so on - under construction
*/
local function funcCheckArgsNum(func, numRequired){
  local infos = func.getfuncinfos()
  local plen = infos.parameters.len() - 1
  local deplen = infos.defparams.len()
  local isVargv = infos.varargs > 0
  if (isVargv)
    plen -= 2
  local mandatoryParams = plen - deplen
  if (mandatoryParams > numRequired)
    return false
  if ((mandatoryParams <= numRequired) && (plen >= numRequired))
    return true
  if (mandatoryParams <= numRequired && isVargv)
    return true
  return false
}


/*******************************************************************************
 ******************** Collections handling (array of tables) *******************
 ******************************************************************************/

/*
Split list into two arrays:
one whose elements all satisfy predicate and one whose elements all do not satisfy predicate.
predicate is transformed through iteratee to facilitate shorthand syntaxes.
*/
local function partition(list, predicate){
  local ok = []
  local not_ok = []
  predicate = mkIteratee(predicate)
  foreach(index, value in list){
    if (predicate(value, index, list))
      ok.append(value)
    else
      not_ok.append(value)
  }
  return [ok, not_ok]
}

/*******************************************************************************
 ****************************** Table handling *********************************
 ******************************************************************************/


/**
 * A convenient version of what is perhaps the most common use-case for map: extracting a list of property values.
 local stooges = [{name: 'moe', age: 40}, {name: 'larry', age: 50}, {name: 'curly', age: 60}]
  _.pluck(stooges, "name")
  => ["moe", "larry", "curly"]
  if entry doesnt have property it skipped in return value
 */
local function pluck(list, propertyName){
  return list.map(function(v){
    if (propertyName not in v)
      throw null
    return v[propertyName]
  })
/*  local res = []
  foreach (v in list) {
    if (propertyName in v)
      res.append(v.propertyName)
  }
  return res
*/
}

/**
 * Returns a copy of the table where the keys have become the values and the
 * values the keys. For this to work, all of your table's values should be
 * unique and string serializable.
 */
local function invert(table) {
  local res = {}
  foreach (key, val in table)
    res[val] <- key
  return res
}

/**
 * Create new table which have all keys from both tables (or just first table,
   if addParams=true), and for each key maps value func(tbl1Value, tbl2Value)
 * If value not exist in one of table it will be pushed to func as defValue
 */
local function tablesCombine(tbl1, tbl2, func=null, defValue = null, addParams = true) {
  local res = {}
  if (func == null)
    func = function (val1, val2) {return val2}
  foreach(key, value in tbl1)
    res[key] <- func(value, tbl2?[key] ?? defValue)
  if (!addParams)
    return res
  foreach(key, value in tbl2)
    if (!(key in res))
      res[key] <- func(defValue, value)
  return res
}

local function isEqual(val1, val2, customIsEqual={}){
  if (val1 == val2)
    return true
  local valType = ::type(val1)
  if (valType != ::type(val2))
    return false

  if (valType in customIsEqual)
    return customIsEqual[valType](val1, val2)

  if (valType == "array" || valType=="table") {
    if (val1.len() != val2.len())
      return false
    foreach(key, val in val1) {
      if (!(key in val2))
        return false
      if (!isEqual(val, val2[key], customIsEqual))
        return false
    }
    return true
  }

  if (valType == "instance") {
    foreach(classRef, func in customIsEqual)
      if (val1 instanceof classRef && val2 instanceof classRef)
        return func(val1, val2)
    return false
  }

  return false
}
/*
foreach (k, v in range(-1, -5, -1))
  print($"{v}  ")
print("\n")
// -1  -2  -3  -4
*/
local function range(m, n=null, step=1) {
  local start = n==null ? 0 : m
  local end = n==null ? m : n
  for (local i=start; (end>start) ? i<end : i>end; i+=step)
    yield i
}

local function enumerate(obj) {
  foreach (k, v in obj)
    yield [k, v]
}

/*
print(breakable_reduce(array(10).map(@(_,i) i), function(a,b) {
  if (b<5) return a+b
  throw null
}, 1000))
*/
/*
**reversed_enumerate**

the most common usecase is to delete some indecies in array
Example:
local arr = ["a", "b", "c", "d"]
foreach (pair in reversed_enumerate(arr)) { // unfortunatel we have no destructuring in foreach and functions. And no tuples only
  local [idx, val] = pair
  print($"[{idx}]: {val}\n")
}
// [3]: d
// [2]: c
// [1]: b
// [0]: a
*/
local function reversed_enumerate(obj) {
  assert(::type(obj)=="array", "reversed supported only for arrays")
  local l = obj.len()
  for (local i=l-1; i>=0; --i)
    yield [i, obj[i]]
}

//not recursive isEqual, for simple lists or tables
local function isEqualSimple(list1, list2, compareFunc=null) {
  compareFunc = compareFunc ?? @(a,b) a!=b
  if (list1 == list2)
    return true
  if (::type(list1) != ::type(list2) || list1.len() != list2.len())
    return false
  foreach (val, key in list1) {
    if (key not in list2 || compareFunc(val, list2[key]))
      return false
  }
  return true
}

return {
  invert
  tablesCombine
  isEqual
  isEqualSimple
  funcCheckArgsNum
  partition
  pluck
  range
  enumerate
  reversed_enumerate
}
