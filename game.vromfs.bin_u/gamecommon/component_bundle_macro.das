module component_bundle_macro shared private
options no_aot

require daslib/ast_boost
require daslib/templates_boost
require daslib/strings_boost
require daslib/defer
require rtti
require ecs


/*
Allows passing bundles of components to helper functions (cross module calls are supported):

[with_bundle(v)]
def func_A(v : tuple<a : int; b : int>; x : int) : int
  return (v.a + v.b) * x

[with_bundle(v)]
def func_b(v : tuple<c : float; d : float>; x : float) : float
  return (v.a + v.b) * x

[es, with_bundle(v)]
def my_ES(v : tuple<
            a : int;
            b : int;
            c : float;
            d : float
          >)
  v.a = func_A(v, 2)
  v.c = func_B(v, 2.0)
*/
[function_macro(name="with_bundle")]
class WithBundleMacro : AstFunctionAnnotation
  [unused_argument(group, args, errors)] def override apply(var func : FunctionPtr; var group : ModuleGroup; args : AnnotationArgumentList; var errors : das_string) : bool
    var bundleArgs : array<string>
    for arg in args
      bundleArgs |> push("{arg.name}")

    apply_to_func(func) <| $(var fun; var arguments; var body; is_es)
      fn_or_es_apply(fun, arguments, body, bundleArgs, is_es)

    if length(bundleArgs) > 0
      macro_error(compiling_program(), func.at, "missing bundle args: {bundleArgs |> join(", ")}")
    return true

  [unused_argument(group, args, progArgs, errors)] def override patch(var func : FunctionPtr; var group : ModuleGroup; args, progArgs : AnnotationArgumentList; var errors : das_string; var astChanged : bool &) : bool
    apply_to_func(func) <| $ [unused_argument(is_es, arguments)] (var fun; var arguments; var body; is_es)
      fn_or_es_restore_fields_and_calls(fun, body, astChanged)
    return true


/*
How it works:

Lets assume we have function:

def func(var v : tuple<a : int; b : int>) : void
  if v.a > 0
    v.b *= 2
    v.a--
    func(v)

APPLY:

1. For each function all bundle arguments are expanded: func(var a : int&; var b : int&)

2. Stub variables for bundles are generated, annotations with info about each bundle are added (fields and index):
  [_bundle_args(v="a,b", v=0)]
  def func(var a : int&; var b : int&)
    var v : tuple<a : int; b : int>?;
    if v.a > 0
      v.b *= 2
      v.a--
      func(v)

3. Stub functions are generated, all bundle parameters are replaced with strings:
  [_bundle_args(v="a,b", v=0)]
  def func__stub(_v : string) : void
    assert(false)

4. Calls with bundle parameters are replaced with stubs. Strings are used to keep info about which bundle was passed:
  ...
  func(v) -> func__stub("v")


INFER (all done in one visitor pass):

1. All stub calls are replaced with normal function calls, while performing parameter checks:
  ...
  func__stub("v") -> func(v.a, v.b)

2. All accesses to bundle tuple fields are replaced with generated parameters, while checking, if they exist in specific bundle
  ...
  func(v.a, v.b) -> func(a, b)

*/

[macro_function]
def fn_or_es_apply(var func; var arguments; var body : ExpressionPtr; var bundleArgs : array<string>; is_es : bool)
  if !is_es && func.result.baseType == Type autoinfer
    macro_error(compiling_program(), func.at, "return type for [with_bundle] functions must be explicitly defined")
    return

  var bundleArgNames : array<string>
  var bundleByFieldName : table<string; string>
  var annArgs : array<tuple<argname : string; argvalue : RttiValue>>
  var stubFuncArgs : array<VariablePtr>;

  var stubLet <- new [[ExprLet() at = func.at, atInit = func.at]]

  var funcArgsTbl : table<string; LineInfo?>
  for fnArg in arguments
    funcArgsTbl["{fnArg.name}"] = unsafe(addr(fnArg.at))

  var i = 0;
  var argIndex = 0;
  while i < length(arguments)
    assume arg = arguments[i]
    var stubFuncArg <- clone_variable(arg)
    let bundleArgName = "{arg.name}"
    let bundleArgIdx = find_index(bundleArgs, bundleArgName)

    if bundleArgIdx != -1
      bundleArgs |> erase(bundleArgIdx)
      if arg._type.baseType != Type tTuple
        macro_error(compiling_program(), arg.at, "bundle argument '{bundleArgName}' must be a tuple")
        continue
      bundleArgNames |> push(bundleArgName)

      var fields : array<string>
      var emplaceIdx = i
      for argName, argType in arg._type.argNames, arg._type.argTypes
        let fieldName = "{argName}"
        let conflictingFuncArgAt = find(funcArgsTbl, fieldName)
        if conflictingFuncArgAt != null
          macro_error(compiling_program(), **conflictingFuncArgAt, "function argument '{fieldName}' shadows component with name '{bundleArgName}.{fieldName}'")
        if key_exists(bundleByFieldName, fieldName)
          let existingBundle = bundleByFieldName[fieldName]
          macro_error(compiling_program(), argType.at, "component with name '{fieldName}' exists both in '{bundleArgName}' and '{existingBundle}' bundles")
        fields |> push(fieldName)
        bundleByFieldName[fieldName] = bundleArgName

        var varType <- clone_type(argType)
        if (arg._type.flags.constant || argType.flags.constant) && !argType.flags.removeConstant
          varType.flags |= TypeDeclFlags constant
        else
          varType.flags |= TypeDeclFlags removeConstant
          varType.flags |= TypeDeclFlags ref
        var variable : VariablePtr <- new [[Variable()
          _type <- varType,
          at=argType.at,
          name := fieldName
        ]]
        arguments |> emplace(variable, ++emplaceIdx)

      annArgs |> emplace <| [[auto bundleArgName, [[RttiValue tString=join(fields, ",")]] ]]
      annArgs |> emplace <| [[auto bundleArgName, [[RttiValue tInt=argIndex]] ]]

      var stubVar <- clone_variable(arg)
      var stubVarType <- new [[TypeDecl() baseType=Type tPointer, at=arg.at]]
      var stubVarFirstType <- clone_type(stubVar._type)
      stubVarType.firstType <- stubVarFirstType
      stubVarType.firstType.flags &= ~(TypeDeclFlags constant)
      stubVarType.flags |= TypeDeclFlags constant
      stubVar._type := null
      stubVar._type <- stubVarType
      stubVar.flags |= VariableFlags generated
      stubLet.variables |> emplace(stubVar)
      stubVar := null

      stubFuncArg._type := null
      stubFuncArg._type <- new [[TypeDecl() baseType=Type tString, at=arg.at]]

      arguments |> erase(i)
      i = emplaceIdx
    else
      i++
    stubFuncArgs |> emplace(stubFuncArg)
    argIndex++

  (body as ExprBlock).list |> emplace(stubLet, 0)
  stubLet := null

  append_annotation(func, "component_bundle_macro", "_bundle_args", annArgs)
  if !is_es
    var stubFunc : FunctionPtr
    if func.result.isVoid
      var tmp <- qmacro_function("{func.name}__stub") <| $($a(stubFuncArgs))
        print("stub!")
        assert(false)
      stubFunc <- tmp
    else
      var tmp <- qmacro_function("{func.name}__stub") <| $($a(stubFuncArgs))
        print("stub!")
        assert(false)
        let result_stub : $t(func.result)? = null
        return *result_stub
      stubFunc <- tmp

    stubFunc.flags |= FunctionFlags noAot
    append_annotation(stubFunc, "component_bundle_macro", "_bundle_args", annArgs)
    for stubFuncArg in stubFunc.arguments
      stubFuncArg.name := "_{stubFuncArg.name}"
      stubFuncArg.flags |= VariableFlags marked_used
    compiling_module() |> add_function(stubFunc)

  for stubArg in stubFuncArgs
    stubArg := null
  stubFuncArgs |> clear()

  var astVisitor = new ReplaceBundleCallsWithStubsAndValidate()
  astVisitor.bundleArgNames <- bundleArgNames
  astVisitor.bundleByFieldName <- bundleByFieldName
  var astVisitorAdapter <- make_visitor(*astVisitor)
  visit(body, astVisitorAdapter)
  astVisitorAdapter := null
  unsafe
    delete astVisitor


class ReplaceBundleCallsWithStubsAndValidate : AstVisitor
  bundleArgNames : array<string>
  bundleByFieldName : table<string; string>

  def override visitExprCall(var expr : smart_ptr<ExprCall>) : ExpressionPtr
    if "{expr.name}" == "make_bundle"
      var bundleNames : array<string>
      for arg in expr.arguments
        if arg is ExprVar
          let argName = "{(arg as ExprVar).name}"
          bundleNames |> push(argName)
      if length(bundleNames) == 0
        return [[ExpressionPtr]]
      return <- new [[ExprConstString() at=expr.at, value := join(bundleNames, ","), genFlags=ExprGenFlags generated]]

    var i = 0
    var hasBundles = false
    while i < length(expr.arguments)
      assume arg = expr.arguments[i]
      if arg is ExprVar && bundleArgNames |> find_index("{(arg as ExprVar).name}") != -1
        var argStub <- new [[ExprConstString() at=arg.at, value := "{(arg as ExprVar).name}", genFlags=ExprGenFlags generated]]
        expr.arguments[i] := null
        expr.arguments[i] <- argStub
        hasBundles = true
      elif arg is ExprConstString && arg.genFlags.generated
        hasBundles = true
      i++
    if hasBundles
      expr.name := "{expr.name}__stub"
    return expr

  def override visitExprVar(var expr : smart_ptr<ExprVar>) : ExpressionPtr
    if key_exists(bundleByFieldName, "{expr.name}")
      let bundleName = bundleByFieldName["{expr.name}"]
      macro_error(compiling_program(), expr.at, "use of bundled component '{expr.name}' without bundle is prohibited, use '{bundleName}.{expr.name}' instead")
    return expr

  def override visitExprLet(var expr : smart_ptr<ExprLet>) : ExpressionPtr
    for variable in expr.variables
      if key_exists(bundleByFieldName, "{variable.name}")
        let bundleName = bundleByFieldName["{variable.name}"]
        macro_error(compiling_program(), variable.at, "local variable '{variable.name}' shadows bundled component '{bundleName}.{variable.name}'")
    return expr


[function_macro(name="_bundle_args")]
class BundleArgsAnn : AstFunctionAnnotation
{}

[macro_function]
def fn_or_es_get_bundles(func)
  var bundles : table<string; array<string>>
  for ann in func.annotations
    if "{ann.annotation.name}" == "_bundle_args"
      for arg in ann.arguments
        if arg.basicType == Type tString
          bundles["{arg.name}"] <- "{arg.sValue}" |> split(",")
  return <- bundles


[macro_function]
def fn_or_es_get_bundle_indices(func)
  var bundles : table<int; string>
  for ann in func.annotations
    if "{ann.annotation.name}" == "_bundle_args"
      for arg in ann.arguments
        if arg.basicType == Type tInt
          bundles[arg.iValue] = "{arg.name}"
  return <- bundles


[macro_function]
def fn_or_es_restore_fields_and_calls(var func; var body; var astChanged : bool&)
  var visitor = new RestoreFieldsAndCallsVisitor()
  visitor.availableBundles <- fn_or_es_get_bundles(func)
  var astVisitorAdapter <- make_visitor(*visitor)
  visit(body, astVisitorAdapter)
  astVisitorAdapter := null
  if visitor.changed
    astChanged = true
  unsafe
    delete(visitor)


[macro_interface]
class RestoreFieldsAndCallsVisitor : AstVisitor
  availableBundles : table<string; array<string>>
  changed : bool = false

  def override visitExprLet(var expr : smart_ptr<ExprLet>) : ExpressionPtr
    for variable in expr.variables
      if key_exists(availableBundles, "{variable.name}")
        variable.name := "_{variable.name}"
        changed = true
    return expr

  def override visitExprField(expr : smart_ptr<ExprField>) : ExpressionPtr
    if expr.value is ExprRef2Value
      var r2v = expr.value as ExprRef2Value
      if r2v.subexpr is ExprVar
        let bundleName = string((r2v.subexpr as ExprVar).name)
        let availableFields = availableBundles |> find(bundleName)
        if availableFields != null
          if *availableFields |> find_index("{expr.name}") != -1
            changed = true
            return new [[ExprVar()
              at=expr.atField,
              name := expr.name
            ]]
          else
            macro_error(compiling_program(), expr.at, "field {expr.name} is not present in bundle {bundleName}")
    return expr

  def override visitExprCall(expr : smart_ptr<ExprCall>) : ExpressionPtr
    let func_name = "{expr.func.name}"
    let postfix = "__stub"
    if !ends_with(func_name, postfix)
      return expr

    var exprClone <- clone_expression(expr)
    var exprCall = exprClone as ExprCall
    var bundles <- fn_or_es_get_bundles(expr.func)
    var bundleIndices <- fn_or_es_get_bundle_indices(expr.func)
    exprCall.name := func_name |> slice(0, length(func_name) - length(postfix))

    var hasErrors = false
    var exprChanged = false

    var i = length(exprCall.arguments) - 1
    while i >= 0
      assume arg = exprCall.arguments[i]
      if key_exists(bundleIndices, i) && arg is ExprConstString && arg.genFlags.generated
        let bundleNames <- "{(arg as ExprConstString).value}" |> split(",")
        var availableFields : table<string; bool>
        for bundleName in bundleNames
          let bundleFields = availableBundles |> find(bundleName)
          if bundleFields != null
            for bundleField in *bundleFields
              availableFields[bundleField] = true
          else
            availableFields[bundleName] = true

        var emplaceIdx = i;
        var missingFields : array<string>
        for field in bundles[bundleIndices[i]]
          var expandedArg : ExpressionPtr <- new [[ExprVar()
            at=arg.at,
            name := field,
            genFlags=ExprGenFlags generated
          ]]
          exprCall.arguments |> emplace(expandedArg, ++emplaceIdx)

          if !key_exists(availableFields, field)
            hasErrors = true
            missingFields |> push(field)

        if length(missingFields) > 0
          if length(bundleNames) == 1
            macro_error(compiling_program(), arg.at, "fields {join(missingFields, ", ")} dont exist in bundle {bundleNames[0]}")
          else
            macro_error(compiling_program(), arg.at, "fields {join(missingFields, ", ")} dont exist in make_bundle({join(bundleNames, ", ")})")

        exprChanged = true
        exprCall.arguments |> erase(i)
      i--

    if hasErrors
      exprCall := null
      exprClone := null
      return expr
    else
      if exprChanged
        changed = true
      return <- exprClone


[macro_function]
def apply_to_func(var func; blk : block<(var func : FunctionPtr; var args : dasvector`smart_ptr`Variable; var body : ExpressionPtr; is_es : bool) : void>)
  var fnBlock = func.body as ExprBlock
  if length(fnBlock.list) > 0
    assume firstBlk = fnBlock.list[0]
    if firstBlk is ExprCall
      let call = firstBlk as ExprCall
      if call.name == "ecs::process_view" && length(call.arguments) > 1 && call.arguments[1] is ExprMakeBlock
        var makeEsBlk := call.arguments[1] as ExprMakeBlock
        var esBlk : ExpressionPtr := makeEsBlk._block
        blk |> invoke(func, (esBlk as ExprBlock).arguments, esBlk, true)
        esBlk := null
        makeEsBlk := null
        return
  blk |> invoke(func, func.arguments, func.body, false)


[call_macro(name="print_bundle")]
class private PrintBundle : AstCallMacro
  [unused_argument(prog, mod)] def override visit(prog : ProgramPtr; mod : Module ?; var call : smart_ptr<ExprCallMacro>) : ExpressionPtr
    var blk <- new [[ExprBlock() at=call.at]]
    for arg in call.arguments
      if arg is ExprVar
        let exprVar = arg as ExprVar
        if exprVar._type.baseType == Type tPointer && exprVar._type.firstType.baseType == Type tTuple
          for compName in exprVar._type.firstType.argNames
            let bundleName = "{exprVar.name}"
            let fullName = "{bundleName}.{compName}"
            var accessExpr <- new [[ExprField()
              value <- new [[ExprVar() name := bundleName]],
              name := compName
            ]]
            var print_expr <- qmacro_expr() <|
              print("  {$v(fullName)} {$e(accessExpr)}")
            blk.list |> emplace(print_expr)
            print_expr := null
            accessExpr := null
    return blk

