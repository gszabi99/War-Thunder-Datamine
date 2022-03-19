local fieldEditText = require("components/apFieldEditText.nut")
local fieldBoolCheckbox = require("components/apFieldBoolCheckbox.nut")

local perCompEdits = {}

local perSqTypeCtors = {
  string  = fieldEditText
  integer = fieldEditText
  float   = fieldEditText
  Point2  = fieldEditText
  Point3  = fieldEditText
  DPoint3 = fieldEditText
  Point4  = fieldEditText
  IPoint2 = fieldEditText
  IPoint3 = fieldEditText
  E3DCOLOR= fieldEditText
  bool    = fieldBoolCheckbox
}

local function registerPerCompPropEdit(compName, ctor) {
  perCompEdits[compName] <- ctor
}

local function registerPerSqTypePropEdit(compName, ctor) {
  perSqTypeCtors[compName] <- ctor
}
local getCompNamePropEdit = @(compName) perCompEdits?[compName]
local getCompSqTypePropEdit = @(typ) perSqTypeCtors?[typ]

return {registerPerCompPropEdit, registerPerSqTypePropEdit, getCompSqTypePropEdit, getCompNamePropEdit}