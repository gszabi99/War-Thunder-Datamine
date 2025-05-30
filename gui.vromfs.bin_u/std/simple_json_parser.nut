

let log = @(...) println("[LOG] "+" ".join(vargv));
let pp = @(...) println(" ".join(vargv));

function mkParser(context, bindings=null) {
  bindings = (bindings ?? {}).__merge({
      upper = function(v) {
          return v.tostring().toupper();
      },
      and = function(a, b){
        return a && b
      }
      or = function(a, b){
        return a || b
      }
      concat = function(a, b) {
          return a.tostring() + b.tostring();
      },
      exists_in_context = function(key) {
          return context.rawin(key);
      },
      map_context = function(key, value) {
        return context.rawin(key) ? value.tostring() : ""
      },
      ["if"] = function(cond, a, b="") {
          return cond ? a : b;
      },
      ["not"] = function(x) {
          return !x;
      },
      equal = function(a, b) {
        return a == b
      }
      not_equal = function(a, b) {
        return a != b
      }
      contains = function(a, b) {
          return a.tostring().indexof(b.tostring()) != null;
      },
      startswith = function(a, b) {
          return a.tostring().indexof(b.tostring()) == 0;
      },
      endswith = function(a, b) {
          local str = a.tostring();
          local suffix = b.tostring();
          return str.slice(str.len() - suffix.len()) == suffix;
      }
  });

  
  local evaluate_config, eval_item, eval_expr, resolve_placeholders, get_context_value;
  

  
  evaluate_config = function(config, ctx) {
      context = ctx;
      local result = [];

      foreach (item in config) {
          try {
              local value = eval_item(item);
              if (typeof value == "array") {
                  foreach (v in value) result.append(v.tostring());
              } else {
                  result.append(value.tostring());
              }
          } catch (e) {
              log("evaluate_config error:", e);
          }
      }

      return result;
  };

  
  eval_item = function(item) {
      if (typeof item == "string") {
          return resolve_placeholders(item);
      }
      if (typeof item == "array") {
          return eval_expr(item);
      }
      return "";
  };

  
  eval_expr = function(expr) {
      if (expr.len() == 0) return "";

      local fname = expr[0];
      local args = [];

      for (local i = 1; i < expr.len(); i++) {
          local arg = expr[i];
          if (typeof arg == "string") {
              args.append(resolve_placeholders(arg));
          } else if (typeof arg == "array") {
              args.append(eval_expr(arg));
          } else {
              args.append(arg);
          }
      }

      if (!bindings.rawin(fname)) {
          log("Unknown function:", fname);
          return "";
      }

      try {
          return bindings[fname].acall([null].extend(args));
      } catch (e) {
          log($"eval_expr error in function '{fname}':", e);
          return "";
      }
  };

  
  resolve_placeholders = function(str) {
      local result = [];
      local i = 0;

      while (i < str.len()) {
          local start = str.indexof("<<", i);
          if (start == null) {
              result.append(str.slice(i));
              break;
          }

          result.append(str.slice(i, start));
          local end = str.indexof(">>", start);
          if (end == null) {
              log("Unclosed << in string:", str);
              result.append(str.slice(start));
              break;
          }

          local key = str.slice(start + 2, end).strip();
          local val = get_context_value(key);
          result.append(val.tostring());
          i = end + 2;
      }

      return "".join(result);
  };

  
  get_context_value = function(key) {
      if (context.rawin(key)) {
          return context[key];
      } else {
          log("Missing context variable:", key);
          return "";
      }
  };
  return evaluate_config
}


if (__name__ == "__main__") {
  function test(config, context){
    let evaluate_config = mkParser(context)
    println("--- Output:");
    let result = evaluate_config(config, context);
    pp(" ".join(result))
    return result
  }
  let cf = [
    "game.exe",
    "lang=<<language>>",
    ["upper", "<<region>>"],
    ["concat", "lang-", ["upper", "<<language>>"]],
    ["if", ["exists_in_context", "region"], ["concat", "-region=", "<<region>>"], ""],
    ["if", ["exists_in_context", "platform"], "platform=<<platform>>", "missing platform"],
    ["nonexistent_func", "arg"],
    ["exists_in_context"],
    ["if", ["endswith", "<<filename>>", ".csv"], "Detected CSV file", "Not a CSV '<<filename>>'"],
    ["if", ["contains", "<<filename>>", "report"], "Contains 'report'", "Doesn't contain 'report'"],
    ["if", ["not", ["contains", "<<filename>>", "secret"]], "OK", "Forbidden"],
    "bad <<language"
  ]
  let ctx = {
    "language": "ru",
    "region": "RU",
    "filename":"a.exe"
    circuit = "production"
    productionCircuit = "production"
  }
  test(cf, ctx)

  test([
      ["map_context", "enable_nvidia_aftermath", "--aftermath"],
      ["map_context", "enable_amd_ags", "--noamdags"],
      ["if", ["equal", "<<curCircuit>>", "<<defaultProductionCircuit>>"], "", "-circuit <<circuit>>"],
      "-fromlauncher",
      "--no-relaunch",
      ["map_context", "language", ["concat", "-lang ", ["upper", "<<language>>"]]],
      ["if", ["and", ["not_equal", "<<dmmUserId>>", ""], ["not_equal", "dmmToken", ""]], "-dmm_user_id <<dmmUserId>> -dmm_token <<dmmToken>>"],
      ["map_context", "ultra_low_quality", "--ultraLowQuality"]
    ], {defaultProductionCircuit = "production", curCircuit = "production", enable_nvidia_aftermath=true, enable_amd_ags=true, language="English", dmmUserId="", dmmToken="", ultra_low_quality = true})
}