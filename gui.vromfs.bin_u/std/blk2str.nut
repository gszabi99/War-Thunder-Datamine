local {Point2, Point3, Color4, TMatrix} = require("dagor.math")

local isPoint2 = @(v) v instanceof Point2
local isPoint3 = @(v) v instanceof Point3
local isColor4 = @(v) v instanceof Color4
local isTMatrix = @(v) v instanceof TMatrix

local function blkParamToString(name, val){
  local vType = " "
  if (val == null) { val = "null" }
  else if (::type(val)=="integer") vType = ":i"
  else if (::type(val)=="float") { vType = ":r"; val = (val % 1) ? $"{val}" : $"{val}.0" }
  else if (::type(val)=="bool") vType = ":b"
  else if (::type(val)=="string") { vType = ":t"; val = $"'{val}'"}
  else if (isPoint2(val)) { vType = ":p2"; val = $"{val.x}, {val.y}"}
  else if (isPoint3(val)) { vType = ":p3"; val = $"{val.x}, {val.y}, {val.z}"}
  else if (isColor4(val)) { vType = ":c";  val = $"{255*val.r}, {255*val.g}, {255*val.b}, {255*val.a}"}
  else if (isTMatrix(val)) { vType = ":m"
    for (local j = 0; j < 4; j++)
    val = " ".concat("[", " ". concat("[", ", ".concat( val[j].x, val[j].y, val[j].z), "]"), "]")
  }
  else val = val.tostring()
  return $"{name}{vType} = {val}"
}
local function blkParamsToString(info, indent=0){
  local res = []
  for (local i = 0; i < info.paramCount(); i++) {
    local name = info.getParamName(i)
    local val = info.getParamValue(i)
    res.append([blkParamToString(name, val), indent])
  }
  return res
}
local function datablockToAst(info, params = {}, result = null){
  result = result ?? []
  local recursionLevel = params?.recursionLevel ?? 6
  local printFn = @(v, indent) ::type(v)=="array" ? result.extend(v) : result.append([v, indent])
  local blockName = (info.getBlockName()!="") ? $"{info.getBlockName()} " : ""
  local indent = params?.indent ?? 0
  if (blockName!="null ") {
    printFn($"{blockName}\{", indent)
    indent = indent+1
  }
  printFn(blkParamsToString(info, indent), 0)
  for (local j = 0; j < info.blockCount(); j++) {
    if (recursionLevel != 0) {
      datablockToAst(info.getBlock(j),
        {recursionLevel = recursionLevel-1, indent=indent}, result)
    }
    else
      printFn($"{info.getBlock(j).getBlockName()} = DataBlock()", indent)
  }
  if (blockName!="null ")
    printFn("}", indent-1)
  return result
}
local function indent(n, indentSym = " ") {
  local res = ""
  for(local i = 0; i<n;i++)
    res = $"{res}{indentSym}"
  return res
}
local function datablockToString(datablock, indentSym = " ", newlines=true){
  local ast = datablockToAst(datablock)
  local res = ""
  foreach (v in ast) {
    res += indent(v[1]) +v[0]+ (newlines ? "\n" : "")
  }
  return res
}

return datablockToString
