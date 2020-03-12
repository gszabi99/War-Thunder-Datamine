local tostring_r = require("string.nut").tostring_r
//local pp = @(...) print(vargv.reduce(@(a,b) a+", " +b) + "\n")

/*
todo:
  __update
  mandatory params [name, def, Optional(Integer)]
  __merge
  ----
    ?register class
    ?inherit from dataclass
  ----extra
  type checking on constructor
  type checking on assignment - need to have set and get and store values in internal field

*/
/*
local Point2_manual = class {
  x = 0
  y = 0
  static __name__ = "Point2"
  constructor(x=0,y=0){
    if (::type(x)=="table"){
      this.x = x?.x ?? 0
      this.y = x?.y ?? 0
      return this
    }
    this.x = x
    this.y = y
    return this
  }
  function __update(vargv){
    ::assert(vargv.len()>0 && vargv.len()<2)
    if (vargv.len() == 1 && ::type(vargv[0]) == "table") {
      local table = vargv[0]
      if ("x" in table)
        this.x = table.x
      if ("y" in table)
        this.y = table.y
    }
    else{
      this.x = vargv[0]
      this.y = vargv[1]
    }
    return this
  }
}
*/

local pp = @(...) print(" ".join(vargv.append("\n")))

local function unpackfield(field){
  local def = null
  if (::type(field) == "array") {
    def = field[1]
    field = field[0]
  }
  return [field, def]
}
local function _cfield(fieldname, def){
  return $"{fieldname} = {def}"
}
local function mkAddNewline(indent=""){
  return @(a,b) $"{a}\n{indent}{b}"
}

local addComma = @(a,b) ", ".concat(a,b)
//local addSemiCol = @(a,b) a+"; "+b
//local addNewline0 = mkAddNewline()
local addNewline1 = mkAddNewline("  ")
//local addNewline2 = mkAddNewline("    ")
local addNewline3 = mkAddNewline("      ")

local function valToStr(val){
  ::assert(["string","null","float","integer", "bool"].indexof(::type(val))!=null, "only simple immutable types currently supported")
  if (::type(val)=="string")
    val = $"\"{val}\""
  return val
}

local function mkClassFields(fields){
  return fields.map(@(v) _cfield(v[0], valToStr(v[1]))).reduce(addNewline1)
}

local function mkPosFieldInit(fieldname, def){
  def = valToStr(def)
  return $"this.{fieldname} = {fieldname}"
}

local function mkTableFieldInit(fieldname, firstarg, def){
  def = valToStr(def)
  def = (def != null)
    ? $" ?? {def}"
    : ""
  return $"this.{fieldname} = {firstarg}?.{fieldname}{def}"
}
local function mkArg(name, def){
  return $"{name} = {def}"
}

local function mkCtor(fields, args){
  local firstarg = fields[0][0]
  pp(tostring_r(fields))
  local kwargs_inits = fields.map(@(v) mkTableFieldInit(v[0], firstarg, v[1])).reduce(addNewline3)
  local pargs_inits = fields.map(@(v) mkPosFieldInit(v[0], v[1])).filter(@(idx,v) v!="" && v!=null).reduce(addNewline3) ?? ""

  local ret = @"
  constructor({0}){
    if (::type({1}) == {4}table{4}){
      {2}
    }
    else {
      {3}
    }
    return this
  }".subst(args, firstarg, kwargs_inits, pargs_inits, "\"")
  return ret
}

local defParams = {name=null, verbose=false}
local function Dataclass(fields, params = defParams){
  local name = defParams?.name
  name = (::type(name)=="string")
    ? $"static __name__ = \"{name}\"\n"
    : ""


  fields = fields.map(unpackfield)
  local args = fields.map(@(v) mkArg(v[0], valToStr(v[1]))).reduce(addComma)
  local classfields = mkClassFields(fields)
  local ctor = mkCtor(fields, args)
//  local updateFunc = @"function __update(...){
//  }".subst(args)
  local ret = @"class {
  {0}{1}
  {2}
}
".subst(
    name,
    classfields,
    ctor
//    updateFunc
  )
  if (params?.verbose)
    print(ret)
  return compilestring($"return {ret}")()
}

if (this?.__name__ == "__main__") {
  local Point2 = Dataclass(["x",["y",0]], {name ="Point2", verbose=true})
  local p2 = Point2(2,3)
  pp(p2.x, p2.y)
//  local b = Point2_manual(10,2).x
//  local p2m = Point2_manual(1,2)
//  local a = Point2_manual(1).__update({y=3})
//  pp(a.x, a.y)
//  a.x=100
//  pp(a.x,a.y)
}

return Dataclass