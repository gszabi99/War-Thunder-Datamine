local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")

local isInBattleState = ::Watched(::is_in_flight())

addListenersWithoutEnv({
  LoadingStateChange = @(_) isInBattleState(::is_in_flight())
})

return {
  isInBattleState
}