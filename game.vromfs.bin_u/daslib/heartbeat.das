options gen2

options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options strict_smart_pointers = true

module heartbeat private








require daslib/ast_boost
require daslib/templates_boost
require daslib/strings_boost

var g_hbCallback : lambda<() : void>
var g_inHB : bool = false

def public set_heartbeat(var cb : lambda<() : void>) {
    
    delete g_hbCallback
    g_hbCallback <- cb
}

def public heartbeat() {
    
    if (g_inHB) {
        return
    }
    if (g_hbCallback != null) {
        g_inHB = true
        invoke(g_hbCallback)
        g_inHB = false
    }
}

class AddHeartbeat : AstVisitor {
    
    astChanged : bool = false
    @do_not_delete func : Function?
    def heartbeatBlock(var body : ExprBlock?) {
        if (length(body.list) == 0) {
            return
        }
        if ((body.list[0] is ExprCall) && (body.list[0] as ExprCall).name == "heartbeat") {
            return
        }
        var expr = qmacro(heartbeat())
        body.list |> emplace(expr, 0)
        astChanged = true
        func.not_inferred()
    }
    def override preVisitFunction(var fun : FunctionPtr) {
        func = fun
    }
    def override visitFunction(var fun : FunctionPtr) : FunctionPtr {
        if (fun.body == null || !(fun.body is ExprBlock)) {
            func = null
            return <- fun
        }
        heartbeatBlock(fun.body as ExprBlock)
        func = null
        return <- fun
    }
    def override visitExprFor(var expr : ExprFor?) : ExpressionPtr {
        if (expr.body == null || !(expr.body is ExprBlock)) {
            return <- expr
        }
        heartbeatBlock(expr.body as ExprBlock)
        return <- expr
    }
    def override visitExprWhile(var expr : ExprWhile?) : ExpressionPtr {
        if (expr.body == null || !(expr.body is ExprBlock)) {
            return <- expr
        }
        heartbeatBlock(expr.body as ExprBlock)
        return <- expr
    }
}

[infer_macro]
class HeartbeatPass : AstPassMacro {
    
    def override apply(prog : ProgramPtr; mod : Module?) : bool {
        var astVisitor = new AddHeartbeat()
        make_visitor(*astVisitor) $(astVisitorAdapter) {
            visit(prog, astVisitorAdapter)
        }
        let result = astVisitor.astChanged
        unsafe {
            delete astVisitor
        }
        return result
    }
}
