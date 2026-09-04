















































from "types" import Array, String

let pp = @(...) print(" ".join(vargv.append("\n")))

function unpackfield(field): array {
  local def = null
  if (field instanceof Array) {
    def = field[1]
    field = field[0]
  }
  return [field, def]
}
function _cfield(fieldname, def): string {
  return $"{fieldname} = {def}"
}
function mkAddNewline(indent=""): function {
  return @(a,b) $"{a}\n{indent}{b}"
}

let addComma = @(a,b): string ", ".concat(a,b)


let addNewline1 = mkAddNewline("  ")

let addNewline3 = mkAddNewline("      ")

function valToStr(val){
  assert(["string","null","float","integer", "bool"].contains(type(val)), "only simple immutable types currently supported")
  if (val instanceof String)
    val = $"\"{val}\""
  return val
}

function mkClassFields(fields){
  return fields.map(@(v) _cfield(v[0], valToStr(v[1]))).reduce(addNewline1)
}

let mkPosFieldInit = @(fieldname, _def): string $"this.{fieldname} = {fieldname}"

function mkTableFieldInit(fieldname, firstarg, def): string {
  def = valToStr(def)
  def = (def != null)
    ? $" ?? {def}"
    : ""
  return $"this.{fieldname} = {firstarg}?.{fieldname}{def}"
}
function mkArg(name, def): string {
  return $"{name} = {def}"
}

function mkCtor(fields, args): string {
  let firstarg = fields[0][0]
  let kwargs_inits = fields.map(@(v) mkTableFieldInit(v[0], firstarg, v[1])).reduce(addNewline3)
  let pargs_inits = fields.map(@(v) mkPosFieldInit(v[0], v[1])).reduce(addNewline3) ?? ""

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
  local name = params?.name
  name = (name instanceof String)
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