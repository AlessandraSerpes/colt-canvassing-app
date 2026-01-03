import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bucket_drilldown_page.dart';

class ManagerDashboardPage extends StatefulWidget {
  const ManagerDashboardPage({super.key});

  @override
  State<ManagerDashboardPage> createState() => _ManagerDashboardPageState();
}

class _ManagerDashboardPageState extends State<ManagerDashboardPage> {
  final _supabase = Supabase.instance.client;

  DateTimeRange? _range;
  String _emailFilter = '';

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(start: now.subtract(const Duration(days: 14)), end: now);
    _fetch();
  }

  String _fmtYmd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _fetch() async {
    if (_range == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final startStr = _fmtYmd(_range!.start);
      final endStr = _fmtYmd(_range!.end);

      // Server-side date filter, no eq()
      final raw = await _supabase
          .from('v_manager_daily_summary')
          .select()
          .gte('work_date_ny', startStr)
          .lte('work_date_ny', endStr)
          .order('work_date_ny', ascending: false);

      final rows = (raw as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // Optional client-side email filter (avoids eq())
      final email = _emailFilter.trim();
      final filtered = email.isEmpty
          ? rows
          : rows.where((r) => (r['user_email'] ?? '').toString() == email).toList();

      setState(() {
        _rows = filtered;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
    );
    if (picked != null) {
      setState(() => _range = picked);
      await _fetch();
    }
  }

  String _num(dynamic v) => v == null ? '-' : v.toString();

  String _numFixed(dynamic v, {int decimals = 2}) {
    if (v == null) return '-';
    final n = v is num ? v : num.tryParse(v.toString());
    if (n == null) return '-';
    return n.toStringAsFixed(decimals);
  }

  String _pct(dynamic v) {
    if (v == null) return '-';
    final n = v is num ? v : num.tryParse(v.toString());
    if (n == null) return '-';
    return '${(n * 100).toStringAsFixed(1)}%';
  }

  void _openDrilldown(Map<String, dynamic> r) {
    final userId = (r['user_id'] ?? '').toString();
    final email = (r['user_email'] ?? '').toString();
    final workDateNy = (r['work_date_ny'] ?? '').toString();

    if (userId.isEmpty || workDateNy.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BucketDrilldownPage(
          userId: userId,
          userEmail: email,
          workDateNy: workDateNy,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rangeLabel = _range == null
        ? 'Pick date range'
        : '${_range!.start.month}/${_range!.start.day} - ${_range!.end.month}/${_range!.end.day}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Dashboard'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _fetch,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(rangeLabel),
                ),
                SizedBox(
                  width: 320,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Filter by user_email (exact match, optional)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => _emailFilter = v,
                    onSubmitted: (_) => _fetch(),
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.red.withOpacity(0.08),
                ),
                child: Text('Error: $_error'),
              ),

            const SizedBox(height: 8),

            Expanded(
              child: _rows.isEmpty && !_loading
                  ? const Center(child: Text('No rows for selected filters.'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Canvasser')),
                          DataColumn(label: Text('Billable hrs')),
                          DataColumn(label: Text('Valid buckets')),
                          DataColumn(label: Text('Knocks')),
                          DataColumn(label: Text('Answers')),
                          DataColumn(label: Text('Signups')),
                          DataColumn(label: Text('Answer %')),
                          DataColumn(label: Text('Signup/Answer %')),
                          DataColumn(label: Text('Knocks / billable hr')),
                        ],
                        rows: _rows.map((r) {
                          return DataRow(
                            onSelectChanged: (_) => _openDrilldown(r),
                            cells: [
                              DataCell(Text(_num(r['work_date_ny']))),
                              DataCell(Text(_num(r['user_email']))),
                              DataCell(Text(_numFixed(r['billable_hours']))),
                              DataCell(Text(_num(r['valid_buckets']))),
                              DataCell(Text(_num(r['total_knocks']))),
                              DataCell(Text(_num(r['answers']))),
                              DataCell(Text(_num(r['signed_ups']))),
                              DataCell(Text(_pct(r['answer_rate']))),
                              DataCell(Text(_pct(r['signup_rate']))),
                              DataCell(Text(_numFixed(r['knocks_per_billable_hour']))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
