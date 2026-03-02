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
        
        var pattern = "{expr.sequence}"
        var ci = false
        var da = false
        let tilde_pos = find(pattern, "~", length(pattern) - 4 > 0 ? length(pattern) - 4 : 0)
        if (tilde_pos != -1) {
            let flags_str = slice(pattern, tilde_pos + 1)
            var valid_flags = true
            for (fc in flags_str) {
                if (fc == 'i') {
                    ci = true
                } elif (fc == 's') {
                    da = true
                } else {
                    valid_flags = false
                    break
                }
            }
            if (valid_flags && length(flags_str) > 0) {
                pattern = slice(pattern, 0, tilde_pos)
            }
        }
        var regex : Regex
        regex_compile(regex, pattern, ci, da)
        if (!is_valid(regex)) {
            unsafe {
                delete regex
            }
            macro_error(prog, expr.at, "regular expression did not compile {pattern}")
            return <- default<ExpressionPtr>
        }
        
        var inscope re_data <- convert_to_expression(regex, expr.at)
        delete regex
        var inscope creg <- new ExprCall(at = expr.at, name := "regex::regex_compile")
        emplace(creg.arguments, re_data)
        return <- creg
    }
}
