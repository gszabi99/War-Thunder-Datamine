from "%scripts/dagui_library.nut" import *

let { get_time_msec } = require("dagor.time")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock = require("DataBlock")
let { addTask } = require("%scripts/tasker.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { updateEntitlementsLimited } = require("%scripts/onlineShop/entitlementsUpdate.nut")

let class ConfigBase {
  
  id = ""
  isActual = null 
  requestUpdate = null  
  getImpl = null 
  cbName = "ConfigUpdate"
  onConfigUpdate = null 
  needScriptedCache = false

  requestDelayMsec = 60000

  
  requestTimeoutMsec = 15000
  lastRequestTime = -1000000
  lastUpdateTime = -1000000
  cbList = null
  errorCbList = null
  cache = null

  constructor(params) {
    foreach (key, value in params)
      if (key in this)
        this[key] = value

    if (!this.isActual)
      this.isActual = function() { return true }
    if (!this.requestUpdate)
      this.requestUpdate = function() { return -1 }
    if (!this.getImpl) {
      assert(false, $"Configs: Not exist 'get' function in config {this.id}")
      this.getImpl = function() { return DataBlock() }
    }
    this.cbList = []
    this.errorCbList = []
  }

  function get() {
    this.checkUpdate()
    if (this.needScriptedCache) {
      if (!this.cache)
        this.cache = this.getImpl()
      return this.cache
    }
    return this.getImpl()
  }

  function checkUpdate(cb = null, onErrorCb = null, showProgressBox = false, fireCbWhenNoRequest = true) {
    if (this.isActual()) {
      if (fireCbWhenNoRequest)
        cb?()
      return true
    }

    this.update(cb, onErrorCb, showProgressBox)
    return false
  }

  function addCbToList(cb, onErrorCb) {
    if (cb)
      this.cbList.append(cb)
    if (onErrorCb)
      this.errorCbList.append(onErrorCb)
  }

  function isRequestInProgress() {
    return this.lastRequestTime > this.lastUpdateTime
        && this.lastRequestTime + this.requestTimeoutMsec > get_time_msec()
  }

  function canRequest(forceUpdate = false) {
    return (!this.isRequestInProgress() && isInMenu.get()
           && (forceUpdate || this.lastRequestTime + this.requestDelayMsec < get_time_msec()))
  }

  function onUpdateComplete() {
    this.invalidateCache()
    this.onConfigUpdate?()

    broadcastEvent(this.cbName)

    foreach (cb in this.cbList)
      cb()
    this.cbList.clear()
    this.errorCbList.clear()

    this.lastUpdateTime = get_time_msec()
  }

  function onUpdateError(errCode) {
    foreach (cb in this.errorCbList)
      cb(errCode)
    this.cbList.clear()
    this.errorCbList.clear()
  }

  function update(cb = null, onErrorCb = null, showProgressBox = false, forceUpdate = false) {
    if (!this.canRequest(forceUpdate)) {
      if (this.isRequestInProgress())
        this.addCbToList(cb, onErrorCb)
      else
        onErrorCb?( - 2)
      return
    }

    let taskId = this.requestUpdate()
    if (taskId == -1) {
      updateEntitlementsLimited() 
      onErrorCb?( - 2)
      return
    }

    log($"Configs: request config update {this.id}. isActual = {this.isActual()}")
    this.lastRequestTime = get_time_msec()
    this.addCbToList(cb, onErrorCb)
    let successCb = Callback(this.onUpdateComplete, this)
    let errorCb = Callback(this.onUpdateError, this)
    addTask(taskId, { showProgressBox }, successCb, errorCb)
  }

  function invalidateCache() {
    this.cache = null
  }
}

return ConfigBase