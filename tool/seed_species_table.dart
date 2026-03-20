import 'dart:convert';
import 'dart:io';

Future<bool> upsertBatch(
  HttpClient client,
  Uri uri,
  String serviceKey,
  List<Map<String, dynamic>> batch,
  int offset,
) async {
  final request = await client.postUrl(uri);
  request.headers.set('Authorization', 'Bearer $serviceKey');
  request.headers.set('apikey', serviceKey);
  request.headers.set('Content-Type', 'application/json');
  request.headers.set('Prefer', 'resolution=merge-duplicates');
  request.add(utf8.encode(jsonEncode(batch)));
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();

  if (response.statusCode >= 200 && response.statusCode < 300) {
    return true;
  } else {
    stderr.writeln(
      'Batch at offset $offset failed: ${response.statusCode} $body',
    );
    return false;
  }
}

void main() async {
  final supabaseUrl = Platform.environment['SUPABASE_URL'];
  final serviceKey = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];

  if (supabaseUrl == null || serviceKey == null) {
    stderr.writeln('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
    exit(1);
  }

  // Load species data
  final jsonFile = File('assets/species_data.json');
  if (!await jsonFile.exists()) {
    stderr.writeln('assets/species_data.json not found');
    exit(1);
  }

  final jsonStr = await jsonFile.readAsString();
  final species = jsonDecode(jsonStr) as List;
  print('Loaded ${species.length} species');

  final uri =
      Uri.parse('$supabaseUrl/rest/v1/species?on_conflict=definition_id');
  final client = HttpClient();

  const batchSize = 500;
  int upserted = 0;
  int failed = 0;

  for (int i = 0; i < species.length; i += batchSize) {
    final batch = species.skip(i).take(batchSize).map((s) {
      final m = s as Map<String, dynamic>;
      final sciName = m['scientificName'] as String;
      return <String, dynamic>{
        'definition_id': 'fauna_${sciName.toLowerCase().replaceAll(' ', '_')}',
        'scientific_name': sciName,
        'common_name': m['commonName'],
        'taxonomic_class': m['taxonomicClass'],
        'iucn_status': m['iucnStatus'],
        'habitats_json': jsonEncode(m['habitats']),
        'continents_json': jsonEncode(m['continents']),
      };
    }).toList();

    var success = await upsertBatch(client, uri, serviceKey, batch, i);

    if (!success) {
      stderr.writeln('Retrying batch at offset $i...');
      await Future.delayed(const Duration(seconds: 2));
      success = await upsertBatch(client, uri, serviceKey, batch, i);
      if (!success) {
        stderr.writeln('Batch at offset $i failed after retry — skipping');
        failed += batch.length;
        continue;
      }
    }

    upserted += batch.length;
    print('Upserted $upserted / ${species.length}');
  }

  client.close();

  if (failed > 0) {
    stderr.writeln('Done with errors: $upserted upserted, $failed failed');
    exit(1);
  } else {
    print('Done: $upserted species upserted successfully');
  }
}
