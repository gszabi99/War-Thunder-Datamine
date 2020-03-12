local guidRe = ::regexp2(@"^\{?[0-9a-fA-F]{8}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{12}\}?$")


local isGuid = function (str) {
  return guidRe.match(str)
}


local export = {
  isGuid = isGuid
}


return export
