import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  String _patientId = "1";
  String _patientName = "Sugan";

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final pid = prefs.getInt("patient_id") ?? prefs.getString("patient_id");
    final name = prefs.getString("patient_name");
    if (mounted) {
      setState(() {
        if (pid != null) _patientId = pid.toString();
        if (name != null) _patientName = name;
      });
    }
  }

  Future<void> _launchWhatsApp() async {
    final url = Uri.parse(
      "https://wa.me/16132616383?text=Hi%20Doctor,%20this%20is%20$_patientName%20(ID:%20$_patientId).%20I'm%20reaching%20out%20via%20Smart%20Health%20Mobile.",
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Smart Health Dashboard", style: TextStyle(fontWeight: '700')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, "/settings"),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Patient Welcome Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Theme.of(context).primaryColor, Colors.blue.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Welcome back,",
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _patientName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: 'bold',
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "ID: #$_patientId",
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: '700'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.apple, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Apple HealthKit & Central Cloud Synced",
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: '600'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // WhatsApp Direct Action Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.green.shade300, width: 1.2),
              ),
              color: const Color(0xFFF0FDF4),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _launchWhatsApp,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Color(0xFF25D366),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.chat, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Chat with Clinic on WhatsApp",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: '700',
                                color: Color(0xFF166534),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Instant AI triage & direct connect with Dr. Patel",
                              style: TextStyle(fontSize: 12, color: Color(0xFF15803D)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF166534)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Main Action Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _buildGridCard(
                  context,
                  title: "AI Assistant",
                  subtitle: "Chat & Telemetry",
                  icon: Icons.smart_toy_rounded,
                  color: Colors.purple.shade600,
                  bgColor: Colors.purple.shade50,
                  route: "/assistant",
                ),
                _buildGridCard(
                  context,
                  title: "Vitals & Apple Watch",
                  subtitle: "Live Telemetry",
                  icon: Icons.favorite_rounded,
                  color: Colors.red.shade600,
                  bgColor: Colors.red.shade50,
                  route: "/vitals",
                ),
                _buildGridCard(
                  context,
                  title: "Medications",
                  subtitle: "Prescription Log",
                  icon: Icons.medication_rounded,
                  color: Colors.blue.shade600,
                  bgColor: Colors.blue.shade50,
                  route: "/medications",
                ),
                _buildGridCard(
                  context,
                  title: "Urgent Care",
                  subtitle: "Clinics & Wait Times",
                  icon: Icons.local_hospital_rounded,
                  color: Colors.orange.shade700,
                  bgColor: Colors.orange.shade50,
                  route: "/urgent-care",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String route,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pushNamed(context, route),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: '700', fontSize: 14)),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
