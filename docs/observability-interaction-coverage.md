| Callback location | Instrumentation wrapper | Expected action_type | Expected payload keys |
|---|---|---|---|
| lib/shared/widgets/tab_shell.dart:84 | ObservableInteraction.wrapValueChanged | tab_selected | action_type,screen_name,widget_name,tab_index |
| lib/features/map/presentation/screens/map_root_screen.dart:41 | ObservableInteraction.wrapScaleEnd | pinch_level_change | action_type,screen_name,widget_name,gesture_direction |
| lib/features/map/presentation/screens/map_screen.dart:298 | ObservableInteraction.wrapTapUp | cell_overlay_tap | action_type,screen_name,widget_name |
| lib/features/map/presentation/screens/map_screen.dart:164 | ObservableInteraction.wrapVoidCallback | snackbar_dismiss | action_type,screen_name,widget_name |
| lib/features/map/presentation/widgets/hierarchy_header.dart:93 | ObservableInteraction.wrapVoidCallback | back_tap | action_type,screen_name,widget_name |
