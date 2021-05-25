/**
 * Documenation: http://mustache.github.io/mustache.5.html
 *
 * to insert generated layout in template use tag @
 * <<@layout>>
 * such param will be not stripTagged
 *
 * to insert localized text you can use tag ?
 * <<?mainmenu/btnControls>>
 *
 *  API
 *
 *  ::handyman.render(template, view)
 *    @template - template raw string
 *    @view - table of data for template
 *    @return - template string with filled data
 *
 *  ::handyman.renderCached(template_name, view)
 *    @template_name - template name in format <path-to-template>/<template-file-name>
 *      File name should be without extantion
 *    @view - table of data for template
 *    @return - template string with filled data
 *
 *  Main difference betwin this two calls is in caching.
 *  ::handyman.render(/.../) use whole template raw string as
 *  cache id for rendered tokens.
 *  ::handyman.renderCached(template_name, view) use just template file name.
 */

#no-plus-concat

local g_string =  require("std/string.nut")

/**
 * A simple string scanner that is used by the template parser to find
 * tokens in template strings.
 */
local Scanner = class {
  string = ""
  tail   = ""
  pos    = 0

  constructor (_string) {
    string = _string
    tail = string
    pos = 0
  }

  /**
   * Returns `true` if the tail is empty (end of string).
   */
  function eos () {
    return tail == ""
  }

  /**
   * Tries to match the given regular expression at the current position.
   * Returns the matched text if it can match, the empty string otherwise.
   */
  function scan (re) {
    local match = re.search(this.tail)

    if (match && match.begin == 0) {
      local string = this.tail.slice(0, match.end)//warning disable: -ident-hides-ident
      this.tail = this.tail.slice(match.end)
      this.pos += string.len()
      return string
    }

    return ""
  }

  /**
   * Skips all text until the given regular expression can be matched. Returns
   * the skipped string, which is the entire tail if no match can be made.
   */
  function scanUntil(re) {
    local res = re.search(tail)
    local match

    if (res == null) {
      match = tail
      tail = ""
    }
    else if (res.begin == 0)
      match = ""
    else {
      match = tail.slice(0, res.begin)
      tail = tail.slice(res.begin)
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

  constructor(_view, _parentContext = null) {
    view          = _view == null ? {} : _view
    cache         = {}
    cache["."]    <- view
    parentContext = _parentContext
  }

  /**
   * Creates a new context using the given view with this context
   * as the parent.
   */
  function push(view) {//warning disable: -ident-hides-ident
    return Context(view, this)
  }

  /**
   * Returns the value of the given name in this context, traversing
   * up the context hierarchy if the value is absent in this context's view.
   */
  function lookup (name) {
    local value = null
    local context = this
    if (name in cache)
      value = cache[name]
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

      cache[name] <- value
    }

    if (typeof value == "function") {
      value = value.call(context.view)
    }

    return value
  }
}

/**
 * A Writer knows how to take a stream of tokens and render them to a
 * string, given a context. It also maintains a cache of templates to
 * avoid the need to parse the same template twice.
 */

local Writer = class {
  cache = {}
  tags = ["<<", ">>"]

  static whiteRe  = ::regexp(@"\s*")
  static spaceRe  = ::regexp(@"\s+")
  static equalsRe = ::regexp(@"\s*=")
  static curlyRe  = ::regexp(@"\s*\}")
  static tagRe    = ::regexp(@"#|\^|\/|>|\{|&|=|!|@|?")
  static escapeRe = ::regexp(@"[\-\[\]{}()*+?.,\\\^$|#\s]")
  static nonSpaceRe = ::regexp(@"\S")

  constructor() {
    this.cache = {}
  }

  /**
   * Clears all cached templates in this writer.
   */
  function clearCache() {
    this.cache = {}
  }

  /**
   * Parses and caches the given `template` and returns the array of tokens
   * that is generated from the parse.
   */
  function parse(template, tags = null) { //warning disable: -ident-hides-ident

    local cache = this.cache //warning disable: -ident-hides-ident
    local tokens = cache?[template]

    if (tokens == null) {
      tokens = parseTemplate(template, tags)
      cache[template] <- tokens
    }

    return tokens
  }

  /**
   * High-level method that is used to render the given `template` with
   * the given `view`.
   *
   * The optional `partials` argument may be an object that contains the
   * names and templates of partials that are used in the template. It may
   * also be a function that is used to load partial templates on the fly
   * that takes a single argument: the name of the partial.
   */
  function render(template, view, partials = null) {
    local tokens = this.parse(template)
    local context = (typeof view == "instance" && view instanceof Context) ? view : Context(view)
    return this.renderTokens(tokens, context, partials, template)
  }

  /**
   * Low-level method that renders the given array of `tokens` using
   * the given `context` and `partials`.
   *
   * Note: The `originalTemplate` is only ever used to extract the portion
   * of the original template that was contained in a higher-order section.
   * If the template doesn't use higher-order sections, this argument may
   * be omitted.
   */
  function renderTokens(tokens, context, partials, originalTemplate) {
    local buffer = []

    // This function is used to render an arbitrary template
    // in the current context by higher-order sections.
    local self = this
    local subRender = (@(self, context, partials) function (template) {// warning disable: -ident-hides-ident
      return self.render(template, context, partials)
    })(self, context, partials)

    local token
    local value

    for (local i = 0; i < tokens.len(); ++i) {
      token = tokens[i]

      if (token[0] == "#") {
        value = context.lookup(token[1])
        if (!value)
          continue
        if (typeof value == "array") {
          for (local j = 0; j < value.len(); ++j) {
            buffer.append(this.renderTokens(token[4], context.push(value[j]), partials, originalTemplate))
          }
        }
        else if (typeof value == "table" || typeof value == "instance" || typeof value == "string") { // !!!!

          buffer.append(this.renderTokens(token[4], context.push(value), partials, originalTemplate))
        }
        else if (typeof value == "function") {
          if (typeof originalTemplate != "string") {
            ::dagor.assertf(false, "Cannot use higher-order sections without the original template")
            return "".join(buffer)
          }

          // Extract the portion of the original template that the section contains.
          value = value.call(context.view, originalTemplate.slice(token[3], token[5]), subRender)

          if (typeof value == "string")
            buffer.append(value)
        }
        else {
          buffer.append(this.renderTokens(token[4], context, partials, originalTemplate))
        }
      }
      else if (token[0] == "^"){
        value = context.lookup(token[1])

        if (!value || ((typeof value == "array") && value.len() == 0)) {
          buffer.append(this.renderTokens(token[4], context, partials, originalTemplate))
        }
      }
      else if (token[0] == ">") {
        if (!partials)
          continue

        if (typeof partials == "function")
          value = partials(token[1])
        else if (token[1] in partials)
          value = partials[token[1]]

        if (value != null) {
          local valueTemplate
          local valueTokens
          // Assume value is a path to some cached template.
          if (value in ::handyman.templateByTemplatePath) {
            valueTemplate = ::handyman.templateByTemplatePath[value]
            valueTokens = ::handyman.tokensByTemplatePath[value]
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
          if (typeof value == "string")
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
        buffer.append(g_string.stripTags(::loc(token[1])))
      else if (token[0] == "text")
        buffer.append(token[1])
    }

    return "".join(buffer)
  }

  function isWhitespace(string) {
    return !nonSpaceRe.match(string)
  }

  function escapeRegExp(string) {
    local start = 0
    local matches = []
    local match = escapeRe.search(string, start)
    while (match) {
      matches.append(match)
      start = match.end
      match = escapeRe.search(string, start)
    }

    for(local i = matches.len() - 1; i >= 0; i--) {
      match = matches[i]
      string = "".concat(string.slice(0, match.begin), "\\", string.slice(match.begin))
    }
    return string
  }

  function escapeTags(tags) { //warning disable: -ident-hides-ident

    if (!(typeof tags == "array") || tags.len() != 2) {
      ::dagor.assertf(false, $"Invalid tags: {tags}")
    }

    return [
      ::regexp("".concat(escapeRegExp(tags[0]), "\\s*")),
      ::regexp("".concat("\\s*", escapeRegExp(tags[1])))
    ]
  }

  function parseTemplate(template, _tags = null) {
    local tags = _tags || tags //warning disable: -ident-hides-ident
    template = template || ""

    if (typeof tags == "string")
     tags = g_string.split(tags, spaceRe)

    local tagRes  = escapeTags(tags)
    local scanner = Scanner(template)

    local sections = []     // Stack to hold section tokens
    local tokens   = []     // Buffer to hold the tokens
    local spaces   = []     // Indices of whitespace tokens on the current line
    local hasTag   = false  // Is there a {{tag}} on the current line?
    local nonSpace = false  // Is there a non-space char on the current line?
    local scanError = false

    local start, tType, value, chr, token, openSection
    while (!scanner.eos()) {
      start = scanner.pos

      // Match any text between tags.
      value = scanner.scanUntil(tagRes[0])
      if (value != "") {
        for (local i = 0; i < value.len(); ++i) {

          chr = value.slice(i, i + 1)

          if (isWhitespace(chr))
            spaces.append(tokens.len())
          else
            nonSpace = true

          tokens.append(["text", chr, start, start + 1])
          start += 1

          // Check for whitespace on the current line.
          if (chr == "\n") {
            // Strips all whitespace tokens array for the current line
            // if there was a {{#tag}} on it and otherwise only space.
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

      // Match the opening tag.
      if (!scanner.scan(tagRes[0]))
        break
      hasTag = true

      // Get the tag type.
      local scaned = scanner.scan(tagRe)
      tType = scaned == "" ? "name" : scaned
      scanner.scan(whiteRe)

      // Get the tag value.
      if (tType == "=") {
        value = scanner.scanUntil(equalsRe)
        scanner.scan(equalsRe)
        scanner.scanUntil(tagRes[1])
      }
      else if (tType == "{") {
        value = scanner.scanUntil(::regexp("".concat("\\s*", escapeRegExp($"\}{tags[1]}"))))
        scanner.scan(curlyRe)
        scanner.scanUntil(tagRes[1])
        tType = "&"
      }
      else {
        value = scanner.scanUntil(tagRes[1])
      }

      // Match the closing tag.
      if (!scanner.scan(tagRes[1])) {
        ::dagor.assertf(false, $"Unclosed tag at {scanner.pos}")
        scanError = true
        break
      }
      token = [ tType, value, start, scanner.pos ]
      tokens.append(token)

      if (tType == "#" || tType == "^") {
        sections.append(token)
      }
      else if (tType == "/") {
        // Check section nesting
        openSection = sections.len()? sections.pop() : null

        if (!openSection) {
          ::dagor.assertf(false, $"Unopened section \"{value}\" at {start}")
          scanError = true
          break
        }

        if (openSection[1] != value) {
          ::dagor.assertf(false, $"Unclosed section \"{openSection[1]}\" at {start}")
          scanError = true
          break
        }
      }
      else if (tType == "name" || tType == "{" || tType == "&") {
        nonSpace = true
      }
      else if (tType == "=") {
        // Set the tags for the next time around.
        tags = value.split(spaceRe)
        tagRes = escapeTags(tags)
      }
    }

    // Make sure there are no open sections when we're done.
    if (sections.len() > 0)
      ::dagor.assertf(false, $"Unclosed section \"{sections[sections.len() - 1][1]}\" at {scanner.pos}")

    if (scanError)
      tokens = []

    return nestTokens(squashTokens(tokens))
  }

  /**
   * Combines the values of consecutive text tokens in the given `tokens` array
   * to a single token.
   */
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

  /**
   * Forms the given array of `tokens` into a nested tree structure where
   * tokens that represent a section have two additional items: 1) an array of
   * all tokens that appear in that section and 2) the index in the original
   * template that represents the end of that section.
   */
  function nestTokens(tokens) {
    local nestedTokens = []
    local collector = nestedTokens
    local sections = []

    local token, section

    for (local i = 0; i < tokens.len(); ++i) {
      token = tokens[i]
      switch (token[0]) {
        case "#":
        case "^":
          collector.append(token)
          sections.append(token)
          token.resize(5, [])
          collector = []
          token[4] = collector
          break

        case "/":
          section = sections.pop()
          section.resize(6, [])
          section[5] = token[2]
          collector = sections.len() > 0 ? sections[sections.len() - 1][4] : nestedTokens
          break

        default:
          collector.append(token)
      }
    }

    return nestedTokens
  }
}

::handyman <- {

  // All high-level functions use this writer.
  defaultWriter = Writer()

  // Caching
  tokensByTemplatePath = {}
  templateByTemplatePath = {}

  lastCacheReset = 0

  /*
   * Clears all cached templates in the default writer.
   * */
  function clearCache() {
    return defaultWriter.clearCache()
  }

  /*
   * Parses and caches the given template in the default writer and returns the
   * array of tokens it contains. Doing this ahead of time avoids the need to
   * parse templates on the fly as they are rendered.
   * */
  function parse(template, tags) {
    return defaultWriter.parse(template, tags)
  }

  /*
   * Renders the `template` with the given `view` and `partials` using the
   * default writer.
   * */
  function render(template, view, partials = null) {
    return defaultWriter.render(template, view, partials)
  }

  /**
   * @param cachePartials Setting this flag to 'true' means that values
   * in 'partials' table are actually paths to corresponding templates
   * which can be cached to increase render performance.
   */
  function renderCached(templatePath, view, partials = null, cachePartials = false) {
    updateCache(templatePath)
    if (partials != null && cachePartials)
      foreach (partialName, partialPath in partials)
        updateCache(partialPath)
    local tokens = tokensByTemplatePath[templatePath]
    local template = tokensByTemplatePath[templatePath]
    local context = (typeof view == "instance" && view instanceof Context) ? view : Context(view)
    return defaultWriter.renderTokens(tokens, context, partials, template)
  }

  function checkCacheReset() {//only for easier development

    if (!::always_reload_scenes || ::dagor.getCurTime() - lastCacheReset < 1000)
      return

    lastCacheReset = ::dagor.getCurTime()
    tokensByTemplatePath.clear()
  }

  function updateCache(templatePath) {
    checkCacheReset()
    if (templatePath in tokensByTemplatePath)
      return
    local template = ::load_template_text(templatePath)
    template = processIncludes(template)
    templateByTemplatePath[templatePath] <- template
    tokensByTemplatePath[templatePath] <- defaultWriter.parseTemplate(template)
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

      local includeRes = ::load_template_text(fName)
      template = "".concat(template.slice(0, startIdx), includeRes, template.slice(endIdx + 1))
    }
    return template
  }

  /*
   * Helpers  function for rendering nested template
   * @template - as regular, nested template string
   * @translation - function, which returns wiew for nested template
   * */
  function renderNested(template, translate) {
    return (@(template, translate) function() {
      return (@(template, translate) function(text, render) {  // warning disable: -ident-hides-ident
        return ::handyman.render(template, translate(render(text)))
      })(template, translate)
    })(template, translate)
  }
}


/*******************************************************************************
 *******************************************************************************
 ************************************ TESTS ************************************
 *******************************************************************************
 ******************************************************************************/


local function testhandyman(_temaple = null, _view = null, partails = null) { // warning disable: -declared-never-used
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

local partials = {
  first = @"text{
    test:t='<<name>>';
  }"
  link = @"link {
  href:t='<<url>>';
  text:t='<<name>>';
}"
}


  local testView = {
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
  ::dlog("before render")
  ::dlog(handyman.render(testTemplate, testView, partials))
}
