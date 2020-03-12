local colors = require("reactiveGui/style/colors.nut")
local hudState = require("reactiveGui/hudState.nut")
local scrollbar = require("scrollbar.nut")
local transition = require("reactiveGui/style/hudTransition.nut")


local logContainer = @() {
  size = [flex(), SIZE_TO_CONTENT]
  gap = ::fpx(3)
  padding = [::scrn_tgt(0.5) , ::scrn_tgt(0.5)]
  flow = FLOW_VERTICAL
}


local hudLog = function (params) {
  local visibleState = params.visibleState
  local messageComponent = params.messageComponent
  local logComponent = params.logComponent
  local onAttach = params?.onAttach ?? @(elem) null
  local onDetach = params?.onDetach ?? @(elem) null

  local logState = logComponent.state
  local content = scrollbar.makeSideScroll(
    logComponent.data(@() logContainer, messageComponent),
    {
      scrollHandler = logComponent.scrollHandler
      barStyle = @(has_scroll) scrollbar.styling.Bar(has_scroll && hudState.cursorVisible.value)
      scrollAlign = ALIGN_LEFT
    }
  )

  local gotNewMessageRecently = function () {
    if (!logState.value.len()) {
      return false
    }
    return logState.value.top().time + transition.slow > ::get_mission_time()
  }

  local transitionTime = function () {
    if (visibleState.value)
      return transition.fast
    return gotNewMessageRecently() ? transition.slow : transition.fast
  }

  local onNewMessage = function (new_val) {
    if (!logState.value.len()) {
      return
    }

    local fadeOutFn = function () { visibleState.update(false) }
    visibleState.update(true)
    ::gui_scene.clearTimer(fadeOutFn)
    ::gui_scene.setTimeout(transition.fast, fadeOutFn)
  }

  return @() {
    rendObj = ROBJ_9RECT
    size = [flex(), ::scrn_tgt(13.5)]
    watch = visibleState
    clipChildren = true
    opacity = visibleState.value ? 1.0 : 0.0
    valign = ALIGN_BOTTOM
    color = colors.hud.hudLogBgColor

    children = content

    onAttach = function (elem) {
      onAttach(elem)
      logState.subscribe(onNewMessage)
    }
    onDetach = function (elem) {
      onDetach(elem)
      logState.unsubscribe(onNewMessage)
    }

    transitions = [transition.make(transitionTime())]
  }
}


return hudLog
