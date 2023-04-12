let user = require("%xboxLib/impl/user.nut")
let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_ACHIEVEMENTS] ")
let {isEqual} = require("%sqstd/underscore.nut")
let {Watched} = require("frp")

let cachedAchievements = Watched({})
let debugAchievements = Watched(false)


let function on_achievements_list_populated(success, achievements) {
  logX($"populate_achievements_list succeeded: {success}")
  if (!success || !achievements)
    return

  let newAchievements = {}
  foreach(achievement in achievements) {
    newAchievements[achievement.id] <- {
      status = achievement.status
      percents = 0
    }
  }
  if (!isEqual(newAchievements, cachedAchievements.value))
    cachedAchievements(newAchievements)
}


let function populate_achievements_list() {
  user.retrieve_achievements_list(on_achievements_list_populated)
}


let function update_achievements_status(achievements) {
  logX("update_achievements_status")
  foreach(achievement in achievements) {
    let cached = cachedAchievements.value?[achievement.id]
    if (!cached) {
      if (debugAchievements.value)
        logX($"Unknown achievement: {achievement.name}, skipping")
      continue
    }

    if (cached.status != user.AchievementStatus.Achieved && cached.percents != achievement.percents) {
      cached.percents = achievement.percents
      if (cached.percents >= 100)
        cached.status = user.AchievementStatus.Achieved
      if (debugAchievements.value)
        logX($"Updating achievement {achievement.name}: {achievement.percents}")
      user.set_achievement_progress(achievement.id.tostring(), achievement.percents)
    } else {
      if (debugAchievements.value)
        logX($"Achievement <{achievement.name}> has not met requirements: {cached.percents}/{achievement.percents}")
    }
  }
}


return {
  cachedAchievements
  populate_achievements_list
  update_achievements_status
  debug_achievements = @(value) debugAchievements.update(value)
}