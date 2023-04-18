<<#rows>>
options_list {
  flow:t='vertical';
  text {
    text:t='<<option_title>>';
  }
  options_nest {
    MultiSelect {
      id:t='<<option_id>>';
      uid:t='<<option_uid>>';
      idx:t='<<option_idx>>';
      value:t='<<option_value>>';
      on_select:t='<<#cb>><<cb>><</cb>><<^cb>>onSelectedOptionChooseUnit<</cb>>'
      flow:t='horizontal';
      smallFont:t='yes';
      optionsShortcuts:t='yes';
      <<#nums>>
      multiOption {
        filter_multi_option:t='yes';
        textareaNoTab {
          max-width:t='0.5@rw -0.5@slot_width'
          pos:t='1@blockInterval, ph/2-h/2'; position:t='relative'
          text:t='<<option_name>>';
          text-align:t='right';
          input-transparent:t='yes';
        }
        <<^visible>>
        display:t='hide';
        inactive:t='yes';
        <</visible>>
        CheckBoxImg{}
      }
      <</nums>>
    }
  }
}
<</rows>>