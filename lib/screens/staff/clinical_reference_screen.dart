import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/clinical_reference_service.dart';

class ClinicalReferenceScreen extends StatefulWidget {
  final Future<ClinicalReferenceDataset> Function()? loader;
  const ClinicalReferenceScreen({super.key, this.loader});

  @override
  State<ClinicalReferenceScreen> createState() =>
      _ClinicalReferenceScreenState();
}

class _ClinicalReferenceScreenState extends State<ClinicalReferenceScreen> {
  late Future<ClinicalReferenceDataset> _dataset;
  String _query = '';
  String _species = 'all';

  @override
  void initState() {
    super.initState();
    _dataset = (widget.loader ?? loadClinicalReferenceDataset)();
  }

  Future<void> _openSource(String url) async {
    try {
      if (!await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication)) {
        throw StateError('Unavailable');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open the source. Its DOI is shown below.')));
    }
  }

  void _showRecord(Map<String, dynamic> row) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.8,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text('Published record ${row['sourceRowNumber']}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
                'Original source text, primarily Spanish. This historical record is not an assessment of the current patient.'),
            const SizedBox(height: 12),
            ...(row['sourceFields'] as Map).entries.map((field) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(field.key.toString(),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        SelectableText(field.value.toString().isEmpty
                            ? 'Not reported'
                            : field.value.toString()),
                      ]),
                )),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Published clinical cases')),
        body: FutureBuilder<ClinicalReferenceDataset>(
          future: _dataset,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Clinical reference data could not be loaded.'),
                TextButton(
                    onPressed: () => setState(() => _dataset =
                        (widget.loader ?? loadClinicalReferenceDataset)()),
                    child: const Text('Retry')),
              ]));
            }
            final dataset = snapshot.data;
            if (dataset == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final matches = dataset.search(_query, species: _species);
            return ListView(padding: const EdgeInsets.all(16), children: [
              Text(dataset.source['title'].toString(),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                  '${dataset.records.length} published record rows. ${dataset.source['author']} · ${dataset.source['license']}\nDOI: ${dataset.source['doi']}'),
              const SizedBox(height: 8),
              const Text(
                  'Urogenital reference examples from a publisher-reported clinical dataset. Original diagnosis labels and notes are preserved. Repeated patient IDs and missing diagnoses are retained. These records do not train or validate the symptom prediction model.'),
              Wrap(spacing: 8, children: [
                TextButton(
                    onPressed: () => _openSource(dataset.source['sourceUrl']),
                    child: const Text('Dataset source')),
                TextButton(
                    onPressed: () => _openSource(dataset.source['licenseUrl']),
                    child: const Text('CC BY 4.0 license')),
              ]),
              TextField(
                  decoration: const InputDecoration(
                      labelText: 'Search diagnosis or original clinical text',
                      prefixIcon: Icon(Icons.search)),
                  onChanged: (text) => setState(() => _query = text)),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('All')),
                    ButtonSegment(value: 'canine', label: Text('Dogs')),
                    ButtonSegment(value: 'feline', label: Text('Cats')),
                  ],
                  selected: {
                    _species
                  },
                  onSelectionChanged: (values) =>
                      setState(() => _species = values.first)),
              const SizedBox(height: 12),
              Text('${matches.length} record rows'),
              if (matches.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No matching records.')),
              ...matches.map((row) => Card(
                      child: ListTile(
                    title: Text(row['hasReportedDiagnosis'] == true
                        ? row['reportedDiagnosis']
                        : 'No reported diagnosis'),
                    subtitle: Text(
                        '${row['species'] == 'canine' ? 'Dog' : 'Cat'} · Source row ${row['sourceRowNumber']} · Source ID ${row['sourcePatientId']}\nOriginal source diagnosis; not independently verified.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showRecord(row),
                  ))),
              const SizedBox(height: 12),
              Text(dataset.source['attribution'].toString(),
                  style: Theme.of(context).textTheme.bodySmall),
            ]);
          },
        ),
      );
}
