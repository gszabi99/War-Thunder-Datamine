<<#block>>
<<#isEmpty>>
  textAreaCentered {
    id:t='categories_header_text'
    width:t='pw'
    pos:t='50%pw-50%w, 0'
    position:t='relative'
    hideEmptyText:t='yes'
    text:t='<<textWhenEmpty>>'
    enable:t='no'
  }
<</isEmpty>>

<<#separator>>
  separator { enable:t='no' }
<</separator>>

<<#isMode>>
gameModeBlock {
  <<#isWide>>
    wide:t='yes';
  <</isWide>>
  <<^isWide>>
    <<#isNarrow>>
      narrow:t='yes';
    <</isNarrow>>
  <</isWide>>
  <<#hasContent>>
  id:t='<<id>>';
  tooltip:t='<<#crossplayTooltip>><<crossplayTooltip>>\n<</crossplayTooltip>><<tooltip>>'
  value:t='<<value>>';

  <<#isFeatured>>
  featured:t='yes';
  <</isFeatured>>

  <<#inactiveColor>>
    inactiveColor:t='yes'
  <</inactiveColor>>

  on_click:t='<<onClick>>'
  <<#onHover>>
    on_hover:t='<<onHover>>'
  <</onHover>>

  <<#isCurrentGameMode>>
    current_mode:t='yes';
  <</isCurrentGameMode>>

  behavior:t='button';
  focusBtnName:t='A'
  background-color:t='@white';
  background-repeat:t='expand';
  background-image:t='#ui/gameuiskin#item';
  background-position:t='3, 4, 3, 5';
  re-type:t='9rect';

  img {
    background-image:t='<<image>>';
    background-repeat:t='repeat-y';
  }

  <<#videoPreview>>
  movie {
    movie-load='<<videoPreview>>'
    movie-autoStart:t='yes'
    movie-loop:t='yes'
  }
  <</videoPreview>>

  glow{}

  <<#inactiveColor>>
  pattern { type:t='dark_diag_lines' }
  <</inactiveColor>>

  title {
    css-hier-invalidate:t='yes';
    tdiv {
      css-hier-invalidate:t='yes';
      flow:t='vertical';

      textarea {
        game_mode_textarea:t='yes';
        text:t='<<#isCrossPlayRequired>><<?icon/cross_play>> <</isCrossPlayRequired>><<text>>';
        <<#crossPlayRestricted>>
          overlayTextColor:t='warning'
        <</crossPlayRestricted>>
      }
      textarea {
        id:t='<<id>>_text_description'
        game_mode_textarea:t='yes';
        text:t='<<textDescription>>';
      }
    }
    <<#newIconWidgetContent>>
    div {
      id:t='<<newIconWidgetId>>'
      pos:t='0, ph-h'; position:t='relative'
      <<@newIconWidgetContent>>
    }
    <</newIconWidgetContent>>
  }

  <<#eventTrophyImage>>
  tdiv {
    height:t='1@mIco'
    padding-left:t='0.0125@scrn_tgt'

    textareaNoTab {
      pos:t='0, 50%(ph-h)'; position:t='relative'
      text:t="#reward/everyDay"
      <<^inactiveColor>>
        <<#isTrophyRecieved>>
          overlayTextColor:t='silver'
        <</isTrophyRecieved>>
        <<^isTrophyRecieved>>
          overlayTextColor:t='active'
        <</isTrophyRecieved>>
      <</inactiveColor>>
    }

    tdiv {
      pos:t='0, 50%(ph-h)'; position:t='relative'
      <<@eventTrophyImage>>

      <<#isTrophyRecieved>>
        img {
          pos:t='50%pw-20%w, 50%ph-50%h'
          position:t='absolute'
          size:t='1@mIco, 1@mIco'
          background-image:t='#ui/gameuiskin#check.svg'
          background-svg-size:t='1@mIco, 1@mIco'
          input-transparent:t='yes'
        }
      <</isTrophyRecieved>>
    }
  }
  <</eventTrophyImage>>
  <<#mapPreferences>>
  Button_text {
    modeId:t='<<modeId>>'
    visualStyle:t='translucent'
    pos:t='pw-w- 1@blockInterval, 1@blockInterval'
    position:t='absolute'
    on_click:t='onMapPreferences'
    tooltip:t='<<prefTitle>>'
    display:t='hide'
    noMargin:t='yes'
    reduceWidthToHeight:t='yes'
    showOn:t='hoverOrSelect'
    text {
      text:t='#icon/gear'
      overflow:t='hidden'
      pare-text:t='yes'
      pos:t='50%pw-50%w, 50%ph-50%h'
      position:t='relative'
    }
  }
  <</mapPreferences>>

  <<#checkBox>>
  CheckBoxImg {}
  <</checkBox>>

  <<#showEventDescription>>
  Button_text {
    visualStyle:t='translucent'
    pos:t='pw-w- 1@blockInterval, 1@blockInterval'
    position:t='absolute'
    on_click:t='onEventDescription'
    tooltip:t='#mainmenu/titleEventDescription'
    value:t='<<eventDescriptionValue>>'
    display:t='hide'
    reduceWidthToHeight:t='yes'
    noMargin:t='yes'
    show_on_parent_hover:t='yes'
    text {
      text:t='?'
      overflow:t='hidden'
      pare-text:t='yes'
      pos:t='50%pw-50%w, 50%ph-50%h'
      position:t='relative'
    }
  }
  <</showEventDescription>>

  <<#hasCountries>>
  tdiv {
    css-hier-invalidate:t='yes';
    <<#countries>>
    img {
      size:t='@cIco, @cIco';
      background-image:t='<<img>>';
      background-svg-size:t='@cIco, @cIco'
      margin-left:t='0.01@sf';
    }
    <</countries>>
  }
  <</hasCountries>>

  <<#linkIcon>>
  dark_corner {
    link_icon {}
  }
  <</linkIcon>>
  <</hasContent>>
  <<^hasContent>>
  enable:t='no';
  <</hasContent>>
}
<</isMode>>
<</block>>