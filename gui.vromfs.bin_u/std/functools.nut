let abs = @(v) v> 0 ? v.tointeger() : -v.tointeger()
let { logerr } = require("dagor.debug")


let callableTypes = ["function","table","instance"]
function isCallable(v) {
  return callableTypes.indexof(type(v)) != null && (v.getfuncinfos() != null)
}






function partial(func, ...){
  assert(isCallable(func), "partial can be applied only to functions as first arguments")
  let infos = func.getfuncinfos()
  let argsnum = infos.parameters.len()-1
  let isvargved = infos.varargs==1
  let pargs = vargv
  let pargslen = pargs.len()
  if ( (pargslen == argsnum) && !isvargved) {
    return function(){
      return func.acall([null].extend(pargs))
    }
  }
  if ( (pargslen <= argsnum) || isvargved) {
    return function(...){
      return func.acall([null].extend(pargs).extend(vargv))
    }
  }
  assert(false, @() $"function '{infos.name}' cannot be partial with more arguments({pargslen}) that it accepts({argsnum})")
  return func
}








let allowedKwargTypes = { table = true, ["class"] = true, instance = true }
let KWARG_NON_STRICT = persist("KWARG_NON_STRICT", @() freeze({}))
function kwarg(func){
  assert(isCallable(func), "kwarg can be applied only to functions as first arguments")
  let infos = func.getfuncinfos()
  let funcName = infos.name
  let funcargs = infos.parameters.slice(1)
  let defargs = infos.defparams
  let argsnum = funcargs.len()
  let kfuncargs = {}
  let mandatoryparams = []
  let defparamsStartFrom = argsnum-defargs.len()
  foreach (idx, arg in funcargs) {
    if (idx >= defparamsStartFrom) {
      kfuncargs[arg] <- defargs[idx-defparamsStartFrom]
    }
    else{
      kfuncargs[arg] <-null
      mandatoryparams.append(arg)
    }
  }
  return function kwarged(params = kfuncargs, strict_mode = null) {
    if (type(params) not in allowedKwargTypes)
      assert(false, @() $"param of function can be only hashable (table, class, instance), found:'{type(params)}'")
    let nonManP = mandatoryparams.filter(@(p) p not in params)
    if (nonManP.len() > 0)
      assert(false, "not all mandatory parameters provided: {0}".subst(nonManP.len()==1 ? $"'{nonManP[0]}'" : nonManP.reduce(@(a,b) $"{a},'{b}'")))
    if (strict_mode != KWARG_NON_STRICT) {
      foreach (k, _ in params){
        if (k not in kfuncargs)
          logerr($"unknown argument in function {funcName} call: '{k}'")
        
        
      }
    }
    let posarguments = funcargs.map(@(kv) kv in params ? params[kv] : kfuncargs[kv])
    posarguments.insert(0, this)
    return func.acall(posarguments)
  }
}






function kwpartial(func, partparams, ...){
  assert(isCallable(func), "partial can be applied only to functions as first arguments")
  assert(["table", "class","instance"].indexof(type(partparams))!=null, "kwpartial second argument of function can be only hashable (table, class, instance)")
  let infos = func.getfuncinfos()
  let funcargs = infos.parameters.slice(1)

  let argsnum = funcargs.len()
  let posfuncargs = {}
  let partvargs = vargv
  foreach (p, v in partparams){
    let posidx = funcargs.indexof(p)
    if (posidx == null)
      continue
    posfuncargs[posidx] <- v
  }
  return function(...){
    let curargs = partvargs.extend(vargv)
    assert(curargs.len()+posfuncargs.len()>=argsnum, @() $"not enough arguments provided for function '{infos?.name}' to call")
    let finalargs = []
    local provArgIdx = 0
    for (local i=0; i<argsnum; i++) {
      if (i in posfuncargs) {
        finalargs.append(posfuncargs[i])
      }
      else {
        finalargs.append(curargs[provArgIdx])
        provArgIdx++
      }
    }
    return func.acall([this].extend(finalargs))
  }
}




function pipe(...){
  let args = vargv.filter(isCallable)
  assert(args.len() == vargv.len() && args.len()>0, "pipe should be called with functions")
  let finfos = args[0].getfuncinfos()
  let numarg = (finfos.native ? abs(finfos.paramscheck) : finfos.parameters.len()) - 1
  let isvargved = finfos.native ? finfos.paramscheck < -2 : finfos.varargs==1
  assert(numarg==1 || (numarg==0 && isvargved), "pipe cannot be applied to multiargument function or function with no argument")
  return @(x) args.reduce(@(a,b) b(a), x)
}



function compose(...){
  let args = vargv.filter(isCallable)
  assert(args.len() == vargv.len() && args.len()>0, "compose should be called with functions")
  args.reverse()
  let finfos = args[0].getfuncinfos()
  let numarg = (finfos.native ? abs(finfos.paramscheck) : finfos.parameters.len()) - 1
  let isvargved = finfos.native ? finfos.paramscheck < -2 : finfos.varargs==1
  assert(numarg==1 || (numarg==0 && isvargved), "compose cannot be applied to multiargument function or function with no argument")
  return @(x) args.reduce(@(a,b) b(a), x)
}



function tryCatch(tryer, catcher=null){
  return function(...) {
    try{
      return tryer.pacall([null].extend(vargv))
    }
    catch(e)
      return catcher?(e)
   }
}





















function curry(fn) {
  let finfos = fn.getfuncinfos()
  assert(!finfos.native || finfos.paramscheck >= 0, "Cannot curry native function with varargs")
  let arity = (finfos.native ? finfos.paramscheck : finfos.parameters.len())-1

  return function f1(...) {
    let args = vargv
    if (args.len() >= arity) {
      return fn.acall([this].extend(args))
    } else {
      let fone = f1
      return function(...) {
        let moreArgs = vargv
        let newArgs = clone args
        newArgs.extend(moreArgs)
        return fone.acall([this].extend(newArgs))
      }
    }
  }
}














let NullKey = persist("NullKey", @() {})
let Leaf = persist("Leaf", @() {})
let NO_VALUE = persist("NO_VALUE", @() {})
let listOfCaches = persist("listOfCaches", @() [])

function setValInCacheVargved(path, value, cache) {
  local curTbl = cache
  foreach (p in path){
    local pathPart = p ?? NullKey
    if (pathPart not in curTbl)
      curTbl[pathPart] <- {}
    curTbl = curTbl[pathPart]
  }
  curTbl[Leaf] <- value
  return value
}

function getValInCacheVargved(path, cache) {
  local curTbl = cache
  foreach (p in path) {
    let key = p ?? NullKey
    if (key in curTbl)
      curTbl = curTbl[p ?? NullKey]
    else
      return NO_VALUE
  }
  return (Leaf in curTbl) ? curTbl[Leaf] : NO_VALUE
}

function setValInCache(path, value, cache) {
  local curTbl = cache
  let n = path.len()-1
  foreach (idx, p in path){
    local pathPart = p ?? NullKey
    if (idx == n) {
      curTbl[pathPart] <- value
      return value
    }
    if (pathPart not in curTbl)
      curTbl[pathPart] <- {}
    curTbl = curTbl[pathPart]
  }
  return value
}

function getValInCache(path, cache) {
  local curTbl = cache
  foreach (p in path) {
    let key = p ?? NullKey
    if (key in curTbl)
      curTbl = curTbl[p ?? NullKey]
    else
      return NO_VALUE
  }
  return curTbl
}

const DEF_MAX_CACHE_ENTRIES = 10000
function memoize(func, hashfunc = null, cacheExternal=null, maxCacheNum=DEF_MAX_CACHE_ENTRIES) {
  let cache = cacheExternal ?? {}
  listOfCaches.append(cache)
  local simpleCache = null
  local simpleCacheUsed = false
  let {parameters=null, varargs=0, defparams=null} = func.getfuncinfos()
  let isVarargved = (varargs > 0) || ((defparams?.len() ?? 0) > 0)
  let parametersNum = (parameters?.len() ?? 0)-1
  let isOneParam = (parametersNum == 1) && !isVarargved
  let isNoParams = (parametersNum == 0) && !isVarargved
  local cacheValues = 0
  if (type(hashfunc)=="function")
    return function memoizedfuncHash(...){
      let args = [null].extend(vargv)
      let hashKey = hashfunc.acall(args) ?? NullKey
      if (hashKey in cache)
        return cache[hashKey]
      cacheValues+=1
      if (cacheValues > maxCacheNum)
        cache.clear()
      let res = func.acall(args)
      cache[hashKey] <- res
      return res


    }
  else if (isOneParam) {
    return function memoizedfuncOne(v){
      let k = v ?? NullKey
      if (k in cache)
        return cache[k]
      cacheValues+=1
      if (cacheValues > maxCacheNum)
        cache.clear()
      let res = func(v)
      cache[k] <- res
      return res


    }
  }
  else if (hashfunc==1) {
    return function memoizedfunc1(...){
      let key = vargv[0] ?? NullKey
      if (key in cache)
        return cache[key]
      if (vargv.len()>0) {
        cacheValues+=1
        if (cacheValues > maxCacheNum)
          cache.clear()
        let res = func.acall([null].extend(vargv))
        cache[key] <- res
        return res
      }
      if (simpleCacheUsed)
        return simpleCache
      simpleCache = func.acall([null].extend(vargv))
      simpleCacheUsed = true
      return simpleCache










    }
  }
  else if (isNoParams)
    return function memoizedfuncNo() {
      if (simpleCacheUsed)
        return simpleCache
      simpleCache = func()
      simpleCacheUsed = true
      return simpleCache
    }
  else if (hashfunc==0) {
    return function memoizedfunc0(...){
      if (simpleCacheUsed)
        return simpleCache
      simpleCache = func.acall([null].extend(vargv))
      simpleCacheUsed = true
      return simpleCache
    }
  }
  else if (type(hashfunc)=="integer") {
    if (isVarargved) {
      return function memoizedfuncIntV(...){
        let path = vargv.slice(0, hashfunc)
        let cached = getValInCacheVargved(path, cache)
        if (cached != NO_VALUE)
          return cached
        cacheValues+=1
        if (cacheValues > maxCacheNum)
          cache.clear()
        return setValInCacheVargved(path, func.acall([null].extend(vargv)), cache)


      }
    }
    return function memoizedfuncInt(...){
      let path = vargv.slice(0, hashfunc)
      let cached = getValInCache(path, cache)
      if (cached != NO_VALUE)
        return cached
      cacheValues+=1
      if (cacheValues > maxCacheNum)
        cache.clear()
      return setValInCache(path, func.acall([null].extend(vargv)), cache)


    }
  }
  assert(hashfunc == null, "hash function should be null, function or integer of arguments of function")
  if (isVarargved) {
    return function memoizedfuncV(...){
      let cached = getValInCacheVargved(vargv, cache)
      if (cached != NO_VALUE)
        return cached
      cacheValues+=1
      if (cacheValues > maxCacheNum)
        cache.clear()
      return setValInCacheVargved(vargv, func.acall([null].extend(vargv)), cache)


    }
  }
  return function memoizedfunc(...){
    let cached = getValInCache(vargv, cache)
    if (cached != NO_VALUE)
      return cached
    cacheValues+=1
    if (cacheValues > maxCacheNum)
      cache.clear()
    return setValInCache(vargv, func.acall([null].extend(vargv)), cache)


  }
}




function once(func){
  local result
  local called = false
  function memoizedfunc(...){
    if (called)
      return result
    let res = func.acall([null].extend(vargv))
    result = res
    called = true
    return res
  }
  return memoizedfunc
}




function before(count, func){
  local called = 0
  local res
  return function beforeTimes(...){
    if (called >= count)
      return res
    called++
    res = func.acall([null].extend(vargv))
    return res
  }
}




function after(count, func){
  local called = 0
  return function beforeTimes(...){
    if (called < count) {
      called++
      return
    }
    return func.acall([null].extend(vargv))
  }
}











































let combine = @(...) @() vargv.each(@(v) v.call(null))





function mkMemoizedMapSet(func){
  let cache = {}
  listOfCaches.append(cache)
  let funcParams = func.getfuncinfos().parameters.len()-1
  return function memoizedMapSet(set){
    foreach (k, v in set){
      if (k in cache)
        continue
      cache[k] <- funcParams == 1 ? func(k) : func(k, v)
    }
    let toDelete = []
    foreach(k, _ in cache) {
      if (k not in set)
        toDelete.append(k)
    }
    foreach(k in toDelete)
      cache.$rawdelete(k)
    return cache
  }
}


function clearMemoizeCaches(){
  foreach (cache in listOfCaches)
    cache.clear()
}


function setImpl(arr){
  let res = {}
  foreach (i in arr)
    res[i] <- i
  return res
}

function Set(...){
  if (vargv.len()==1 && typeof(vargv[0]) == "array")
    return setImpl(vargv[0])
  return setImpl(vargv)
}

return {
  partial
  pipe
  compose
  kwarg
  KWARG_NON_STRICT
  kwpartial
  curry
  memoize
  isCallable
  once
  before
  after


  combine
  tryCatch
  mkMemoizedMapSet
  clearMemoizeCaches
  Set
}
