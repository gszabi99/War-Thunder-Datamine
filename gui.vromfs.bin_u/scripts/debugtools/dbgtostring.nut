// warning disable: -file:forbidden-function

local time = require("scripts/time.nut")

::dlog <- function dlog(...)
{
  for (local i = 0; i < vargv.len(); i++)
  {
    dagor.debug("DLOG: " + vargv[i])
    dagor.screenlog("" + vargv[i])
  }
}

::clog <- function clog(...)
{
  foreach (arg in vargv)
    ::dagor.console_print(":  ".concat(time.getCurTimeMillisecStr(), ::type(arg) == "string" ? arg : ::toString(arg)))
}

::can_be_readed_as_datablock <- function can_be_readed_as_datablock(blk) //can be overrided by dataBlockAdapter
{
  return u.isDataBlock(blk)
}

function initEventBroadcastLogging()
{
  local subscriptions = require("sqStdLibs/helpers/subscriptions.nut")
  subscriptions.setDebugLoggingParams(::dagor.debug, ::dagor.getCurTime, ::toString)
  ::debug_event_logging <- subscriptions.debugLoggingEnable
}

local function tableKeyToString(k) {
  if (typeof(k) != "string")
    return "[" + ::toString(k) + "]"
  if (::g_string.isStringInteger(k) || ::g_string.isStringFloat(k) ||
    ::isInArray(k, [ "true", "false", "null" ]))
      return "[\"" + k + "\"]"
  return k
}

local DEBUG_TABLE_DATA_PARAMS = {
  recursionLevel = 4,
  addStr = "",
  showBlockBrackets = true,
  silentMode = false,
  printFn = null
}

::debugTableData <- function debugTableData(info, params = DEBUG_TABLE_DATA_PARAMS)
{
  local showBlockBrackets = params?.showBlockBrackets ?? true
  local addStr = params?.addStr ?? ""
  local silentMode = params?.silentMode ?? false
  local recursionLevel = params?.recursionLevel ?? 4
  local printFn = params?.printFn
  local needUnfoldInstances = params?.needUnfoldInstances ?? false

  if (printFn == null)
    printFn = silentMode ? @(t) ::print(t + "\n") : ::dagor.debug;

  if (addStr=="" && !silentMode)
    printFn("DD: START")

  local prefix = silentMode ? "" : "DD: ";

  if (info == null)
    printFn(prefix + "null");
  else
  {
    if (::can_be_readed_as_datablock(info))
    {
      local blockName = (info.getBlockName()!="")? info.getBlockName()+" " : ""
      if (showBlockBrackets)
        printFn(prefix+addStr+blockName+"{")
      local addStr2 = addStr + (showBlockBrackets? "  " : "")
      for (local i = 0; i < info.paramCount(); i++)
      {
        local name = info.getParamName(i)
        local val = info.getParamValue(i)
        local vType = " "
        if (val == null) { val = "null" }
        else if (typeof(val)=="integer") vType = ":i"
        else if (typeof(val)=="float") { vType = ":r"; val = val.tostring() + ((val % 1) ? "" : ".0") }
        else if (typeof(val)=="bool") vType = ":b"
        else if (typeof(val)=="string") { vType = ":t"; val = "'" + val + "'" }
        else if (u.isPoint2(val)) { vType = ":p2"; val = ::format("%s, %s", val.x.tostring(), val.y.tostring()) }
        else if (u.isPoint3(val)) { vType = ":p3"; val = ::format("%s, %s, %s", val.x.tostring(), val.y.tostring(), val.z.tostring()) }
        else if (u.isColor4(val)) { vType = ":c";  val = ::format("%d, %d, %d, %d", 255 * val.r, 255 * val.g, 255 * val.b, 255 * val.a) }
        else if (u.isTMatrix(val)) { vType = ":m"
          local arr = []
          for (local j = 0; j < 4; j++)
            arr.append("[" + ::g_string.implode([ val[j].x, val[j].y, val[j].z ], ", ") + "]")
          val = "[" + ::g_string.implode(arr, " ") + "]"
        }
        else val = ::toString(val)
        printFn(prefix+addStr2+name+vType+"= " + val)
      }
      for (local j = 0; j < info.blockCount(); j++)
        if (recursionLevel)
          ::debugTableData(info.getBlock(j),
            {recursionLevel = recursionLevel-1, addStr = addStr2, showBlockBrackets = true, silentMode = silentMode, printFn = printFn})
        else
          printFn(prefix+addStr2 + info.getBlock(j).getBlockName() + " = ::DataBlock()")
      if (showBlockBrackets)
        printFn(prefix+addStr+"}")
    }
    else if (typeof(info)=="array" || typeof(info)=="table" || (typeof(info)=="instance" && needUnfoldInstances))
    {
      if (showBlockBrackets)
        printFn(prefix + addStr + (typeof(info) == "array" ? "[" : "{"))
      local addStr2 = addStr + (showBlockBrackets? "  " : "")
      foreach(id, data in info)
      {
        local dType = typeof(data)
        local isDataBlock = ::can_be_readed_as_datablock(data)
        local idText = tableKeyToString(id)
        if (isDataBlock || dType=="array" || dType=="table" || (dType=="instance" && needUnfoldInstances))
        {
          local openBraket = isDataBlock ? "DataBlock {" : dType == "array" ? "[" : "{"
          local closeBraket = ((dType=="array")? "]":"}")
          if (recursionLevel)
          {
            printFn(prefix + addStr2 + idText + " = " + openBraket)
            ::debugTableData(data,
              {recursionLevel = recursionLevel - 1, addStr = addStr2 + "  ", showBlockBrackets = false,
                needUnfoldInstances, silentMode, printFn })

            printFn(prefix+addStr2+closeBraket)
          }
          else
          {
            local hasContent = (isDataBlock && (data.paramCount() + data.blockCount()) > 0)
              || dType=="instance" || data.len() > 0
            printFn("".concat(prefix, addStr2, idText, " = ", openBraket, hasContent ? "..." : "", closeBraket))
          }
        }
        else if (dType=="instance")
          printFn(prefix+addStr2+idText+" = " + ::toString(data, ::min(1, recursionLevel), addStr2))
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
      printFn(prefix + addStr + toString(info, ::min(1, recursionLevel), addStr)) //not decrease recursion because it current instance
    else
    {
      local iType = typeof(info)
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

::debugTableDataC <- function debugTableDataC(info, params = DEBUG_TABLE_DATA_PARAMS)
{
  ::debugTableData(info, params.__merge({ printFn = ::dagor.console_print }))
}

::toString <- function toString(val, recursion = 1, addStr = "")
{
  if (::type(val) == "instance")
  {
    if (::can_be_readed_as_datablock(val))
    {
      local rootBlockName = val.getBlockName() ?? ""
      local iv = []
      for (local i = 0; i < val.paramCount(); i++)
        iv.append("" + val.getParamName(i) + " = " + ::toString(val.getParamValue(i)))
      for (local i = 0; i < val.blockCount(); i++)
        iv.append("" + val.getBlock(i).getBlockName() + " = " + ::toString(val.getBlock(i)))
      return format("DataBlock %s{ %s }", rootBlockName, ::g_string.implode(iv, ", "))
    }
    else if (u.isPoint2(val))
      return format("Point2(%s, %s)", val.x.tostring(), val.y.tostring())
    else if (u.isPoint3(val))
      return format("Point3(%s, %s, %s)", val.x.tostring(), val.y.tostring(), val.z.tostring())
    else if (u.isColor4(val))
      return format("Color4(%d/255.0, %d/255.0, %d/255.0, %d/255.0)", 255 * val.r, 255 * val.g, 255 * val.b, 255 * val.a)
    else if (u.isTMatrix(val))
    {
      local arr = []
      for (local i = 0; i < 4; i++)
        arr.append(::toString(val[i]))
      return "TMatrix(" + ::g_string.implode(arr, ", ") + ")"
    }
    else if (::getTblValue("isToStringForDebug", val))
      return val.tostring()
    else if (val instanceof ::DaGuiObject)
      return val.isValid()
        ? "DaGuiObject(tag = {0}, id = {1} )".subst(val.tag, val?.id ?? "NULL")
        : "invalid DaGuiObject"
    else
    {
      local ret = ""
      if (val instanceof ::BaseGuiHandler)
        ret = ::format("BaseGuiHandler(sceneBlkName = %s)", ::toString(val.sceneBlkName))
      else
      {
        ret += val?.getmetamethod("_tostring") != null
          ? "instance \"{0}\"".subst(val.tostring())
          : "instance"
      }

      if (recursion > 0)
        foreach (idx, v in val)
        {
          //!!FIX ME: better to not use \n in toString()
          //and make different view ways for debugTabledata and toString
          //or it make harder to read debugtableData result in log, also arrays in one string generate too long strings
          if (typeof(v) != "function")
          {
            local index = ::isInArray(::type(idx), [ "float", "null" ]) ? ::toString(idx) : idx
            ret += "\n" + addStr + "  " + index + " = " + ::toString(v, recursion - 1, addStr + "  ")
          }
        }

      return ret;
    }
  }
  if (val == null)
    return "null"
  if (::type(val) == "string")
    return format("\"%s\"", val)
  if (::type(val) == "float")
    return val.tostring() + ((val % 1) ? "" : ".0")
  if (::type(val) != "array" && ::type(val) != "table")
    return "" + val
  local isArray = ::type(val) == "array"
  local str = ""
  if (recursion > 0)
  {
    local iv = []
    foreach (i,v in val)
    {
      local index = isArray ? ("[" + i + "]") : tableKeyToString(i)
      iv.append("" + index + " = " + ::toString(v, recursion - 1, ""))
    }
    str = ::g_string.implode(iv, ", ")
  } else
    str = val.len() ? "..." : ""
  return isArray ? ("[ " + str + " ]") : ("{ " + str + " }")
}

initEventBroadcastLogging()
