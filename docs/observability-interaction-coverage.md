| Callback location | Instrumentation wrapper | Expected action_type | Expected payload keys |
|---|---|---|---|
| lib/features/auth/presentation/screens/login_screen.dart:145 | ObservableInteraction.wrapVoidCallback | tap | action_type,screen_name,widget_name,input_valid |
| lib/shared/widgets/tab_shell.dart:84 | ObservableInteraction.wrapValueChanged | tab_selected | action_type,screen_name,widget_name,tab_index |
| lib/features/map/presentation/screens/map_root_screen.dart:41 | ObservableInteraction.wrapScaleEnd | pinch_level_change | action_type,screen_name,widget_name,gesture_direction |
| lib/features/map/presentation/screens/map_screen.dart:298 | ObservableInteraction.wrapTapUp | cell_overlay_tap | action_type,screen_name,widget_name |
| lib/features/map/presentation/screens/map_screen.dart:164 | ObservableInteraction.wrapVoidCallback | snackbar_dismiss | action_type,screen_name,widget_name |
| lib/features/map/presentation/widgets/hierarchy_header.dart:93 | ObservableInteraction.wrapVoidCallback | back_tap | action_type,screen_name,widget_name |
| lib/features/identification/presentation/screens/pack_screen.dart:66 | ObservableInteraction.log | category_page_swipe | action_type,screen_name,widget_name,category_index |
| lib/features/identification/presentation/screens/pack_screen.dart:121 | ObservableInteraction.wrapValueChanged | category_tab_tap | action_type,screen_name,widget_name,category_index |
| lib/features/identification/presentation/screens/pack_screen.dart:130 | ObservableInteraction.wrapValueChanged | sort_mode_toggle | action_type,screen_name,widget_name,sort_mode |
| lib/features/identification/presentation/screens/pack_screen.dart:139 | ObservableInteraction.wrapValueChanged | type_filter_toggle | action_type,screen_name,widget_name,taxonomic_group |
| lib/features/identification/presentation/screens/pack_screen.dart:148 | ObservableInteraction.wrapValueChanged | habitat_filter_toggle | action_type,screen_name,widget_name,habitat |
| lib/features/identification/presentation/screens/pack_screen.dart:157 | ObservableInteraction.wrapValueChanged | region_filter_toggle | action_type,screen_name,widget_name,region |
| lib/features/identification/presentation/screens/pack_screen.dart:166 | ObservableInteraction.wrapValueChanged | rarity_filter_toggle | action_type,screen_name,widget_name,rarity |
| lib/features/identification/presentation/screens/pack_screen.dart:174 | ObservableInteraction.wrapVoidCallback | clear_filters | action_type,screen_name,widget_name |
| lib/features/identification/presentation/screens/pack_screen.dart:181 | ObservableInteraction.wrapVoidCallback | toggle_filter_panel | action_type,screen_name,widget_name,panel_expanded |
| lib/features/identification/presentation/screens/pack_screen.dart:190 | ObservableInteraction.wrapValueChanged | search_changed | action_type,screen_name,widget_name,query_length |
| lib/features/identification/presentation/screens/pack_screen.dart:103 | ObservableInteraction.wrapVoidCallback | retry_fetch | action_type,screen_name,widget_name |
| lib/features/identification/presentation/screens/pack_screen.dart:1100 | ObservableInteraction.wrapVoidCallback | search_clear | action_type,screen_name,widget_name |
| lib/features/identification/presentation/screens/pack_screen.dart:1220 | ObservableInteraction.wrapVoidCallback | species_card_open | action_type,screen_name,widget_name,item_id |
| lib/features/identification/presentation/widgets/species_card.dart:73 | ObservableInteraction.log | species_card_swipe_dismiss | action_type,screen_name,widget_name |
| lib/features/identification/presentation/widgets/species_card.dart:197 | ObservableInteraction.wrapVoidCallback | species_card_close | action_type,screen_name,widget_name |
| lib/features/profile/presentation/screens/settings_screen.dart:46 | ObservableInteraction.wrapVoidCallback | sign_out_dialog_open | action_type,screen_name,widget_name |
| lib/features/profile/presentation/screens/settings_screen.dart:82 | ObservableInteraction.wrapVoidCallback | sign_out_cancel | action_type,screen_name,widget_name |
| lib/features/profile/presentation/screens/settings_screen.dart:92 | ObservableInteraction.wrapVoidCallback | sign_out_confirm | action_type,screen_name,widget_name |
