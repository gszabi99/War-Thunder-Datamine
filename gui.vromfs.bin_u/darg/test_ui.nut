let {exit, get_arg_value_by_name} = require("dagor.system")

function testUi(entry){
  if (entry==null)
    return true
  if (type(entry)=="function")
    entry=entry()
  let t = type(entry)
  if (t=="table" || t=="class") {
    if ("children" not in entry)
      return true
    if ("array"==type(entry.children)) {
      foreach(child in entry.children) {
        if (!testUi(child))
          return false
      }
      return true
    }
    return testUi(entry.children)
  }
  return false
}

function test(){
  let entryPoint = get_arg_value_by_name("ui")
  if (entryPoint==null) {
    println($"Usage: csq {__FILE__} -ui:<path_to_darg_ui.nut>")
    exit(0)
  }
  println($"starting test for '{entryPoint}'...")
  if (!testUi(require(entryPoint))){
    println("failed to run")
    exit(1)
  }
  println("all ok")
}

if (__name__ == "__main__") {
  test()
}

return {testUi, test}