local list = ::Watched([])
local flex = ::flex // warning disable: -declared-never-used

local WND_PARAMS = {
  key = null //generate automatically when not set
  children= null
  onClick = null //remove current modal window when not set

  size = flex()
  behavior = Behaviors.Button
  stopMouse = true
  stopHotkeys = true

  animations = [
    { prop=AnimProp.opacity, from=0.0, to=1.0, duration=0.3, play=true, easing=OutCubic }
    { prop=AnimProp.opacity, from=1.0, to=0.0, duration=0.25, playFadeOut=true, easing=OutCubic }
  ]
}

local function remove(key) {
  local idx = list.value.findindex(@(w) w.key == key)
  if (idx == null)
    return false
  list(@(l) l.remove(idx))
  return true
}

local lastWndIdx = 0
local function add(wnd = WND_PARAMS) {
  wnd = WND_PARAMS.__merge(wnd)
  if (wnd.key != null)
    remove(wnd.key)
  else {
    lastWndIdx++
    wnd.key = "modal_wnd_{0}".subst(lastWndIdx)
  }
  wnd.onClick = wnd.onClick ?? @() remove(wnd.key)
  list.update(@(value) value.append(wnd))
}

return {
  list = list
  add = add
  remove = remove

  hideAll = @() list([])

  component = @() {
    watch = list
    size = flex()
    children = list.value
  }
}