from "string.nut" import tostring_r
















































let pp = @(...) print(" ".join(vargv.append("\n")))

function unpackfield(field){
  local def = null
  if (type(field) == "array") {
    def = field[1]
    field = field[0]
  }
  return [field, def]
}
function _cfield(fieldname, def){
  return $"{fieldname} = {def}"
}
function mkAddNewline(indent=""){
  return @(a,b) $"{a}\n{indent}{b}"
}

let addComma = @(a,b) ", ".concat(a,b)


let addNewline1 = mkAddNewline("  ")

let addNewline3 = mkAddNewline("      ")

function valToStr(val){
  assert(["string","null","float","integer", "bool"].indexof(type(val))!=null, "only simple immutable types currently supported")
  if (type(val)=="string")
    val = $"\"{val}\""
  return val
}

function mkClassFields(fields){
  return fields.map(@(v) _cfield(v[0], valToStr(v[1]))).reduce(addNewline1)
}

let mkPosFieldInit = @(fieldname, def) $"this.{fieldname} = {valToStr(def)}"

function mkTableFieldInit(fieldname, firstarg, def){
  def = valToStr(def)
  def = (def != null)
    ? $" ?? {def}"
    : ""
  return $"this.{fieldname} = {firstarg}?.{fieldname}{def}"
}
function mkArg(name, def){
  return $"{name} = {def}"
}

function mkCtor(fields, args){
  let firstarg = fields[0][0]
  pp(tostring_r(fields))
  let kwargs_inits = fields.map(@(v) mkTableFieldInit(v[0], firstarg, v[1])).reduce(addNewline3)
  let pargs_inits = fields.map(@(v) mkPosFieldInit(v[0], v[1])).filter(@(_idx, v) v!="" && v!=null).reduce(addNewline3) ?? ""

  let ret = @"
  constructor({0}){
    if (type({1}) == {4}table{4}){
      {2}
    }
    else {
      {3}
    }
    return this
  }".subst(args, firstarg, kwargs_inits, pargs_inits, "\"")
  return ret
}

let defParams = {name=null, verbose=false}
function Dataclass(fields, params = defParams){
  local name = defParams?.name
  name = (type(name)=="string")
    ? $"static __name__ = \"{name}\"\n"
    : ""

  fields = fields.map(unpackfield)
  let args = fields.map(@(v) mkArg(v[0], valToStr(v[1]))).reduce(addComma)
  let classfields = mkClassFields(fields)
  let ctor = mkCtor(fields, args)


  let ret = @"class {
    {0}{1}
    {2}
  }".subst(
    name,
    classfields,
    ctor

  )
  if (params?.verbose)
    print(ret)
  return compilestring($"return {ret}", "dataclass-gen", {type})()
}

if (__name__ == "__main__") {
  let Point2 = Dataclass(["x",["y",0]], {name ="Point2", verbose=true})
  let p2 = Point2(2,3)
  pp(p2.x, p2.y)






}

return Dataclass