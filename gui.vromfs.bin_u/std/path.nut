from "string" import split_by_chars, regexp
from "types" import String, Array


















function [pure] normalize(path: string): string {
  let pathSegments = split_by_chars(path, "\\/")
  local isAbsolutePath = false

  if (path.len() > 0 && (path[0] == '/' || path[0] == "\\"[0])) {
    isAbsolutePath = true
    pathSegments.insert(0, "/")
  }
  else if (pathSegments.len() > 0 &&
    regexp("^[a-zA-Z]:.*$").match(pathSegments[0])) {
    isAbsolutePath = true
    if (pathSegments[0].len() > 2) {
      pathSegments.insert(0, pathSegments[0].slice(0, 2))
      pathSegments[1] = pathSegments[1].slice(2)
    }
  }

  local numRemoved = 0
  for (local j = pathSegments.len() - 1; j >= 0; j--) {
    let segment = pathSegments[j]
    if (segment == ".")
      numRemoved += 1
    else if (segment == "..")
      numRemoved += 2

    if (numRemoved > 0 && (!isAbsolutePath || j > 0)){
      pathSegments.remove(j)
      numRemoved--
    }
  }

  local normalizedPath = "/".join(pathSegments.filter(@(val) val != ""))
  if (normalizedPath.len() > 2 && normalizedPath.slice(0, 2) == "//")
    normalizedPath = normalizedPath.slice(1)
  return normalizedPath
}





function [pure] isNormalized(path: string): bool {
  return path == normalize(path)
}





function [pure] getLastSeparatorIndex(path:string): int {
  for (local j = path.len() - 1; j >= 0; j--)
    if (path[j] == '/')
      return j
  return -1
}













function [pure] parentPath(path:string): string|null {
  if (path == "/")
    return null

  let separatorIdx = getLastSeparatorIndex(path)
  if (separatorIdx > 0)
    return path.slice(0, separatorIdx)
  else if (separatorIdx == 0)
    return "/"
  else
    return null
}













function [pure] fileName(path:string): string {
  if (path == "/")
    return "/"

  let separatorIdx = getLastSeparatorIndex(path)
  if (separatorIdx == -1)
    return path
  else
    return path.slice(separatorIdx + 1)
}












function _join(basePath, other) {
  assert(basePath instanceof String)
  assert(other instanceof String)
  if (basePath == "")
    return other
  else if (other == "" || other == "/")
    return basePath
  else if (basePath[basePath.len() - 1] == '/' && other[0] == '/')
    return $"{basePath}{other.slice(1)}"
  else if (basePath[basePath.len() - 1] == '/' || other[0] == '/')
    return $"{basePath}{other}"
  else
    return $"{basePath}/{other}"
}











function joinArray(pathArray): string {
  if (pathArray.len() > 1 && pathArray[0] == "/")
    return $"/{"/".join(pathArray.slice(1), true)}"
  return "/".join(pathArray)
}

function join(...) {
  local path = ""
  foreach (pathSegment in vargv) {
    if (pathSegment instanceof Array) {
      path = _join(path,joinArray(pathSegment))
    }
    else {
      path = _join(path, pathSegment)
    }
  }
  return path
}











function [pure] splitToArray(path: string): array {
  if (path == "")
    return []
  let segments = split_by_chars(path, "/")
  if (path[0] == '/')
    segments.insert(0, "/")

  return segments
}


return {
  normalize
  isNormalized
  getLastSeparatorIndex
  parentPath
  fileName
  join
  splitToArray
}
