let function setValInTblPath(table, path, value){
  let pathLen = path.len()
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
  if (path==null)
    return null
  if (startIdx > 0)
    path = path.slice(startIdx)
  foreach (pathPart in path){
    curTbl = curTbl?[pathPart]
    if (curTbl==null)
      return null
  }
  return curTbl
}

let function tryGetValInTblPath(table, path){
  foreach (idx, _ in path) {
    let val = getValInTblPath(table, path, idx)
    if (val != null)
      return val
  }
  return null
}

return {
  tryGetValInTblPath
  setValInTblPath
  getValInTblPath
}