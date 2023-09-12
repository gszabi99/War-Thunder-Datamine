//-file:plus-string
from "%scripts/dagui_library.nut" import *


let { get_time_msec } = require("dagor.time")

dagui_propid_add_name_id("_set_aabb_by_object")

::HudTutorialObject <- class {
  obj = null
  showUpTo = 0
  hasAabb = false
  isVisible = true

  aabbFromName = null

  constructor(id, scene) {
    this.refreshObj(id, scene)
  }

  function refreshObj(id, scene) {
    this.obj = scene.findObject(id)
    this.show(this.isVisible)
    this.initAabb()
  }

  function isValid() {
    return checkObj(this.obj)
  }

  function show(value) {
    if (checkObj(this.obj))
      this.obj.show(value)
    this.isVisible = value
  }

  function setTime(timeSec) {
    if (timeSec > 0)
      this.showUpTo = get_time_msec() + 1000 * timeSec
  }

  function getTimeLeft() {
    return 0.001 * (this.showUpTo - get_time_msec())
  }

  function hasTimer() {
    return this.showUpTo > 0
  }

  function isVisibleByTime() {
    return this.isVisible && (!this.hasTimer() || this.showUpTo < get_time_msec())
  }

  function initAabb() {
    if (!this.isValid())
      return

    this.aabbFromName = this.obj?._set_aabb_by_object
    if (this.aabbFromName && !this.aabbFromName.len())
      this.aabbFromName = null
    this.updateAabb()
  }

  function updateAabb() {
    if (!this.aabbFromName || !this.isValid())
      return

    let aabb = ::g_hud_tutorial_elements.getAABB(this.aabbFromName)
    if (!aabb || aabb.size[0] <= 0)
      return

    this.obj.size = aabb.size[0] + ", " + aabb.size[1]
    this.obj.pos = aabb.pos[0] + ", " + aabb.pos[1]
    this.obj.position = "root"
  }
}