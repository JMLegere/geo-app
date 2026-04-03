import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/data/repos/hierarchy_repo.dart';
import 'package:earth_nova/providers/database_provider.dart';

final hierarchyRepoProvider = Provider<HierarchyRepo>((ref) {
  return HierarchyRepo(ref.watch(databaseProvider));
});
