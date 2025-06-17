import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../providers/damage_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedDamageClass;
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      await Provider.of<DamageProvider>(context, listen: false).loadReports();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load reports')),
        );
      }
    }
  }

  List<DamageReport> _getFilteredReports() {
    return Provider.of<DamageProvider>(context, listen: false)
        .getFilteredReports(
      startDate: _startDate,
      endDate: _endDate,
      damageClass: _selectedDamageClass,
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _exportToCSV() async {
    final reports = _getFilteredReports();
    final csvData = [
      [
        'ID',
        'Date',
        'Damage Class',
        'Road Name',
        'Location',
        'Comments',
        'Status',
        'Contractor',
        'Officer Comment',
      ],
      ...reports.map((report) => [
            report.id,
            _dateFormat.format(report.dateCreated),
            report.damageClass,
            report.roadName,
            '${report.location['street']}, ${report.location['city']}, ${report.location['region']}, ${report.location['country']}',
            report.comment,
            report.approvalStatus,
            report.contractor ?? 'N/A',
            report.officerComment ?? 'N/A',
          ]),
    ];

    final csvString = const ListToCsvConverter().convert(csvData);
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/damage_reports.csv');
    await file.writeAsString(csvString);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV exported to: ${file.path}')),
      );
    }
  }

  Future<void> _exportToPDF() async {
    final reports = _getFilteredReports();
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Table.fromTextArray(
          headers: [
            'Date',
            'Class',
            'Road Name',
            'Location',
            'Status',
            'Comments',
          ],
          data: reports
              .map((report) => [
                    _dateFormat.format(report.dateCreated),
                    report.damageClass,
                    report.roadName,
                    '${report.location['street']}, ${report.location['city']}',
                    report.approvalStatus,
                    report.comment,
                  ])
              .toList(),
        ),
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/damage_reports.pdf');
    await file.writeAsBytes(await pdf.save());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF exported to: ${file.path}')),
      );
    }
  }

  void _showReportDetails(DamageReport report) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 600 || screenWidth < 400;
    final damageClasses =
        Provider.of<DamageProvider>(context, listen: false).damageClasses;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: screenWidth * 0.9,
            maxHeight: screenHeight * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with status and title
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: report.approvalStatus == 'approved'
                            ? Colors.green[100]
                            : report.approvalStatus == 'pending'
                                ? Colors.orange[100]
                                : Colors.red[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        report.approvalStatus.toUpperCase(),
                        style: TextStyle(
                          color: report.approvalStatus == 'approved'
                              ? Colors.green[800]
                              : report.approvalStatus == 'pending'
                                  ? Colors.orange[800]
                                  : Colors.red[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Class ${report.damageClass}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Damage Class Info
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.blue[50],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Damage Class Details',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      damageClasses
                          .firstWhere(
                              (dc) => dc.damageClass == report.damageClass)
                          .description,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${damageClasses.firstWhere((dc) => dc.damageClass == report.damageClass).repairCost.toStringAsFixed(0)} TZS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Image section
              if (report.photoUrl.isNotEmpty)
                Container(
                  height: isSmallScreen ? 150 : 200,
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(0)),
                    child: Image.network(
                      report.photoUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 48),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(Icons.calendar_today, 'Date',
                          _dateFormat.format(report.dateCreated)),
                      _buildInfoRow(Icons.map, 'Road', report.roadName),
                      _buildInfoRow(
                        Icons.location_on,
                        'Location',
                        '${report.location['street']}, ${report.location['city']}, ${report.location['region']}, ${report.location['country']}',
                      ),
                      _buildInfoRow(
                        Icons.gps_fixed,
                        'Coordinates',
                        '[${report.location['latitude']}, ${report.location['longitude']}]',
                      ),
                      if (report.contractor != null)
                        _buildInfoRow(
                            Icons.person, 'Contractor', report.contractor!),
                      if (report.officerComment != null)
                        _buildInfoRow(Icons.comment, 'Officer Comment',
                            report.officerComment!),
                      if (report.validationDate != null)
                        _buildInfoRow(
                          Icons.check_circle,
                          'Validated on',
                          _dateFormat.format(report.validationDate!),
                        ),
                      const SizedBox(height: 16),
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          report.comment,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer with close button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final damageClasses = Provider.of<DamageProvider>(context).damageClasses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Damage Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
            tooltip: 'Refresh Reports',
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportToCSV,
            tooltip: 'Export to CSV',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportToPDF,
            tooltip: 'Export to PDF',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _selectDate(context, true),
                        icon: const Icon(Icons.calendar_today),
                        label: Text(_startDate == null
                            ? 'Start Date'
                            : _dateFormat.format(_startDate!)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _selectDate(context, false),
                        icon: const Icon(Icons.calendar_today),
                        label: Text(_endDate == null
                            ? 'End Date'
                            : _dateFormat.format(_endDate!)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedDamageClass,
                  decoration: const InputDecoration(
                    labelText: 'Damage Class',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.construction),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Classes'),
                    ),
                    ...damageClasses.map((DamageClass damageClass) {
                      return DropdownMenuItem<String>(
                        value: damageClass.damageClass,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Class ${damageClass.damageClass}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              damageClass.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${damageClass.repairCost.toStringAsFixed(0)} TZS',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: (String? value) {
                    setState(() => _selectedDamageClass = value);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<DamageProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading reports...'),
                      ],
                    ),
                  );
                }

                final reports = _getFilteredReports();
                if (reports.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No reports found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (_startDate != null ||
                            _endDate != null ||
                            _selectedDamageClass != null)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _startDate = null;
                                _endDate = null;
                                _selectedDamageClass = null;
                              });
                            },
                            child: const Text('Clear Filters'),
                          ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _loadReports,
                  child: ListView.builder(
                    itemCount: reports.length,
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: report.photoUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    report.photoUrl,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 60,
                                        height: 60,
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.broken_image),
                                      );
                                    },
                                  ),
                                )
                              : Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.construction),
                                ),
                          title: Text(
                            'Class ${report.damageClass} - ${report.roadName}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_dateFormat.format(report.dateCreated)),
                              Text(
                                '${report.location['street']}, ${report.location['city']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                damageClasses
                                    .firstWhere((dc) =>
                                        dc.damageClass == report.damageClass)
                                    .description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: report.approvalStatus == 'approved'
                                      ? Colors.green[100]
                                      : report.approvalStatus == 'pending'
                                          ? Colors.orange[100]
                                          : Colors.red[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  report.approvalStatus.toUpperCase(),
                                  style: TextStyle(
                                    color: report.approvalStatus == 'approved'
                                        ? Colors.green[800]
                                        : report.approvalStatus == 'pending'
                                            ? Colors.orange[800]
                                            : Colors.red[800],
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showReportDetails(report),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
