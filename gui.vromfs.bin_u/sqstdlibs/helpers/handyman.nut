





























let g_string =  require("%sqstd/string.nut")
let { loc } = require("dagor.localize")
local {regexp} = require("string")
let {memoize} = require("%sqstd/functools.nut")
let { read_text_from_file } = require("dagor.fs")
let loadTemplateText = memoize(@(v) read_text_from_file(v))





local handyman
local Scanner = class {
  string = ""
  tail   = ""
  pos    = 0

  constructor (string_) {
    this.string = string_
    this.tail = string_
    this.pos = 0
  }

  


  function eos () {
    return this.tail == ""
  }

  



  function scan (re) {
    local match = re.search(this.tail)

    if (match && match.begin == 0) {
      local s = this.tail.slice(0, match.end)
      this.tail = this.tail.slice(match.end)
      this.pos += s.len()
      return s
    }

    return ""
  }

  



  function scanUntil(re) {
    local res = re.search(this.tail)
    local match

    if (res == null) {
      match = this.tail
      this.tail = ""
    }
    else if (res.begin == 0)
      match = ""
    else {
      match = this.tail.slice(0, res.begin)
      this.tail = this.tail.slice(res.begin)
    }

    this.pos += match.len()
    return match
  }
}

local Context
Context = class {
  view          = {}
  cache         = {}
  parentContext = null

  constructor(view_, parentContext_ = null) {
    this.view          = view_ == null ? {} : view_
    this.cache         = {}
    this.cache["."]    <- this.view
    this.parentContext = parentContext_
  }

  



  function push(view) {
    return Context(view, this)
  }

  



  function lookup (name) {
    local value = null
    local context = this
    if (name in this.cache)
      value = this.cache[name]
    else {
      while (context) {
        if ((name.indexof(".") ?? -1) > 0) {
          value = context.view

          local names = g_string.split(name, ".")
          local i = 0
          while (value != null && i < names.len()) {
            value = value[names[i++]]
          }
        }
        else {
          value = context.view?[name]
        }

        if (value != null)
          break

        context = context.parentContext
      }

      this.cache[name] <- value
    }

    if (type(value) == "function") {
      value = value.call(context.view)
    }

    return value
  }
}







local Writer = class {
  cache = {}
  tags = ["<<", ">>"]

  static whiteRe  = regexp(@"\s*")
  static spaceRe  = regexp(@"\s+")
  static equalsRe = regexp(@"\s*=")
  static curlyRe  = regexp(@"\s*\}")
  static tagRe    = regexp(@"#|\^|\/|>|\{|&|=|!|@|?")
  static escapeRe = regexp(@"[\-\[\]{}()*+?.,\\\^$|#\s]")
  static nonSpaceRe = regexp(@"\S")

  constructor() {
    this.cache = {}
  }

  


  function clearCache() {
    this.cache = {}
  }

  



  function parse(template, tags = null) { 
    local tokens = this.cache?[template]
    if (tokens == null) {
      tokens = this.parseTemplate(template, tags)
      this.cache[template] <- tokens
    }

    return tokens
  }

  








  function render(template, view, partials = null) {
    local tokens = this.parse(template)
    local context = (type(view) == "instance" && view instanceof Context) ? view : Context(view)
    return this.renderTokens(tokens, context, partials, template)
  }

  








  function renderTokens(tokens, context, partials, originalTemplate) {
    local buffer = []

    
    
    local self = this
    local subRender = function (template) {
      return self.render(template, context, partials)
    }

    local token
    local value

    for (local i = 0; i < tokens.len(); ++i) {
      token = tokens[i]

      if (token[0] == "#") {
        value = context.lookup(token[1])
        if (!value)
          continue
        if (type(value) == "array") {
          for (local j = 0; j < value.len(); ++j) {
            buffer.append(this.renderTokens(token[4], context.push(value[j]), partials, originalTemplate))
          }
        }
        else if (type(value) == "table" || type(value) == "instance" || type(value) == "string") { 

          buffer.append(this.renderTokens(token[4], context.push(value), partials, originalTemplate))
        }
        else if (type(value) == "function") {
          if (type(originalTemplate) != "string") {
            assert(false, "Cannot use higher-order sections without the original template")
            return "".join(buffer)
          }

          
          value = value.call(context.view, originalTemplate.slice(token[3], token[5]), subRender)

          if (type(value) == "string")
            buffer.append(value)
        }
        else {
          buffer.append(this.renderTokens(token[4], context, partials, originalTemplate))
        }
      }
      else if (token[0] == "^"){
        value = context.lookup(token[1])

        if (!value || ((type(value) == "array") && value.len() == 0)) {
          buffer.append(this.renderTokens(token[4], context, partials, originalTemplate))
        }
      }
      else if (token[0] == ">") {
        if (!partials)
          continue

        if (type(partials) == "function")
          value = partials(token[1])
        else if (token[1] in partials)
          value = partials[token[1]]

        if (value != null) {
          local valueTemplate
          local valueTokens
          
          if (value in handyman.templateByTemplatePath) {
            valueTemplate = handyman.templateByTemplatePath[value]
            valueTokens = handyman.tokensByTemplatePath[value]
          }
          else {
            valueTemplate = value
            valueTokens = this.parse(value)
          }
          buffer.append(this.renderTokens(valueTokens, context, partials, valueTemplate))
        }
      }
      else if (token[0] == "&") {
        value = context.lookup(token[1])
        if (value != null)
          buffer.append(value)
      }
      else if(token[0] == "name") {
        value = context.lookup(token[1])
        if (value != null)
          if (type(value) == "string")
            buffer.append(g_string.stripTags(value))
          else
            buffer.append(value.tostring())

      }
      else if (token[0] == "@") {
        value = context.lookup(token[1])
        if (value != null)
          buffer.append(value.tostring())
      }
      else if (token[0] == "?")
        buffer.append(g_string.stripTags(loc(token[1])))
      else if (token[0] == "text")
        buffer.append(token[1])
    }

    return "".join(buffer)
  }

  function isWhitespace(string) {
    return !this.nonSpaceRe.match(string)
  }

  function escapeRegExp(string) {
    local start = 0
    local matches = []
    local match = this.escapeRe.search(string, start)
    while (match) {
      matches.append(match)
      start = match.end
      match = this.escapeRe.search(string, start)
    }

    for(local i = matches.len() - 1; i >= 0; i--) {
      match = matches[i]
      string = "".concat(string.slice(0, match.begin), "\\", string.slice(match.begin))
    }
    return string
  }

  function escapeTags(tags) { 
    if (!(type(tags) == "array") || tags.len() != 2) {
      assert(false, $"Invalid tags: {tags}")
    }

    return [
      regexp("".concat(this.escapeRegExp(tags[0]), "\\s*")),
      regexp("".concat("\\s*", this.escapeRegExp(tags[1])))
    ]
  }

  function parseTemplate(template, tags_ = null) {
    local tags = tags_ || this.tags 
    template = template || ""

    if (type(tags) == "string")
     tags = g_string.split(tags, this.spaceRe)

    local tagRes  = this.escapeTags(tags)
    local scanner = Scanner(template)

    local sections = []     
    local tokens   = []     
    local spaces   = []     
    local hasTag   = false  
    local nonSpace = false  
    local scanError = false

    local start, tType, value, chr, token, openSection
    while (!scanner.eos()) {
      start = scanner.pos

      
      value = scanner.scanUntil(tagRes[0])
      if (value != "") {
        for (local i = 0; i < value.len(); ++i) {

          chr = value.slice(i, i + 1)

          if (this.isWhitespace(chr))
            spaces.append(tokens.len())
          else
            nonSpace = true

          tokens.append(["text", chr, start, start + 1])
          start += 1

          
          if (chr == "\n") {
            
            
            if (hasTag && !nonSpace) {
              while (spaces.len()) {
                tokens.remove(spaces.pop())
              }
            }
            else {
              spaces = []
            }

            hasTag = false
            nonSpace = false
          }
        }
      }

      
      if (!scanner.scan(tagRes[0]))
        break
      hasTag = true

      
      local scaned = scanner.scan(this.tagRe)
      tType = scaned == "" ? "name" : scaned
      scanner.scan(this.whiteRe)

      
      if (tType == "=") {
        value = scanner.scanUntil(this.equalsRe)
        scanner.scan(this.equalsRe)
        scanner.scanUntil(tagRes[1])
      }
      else if (tType == "{") {
        value = scanner.scanUntil(regexp("".concat("\\s*", this.escapeRegExp($"\}{tags[1]}"))))
        scanner.scan(this.curlyRe)
        scanner.scanUntil(tagRes[1])
        tType = "&"
      }
      else {
        value = scanner.scanUntil(tagRes[1])
      }

      
      if (!scanner.scan(tagRes[1])) {
        assert(false, $"Unclosed tag at {scanner.pos}")
        scanError = true
        break
      }
      token = [ tType, value, start, scanner.pos ]
      tokens.append(token)

      if (tType == "#" || tType == "^") {
        sections.append(token)
      }
      else if (tType == "/") {
        
        openSection = sections.len()? sections.pop() : null

        if (!openSection) {
          assert(false, $"Unopened section \"{value}\" at {start}")
          scanError = true
          break
        }

        if (openSection[1] != value) {
          assert(false, $"Unclosed section \"{openSection[1]}\" at {start}")
          scanError = true
          break
        }
      }
      else if (tType == "name" || tType == "{" || tType == "&") {
        nonSpace = true
      }
      else if (tType == "=") {
        
        tags = value.split(this.spaceRe)
        tagRes = this.escapeTags(tags)
      }
    }

    
    if (sections.len() > 0)
      assert(false, $"Unclosed section \"{sections[sections.len() - 1][1]}\" at {scanner.pos}")

    if (scanError)
      tokens = []

    return this.nestTokens(this.squashTokens(tokens))
  }

  



  function squashTokens(tokens) {
    local squashedTokens = []

    local token, lastToken
    for (local i = 0; i < tokens.len(); ++i) {
      token = tokens[i]

      if (token) {
        if (token[0] == "text" && lastToken && lastToken[0] == "text") {
          lastToken[1] = $"{lastToken[1]}{token[1]}"
          lastToken[3] = token[3]
        }
        else {
          squashedTokens.append(token)
          lastToken = token
        }
      }
    }

    return squashedTokens
  }

  





  function nestTokens(tokens) {
    local nestedTokens = []
    local collector = nestedTokens
    local sections = []

    local token, section

    for (local i = 0; i < tokens.len(); ++i) {
      token = tokens[i]
      if (["#", "^"].contains(token[0])) {
        collector.append(token)
        sections.append(token)
        token.resize(5, [])
        collector = []
        token[4] = collector
      }
      else if (token[0]=="/") {
        section = sections.pop()
        section.resize(6, [])
        section[5] = token[2]
        collector = sections.len() > 0 ? sections[sections.len() - 1][4] : nestedTokens
      }
      else
        collector.append(token)
    }

    return nestedTokens
  }
}

handyman = {

  
  defaultWriter = Writer()

  
  tokensByTemplatePath = {}
  templateByTemplatePath = {}

  lastCacheReset = 0

  


  function clearCache() {
    return this.defaultWriter.clearCache()
  }

  




  function parse(template, tags) {
    return this.defaultWriter.parse(template, tags)
  }

  



  function render(template, view, partials = null) {
    return this.defaultWriter.render(template, view, partials)
  }

  




  function renderCached(templatePath, view, partials = null, cachePartials = false) {
    this.updateCache(templatePath)
    if (partials != null && cachePartials)
      foreach (partialPath in partials)
        this.updateCache(partialPath)
    local tokens = this.tokensByTemplatePath[templatePath]
    local template = this.tokensByTemplatePath[templatePath]
    local context = (type(view) == "instance" && view instanceof Context) ? view : Context(view)
    return this.defaultWriter.renderTokens(tokens, context, partials, template)
  }

  function updateCache(templatePath) {
    if (templatePath in this.tokensByTemplatePath)
      return
    local template = loadTemplateText(templatePath)
    template = this.processIncludes(template)
    this.templateByTemplatePath[templatePath] <- template
    this.tokensByTemplatePath[templatePath] <- this.defaultWriter.parseTemplate(template)
  }

  function processIncludes(template) {
    local startIdx = 0
    while(true) {
      startIdx = template.indexof("include \"", startIdx)
      if(startIdx == null)
        break

      local fNameStart = startIdx + 9
      local endIdx = template.indexof("\"", fNameStart)
      if (endIdx == null)
        break

      local fName = template.slice(fNameStart, endIdx)
      if (fName.slice(-4) == ".blk") {
        startIdx = endIdx + 1
        continue
      }

      local includeRes = loadTemplateText(fName)
      template = "".concat(template.slice(0, startIdx), includeRes, template.slice(endIdx + 1))
    }
    return template
  }

  




  function renderNested(template, translate) {
    return function() {
      return function(text, render) {
        return handyman.render(template, translate(render(text)))
      }
    }
  }
}









function testhandyman(_temaple = null, _view = null, _partails = null) {
  local testTemplate = @"text{
  text:t='<<header>>';
}
<<#bug>>
<</bug>>

<<#items>>
  <<#first>>
    <<>first>>
  <</first>>
  <<#link>>
    <<>link>>
  <</link>>
<</items>>

<<@layout_insertion>>

<<#empty>>
  text{
    text:t='The list is empty. <<header>>';
  }
<</empty>>"

  let partials = {
    first = @"text{
  test:t='<<name>>';
}"
    link = @"link {
  href:t='<<url>>';
  text:t='<<name>>';
}"
  }


  let testView = {
    header = "Colors"
    items = [
        {name = "red", first= true, url= "#Red"}
        {name = "green", link= true, url= "#Green"}
        {name = "blue", link= true, url= "#Blue"}
    ]
    empty = function() {
      return function(text, render) {
        return render(text)
      }
    }
    layout_insertion = "wink:t='yes';"
  }
  println("before render")
  println(handyman.render(testTemplate, testView, partials))
}

if (__name__ == "__main__")
  testhandyman()
return {
  handyman
}