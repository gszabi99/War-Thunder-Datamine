options no_unused_function_arguments = false
options no_aot=true//currently, as of 08.10.2021 there is a bug in AOT codegen for E3DCOLOR
module ecs_template shared private
require ecs
require DagorMath
require DagorSystem
require daslib/strings_boost
require daslib/templates
require daslib/templates_boost
require daslib/ast_boost
require daslib/defer
require daslib/functional

bitfield TemplateComponentFlags
  TRACKED
  REPLICATED
  IGNORED

def private template_flags(annotations : AnnotationArgumentList)
  var ret:TemplateComponentFlags
  for a in annotations
    if a.basicType != Type tBool
      continue
    if eq(a.name, "t")
      ret |= TemplateComponentFlags TRACKED
    elif eq(a.name, "tr") || eq(a.name, "rt")
      ret |= (TemplateComponentFlags TRACKED) | (TemplateComponentFlags REPLICATED)
    elif eq(a.name, "r")
      ret |= (TemplateComponentFlags REPLICATED)
    elif eq(a.name, "i")
      ret |= (TemplateComponentFlags IGNORED)
  return ret

def private is_undef(arg)
  return (arg is tBool) || (arg is tString)

def private is_undef(annotations : AnnotationArgumentList)
  return is_undef(find_arg("undef", annotations))

def set_undef(var t: CreatingTemplate; f:TemplateComponentFlags; fieldName,typeName:string)
  set_undef(t, uint(f), fieldName, typeName)
def set(var t: CreatingTemplate; f:TemplateComponentFlags; fieldName:string; v)
  set(t, uint(f), fieldName, v)

def follow_the_yellow_brick_road ( expr:ExpressionPtr ) : ExpressionPtr
  if expr is ExprRef2Value
    return (expr as ExprRef2Value).subexpr |> follow_the_yellow_brick_road
  elif expr is ExprVar
    let ev = expr as ExprVar
    if !ev.varFlags.local && !ev.varFlags.argument && !ev.varFlags._block
      if ev.variable!=null && ev.variable._type.flags.constant && ev.variable.init!=null
        return ev.variable.init |> follow_the_yellow_brick_road
  return expr

[template(result)]
def get_eval_any ( econst:ExpressionPtr; result:auto(TT); var errors:das_string; var any_errors:bool& ) : TT
  if econst is ExprCall
    if econst.flags.noSideEffects
      var ok = true
      var res : variant<dummy:float4;id:TT - &>
      unsafe
        res.dummy = eval_single_expression(econst,ok)
      if !ok
        errors := "{errors}\nexpression failed to evaluate {describe(econst)}"
        any_errors = true
      unsafe
        return res.id
  errors := "{errors}\nunsupported initializer {describe(econst)}"
  any_errors = true
  return [[TT]]

def get_const_expr ( expr:ExpressionPtr ) : ExpressionPtr
  if expr == null
    return [[ExpressionPtr]]
  let econst <- expr |> follow_the_yellow_brick_road
  return econst |> is_expr_const ? econst : [[ExpressionPtr]]

def get_templ_const ( expr:ExpressionPtr; var errors:das_string; var any_errors:bool&; defVal:auto(valT) )
  if expr == null
    return defVal
  let econst <- expr |> follow_the_yellow_brick_road
  return econst |> get_eval_any(type<valT -const>, errors, any_errors)

def def_string(v:das_string?)
  return v != null ? string(*v) : ""

[structure_macro(name=ecs_template)]
class CreateTemplateAnnotation : AstStructureAnnotation
  def override apply ( var st:StructurePtr; var group:ModuleGroup; args:AnnotationArgumentList; var errors : das_string ) : bool
    for field in st.fields
      let arg = find_arg("undef", field.annotation)
      if is_undef(arg)
        let typeName = describe(field._type)
        let undefType = field._type.baseType == Type tVoid || field._type.baseType == Type autoinfer
        field._type := null
        if undefType && !(arg is tString)
          field._type <- new [[TypeDecl() baseType = Type tInt]]
        else
          field._type <- new [[TypeDecl() baseType = Type tInt, alias := (arg ?as tString) ?? typeName]]
        field.init := null
    return true

  def override finish ( var st:StructurePtr; var group:ModuleGroup; args:AnnotationArgumentList; var errors : das_string ) : bool
    if is_in_aot() || find_index_if(each(args), $(a:AnnotationArgument) {return a.basicType == Type tString && eq(a.name, "tag") && filter_pass_component_tag(group, a.sValue);}) != -1
      st.fields |> clear()
      return true
    var parents:array<string>
    defer_delete(parents)
    var hadErrors = false
    for a in args
      if eq(a.name, "extends")
        if a.basicType != Type tString
          errors := "{errors}\nextends argument has to be of string type"
          hadErrors = true
        else
          parents |> emplace(string(a.sValue))
    createTemplate2(group, ecs_hash(string(st.at.fileInfo.name)), string(st.name), parents) <| $(var cmp:CreatingTemplate)
      for field in st.fields
        //filter out
        //if field.annotation |> each |> map ( @(a) : bool => a.basicType == Type tString && eq(a.name, "tag") && filter_pass_component_tag(cmp, a.sValue)) |> any//map-reduce is a bit slower
        if find_index_if(each(field.annotation), $(a:AnnotationArgument) {return a.basicType == Type tString && eq(a.name, "tag") && filter_pass_component_tag_templ(cmp, a.sValue);}) != -1
          continue
        let f = template_flags(field.annotation)
        let undefType = is_undef(field.annotation)
        let fieldName = string(field.name);
        if undefType
          set_undef(cmp, f, fieldName, string(field._type.alias))
        else
          let econst <- field.init |> get_const_expr
          if field._type.baseType==Type tBool
            set(cmp, f, fieldName, (econst ?as ExprConstBool)?.value ?? false)
          elif field._type.baseType==Type tInt
            set(cmp, f, fieldName, (econst ?as ExprConstInt)?.value ?? 0)
          elif field._type.baseType==Type tInt2
            set(cmp, f, fieldName, (econst ?as ExprConstInt2)?.value ?? int2(0))
          elif field._type.baseType==Type tInt3
            set(cmp, f, fieldName, (econst ?as ExprConstInt3)?.value ?? int3(0))
          elif field._type.baseType==Type tFloat
            set(cmp, f, fieldName, (econst ?as ExprConstFloat)?.value ?? 0.)
          elif field._type.baseType==Type tFloat2
            set(cmp, f, fieldName, (econst ?as ExprConstFloat2)?.value ?? float2(0.))
          elif field._type.baseType==Type tFloat3
            set(cmp, f, fieldName, (econst ?as ExprConstFloat3)?.value ?? float3(0.))
          elif field._type.baseType==Type tFloat4
            set(cmp, f, fieldName, (econst ?as ExprConstFloat4)?.value ?? float4(0.))
          elif field._type.baseType==Type tFloat4
            set(cmp, f, fieldName, (econst ?as ExprConstFloat4)?.value ?? float4(0.))
          elif field._type.baseType==Type tString
            set(cmp, f, fieldName, def_string((econst ?as ExprConstString)?.value))
          elif field._type.baseType==Type tHandle
            if eq(field._type.annotation.name, "EntityId")
              set(cmp, f, fieldName, INVALID_ENTITY_ID)
            elif eq(field._type.annotation.name, "E3DCOLOR")
              set(cmp, f, fieldName, get_templ_const(field.init,errors,hadErrors, E3DCOLOR(uint4(0))) )
            else
              logerr("Template {st.name} declared at {st.at.fileInfo.name} has field <{fieldName}> of unknown handleType <describe(field._type)>")
    return !hadErrors
