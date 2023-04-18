//this file should read version from version.txt, which is included in .cpp and set it to roo
#explicit-this
#no-root-fallback
let { read_text_from_file } = require("dagor.fs")
let f = read_text_from_file("%globalScripts/version.txt")
local version = -1
foreach (l in f.split("\n")) {
  if (l.startswith("script_protocol_version = ")) {
    version = l.slice("script_protocol_version = ".len(), -1).tointeger()
    break
  }
}
return { script_protocol_version = version }
