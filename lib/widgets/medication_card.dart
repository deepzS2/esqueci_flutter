import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tordo/models/medication.dart';
import 'package:audioplayers/audioplayers.dart';

class MedicationCard extends StatefulWidget {
  final Medication medication;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final Function(bool isActive) onToggleActive;

  const MedicationCard({
    super.key,
    required this.medication,
    required this.onDelete,
    required this.onEdit,
    required this.onToggleActive,
  });

  @override
  State<MedicationCard> createState() => _MedicationCardState();
}

class _MedicationCardState extends State<MedicationCard> {
  bool _isPlaying = false;
  final _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio() async {
    if (widget.medication.audioPath.isNotEmpty) {
      if (File(widget.medication.audioPath).existsSync()) {
        setState(() {
          _isPlaying = true;
        });

        final source = DeviceFileSource(widget.medication.audioPath);
        await _audioPlayer.play(source);

        _audioPlayer.eventStream.listen((event) {
          if (event.eventType == AudioEventType.complete) {
            setState(() {
              _isPlaying = false;
            });
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('O arquivo de áudio não foi encontrado'),
            ),
          );
        }
      }
    }
  }

  Future<void> _stopPlayback() async {
    await _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Medication Image
          if (widget.medication.photoPath.isNotEmpty &&
              File(widget.medication.photoPath).existsSync())
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Image.file(
                File(widget.medication.photoPath),
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

          // Medication Details
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.medication.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Switch(
                      value: widget.medication.isActive,
                      onChanged: widget.onToggleActive,
                      activeColor: Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.medication.description,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 15),

                // Alarm Times
                const Text(
                  'Horários:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      widget.medication.alarmTimes.map((time) {
                        return Chip(
                          label: Text(
                            time,
                            style: const TextStyle(fontSize: 14),
                          ),
                          avatar: const Icon(Icons.access_time, size: 18),
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 15),

                // Audio Controls
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isPlaying ? _stopPlayback : _playAudio,
                      icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                      label: Text(
                        _isPlaying ? 'Parar' : 'Ouvir Instruções',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        backgroundColor: _isPlaying ? Colors.red : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar', style: TextStyle(fontSize: 16)),
                ),
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Confirmar exclusão'),
                            content: Text(
                              'Tem certeza que deseja excluir o medicamento "${widget.medication.name}"?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  widget.onDelete();
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Excluir'),
                              ),
                            ],
                          ),
                    );
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text(
                    'Excluir',
                    style: TextStyle(fontSize: 16, color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
