::g_last_nav_wrap <- {
  wrapObj = null
  wrapTime = 0
  wrapDir = ::g_wrap_dir.LEFT

  prevWrappedObjsList = []
  TIME_TO_RESET_RECURSION_LIST = 200

  function setWrapFrom(obj, dir)
  {
    if (!checkWrapRecursion(obj))
    {
      clearWrap()
      return
    }

    wrapObj = obj
    wrapDir = dir
    wrapTime = ::dagor.getCurTime()
    prevWrappedObjsList.append(obj)
  }

  function clearWrap()
  {
    wrapObj = null
  }

  function getWrapObj()
  {
    if (!::check_obj(wrapObj) || wrapTime < ::dagor.getCurTime() - 100)
      return null
    return wrapObj
  }

  function getWrapDir()
  {
    return wrapDir
  }

  function checkWrapRecursion(obj) //return true when all ok (no recursion)
  {
    if (wrapTime < ::dagor.getCurTime() - TIME_TO_RESET_RECURSION_LIST)
    {
      prevWrappedObjsList.clear()
      return true
    }

    foreach(o in prevWrappedObjsList)
      if (::check_obj(o) && o.isEqual(obj))
        return false
    return true
  }
}
