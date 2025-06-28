import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/damage_provider.dart';
import 'survey_screen.dart';

class RejectedPhotosScreen extends StatefulWidget {
  const RejectedPhotosScreen({super.key});

  @override
  State<RejectedPhotosScreen> createState() => _RejectedPhotosScreenState();
}

class _RejectedPhotosScreenState extends State<RejectedPhotosScreen> {
  @override
  void initState() {
    super.initState();
    _loadRejectedPhotos();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rejected Photos'),
      ),
      body: Consumer<DamageProvider>(
        builder: (context, damageProvider, child) {
          if (damageProvider.isLoading) {
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
                      Image.network(photo.photoUrl),
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
                              builder: (context) => SurveyScreen(
                                roadName: photo.roadName,
                                reportToEdit: photo,
                              ),
                            ),
                          );
                        },
                        child: const Text('Edit & Resubmit'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
