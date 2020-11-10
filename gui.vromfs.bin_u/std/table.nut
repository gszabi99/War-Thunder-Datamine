local function setValInTblPath(table, path, value){
  local pathLen = path.len()
  local curTbl = table
  foreach (idx, pathPart in path){
    if (idx == pathLen-1)
      curTbl[pathPart] <- value
    else{
      if (!(pathPart in curTbl))
        curTbl[pathPart] <- {}
      curTbl = curTbl[pathPart]
    }
  }
}
local function getValInTblPath(table, path, startIdx=0){
  local curTbl = table
  foreach (idx, pathPart in path){
    if (startIdx >= idx)
      continue
    if (idx == path.len()-1)
      return curTbl?[pathPart]
    else{
      if (pathPart in curTbl)
        curTbl = curTbl[pathPart]
      else
        return null
    }
  }
  return null
}

local function tryGetValInTblPath(table, path){
  local startIdx = 0
  foreach (idx, _ in path) {
    local val = getValInTblPath(table, path, startIdx)
    if (val != null)
      return val
    else if (idx == path.len()-1)
      return null
    else
      startIdx = idx
  }
  return null
}

return {
  tryGetValInTblPath
  setValInTblPath
  getValInTblPath
}