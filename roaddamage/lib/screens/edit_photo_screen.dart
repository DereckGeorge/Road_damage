import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/damage_provider.dart';
import '../providers/auth_provider.dart';

class EditPhotoScreen extends StatefulWidget {
  final DamageReport reportToEdit;

  const EditPhotoScreen({super.key, required this.reportToEdit});

  @override
  State<EditPhotoScreen> createState() => _EditPhotoScreenState();
}

class _EditPhotoScreenState extends State<EditPhotoScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _roadNameController;
  late TextEditingController _commentController;
  late TextEditingController _editReasonController;
  String? _selectedDamageClass;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final report = widget.reportToEdit;
    _roadNameController = TextEditingController(text: report.roadName);
    _commentController = TextEditingController(text: report.comment);
    _editReasonController = TextEditingController();
    _selectedDamageClass = report.damageClass;
  }

  @override
  void dispose() {
    _roadNameController.dispose();
    _commentController.dispose();
    _editReasonController.dispose();
    super.dispose();
  }

  Future<void> _submitEdit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final damageProvider =
          Provider.of<DamageProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      try {
        await damageProvider.editRejectedPhoto(
          photoId: widget.reportToEdit.id,
          roadName: _roadNameController.text,
          damageClass: _selectedDamageClass!,
          comment: _commentController.text,
          editReason: _editReasonController.text,
          email: authProvider.email!,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo edited successfully!')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to edit photo: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final damageClasses = Provider.of<DamageProvider>(context, listen: false)
        .damageClasses
        .map((e) => e.damageClass)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Photo Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.network(widget.reportToEdit.photoUrl),
              const SizedBox(height: 16),
              TextFormField(
                controller: _roadNameController,
                decoration: const InputDecoration(labelText: 'Road Name'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a road name' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedDamageClass,
                decoration: const InputDecoration(labelText: 'Damage Class'),
                items: damageClasses.map((damageClass) {
                  return DropdownMenuItem(
                    value: damageClass,
                    child: Text(damageClass),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDamageClass = value;
                  });
                },
                validator: (value) =>
                    value == null ? 'Please select a damage class' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _commentController,
                decoration: const InputDecoration(labelText: 'Comment'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _editReasonController,
                decoration: const InputDecoration(labelText: 'Reason for Edit'),
                validator: (value) => value!.isEmpty
                    ? 'Please provide a reason for the edit'
                    : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitEdit,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Submit Edit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
