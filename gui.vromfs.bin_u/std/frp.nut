local {Watched} = require("frp")
const FORBID_MUTATE_COMPUTED = true //for debug purposes

local function combinec(obss, func) {
  //this function create and returns observable that is subscribed to list of observables
  // and its value is combination of their values by provided function
  ::assert(["array","table"].indexof(::type(obss))!=null, "frp combine supports only tables and arrays")
  ::assert(::type(func) =="function", "frp combine needs function as second param")
  local infos = func.getfuncinfos()
  local params = infos.parameters.len()-1
  local multiparamfunc = ::type(obss)=="array" && (infos.varargs>0 || (params > 1 && params == obss.len()))
  local curData = obss.map(@(v) v.value)
  local res = multiparamfunc ? Watched(func.pacall([null].extend(curData))) : Watched(func(curData))
  foreach(id, w in obss) {
    local key = id
    local function listener(v) {
      curData[key] = v
      if (multiparamfunc)
        res(func.pacall([null].extend(curData)))
      else
        res(func(curData))
    }
    if (FORBID_MUTATE_COMPUTED)
      res.whiteListMutatorClosure(listener)
    w.subscribe(listener)
  }
  return res
}

local function combinef(func) {
  //this function create and returns observable that is subscribed to list of observables
  //list is calculated from default arguments of function func(val1=Wal1, val2=Wal2){}
  // and its value is combination of their values by provided function
  ::assert(::type(func) =="function", "frp combine needs function as second param")
  local info = func.getfuncinfos()
  local obss = info.defparams
  ::assert((obss.len()==(info.parameters.len()-1)) && info.varargs==0)
  local curData = obss.map(@(v) v.value)
  local res = Watched(func.pacall([null].extend(curData)))
  foreach(id, w in obss) {
    local key = id
    local function listener(v) {
      curData[key] = v
      res(func.pacall([null].extend(curData)))
    }
    if (FORBID_MUTATE_COMPUTED)
      res.whiteListMutatorClosure(listener)
    w.subscribe(listener)
  }
  return res
}
local function combine(obss, func=null){
  ::assert(["array","table","function"].indexof(::type(obss))!=null, "frp combine supports only tables and arrays as first argument and function as second, or function(arg1=Watched,){} as first")
  return (func==null) ? combinef(obss) : combinec(obss, func)
}

local function map(src_observable, func) {
  //creates new computed observable that is func value of source observable
  local obs = Watched(func(src_observable.value))
  local listener = @(v) obs.update(func(v))
  if (FORBID_MUTATE_COMPUTED)
    obs.whiteListMutatorClosure(listener)
  src_observable.subscribe(listener)
  return obs
}

local function invertBool(src_observable) {
  return map(src_observable, @(val) !val)
}

local function reduceAny(list) {
  return list.reduce(@(a, b) a||b)
}

local function reduceAll(list) {
  return list.reduce(@(a, b) a&&b)
}

local function reduceNone(list) {
  return !list.reduce(@(a, b) a||b)
}

local NO_INITIALIZER = {}
local function merge(list, initial_value=NO_INITIALIZER) {
  ::assert(list.len() > 0)
  local res = Watched(initial_value!=NO_INITIALIZER ? initial_value : list[0].value)
  local function listener(val) {
    res(val)
  }

  foreach (input in list) {
    input.subscribe(listener)
    if (FORBID_MUTATE_COMPUTED)
      res.whiteListMutatorClosure(listener)
  }

  return res
}


local function subscribe(list, func){
  foreach(idx, observable in list)
    observable.subscribe(func)
}


return {
  combine = combine
  reduceAny = reduceAny
  reduceNone = reduceNone
  reduceAll = reduceAll
  invertBool = invertBool
  map = map
  merge = merge
  subscribe = subscribe
}
