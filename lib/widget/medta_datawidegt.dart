import 'package:flutter/material.dart';
import 'package:question_bank/service/metadata_service.dart';

class MetadataManager extends StatefulWidget {
  final VoidCallback onMetadataUpdated;

  const MetadataManager({Key? key, required this.onMetadataUpdated})
      : super(key: key);

  @override
  State<MetadataManager> createState() => _MetadataManagerState();
}

class _MetadataManagerState extends State<MetadataManager> {
  final MetadataService _metadataService = MetadataService();
  final TextEditingController _newItemController = TextEditingController();

  String selectedCategory = 'streams';

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    await _metadataService.loadAllMetadata();
    setState(() {});
  }

  List<String> _getCurrentList() {
    switch (selectedCategory) {
      case 'streams':
        return _metadataService.streams;
      case 'levels':
        return _metadataService.levels;
      case 'topics':
        return _metadataService.topics;
      case 'subtopics':
        return _metadataService.subtopics;
      case 'languages':
        return _metadataService.languages;
      case 'chapters':
        return _metadataService.chapters;
      case 'types':
        return _metadataService.types;
      default:
        return [];
    }
  }

  Future<void> _addItem() async {
    if (_newItemController.text.isNotEmpty) {
      await _metadataService.addItem(selectedCategory, _newItemController.text);
      _newItemController.clear();
      setState(() {});
      widget.onMetadataUpdated();
    }
  }

  Future<void> _removeItem(String item) async {
    await _metadataService.removeItem(selectedCategory, item);
    setState(() {});
    widget.onMetadataUpdated();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Metadata'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Category Selector
            DropdownButton<String>(
              value: selectedCategory,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'streams', child: Text('Streams')),
                DropdownMenuItem(value: 'levels', child: Text('Levels')),
                DropdownMenuItem(value: 'topics', child: Text('Topics')),
                DropdownMenuItem(value: 'subtopics', child: Text('Subtopics')),
                DropdownMenuItem(value: 'languages', child: Text('Languages')),
                DropdownMenuItem(value: 'chapters', child: Text('Chapters')),
                DropdownMenuItem(value: 'types', child: Text('Types')),
              ],
              onChanged: (value) {
                setState(() {
                  selectedCategory = value!;
                });
              },
            ),
            const SizedBox(height: 20),

            // Add New Item
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newItemController,
                    decoration: InputDecoration(
                      labelText:
                          'Add new ${selectedCategory.substring(0, selectedCategory.length - 1)}',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _addItem,
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // List of Items
            Expanded(
              child: Card(
                child: ListView.builder(
                  itemCount: _getCurrentList().length,
                  itemBuilder: (context, index) {
                    final item = _getCurrentList()[index];
                    return ListTile(
                      title: Text(item),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeItem(item),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _newItemController.dispose();
    super.dispose();
  }
}
