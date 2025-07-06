import 'package:flutter/material.dart';
import 'package:question_bank/model/question_metadata_model.dart';

import 'package:question_bank/service/metadata_service.dart';

class QuestionMetadataForm extends StatefulWidget {
  final QuestionMetadataModel questionModel;
  final MetadataService metadataService;
  final VoidCallback onMetadataChanged;

  const QuestionMetadataForm({
    Key? key,
    required this.questionModel,
    required this.metadataService,
    required this.onMetadataChanged,
  }) : super(key: key);

  @override
  State<QuestionMetadataForm> createState() => _QuestionMetadataFormState();
}

class _QuestionMetadataFormState extends State<QuestionMetadataForm> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Stream Dropdown
          DropdownButtonFormField<String>(
            value: widget.questionModel.stream,
            decoration: const InputDecoration(
              labelText: 'Stream',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: widget.metadataService.streams.map((stream) {
              return DropdownMenuItem(
                value: stream,
                child: Text(stream),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                widget.questionModel.stream = value;
              });
              widget.onMetadataChanged();
            },
          ),
          const SizedBox(height: 12),

          // Level Dropdown
          DropdownButtonFormField<String>(
            value: widget.questionModel.level,
            decoration: const InputDecoration(
              labelText: 'Level',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: widget.metadataService.levels.map((level) {
              return DropdownMenuItem(
                value: level,
                child: Text(level),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                widget.questionModel.level = value;
              });
              widget.onMetadataChanged();
            },
          ),
          const SizedBox(height: 12),

          // Topic Dropdown
          DropdownButtonFormField<String>(
            value: widget.questionModel.topic,
            decoration: const InputDecoration(
              labelText: 'Topic',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: widget.metadataService.topics.map((topic) {
              return DropdownMenuItem(
                value: topic,
                child: Text(topic),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                widget.questionModel.topic = value;
              });
              widget.onMetadataChanged();
            },
          ),
          const SizedBox(height: 12),

          // Subtopic Dropdown
          DropdownButtonFormField<String>(
            value: widget.questionModel.subtopic,
            decoration: const InputDecoration(
              labelText: 'Subtopic',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: widget.metadataService.subtopics.map((subtopic) {
              return DropdownMenuItem(
                value: subtopic,
                child: Text(subtopic),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                widget.questionModel.subtopic = value;
              });
              widget.onMetadataChanged();
            },
          ),
          const SizedBox(height: 12),

          // Language Dropdown
          DropdownButtonFormField<String>(
            value: widget.questionModel.language,
            decoration: const InputDecoration(
              labelText: 'Language',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: widget.metadataService.languages.map((language) {
              return DropdownMenuItem(
                value: language,
                child: Text(language),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                widget.questionModel.language = value;
              });
              widget.onMetadataChanged();
            },
          ),
          const SizedBox(height: 12),

          // Chapter Dropdown
          DropdownButtonFormField<String>(
            value: widget.questionModel.chapter,
            decoration: const InputDecoration(
              labelText: 'Chapter',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: widget.metadataService.chapters.map((chapter) {
              return DropdownMenuItem(
                value: chapter,
                child: Text(chapter),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                widget.questionModel.chapter = value;
              });
              widget.onMetadataChanged();
            },
          ),
          const SizedBox(height: 12),

          // Type Dropdown
          DropdownButtonFormField<String>(
            value: widget.questionModel.type,
            decoration: const InputDecoration(
              labelText: 'Type',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: widget.metadataService.types.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                widget.questionModel.type = value;
              });
              widget.onMetadataChanged();
            },
          ),
          const SizedBox(height: 20),

          // Validation Status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.questionModel.isValid
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.questionModel.isValid
                    ? Colors.green.shade200
                    : Colors.orange.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.questionModel.isValid
                      ? Icons.check_circle
                      : Icons.warning,
                  color: widget.questionModel.isValid
                      ? Colors.green
                      : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.questionModel.isValid
                        ? 'All metadata fields completed'
                        : 'Please fill all metadata fields',
                    style: TextStyle(
                      color: widget.questionModel.isValid
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Quick Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _clearAllFields,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Clear All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade100,
                    foregroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _fillDefaults,
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: const Text('Set Defaults'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade100,
                    foregroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _clearAllFields() {
    setState(() {
      widget.questionModel.stream = null;
      widget.questionModel.level = null;
      widget.questionModel.topic = null;
      widget.questionModel.subtopic = null;
      widget.questionModel.language = null;
      widget.questionModel.chapter = null;
      widget.questionModel.type = null;
    });
    widget.onMetadataChanged();
  }

  void _fillDefaults() {
    setState(() {
      if (widget.metadataService.streams.isNotEmpty) {
        widget.questionModel.stream = widget.metadataService.streams.first;
      }
      if (widget.metadataService.levels.isNotEmpty) {
        widget.questionModel.level = widget.metadataService.levels.first;
      }
      if (widget.metadataService.topics.isNotEmpty) {
        widget.questionModel.topic = widget.metadataService.topics.first;
      }
      if (widget.metadataService.subtopics.isNotEmpty) {
        widget.questionModel.subtopic = widget.metadataService.subtopics.first;
      }
      if (widget.metadataService.languages.isNotEmpty) {
        widget.questionModel.language = widget.metadataService.languages.first;
      }
      if (widget.metadataService.chapters.isNotEmpty) {
        widget.questionModel.chapter = widget.metadataService.chapters.first;
      }
      if (widget.metadataService.types.isNotEmpty) {
        widget.questionModel.type = widget.metadataService.types.first;
      }
    });
    widget.onMetadataChanged();
  }
}
