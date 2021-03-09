local string = require("string")
local dagorMath = require("dagor.math")
local {tostring_r} = require("std/string.nut")

local rexFloat = string.regexp(@"(\+|-)?([0-9]+\.?[0-9]*|\.[0-9]+)([eE](\+|-)?[0-9]+)?")
local rexInt = string.regexp(@"[\+\-]?[0-9]+")
local tofloat = @(v) v.tofloat()
local tointeger = @(v) v.tointeger()
local isStrInt = @(v) rexInt.match(string.strip(v))
local isStrFloat = @(v) rexFloat.match(string.strip(v))
local function isStrBool(text){
  local s = string.strip(text)
  return (s == "true" || s == "1" || s == "false" || s == "0")
}
local function isValueTextValid(comp_type, text) {
  local simpleTypeFunc = {
    string = @(v) true
    integer = isStrInt
    float = isStrFloat
    bool = isStrBool
  }?[comp_type]

  if (simpleTypeFunc)
    return simpleTypeFunc(text)

  local nFields = {Point2=2, Point3=3, DPoint3=3, Point4=4}.map(@(v) [v, isStrFloat]).__update(
        {IPoint2=2, IPoint3=3, E3DCOLOR=4}
        .map(@(v) [v, isStrInt])
      )?[comp_type]

  if (nFields) {
    local fields = text.split(",")
    if (fields.len()!=nFields[0])
      return false
    return fields.reduce(@(a,b) a && nFields[1](b))
  }
  return false
}

local function call_strfunc(str, func){
  local ret = str
  try {
    ret = func.pcall(str)
  }
  catch(e){
    log_for_user("can't convert to string", str)
  }
  return ret
}

local function safe_cvt_txt(str, func, empty){
  return str!="" ? call_strfunc(str, func) : empty
}

local dagorMathClassFields = {
  Point2 = ["x", "y"],
  Point3 = ["x", "y", "z"],
  DPoint3 = ["x", "y", "z"],
  Point4 = ["x", "y", "z", "w"],
  IPoint2 = ["x", "y"],
  IPoint3 = ["x", "y", "z"]
}


local function convertTextToValForDagorClass(name, fields){
  local classFields = dagorMathClassFields?[name]
  if (fields.len()!=classFields?.len?())
    return null
  local res = dagorMath[name]()
  classFields.each(@(key, idx) res[key] = fields[idx])
  return res
}

local convertTextToValFuncs = {
  string = @(v) v,
  integer = @(v) safe_cvt_txt(v, "".tointeger, 0),
  float = @(v) safe_cvt_txt(v, "".tofloat, 0.0)
  bool = function(s){
    s = string.strip(s)
    if (s=="true" || s=="1")
      return true
    if (s=="false" || s=="0")
      return false
    return null
  }
}

local function convertTextToVal(comp_type, text) {
  if (convertTextToValFuncs?[comp_type] != null)
    return convertTextToValFuncs[comp_type](text)

  local fields = text.split(",")
  local floatDagorMathTypes = ["Point2", "Point3", "DPoint3", "Point4"]
  if (floatDagorMathTypes.indexof(comp_type) != null)
    return convertTextToValForDagorClass(comp_type, fields.map(pipe(string.strip, tofloat)))

  local intDagorMathTypes = ["IPoint2", "IPoint3"]
  if (intDagorMathTypes.indexof(comp_type) != null)
    return convertTextToValForDagorClass(comp_type, fields.map(pipe(string.strip, tointeger)))

  if (comp_type == "E3DCOLOR") {
    if (fields.len()!=4)
      return null
    local f = fields.map(pipe(string.strip, tointeger, @(v) ::clamp(v, 0, 255)))
    local res = dagorMath.E3DCOLOR()
    foreach (idx, field in ["r","g","b","a"]) {
      res[field] = f[idx]
    }
    return res
  }

  return null
}

local map_type_to_str = {
  float =  function(v){
    local tf = v.tostring()
    return (tf.indexof(".") != null || tf.indexof("e") != null) ? tf : $"{tf}.0"
  },
  ["null"] = @(v) "null",
}
local map_class_to_str = {
  [dagorMath.Point2] = @(v) string.format("%.4f, %.4f", v.x, v.y),
  [dagorMath.Point3] = @(v) string.format("%.4f, %.4f, %.4f", v.x, v.y, v.z),
  [dagorMath.DPoint3] = @(v) string.format("%.4f, %.4f, %.4f", v.x, v.y, v.z),
  [dagorMath.Point4] = @(v) string.format("%.4f, %.4f, %.4f, %.4f", v.x, v.y, v.z, v.w),
  [dagorMath.IPoint2] = @(v) string.format("%d, %d", v.x, v.y),
  [dagorMath.IPoint3] = @(v) string.format("%d, %d, %d", v.x, v.y, v.z),
  [dagorMath.E3DCOLOR] = @(v) string.format("%d, %d, %d, %d", v.r, v.g, v.b, v.a),
  [dagorMath.TMatrix] = function(v){
    local pos = v[3]
    return string.format("TM: [3]=%.2f, %.2f, %.2f", pos.x, pos.y, pos.z)
  },
}

local function compValToString(v, max_cvstr_len = 80){
  local compValToString_ = callee()
  local function instance_to_str(v){
    local function objToStr(v){
      local s = string.format("[%d]={", v.len())
      foreach (val in v) {
        local nexts = "{0}{{1}},".subst(s, compValToString_(val, max_cvstr_len))
        if (max_cvstr_len > 0 && nexts.len() > max_cvstr_len) {
          s = $"{s}..."
          break
        }
        else
          s = nexts
      }
      s = $"{s}\}"
      return s
    }

    local function arrayToStr(v){
      local s = ""
      foreach (fieldName, fieldVal in v.getAll()) {
        if (s.len()>0)
          s = $"{s}|"
        local nexts = $"{s}{fieldName} = {tostring_r(fieldVal)}"
        if (max_cvstr_len > 0 && nexts.len() > max_cvstr_len) {
          s = $"{s}..."
          break
        }
        else
          s = nexts
      }
      return s
    }

    local res =  map_class_to_str?[v?.getclass()]?(v)
    if (res == null) {
      if (v instanceof ::ecs.CompObject)
        res = objToStr(v)
      else if (v instanceof ::ecs.CompArray)
        res = arrayToStr(v)
      else
        res = ""
    }
    return res
  }
  return ::type(v) == "instance"
    ? instance_to_str(v)
    : (map_type_to_str?[::type(v)]?(v) ?? v.tostring())
}

local function getValFromObj(object, path=null){
  local res = object
  foreach (key in (path ?? [])) {
    if (res?[key] != null || key in object || object?.indexof(key)!=null) {
      res = res?[key]
    }
    else
      break
  }
  return res
}

local function setValToObj(object, path, val){
  local res = object
  local lastkey = path?[path.len()-1]
  local lasfoundIdx = -1
  if (lastkey == null)
    return
  foreach (idx, key in path) {
    if (idx < path.len()-1 && (res?[key] != null || key in object || object?.indexof(key)!=null)) {
      lasfoundIdx = idx
      res = res[key]
    }
    else
      break
  }
  res[lastkey] = val
  if (lasfoundIdx == path.len()-1) {
    res[lastkey] = val
  }
}

local exports = {
  getValFromObj
  setValToObj
  isValueTextValid
  convertTextToVal
  compValToString

  ecsTypeToSquirrelType = {
    //[::ecs.TYPE_NULL] = null
    [::ecs.TYPE_STRING] = "string",
    [::ecs.TYPE_INT] = "integer",
    [::ecs.TYPE_FLOAT] = "float",
    [::ecs.TYPE_POINT2] = "Point2",
    [::ecs.TYPE_POINT3] = "Point3",
    [::ecs.TYPE_DPOINT3] = "DPoint3",
    [::ecs.TYPE_POINT4] = "Point4",
    [::ecs.TYPE_IPOINT2] = "IPoint2",
    [::ecs.TYPE_IPOINT3] = "IPoint3",
    [::ecs.TYPE_BOOL] = "bool",
    [::ecs.TYPE_COLOR] = "E3DCOLOR",
    [::ecs.TYPE_MATRIX] = "TMatrix",
    [::ecs.TYPE_EID] = "integer",
  }
}




return exports
