//-file:plus-string
let { isDataBlock } = require("%sqstd/underscore.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let g_string = require("%sqstd/string.nut")
let {format} = require("string")


local toString //forward declaration

let function tableKeyToString(k) {
  if (typeof(k) != "string")
    return $"[ {toString(k) }]"
  if (g_string.isStringInteger(k) || g_string.isStringFloat(k) ||
    [ "true", "false", "null" ].contains(k))
      return $"[\"{k}\"]"
  return k
}

let DEBUG_TABLE_DATA_PARAMS = {
  recursionLevel = 4,
  addStr = "",
  showBlockBrackets = true,
  silentMode = false,
  printFn = null
}

let function debugTableData(info, params = DEBUG_TABLE_DATA_PARAMS) {
  let showBlockBrackets = params?.showBlockBrackets ?? true
  let addStr = params?.addStr ?? ""
  let silentMode = params?.silentMode ?? false
  let recursionLevel = params?.recursionLevel ?? 4
  local printFn = params?.printFn
  let needUnfoldInstances = params?.needUnfoldInstances ?? false

  if (printFn == null)
    printFn = println

  if (addStr=="" && !silentMode)
    printFn("DD: START")

  let prefix = silentMode ? "" : "DD: ";

  if (info == null)
    printFn(prefix + "null");
  else {
    if (isDataBlock(info)) {
      let blockName = (info.getBlockName()!="")? info.getBlockName()+" " : ""
      if (showBlockBrackets)
        printFn(prefix+addStr+blockName+"{")
      let addStr2 = addStr + (showBlockBrackets? "  " : "")
      for (local i = 0; i < info.paramCount(); i++) {
        let name = info.getParamName(i)
        local val = info.getParamValue(i)
        local vType = " "
        if (val == null) { val = "null" }
        else if (typeof(val)=="integer") vType = ":i"
        else if (typeof(val)=="float") { vType = ":r"; val = val.tostring() + ((val % 1) ? "" : ".0") }
        else if (typeof(val)=="bool") vType = ":b"
        else if (typeof(val)=="string") { vType = ":t"; val = "'" + val + "'" }
        else if (u.isPoint2(val)) { vType = ":p2"; val = format("%s, %s", val.x.tostring(), val.y.tostring()) }
        else if (u.isPoint3(val)) { vType = ":p3"; val = format("%s, %s, %s", val.x.tostring(), val.y.tostring(), val.z.tostring()) }
        else if (u.isColor4(val)) { vType = ":c";  val = format("%d, %d, %d, %d", 255 * val.r, 255 * val.g, 255 * val.b, 255 * val.a) }
        else if (u.isTMatrix(val)) { vType = ":m"
          let arr = []
          for (local j = 0; j < 4; j++)
            arr.append("[" + g_string.implode([ val[j].x, val[j].y, val[j].z ], ", ") + "]")
          val = "[" + g_string.implode(arr, " ") + "]"
        }
        else val = toString(val)
        printFn(prefix+addStr2+name+vType+"= " + val)
      }
      for (local j = 0; j < info.blockCount(); j++)
        if (recursionLevel)
          debugTableData(info.getBlock(j),
            {recursionLevel = recursionLevel-1, addStr = addStr2, showBlockBrackets = true, silentMode = silentMode, printFn = printFn})
        else
          printFn(prefix+addStr2 + info.getBlock(j).getBlockName() + " = DataBlock()")
      if (showBlockBrackets)
        printFn(prefix+addStr+"}")
    }
    else if (typeof(info)=="array" || typeof(info)=="table" || (typeof(info)=="instance" && needUnfoldInstances)) {
      if (showBlockBrackets)
        printFn(prefix + addStr + (typeof(info) == "array" ? "[" : "{"))
      let addStr2 = addStr + (showBlockBrackets? "  " : "")
      foreach(id, data in info) {
        let dType = typeof(data)
        let isDataBlockType = isDataBlock(data)
        let idText = tableKeyToString(id)
        if (isDataBlockType || dType=="array" || dType=="table" || (dType=="instance" && needUnfoldInstances)) {
          let openBraket = isDataBlockType ? "DataBlock {" : dType == "array" ? "[" : "{"
          let closeBraket = ((dType=="array")? "]":"}")
          if (recursionLevel) {
            printFn(prefix + addStr2 + idText + " = " + openBraket)
            debugTableData(data,
              {recursionLevel = recursionLevel - 1, addStr = addStr2 + "  ", showBlockBrackets = false,
                needUnfoldInstances, silentMode, printFn })

            printFn(prefix+addStr2+closeBraket)
          }
          else {
            let hasContent = (isDataBlockType && (data.paramCount() + data.blockCount()) > 0)
              || dType=="instance" || data.len() > 0
            printFn("".concat(prefix, addStr2, idText, " = ", openBraket, hasContent ? "..." : "", closeBraket))
          }
        }
        else if (dType=="instance")
          printFn(prefix+addStr2+idText+" = " + toString(data, min(1, recursionLevel), addStr2))
        else if (dType=="string")
          printFn(prefix+addStr2+idText+" = \"" + data + "\"")
        else if (dType=="float")
          printFn(prefix+addStr2+idText+" = " + data + ((data % 1) ? "" : ".0"))
        else if (dType=="null")
          printFn(prefix+addStr2+idText+" = null")
        else
          printFn(prefix+addStr2+idText+" = " + data)
      }
      if (showBlockBrackets)
        printFn(prefix + addStr + (typeof(info) == "array" ? "]" : "}"))
    }
    else if (typeof(info)=="instance")
      printFn(prefix + addStr + toString(info, min(1, recursionLevel), addStr)) //not decrease recursion because it current instance
    else {
      let iType = typeof(info)
      if (iType == "string")
        printFn(prefix + addStr + "\"" + info + "\"")
      else if (iType == "float")
        printFn(prefix + addStr + info + ((info % 1) ? "" : ".0"))
      else if (iType == "null")
        printFn(prefix + addStr + "null")
      else
        printFn(prefix + addStr + info)
    }
  }
  if (addStr=="" && !silentMode)
    printFn("DD: DONE.")
}

toString = function (val, recursion = 1, addStr = "") {
  if (type(val) == "instance") {
    if (isDataBlock(val)) {
      let rootBlockName = val.getBlockName() ?? ""
      let iv = []
      for (local i = 0; i < val.paramCount(); i++)
        iv.append("" + val.getParamName(i) + " = " + toString(val.getParamValue(i)))
      for (local i = 0; i < val.blockCount(); i++)
        iv.append("" + val.getBlock(i).getBlockName() + " = " + toString(val.getBlock(i)))
      return format("DataBlock %s{ %s }", rootBlockName, g_string.implode(iv, ", "))
    }
    else if (u.isPoint2(val))
      return format("Point2(%s, %s)", val.x.tostring(), val.y.tostring())
    else if (u.isPoint3(val))
      return format("Point3(%s, %s, %s)", val.x.tostring(), val.y.tostring(), val.z.tostring())
    else if (u.isColor4(val))
      return format("Color4(%d/255.0, %d/255.0, %d/255.0, %d/255.0)", 255 * val.r, 255 * val.g, 255 * val.b, 255 * val.a)
    else if (u.isTMatrix(val)) {
      let arr = []
      for (local i = 0; i < 4; i++)
        arr.append(toString(val[i]))
      return "TMatrix(" + g_string.implode(arr, ", ") + ")"
    }
    else if ("isToStringForDebug" in val)
      return val.tostring()
    else if ("DaGuiObject" in getroottable() && val instanceof getroottable()["DaGuiObject"])
      return val.isValid()
        ? "DaGuiObject(tag = {0}, id = {1} )".subst(val.tag, val?.id ?? "NULL")
        : "invalid DaGuiObject"
    else {
      local ret = val?.getmetamethod("_tostring") != null
        ? "instance \"{0}\"".subst(val.tostring())
        : "instance"

      if (recursion > 0)
        foreach (idx, v in val) {
          //!!FIX ME: better to not use \n in toString()
          //and make different view ways for debugTabledata and toString
          //or it make harder to read debugtableData result in log, also arrays in one string generate too long strings
          if (typeof(v) != "function") {
            let index = [ "float", "null" ].contains(type(idx)) ? toString(idx) : idx
            ret += "\n" + addStr + "  " + index + " = " + toString(v, recursion - 1, addStr + "  ")
          }
        }

      return ret;
    }
  }
  if (val == null)
    return "null"
  if (type(val) == "string")
    return format("\"%s\"", val)
  if (type(val) == "float")
    return val.tostring() + ((val % 1) ? "" : ".0")
  if (type(val) != "array" && type(val) != "table")
    return "" + val
  let isArray = type(val) == "array"
  local str = ""
  if (recursion > 0) {
    let iv = []
    foreach (i,v in val) {
      let index = isArray ? ("[" + i + "]") : tableKeyToString(i)
      iv.append("" + index + " = " + toString(v, recursion - 1, ""))
    }
    str = g_string.implode(iv, ", ")
  } else
    str = val.len() ? "..." : ""
  return isArray ? ("[ " + str + " ]") : ("{ " + str + " }")
}

return {
  debugTableData
  toString
}