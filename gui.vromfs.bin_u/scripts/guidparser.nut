let guidRe = ::regexp2(@"^\{?[0-9a-fA-F]{8}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{12}\}?$")


let isGuid = function (str) {
  return guidRe.match(str)
}


let export = {
  isGuid = isGuid
}


return export
