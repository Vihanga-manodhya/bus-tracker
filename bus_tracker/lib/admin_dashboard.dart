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
  bool _isAutoTracking = true;
  LatLng? _latestLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SLTB Monitoring: ${widget.busId}', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueGrey[900],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('buses').doc(widget.busId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("No GPS signal received yet."));
          }

          var busData = snapshot.data!.data() as Map<String, dynamic>;
          double lat = busData['latitude'] ?? 6.0535;
          double lng = busData['longitude'] ?? 80.2210;
          String speed = busData['speed_kmh'] ?? "0.0";
          String state = busData['state'] ?? "Unknown";
          
          Timestamp? timestamp = busData['last_updated'];
          String lastUpdated = timestamp != null 
              ? "${timestamp.toDate().hour.toString().padLeft(2, '0')}:${timestamp.toDate().minute.toString().padLeft(2, '0')}" 
              : "N/A";

          _latestLocation = LatLng(lat, lng);

          // Extract the Route History (Path)
          List<LatLng> routeHistory = [];
          if (busData['path'] != null) {
            List<dynamic> rawPath = busData['path'];
            for (var point in rawPath) {
              if (point is GeoPoint) {
                routeHistory.add(LatLng(point.latitude, point.longitude));
              }
            }
          }

          if (_isAutoTracking) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _mapController.move(_latestLocation!, 15.0);
            });
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              bool isMobile = constraints.maxWidth < 800;

              Widget mapWidget = Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _latestLocation!,
                      initialZoom: 15.0,
                      onPositionChanged: (position, hasGesture) {
                        if (hasGesture && _isAutoTracking) {
                          setState(() => _isAutoTracking = false);
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.bus_tracker',
                      ),
                      // DRAW THE ROUTE LINE
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: routeHistory,
                            strokeWidth: 5.0,
                            color: Colors.blueAccent,
                          ),
                        ],
                      ),
                      // DRAW THE BUS MARKER
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _latestLocation!,
                            width: 60,
                            height: 60,
                            child: Icon(
                              Icons.directions_bus, 
                              color: state.contains("Idling") ? Colors.orange : Colors.red, 
                              size: 40
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: FloatingActionButton.extended(
                      backgroundColor: _isAutoTracking ? Colors.green : Colors.redAccent,
                      onPressed: () {
                        setState(() => _isAutoTracking = true);
                        _mapController.move(_latestLocation!, 15.0);
                      },
                      icon: Icon(_isAutoTracking ? Icons.my_location : Icons.location_searching, color: Colors.white),
                      label: Text(_isAutoTracking ? "Tracking" : "Locate"),
                    ),
                  ),
                ],
              );

              Widget detailsWidget = Container(
                color: Colors.white,
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SLTB Waybill Telemetry', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const Divider(),
                      
                      // Highlight the Bus State (Moving vs Stopped at Checkpoint)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: state.contains("At Stop") ? Colors.green[50] : (state.contains("Idling") ? Colors.orange[50] : Colors.blue[50]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: state.contains("At Stop") ? Colors.green : Colors.blue),
                            const SizedBox(width: 10),
                            Expanded(child: Text(state, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildInfoTile(Icons.speed, 'Speed', '$speed km/h', Colors.blue),
                      _buildInfoTile(Icons.update, 'Last Sync', lastUpdated, Colors.green),
                      _buildInfoTile(Icons.route, 'Data Points Saved', '${routeHistory.length} locations', Colors.purple),
                    ],
                  ),
                ),
              );

              if (isMobile) {
                return Column(
                  children: [
                    Expanded(flex: 2, child: mapWidget),
                    Expanded(flex: 1, child: detailsWidget),
                  ],
                );
              } else {
                return Row(
                  children: [
                    Expanded(flex: 7, child: mapWidget),
                    Expanded(flex: 3, child: detailsWidget),
                  ],
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: iconColor.withOpacity(0.1), child: Icon(icon, color: iconColor)),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }
}