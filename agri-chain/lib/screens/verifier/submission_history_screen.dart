// Submission history screen — shows all past yield reports from this verifier.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agri_chain/providers/verifier_provider.dart';
import 'package:agri_chain/models/verifier_models.dart';
import 'package:agri_chain/screens/verifier/widgets/submission_card.dart';

class SubmissionHistoryScreen extends StatefulWidget {
  const SubmissionHistoryScreen({super.key});

  @override
  State<SubmissionHistoryScreen> createState() => _SubmissionHistoryScreenState();
}

class _SubmissionHistoryScreenState extends State<SubmissionHistoryScreen> {
  List<OracleSubmission> _subs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prov = context.read<VerifierProvider>();
    final subs = await prov.loadAllSubmissions();
    if (mounted) {
      setState(() {
        _subs = subs;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submission History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _subs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text('No submissions yet',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _subs.length,
                    itemBuilder: (context, i) => SubmissionCard(submission: _subs[i]),
                  ),
                ),
    );
  }
}
