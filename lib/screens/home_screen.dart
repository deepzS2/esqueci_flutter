import 'package:flutter/material.dart';
import 'package:tordo/models/medication.dart';
import 'package:tordo/screens/upsert_medication_screen.dart';
import 'package:tordo/services/database_helper.dart';
import 'package:tordo/services/notification_service.dart';
import 'package:tordo/widgets/medication_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final NotificationService _notificationService = NotificationService();
  List<Medication> _medications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedications();

    // Listen for notification clicks
    _notificationService.onNotificationClick.stream.listen(
      _onNotificationClick,
    );
  }

  Future<void> _loadMedications() async {
    setState(() {
      _isLoading = true;
    });

    final medications = await _databaseHelper.getMedications();

    setState(() {
      _medications = medications;
      _isLoading = false;
    });
  }

  void _onNotificationClick(String? payload) async {
    if (payload == null) return;

    final int medicationId = int.parse(payload);
    final medication = await _databaseHelper.getMedication(medicationId);

    if (medication != null && context.mounted) {
      // Play audio instructions
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddEditMedicationScreen(medication: medication),
        ),
      );

      // Speak instructions
      await _notificationService.speakInstructions(medication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Esqueci',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _medications.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.medication_outlined,
                      size: 80,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Nenhum medicamento cadastrado',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Clique no botão abaixo para adicionar',
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: _medications.length,
                padding: const EdgeInsets.all(16.0),
                itemBuilder: (context, index) {
                  return MedicationCard(
                    medication: _medications[index],
                    onDelete: () async {
                      await _databaseHelper.deleteMedication(
                        _medications[index].id!,
                      );
                      await _notificationService.cancelAlarms(
                        _medications[index].id!,
                      );
                      _loadMedications();
                    },
                    onEdit: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => AddEditMedicationScreen(
                                medication: _medications[index],
                              ),
                        ),
                      );
                      _loadMedications();
                    },
                    onToggleActive: (bool isActive) async {
                      final updatedMedication = Medication(
                        id: _medications[index].id,
                        name: _medications[index].name,
                        description: _medications[index].description,
                        photoPath: _medications[index].photoPath,
                        audioPath: _medications[index].audioPath,
                        alarmTimes: _medications[index].alarmTimes,
                        isActive: isActive,
                      );

                      await _databaseHelper.updateMedication(updatedMedication);
                      await _notificationService.scheduleAlarms(
                        updatedMedication,
                      );
                      _loadMedications();
                    },
                  );
                },
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditMedicationScreen(),
            ),
          );
          _loadMedications();
        },
        icon: const Icon(Icons.add),
        label: const Text(
          'Adicionar Medicamento',
          style: TextStyle(fontSize: 16),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
