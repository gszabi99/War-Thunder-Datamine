let { split_by_chars } = require("string")
enum HINT_PIECE_TYPE
{
  TEXT,
  TAG
}


::g_hints <- {
  hintTags = ["{{", "}}"]
  timerMark = ::g_hint_tag.TIMER.typeName
  colorTags = ["<color=", "</color>"]
}

/*
  params:
  * id          //null
  * style       //""
  * time        //0 - only to show time in text
  * timeoffset  //0 - only to show time in text
*/
g_hints.buildHintMarkup <- function buildHintMarkup(text, params = {}) {
  return ::handyman.renderCached("%gui/hint", getHintSlices(text, params))
}

g_hints.getHintSlices <- function getHintSlices(text, params = {})
{
  let rows = split_by_chars(text, "\n")
  let isWrapInRowAllowed = params?.isWrapInRowAllowed ?? false
  let view = {
    id = ::getTblValue("id", params)
    style = ::getTblValue("style", params, "")
    isOrderPopup = ::getTblValue("isOrderPopup", params, false)
    isWrapInRowAllowed = isWrapInRowAllowed
    flowAlign = ::getTblValue("flowAlign", params, "center")
    animation = ::getTblValue("animation", params)
    rows = []
  }

  let colors = [] //array of opened color tags, contains color itself

  foreach (row in rows)
  {
    let slices = []
    let rawRowPieces = splitRowToPieces(row)
    let needSplitByWords = isWrapInRowAllowed && rawRowPieces.len() > 1

    foreach (rawRowPiece in rawRowPieces)
    {
      if (rawRowPiece.type == HINT_PIECE_TYPE.TEXT)
      {
        local piece = rawRowPiece.piece
        local carriage = 0
        local unclosedTags = 0
        local textsArray = []
        local lastIdxOfSlicedPiece = 0

        while (true)
        {
          let openingColorTagStartIndex = piece.indexof(colorTags[0], carriage)
          let closingColorTagStartIndex = piece.indexof(colorTags[1], carriage)

          if (openingColorTagStartIndex == null && closingColorTagStartIndex == null)
            break

          //move carriage
          if (openingColorTagStartIndex == null)
            carriage = closingColorTagStartIndex + colorTags[1].len()
          else if (closingColorTagStartIndex == null)
            carriage = openingColorTagStartIndex + colorTags[0].len()
          else
            carriage = min(
              openingColorTagStartIndex + colorTags[0].len(),
              closingColorTagStartIndex + colorTags[1].len()
            )

          //closing tag found, pop color from stack and continue
          if ((openingColorTagStartIndex == null && closingColorTagStartIndex != null) ||
            openingColorTagStartIndex > closingColorTagStartIndex)
          {
            if (unclosedTags > 0)
              unclosedTags--
            else
            {
              let lenBefore = piece.len()
              piece = "<color=" + colors.top() + ">" + piece
              carriage += piece.len() - lenBefore
            }

            colors.pop()
            if (needSplitByWords && colors.len() == 0) {
              textsArray.append(piece.slice(lastIdxOfSlicedPiece, carriage))
              lastIdxOfSlicedPiece = carriage
            }
          }

          //opening tag found, add color to stack, increment unclosedTags counter
          else if ((closingColorTagStartIndex == null && openingColorTagStartIndex != null) ||
            openingColorTagStartIndex < closingColorTagStartIndex)
          {
            let colorEnd = piece.indexof(">", openingColorTagStartIndex)
            let colorStart = openingColorTagStartIndex + colorTags[0].len()
            colors.append(piece.slice(colorStart, colorEnd))
            unclosedTags++
          }
        }

        //close all unclosed tags
        for (local i = 0; i < unclosedTags; ++i)
          piece += colorTags[1]

        if (colors.len() > 0)
          piece = ::colorize(colors.top(), piece)

        if (piece.len()) {
          if (colors.len() > 0 || !needSplitByWords)
            textsArray = [piece]
          else {
            let lastPiece = piece.slice(lastIdxOfSlicedPiece, piece.len())
            if (lastPiece != "")
              textsArray.extend(lastPiece.split(" "))
          }

          slices.append(getTextSlice(textsArray))
        }
      }
      else if (rawRowPiece.type == HINT_PIECE_TYPE.TAG)
      {
        let tagType = ::g_hint_tag.getHintTagType(rawRowPiece.piece)
        slices.extend(tagType.getViewSlices(rawRowPiece.piece, params))
      }
    }

    view.rows.append({ slices = slices })
  }

  if (colors.len())
    ::dagor.debug("unclosed <color> tag! in text: " + text)

  return view
}

/**
 * Split row to atomic parts to work with
 * @return array of strings with type specifieres (text or tag)
 */
g_hints.splitRowToPieces <- function splitRowToPieces(row)
{
  let slices = []
  while (row.len() > 0)
  {
    let tagStartIndex = row.indexof(hintTags[0])

    //no tags on current row
    //put entire row in one piece and exit
    if (tagStartIndex == null)
    {
      slices.append({
        type = HINT_PIECE_TYPE.TEXT,
        piece = row
      })
      break
    }

    let tagEndIndex = row.indexof(hintTags[1], tagStartIndex)
    //there is unclosed tag
    //flush current row content to one piece and exit
    if (tagEndIndex == null)
    {
      slices.append({
        type = HINT_PIECE_TYPE.TEXT,
        piece = row
      })
      break
    }

    //slice piece before tag
    slices.append({
      type = HINT_PIECE_TYPE.TEXT,
      piece = row.slice(0, tagStartIndex)
    })

    //slice piece that contains tag
    slices.append({
      type = HINT_PIECE_TYPE.TAG
      piece = row.slice(tagStartIndex + hintTags[0].len(), tagEndIndex)
    })

    row = row.slice(tagEndIndex + hintTags[1].len())
  }

  return slices
}

g_hints.getTextSlice <- function getTextSlice(textsArray)
{
  return { text = textsArray.map(
    @(text, idx) { textValue = textsArray?[idx+1] != null ? $"{text} " : text }) }
}

::cross_call_api.getHintConfig <- @(text) ::g_hints.getHintSlices(text, { needConfig = true })
