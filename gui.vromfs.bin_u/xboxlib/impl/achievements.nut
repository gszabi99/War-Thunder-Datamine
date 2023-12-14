let user = require("xbox.user")
let {subscribe, subscribe_onehit} = require("eventbus")


let function register_update_callback(callback) {
  subscribe(user.achievement_updated_event_name, function(result) {
    callback?(result?.success, result?.id, result?.status)
  })
}


let function synchronize(callback) {
  let eventName = "xbox_achievements_on_synchronize_finish"
  subscribe_onehit(eventName, function(result) {
    callback?(result?.success)
  })
  user.synchronize_achievements(eventName)
}


return {
  synchronize
  register_update_callback

  Status = user.AchievementStatus

  set_progress = user.set_achievement_progress
  set_progress_batch = user.set_achievement_progress_batch
  get_status = user.get_achievement_status

}