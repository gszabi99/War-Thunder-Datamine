module macro shared


def validate_string_argument(arg; name:string; var errors: das_string): bool
  if arg is nothing
    errors := "{name} is not defined"
    return false
  if !(arg is tString)
    errors := "{name} should be string value"
    return false
  return true


def validate_bool_argument(arg; name:string; var errors: das_string): bool
  if arg is nothing
    errors := "{name} is not defined"
    return false
  if !(arg is tBool)
    errors := "{name} should be bool value"
    return false
  return true
