import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../canvassing/towns_page.dart';

class CanvasserDashboardPage extends StatefulWidget {
  const CanvasserDashboardPage({super.key});

  @override
  State<CanvasserDashboardPage> createState() => _CanvasserDashboardPageState();
}

class _CanvasserDashboardPageState extends State<CanvasserDashboardPage> {
  final _supabase = Supabase.instance.client;

  DateTimeRange? _range;

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
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Not signed in.';
        _rows = [];
        _loading = false;
      });
      return;
    }
    if (_range == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final startStr = _fmtYmd(_range!.start);
      final endStr = _fmtYmd(_range!.end);

      // ✅ Filter by the logged-in user_id explicitly (do NOT rely on view/RLS behavior)
      final payrollRaw = await _supabase
          .from('v_payroll_daily')
          .select()
          .match({'user_id': user.id})
          .gte('work_date_ny', startStr)
          .lte('work_date_ny', endStr)
          .order('work_date_ny', ascending: false);

      final perfRaw = await _supabase
          .from('v_performance_daily')
          .select()
          .match({'user_id': user.id})
          .gte('work_date_ny', startStr)
          .lte('work_date_ny', endStr)
          .order('work_date_ny', ascending: false);

      final payroll = (payrollRaw as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final perf = (perfRaw as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final perfByDate = <String, Map<String, dynamic>>{};
      for (final r in perf) {
        final d = (r['work_date_ny'] ?? '').toString();
        if (d.isNotEmpty) perfByDate[d] = r;
      }

      final joined = <Map<String, dynamic>>[];
      for (final p in payroll) {
        final d = (p['work_date_ny'] ?? '').toString();
        final pr = perfByDate[d];

        joined.add({
          'work_date_ny': d,
          'billable_hours': p['billable_hours'],
          // 🚫 removed valid_buckets
          'total_knocks': p['total_knocks'],
          'answers': pr?['answers'] ?? 0,
          'signed_ups': pr?['signed_ups'] ?? 0,
          'answer_rate': pr?['answer_rate'] ?? 0,
          'signup_rate': pr?['signup_rate'] ?? 0,
        });
      }

      setState(() {
        _rows = joined;
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

  String _pctFromRatio(num ratio) => '${(ratio * 100).toStringAsFixed(1)}%';

  Future<void> _logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (_) {
      // Even if sign out errors, still return to root so auth gate can handle.
    }
    if (!mounted) return;
    Navigator.popUntil(context, (r) => r.isFirst);
  }

  Widget _summaryCard() {
    final totalHours = _rows.fold<num>(0, (s, r) => s + _toNum(r['billable_hours']));
    final totalKnocks = _rows.fold<num>(0, (s, r) => s + _toNum(r['total_knocks']));
    final totalAnswers = _rows.fold<num>(0, (s, r) => s + _toNum(r['answers']));
    final totalSignups = _rows.fold<num>(0, (s, r) => s + _toNum(r['signed_ups']));

    final answerRate = totalKnocks > 0 ? (totalAnswers / totalKnocks) : 0;
    final conversionRate = totalAnswers > 0 ? (totalSignups / totalAnswers) : 0;

    TextStyle kLabel(BuildContext c) =>
        Theme.of(c).textTheme.labelMedium!.copyWith(color: Colors.black54, fontWeight: FontWeight.w600);
    TextStyle kValue(BuildContext c, {bool strong = false}) => Theme.of(c).textTheme.titleMedium!.copyWith(
          fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
        );

    return Card(
      elevation: 0,
      color: Colors.black.withOpacity(0.03),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 18,
          runSpacing: 10,
          children: [
            _metricBlock('Total Paid Time', '${totalHours.toStringAsFixed(2)} hrs', strong: true, labelStyle: kLabel(context), valueStyle: kValue(context, strong: true)),
            _metricBlock('Doors Knocked', totalKnocks.toStringAsFixed(0), labelStyle: kLabel(context), valueStyle: kValue(context)),
            _metricBlock('People Answered', totalAnswers.toStringAsFixed(0), labelStyle: kLabel(context), valueStyle: kValue(context)),
            _metricBlock('Sign-ups', totalSignups.toStringAsFixed(0), strong: true, labelStyle: kLabel(context), valueStyle: kValue(context, strong: true)),
            _metricBlock('Answer Rate', _pctFromRatio(answerRate), labelStyle: kLabel(context), valueStyle: kValue(context)),
            _metricBlock('Conversion Rate', _pctFromRatio(conversionRate), labelStyle: kLabel(context), valueStyle: kValue(context)),
          ],
        ),
      ),
    );
  }

  Widget _metricBlock(
    String label,
    String value, {
    required TextStyle labelStyle,
    required TextStyle valueStyle,
    bool strong = false,
  }) {
    return SizedBox(
      width: 170,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 4),
        Text(value, style: valueStyle),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    final email = user?.email ?? '';

    final rangeLabel = _range == null
        ? 'Pick date range'
        : '${_range!.start.month}/${_range!.start.day} - ${_range!.end.month}/${_range!.end.day}';

    final emphasisStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Stats'),
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
            tooltip: 'Refresh',
            onPressed: _loading ? null : _fetch,
            icon: const Icon(Icons.refresh),
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
                    avatar: const Icon(Icons.person, size: 18),
                    label: Text(email),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'These stats show your daily activity and paid time based on door-knocking events.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
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

            if (_rows.isNotEmpty) ...[
              const SizedBox(height: 10),
              _summaryCard(),
            ],

            const SizedBox(height: 8),
            Expanded(
              child: _rows.isEmpty && !_loading
                  ? const Center(
                      child: Text(
                        'No activity yet for this date range.\nStart knocking doors to see your stats here.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Paid Time (hrs)')),
                          DataColumn(label: Text('Doors Knocked')),
                          DataColumn(label: Text('People Answered')),
                          DataColumn(label: Text('Sign-ups')),
                          DataColumn(label: Text('Answer Rate')),
                          DataColumn(label: Text('Conversion Rate')),
                        ],
                        rows: _rows.map((r) {
                          return DataRow(
                            cells: [
                              DataCell(Text(_num(r['work_date_ny']))),
                              DataCell(Text(_numFixed(r['billable_hours']), style: emphasisStyle)),
                              DataCell(Text(_num(r['total_knocks']))),
                              DataCell(Text(_num(r['answers']))),
                              DataCell(Text(_num(r['signed_ups']), style: emphasisStyle)),
                              DataCell(Text(_pctFromRatio(_toNum(r['answer_rate'])))),
                              DataCell(Text(_pctFromRatio(_toNum(r['signup_rate'])))),
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
