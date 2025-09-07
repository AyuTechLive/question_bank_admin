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
  List<String> availableTopics = [];
  List<String> availableSubtopics = [];
  List<String> availableChapters = [];

  @override
  void initState() {
    super.initState();
    _updateAvailableOptions();
  }

  void _updateAvailableOptions() {
    setState(() {
      // Update topics based on selected stream
      availableTopics = widget.metadataService
          .getTopicsForStream(widget.questionModel.stream);

      // Update subtopics based on selected topic
      availableSubtopics = widget.metadataService
          .getSubtopicsForTopic(widget.questionModel.topic);

      // Update chapters based on selected topic
      availableChapters = widget.metadataService
          .getChaptersForTopic(widget.questionModel.topic);
    });

    // Validate current selections and clear invalid ones
    _validateAndClearInvalidSelections();
  }

  void _validateAndClearInvalidSelections() {
    bool changed = false;

    // Clear topic if it's not valid for current stream
    if (widget.questionModel.topic != null &&
        !availableTopics.contains(widget.questionModel.topic)) {
      widget.questionModel.topic = null;
      changed = true;
    }

    // Clear subtopic if it's not valid for current topic
    if (widget.questionModel.subtopic != null &&
        !availableSubtopics.contains(widget.questionModel.subtopic)) {
      widget.questionModel.subtopic = null;
      changed = true;
    }

    // Clear chapter if it's not valid for current topic
    if (widget.questionModel.chapter != null &&
        !availableChapters.contains(widget.questionModel.chapter)) {
      widget.questionModel.chapter = null;
      changed = true;
    }

    if (changed) {
      widget.onMetadataChanged();
    }
  }

  void _onStreamChanged(String? value) {
    setState(() {
      widget.questionModel.stream = value;
      // Clear dependent fields when stream changes
      widget.questionModel.topic = null;
      widget.questionModel.subtopic = null;
      widget.questionModel.chapter = null;
    });
    _updateAvailableOptions();
    widget.onMetadataChanged();
  }

  void _onTopicChanged(String? value) {
    setState(() {
      widget.questionModel.topic = value;
      // Clear dependent fields when topic changes
      widget.questionModel.subtopic = null;
      widget.questionModel.chapter = null;
    });
    _updateAvailableOptions();
    widget.onMetadataChanged();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Stream Dropdown
          DropdownButtonFormField<String>(
            value: widget.questionModel.stream,
            decoration: const InputDecoration(
              labelText: 'Stream *',
              border: OutlineInputBorder(),
              isDense: true,
              helperText: 'Select the exam stream first',
            ),
            items: widget.metadataService.streams.map((stream) {
              return DropdownMenuItem(
                value: stream,
                child: Text(stream),
              );
            }).toList(),
            onChanged: _onStreamChanged,
            validator: (value) =>
                value == null ? 'Please select a stream' : null,
          ),
          const SizedBox(height: 12),

          // Topic Dropdown (depends on stream)
          DropdownButtonFormField<String>(
            value: widget.questionModel.topic,
            decoration: InputDecoration(
              labelText: 'Subject/Topic *',
              border: const OutlineInputBorder(),
              isDense: true,
              helperText: widget.questionModel.stream == null
                  ? 'Select a stream first'
                  : 'Available topics for ${widget.questionModel.stream}',
              enabled: widget.questionModel.stream != null,
            ),
            items: availableTopics.map((topic) {
              return DropdownMenuItem(
                value: topic,
                child: Text(topic),
              );
            }).toList(),
            onChanged:
                widget.questionModel.stream != null ? _onTopicChanged : null,
            validator: (value) =>
                value == null ? 'Please select a topic' : null,
          ),
          const SizedBox(height: 12),

          // Level Dropdown (independent)
          DropdownButtonFormField<String>(
            value: widget.questionModel.level,
            decoration: const InputDecoration(
              labelText: 'Difficulty Level *',
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
            validator: (value) =>
                value == null ? 'Please select a level' : null,
          ),
          const SizedBox(height: 12),

          // Subtopic Dropdown (depends on topic)
          DropdownButtonFormField<String>(
            value: widget.questionModel.subtopic,
            decoration: InputDecoration(
              labelText: 'Subtopic *',
              border: const OutlineInputBorder(),
              isDense: true,
              helperText: widget.questionModel.topic == null
                  ? 'Select a topic first'
                  : 'Available subtopics for ${widget.questionModel.topic}',
              enabled: widget.questionModel.topic != null,
            ),
            items: availableSubtopics.map((subtopic) {
              return DropdownMenuItem(
                value: subtopic,
                child: Text(subtopic),
              );
            }).toList(),
            onChanged: widget.questionModel.topic != null
                ? (value) {
                    setState(() {
                      widget.questionModel.subtopic = value;
                    });
                    widget.onMetadataChanged();
                  }
                : null,
            validator: (value) =>
                value == null ? 'Please select a subtopic' : null,
          ),
          const SizedBox(height: 12),

          // Chapter Dropdown (depends on topic)
          DropdownButtonFormField<String>(
            value: widget.questionModel.chapter,
            decoration: InputDecoration(
              labelText: 'Chapter *',
              border: const OutlineInputBorder(),
              isDense: true,
              helperText: widget.questionModel.topic == null
                  ? 'Select a topic first'
                  : 'Available chapters for ${widget.questionModel.topic}',
              enabled: widget.questionModel.topic != null,
            ),
            items: availableChapters.map((chapter) {
              return DropdownMenuItem(
                value: chapter,
                child: Text(chapter),
              );
            }).toList(),
            onChanged: widget.questionModel.topic != null
                ? (value) {
                    setState(() {
                      widget.questionModel.chapter = value;
                    });
                    widget.onMetadataChanged();
                  }
                : null,
            validator: (value) =>
                value == null ? 'Please select a chapter' : null,
          ),
          const SizedBox(height: 12),

          // Language Dropdown (independent)
          DropdownButtonFormField<String>(
            value: widget.questionModel.language,
            decoration: const InputDecoration(
              labelText: 'Language *',
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
            validator: (value) =>
                value == null ? 'Please select a language' : null,
          ),
          const SizedBox(height: 12),

          // Type Dropdown (independent)
          DropdownButtonFormField<String>(
            value: widget.questionModel.type,
            decoration: const InputDecoration(
              labelText: 'Question Type *',
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
            validator: (value) => value == null ? 'Please select a type' : null,
          ),
          const SizedBox(height: 20),

          // Hierarchy Validation Info
          if (widget.questionModel.stream != null &&
              widget.questionModel.topic != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade600, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Hierarchy Information',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Stream: ${widget.questionModel.stream}',
                    style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                  ),
                  Text(
                    'Topic: ${widget.questionModel.topic}',
                    style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                  ),
                  if (availableSubtopics.isNotEmpty)
                    Text(
                      'Available Subtopics: ${availableSubtopics.length}',
                      style:
                          TextStyle(color: Colors.blue.shade700, fontSize: 12),
                    ),
                  if (availableChapters.isNotEmpty)
                    Text(
                      'Available Chapters: ${availableChapters.length}',
                      style:
                          TextStyle(color: Colors.blue.shade700, fontSize: 12),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 12),

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
                        ? 'All metadata fields completed and hierarchy is valid'
                        : 'Please fill all metadata fields following the hierarchy',
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

          const SizedBox(height: 12),

          // Add New Items Section
          if (widget.questionModel.stream != null)
            ExpansionTile(
              title: Text(
                'Manage Metadata',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              children: [
                _buildAddItemSection(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAddItemSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add Topic to Current Stream
          if (widget.questionModel.stream != null)
            _buildQuickAddField(
              'Add Topic to ${widget.questionModel.stream}',
              Icons.subject,
              (value) async {
                await widget.metadataService.addTopicToStream(
                  widget.questionModel.stream!,
                  value,
                );
                _updateAvailableOptions();
                widget.onMetadataChanged();
              },
            ),

          const SizedBox(height: 8),

          // Add Subtopic to Current Topic
          if (widget.questionModel.topic != null)
            _buildQuickAddField(
              'Add Subtopic to ${widget.questionModel.topic}',
              Icons.topic,
              (value) async {
                await widget.metadataService.addSubtopicToTopic(
                  widget.questionModel.topic!,
                  value,
                );
                _updateAvailableOptions();
                widget.onMetadataChanged();
              },
            ),

          const SizedBox(height: 8),

          // Add Chapter to Current Topic
          if (widget.questionModel.topic != null)
            _buildQuickAddField(
              'Add Chapter to ${widget.questionModel.topic}',
              Icons.book,
              (value) async {
                await widget.metadataService.addChapterToTopic(
                  widget.questionModel.topic!,
                  value,
                );
                _updateAvailableOptions();
                widget.onMetadataChanged();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildQuickAddField(
    String label,
    IconData icon,
    Future<void> Function(String) onAdd,
  ) {
    final controller = TextEditingController();

    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 12),
            onSubmitted: (value) async {
              if (value.trim().isNotEmpty) {
                try {
                  await onAdd(value.trim());
                  controller.clear();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added: $value'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error adding item: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () async {
            final value = controller.text.trim();
            if (value.isNotEmpty) {
              try {
                await onAdd(value);
                controller.clear();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added: $value'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error adding item: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }
          },
          icon: const Icon(Icons.add, size: 16),
          tooltip: 'Add',
        ),
      ],
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
    _updateAvailableOptions();
    widget.onMetadataChanged();
  }

  void _fillDefaults() {
    setState(() {
      if (widget.metadataService.streams.isNotEmpty) {
        widget.questionModel.stream = widget.metadataService.streams.first;
        _updateAvailableOptions();

        if (availableTopics.isNotEmpty) {
          widget.questionModel.topic = availableTopics.first;
          _updateAvailableOptions();

          if (availableSubtopics.isNotEmpty) {
            widget.questionModel.subtopic = availableSubtopics.first;
          }
          if (availableChapters.isNotEmpty) {
            widget.questionModel.chapter = availableChapters.first;
          }
        }
      }

      if (widget.metadataService.levels.isNotEmpty) {
        widget.questionModel.level = widget.metadataService.levels.first;
      }
      if (widget.metadataService.languages.isNotEmpty) {
        widget.questionModel.language = widget.metadataService.languages.first;
      }
      if (widget.metadataService.types.isNotEmpty) {
        widget.questionModel.type = widget.metadataService.types.first;
      }
    });
    widget.onMetadataChanged();
  }
}
