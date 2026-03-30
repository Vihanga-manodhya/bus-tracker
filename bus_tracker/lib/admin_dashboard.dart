import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class AdminDashboard extends StatefulWidget {
  final String busId;

  const AdminDashboard({super.key, required this.busId});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final MapController _mapController = MapController();
  
  // Controls whether the map should automatically lock onto the moving bus
  bool _isAutoTracking = true; 
  LatLng? _latestLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Depot Dashboard', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueGrey[900],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('buses').doc(widget.busId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("No live data available for this bus yet."));
          }

          var busData = snapshot.data!.data() as Map<String, dynamic>;
          double lat = busData['latitude'] ?? 6.0535;
          double lng = busData['longitude'] ?? 80.2210;
          String speed = busData['speed_kmh'] ?? "0.00";
          String status = busData['status'] ?? "Unknown";
          
          Timestamp? timestamp = busData['last_updated'];
          String lastUpdated = timestamp != null 
              ? _formatTime(timestamp.toDate()) 
              : "N/A";

          _latestLocation = LatLng(lat, lng);

          // If auto-tracking is ON, smoothly move the camera to the new pinpoint
          if (_isAutoTracking) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Zoom level 16.0 provides a much better "pinpoint" street view
              _mapController.move(_latestLocation!, 16.0); 
            });
          }

          return Row(
            children: [
              // LEFT SIDE: The Live Map
              Expanded(
                flex: 7,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _latestLocation!,
                        initialZoom: 16.0,
                        // Detect if the admin manually drags the map
                        onPositionChanged: (position, hasGesture) {
                          if (hasGesture && _isAutoTracking) {
                            // Turn off auto-tracking so they can freely explore the map
                            setState(() {
                              _isAutoTracking = false;
                            });
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.bus_tracker',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _latestLocation!,
                              width: 60,
                              height: 60,
                              // The pinpoint marker
                              child: const Icon(
                                Icons.location_on, // Changed to a solid pin icon
                                color: Colors.red,
                                size: 50,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    // The "Recenter" Floating Action Button
                    Positioned(
                      bottom: 30,
                      right: 30,
                      child: FloatingActionButton.extended(
                        onPressed: () {
                          // Manually lock back onto the bus
                          setState(() {
                            _isAutoTracking = true;
                          });
                          _mapController.move(_latestLocation!, 16.0);
                        },
                        icon: Icon(_isAutoTracking ? Icons.my_location : Icons.location_searching, color: Colors.white),
                        label: Text(
                          _isAutoTracking ? 'Tracking Live' : 'Locate Bus',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: _isAutoTracking ? Colors.green : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),

              // RIGHT SIDE: The Details Panel
              Expanded(
                flex: 3,
                child: Container(
                  color: Colors.grey[100],
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bus Details',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const Divider(),
                      const SizedBox(height: 20),
                      _buildInfoCard(Icons.badge, 'Bus ID', widget.busId),
                      const SizedBox(height: 15),
                      _buildInfoCard(Icons.speed, 'Current Speed', '$speed km/h'),
                      const SizedBox(height: 15),
                      _buildInfoCard(Icons.satellite_alt, 'Status', status.toUpperCase()),
                      const SizedBox(height: 15),
                      _buildInfoCard(Icons.access_time, 'Last Signal', lastUpdated),
                    ],
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String title, String value) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: Colors.blueGrey),
        title: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}";
  }
}