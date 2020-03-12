rootUnderPopupMenu {
  on_click:t='goBack'
  on_r_click:t='goBack'
  input-transparent:t='yes'
}

popup_menu {
  id:t='main_frame'
  width:t='<<itemsInRow>> * 0.5@itemWidth +  <<columns>> * 2@recipeInterval + (<<columns>> - 1) * @itemsSeparatorSize+ 2@dp'
  position:t='root'
  pos:t='<<position>>'
  menu_align:t='<<align>>'
  total-input-transparent:t='yes'
  flow:t='vertical'

  Button_close { _on_click:t='goBack'; smallIcon:t='yes'}

  textAreaCentered {
    id:t='header_text'
    width:t='pw'
    overlayTextColor:t='active'
    text:t='<<headerText>>'
  }

  tdiv {
    size:t='pw, @itemsSeparatorSize'
    background-color:t='@frameSeparatorColor'
    margin-top:t='1@blockInterval'
  }

  div {
    id:t='recipes_list'
    width:t='pw'
    padding:t='-1@framePadding + 1@dp, 0'
    padding-bottom:t='-1@blockInterval'
    height:t='<<rows>>*(0.5@itemHeight + 1@recipeInterval) + 1@recipeInterval - 1@blockInterval'
    flow:t="v-flow"
    total-input-transparent:t='yes'
    overflow-y:t='auto'

    behaviour:t='posNavigator'
    moveX:t='linear'
    moveY:t='linear'
    navigatorShortcuts:t='yes'
    on_select:t='onRecipeSelect'

    <<#recipesList>>
    <<#isSeparator>>
    itemsSeparator { height:t='ph - 2@recipeInterval'; margin:t='@recipeInterval, 0'; }
    <</isSeparator>>
    <<^isSeparator>>
    recipe {
      id = 'id_<<@uid>>'
      height:t='0.5@itemHeight'
      margin:t='@recipeInterval'
      smallItems:t="yes"
      css-hier-invalidate:t='yes'
      isRecipeLocked:t=<<#isRecipeLocked>>'yes'<</isRecipeLocked>><<^isRecipeLocked>>'no'<</isRecipeLocked>>

      <<@getIconedMarkup>>

      <<#hasMarkers>>
      img{
        id:t='img_<<@uid>>'
        pos:t='pw - 0.8w, ph - 0.8h'
        position:t='absolute'
        size:t='@cIco, @cIco'
        background-svg-size:t='@cIco, @cIco'
        background-image:t='<<@getMarkIcon>>'
        background-repeat:t='aspect-ratio'
        input-transparent:t='yes'
        tooltip:t='<<@getMarkTooltip>>'
      }
      <</hasMarkers>>

      focus_border {}
    }
    <</isSeparator>>
    <</recipesList>>
  }

  navBar {
    class:t='relative'
    //0.1@dico - is a visual space in item type icon.
    style:t='height:(<<maxRecipeLen>><<#hasMarkers>>+1<</hasMarkers>>)@dIco + 1@buttonHeight + 1@navBarTopPadding + 1@buttonMargin;'

    navLeft {
      size:t='pw, ph - 1@navBarTopPadding'
      tdiv {
        id:t='selected_recipe_info'
        width:t='pw'
        pos:t='0, 0.1@dIco'
        position:t='relative'
      }
    }

    navRight {
      height:t='ph - 1@navBarTopPadding'
      left:t='pw - w'
      position:t='relative'
      <<#hasMarkers>>
      Button_text {
        id:t = 'btn_mark'
        text:t = '#item/recipes/markFake'
        btnName:t='X'
        _on_click:t = 'onRecipeMark'
        ButtonImg {}
      }
      <</hasMarkers>>
      Button_text {
        id:t = 'btn_apply'
        text:t = '<<buttonText>>'
        btnName:t='A'
        _on_click:t = 'onRecipeApply'
        ButtonImg {}
      }
    }
  }

  popup_menu_arrow{}
}
