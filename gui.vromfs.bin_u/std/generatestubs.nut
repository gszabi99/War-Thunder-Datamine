local io = require("io")
local {file_exists} = require("dagor.fs")
local {argv} = require("dagor.system")
/*
  allow generate stubs for native modules
  TODO:
    we need return type of function or it is mostly useless even for stubs
    class are not generated yet

*/
local function saveFile(file_path, data){
  assert(type(data) == "string", "data should be string")
  local file = io.file(file_path, "wt+")
  file.writestring(data)
  file.close()
  return true
}

local {get_native_module_names} = require("modules")
local params_names = ["a", "b", "c", "d", "e"].extend(array(10).map(@(_, i) $"var_{i+5}"))
local function mkFunStubStr(func, name=null){
  local infos = func.getfuncinfos()
  local {paramscheck/*, freevars, typecheck*/} = infos
  name = name ?? infos.name
  name = name!=null ? $" {name}" : ""
  local args_string = paramscheck>=0 ? ", ".join(array(paramscheck).map(@(_, i) params_names[i])) : ""
  return name == " constructor"
    ? $"constructor({args_string})\{\}"
    : $"function{name}({args_string})\{\}"
}

const INDENT_SYM = "  "

local function mkStubStr(val, name=null, indent=0){
  local typ = type(val)
  local indentStr = "".join(array(indent, INDENT_SYM))
  local mkStubSt = callee()
  if (["string", "float", "integer", "boolean"].contains(typ))
    return name == null ? val.tostring() : $"{indentStr}{name} = {val.tostring()}"
  if (typ=="function")
    return  $"{indentStr}{mkFunStubStr(val, name)}"
  if (typ=="table"){
    local res = [name!=null ? $"{indentStr}{name} = \{" : $"{indentStr}\{"]
    foreach(k, v in val){
      res.append(mkStubSt(v, k, indent+1))
    }
    res.append($"{indentStr}\}")
    return "\n".join(res)
  }
  if (typ=="class"){
    local res = [name==null ? $"{indentStr}class\{" : $"{indentStr}{name} = class\{"]
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

local mkModuleStub = @(nm) mkStubStr(require(nm), nm)

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
