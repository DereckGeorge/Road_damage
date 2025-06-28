import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/damage_provider.dart';
import 'edit_photo_screen.dart';
import 'login_screen.dart';
import 'rejected_photos_screen.dart';
import 'survey_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAssignedRoads();
  }

  Future<void> _loadAssignedRoads() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.email != null) {
      try {
        await Provider.of<DamageProvider>(context, listen: false)
            .loadAssignedRoads(authProvider.email!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load assigned roads: $e')),
          );
        }
      }
    }
  }

  Future<void> _loadMyPhotos() async {
    try {
      await Provider.of<DamageProvider>(context, listen: false).loadReports();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load reports: $e')),
        );
      }
    }
  }

  Future<void> _loadRejectedPhotos() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.email != null) {
      try {
        await Provider.of<DamageProvider>(context, listen: false)
            .loadRejectedPhotos(authProvider.email!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load rejected photos: $e')),
          );
        }
      }
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });

    final damageProvider = Provider.of<DamageProvider>(context, listen: false);

    if (index == 1 && damageProvider.reports.isEmpty) {
      _loadMyPhotos();
    } else if (index == 2 && damageProvider.rejectedPhotos.isEmpty) {
      _loadRejectedPhotos();
    }
  }

  void _logout() {
    Provider.of<AuthProvider>(context, listen: false).logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    const List<String> titles = [
      'Assigned Roads',
      'My Photos',
      'Rejected Photos'
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Assigned Roads',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_library),
            label: 'My Photos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.report_problem),
            label: 'Rejected Photos',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _AssignedRoadsView(
          onBuildStatusButton: (road) => _buildStatusButton(road),
        );
      case 1:
        return const _MyPhotosView();
      case 2:
        return const _RejectedPhotosView();
      default:
        return const Center(child: Text('Something went wrong'));
    }
  }

  Widget _buildStatusButton(AssignedRoad road) {
    switch (road.status) {
      case 'assigned':
        return ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('This road is awaiting approval from a manager.')),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
          ),
          child: const Text('Awaiting Approval'),
        );
      case 'approved':
      case 'in_progress':
        return ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => SurveyScreen(roadName: road.roadName),
              ),
            );
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('Start Survey'),
        );
      default:
        return Text(road.status,
            style: const TextStyle(fontWeight: FontWeight.bold));
    }
  }
}

class _AssignedRoadsView extends StatelessWidget {
  final Widget Function(AssignedRoad) onBuildStatusButton;

  const _AssignedRoadsView({required this.onBuildStatusButton});

  @override
  Widget build(BuildContext context) {
    return Consumer<DamageProvider>(
      builder: (context, damageProvider, child) {
        if (damageProvider.isLoading && damageProvider.assignedRoads.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (damageProvider.assignedRoads.isEmpty) {
          return const Center(child: Text('No roads assigned.'));
        }

        return ListView.builder(
          itemCount: damageProvider.assignedRoads.length,
          itemBuilder: (context, index) {
            final road = damageProvider.assignedRoads[index];
            return Card(
              margin: const EdgeInsets.all(8.0),
              child: ListTile(
                title: Text(road.roadName),
                subtitle: Text('Status: ${road.status}'),
                trailing: onBuildStatusButton(road),
              ),
            );
          },
        );
      },
    );
  }
}

class _MyPhotosView extends StatefulWidget {
  const _MyPhotosView();

  @override
  State<_MyPhotosView> createState() => _MyPhotosViewState();
}

class _MyPhotosViewState extends State<_MyPhotosView> {
  String? _selectedClass;
  String? _selectedStatus;
  final _roadNameController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _roadNameController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _selectedClass = null;
      _selectedStatus = null;
      _roadNameController.clear();
      _startDate = null;
      _endDate = null;
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final damageProvider = Provider.of<DamageProvider>(context);

    final damageClasses =
        damageProvider.damageClasses.map((e) => e.damageClass).toSet().toList();
    final statuses =
        damageProvider.reports.map((e) => e.approvalStatus).toSet().toList();

    final myPhotos = damageProvider
        .getFilteredReports(
          damageClass: _selectedClass,
          status: _selectedStatus,
          roadName: _roadNameController.text,
          startDate: _startDate,
          endDate: _endDate,
        )
        .where((report) => report.email == authProvider.email)
        .toList();

    return Column(
      children: [
        // Filter UI
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ExpansionTile(
            title: const Text('Filters'),
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // ... filter widgets ...
                    TextField(
                      controller: _roadNameController,
                      decoration: const InputDecoration(labelText: 'Road Name'),
                      onChanged: (value) => setState(() {}),
                    ),
                    DropdownButton<String>(
                      value: _selectedClass,
                      hint: const Text('Filter by Class'),
                      onChanged: (value) =>
                          setState(() => _selectedClass = value),
                      items: damageClasses
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                    ),
                    DropdownButton<String>(
                      value: _selectedStatus,
                      hint: const Text('Filter by Status'),
                      onChanged: (value) =>
                          setState(() => _selectedStatus = value),
                      items: statuses
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                    ),
                    ElevatedButton(
                      onPressed: () => _selectDate(context, true),
                      child: Text(_startDate == null
                          ? 'Start Date'
                          : 'From: ${_startDate!.toLocal().toString().split(' ')[0]}'),
                    ),
                    ElevatedButton(
                      onPressed: () => _selectDate(context, false),
                      child: Text(_endDate == null
                          ? 'End Date'
                          : 'To: ${_endDate!.toLocal().toString().split(' ')[0]}'),
                    ),
                    ElevatedButton(
                      onPressed: _resetFilters,
                      child: const Text('Reset'),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),

        // Photo List
        Expanded(
          child: Consumer<DamageProvider>(
            builder: (context, damageProvider, child) {
              if (damageProvider.isLoading && damageProvider.reports.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (myPhotos.isEmpty) {
                return const Center(
                    child: Text('No photos match your criteria.'));
              }

              return ListView.builder(
                itemCount: myPhotos.length,
                itemBuilder: (context, index) {
                  final photo = myPhotos[index];
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ExpansionTile(
                      leading: SizedBox(
                        width: 50,
                        height: 50,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.network(
                            photo.photoUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                  child: CircularProgressIndicator());
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.broken_image, size: 50);
                            },
                          ),
                        ),
                      ),
                      title: Text(photo.roadName),
                      subtitle: Text('Status: ${photo.approvalStatus}'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow('Damage Class:', photo.damageClass),
                              _buildInfoRow(
                                  'Date Submitted:',
                                  photo.dateCreated
                                      .toLocal()
                                      .toString()
                                      .split(' ')[0]),
                              if (photo.comment.isNotEmpty)
                                _buildInfoRow('Your Comment:', photo.comment),
                              if (photo.officerComment != null &&
                                  photo.officerComment!.isNotEmpty)
                                _buildInfoRow(
                                    'Officer Comment:', photo.officerComment!),
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _RejectedPhotosView extends StatelessWidget {
  const _RejectedPhotosView();

  @override
  Widget build(BuildContext context) {
    return Consumer<DamageProvider>(
      builder: (context, damageProvider, child) {
        if (damageProvider.isLoading && damageProvider.rejectedPhotos.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (damageProvider.rejectedPhotos.isEmpty) {
          return const Center(child: Text('You have no rejected photos.'));
        }

        return ListView.builder(
          itemCount: damageProvider.rejectedPhotos.length,
          itemBuilder: (context, index) {
            final photo = damageProvider.rejectedPhotos[index];
            return Card(
              margin: const EdgeInsets.all(8.0),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.network(photo.photoUrl, fit: BoxFit.cover),
                    const SizedBox(height: 8),
                    Text('Road: ${photo.roadName}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Damage Class: ${photo.damageClass}'),
                    if (photo.officerComment != null &&
                        photo.officerComment!.isNotEmpty)
                      Text('Officer Comment: ${photo.officerComment}'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => EditPhotoScreen(
                              reportToEdit: photo,
                            ),
                          ),
                        );
                      },
                      child: const Text('Edit Details'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
