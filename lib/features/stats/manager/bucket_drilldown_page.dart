import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../canvassing/towns_page.dart';

class BucketDrilldownPage extends StatefulWidget {
  final String userId; // uuid as string
  final String userEmail;
  final String workDateNy; // 'YYYY-MM-DD'

  const BucketDrilldownPage({
    super.key,
    required this.userId,
    required this.userEmail,
    required this.workDateNy,
  });

  @override
  State<BucketDrilldownPage> createState() => _BucketDrilldownPageState();
}

class _BucketDrilldownPageState extends State<BucketDrilldownPage> {
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // We filter by:
      // - user_id
      // - work_date_ny (DATE)
      final raw = await _supabase
          .from('v_bucket_drilldown')
          .select()
          .match({
            'user_id': widget.userId,
            'work_date_ny': widget.workDateNy,
          })
          .order('bucket_start_ny', ascending: true);

      final rows = (raw as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _num(dynamic v) => v == null ? '-' : v.toString();

  String _numFixed(dynamic v, {int decimals = 2}) {
    if (v == null) return '-';
    final n = v is num ? v : num.tryParse(v.toString());
    if (n == null) return '-';
    return n.toStringAsFixed(decimals);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.userEmail} • ${widget.workDateNy}'),
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
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
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
            if (!_loading && _error == null && _rows.isEmpty)
              const Expanded(
                child: Center(child: Text('No buckets found for this day.')),
              ),
            if (!_loading && _error == null && _rows.isNotEmpty)
              Expanded(
                child: ListView.separated(
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = _rows[i];
                    final bucketStart = _num(r['bucket_start_ny']);
                    final knockCount = _num(r['knock_count']);
                    final isValid = (r['is_valid'] == true) ||
                        (r['is_valid']?.toString() == 'true');
                    final billable = _numFixed(r['billable_hours']);

                    return ListTile(
                      title: Text(bucketStart),
                      subtitle: Text('knocks: $knockCount'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(isValid ? 'VALID' : 'NOT VALID'),
                          Text('hrs: $billable'),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
