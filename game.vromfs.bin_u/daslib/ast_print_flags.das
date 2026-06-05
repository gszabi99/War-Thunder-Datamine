module ast_print_flags






options gen2

options rtti = true

options strict_smart_pointers = false


require daslib/rtti
require daslib/ast
require daslib/ast_boost
require daslib/strings_boost

class SetPrinterFlags : AstVisitor {
    
    def override preVisitExprBlockExpression(block1 : ExprBlock?; var expr : ExpressionPtr) {
        
        expr.printFlags := ExprPrintFlags.argLevel
    }

    def override preVisitExprNewArgument(call : ExprNew?; var expr : Expression?; last : bool) {
        
        expr.printFlags := ExprPrintFlags.argLevel
    }

    def override preVisitExprCallArgument(casll : ExprCall?; var expr : Expression?; last : bool) {
        
        expr.printFlags := ExprPrintFlags.argLevel
    }

    def override preVisitExprLooksLikeCallArgument(call : ExprLooksLikeCall?; var expr : Expression?; last : bool) {
        
        expr.printFlags := ExprPrintFlags.argLevel
    }

    def override preVisitExprIfThenElse(var expr : ExprIfThenElse?) {
        
        expr.cond.printFlags := ExprPrintFlags.argLevel
    }

    def override preVisitExprWhile(var expr : ExprWhile?) {
        
        expr.cond.printFlags := ExprPrintFlags.argLevel
    }

    def override preVisitExprReturn(var expr : ExprReturn?) {
        
        if (expr.subexpr != null) {
            expr.subexpr.printFlags := ExprPrintFlags.argLevel
        }
    }

    def override preVisitExprCopy(var expr : ExprCopy?) {
        
        if (expr.printFlags.topLevel || expr.printFlags.argLevel) {
            expr.right.printFlags := ExprPrintFlags.argLevel
        }
    }

    def override preVisitExprClone(var expr : ExprClone?) {
        
        if (expr.printFlags.topLevel || expr.printFlags.argLevel) {
            expr.right.printFlags := ExprPrintFlags.argLevel
        }
    }

    def override preVisitExprVar(var expr : ExprVar?) {
        
        expr.printFlags := ExprPrintFlags.bottomLevel
    }

    def override preVisitExprTypeInfo(var expr : ExprTypeInfo?) {
        
        if (expr.subexpr != null) {
            expr.subexpr.printFlags := ExprPrintFlags.argLevel
        }
    }

    def override preVisitExprArrayComprehension(var expr : ExprArrayComprehension?) {
        
        expr.subexpr.printFlags = ExprPrintFlags.argLevel;
        if (expr.exprWhere != null) {
            expr.exprWhere.printFlags := ExprPrintFlags.argLevel
        }
    }
}

[export]
def used_flags() {
    
    new SetPrinterFlags();
    panic("unused");
}