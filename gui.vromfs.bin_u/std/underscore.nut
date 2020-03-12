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
//  return list.map(@(v) v?[propertyName]).filter(@(v) v!=null) - incorrect when property has null value and slow
  local res = []
  foreach (v in list) {
    if (propertyName in v)
      res.append(v.propertyName)
  }
  return res
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
  if (::type(val1) != ::type(val2))
    return false
  if (::type(val1)=="array" || ::type(val1)=="table") {
    if (val1.len() != val2.len())
      return false
    foreach(key, val in val1) {
      if (!(key in val2))
        return false
      if (!isEqual(val, val2[key]))
        return false
    }
    return true
  }

  if (::type(val1)=="instance") {
    foreach(classRef, func in customIsEqual)
      if (val1 instanceof classRef && val2 instanceof classRef)
        return func(val1, val2)
    return false
  }

  return false
}

return {
  invert = invert
  tablesCombine = tablesCombine
  isEqual = isEqual
  funcCheckArgsNum = funcCheckArgsNum
  partition = partition
  pluck = pluck
}