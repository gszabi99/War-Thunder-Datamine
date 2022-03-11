
/*
This is table class with controlled access
One can be sure that each deletion and newslot would be logged
Also one can't override slot by newslot operation
There is also no mutation of fields (foo.bar = 2 will cause error)
There is also no information to real table with foreach

But unfortunately there is no way to protect fields of class via direct access instance.__registry__
and there is no way to protect table from rawset
so we create class in function-constructor with the __registry__
this way all is protected from modification


Future improvements:
It is also possible to make typed check access to fields
*/

local {kwarg} = require("functools.nut")
local {tostring_r} = require("string.nut")
local {logerr} = require("dagor.debug")

local function print_(val, separator="\n"){
  print($"{val}{separator}")
}

local function log(...) {
  if (vargv.len()==1)
    print_(tostring_r(vargv[0],{compact=true, maxdeeplevel=4}))
  else
    print_(" ".join(vargv.map(@(v) tostring_r(v,{compact=true, maxdeeplevel=4}))))
}

local function newslot(r, idx, v, logFunc, logerrFunc, id){
  log($"setting '{idx}' in {id}")
  if (idx in r) {
    local stack = getstackinfos(3) //0 is stackinfos, 1 is this function, 2 is class instance
    delete stack.locals["this"]
    logFunc($"ERROR! Field in {id} is already registered")
    logFunc("stack:", stack)
    logerrFunc($"field in {id} is already registered")
  }
  r[idx] <- v
}

local mkGuardedTable = kwarg(function(id = null, logerrFunc = null, logFunc = null, logAccess=null){
  logerrFunc = logerrFunc ?? logerr
  logFunc = logFunc ?? log
  local __registry__ = {}
  id = id ?? "_registry_"

  return class {
    function _get(idx) {// warning disable: -all-paths-return-value
      logAccess?($"Read {idx} in {id}")
      if (idx in __registry__)
        return __registry__[idx]
      throw null
    }

    function _set(idx, val){
      throw $"Can't modify {id}"
    }

    function _newslot(idx, v){
      newslot(__registry__, idx, v, logFunc, logerrFunc, id)
    }

    function _multipleAdd(table){
      foreach(k, v in table)
        newslot(__registry__, k, v, logFunc, logerrFunc, id)
    }

    function _multipleForceAdd(table){
      foreach(k, v in table) {
        logFunc?($"force '{k}' in {id}")
        __registry__[k] <- v
      }
    }

    function _create(idx, v){
      newslot(__registry__, idx, v, logFunc, logerrFunc, id)
    }

    function _forceSet(idx, v){
      logFunc?($"force '{idx}' in {id}")
      __registry__[idx] <- v
    }

    function _delslot(key){
      logFunc?($"delete {key} from {id}")
      if (key in __registry__)
        delete __registry__[key]
    }

  //  function _tostring(){
  //    return $"Registry: {tostring_r(__registry__)}"
  //  }

    function _nexti(previdx){
      local found = false
      foreach (i,v in this.getclass()) {
        if (previdx == null || found)
          return i
        if (previdx==i)
          found=true
      }
      foreach (i, v in __registry__){
        if (previdx == null || found)
          return i
        if (previdx==i)
          found=true
      }
      return null
    }
  }
})

return mkGuardedTable
