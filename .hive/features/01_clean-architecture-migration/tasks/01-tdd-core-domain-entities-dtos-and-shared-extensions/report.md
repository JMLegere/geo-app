# Task Report: 01-tdd-core-domain-entities-dtos-and-shared-extensions

**Feature:** clean-architecture-migration
**Completed:** 2026-04-06T03:17:55.224Z
**Status:** success
**Commit:** 4b0f44cb825b9a1a0cc83827a618a5914455930a

---

## Summary

Created 11 new lib/ files and 11 matching test files via strict TDD (red→green for each). Core domain entities (UserProfile, AuthState, IucnStatus, TaxonomicGroup, Habitat, GameRegion, Item) are pure Dart with no Flutter imports. DTOs (UserProfileDto, ItemDto) handle serialization in the data layer. Shared extensions (IucnStatusTheme, iconography with AppIcons/PackSortMode) add Flutter/emoji concerns without polluting domain. All 276 tests pass, flutter analyze reports 0 issues.

---

## Changes

- **Files changed:** 80
- **Insertions:** +1462
- **Deletions:** -0

### Files Modified

- `.../res/drawable-hdpi/ic_launcher_foreground.png`
- `.../res/drawable-mdpi/ic_launcher_foreground.png`
- `.../src/main/res/drawable-night-v21/background.png`
- `.../app/src/main/res/drawable-night/background.png`
- `.../app/src/main/res/drawable-v21/background.png`
- `.../res/drawable-xhdpi/ic_launcher_foreground.png`
- `.../res/drawable-xxhdpi/ic_launcher_foreground.png`
- `.../drawable-xxxhdpi/ic_launcher_foreground.png`
- `android/app/src/main/res/drawable/background.png`
- `.../app/src/main/res/mipmap-hdpi/ic_launcher.png`
- `.../app/src/main/res/mipmap-hdpi/launcher_icon.png`
- `.../app/src/main/res/mipmap-mdpi/ic_launcher.png`
- `.../app/src/main/res/mipmap-mdpi/launcher_icon.png`
- `.../app/src/main/res/mipmap-xhdpi/ic_launcher.png`
- `.../src/main/res/mipmap-xhdpi/launcher_icon.png`
- `.../app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
- `.../src/main/res/mipmap-xxhdpi/launcher_icon.png`
- `.../src/main/res/mipmap-xxxhdpi/ic_launcher.png`
- `.../src/main/res/mipmap-xxxhdpi/launcher_icon.png`
- `.../AppIcon.appiconset/Icon-App-1024x1024@1x.png`
- `.../AppIcon.appiconset/Icon-App-20x20@1x.png`
- `.../AppIcon.appiconset/Icon-App-20x20@2x.png`
- `.../AppIcon.appiconset/Icon-App-20x20@3x.png`
- `.../AppIcon.appiconset/Icon-App-29x29@1x.png`
- `.../AppIcon.appiconset/Icon-App-29x29@2x.png`
- `.../AppIcon.appiconset/Icon-App-29x29@3x.png`
- `.../AppIcon.appiconset/Icon-App-40x40@1x.png`
- `.../AppIcon.appiconset/Icon-App-40x40@2x.png`
- `.../AppIcon.appiconset/Icon-App-40x40@3x.png`
- `.../AppIcon.appiconset/Icon-App-50x50@1x.png`
- `.../AppIcon.appiconset/Icon-App-50x50@2x.png`
- `.../AppIcon.appiconset/Icon-App-57x57@1x.png`
- `.../AppIcon.appiconset/Icon-App-57x57@2x.png`
- `.../AppIcon.appiconset/Icon-App-60x60@2x.png`
- `.../AppIcon.appiconset/Icon-App-60x60@3x.png`
- `.../AppIcon.appiconset/Icon-App-72x72@1x.png`
- `.../AppIcon.appiconset/Icon-App-72x72@2x.png`
- `.../AppIcon.appiconset/Icon-App-76x76@1x.png`
- `.../AppIcon.appiconset/Icon-App-76x76@2x.png`
- `.../AppIcon.appiconset/Icon-App-83.5x83.5@2x.png`
- `.../LaunchBackground.imageset/background.png`
- `.../LaunchBackground.imageset/darkbackground.png`
- `.../LaunchImage.imageset/LaunchImage.png`
- `.../LaunchImage.imageset/LaunchImage@2x.png`
- `.../LaunchImage.imageset/LaunchImage@3x.png`
- `lib/core/domain/entities/auth_state.dart`
- `lib/core/domain/entities/game_region.dart`
- `lib/core/domain/entities/habitat.dart`
- `lib/core/domain/entities/item.dart`
- `lib/core/domain/entities/iucn_status.dart`
- `lib/core/domain/entities/taxonomic_group.dart`
- `lib/core/domain/entities/user_profile.dart`
- `lib/features/auth/data/dtos/user_profile_dto.dart`
- `.../identification/data/dtos/item_dto.dart`
- `lib/shared/extensions/iconography.dart`
- `lib/shared/extensions/iucn_status_theme.dart`
- `.../AppIcon.appiconset/app_icon_1024.png`
- `.../AppIcon.appiconset/app_icon_128.png`
- `.../AppIcon.appiconset/app_icon_16.png`
- `.../AppIcon.appiconset/app_icon_256.png`
- `.../AppIcon.appiconset/app_icon_32.png`
- `.../AppIcon.appiconset/app_icon_512.png`
- `.../AppIcon.appiconset/app_icon_64.png`
- `test/core/domain/entities/auth_state_test.dart`
- `test/core/domain/entities/game_region_test.dart`
- `test/core/domain/entities/habitat_test.dart`
- `test/core/domain/entities/item_test.dart`
- `test/core/domain/entities/iucn_status_test.dart`
- `.../core/domain/entities/taxonomic_group_test.dart`
- `test/core/domain/entities/user_profile_test.dart`
- `.../auth/data/dtos/user_profile_dto_test.dart`
- `.../identification/data/dtos/item_dto_test.dart`
- `test/shared/extensions/iconography_test.dart`
- `test/shared/extensions/iucn_status_theme_test.dart`
- `web/favicon.png`
- `web/icons/Icon-192.png`
- `web/icons/Icon-512.png`
- `web/icons/Icon-maskable-192.png`
- `web/icons/Icon-maskable-512.png`
- `windows/runner/resources/app_icon.ico`
