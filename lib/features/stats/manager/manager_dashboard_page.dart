import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../canvassing/towns_page.dart';
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

      final raw = await _supabase
          .from('v_manager_daily_summary')
          .select()
          .gte('work_date_ny', startStr)
          .lte('work_date_ny', endStr)
          .order('work_date_ny', ascending: false);

      final rows = (raw as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

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

  num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

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

  Future<void> _logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (_) {}
    if (!mounted) return;
    Navigator.popUntil(context, (r) => r.isFirst);
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

  Widget _metricBlock(String label, String value,
      {bool strong = false, double width = 190}) {
    final t = Theme.of(context).textTheme;
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: t.labelMedium?.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: 4),
        Text(
          value,
          style: t.titleMedium?.copyWith(
            fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ]),
    );
  }

  // Widget _summaryCard() {
  //   if (_rows.isEmpty) return const SizedBox.shrink();

  //   final totalHours = _rows.fold<num>(0, (s, r) => s + _toNum(r['billable_hours']));
  //   final totalBuckets =
  //       _rows.fold<num>(0, (s, r) => s + _toNum(r['valid_buckets']));
  //   final totalKnocks = _rows.fold<num>(0, (s, r) => s + _toNum(r['total_knocks']));
  //   final totalAnswers = _rows.fold<num>(0, (s, r) => s + _toNum(r['answers']));
  //   final totalSignups = _rows.fold<num>(0, (s, r) => s + _toNum(r['signed_ups']));

  //   final answerRate = totalKnocks > 0 ? (totalAnswers / totalKnocks) : 0;
  //   final conversionRate = totalAnswers > 0 ? (totalSignups / totalAnswers) : 0;
  //   final knocksPerHr = totalHours > 0 ? (totalKnocks / totalHours) : 0;

  //   return Card(
  //     elevation: 0,
  //     color: Colors.black.withOpacity(0.03),
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //     child: Padding(
  //       padding: const EdgeInsets.all(12),
  //       child: Wrap(
  //         spacing: 18,
  //         runSpacing: 10,
  //         children: [
  //           _metricBlock('Total Paid Time', '${totalHours.toStringAsFixed(2)} hrs',
  //               strong: true),
  //           _metricBlock('Valid 15-min Buckets', totalBuckets.toStringAsFixed(0)),
  //           _metricBlock('Doors Knocked', totalKnocks.toStringAsFixed(0)),
  //           _metricBlock('People Answered', totalAnswers.toStringAsFixed(0)),
  //           _metricBlock('Sign-ups', totalSignups.toStringAsFixed(0), strong: true),
  //           _metricBlock('Answer Rate', '${(answerRate * 100).toStringAsFixed(1)}%'),
  //           _metricBlock('Conversion Rate',
  //               '${(conversionRate * 100).toStringAsFixed(1)}%'),
  //           _metricBlock('Knocks per Paid Hour', knocksPerHr.toStringAsFixed(2)),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    final rangeLabel = _range == null
        ? 'Pick date range'
        : '${_range!.start.month}/${_range!.start.day} - ${_range!.end.month}/${_range!.end.day}';

    final user = _supabase.auth.currentUser;
    final email = user?.email ?? '';

    final emphasisStyle =
        Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Go to Towns',
            icon: const Icon(Icons.map_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TownsPage()),
              );
            },
          ),
          IconButton(
            onPressed: _loading ? null : _fetch,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: _loading ? null : _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Email + explainer
            Row(
              children: [
                if (email.isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.admin_panel_settings, size: 18),
                    label: Text(email),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Daily team stats. Click any row to open the 15-minute bucket drilldown for that canvasser and date.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.black54),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

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
                      labelText: 'Filter by canvasser email (exact match)',
                      hintText: 'name@company.com',
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

            // if (_rows.isNotEmpty) ...[
            //   const SizedBox(height: 10),
            //   _summaryCard(),
            // ],

            const SizedBox(height: 8),

            Expanded(
              child: _rows.isEmpty && !_loading
                  ? const Center(
                      child: Text(
                        'No results for the selected date range / filter.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Canvasser')),
                          DataColumn(label: Text('Paid Time (hrs)')),
                          DataColumn(label: Text('Valid Buckets')),
                          DataColumn(label: Text('Doors Knocked')),
                          DataColumn(label: Text('People Answered')),
                          DataColumn(label: Text('Sign-ups')),
                          DataColumn(label: Text('Answer Rate')),
                          DataColumn(label: Text('Conversion Rate')),
                          DataColumn(label: Text('Knocks / Paid Hr')),
                        ],
                        rows: _rows.map((r) {
                          return DataRow(
                            onSelectChanged: (_) => _openDrilldown(r),
                            cells: [
                              DataCell(Text(_num(r['work_date_ny']))),
                              DataCell(Text(_num(r['user_email']))),
                              DataCell(Text(_numFixed(r['billable_hours']),
                                  style: emphasisStyle)),
                              DataCell(Text(_num(r['valid_buckets']))),
                              DataCell(Text(_num(r['total_knocks']))),
                              DataCell(Text(_num(r['answers']))),
                              DataCell(Text(_num(r['signed_ups']),
                                  style: emphasisStyle)),
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
