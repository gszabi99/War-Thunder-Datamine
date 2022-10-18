from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { get_time_msec } = require("dagor.time")

::dagui_propid.add_name_id("_set_aabb_by_object")

::HudTutorialObject <- class
{
  obj = null
  showUpTo = 0
  hasAabb = false
  isVisible = true

  aabbFromName = null

  constructor(id, scene)
  {
    refreshObj(id, scene)
  }

  function refreshObj(id, scene)
  {
    obj = scene.findObject(id)
    show(isVisible)
    initAabb()
  }

  function isValid()
  {
    return checkObj(obj)
  }

  function show(value)
  {
    if (checkObj(obj))
      obj.show(value)
    isVisible = value
  }

  function setTime(timeSec)
  {
    if (timeSec > 0)
      showUpTo = get_time_msec() + 1000 * timeSec
  }

  function getTimeLeft()
  {
    return 0.001 * (showUpTo - get_time_msec())
  }

  function hasTimer()
  {
    return showUpTo > 0
  }

  function isVisibleByTime()
  {
    return isVisible && (!hasTimer() || showUpTo < get_time_msec())
  }

  function initAabb()
  {
    if (!isValid())
      return

    aabbFromName = obj?._set_aabb_by_object
    if (aabbFromName && !aabbFromName.len())
      aabbFromName = null
    updateAabb()
  }

  function updateAabb()
  {
    if (!aabbFromName || !isValid())
      return

    let aabb = ::g_hud_tutorial_elements.getAABB(aabbFromName)
    if (!aabb || aabb.size[0] <= 0)
      return

    obj.size = aabb.size[0] + ", " + aabb.size[1]
    obj.pos = aabb.pos[0] + ", " + aabb.pos[1]
    obj.position = "root"
  }
}