



function pickLoadingBg(list, rnd) {
  local sum = 0.0
  foreach (value in list)
    sum += value
  sum = rnd * sum
  local res = ""
  foreach (name, value in list) {
    res = name
    sum -= value
    if (sum <= 0)
      break
  }
  return res
}

let loadingBgBlkPath = @[pure, nodiscard] (name) name.split(".").len() > 1 ? name : $"loadingbg/{name}.blk"

return freeze({ pickLoadingBg, loadingBgBlkPath })
