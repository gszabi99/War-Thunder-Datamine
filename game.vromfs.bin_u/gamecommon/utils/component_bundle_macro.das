module component_bundle_macro shared private
options no_aot

require DagorSystem
require daslib/strings_boost
require daslib/ast_boost
require rtti




























struct private BundleMacroResult
  idx : int
  fields : array<string>

[macro_function]
def get_or_expand_bundle_args(var func; var arguments; var body : ExpressionPtr; var funcName : string; var bundleArgName : string; is_es : bool; get_only : bool) : BundleMacroResult
  var bundleArgIdx = -1
  var bundleFieldNames : array<string>
  var bundleFieldNamesValidationSet : table<string; bool>

  
  if !is_es
    for ann in func.annotations
      let annName = "{ann.annotation.name}"
      if annName == "_bundle_args"
        for arg in ann.arguments
          if arg.basicType == Type.tString
            bundleFieldNames <- "{arg.sValue}" |> split(",")
          elif arg.basicType == Type.tInt
            bundleArgIdx = arg.iValue
  if bundleArgIdx >= 0 || get_only
    return <- BundleMacroResult(idx = bundleArgIdx, fields <- bundleFieldNames)

  var inscope stubLet <- new ExprLet(at = func.at, atInit = func.at)

  let inCompletion = is_in_completion()
  let isValidationRequired = get_DAGOR_DBGLEVEL() > 0 || is_in_aot() || inCompletion

  var funcArgsTbl : table<string; bool>
  if isValidationRequired
    for fnArg in arguments
      funcArgsTbl.insert("{fnArg.name}", true)

  
  var i = 0
  while i < length(arguments)
    assume arg = arguments[i]
    if "{arg.name}" != bundleArgName
      i++
      continue

    if arg._type.baseType != Type.tTuple
      macro_error(compiling_program(), arg.at, "bundle argument '{bundleArgName}' must be a tuple")
      break

    bundleArgIdx = i
    var emplaceIdx = i
    for argName, argType in arg._type.argNames, arg._type.argTypes
      let fieldName = "{argName}"
      if isValidationRequired
        if key_exists(funcArgsTbl, fieldName)
          macro_error(compiling_program(), argType.at, "function argument '{fieldName}' shadows component with name '{bundleArgName}.{fieldName}'")
        if key_exists(bundleFieldNamesValidationSet, fieldName)
          macro_error(compiling_program(), argType.at, "duplicate component with name '{fieldName}'")
        bundleFieldNamesValidationSet.insert(fieldName, true)
      bundleFieldNames |> push(fieldName)

      if true
        var inscope varType <- clone_type(argType)
        if (arg._type.flags.constant || argType.flags.constant) && !argType.flags.removeConstant
          varType.flags |= TypeDeclFlags.constant
        else
          varType.flags |= TypeDeclFlags.removeConstant
          varType.flags |= TypeDeclFlags.ref
        var inscope variable : VariablePtr <- new Variable(
          _type <- varType,
          at = argType.at,
          name := fieldName
        )
        arguments |> emplace(variable, ++emplaceIdx)

    if inCompletion
      var inscope stubVar <- clone_variable(arg)
      var inscope stubVarType <- new TypeDecl(baseType = Type.tPointer, at = arg.at)
      move_new(stubVarType.firstType) <| clone_type(stubVar._type)
      stubVarType.firstType.flags &= ~(TypeDeclFlags.constant)
      stubVarType.flags |= TypeDeclFlags.removeConstant
      stubVar._type := stubVarType
      stubVar.flags |= VariableFlags.generated
      stubLet.variables |> emplace(stubVar)
    arguments |> erase(i)

  if length(stubLet.variables) > 0
    (body as ExprBlock).list |> emplace(stubLet, 0)

  if !is_es
    var annArgs : array<tuple<argname : string; argvalue : RttiValue>>
    annArgs |> emplace <| (bundleArgName, RttiValue(tString = join(bundleFieldNames, ",")))
    annArgs |> emplace <| (bundleArgName, RttiValue(tInt = bundleArgIdx))
    append_annotation(func, "component_bundle_macro", "_bundle_args", annArgs)

  var astVisitor = new ResolveBundlesVisitor()

  
  astVisitor.bundleArgName <- bundleArgName
  astVisitor.bundleFieldNamesSetForValidation <- bundleFieldNamesValidationSet
  astVisitor.bundleFieldNames <- bundleFieldNames
  astVisitor.thisFuncName = funcName
  astVisitor.thisFuncBundleArgIdx = bundleArgIdx

  var inscope astVisitorAdapter <- make_visitor(*astVisitor)
  visit(body, astVisitorAdapter)
  bundleArgName <- astVisitor.bundleArgName
  bundleFieldNames <- astVisitor.bundleFieldNames

  unsafe
    delete astVisitor
  return <- BundleMacroResult(idx = bundleArgIdx, fields <- bundleFieldNames)


[macro_function]
def apply_to_func(var func; blk : block<(var func : FunctionPtr; var args : dasvector`smart_ptr`Variable; var body : ExpressionPtr; is_es : bool) : void>)
  var fnBlock = func.body as ExprBlock
  if length(fnBlock.list) > 0
    assume firstBlk = fnBlock.list[0]
    if firstBlk is ExprCall
      let call = firstBlk as ExprCall
      if call.name == "ecs::process_view" && length(call.arguments) > 1 && call.arguments[1] is ExprMakeBlock
        var makeEsBlk = call.arguments[1] as ExprMakeBlock
        var inscope esBlk : ExpressionPtr := makeEsBlk._block
        blk |> invoke(func, (esBlk as ExprBlock).arguments, esBlk, true)
        return
  blk |> invoke(func, func.arguments, func.body, false)


def find_unique_function_in_all_modules(name : string)
  var inscope res : FunctionPtr
  var count = 0
  for_each_function(compiling_module(), name) <| $(func)
    res := func
    count ++
  if count == 0
    compiling_program() |> program_for_each_module() <| $(mod)
      for_each_function(mod, name) <| $(func)
        res := func
        count ++
  if count > 1
    return <- default<FunctionPtr>
  return <- res


class ResolveBundlesVisitor : AstVisitor
  bundleArgName : string
  bundleFieldNames : array<string>
  bundleFieldNamesSetForValidation : table<string; bool>
  thisFuncName : string
  thisFuncBundleArgIdx : int

  def override visitExprCall(var expr : smart_ptr<ExprCall>) : ExpressionPtr
    var i = 0
    var bundlePassedAt = -1
    while i < length(expr.arguments)
      assume arg = expr.arguments[i]
      if arg is ExprVar && "{(arg as ExprVar).name}" == bundleArgName
        if bundlePassedAt >= 0
          macro_error(compiling_program(), arg.at, "bundle argument passed twice")
        else
          bundlePassedAt = i
      i++

    if bundlePassedAt < 0
      return <- expr

    let fnName = "{expr.name}"
    var inscope fn <- find_unique_function_in_all_modules(fnName)
    var res : BundleMacroResult
    if thisFuncName == fnName
      res.idx = thisFuncBundleArgIdx
      res.fields := bundleFieldNames
    elif fn == null
      macro_error(compiling_program(), expr.at, "failed to find function '{fnName}'")
      return <- expr
    else
      res <- get_or_expand_bundle_args(fn, fn.arguments, fn.body, fnName, bundleArgName, false, true)
    if res.idx < 0
      macro_error(compiling_program(), expr.at, "calling function '{fnName}' which does not have bundle args")
      return <- expr
    if res.idx != bundlePassedAt
      macro_error(compiling_program(), expr.at, "bundle parameter passed to '{fnName}' at invalid index {bundlePassedAt} while expected at {res.idx}")
      return <- expr

    assume bundleArg = expr.arguments[res.idx]
    var emplaceIdx = res.idx
    for fieldName in res.fields
      if true
        var inscope expandedArg : ExpressionPtr <- new ExprVar(
          at = bundleArg.at,
          name := fieldName,
          genFlags = ExprGenFlags.generated
        )
        expr.arguments |> emplace(expandedArg, ++emplaceIdx)
    expr.arguments |> erase(res.idx)
    return <- expr

  def override visitExprField(var expr : smart_ptr<ExprField>) : ExpressionPtr
    if expr.value is ExprVar
      let bundleName = string((expr.value as ExprVar).name)
      if bundleName == bundleArgName
        if find_index(bundleFieldNames, "{expr.name}") != -1
          return <- new ExprVar(
            at = expr.atField,
            name := expr.name
          )
        else
          macro_error(compiling_program(), expr.at, "field {expr.name} is not present in bundle {bundleName}")
    return <- expr

  def override visitExprVar(var expr : smart_ptr<ExprVar>) : ExpressionPtr
    if key_exists(bundleFieldNamesSetForValidation, "{expr.name}")
      macro_error(compiling_program(), expr.at, "use of bundled component '{expr.name}' without bundle is prohibited, use '{bundleArgName}.{expr.name}' instead")
    return <- expr

  def override visitExprLet(var expr : smart_ptr<ExprLet>) : ExpressionPtr
    for variable in expr.variables
      if key_exists(bundleFieldNamesSetForValidation, "{variable.name}")
        macro_error(compiling_program(), variable.at, "local variable '{variable.name}' shadows bundled component '{bundleArgName}.{variable.name}'")
    return <- expr


[function_macro(name="with_bundle")]
class WithBundleMacro : AstFunctionAnnotation
  [unused_argument(group, errors)] def override apply(var func : FunctionPtr; var group : ModuleGroup; args : AnnotationArgumentList; var errors : das_string) : bool
    var bundleArgName : string = ""
    for arg in args
      bundleArgName = "{arg.name}"
    apply_to_func(func) <| $(var fun; var arguments; var body; is_es)
      let res <- get_or_expand_bundle_args(fun, arguments, body, "{fun.name}", bundleArgName, is_es, false)
      if res.idx < 0
        macro_error(compiling_program(), func.at, "no bundle arg '{bundleArgName}' found")
    return true

[block_macro(name="block_with_bundle")]
class BlockWithBundleMacro : AstBlockAnnotation
  [unused_argument(group, errors)] def override apply(var blk : smart_ptr<ExprBlock>; var group : ModuleGroup; args : AnnotationArgumentList; var errors : das_string) : bool
    var bundleArgName : string = ""
    for arg in args
      bundleArgName = "{arg.name}"
    let res <- get_or_expand_bundle_args(blk, blk.arguments, blk, "", bundleArgName, true, false)
    if res.idx < 0
      macro_error(compiling_program(), blk.at, "no bundle arg '{bundleArgName}' found")
    return true

[function_macro(name="_bundle_args")]
class BundleArgsInfoAnnotation : AstFunctionAnnotation {}
