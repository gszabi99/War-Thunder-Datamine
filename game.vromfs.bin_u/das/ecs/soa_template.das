
module soa_template shared private

require ecs
require strings
require daslib/ast_boost
require daslib/templates_boost


let show_completion = true


[function_macro(name="soa_es")]
class SoaEsCallMacro : AstFunctionAnnotation

  [unused_argument(group, args)] def override apply(var func : FunctionPtr; var group : ModuleGroup; args : AnnotationArgumentList; var errors : das_string) : bool
    if show_completion && is_in_completion()
      return true
    var usedTypes : table<string; bool>
    var toReplace : array<tuple<name : string; fields : array<string>>>
    var addedFields : table<string; bool>
    var i = 0
    while i < length(func.arguments)
      assume arg = func.arguments[i]
      if arg._type.baseType == Type tStructure && arg._type.structType.name |> ends_with("_SOA")
        let desc = arg._type |> describe(false, false, true)
        if usedTypes |> key_exists(desc)
          errors := "Multiple arguments with same soa type '{desc}'"
          return false
        usedTypes[desc] = true
        for field in arg._type.structType.fields
          var fieldType <- clone_type(field._type)
          if arg._type.flags.constant
            fieldType.flags |= TypeDeclFlags constant
          func.arguments |> emplace_new <| new [[Variable() at=arg.at,
            name := field.name,
            _type <- fieldType,
            _aka := "{field.name}_SOA"
          ]]
          addedFields[string(field.name)] = true
        toReplace |> emplace <| [[auto string(arg.name), [{ for f in arg._type.structType.fields; string(f.name) }] ]]
        func.arguments |> erase(i)
      else
        i += 1
    var usedNames : table<string; bool>
    for replace in toReplace
      replate_index_and_field(replace.name, replace.fields, func.body, usedNames)

    i = 0
    while i < length(func.arguments)
      assume arg = func.arguments[i]
      if addedFields |> key_exists(string(arg.name)) && !key_exists(usedNames, string(arg.name))
        func.arguments |> erase(i)
      else
        i += 1
    return true


[macro_function]
def replate_index_and_field(prefix : string; var fields : array<string>; blk : ExpressionPtr; var usedNames : table<string; bool>)
  var astVisitor = new ReplaceIndexAndFieldsVisitor(prefix, fields)
  var astVisitorAdapter <- make_visitor(*astVisitor)
  visit(blk, astVisitorAdapter)
  for n in keys(astVisitor.usedNames)
    usedNames[n] = true
  astVisitorAdapter := null
  unsafe
    delete astVisitor


class ReplaceIndexAndFieldsVisitor : AstVisitor
  it_prefix : string
  fields : array<string>
  usedNames : table<string; bool>

  def ReplaceIndexAndFieldsVisitor(prefix : string; var fields_ : array<string>)
    it_prefix = prefix
    fields <- fields_

  def override visitExprField(expr : smart_ptr<ExprField>) : ExpressionPtr
    if expr.value is ExprAt
      assume at = expr.value as ExprAt
      if (at.subexpr is ExprVar)
        if (at.subexpr as ExprVar).name == it_prefix
          let ename = string(expr.name)
          usedNames[ename] = true
          return <- new [[ExprAt()
            at=expr.at,
            subexpr <- new [[ExprVar() at=expr.at, name := ename]],
            index <- clone_expression(at.index)
            ]]
    return expr

  def override visitExprCall(expr : smart_ptr<ExprCall>) : ExpressionPtr
    let argsNum = length(expr.arguments)
    if (expr.name == "length") && argsNum == 1
      assume arg = expr.arguments[0]
      if (arg is ExprVar)
        if (arg as ExprVar).name == it_prefix
          var len <- clone_expression(expr)
          var lenCall = len as ExprCall
          usedNames[fields[0]] = true
          lenCall.arguments[0] := null
          lenCall.arguments[0] <- new [[ExprVar() at=arg.at, name := fields[0]]]
          return len
    elif ((argsNum == 2 && (expr.name == "push" || expr.name == "push_clone" || expr.name == "emplace" || expr.name == "erase"))
      || (argsNum == 1 && expr.name == "clear"))
      assume arg = expr.arguments[0]
      if (arg is ExprVar)
        if (arg as ExprVar).name == it_prefix
          var pushExpr <- clone_expression(expr)
          var pushCall = pushExpr as ExprCall
          pushCall.arguments |> erase(0)
          for field in fields
            pushCall.arguments |> emplace_new <| new [[ExprVar()
              at=arg.at,
              name := field
            ]]
            usedNames[field] = true
          return pushExpr
    return expr

  def override visitExprFor(expr : smart_ptr<ExprFor>) : ExpressionPtr
    var soa_index = -1
    for index, its in range(100500), expr.sources
      if (its is ExprVar)
        if (its as ExprVar).name == it_prefix
          soa_index = index
          break
    if soa_index != -1
      let itPrefix = string(expr.iterators[soa_index])
      var newForExpr <- clone_expression(expr)
      var newFor = newForExpr as ExprFor
      newFor.sources |> erase(soa_index)
      newFor.iterators |> erase(soa_index)
      newFor.iteratorsAt |> erase(soa_index)
      newFor.iteratorsAka |> erase(soa_index)
      var names2 <- collect_and_replace_iterator_fields(itPrefix, newFor.body)
      if names2 |> length == 0
        names2 |> push <| fields[0]
      for itn in names2
        let si = newFor.iterators |> length()
        newFor.iterators |> resize(si + 1)
        newFor.iterators[si] := "{itPrefix}_{itn}"
        newFor.iteratorsAka |> resize(si + 1)
        newFor.iteratorsAka[si] := ""
        newFor.iteratorsAt |> push(expr.iteratorsAt[soa_index])
        var nsrc <- new [[ExprVar()
          at=expr.sources[soa_index].at,
          name := itn
        ]]
        usedNames[itn] = true
        newFor.sources |> emplace(nsrc)
      newFor.iteratorVariables |> clear()

      return newForExpr
    return expr



[structure_macro(name=soa_template)]
class SoaTemplateStructMacro : AstStructureAnnotation

  [unused_argument(group, args)] def override apply(var st : StructurePtr; var group : ModuleGroup; args : AnnotationArgumentList; var errors : das_string) : bool
    if st.fields.length == 0
      errors := "soa macro expects at least one field"
      return false
    if show_completion && is_in_completion()
      var tdef <- new [[TypeDecl()
          at=st.at,
          baseType = Type tArray,
          alias := "{st.name}_SOA",
          firstType <- new [[TypeDecl() at=st.at,
              baseType = Type tStructure,
              structType = get_ptr(st)
          ]]
      ]]
      compiling_module() |> add_alias(tdef)
      return true
    // soa
    var stype <- clone_structure(get_ptr(st))
    stype.name := "{stype.name}_SOA"

    var t = get_ptr(stype)
    for fld in t.fields
      fld._type := make_field_type(fld, errors)

    let cmdArgs <- get_command_line_arguments()
    var checkSizes = !is_in_aot()
    for idx in range(length(cmdArgs) - 1)
      if cmdArgs[idx] == "-sConfig"
        checkSizes = cmdArgs[idx + 1] == "dev"

    // push
    var push_op <- make_named_call(st, stype, "push", "push", /*isConst*/true, checkSizes)
    compiling_module() |> add_generic(push_op)
    // push_clone
    // TODO: add this function if need it
    // var push_clone_op <- make_named_call(st, stype, "push_clone", "push_clone", true)
    // compiling_module() |> add_function(push_clone_op)
    // erase
    var erase_op <- make_erase(st, stype, checkSizes)
    compiling_module() |> add_function(erase_op)
    // emplace
    var emplace_op <- make_named_call(st, stype, "emplace", "emplace", /*isConst*/false, checkSizes)
    compiling_module() |> add_function(emplace_op)
    // clear
    var clear_op <- make_clear(st, stype, checkSizes)
    compiling_module() |> add_function(clear_op)

    compiling_module() |> add_structure(stype)
    return true

  def make_field_type(fld : FieldDeclaration; var errors : das_string) : TypeDeclPtr
    if length(fld._type.dim) > 0
      errors := "{errors}\nunsupported type {describe(fld._type)}"
      return fld._type

    if fld._type.baseType == Type tFloat
      return typeinfo(ast_typedecl type<ecs::FloatList>)

    if fld._type.baseType == Type tBool
      return typeinfo(ast_typedecl type<ecs::BoolList>)

    if fld._type.baseType == Type tInt
      return typeinfo(ast_typedecl type<ecs::IntList>)

    if fld._type.baseType == Type tHandle
      if fld._type.annotation.name == "EntityId" && fld._type.annotation._module.name == "ecs"
        return typeinfo(ast_typedecl type<ecs::EidList>)

    errors := "{errors}\nunsupported type {describe(fld._type)}"
    return fld._type

  def make_any_named_call(st, stype : StructurePtr; var argT : TypeDeclPtr; fnName, callName : string; argField, check_sizes : bool) : FunctionPtr
    var pushOp <- new [[Function() at=st.at, atDecl=st.at, name := fnName]]
    pushOp.flags |= FunctionFlags generated
    pushOp.result <- new [[TypeDecl() baseType=Type tVoid, at=st.at]]
    var pushBody <- new [[ExprBlock() at=st.at]]
    if check_sizes && length(st.fields) > 1
      for idx, fld in iter_range(st.fields), st.fields
        if idx > 0
          var compareLen1 <- new [[ExprCall() at=st.at, name := "length"]]
          compareLen1.arguments |> emplace_new <| new [[ExprVar() at=st.at, name := st.fields[0].name]]

          var compareLen2 <- new [[ExprCall() at=st.at, name := "length"]]
          compareLen2.arguments |> emplace_new <| new [[ExprVar() at=st.at, name := fld.name]]

          var compalreLens <- new [[ExprOp2()
            at=st.at,
            op := "==",
            left <- compareLen1,
            right <- compareLen2
          ]]

          var pushVerify <- new [[ExprAssert() at=st.at]]
          pushVerify.arguments |> emplace_new <| compalreLens
          pushVerify.arguments |> emplace_new <| new [[ExprConstString() at=st.at, value := "length(\"{st.fields[0].name}\") != length(\"{fld.name}\")"]]
          pushBody.list |> emplace(pushVerify)

    for fld in st.fields

      var pushCall <- new [[ExprCall() at=st.at, name := callName]]
      pushCall.arguments |> emplace_new <| new [[ExprVar() at=st.at, name := fld.name]]
      if argT == null
        pass
      elif argField
        pushCall.arguments |> emplace_new <| new [[ExprField() at=st.at,
            value <- new [[ExprVar() at=st.at, name := "arg"]],
            name := fld.name,
            fieldFlags = ExprFieldFieldFlags no_promotion
        ]]
      else
        pushCall.arguments |> emplace_new <| new [[ExprVar() at=st.at, name := "arg"]]
      pushBody.list |> emplace(pushCall)
    if argT != null
      pushOp.arguments |> emplace_new <| new [[Variable()
        name := "arg",
        at=st.at,
        _type <- argT
      ]]
    for fld in stype.fields
      pushOp.arguments |> emplace_new <| new [[Variable()
        name := fld.name,
        at=fld.at,
        _type <- clone_type(fld._type)
      ]]
    pushOp.body <- pushBody
    return <- pushOp

  def make_erase(st, stype : StructurePtr; check_sizes : bool)
    var argT <- new [[TypeDecl() baseType=Type tInt, at=st.at]]
    return <- make_any_named_call(st, stype, argT, "erase", "erase", false, check_sizes)

  def make_clear(st, stype : StructurePtr; check_sizes : bool)
    var argT : TypeDeclPtr
    return <- make_any_named_call(st, stype, argT, "clear", "clear", false, check_sizes)

  def make_named_call(st, stype : StructurePtr; fnName, callName : string; isConst : bool; check_sizes : bool) : FunctionPtr
    var argT <- new [[TypeDecl() baseType=Type tStructure, at=st.at, structType=get_ptr(st), flags= isConst ? TypeDeclFlags constant : bitfield(0)]]
    return <- make_any_named_call(st, stype, argT, fnName, callName, true, check_sizes)


class CollectAndReplaceIteratorFields : AstVisitor
  prefix : string
  names : table<string; bool>
  def CollectAndReplaceIteratorFields(prefix_ : string)
    prefix = prefix_
  def override visitExprField(expr : smart_ptr<ExprField>) : ExpressionPtr
    if expr.value is ExprVar
      if (expr.value as ExprVar).name == prefix
        let ename = string(expr.name)
        names[ename] = true
        return <- new [[ExprVar() at=expr.at, name := "{prefix}_{ename}"]]
    return expr


[macro_function]
def collect_and_replace_iterator_fields(prefix : string; blk : ExpressionPtr) : array<string>
  var names : array<string>
  var astVisitor = new CollectAndReplaceIteratorFields(prefix)
  var astVisitorAdapter <- make_visitor(*astVisitor)
  visit(blk, astVisitorAdapter)
  for n in keys(astVisitor.names)
    names |> push(n)
  astVisitorAdapter := null
  unsafe
    delete astVisitor
  return <- names
