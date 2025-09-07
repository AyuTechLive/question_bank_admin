import 'package:flutter/material.dart';
import 'package:question_bank/service/metadata_service.dart';

class MetadataManager extends StatefulWidget {
  final VoidCallback onMetadataUpdated;

  const MetadataManager({Key? key, required this.onMetadataUpdated})
      : super(key: key);

  @override
  State<MetadataManager> createState() => _MetadataManagerState();
}

class _MetadataManagerState extends State<MetadataManager>
    with SingleTickerProviderStateMixin {
  final MetadataService _metadataService = MetadataService();
  late TabController _tabController;

  // Controllers for adding new items
  final _newStreamController = TextEditingController();
  final _newTopicController = TextEditingController();
  final _newSubtopicController = TextEditingController();
  final _newChapterController = TextEditingController();
  final _newLevelController = TextEditingController();
  final _newLanguageController = TextEditingController();
  final _newTypeController = TextEditingController();

  // Selected items for hierarchical management
  String? selectedStream;
  String? selectedTopic;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMetadata();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _newStreamController.dispose();
    _newTopicController.dispose();
    _newSubtopicController.dispose();
    _newChapterController.dispose();
    _newLevelController.dispose();
    _newLanguageController.dispose();
    _newTypeController.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    await _metadataService.loadAllMetadata();
    setState(() {
      // Set default selections
      if (_metadataService.streams.isNotEmpty && selectedStream == null) {
        selectedStream = _metadataService.streams.first;
      }
      if (selectedStream != null) {
        final topics = _metadataService.getTopicsForStream(selectedStream);
        if (topics.isNotEmpty && selectedTopic == null) {
          selectedTopic = topics.first;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Metadata Management'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Hierarchical', icon: Icon(Icons.account_tree)),
            Tab(text: 'Independent', icon: Icon(Icons.list)),
            Tab(text: 'Overview', icon: Icon(Icons.analytics)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadMetadata,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHierarchicalTab(),
          _buildIndependentTab(),
          _buildOverviewTab(),
        ],
      ),
    );
  }

  Widget _buildHierarchicalTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Left Panel - Streams and Topics
          Expanded(
            flex: 1,
            child: Card(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      border: Border(
                        bottom: BorderSide(color: Colors.blue.shade200),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.stream, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Streams & Topics',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _buildStreamTopicManager()),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Right Panel - Subtopics and Chapters
          Expanded(
            flex: 1,
            child: Card(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border(
                        bottom: BorderSide(color: Colors.green.shade200),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.topic, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedTopic != null
                                ? 'Subtopics & Chapters for $selectedTopic'
                                : 'Select a Topic',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _buildSubtopicChapterManager()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamTopicManager() {
    return Column(
      children: [
        // Add new stream
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newStreamController,
                  decoration: const InputDecoration(
                    labelText: 'Add New Stream',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addNewStream(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _addNewStream,
                icon: const Icon(Icons.add, color: Colors.blue),
                tooltip: 'Add Stream',
              ),
            ],
          ),
        ),
        // Streams list
        Expanded(
          child: ListView.builder(
            itemCount: _metadataService.streams.length,
            itemBuilder: (context, index) {
              final stream = _metadataService.streams[index];
              final isSelected = selectedStream == stream;
              final topics = _metadataService.getTopicsForStream(stream);

              return ExpansionTile(
                title: Text(
                  stream,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.blue : null,
                  ),
                ),
                subtitle: Text('${topics.length} topics'),
                leading: Radio<String>(
                  value: stream,
                  groupValue: selectedStream,
                  onChanged: (value) {
                    setState(() {
                      selectedStream = value;
                      selectedTopic = null;
                    });
                  },
                ),
                trailing: IconButton(
                  onPressed: () => _removeStream(stream),
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                ),
                children: [
                  // Add topic to stream
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Add Topic',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSubmitted: (value) =>
                                _addTopicToStream(stream, value),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _showAddTopicDialog(stream),
                          icon: const Icon(Icons.add, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                  // Topics list
                  ...topics.map((topic) => ListTile(
                        contentPadding:
                            const EdgeInsets.only(left: 32, right: 16),
                        title: Text(topic),
                        leading: Radio<String>(
                          value: topic,
                          groupValue: selectedTopic,
                          onChanged: (value) {
                            setState(() {
                              selectedTopic = value;
                            });
                          },
                        ),
                        trailing: IconButton(
                          onPressed: () =>
                              _removeTopicFromStream(stream, topic),
                          icon: const Icon(Icons.remove_circle,
                              color: Colors.red, size: 18),
                        ),
                        dense: true,
                      )),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubtopicChapterManager() {
    if (selectedTopic == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.topic, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Select a topic to manage\nsubtopics and chapters',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final subtopics = _metadataService.getSubtopicsForTopic(selectedTopic!);
    final chapters = _metadataService.getChaptersForTopic(selectedTopic!);

    return Column(
      children: [
        // Subtopics Section
        Expanded(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.category, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Subtopics (${subtopics.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              // Add subtopic
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Add Subtopic',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (value) =>
                            _addSubtopicToTopic(selectedTopic!, value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _showAddSubtopicDialog(selectedTopic!),
                      icon: const Icon(Icons.add, color: Colors.green),
                    ),
                  ],
                ),
              ),
              // Subtopics list
              Expanded(
                child: ListView.builder(
                  itemCount: subtopics.length,
                  itemBuilder: (context, index) {
                    final subtopic = subtopics[index];
                    return ListTile(
                      title: Text(subtopic),
                      trailing: IconButton(
                        onPressed: () =>
                            _removeSubtopicFromTopic(selectedTopic!, subtopic),
                        icon: const Icon(Icons.delete,
                            color: Colors.red, size: 18),
                      ),
                      dense: true,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        // Chapters Section
        Expanded(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.book, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Chapters (${chapters.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              // Add chapter
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Add Chapter',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (value) =>
                            _addChapterToTopic(selectedTopic!, value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _showAddChapterDialog(selectedTopic!),
                      icon: const Icon(Icons.add, color: Colors.orange),
                    ),
                  ],
                ),
              ),
              // Chapters list
              Expanded(
                child: ListView.builder(
                  itemCount: chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = chapters[index];
                    return ListTile(
                      title: Text(chapter),
                      trailing: IconButton(
                        onPressed: () =>
                            _removeChapterFromTopic(selectedTopic!, chapter),
                        icon: const Icon(Icons.delete,
                            color: Colors.red, size: 18),
                      ),
                      dense: true,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIndependentTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Levels and Languages
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildMetadataSection(
                    'Difficulty Levels',
                    _metadataService.levels,
                    _newLevelController,
                    _addLevel,
                    _removeLevel,
                    Icons.trending_up,
                    Colors.blue,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _buildMetadataSection(
                    'Languages',
                    _metadataService.languages,
                    _newLanguageController,
                    _addLanguage,
                    _removeLanguage,
                    Icons.language,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Question Types
          Expanded(
            child: _buildMetadataSection(
              'Question Types',
              _metadataService.types,
              _newTypeController,
              _addType,
              _removeType,
              Icons.quiz,
              Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Statistics Cards
          Row(
            children: [
              _buildStatCard('Streams', _metadataService.streams.length,
                  Icons.stream, Colors.blue),
              const SizedBox(width: 16),
              _buildStatCard('Topics', _metadataService.topics.length,
                  Icons.subject, Colors.green),
              const SizedBox(width: 16),
              _buildStatCard('Subtopics', _metadataService.subtopics.length,
                  Icons.topic, Colors.orange),
              const SizedBox(width: 16),
              _buildStatCard('Chapters', _metadataService.chapters.length,
                  Icons.book, Colors.purple),
            ],
          ),
          const SizedBox(height: 24),

          // Additional Stats
          Row(
            children: [
              _buildStatCard('Levels', _metadataService.levels.length,
                  Icons.trending_up, Colors.teal),
              const SizedBox(width: 16),
              _buildStatCard('Languages', _metadataService.languages.length,
                  Icons.language, Colors.indigo),
              const SizedBox(width: 16),
              _buildStatCard('Types', _metadataService.types.length, Icons.quiz,
                  Colors.red),
              const SizedBox(width: 16),
              // Empty card for balance
              Expanded(child: Container()),
            ],
          ),
          const SizedBox(height: 24),

          // Hierarchy Breakdown
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hierarchy Breakdown',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _metadataService.streams.length,
                        itemBuilder: (context, index) {
                          final stream = _metadataService.streams[index];
                          final topics =
                              _metadataService.getTopicsForStream(stream);

                          return ExpansionTile(
                            title: Text('$stream (${topics.length} topics)'),
                            leading:
                                Icon(Icons.stream, color: Colors.blue.shade600),
                            children: topics.map((topic) {
                              final subtopics =
                                  _metadataService.getSubtopicsForTopic(topic);
                              final chapters =
                                  _metadataService.getChaptersForTopic(topic);

                              return ExpansionTile(
                                title: Text(topic),
                                subtitle: Text(
                                    '${subtopics.length} subtopics, ${chapters.length} chapters'),
                                leading: Icon(Icons.subject,
                                    color: Colors.green.shade600),
                                // contentPadding: const EdgeInsets.only(left: 32),
                                children: [
                                  if (subtopics.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(left: 48),
                                      child: ListTile(
                                        title: Text(
                                          'Subtopics: ${subtopics.join(", ")}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        leading: Icon(Icons.category,
                                            size: 16,
                                            color: Colors.orange.shade600),
                                        dense: true,
                                      ),
                                    ),
                                  ],
                                  if (chapters.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(left: 48),
                                      child: ListTile(
                                        title: Text(
                                          'Chapters: ${chapters.length} items',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        leading: Icon(Icons.book,
                                            size: 16,
                                            color: Colors.purple.shade600),
                                        dense: true,
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 4,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 12),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataSection(
    String title,
    List<String> items,
    TextEditingController controller,
    VoidCallback onAdd,
    Function(String) onRemove,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              border: Border(bottom: BorderSide(color: color.withOpacity(0.3))),
            ),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${items.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Add new ${title.toLowerCase()}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(icon, size: 20),
                    ),
                    onSubmitted: (_) => onAdd(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'No ${title.toLowerCase()} added yet',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        title: Text(item),
                        leading: Icon(icon, size: 20, color: color),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => onRemove(item),
                          tooltip: 'Remove $item',
                        ),
                        dense: true,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Action methods
  Future<void> _addNewStream() async {
    final value = _newStreamController.text.trim();
    if (value.isNotEmpty) {
      try {
        await _metadataService.addStream(value);
        _newStreamController.clear();
        setState(() {});
        widget.onMetadataUpdated();
        _showSuccessSnackBar('Stream "$value" added successfully');
      } catch (e) {
        _showErrorSnackBar('Failed to add stream: $e');
      }
    }
  }

  Future<void> _addTopicToStream(String stream, String topic) async {
    if (topic.trim().isNotEmpty) {
      try {
        await _metadataService.addTopicToStream(stream, topic.trim());
        setState(() {});
        widget.onMetadataUpdated();
        _showSuccessSnackBar('Topic "$topic" added to "$stream"');
      } catch (e) {
        _showErrorSnackBar('Failed to add topic: $e');
      }
    }
  }

  Future<void> _addSubtopicToTopic(String topic, String subtopic) async {
    if (subtopic.trim().isNotEmpty) {
      try {
        await _metadataService.addSubtopicToTopic(topic, subtopic.trim());
        setState(() {});
        widget.onMetadataUpdated();
        _showSuccessSnackBar('Subtopic "$subtopic" added to "$topic"');
      } catch (e) {
        _showErrorSnackBar('Failed to add subtopic: $e');
      }
    }
  }

  Future<void> _addChapterToTopic(String topic, String chapter) async {
    if (chapter.trim().isNotEmpty) {
      try {
        await _metadataService.addChapterToTopic(topic, chapter.trim());
        setState(() {});
        widget.onMetadataUpdated();
        _showSuccessSnackBar('Chapter "$chapter" added to "$topic"');
      } catch (e) {
        _showErrorSnackBar('Failed to add chapter: $e');
      }
    }
  }

  Future<void> _addLevel() async {
    final value = _newLevelController.text.trim();
    if (value.isNotEmpty) {
      try {
        await _metadataService.addLevel(value);
        _newLevelController.clear();
        setState(() {});
        widget.onMetadataUpdated();
        _showSuccessSnackBar('Level "$value" added successfully');
      } catch (e) {
        _showErrorSnackBar('Failed to add level: $e');
      }
    }
  }

  Future<void> _addLanguage() async {
    final value = _newLanguageController.text.trim();
    if (value.isNotEmpty) {
      try {
        await _metadataService.addLanguage(value);
        _newLanguageController.clear();
        setState(() {});
        widget.onMetadataUpdated();
        _showSuccessSnackBar('Language "$value" added successfully');
      } catch (e) {
        _showErrorSnackBar('Failed to add language: $e');
      }
    }
  }

  Future<void> _addType() async {
    final value = _newTypeController.text.trim();
    if (value.isNotEmpty) {
      try {
        await _metadataService.addType(value);
        _newTypeController.clear();
        setState(() {});
        widget.onMetadataUpdated();
        _showSuccessSnackBar('Question type "$value" added successfully');
      } catch (e) {
        _showErrorSnackBar('Failed to add question type: $e');
      }
    }
  }

  // Remove methods
  Future<void> _removeStream(String stream) async {
    final confirm = await _showConfirmDialog(
      'Remove Stream',
      'Remove "$stream" and all its topics?\n\nThis will also remove all associated subtopics and chapters.',
    );
    if (confirm == true) {
      try {
        await _metadataService.removeStream(stream);
        if (selectedStream == stream) {
          selectedStream = null;
          selectedTopic = null;
        }
        setState(() {});
        widget.onMetadataUpdated();
        _showSuccessSnackBar('Stream "$stream" removed successfully');
      } catch (e) {
        _showErrorSnackBar('Failed to remove stream: $e');
      }
    }
  }

  Future<void> _removeTopicFromStream(String stream, String topic) async {
    final confirm = await _showConfirmDialog(
      'Remove Topic',
      'Remove "$topic" from "$stream"?\n\nThis will also remove all associated subtopics and chapters.',
    );
    if (confirm == true) {
      try {
        await _metadataService.removeTopicFromStream(stream, topic);
        if (selectedTopic == topic) {
          selectedTopic = null;
        }
        setState(() {});
        widget.onMetadataUpdated();
        _showSuccessSnackBar('Topic "$topic" removed from "$stream"');
      } catch (e) {
        _showErrorSnackBar('Failed to remove topic: $e');
      }
    }
  }

  Future<void> _removeSubtopicFromTopic(String topic, String subtopic) async {
    final confirm = await _showConfirmDialog(
        'Remove Subtopic', 'Remove "$subtopic" from "$topic"?');
    if (confirm == true) {
      try {
        await _metadataService.removeSubtopicFromTopic(topic, subtopic);
        setState(() {});
        widget.onMetadataUpdated();
        _showSuccessSnackBar('Subtopic "$subtopic" removed from "$topic"');
      } catch (e) {
        _showErrorSnackBar('Failed to remove subtopic: $e');
      }
    }
  }

  Future<void> _removeChapterFromTopic(String topic, String chapter) async {
    final confirm = await _showConfirmDialog(
        'Remove Chapter', 'Remove "$chapter" from "$topic"?');
    if (confirm == true) {
      try {
        await _metadataService.removeChapterFromTopic(topic, chapter);
        setState(() {});
        widget.onMetadataUpdated();
        _showSuccessSnackBar('Chapter "$chapter" removed from "$topic"');
      } catch (e) {
        _showErrorSnackBar('Failed to remove chapter: $e');
      }
    }
  }

  Future<void> _removeLevel(String level) async {
    final confirm = await _showConfirmDialog(
        'Remove Level', 'Remove difficulty level "$level"?');
    if (confirm == true) {
      try {
        await _metadataService.removeLevel(level);
        setState(() {});
        widget.onMetadataUpdated();
        _showSuccessSnackBar('Level "$level" removed successfully');
      } catch (e) {
        _showErrorSnackBar('Failed to remove level: $e');
      }
    }
  }

  Future<void> _removeLanguage(String language) async {
    final confirm = await _showConfirmDialog(
        'Remove Language', 'Remove language "$language"?');
    if (confirm == true) {
      try {
        await _metadataService.removeLanguage(language);
        setState(() {});
        widget.onMetadataUpdated();
        _showSuccessSnackBar('Language "$language" removed successfully');
      } catch (e) {
        _showErrorSnackBar('Failed to remove language: $e');
      }
    }
  }

  Future<void> _removeType(String type) async {
    final confirm = await _showConfirmDialog(
        'Remove Type', 'Remove question type "$type"?');
    if (confirm == true) {
      try {
        await _metadataService.removeType(type);
        setState(() {});
        widget.onMetadataUpdated();
        _showSuccessSnackBar('Question type "$type" removed successfully');
      } catch (e) {
        _showErrorSnackBar('Failed to remove question type: $e');
      }
    }
  }

  // Dialog methods
  Future<void> _showAddTopicDialog(String stream) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text('Add Topic to $stream'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Topic Name',
                border: OutlineInputBorder(),
                hintText: 'Enter topic name (e.g., Physics, Chemistry)',
              ),
              autofocus: true,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.pop(context, value.trim());
                }
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade600, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Topics will have their own subtopics and chapters',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(context, value);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Add Topic'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _addTopicToStream(stream, result);
    }
  }

  Future<void> _showAddSubtopicDialog(String topic) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add_circle, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(child: Text('Add Subtopic to $topic')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Subtopic Name',
                border: OutlineInputBorder(),
                hintText: 'Enter subtopic name (e.g., Mechanics, Optics)',
              ),
              autofocus: true,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.pop(context, value.trim());
                }
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.orange.shade600, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Subtopics help organize questions within $topic',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(context, value);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Add Subtopic'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _addSubtopicToTopic(topic, result);
    }
  }

  Future<void> _showAddChapterDialog(String topic) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add_circle, color: Colors.purple),
            const SizedBox(width: 8),
            Expanded(child: Text('Add Chapter to $topic')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Chapter Name',
                border: OutlineInputBorder(),
                hintText: 'Enter chapter name (e.g., Chapter 1: Motion)',
              ),
              autofocus: true,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.pop(context, value.trim());
                }
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.purple.shade600, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Chapters help organize questions by syllabus structure',
                      style: TextStyle(
                        color: Colors.purple.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(context, value);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('Add Chapter'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _addChapterToTopic(topic, result);
    }
  }

  Future<bool?> _showConfirmDialog(String title, String message) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  // Utility methods for showing messages
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
