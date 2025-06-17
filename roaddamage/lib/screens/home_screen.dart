import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../providers/auth_provider.dart';
import '../providers/damage_provider.dart';
import '../services/api_service.dart';
import 'reports_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  Position? _currentPosition;
  Map<String, dynamic>? _locationDetails;
  String? _selectedDamageClass;
  final _roadNameController = TextEditingController();
  final _commentController = TextEditingController();
  XFile? _capturedImage;
  bool _isLoading = false;
  bool _isLocationLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _getCurrentLocation();
    _loadDamageClasses();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _roadNameController.dispose();
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
      print('Checking location service status...');

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Please enable location services in your device settings.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      print('Requesting location permission...');
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permission denied');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Location permission denied. Please enable location access in app settings.'),
                duration: Duration(seconds: 5),
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permission permanently denied');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Location permission permanently denied. Please enable it in app settings.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      print('Getting current position...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );
      print('Position obtained: ${position.latitude}, ${position.longitude}');
      setState(() => _currentPosition = position);

      // Get address from coordinates using OpenStreetMap Nominatim
      print('Fetching address from OpenStreetMap...');
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1',
        ),
      );

      print('OpenStreetMap response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('OpenStreetMap data: $data');
        setState(() {
          _locationDetails = {
            'street': data['address']['road'] ?? '',
            'city': data['address']['city'] ??
                data['address']['town'] ??
                data['address']['village'] ??
                '',
            'region': data['address']['state'] ?? '',
            'country': data['address']['country'] ?? '',
            'latitude': position.latitude,
            'longitude': position.longitude,
          };
        });
        print('Location details set: $_locationDetails');
      } else {
        print('OpenStreetMap request failed: ${response.body}');
        // If reverse geocoding fails, still save coordinates
        setState(() {
          _locationDetails = {
            'street': '',
            'city': '',
            'region': '',
            'country': '',
            'latitude': position.latitude,
            'longitude': position.longitude,
          };
        });
        print('Location details set with coordinates only: $_locationDetails');
      }
    } catch (e) {
      print('Error getting location: $e');
      debugPrint('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load damage classes')),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking picture: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String> _imageToBase64() async {
    if (_capturedImage == null) return '';

    try {
      final imageBytes = await _capturedImage!.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      // Return as data URL format like the web version
      return 'data:image/jpeg;base64,$base64Image';
    } catch (e) {
      debugPrint('Error converting image to base64: $e');
      return '';
    }
  }

  Future<void> _submitReport() async {
    if (_capturedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please take a picture first')),
      );
      return;
    }

    if (_selectedDamageClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a damage class')),
      );
      return;
    }

    if (_roadNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter road name')),
      );
      return;
    }

    if (_commentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a comment')),
      );
      return;
    }

    if (_locationDetails == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Location not available. Please enable location permissions.')),
      );
      return;
    }

    // Check if we have at least coordinates
    if (_locationDetails!['latitude'] == null ||
        _locationDetails!['longitude'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'GPS coordinates not available. Please check location settings.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final imageData = await _imageToBase64();

      print('Image data length: ${imageData.length}');
      print('Image data preview: ${imageData.substring(0, 100)}...');

      await Provider.of<DamageProvider>(context, listen: false).submitReport(
        userId: authProvider.userId!,
        fullname: authProvider.fullname!,
        email: authProvider.email!,
        imageData: imageData,
        location: _locationDetails!,
        roadName: _roadNameController.text,
        damageClass: _selectedDamageClass!,
        comment: _commentController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted successfully')),
        );
        _resetForm();
      }
    } catch (e) {
      print('Error submitting report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit report: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetForm() {
    setState(() {
      _capturedImage = null;
      _selectedDamageClass = null;
      _roadNameController.clear();
      _commentController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final damageClasses = Provider.of<DamageProvider>(context).damageClasses;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Road Damage Survey'),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: _controller == null
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.blue[50]!,
                    Colors.white,
                  ],
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Initializing camera...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.blue[50]!,
                          Colors.white,
                        ],
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Camera Preview
                          Container(
                            height: 300,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _capturedImage != null
                                  ? Image.file(
                                      File(_capturedImage!.path),
                                      fit: BoxFit.cover,
                                    )
                                  : CameraPreview(_controller!),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Camera Controls
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isLoading ? null : _takePicture,
                                    icon: _isLoading
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white),
                                          )
                                        : const Icon(Icons.camera_alt),
                                    label: Text(_isLoading
                                        ? 'Capturing...'
                                        : 'Take Photo'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[600],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_capturedImage != null) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          setState(() => _capturedImage = null),
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Retake'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange[600],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Location Information
                          if (_locationDetails != null ||
                              _isLocationLoading) ...[
                            Card(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.blue[50]!,
                                      Colors.white,
                                    ],
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[100],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(Icons.location_on,
                                                color: Colors.blue[600]),
                                          ),
                                          const SizedBox(width: 12),
                                          const Expanded(
                                            child: Text(
                                              'Location Details',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (_isLocationLoading)
                                            const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2),
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
                                      if (_isLocationLoading)
                                        const Text('Getting location...')
                                      else if (_locationDetails != null) ...[
                                        _buildLocationRow('Street',
                                            _locationDetails!['street']),
                                        _buildLocationRow(
                                            'City', _locationDetails!['city']),
                                        _buildLocationRow('Region',
                                            _locationDetails!['region']),
                                        _buildLocationRow('Country',
                                            _locationDetails!['country']),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[100],
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.gps_fixed,
                                                  size: 16,
                                                  color: Colors.blue[700]),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Coordinates: [${_locationDetails!['latitude'].toStringAsFixed(5)}, ${_locationDetails!['longitude'].toStringAsFixed(5)}]',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue[700],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Report Form
                          Card(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white,
                                    Colors.grey[50]!,
                                  ],
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[100],
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.assignment,
                                              color: Colors.blue[600]),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'Report Details',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),

                                    // Road Name
                                    TextField(
                                      controller: _roadNameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Road / Street Name',
                                        prefixIcon: Icon(Icons.map),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Damage Class Dropdown
                                    DropdownButtonFormField<String>(
                                      value: _selectedDamageClass,
                                      decoration: const InputDecoration(
                                        labelText: 'Damage Class',
                                        prefixIcon: Icon(Icons.construction),
                                      ),
                                      items: damageClasses
                                          .map((DamageClass damageClass) {
                                        return DropdownMenuItem<String>(
                                          value: damageClass.damageClass,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Class ${damageClass.damageClass}',
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
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
                                      }).toList(),
                                      onChanged: (String? value) {
                                        setState(
                                            () => _selectedDamageClass = value);
                                      },
                                    ),
                                    const SizedBox(height: 16),

                                    // Selected Damage Class Info
                                    if (_selectedDamageClass != null) ...[
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Colors.blue[50]!,
                                              Colors.blue[100]!,
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.blue[200]!,
                                            width: 1,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.info_outline,
                                                    color: Colors.blue[600],
                                                    size: 20),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Selected Damage Class',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue[800],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Class $_selectedDamageClass',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              damageClasses
                                                  .firstWhere((dc) =>
                                                      dc.damageClass ==
                                                      _selectedDamageClass)
                                                  .description,
                                              style:
                                                  const TextStyle(fontSize: 14),
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.blue[200],
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Text(
                                                '${damageClasses.firstWhere((dc) => dc.damageClass == _selectedDamageClass).repairCost.toStringAsFixed(0)} TZS',
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
                                      const SizedBox(height: 16),
                                    ],

                                    // Comments
                                    TextField(
                                      controller: _commentController,
                                      decoration: const InputDecoration(
                                        labelText: 'Describe the damage',
                                        prefixIcon: Icon(Icons.comment),
                                        alignLabelWithHint: true,
                                      ),
                                      maxLines: 3,
                                    ),
                                    const SizedBox(height: 24),

                                    // Submit Button
                                    Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.green[600]!,
                                            Colors.green[700]!,
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.green.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton.icon(
                                        onPressed:
                                            _isLoading ? null : _submitReport,
                                        icon: _isLoading
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white),
                                              )
                                            : const Icon(Icons.send),
                                        label: Text(_isLoading
                                            ? 'Submitting...'
                                            : 'Submit Report'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          foregroundColor: Colors.white,
                                          shadowColor: Colors.transparent,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          textStyle:
                                              const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Bottom Navigation
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ReportsScreen()),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.history, color: Colors.blue[600]),
                                const SizedBox(height: 4),
                                Text(
                                  'View Reports',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            await Provider.of<AuthProvider>(context,
                                    listen: false)
                                .logout();
                            if (mounted) {
                              Navigator.of(context)
                                  .pushReplacementNamed('/login');
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.logout, color: Colors.red[600]),
                                const SizedBox(height: 4),
                                Text(
                                  'Logout',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLocationRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
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
}
