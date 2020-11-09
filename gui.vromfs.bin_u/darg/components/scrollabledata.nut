local function make(log_state) {
  local scrollHandler = ::ScrollHandler()
  local scrolledTo = null
  local shouldScroll = false
  return {
    state = log_state
    scrollHandler = scrollHandler
    data = function (container_ctor, message_component) {
      local container = container_ctor()
      return function () {
        local result = (typeof container == "function") ? container() : container
        local messages = log_state.value.map(message_component)
        result.flow <- FLOW_VERTICAL
        result.children <- messages
        result.watch <- log_state
        result.behavior <- Behaviors.RecalcHandler

        local lastLog = log_state.value.len() ? log_state.value.top() : null
        shouldScroll = shouldScroll || lastLog != scrolledTo
        scrolledTo = lastLog

        result.onRecalcLayout <- function(initial) {
          if (!shouldScroll)
            return
          scrollHandler.scrollToY(1e10) //it will clamp by elem size
          shouldScroll = false
        }
        return result
      }
    }
  }
}


return {
  make = make
}
