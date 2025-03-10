















function apply_compatibilities(comp_table) {
  local rootTable = getroottable()
  local constTable = getconsttable()
  foreach(key, value in comp_table) {
    let isRoot = type(value)=="function"
    if (isRoot && !(key in rootTable)) {
      rootTable[key] <- value
      continue
    }
    if (!(key in constTable))
      constTable[key] <- value
  }
}
return {
  apply_compatibilities
}