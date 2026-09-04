options gen2
options indenting = 4
options strict_smart_pointers = true

module lint_everything shared private






require daslib/ast_boost
require daslib/lint

[global_lint_macro]
class LintEverythingGlobal : AstPassMacro {
    
    def override apply(prog : ProgramPtr; mod : Module?) : bool {
        paranoid(prog, true)
        return true
    }
}
