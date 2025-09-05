













let isTable = @(v) type(v)=="table"
let isArray = @(v) type(v)=="array"
let isString = @(v) type(v)=="string"
let isFunction = @(v) type(v)=="function"

function isDataBlock(obj) {
  
  if (obj?.paramCount!=null && obj?.blockCount != null)
    return true
  return false
}

let callableTypes = static ["function","table","instance"].totable()
let recursivetypes = static ["table","array","class"].totable()

function isCallable(v) {
  let typ = typeof v
  return typ=="function" || (typ in callableTypes && (v.getfuncinfos() != null))
}

function mkIteratee(func){
  let infos = func.getfuncinfos()
  let params = infos.parameters.len()-1
  assert(params>0 && params<3)
  if (params == 3)
    return func
  else if (params==2)
    return function(value, index, _list) {return func.pcall(null, value, index)}
  else
    return function(value, _index, _list) {return func.pcall(null, value)}
}




function funcCheckArgsNum(func, numRequired){
  let infos = func.getfuncinfos()
  local plen = infos.parameters.len() - 1
  let deplen = infos.defparams.len()
  let isVargv = infos.varargs > 0
  if (isVargv)
    plen -= 2
  let mandatoryParams = plen - deplen
  if (mandatoryParams > numRequired)
    return false
  if ((mandatoryParams <= numRequired) && (plen >= numRequired))
    return true
  if (mandatoryParams <= numRequired && isVargv)
    return true
  return false
}











function partition(list, predicate){
  let ok = []
  let not_ok = []
  predicate = mkIteratee(predicate)
  foreach(index, value in list){
    if (predicate(value, index, list))
      ok.append(value)
    else
      not_ok.append(value)
  }
  return [ok, not_ok]
}













function pluck(list, propertyName){
  return list.map(function(v){
    if (propertyName not in v)
      throw null
    return v[propertyName]
  })







}






function invert(table) {
  let res = {}
  foreach (key, val in table)
    res[val] <- key
  return res
}






function tablesCombine(tbl1, tbl2, func=null, defValue = null, addParams = true) {
  let res = {}
  if (func == null)
    func = function (_val1, val2) {return val2}
  foreach(key, value in tbl1)
    res[key] <- func(value, tbl2?[key] ?? defValue)
  if (!addParams)
    return res
  foreach(key, value in tbl2)
    if (!(key in res))
      res[key] <- func(defValue, value)
  return res
}

function isEqual(val1, val2, customIsEqual={}){
  if (val1 == val2)
    return true
  let valType = type(val1)
  if (valType != type(val2))
    return false

  if (valType in customIsEqual)
    return customIsEqual[valType](val1, val2)

  if (valType in recursivetypes) {
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





function unique(list, hashfunc=null){
  let values = {}
  let res = []
  hashfunc = hashfunc ?? @(v) v
  foreach (v in list){
    let hash = hashfunc(v)
    if (hash in values)
      continue
    values[hash]<-true
    res.append(v)
  }
  return res
}






function range(m, n=null, step=1) {
  let start = n==null ? 0 : m
  let end = n==null ? m : n
  for (local i=start; (end>start) ? i<end : i>end; i+=step) 
    yield i
}


function isEqualSimple(list1, list2, compareFunc=null) {
  compareFunc = compareFunc ?? @(a,b) a!=b
  if (list1 == list2)
    return true
  if (type(list1) != type(list2) || list1.len() != list2.len())
    return false
  foreach (key, val in list1) {
    if (key not in list2 || compareFunc(val, list2[key]))
      return false
  }
  return true
}


function arrayByRows(arr, columns) {
  let res = []
  for(local i = 0; i < arr.len(); i += columns)
    res.append(arr.slice(i, i + columns))
  return res
}





function chunk(list, count) {
  if (count == null || count < 1) return []
  let result = []
  local i = 0
  let length = list.len()
  while (i < length) {
    let n = i + count
    result.append(list.slice(i, n))
    i = n
  }
  return result
}






function indexBy(list, iteratee) {
  let res = {}
  if (isString(iteratee)){
    foreach (val in list)
      res[val[iteratee]] <- val
  }
  else if (isFunction(iteratee)){
    foreach (idx, val in list)
      res[iteratee(val, idx, list)] <- val
  }

  return res
}

function deep_clone(val) {
  if (type(val) not in recursivetypes)
    return val
  return val.map(deep_clone)
}










function deep_update(target, source) {
  if (type(source) not in recursivetypes) {
    target = source
    return target
  }
  if (type(target)!=type(source) || isArray(source)){
    target = deep_clone(source)
    return target
  }
  foreach(k, v in source){
    if (!(k in target)){
      target[k] <- deep_clone(v)
    }
    else if (type(v) not in recursivetypes){
      target[k] = v
    }
    else {
      target[k]=deep_update(target[k], v)
    }
  }
  return target
}


function deep_merge(target, source) {
  let ret = deep_clone(target)
  return deep_update(ret, source)
}

function flatten(list, depth = -1, level=0){
  if (!isArray(list))
    return list
  let res = []
  foreach (i in list){
    if (!isArray(i) || level==depth)
      res.append(i)
    else {
      res.extend(flatten(i, depth, level))
    }
  }
  return res
}


































function do_in_scope(obj, doFn){
  assert(
    (type(obj)=="instance" || type(obj)=="table") &&  "__enter__" in obj && "__exit__" in obj,
    "to support 'do_in_scope' object passed as first argument should implement '__enter__' and '__exit__' methods"
  )
  assert(type(doFn) == "function", "function should be passed as second argument")

  let scope = obj.__enter__()
  let defErr = {}
  local err = defErr
  local res
  try {
    res = doFn(scope)
  }
  catch(e){
    println($"Catch error while doing action {e}")
    err = e
  }
  if (obj.__exit__.getfuncinfos().parameters.len() > 1)
    obj.__exit__(scope)
  else
    obj.__exit__()
  if (err!=defErr)
    throw(err)
  return res
}

function insertGap(list, gap){
  let res = []
  let len = list.len()
  foreach (idx, l in list){
    res.append(l)
    if (idx==len-1)
      break
    res.append(gap)
  }
  return res
}

return freeze({
  invert
  tablesCombine
  isEqual
  isEqualSimple
  prevIfEqual = @(prev, cur) isEqual(cur, prev) ? prev : cur
  funcCheckArgsNum
  partition
  pluck
  range
  do_in_scope
  unique
  arrayByRows
  chunk
  isTable
  isArray
  isString
  isFunction
  isCallable
  isDataBlock
  indexBy
  deep_clone
  deep_update
  deep_merge
  flatten
  insertGap
})
