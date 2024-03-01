options no_aot
module bfg_ecs shared
require daBfg public
require DagorSystem public

require daslib/ast_boost
require daslib/templates_boost
require ecs
require ecs.macro_common
require DeferToAct

let private BFG_ECS_NODE_ALLOWED_ARGUMENTS <- [{auto "name"; "entity"; "handle"; "counter_handle"}]

struct private BfgEcsNodeAnnotationArgs
  ok : bool = false
  isCollection : bool
  entityName : string
  handleName : string

//! Declare node, that stored in ecs
//!
//! This node will be reloaded automatically on das scripts reload.
//!
//! For every register node function like this:
//!
//! [bfg_ecs_node]
//! def register_sample_node(var sample_node: NodeHandle &)
//!   sample_node <- root() |> registerNode("node_name") <| @(var registry : Registry)
//!     ...
//!
//! Will be automatically generated reload function like this:
//!
//! [defer_to_act]
//! def reload_node`register_sample_node()
//!   query() <| $ [es] (var sample_node: NodeHandle &)
//!     register_sample_node(sample_node)
//!
//! This function will be called in act stage after reloading of script.
[function_macro(name="bfg_ecs_node")]
class BfgEcsNodeAnnotation : AstFunctionAnnotation

  def declareReloadSingleNode(func : FunctionPtr; args : BfgEcsNodeAnnotationArgs)

    let reloadName = "reload_node`{func.name}"
    return <- qmacro_function(reloadName) <| $()
      if !is_dabfg_runtime_initialized()
        logerr("dabfg::startup must be called before loading any das scripts that use daBfg!")
        return

      let eid = getSingletonEntity($v(args.entityName))
      if eid == INVALID_ENTITY_ID
        return

      query(eid) <| $ [es] (var $i(args.handleName) : NodeHandle&)
        if $i(args.handleName).valid
          $c(func.name)($i(args.handleName))

  def declareReloadCollection(func : FunctionPtr; args : BfgEcsNodeAnnotationArgs)

    let reloadName = "reload_node`{func.name}"
    return <- qmacro_function(reloadName) <| $()
      if !is_dabfg_runtime_initialized()
        logerr("dabfg::startup must be called before loading any das scripts that use daBfg!")
        return

      let eid = getSingletonEntity($v(args.entityName))
      if eid == INVALID_ENTITY_ID
        return

      query(eid) <| $ [es] (var $i(args.handleName) : NodeHandleVector&)
        for i, handle in count(), $i(args.handleName)
          if handle.valid
            $c(func.name)(handle, i)


  def declareReloadNode(func : FunctionPtr; args : BfgEcsNodeAnnotationArgs)
    var inscope reloadNode <- args.isCollection ? (func |> declareReloadCollection(args)) : (func |> declareReloadSingleNode(args))

    reloadNode |> append_annotation("DeferToAct", "defer_to_act")
    compiling_module() |> add_function(reloadNode)

  def parseArgs(func : FunctionPtr; args : AnnotationArgumentList; var errors : das_string) : BfgEcsNodeAnnotationArgs

    for arg in args
      if BFG_ECS_NODE_ALLOWED_ARGUMENTS |> find_index("{arg.name}") == -1
        errors := "Unexpected parameter '{arg.name}' in [bfg_ecs_node] for {func.name}; expected one of {BFG_ECS_NODE_ALLOWED_ARGUMENTS}"
        return [[BfgEcsNodeAnnotationArgs]]

    let counterArg = find_arg(args, "counter_handle")
    var isCollection = false
    if !(counterArg is nothing)
      isCollection = true
      if !(counterArg |> validate_string_argument("counter_handle", errors))
        return [[BfgEcsNodeAnnotationArgs]]

    let persistentHeapArg = compiling_program()._options |> find_arg("persistent_heap")
    if !(persistentHeapArg is tBool && (persistentHeapArg as tBool))
      errors := "The file {func.at.fileInfo.name} contains [bfg_ecs_node] must use persistent heap `options persistent_heap` for correct callback handling!"
      return [[BfgEcsNodeAnnotationArgs]]

    let funcArgsCnt = isCollection ? 2 : 1
    if func.arguments |> length() != funcArgsCnt
      errors := "Function {func.name} annotated with [bfg_ecs_node] expects {funcArgsCnt} parameter, but {func.arguments |> length()} provided."
      return [[BfgEcsNodeAnnotationArgs]]

    let firstArgType = describe_typedecl(func.arguments[0]._type, true, true, true)
    if !(firstArgType == "daBfgCore::NodeHandle&|daBfgCore::NodeHandle&# -const" || firstArgType == "daBfgCore::NodeHandle& -const")
      errors := "Function {func.name} annotated with [bfg_ecs_node] expects first parameter '{func.arguments[0].name}' with type 'NodeHandle& |#', but '{firstArgType}' provided."
      return [[BfgEcsNodeAnnotationArgs]]

    if isCollection
      let secondArgType = describe_typedecl(func.arguments[1]._type, true, true, true)
      if secondArgType != "int const"
        errors := "Function {func.name} annotated with [bfg_ecs_node] expects second parameter '{func.arguments[1].name}' with type 'int const', but '{secondArgType}'' provided."
        return [[BfgEcsNodeAnnotationArgs]]

    let entityArg = find_arg(args, "entity")
    if !(entityArg |> validate_string_argument("entity", errors))
      return [[BfgEcsNodeAnnotationArgs]]
    var entityName = entityArg as tString

    let handleArg = find_arg(args, "handle")
    if !(handleArg |> validate_string_argument("handle", errors))
      return [[BfgEcsNodeAnnotationArgs]]
    var handleName = handleArg as tString

    return [[BfgEcsNodeAnnotationArgs
      ok = true,
      isCollection = isCollection,
      entityName <- entityName,
      handleName <- handleName
    ]]


  [unused_argument(group)] def override apply(var func : FunctionPtr; var group : ModuleGroup; args : AnnotationArgumentList; var errors : das_string) : bool

    let parsed = func |> parseArgs(args, errors)
    if !parsed.ok
      return false

    func |> declareReloadNode(parsed)
    return true