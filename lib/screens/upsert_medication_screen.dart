import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tordo/models/medication.dart';
import 'package:tordo/services/database_helper.dart';
import 'package:tordo/services/notification_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

class AddEditMedicationScreen extends StatefulWidget {
  final Medication? medication;

  const AddEditMedicationScreen({super.key, this.medication});

  @override
  State<AddEditMedicationScreen> createState() =>
      _AddEditMedicationScreenState();
}

class _AddEditMedicationScreenState extends State<AddEditMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _photoPath = '';
  String _audioPath = '';
  final List<String> _alarmTimes = [];
  bool _isActive = true;
  bool _isRecording = false;
  bool _isPlaying = false;
  final _record = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();

    _requestPermissions();

    if (widget.medication != null) {
      _nameController.text = widget.medication!.name;
      _descriptionController.text = widget.medication!.description;
      _photoPath = widget.medication!.photoPath;
      _audioPath = widget.medication!.audioPath;
      _alarmTimes.addAll(widget.medication!.alarmTimes);
      _isActive = widget.medication!.isActive;
    }

    // Add at least one alarm time if none exists
    if (_alarmTimes.isEmpty) {
      _alarmTimes.add('08:00');
    }
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    await Permission.microphone.request();
    await Permission.storage.request();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _record.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (image != null) {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = File(path.join(directory.path, fileName));
      await savedImage.writeAsBytes(await image.readAsBytes());

      setState(() {
        _photoPath = savedImage.path;
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (image != null) {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = File(path.join(directory.path, fileName));
      await savedImage.writeAsBytes(await image.readAsBytes());

      setState(() {
        _photoPath = savedImage.path;
      });
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _record.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.m4a';
        final filePath = path.join(directory.path, fileName);

        const recordConfig = RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 4410,
        );

        await _record.start(recordConfig, path: filePath);

        setState(() {
          _isRecording = true;
          _audioPath = filePath;
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao gravar áudio: $e')));
      }
    }
  }

  Future<void> _stopRecording() async {
    await _record.stop();
    setState(() {
      _isRecording = false;
    });
  }

  Future<void> _playAudio() async {
    if (_audioPath.isNotEmpty && File(_audioPath).existsSync()) {
      setState(() {
        _isPlaying = true;
      });

      final source = DeviceFileSource(_audioPath);
      await _audioPlayer.play(source);

      _audioPlayer.eventStream.listen((event) {
        if (event.eventType == AudioEventType.complete) {
          setState(() {
            _isPlaying = false;
          });
        }
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nenhum áudio gravado')));
    }
  }

  Future<void> _stopPlayback() async {
    await _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
    });
  }

  Future<void> _selectTime(int index) async {
    final TimeOfDay? selected = await showTimePicker(
      context: context,
      initialTime: _parseTimeOfDay(_alarmTimes[index]),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            timePickerTheme: TimePickerThemeData(
              dialTextColor: Colors.black,
              hourMinuteTextColor: Colors.black,
              dayPeriodTextColor: Colors.black,
              dialHandColor: Colors.blue,
              dialBackgroundColor: Colors.white,
              hourMinuteColor: WidgetStateColor.resolveWith(
                (states) =>
                    states.contains(WidgetState.selected)
                        ? Colors.blue
                        : Colors.grey.shade200,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (selected != null) {
      setState(() {
        _alarmTimes[index] =
            '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  TimeOfDay _parseTimeOfDay(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  void _addAlarmTime() {
    setState(() {
      _alarmTimes.add('08:00');
    });
  }

  void _removeAlarmTime(int index) {
    if (_alarmTimes.length > 1) {
      setState(() {
        _alarmTimes.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('É necessário ter pelo menos um horário de alarme'),
        ),
      );
    }
  }

  Future<void> _saveMedication() async {
    if (!_formKey.currentState!.validate()) return;

    if (_photoPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, adicione uma foto do medicamento'),
        ),
      );
      return;
    }

    if (_audioPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, grave instruções de áudio')),
      );
      return;
    }

    final medication = Medication(
      id: widget.medication?.id,
      name: _nameController.text,
      description: _descriptionController.text,
      photoPath: _photoPath,
      audioPath: _audioPath,
      alarmTimes: _alarmTimes,
      isActive: _isActive,
    );

    final DatabaseHelper dbHelper = DatabaseHelper();
    final NotificationService notificationService = NotificationService();

    if (widget.medication == null) {
      final id = await dbHelper.insertMedication(medication);
      medication.id = id as int?;
    } else {
      await dbHelper.updateMedication(medication);
    }

    await notificationService.scheduleAlarms(medication);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.medication == null ? 'Novo Medicamento' : 'Editar Medicamento',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Medication Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Medicamento',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.medication),
                ),
                style: const TextStyle(fontSize: 18),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o nome do medicamento';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Medication Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Instruções ou Descrição',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                style: const TextStyle(fontSize: 18),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira as instruções de uso';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Medication Photo
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Foto do Medicamento',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _photoPath.isNotEmpty
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(_photoPath),
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          )
                          : Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.photo_outlined,
                              size: 80,
                              color: Colors.grey,
                            ),
                          ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _takePicture,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text(
                              'Tirar Foto',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.photo_library),
                            label: const Text(
                              'Galeria',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Audio Recording
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Instruções de Áudio',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Grave um áudio com instruções sobre como tomar este medicamento:',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (!_isRecording && !_isPlaying)
                            ElevatedButton.icon(
                              onPressed: _startRecording,
                              icon: const Icon(Icons.mic),
                              label: const Text(
                                'Gravar Áudio',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          if (_isRecording)
                            ElevatedButton.icon(
                              onPressed: _stopRecording,
                              icon: const Icon(Icons.stop),
                              label: const Text(
                                'Parar Gravação',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          if (!_isRecording &&
                              _audioPath.isNotEmpty &&
                              !_isPlaying)
                            ElevatedButton.icon(
                              onPressed: _playAudio,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text(
                                'Ouvir Áudio',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          if (_isPlaying)
                            ElevatedButton.icon(
                              onPressed: _stopPlayback,
                              icon: const Icon(Icons.stop),
                              label: const Text(
                                'Parar',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (_audioPath.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            _isRecording
                                ? 'Gravando...'
                                : _isPlaying
                                ? 'Reproduzindo...'
                                : 'Áudio gravado ${_audioPath.split('/').last}',
                            style: TextStyle(
                              fontSize: 14,
                              color: _isRecording ? Colors.red : Colors.green,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Alarm Times
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Horários dos Alarmes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Defina os horários para os lembretes:',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _alarmTimes.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _selectTime(index),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.access_time),
                                          const SizedBox(width: 10),
                                          Text(
                                            _alarmTimes[index],
                                            style: const TextStyle(
                                              fontSize: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _removeAlarmTime(index),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _addAlarmTime,
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'Adicionar Horário',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Active Status
              SwitchListTile(
                title: const Text(
                  'Ativar Lembretes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
                secondary: Icon(
                  _isActive
                      ? Icons.notifications_active
                      : Icons.notifications_off,
                  color: _isActive ? Colors.green : Colors.grey,
                  size: 30,
                ),
              ),
              const SizedBox(height: 30),

              // Save Button
              ElevatedButton(
                onPressed: _saveMedication,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  widget.medication == null
                      ? 'Salvar Medicamento'
                      : 'Atualizar Medicamento',
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
