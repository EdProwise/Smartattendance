import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<AttendanceRecord> _records = [];
  bool _loading = true;
  String? _error;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchRecords();
  }

  Future<void> _fetchRecords() async {
    setState(() { _loading = true; _error = null; });
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final list = await ApiService.getAttendance(date: dateStr);
      if (mounted) setState(() { _records = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetchRecords();
    }
  }

  @override
  Widget build(BuildContext context) {
    final presentCount = _records.where((r) => r.status == 'present').length;
    final unknownCount = _records.where((r) => r.status == 'unrecognized').length;
    final dateLabel = DateFormat('EEE, MMM d, yyyy').format(_selectedDate);
    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text('Attendance Log'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchRecords),
        ],
      ),
      body: Column(
        children: [
          // Date selector bar
          Container(
      color: const Color(0xFF854CF4),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isToday ? 'Today' : dateLabel,
                        style: const TextStyle(color: Colors.white, fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      if (!isToday)
                        Text(dateLabel,
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, color: Colors.white, size: 16),
                  label: const Text('Change Date',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          // Summary chips
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  _SummaryChip(
                      label: 'Present',
                      count: presentCount,
                      color: const Color(0xFF2E7D32)),
                  const SizedBox(width: 10),
                  _SummaryChip(
                      label: 'Unrecognized',
                      count: unknownCount,
                      color: const Color(0xFFE65100)),
                  const SizedBox(width: 10),
                    _SummaryChip(
                        label: 'Total',
                        count: _records.length,
                        color: const Color(0xFF854CF4)),
                ],
              ),
            ),
          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(_error!),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: _fetchRecords, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _records.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_busy, size: 72, color: Colors.black26),
                                SizedBox(height: 16),
                                Text('No records for this date',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                SizedBox(height: 8),
                                Text('Attendance data will appear here after scanning.',
                                    style: TextStyle(color: Colors.black54),
                                    textAlign: TextAlign.center),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchRecords,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                              itemCount: _records.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) => _RecordTile(record: _records[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final AttendanceRecord record;
  const _RecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final isPresent = record.status == 'present';
    final color = isPresent ? const Color(0xFF2E7D32) : const Color(0xFFE65100);
    final timeStr = DateFormat('hh:mm a').format(record.timestamp.toLocal());

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(
                isPresent ? Icons.check_circle_rounded : Icons.help_outline_rounded,
                color: color,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.employeeName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(record.department,
                      style: const TextStyle(color: Colors.black54, fontSize: 13)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(timeStr,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14, color: color)),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPresent ? 'Present' : 'Unknown',
                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
