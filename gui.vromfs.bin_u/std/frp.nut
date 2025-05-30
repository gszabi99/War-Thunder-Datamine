from "frp" import Computed, Watched, FRP_INITIAL, FRP_DONT_CHECK_NESTED, set_nested_observable_debug,
  make_all_observables_immutable, recalc_all_computed_values, gather_graph_stats, update_deferred, set_default_deferred



function WatchedImmediate(...) {
  let w = Watched.acall([this].extend(vargv))
  w.setDeferred(false)
  return w
}

function ComputedImmediate(...) {
  let c = Computed.acall([this].extend(vargv))
  c.setDeferred(false)
  return c
}

let isComputed = @(v) type(v)=="instance" && v instanceof Computed
let isWatched = @(v) type(v)=="instance" && v instanceof Watched
let isObservable = @(v) isWatched(v) || isComputed(v)

function watchedTable2TableOfWatched(state, fieldsList = null) {
  assert(isObservable(state), "state has to be Watched")
  let list = fieldsList ?? state.value
  assert(type(list) == "table", "fieldsList should be provided as table")
  return list.map(@(_, key) Computed(@() state.value[key]))
}













function mkLatestByTriggerStream(triggerObservable) {
  return function mkLatestStream(defValue = null, name = null){
    let isTable = type(defValue) == "table"
    local next_value = defValue
    let res = Watched(defValue)
    function updateFunc(...) {
      let oldValue = res.value
      triggerObservable.unsubscribe(updateFunc)
      res.set(next_value)
      if (next_value == oldValue){
        let resType = type(next_value)
        if (resType == "table" || resType == "array"){
          res.trigger()
        }
      }
    }
    res.whiteListMutatorClosure(updateFunc)
    function deleteKey(k){
      if (k in next_value){
        next_value.$rawdelete(k)
        triggerObservable.subscribe(updateFunc)
      }
    }
    function setKeyVal(k, v){
      next_value[k] <- v
      triggerObservable.subscribe(updateFunc)
    }
    function setValue(val){
      next_value = val
      triggerObservable.subscribe(updateFunc)
    }
    function modify(val){
      next_value = val(next_value)
      triggerObservable.subscribe(updateFunc)
    }
    if (name==null) {
      return {state = res, setValue, modify}.__update(isTable ? {setKeyVal, deleteKey } : {})
    }
    return {
      [name] = res, [$"{name}SetValue"] = setValue, [$"{name}Modify"] = modify
    }.__update(isTable ? {[$"{name}SetKeyVal"] = setKeyVal, [$"{name}DeleteKey"] = deleteKey} : {})
  }
}













let TO_DELETE = persist("TO_DELETE", @() freeze({}))
const MK_COMBINED_STATE = true

function mkTriggerableLatestWatchedSetAndStorage(triggerableObservable) {
  return function mkLatestWatchedSetAndStorage(key=null, mkCombined=false) {
    let observableEidsSet = mkCombined ? null : Watched({})
    let state = mkCombined ? Watched({}) : null
    let storage = {}
    let eidToUpdate = {}
    local update
    update = mkCombined == MK_COMBINED_STATE
      ? function (_){
        state?.mutate(function(v) {
          foreach(eid, val in eidToUpdate){
            if (val == TO_DELETE) {
              storage?.$rawdelete(eid)
              v?.$rawdelete(eid)
            }
            else
              v[eid] <- val
          }
        })
        eidToUpdate.clear()
        triggerableObservable.unsubscribe(update)
      }
      : function (_){
        observableEidsSet?.mutate(function(v) {
          foreach(eid, val in eidToUpdate){
            if (val == TO_DELETE) {
              storage?.$rawdelete(eid)
              v?.$rawdelete(eid)
            }
            else
              v[eid] <- eid
          }
        })
        eidToUpdate.clear()
        triggerableObservable.unsubscribe(update)
      }
    let destroyEid = function (eid) {
      if (eid not in storage)
        return
      eidToUpdate[eid] <- TO_DELETE
      triggerableObservable.subscribe(update)
    }
    let updateEidProps = (mkCombined == MK_COMBINED_STATE)
      ? function ( eid, val ) {
          if (eid not in storage || eidToUpdate?[eid] == TO_DELETE) {
            storage[eid] <- Watched(val)
          }
          else {
            storage[eid].update(val)
          }
          eidToUpdate[eid] <- val
          triggerableObservable.subscribe(update)
        }
      : function (eid, val) {
          if (eid not in storage || eidToUpdate?[eid] == TO_DELETE) {
            storage[eid] <- Watched(val)
            eidToUpdate[eid] <- eid
            triggerableObservable.subscribe(update)
          }
          else
            storage[eid].update(val)
        }
    function getWatchedByEid(eid){
      return storage?[eid]
    }
    if (mkCombined == MK_COMBINED_STATE)
      state?.whiteListMutatorClosure(update)
    else
      observableEidsSet?.whiteListMutatorClosure(update)

    if (key==null) {
      return {
        getWatched = getWatchedByEid
        updateEid = updateEidProps
        destroyEid
      }.__update(mkCombined==MK_COMBINED_STATE ? {state} : {set = observableEidsSet})
    }
    else {
      assert(type(key)=="string", @() $"key should be null or string, but got {type(key)}")
      return {
        [$"{key}GetWatched"] = getWatchedByEid,
        [$"{key}UpdateEid"] = updateEidProps,
        [$"{key}DestroyEid"] = destroyEid,
      }.__update(mkCombined==MK_COMBINED_STATE ? {[$"{key}State"] = state} : {[$"{key}Set"] = observableEidsSet})
    }
  }
}

function emptyMutatorDummy() {}

function WatchedRo(val) {
  let w = Watched(val)
  w.whiteListMutatorClosure(emptyMutatorDummy)
  return w
}


function getWatcheds(func) {
  assert(type(func) == "function")
  let num = func.getfuncinfos().freevars
  let res = []
  for (local i=0; i< num; i++) {
    let var = func.getfreevar(i).value
    if ( var instanceof Watched )
      res.append(var)
  }
  return res
}

return {
  mkLatestByTriggerStream
  mkTriggerableLatestWatchedSetAndStorage
  watchedTable2TableOfWatched
  MK_COMBINED_STATE
  Computed
  ComputedImmediate
  Watched
  WatchedImmediate
  FRP_INITIAL
  FRP_DONT_CHECK_NESTED
  set_nested_observable_debug
  make_all_observables_immutable
  recalc_all_computed_values
  gather_graph_stats
  update_deferred
  set_default_deferred
  WatchedRo
  isObservable
  isComputed
  isWatched
  getWatcheds
}
