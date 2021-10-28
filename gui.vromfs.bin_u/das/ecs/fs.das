module fs shared
require DagorFindFiles
require DagorSystem
require ecs

[generic]
def load_folder(path : string) : bool
  var ok = true
  var n = 0
  find_files_in_folder(path, "*.das") <| $(files)
    for file in files
      n += 1
      ok = load_es(file) && ok
  if n == 0
    logerr("folder `{path}` is empty, maybe wrong path")
  return ok

[generic]
def load_optional_folder(path : string) : bool
  var ok = true
  find_files_in_folder(path, "*.das") <| $(files)
    for file in files
      ok = load_es(file) && ok
  return ok