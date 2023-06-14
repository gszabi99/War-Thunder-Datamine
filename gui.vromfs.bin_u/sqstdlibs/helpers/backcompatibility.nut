
/**
 * This provides ability to keep scripts back compatible with older version of client.
 *
 * Example:
 *   New method was bound to script and script starts to using it. To be sure that
 *   scrip will work fine (or at least acceptable), add dump method with same name
 *   with apply_compatibility.
 */


/**
 * Extends squirrel root table with @comp_table.
 * Each value will be pushed to root table only of there is no same
 * key in root table
 */
let function apply_compatibilities(comp_table) {
  local rootTable = getroottable()
  local constTable = getconsttable()
  foreach(key, value in comp_table)
    if (!(key in rootTable) && !(key in constTable))
      rootTable[key] <- value
}
return {
  apply_compatibilities
}