import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Define the major bus stops (Virtual Checkpoints)
class BusStop {
  final String name;
  final double lat;
  final double lng;
  final double radiusMeters;

  BusStop(this.name, this.lat, this.lng, {this.radiusMeters = 50.0});
}

class TrackingPage extends StatefulWidget {
  final String busId;
  const TrackingPage({super.key, required this.busId});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  StreamSubscription<Position>? _positionStreamSubscription;
  String _status = "Checking permissions...";
  String _currentBusState = "Starting up...";
  Position? _currentPosition;
  bool _isTracking = false;

  // Example coordinates for Baddegama to Galle route
  final List<BusStop> stops = [
    BusStop("Baddegama Bus Stand", 6.1186, 80.1983),
    BusStop("Wanduramba Junction", 6.0964, 80.2522),
    BusStop("Galle Main Stand", 6.0328, 80.2150),
  ];

  @override
  void initState() {
    super.initState();
    _requestPermissionAndStart();
  }

  Future<void> _requestPermissionAndStart() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _status = "Error: Turn on GPS");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _status = "Error: Permission denied.");
          return;
        }
      }

      setState(() {
        _status = "Tracking Active";
        _isTracking = true;
      });

      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15, // Update every 15 meters to save database reads
      );

      _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
          .listen((Position position) {
        _processNewLocation(position);
      });
    } catch (e) {
      setState(() => _status = "Error: $e");
    }
  }

  void _processNewLocation(Position position) {
    setState(() => _currentPosition = position);
    double speedKmh = position.speed * 3.6;

    // 1. Check Geofences (Are we inside a bus stop?)
    String newState = "Moving";
    if (speedKmh < 3.0) {
      newState = "Idling / Traffic"; // Default if stopped outside a zone
      
      for (var stop in stops) {
        double distance = Geolocator.distanceBetween(
          position.latitude, position.longitude,
          stop.lat, stop.lng
        );
        if (distance <= stop.radiusMeters) {
          newState = "At Stop: ${stop.name}";
          break; // Stop searching once we find the bus stop
        }
      }
    }

    setState(() => _currentBusState = newState);
    _updateDatabase(position, speedKmh, newState);
  }

  Future<void> _updateDatabase(Position position, double speedKmh, String state) async {
    try {
      // Create a GeoPoint for the path array
      GeoPoint currentGeoPoint = GeoPoint(position.latitude, position.longitude);

      await FirebaseFirestore.instance.collection('buses').doc(widget.busId).set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'speed_kmh': speedKmh.toStringAsFixed(1),
        'state': state,
        'last_updated': FieldValue.serverTimestamp(),
        // ArrayUnion appends the new location to the list without overwriting the old ones
        'path': FieldValue.arrayUnion([currentGeoPoint]) 
      }, SetOptions(merge: true));
    } catch (e) {
      print("Firebase Error: $e");
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('SLTB Driver Console', style: TextStyle(color: Colors.white)),
        backgroundColor: _isTracking ? Colors.green[700] : Colors.orange[800],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isTracking ? Icons.satellite_alt : Icons.location_off,
                        size: 60,
                        color: _isTracking ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _status,
                        style: TextStyle(fontSize: 18, color: _isTracking ? Colors.green[800] : Colors.red),
                      ),
                      const Divider(height: 30, thickness: 2),
                      
                      // Status Display (Moving, At Stop, Idling)
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue),
                        ),
                        child: Column(
                          children: [
                            const Text("Current Status", style: TextStyle(color: Colors.blueGrey)),
                            const SizedBox(height: 5),
                            Text(_currentBusState, 
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      if (_currentPosition != null) ...[
                        _buildDataRow('Speed', '${(_currentPosition!.speed * 3.6).toStringAsFixed(1)} km/h'),
                      ] else if (_isTracking) ...[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 15),
                        const Text("Acquiring GPS Signal..."),
                      ]
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, color: Colors.blueGrey)),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}