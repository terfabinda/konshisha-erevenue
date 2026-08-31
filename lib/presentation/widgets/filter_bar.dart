import 'package:flutter/material.dart';

class FilterBar extends StatefulWidget {
  final Function({DateTime? startDate, DateTime? endDate, String? status}) onFilter;

  const FilterBar({
    super.key,
    required this.onFilter,
  });

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _status;

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _applyFilters();
    }
  }

  void _applyFilters() {
    widget.onFilter(
      startDate: _startDate,
      endDate: _endDate,
      status: _status,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _startDate != null && _endDate != null
        ? '${_startDate!.day}/${_startDate!.month} - ${_endDate!.day}/${_endDate!.month}'
        : 'Date Range';

    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(dateLabel),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _status,
                  isDense: true,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                    isCollapsed: true,
                  ),
                  hint: const Text('Status'),
                  items: const [
                    DropdownMenuItem<String?>(value: null, child: Text('All')),
                    DropdownMenuItem<String?>(value: 'active', child: Text('Active')),
                    DropdownMenuItem<String?>(value: 'voided', child: Text('Voided')),
                  ],
                  onChanged: (v) {
                    setState(() => _status = v);
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
          if (_startDate != null || _status != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                        _status = null;
                      });
                      _applyFilters();
                    },
                    child: const Text('Clear Filters'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
