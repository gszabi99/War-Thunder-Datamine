let io = require("io")
let {file_exists} = require("dagor.fs")
let {argv} = require("dagor.system")
let {get_native_module_names} = require("modules")
/*
  allow generate stubs for native modules
  TODO:
    we need return type of function or it is mostly useless even for stubs
    class are not generated yet

*/
let function saveFile(file_path, data){
  assert(type(data) == "string", "data should be string")
  let file = io.file(file_path, "wt+")
  file.writestring(data)
  file.close()
  return true
}

let params_names = ["a", "b", "c", "d", "e"].extend(array(10).map(@(_, i) $"var_{i+5}"))
local function mkFunStubStr(func, name=null){
  let infos = func.getfuncinfos()
  let {paramscheck/*, freevars, typecheck*/} = infos
  name = name ?? infos.name
  name = name!=null ? $" {name}" : ""
  let args_string = paramscheck>=0 ? ", ".join(array(paramscheck).map(@(_, i) params_names[i])) : ""
  return name == " constructor"
    ? $"constructor({args_string})\{\}"
    : $"function{name}({args_string})\{\}"
}

const INDENT_SYM = "  "

let function mkStubStr(val, name=null, indent=0){
  let typ = type(val)
  let indentStr = "".join(array(indent, INDENT_SYM))
  let mkStubSt = callee()
  if (["string", "float", "integer", "boolean"].contains(typ))
    return name == null ? val.tostring() : $"{indentStr}{name} = {val.tostring()}"
  if (typ=="function")
    return  $"{indentStr}{mkFunStubStr(val, name)}"
  if (typ=="table"){
    let res = [name!=null ? $"{indentStr}{name} = \{" : $"{indentStr}\{"]
    foreach(k, v in val){
      res.append(mkStubSt(v, k, indent+1))
    }
    res.append($"{indentStr}\}")
    return "\n".join(res)
  }
  if (typ=="class"){
    let res = [name==null ? $"{indentStr}class\{" : $"{indentStr}{name} = class\{"]
    foreach(k, v in val){
      res.append(mkStubSt(v, k, indent+1))
    }
    res.append($"{indentStr}\}")
    return "\n".join(res)
  }
  if (typ == "array") {
    if (name=="argv")//hack for bad dagor.system api
      return $"{indentStr}argv = []"
    return name == null
      ? $"{indentStr}[{", ".join(val.map(@(j) mkStubSt(j, null, 0)))}]"
      : $"{indentStr}{name} = [{", ".join(val.map(@(j) mkStubSt(j, null, 0)))}]"
  }
  return name == null ? $"\"{typ}\"" : $"{indentStr}{name} = \"{typ}\""
}

let mkModuleStub = @(nm) mkStubStr(require(nm), nm)

local function generateStubs(stubsDir=""){
  stubsDir = stubsDir ?? ""
  foreach(nm in get_native_module_names()) {
    local path = stubsDir=="" ? nm : $"{stubsDir}/{nm}"
    if (file_exists(path))
      path = $"{path}.gen"
    print($"generating stub for '{nm}' in path '{path}'\n")
    saveFile(path, $"return {mkStubStr(require(nm))}")
  }
  print("all done\n")
}

if (__name__ == "__main__" && argv.contains("-build"))
  generateStubs("../stubs")

return {
  mkModuleStub
  generateStubs
}
