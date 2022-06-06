::ConfigBase <- class
{
  //main params to set in constructor
  id = ""
  isActual = null // function() { return true }
  requestUpdate = null  //function() { return -1 }
  getImpl = null //function() { return ::DataBlock() }
  cbName = "ConfigUpdate"
  onConfigUpdate = null //function()
  needScriptedCache = false

  requestDelayMsec = 60000

  //other params
  requestTimeoutMsec = 15000
  lastRequestTime = -1000000
  lastUpdateTime = -1000000
  cbList = null
  errorCbList = null
  cache = null

  constructor(params)
  {
    foreach(key, value in params)
      if (key in this)
        this[key] = value

    if (!isActual)
      isActual = function() { return true }
    if (!requestUpdate)
      requestUpdate = function() { return -1 }
    if (!getImpl)
    {
      ::dagor.assertf(false, "Configs: Not exist 'get' function in config " + id)
      getImpl = function() { return ::DataBlock() }
    }
    cbList = []
    errorCbList = []
  }

  function get()
  {
    checkUpdate()
    if (needScriptedCache)
    {
      if (!cache)
        cache = getImpl()
      return cache
    }
    return getImpl()
  }

  function checkUpdate(cb = null, onErrorCb = null, showProgressBox = false, fireCbWhenNoRequest = true)
  {
    if (isActual())
    {
      if (fireCbWhenNoRequest)
        cb?()
      return true
    }

    update(cb, onErrorCb, showProgressBox)
    return false
  }

  function addCbToList(cb, onErrorCb)
  {
    if (cb)
      cbList.append(cb)
    if (onErrorCb)
      errorCbList.append(onErrorCb)
  }

  function isRequestInProgress()
  {
    return lastRequestTime > lastUpdateTime && lastRequestTime + requestTimeoutMsec > ::dagor.getCurTime()
  }

  function canRequest(forceUpdate = false)
  {
    return (!isRequestInProgress() && ::isInMenu()
           && (forceUpdate || lastRequestTime + requestDelayMsec < ::dagor.getCurTime()))
  }

  function onUpdateComplete()
  {
    invalidateCache()
    if (onConfigUpdate)
      onConfigUpdate()

    ::broadcastEvent(cbName)

    foreach(cb in cbList)
      cb()
    cbList.clear()
    errorCbList.clear()

    lastUpdateTime = ::dagor.getCurTime()
  }

  function onUpdateError(errCode)
  {
    foreach(cb in errorCbList)
      cb(errCode)
    cbList.clear()
    errorCbList.clear()
  }

  function update(cb = null, onErrorCb = null, showProgressBox = false, forceUpdate = false)
  {
    if (!canRequest(forceUpdate))
    {
      if (isRequestInProgress())
        addCbToList(cb, onErrorCb)
      else
        onErrorCb?(-2)
      return
    }

    let taskId = requestUpdate()
    if (taskId == -1)
    {
      ::update_entitlements_limited() //code sure that he better know about prices actuality, so need to update profile
      onErrorCb?(-2)
      return
    }

    ::dagor.debug("Configs: request config update " + id + ". isActual = " + isActual())
    lastRequestTime = ::dagor.getCurTime()
    addCbToList(cb, onErrorCb)
    let successCb = ::Callback(onUpdateComplete, this)
    let errorCb = ::Callback(onUpdateError, this)
    ::g_tasker.addTask(taskId, { showProgressBox = showProgressBox }, successCb, errorCb)
  }

  function invalidateCache()
  {
    cache = null
  }
}

return ConfigBase