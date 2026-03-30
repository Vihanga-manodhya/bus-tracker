import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TrackingPage extends StatefulWidget {
  final String busId;

  const TrackingPage({super.key, required this.busId});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  StreamSubscription<Position>? _positionStreamSubscription;
  String _status = "Initializing...";
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  Future<void> _startTracking() async {
    // 1. Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _status = "Location services are disabled.");
      return;
    }

    // 2. Check and request location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _status = "Location permissions denied.");
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      setState(() => _status = "Location permissions are permanently denied.");
      return;
    }

    setState(() => _status = "Tracking Started...");

    // 3. Start listening to location updates
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Only update if the bus moves by 10 meters
    );

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      
      setState(() {
        _currentPosition = position;
      });

      // 4. Send the new location to Firebase
      _updateDatabase(position);
    });
  }

  Future<void> _updateDatabase(Position position) async {
    try {
      // We use set() to update a specific document for this bus
      await FirebaseFirestore.instance.collection('buses').doc(widget.busId).set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'speed_kmh': (position.speed * 3.6).toStringAsFixed(2), // Convert m/s to km/h
        'last_updated': FieldValue.serverTimestamp(),
        'status': 'moving',
      }, SetOptions(merge: true)); // Merge ensures we don't overwrite other data
      
    } catch (e) {
      print("Error updating database: $e");
    }
  }

  @override
  void dispose() {
    // Stop tracking when the page is closed to save battery
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver App - ${widget.busId}'),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_bus, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            Text(
              'Status: $_status',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (_currentPosition != null) ...[
              Text('Latitude: ${_currentPosition!.latitude}'),
              Text('Longitude: ${_currentPosition!.longitude}'),
              Text('Speed: ${(_currentPosition!.speed * 3.6).toStringAsFixed(2)} km/h'),
            ]
          ],
        ),
      ),
    );
  }
}