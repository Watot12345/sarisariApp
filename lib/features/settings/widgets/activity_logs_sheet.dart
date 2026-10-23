import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/activity_log.dart';
import '../../../data/repositories/activity_log_repository.dart';

/// Modal bottom sheet displaying the chronological store Activity Logs (Audit Trail).
class ActivityLogsSheet extends StatefulWidget {
  const ActivityLogsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ActivityLogsSheet(),
    );
  }

  @override
  State<ActivityLogsSheet> createState() => _ActivityLogsSheetState();
}

class _ActivityLogsSheetState extends State<ActivityLogsSheet> {
  final ActivityLogRepository _repo = ActivityLogRepository();
  List<ActivityLog> _logs = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'sales', 'inventory', 'credit'

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final rows = await _repo.getRecentLogs(limit: 120);
    if (mounted) {
      setState(() {
        _logs = rows;
        _isLoading = false;
      });
    }
  }

  List<ActivityLog> get _filteredLogs {
    if (_selectedFilter == 'all') return _logs;
    return _logs.where((log) {
      if (_selectedFilter == 'sales') {
        return log.actionType.startsWith('sale_');
      } else if (_selectedFilter == 'inventory') {
        return log.actionType.startsWith('product_') ||
            log.actionType.startsWith('stock_');
      } else if (_selectedFilter == 'credit') {
        return log.actionType.startsWith('credit_');
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTl = context.watch<LanguageProvider?>()?.isTagalog ?? false;
    final items = _filteredLogs;

    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppConstants.borderRadiusTopSheet,
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.history_edu_rounded,
                      color: AppTheme.primaryGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTl ? 'Activity Logs (Audit ng Tindahan)' : 'Activity Logs (Store Audit)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          isTl
                              ? 'Rekord ng lahat ng benta, pagbabago sa paninda, at bayad'
                              : 'Chronological audit trail of sales, inventory, and credit actions',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    onPressed: _loadLogs,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Filter Dropdown / Segment Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  _buildFilterChip('all', isTl ? 'Lahat' : 'All'),
                  const SizedBox(width: 6),
                  _buildFilterChip('sales', isTl ? 'Benta' : 'Sales'),
                  const SizedBox(width: 6),
                  _buildFilterChip('inventory', isTl ? 'Paninda' : 'Inventory'),
                  const SizedBox(width: 6),
                  _buildFilterChip('credit', isTl ? 'Utang' : 'Credit'),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.history_toggle_off_rounded,
                                  size: 48,
                                  color: Colors.grey.withOpacity(0.4),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  isTl
                                      ? 'Wala pang naitalang aktibidad'
                                      : 'No activity logs recorded yet',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isTl
                                      ? 'Awtomatikong malalagay dito ang bawat benta, dagdag-paninda, at bayad.'
                                      : 'Every sale, stock update, and credit entry will automatically appear here.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final log = items[i];
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.cardTheme.color,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.outline.withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: log.color.withOpacity(0.14),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(log.icon, color: log.color, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          log.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          log.description,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.onSurface.withOpacity(0.75),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat('MMM d, yyyy • h:mm a').format(log.createdAt.toLocal()),
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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

  Widget _buildFilterChip(String key, String label) {
    final selected = _selectedFilter == key;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedFilter = key);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryGreen
                : AppTheme.primaryGreen.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppTheme.primaryGreen,
            ),
          ),
        ),
      ),
    );
  }
}
