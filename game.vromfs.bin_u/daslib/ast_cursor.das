options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options strict_smart_pointers = true








module ast_cursor shared public

require daslib/ast_boost
require strings



struct public CursorHit {
    
    expr : Expression const?
    
    func : Function const?
    
    name : string
    
    rtti : string
}



def public cursor_inside(line, col : int; at : LineInfo) : bool {
    if (int(at.line) == 0 && int(at.last_line) == 0) {
        return false
    }
    let tl = int(at.line)
    let tc = int(at.column)
    let tll = int(at.last_line)
    let tlc = int(at.last_column)
    if (line < tl || line > tll) {
        return false
    }
    
    if (line == tl && line == tll) {
        return col >= tc && col < tlc
    }
    
    if (line == tl) {
        return col >= tc
    }
    
    if (line == tll) {
        return col < tlc
    }
    
    return true
}


def private expression_name(expr : ExpressionPtr) : string {
    if (expr is ExprVar) {
        return string((expr as ExprVar).name)
    }
    if (expr is ExprCall) {
        return string((expr as ExprCall).name)
    }
    if (expr is ExprField) {
        return string((expr as ExprField).name)
    }
    if (expr is ExprSafeField) {
        return string((expr as ExprSafeField).name)
    }
    if (expr is ExprOp1) {
        return string((expr as ExprOp1).op)
    }
    if (expr is ExprOp2) {
        return string((expr as ExprOp2).op)
    }
    if (expr is ExprOp3) {
        return "?"
    }
    if (expr is ExprLooksLikeCall) {
        return string((expr as ExprLooksLikeCall).name)
    }
    if (expr is ExprNamedCall) {
        return string((expr as ExprNamedCall).name)
    }
    return ""
}

class CursorVisitor : AstVisitor {
    targetLine : int
    targetCol : int
    targetFile : string
    hits : array<CursorHit>
    currentFunc : Function const?

    def CursorVisitor(file : string; line, col : int) {
        targetFile = file
        targetLine = line
        targetCol = col
        currentFunc = null
    }

    def override preVisitFunction(fun : FunctionPtr) : void {
        currentFunc = fun
    }

    def override visitFunction(var fun : FunctionPtr) : FunctionPtr {
        currentFunc = null
        return fun
    }

    def override preVisitExpression(expr : ExpressionPtr) : void {
        let e = expr
        
        if (!empty(targetFile) && e.at.fileInfo != null) {
            let fname = string(e.at.fileInfo.name)
            if (find(fname, targetFile) < 0) {
                return
            }
        }
        if (cursor_inside(targetLine, targetCol, e.at)) {
            hits |> emplace(CursorHit(
                expr = e,
                func = currentFunc,
                name = expression_name(expr),
                rtti = string(e.__rtti)
            ))
        }
    }
}

def private reverse_hits(var src : array<CursorHit>) : array<CursorHit> {
    var result : array<CursorHit>
    result |> reserve(length(src))
    var i = length(src) - 1
    while (i >= 0) {
        result |> emplace <| src[i]
        i--
    }
    return <- result
}



def public find_at_cursor(program : smart_ptr<Program>; file : string; line, col : int) : array<CursorHit> {
    var visitor = new CursorVisitor(file, line, col)
    make_visitor(*visitor) $(adapter) {
        visit(program, adapter)
    }
    
    var result <- reverse_hits(visitor.hits)
    unsafe {
        delete visitor
    }
    return <- result
}



def public find_at_cursor_in_function(func : FunctionPtr; file : string; line, col : int) : array<CursorHit> {
    var visitor = new CursorVisitor(file, line, col)
    visitor.currentFunc = func
    make_visitor(*visitor) $(adapter) {
        visit(func, adapter)
    }
    var result <- reverse_hits(visitor.hits)
    unsafe {
        delete visitor
    }
    return <- result
}


def public describe(hit : CursorHit) : string {
    return build_string() $(var w) {
        write(w, hit.rtti)
        if (!empty(hit.name)) {
            write(w, "({hit.name})")
        }
        if (hit.expr != null && hit.expr._type != null) {
            write(w, " : {describe(hit.expr._type)}")
        }
        write(w, " at {int(hit.expr.at.line)}:{int(hit.expr.at.column)}-{int(hit.expr.at.last_line)}:{int(hit.expr.at.last_column)}")
        if (hit.func != null) {
            write(w, " in {hit.func.name}")
        }
    }
}
