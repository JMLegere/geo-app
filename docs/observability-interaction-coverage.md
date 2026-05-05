| Callback location | Instrumentation wrapper | Expected action_type | Expected payload keys |
|---|---|---|---|
| lib/features/auth/presentation/screens/login_screen.dart:152 | ObservableInteraction.wrapAsyncCallback | submit | action_type,screen_name,widget_name,flow |
| lib/shared/widgets/tab_shell.dart:159 | ObservableInteraction.wrapValueChanged | tab_selected | action_type,screen_name,widget_name,tab_index |
| lib/features/identification/presentation/screens/pack_screen.dart:113 | ObservableInteraction.log | category_page_changed | action_type,screen_name,widget_name,category,category_index |
| lib/features/identification/presentation/screens/pack_screen.dart:177 | ObservableInteraction.log | select_category | action_type,screen_name,widget_name,category,category_index |
| lib/features/identification/presentation/screens/pack_screen.dart:190 | ObservableInteraction.log | sort_changed | action_type,screen_name,widget_name,sort |
| lib/features/identification/presentation/screens/pack_screen.dart:195 | ObservableInteraction.log | filter_type_toggled | action_type,screen_name,widget_name,type,active_after |
| lib/features/identification/presentation/screens/pack_screen.dart:203 | ObservableInteraction.log | filter_habitat_toggled | action_type,screen_name,widget_name,habitat,active_after |
| lib/features/identification/presentation/screens/pack_screen.dart:211 | ObservableInteraction.log | filter_region_toggled | action_type,screen_name,widget_name,region,active_after |
| lib/features/identification/presentation/screens/pack_screen.dart:219 | ObservableInteraction.log | filter_rarity_toggled | action_type,screen_name,widget_name,rarity,active_after |
| lib/features/identification/presentation/screens/pack_screen.dart:227 | ObservableInteraction.log | clear_filters | action_type,screen_name,widget_name,active_filter_count |
| lib/features/identification/presentation/screens/pack_screen.dart:234 | ObservableInteraction.log | toggle_filter_panel | action_type,screen_name,widget_name,expanded_after |
| lib/features/identification/presentation/screens/pack_screen.dart:241 | ObservableInteraction.log | search_changed | action_type,screen_name,widget_name,query_length,had_previous_query |
| lib/features/identification/presentation/screens/pack_screen.dart:250 | ObservableInteraction.log | open_species_card | action_type,screen_name,widget_name,item_id,category,rarity,has_frame2 |
| lib/features/profile/presentation/screens/settings_screen.dart:58 | ObservableInteraction.wrapValueChanged | toggle_debug_mode | action_type,screen_name,widget_name,enabled |
| lib/features/profile/presentation/screens/settings_screen.dart:69 | ObservableInteraction.wrapVoidCallback | open_sign_out_dialog | action_type,screen_name,widget_name |
| lib/features/profile/presentation/screens/settings_screen.dart:110 | ObservableInteraction.wrapVoidCallback | cancel_sign_out | action_type,screen_name,widget_name |
| lib/features/profile/presentation/screens/settings_screen.dart:120 | ObservableInteraction.wrapVoidCallback | confirm_sign_out | action_type,screen_name,widget_name |
| lib/features/map/presentation/screens/map_root_screen.dart:72 | ObservableInteraction.wrapScaleEnd | pinch_level_change | action_type,screen_name,widget_name,gesture_direction |
| lib/features/map/presentation/screens/map_screen.dart:628 | ObservableInteraction.wrapTapUp | cell_overlay_tap | action_type,screen_name,widget_name |
| lib/features/map/presentation/screens/map_screen.dart:706 | ObservableInteraction.wrapVoidCallback | toast_dismiss | action_type,screen_name,widget_name |
| lib/features/map/presentation/widgets/hierarchy_header.dart:93 | ObservableInteraction.wrapVoidCallback | back_tap | action_type,screen_name,widget_name |
