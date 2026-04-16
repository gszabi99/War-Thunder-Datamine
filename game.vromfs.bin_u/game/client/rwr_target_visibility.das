require ecs
require hud
require TwsHud
require app
require DagorSystem

let DIST_SQ_MAX = 0.34 * 0.34

def is_rwr_target_valid(hud : Hud&; idx : int) : bool
  return hud.rwrHudProperties.directionMap |> lookup(hud.rwrTargets[idx].groupId) != int(RwrDirectionMapResult.DIRECTION_HIDDEN)

[es(tag=gameClient, no_order)]
def rwr_target_visibility_update_es(info : UpdateStageInfoAct)
  var hud = get_cur_hud()
  if hud == null
    return

  static_if typeinfo has_field<rwrTargetVisibility>(*hud)
    let targetCount = length(hud.rwrTargets)
    if targetCount == 0 || !hud.rwrTargetVisibility.targetTracking
      return

    let oldShowSize = length(hud.rwrTargetVisibility.targetShow)
    if oldShowSize != targetCount
      hud.rwrTargetVisibility.targetShow |> resize(targetCount)
      for i in range(oldShowSize, targetCount)
        hud.rwrTargetVisibility.targetShow[i] = true

    let curTime = get_sync_time()
    let curTick = int(curTime * 2.0)
    let lastTick = int(hud.rwrTargetVisibility.lastBlinkTime * 2.0)
    if curTick == lastTick
      return
    hud.rwrTargetVisibility.lastBlinkTime = curTime

    for ui in range(length(hud.rwrTargetVisibility.targetsUsed))
      let idx = hud.rwrTargetVisibility.targetsUsed[ui]
      if idx >= 0 && idx < targetCount
        hud.rwrTargetVisibility.targetShow[idx] = false

    let totalTracked = length(hud.rwrTargetVisibility.targetsUsed) + length(hud.rwrTargetVisibility.targetsUnused)
    if totalTracked == 0
      hud.rwrTargetVisibility.targetsUnused |> resize(targetCount)
      for i in range(targetCount)
        hud.rwrTargetVisibility.targetsUnused[i] = i
    elif totalTracked < targetCount
      for i in range(targetCount)
        var found = false
        for j in range(length(hud.rwrTargetVisibility.targetsUnused))
          if hud.rwrTargetVisibility.targetsUnused[j] == i
            found = true
            break
        if !found
          for j in range(length(hud.rwrTargetVisibility.targetsUsed))
            if hud.rwrTargetVisibility.targetsUsed[j] == i
              found = true
              break
        if !found
          hud.rwrTargetVisibility.targetsUnused |> push(i)

    var free : array<int>
    free |> resize(length(hud.rwrTargetVisibility.targetsUnused))
    for i in range(length(free))
      free[i] = hud.rwrTargetVisibility.targetsUnused[i]

    var nulledCount = 0
    for i in range(length(free))
      let idx = free[i]
      if idx < 0 || idx >= targetCount
        continue
      if !is_rwr_target_valid(*hud, idx)
        continue

      hud.rwrTargetVisibility.targetShow[idx] = true
      free[i] = -1
      hud.rwrTargetVisibility.targetsUnused[i] = -1
      nulledCount++
      hud.rwrTargetVisibility.targetsUsed |> push(idx)

      if hud.rwrTargets[idx].sector < 2.0
        for j in range(i + 1, length(free))
          let idx2 = free[j]
          if idx2 < 0 || idx2 >= targetCount
            continue
          if !is_rwr_target_valid(*hud, idx2)
            continue
          let gi1 = hud.rwrTargets[idx].groupId
          let gi2 = hud.rwrTargets[idx2].groupId
          if gi1 >= 0 || gi2 >= 0
            let dx = hud.rwrTargets[idx].dirX - hud.rwrTargets[idx2].dirX
            let dy = hud.rwrTargets[idx].dirY - hud.rwrTargets[idx2].dirY
            if dx * dx + dy * dy < DIST_SQ_MAX
              hud.rwrTargetVisibility.targetShow[idx2] = false
              free[j] = -1

    if nulledCount == length(hud.rwrTargetVisibility.targetsUnused)
      hud.rwrTargetVisibility.targetsUnused |> clear()
    else
      var k = 0
      while k < length(hud.rwrTargetVisibility.targetsUnused)
        if hud.rwrTargetVisibility.targetsUnused[k] < 0
          hud.rwrTargetVisibility.targetsUnused |> erase(k)
        else
          k++

    var i = 0
    while i < length(hud.rwrTargetVisibility.targetsUsed)
      let idx = hud.rwrTargetVisibility.targetsUsed[i]
      if idx < 0 || idx >= targetCount || !is_rwr_target_valid(*hud, idx)
        i++
        continue

      if !hud.rwrTargets[idx].track && !hud.rwrTargets[idx].launch
        var collision = false
        for j in range(i + 1, length(hud.rwrTargetVisibility.targetsUsed))
          let idx2 = hud.rwrTargetVisibility.targetsUsed[j]
          if idx2 < 0 || idx2 >= targetCount || !is_rwr_target_valid(*hud, idx2)
            continue
          if (hud.rwrTargets[idx2].track || hud.rwrTargets[idx2].launch)
            let gi1 = hud.rwrTargets[idx].groupId
            let gi2 = hud.rwrTargets[idx2].groupId
            if gi1 >= 0 || gi2 >= 0
              let dx = hud.rwrTargets[idx].dirX - hud.rwrTargets[idx2].dirX
              let dy = hud.rwrTargets[idx].dirY - hud.rwrTargets[idx2].dirY
              if dx * dx + dy * dy < DIST_SQ_MAX
                collision = true
                break
        if collision
          i++
          continue

      var collision2 = false
      if hud.rwrTargets[idx].sector < 2.0
        for j in range(length(hud.rwrTargetVisibility.targetsUnused))
          let idx2 = hud.rwrTargetVisibility.targetsUnused[j]
          if idx2 < 0 || idx2 >= targetCount || !is_rwr_target_valid(*hud, idx2)
            continue
          let gi1 = hud.rwrTargets[idx].groupId
          let gi2 = hud.rwrTargets[idx2].groupId
          if gi1 >= 0 || gi2 >= 0
            let dx = hud.rwrTargets[idx].dirX - hud.rwrTargets[idx2].dirX
            let dy = hud.rwrTargets[idx].dirY - hud.rwrTargets[idx2].dirY
            if dx * dx + dy * dy < DIST_SQ_MAX
              collision2 = true
              break
      if collision2
        i++
        continue

      hud.rwrTargetVisibility.targetsUnused |> push(hud.rwrTargetVisibility.targetsUsed[i])
      hud.rwrTargetVisibility.targetsUsed |> erase(i)
