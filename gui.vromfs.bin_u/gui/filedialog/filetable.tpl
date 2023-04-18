<<#rows>>
tr {
  id:t='<<row_id>>'
  <<#even>> even:t='yes' <</even>>
  <<#isHeaderRow>>
    inactive:t='yes';
    commonTextColor:t='yes';
    bigIcons:t='yes';
    auto-scroll:t='yes';
  <</isHeaderRow>>
  <<@trParams>>

  <<#cells>>
  td {
    id:t='<<id>>'
    <<#width>> width:t='<<width>>' <</width>>
    overflow:t='hidden';
    <<#tooltip>> tooltip:t='<<tooltip>>' <</tooltip>>
    <<#tdalign>> tdalign:t='<<tdalign>>' <</tdalign>>
    <<#active>> active:t='yes' <</active>>
    <<@rawParam>>

    <<#callback>>
      behaviour:t='button'
      on_click:t='<<callback>>'
    <</callback>>

    <<#text>>
      activeText {
        id:t='txt_<<id>>'
        behaviour:t='OverflowScroller';
        text:t='<<text>>'
        auto-scroll:t='slow';
        <<@textRawParam>>
      }
    <</text>>

    <<#image>>
      cardImg {
        id:t='img_<<id>>'
        background-image:t='<<image>>'
        <<@imageRawParams>>
      }
    <</image>>
  }
  <</cells>>
}
<</rows>>
