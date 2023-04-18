tdiv {
  id:t='armies_object'
  size:t='pw, ph'
  flow:t='vertical'

  HorizontalListBox {
    id:t='armies_by_status_list'
    width:t='pw'

    navigatorShortcuts:t='yes'
    on_select:t='onArmiesByStatusTabChange'

    <<#armiesByState>>
      shopFilter {
        tooltip:t='<<tabText>>'

        shopFilterText {
          text:t='<<tabIconText>> '
        }
        shopFilterText {
          id:t='army_by_state_title_<<id>>'
          display:t='hide'
          smallFont:t='yes'
          text:t='<<tabText>> '
        }
        shopFilterText {
          id:t='army_by_state_title_count_<<id>>'
          smallFont:t='yes'
          text:t='<<armiesCountText>>'
        }
      }
    <</armiesByState>>
  }

  tdiv {
    id:t='armies_tab_content'
    size:t='pw, fh'
    margin:t='1@framePadding'
    flow:t='h-flow'
    flow-align:t='left'
  }

  statusPanel {
    id:t='paginator_nest_obj'
    size:t='pw, 1@statusPanelHeight'
    background-color:t='@objectiveHeaderBackground'

    tdiv {
      id:t='paginator_place'
      pos:t='50%(pw-w), 50%(ph-h)'; position:t='relative'
    }
  }
}
