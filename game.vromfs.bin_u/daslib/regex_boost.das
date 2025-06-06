options gen2
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options indenting = 4
options strict_smart_pointers = true

module regex_boost shared private

require ast
require strings
require daslib/ast_boost
require daslib/regex public

[reader_macro(name="regex")]
class RegexReader : AstReaderMacro {
    
    
    
    def override accept(prog : ProgramPtr; mod : Module?; var expr : ExprReader?; ch : int; info : LineInfo) : bool {
        if (ch != '\n' && ch != '\r') {
            append(expr.sequence, ch)
        }
        if (ends_with(expr.sequence, "%%")) {
            let len = length(expr.sequence)
            resize(expr.sequence, len - 2)
            return false
        } else {
            return true
        }
    }
    def override visit(prog : ProgramPtr; mod : Module?; expr : smart_ptr<ExprReader>) : ExpressionPtr {
        var regex : Regex
        regex_compile(regex, "{expr.sequence}")
        if (!is_valid(regex)) {
            unsafe {
                delete regex
            }
            macro_error(prog, expr.at, "regular expression did not compile {expr.sequence}")
            return <- default<ExpressionPtr>
        }
        
        var inscope re_data <- convert_to_expression(regex, expr.at)
        delete regex
        var inscope creg <- new ExprCall(at = expr.at, name := "regex::regex_compile")
        emplace(creg.arguments, re_data)
        return <- creg
    }
}
