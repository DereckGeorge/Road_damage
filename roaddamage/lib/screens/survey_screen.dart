import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/damage_provider.dart';

class SurveyScreen extends StatefulWidget {
  final String roadName;
  final DamageReport? reportToEdit;

  const SurveyScreen({super.key, required this.roadName, this.reportToEdit});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  Position? _currentPosition;
  Map<String, dynamic>? _locationDetails;
  String? _selectedDamageClass;
  final _commentController = TextEditingController();
  XFile? _capturedImage;
  bool _isLoading = false;
  bool _isLocationLoading = false;
  DateTime? _surveyStartDate;
  DateTime? _surveyEndDate;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _getCurrentLocation();
    _loadDamageClasses();

    if (widget.reportToEdit != null) {
      final report = widget.reportToEdit!;
      _selectedDamageClass = report.damageClass;
      _commentController.text = report.comment;
      _surveyStartDate = report.surveyStartDate;
      _surveyEndDate = report.surveyEndDate;
      // Note: Image and location are not pre-filled, user needs to capture new ones.
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocationLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Handle disabled location services
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Handle denied location permission
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Handle permanently denied location permission
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() => _currentPosition = position);

      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${position.latitude}&lon=${position.longitude}',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _locationDetails = {
            'street': data['address']['road'] ?? '',
            'city': data['address']['city'] ?? '',
            'region': data['address']['state'] ?? '',
            'country': data['address']['country'] ?? '',
            'latitude': position.latitude,
            'longitude': position.longitude,
          };
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    } finally {
      if (mounted) {
        setState(() => _isLocationLoading = false);
      }
    }
  }

  Future<void> _loadDamageClasses() async {
    try {
      await Provider.of<DamageProvider>(context, listen: false)
          .loadDamageClasses();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      setState(() => _isLoading = true);
      final image = await _controller!.takePicture();
      setState(() => _capturedImage = image);
    } catch (e) {
      debugPrint('Error taking picture: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String> _imageToBase64() async {
    if (_capturedImage == null) return '';
    final imageBytes = await _capturedImage!.readAsBytes();
    return 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _surveyStartDate = picked;
        } else {
          _surveyEndDate = picked;
        }
      });
    }
  }

  Future<void> _uploadPhoto() async {
    if (_capturedImage == null ||
        _selectedDamageClass == null ||
        _surveyStartDate == null ||
        _surveyEndDate == null ||
        _locationDetails == null) {
      // Show error message
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final imageData = await _imageToBase64();

      await Provider.of<DamageProvider>(context, listen: false).uploadPhoto(
        userId: authProvider.userId!,
        fullname: authProvider.fullname!,
        email: authProvider.email!,
        imageData: imageData,
        location: _locationDetails!,
        roadName: widget.roadName,
        damageClass: _selectedDamageClass!,
        comment: _commentController.text,
        surveyStartDate: DateFormat('yyyy-MM-dd').format(_surveyStartDate!),
        surveyEndDate: DateFormat('yyyy-MM-dd').format(_surveyEndDate!),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo uploaded successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload photo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildLocationRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
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
        title: Text('Survey: ${widget.roadName}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Camera preview
            _isCameraInitialized
                ? AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: CameraPreview(_controller!),
                  )
                : const Center(child: CircularProgressIndicator()),

            _capturedImage != null
                ? Image.file(File(_capturedImage!.path))
                : Container(),

            ElevatedButton.icon(
              onPressed: _takePicture,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Picture'),
            ),

            const SizedBox(height: 16),

            // Location Info Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Location Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_isLocationLoading)
                          const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          IconButton(
                            onPressed: _getCurrentLocation,
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Refresh Location',
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_locationDetails != null) ...[
                      _buildLocationRow('Street', _locationDetails!['street']),
                      _buildLocationRow('City', _locationDetails!['city']),
                      _buildLocationRow('Region', _locationDetails!['region']),
                      _buildLocationRow(
                          'Country', _locationDetails!['country']),
                      const SizedBox(height: 8),
                      Text(
                        'Lat: ${_locationDetails!['latitude']?.toStringAsFixed(5)}, Lon: ${_locationDetails!['longitude']?.toStringAsFixed(5)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ] else if (_isLocationLoading)
                      const Text('Getting location...')
                    else
                      const Text('Location not available.'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Damage class dropdown
            DropdownButtonFormField<String>(
              value: _selectedDamageClass,
              decoration: const InputDecoration(labelText: 'Damage Class'),
              items: damageClasses.map((damageClass) {
                return DropdownMenuItem(
                  value: damageClass.damageClass,
                  child: Text(
                      '${damageClass.damageClass} - ${damageClass.description}'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDamageClass = value;
                });
              },
            ),

            const SizedBox(height: 16),

            // Comment text field
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(labelText: 'Comment'),
              maxLines: 3,
            ),

            const SizedBox(height: 16),

            // Date pickers
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _selectDate(context, true),
                    child: Text(_surveyStartDate == null
                        ? 'Select Start Date'
                        : DateFormat('yyyy-MM-dd').format(_surveyStartDate!)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _selectDate(context, false),
                    child: Text(_surveyEndDate == null
                        ? 'Select End Date'
                        : DateFormat('yyyy-MM-dd').format(_surveyEndDate!)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Submit button
            ElevatedButton(
              onPressed: _isLoading ? null : _uploadPhoto,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
