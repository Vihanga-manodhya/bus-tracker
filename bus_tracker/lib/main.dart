import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Import your two pages
import 'tracking_page.dart';
import 'admin_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const BusTrackerApp());
}

class BusTrackerApp extends StatelessWidget {
  const BusTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bus Fleet Tracker',
      debugShowCheckedModeBanner: false, // Removes the "DEBUG" banner
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // Set the home screen to our new selection page
      home: const RoleSelectionPage(), 
    );
  }
}

// --- NEW LANDING PAGE ---
class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  // We are using a fixed ID for the pilot project test
  final String testBusId = 'baddegama_galle_001';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus Tracker System', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueGrey[900],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_transit, size: 100, color: Colors.blueGrey[700]),
            const SizedBox(height: 30),
            const Text(
              'Select Your Role',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            
            // BUTTON 1: DRIVER APP
            ElevatedButton.icon(
              icon: const Icon(Icons.drive_eta),
              label: const Text('Start Driver Tracker (Mobile)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, // Background color
                foregroundColor: Colors.white, // Text color
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                // Navigate to the Tracking Page
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TrackingPage(busId: testBusId),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 20),
            
            // BUTTON 2: ADMIN DASHBOARD
            ElevatedButton.icon(
              icon: const Icon(Icons.map),
              label: const Text('Open Admin Dashboard (Web)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, // Background color
                foregroundColor: Colors.white, // Text color
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                // Navigate to the Admin Dashboard
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminDashboard(busId: testBusId),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}