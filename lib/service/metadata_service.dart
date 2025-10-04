import 'package:cloud_firestore/cloud_firestore.dart';

class MetadataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Base metadata
  List<String> streams = [];
  List<String> levels = [];
  List<String> languages = [];
  List<String> types = [];
  List<String> tags = []; // New independent tags list

  // Hierarchical metadata maps
  Map<String, List<String>> streamTopics = {}; // stream -> topics
  Map<String, List<String>> topicSubtopics = {}; // topic -> subtopics
  Map<String, List<String>> topicChapters = {}; // topic -> chapters

  Future<void> loadAllMetadata() async {
    await Future.wait([
      loadStreams(),
      loadLevels(),
      loadLanguages(),
      loadTypes(),
      loadTags(), // Load tags
      loadStreamTopics(),
      loadTopicSubtopics(),
      loadTopicChapters(),
    ]);
  }

  // Load basic metadata
  Future<void> loadStreams() async {
    final snapshot =
        await _firestore.collection('metadata').doc('streams').get();
    if (snapshot.exists && snapshot.data()?['values'] != null) {
      streams = List<String>.from(snapshot.data()!['values']);
    } else {
      streams = ['JEE Main', 'NEET', 'JEE Advanced'];
      await _firestore
          .collection('metadata')
          .doc('streams')
          .set({'values': streams});
    }
  }

  Future<void> loadLevels() async {
    final snapshot =
        await _firestore.collection('metadata').doc('levels').get();
    if (snapshot.exists && snapshot.data()?['values'] != null) {
      levels = List<String>.from(snapshot.data()!['values']);
    } else {
      levels = ['Easy', 'Medium', 'Hard'];
      await _firestore
          .collection('metadata')
          .doc('levels')
          .set({'values': levels});
    }
  }

  Future<void> loadLanguages() async {
    final snapshot =
        await _firestore.collection('metadata').doc('languages').get();
    if (snapshot.exists && snapshot.data()?['values'] != null) {
      languages = List<String>.from(snapshot.data()!['values']);
    } else {
      languages = ['English', 'Hindi'];
      await _firestore
          .collection('metadata')
          .doc('languages')
          .set({'values': languages});
    }
  }

  Future<void> loadTypes() async {
    final snapshot = await _firestore.collection('metadata').doc('types').get();
    if (snapshot.exists && snapshot.data()?['values'] != null) {
      types = List<String>.from(snapshot.data()!['values']);
    } else {
      types = [
        'Single Correct MCQ',
        'Multiple Correct MCQ',
        'Numerical',
        'Matrix Match'
      ];
      await _firestore
          .collection('metadata')
          .doc('types')
          .set({'values': types});
    }
  }

  // Load tags
  Future<void> loadTags() async {
    final snapshot = await _firestore.collection('metadata').doc('tags').get();
    if (snapshot.exists && snapshot.data()?['values'] != null) {
      tags = List<String>.from(snapshot.data()!['values']);
    } else {
      tags = [
        'JEE 2024',
        'JEE 2025',
        'JEE 2026',
        'NEET 2024',
        'NEET 2025',
        'NEET 2026',
        'Previous Year',
        'Practice',
        'Mock Test',
        'Important',
        'Revision',
        'Difficult',
        'Quick Review',
        'Formula Based',
        'Conceptual',
        'Application Based',
        'Theory',
        'Numerical Problem'
      ];
      await _firestore.collection('metadata').doc('tags').set({'values': tags});
    }
  }

  // Load hierarchical metadata
  Future<void> loadStreamTopics() async {
    final snapshot =
        await _firestore.collection('metadata').doc('stream_topics').get();
    if (snapshot.exists && snapshot.data() != null) {
      final data = snapshot.data()!;
      streamTopics = {};
      for (String stream in data.keys) {
        streamTopics[stream] = List<String>.from(data[stream] ?? []);
      }
    } else {
      // Initialize with default data
      streamTopics = {
        'JEE Main': ['Physics', 'Chemistry', 'Mathematics'],
        'NEET': ['Physics', 'Chemistry', 'Biology', 'Botany', 'Zoology'],
        'JEE Advanced': ['Physics', 'Chemistry', 'Mathematics'],
      };
      await _firestore
          .collection('metadata')
          .doc('stream_topics')
          .set(streamTopics);
    }
  }

  Future<void> loadTopicSubtopics() async {
    final snapshot =
        await _firestore.collection('metadata').doc('topic_subtopics').get();
    if (snapshot.exists && snapshot.data() != null) {
      final data = snapshot.data()!;
      topicSubtopics = {};

      for (String topic in data.keys) {
        topicSubtopics[topic] = List<String>.from(data[topic] ?? []);
      }
    } else {
      // Initialize with default data
      topicSubtopics = {
        'Physics': [
          'Mechanics',
          'Thermodynamics',
          'Electromagnetism',
          'Optics',
          'Modern Physics',
          'Waves',
          'Oscillations'
        ],
        'Chemistry': [
          'Physical Chemistry',
          'Organic Chemistry',
          'Inorganic Chemistry',
          'Environmental Chemistry',
          'Nuclear Chemistry'
        ],
        'Mathematics': [
          'Algebra',
          'Calculus',
          'Coordinate Geometry',
          'Trigonometry',
          'Statistics',
          'Probability',
          'Vector Algebra'
        ],
        'Biology': [
          'Cell Biology',
          'Genetics',
          'Evolution',
          'Ecology',
          'Human Physiology',
          'Plant Physiology'
        ],
        'Botany': [
          'Plant Anatomy',
          'Plant Physiology',
          'Plant Taxonomy',
          'Plant Reproduction',
          'Plant Ecology'
        ],
        'Zoology': [
          'Animal Anatomy',
          'Animal Physiology',
          'Animal Behavior',
          'Animal Classification',
          'Animal Reproduction'
        ]
      };
      await _firestore
          .collection('metadata')
          .doc('topic_subtopics')
          .set(topicSubtopics);
    }
  }

  Future<void> loadTopicChapters() async {
    final snapshot =
        await _firestore.collection('metadata').doc('topic_chapters').get();
    if (snapshot.exists && snapshot.data() != null) {
      final data = snapshot.data()!;
      topicChapters = {};
      for (String topic in data.keys) {
        topicChapters[topic] = List<String>.from(data[topic] ?? []);
      }
    } else {
      // Initialize with default data
      topicChapters = {
        'Physics': [
          'Chapter 1: Units and Measurements',
          'Chapter 2: Motion in Straight Line',
          'Chapter 3: Motion in Plane',
          'Chapter 4: Laws of Motion',
          'Chapter 5: Work Energy Power',
          'Chapter 6: System of Particles',
          'Chapter 7: Rotational Motion',
          'Chapter 8: Gravitation',
          'Chapter 9: Mechanical Properties',
          'Chapter 10: Thermal Properties'
        ],
        'Chemistry': [
          'Chapter 1: Some Basic Concepts',
          'Chapter 2: Structure of Atom',
          'Chapter 3: Classification of Elements',
          'Chapter 4: Chemical Bonding',
          'Chapter 5: States of Matter',
          'Chapter 6: Thermodynamics',
          'Chapter 7: Equilibrium',
          'Chapter 8: Redox Reactions',
          'Chapter 9: Hydrogen',
          'Chapter 10: S-Block Elements'
        ],
        'Mathematics': [
          'Chapter 1: Sets',
          'Chapter 2: Relations and Functions',
          'Chapter 3: Trigonometric Functions',
          'Chapter 4: Complex Numbers',
          'Chapter 5: Linear Inequalities',
          'Chapter 6: Permutations and Combinations',
          'Chapter 7: Binomial Theorem',
          'Chapter 8: Sequences and Series',
          'Chapter 9: Straight Lines',
          'Chapter 10: Conic Sections'
        ],
        'Biology': [
          'Chapter 1: The Living World',
          'Chapter 2: Biological Classification',
          'Chapter 3: Plant Kingdom',
          'Chapter 4: Animal Kingdom',
          'Chapter 5: Morphology of Plants',
          'Chapter 6: Anatomy of Plants',
          'Chapter 7: Structural Organisation in Animals',
          'Chapter 8: Cell - Unit of Life',
          'Chapter 9: Biomolecules',
          'Chapter 10: Cell Cycle and Division'
        ],
        'Botany': [
          'Chapter 1: Plant Diversity',
          'Chapter 2: Plant Anatomy',
          'Chapter 3: Plant Physiology',
          'Chapter 4: Plant Reproduction',
          'Chapter 5: Plant Genetics'
        ],
        'Zoology': [
          'Chapter 1: Animal Diversity',
          'Chapter 2: Animal Anatomy',
          'Chapter 3: Animal Physiology',
          'Chapter 4: Animal Reproduction',
          'Chapter 5: Animal Genetics'
        ]
      };
      await _firestore
          .collection('metadata')
          .doc('topic_chapters')
          .set(topicChapters);
    }
  }

  // Get filtered data based on hierarchy
  List<String> getTopicsForStream(String? stream) {
    if (stream == null || stream.isEmpty) return [];
    return streamTopics[stream] ?? [];
  }

  List<String> getSubtopicsForTopic(String? topic) {
    if (topic == null || topic.isEmpty) return [];
    return topicSubtopics[topic] ?? [];
  }

  List<String> getChaptersForTopic(String? topic) {
    if (topic == null || topic.isEmpty) return [];
    return topicChapters[topic] ?? [];
  }

  // Get all topics/subtopics/chapters (for backward compatibility)
  List<String> get topics {
    Set<String> allTopics = {};
    for (List<String> topicList in streamTopics.values) {
      allTopics.addAll(topicList);
    }
    return allTopics.toList()..sort();
  }

  List<String> get subtopics {
    Set<String> allSubtopics = {};
    for (List<String> subtopicList in topicSubtopics.values) {
      allSubtopics.addAll(subtopicList);
    }
    return allSubtopics.toList()..sort();
  }

  List<String> get chapters {
    Set<String> allChapters = {};
    for (List<String> chapterList in topicChapters.values) {
      allChapters.addAll(chapterList);
    }
    return allChapters.toList()..sort();
  }

  // Tag management methods
  Future<void> addTag(String value) async {
    if (!tags.contains(value)) {
      tags.add(value);
      tags.sort(); // Keep tags sorted
      await _firestore.collection('metadata').doc('tags').set({'values': tags});
    }
  }

  Future<void> removeTag(String value) async {
    tags.remove(value);
    await _firestore.collection('metadata').doc('tags').set({'values': tags});
  }

  Future<void> reorderTags(List<String> newOrder) async {
    tags = newOrder;
    await _firestore.collection('metadata').doc('tags').set({'values': tags});
  }

  // Get popular tags (tags that are used most frequently in questions)
  Future<List<String>> getPopularTags({int limit = 10}) async {
    try {
      // This would require implementing tag usage tracking in your questions
      // For now, return the first few tags as "popular"
      return tags.take(limit).toList();
    } catch (e) {
      return tags.take(5).toList(); // Fallback
    }
  }

  // Search tags with filtering
  List<String> searchTags(String query) {
    if (query.isEmpty) return tags;

    final lowerQuery = query.toLowerCase();
    return tags.where((tag) => tag.toLowerCase().contains(lowerQuery)).toList();
  }

  // Get suggested tags based on current metadata
  List<String> getSuggestedTags({
    String? stream,
    String? level,
    String? topic,
  }) {
    List<String> suggestions = [];

    // Add stream-based suggestions
    if (stream != null) {
      suggestions.addAll(tags
          .where((tag) => tag.toLowerCase().contains(stream.toLowerCase())));
    }

    // Add level-based suggestions
    if (level != null) {
      if (level.toLowerCase() == 'hard') {
        suggestions.addAll(['Difficult', 'Conceptual', 'Application Based']);
      } else if (level.toLowerCase() == 'easy') {
        suggestions.addAll(['Quick Review', 'Formula Based', 'Theory']);
      }
    }

    // Add topic-based suggestions
    if (topic != null) {
      if (topic.toLowerCase().contains('math')) {
        suggestions.addAll(['Numerical Problem', 'Formula Based']);
      } else if (topic.toLowerCase().contains('physics')) {
        suggestions
            .addAll(['Conceptual', 'Application Based', 'Formula Based']);
      }
    }

    // Remove duplicates and ensure they exist in our tags list
    return suggestions.toSet().where((tag) => tags.contains(tag)).toList();
  }

  // Add new items (existing methods)
  Future<void> addStream(String value) async {
    if (!streams.contains(value)) {
      streams.add(value);
      await _firestore
          .collection('metadata')
          .doc('streams')
          .set({'values': streams});

      // Initialize empty topics list for new stream
      streamTopics[value] = [];
      await _firestore
          .collection('metadata')
          .doc('stream_topics')
          .set(streamTopics);
    }
  }

  Future<void> addTopicToStream(String stream, String topic) async {
    if (streamTopics[stream] == null) {
      streamTopics[stream] = [];
    }
    if (!streamTopics[stream]!.contains(topic)) {
      streamTopics[stream]!.add(topic);
      await _firestore
          .collection('metadata')
          .doc('stream_topics')
          .set(streamTopics);

      // Initialize empty subtopics and chapters lists for new topic
      if (topicSubtopics[topic] == null) {
        topicSubtopics[topic] = [];
        await _firestore
            .collection('metadata')
            .doc('topic_subtopics')
            .set(topicSubtopics);
      }
      if (topicChapters[topic] == null) {
        topicChapters[topic] = [];
        await _firestore
            .collection('metadata')
            .doc('topic_chapters')
            .set(topicChapters);
      }
    }
  }

  Future<void> addSubtopicToTopic(String topic, String subtopic) async {
    if (topicSubtopics[topic] == null) {
      topicSubtopics[topic] = [];
    }
    if (!topicSubtopics[topic]!.contains(subtopic)) {
      topicSubtopics[topic]!.add(subtopic);
      await _firestore
          .collection('metadata')
          .doc('topic_subtopics')
          .set(topicSubtopics);
    }
  }

  Future<void> addChapterToTopic(String topic, String chapter) async {
    if (topicChapters[topic] == null) {
      topicChapters[topic] = [];
    }
    if (!topicChapters[topic]!.contains(chapter)) {
      topicChapters[topic]!.add(chapter);
      await _firestore
          .collection('metadata')
          .doc('topic_chapters')
          .set(topicChapters);
    }
  }

  Future<void> addLevel(String value) async {
    if (!levels.contains(value)) {
      levels.add(value);
      await _firestore
          .collection('metadata')
          .doc('levels')
          .set({'values': levels});
    }
  }

  Future<void> addLanguage(String value) async {
    if (!languages.contains(value)) {
      languages.add(value);
      await _firestore
          .collection('metadata')
          .doc('languages')
          .set({'values': languages});
    }
  }

  Future<void> addType(String value) async {
    if (!types.contains(value)) {
      types.add(value);
      await _firestore
          .collection('metadata')
          .doc('types')
          .set({'values': types});
    }
  }

  // Remove items (existing methods)
  Future<void> removeStream(String value) async {
    streams.remove(value);
    await _firestore
        .collection('metadata')
        .doc('streams')
        .set({'values': streams});

    // Remove associated topics
    streamTopics.remove(value);
    await _firestore
        .collection('metadata')
        .doc('stream_topics')
        .set(streamTopics);
  }

  Future<void> removeTopicFromStream(String stream, String topic) async {
    if (streamTopics[stream] != null) {
      streamTopics[stream]!.remove(topic);
      await _firestore
          .collection('metadata')
          .doc('stream_topics')
          .set(streamTopics);

      // Check if topic is used in other streams
      bool topicUsedElsewhere = false;
      for (String otherStream in streamTopics.keys) {
        if (otherStream != stream &&
            streamTopics[otherStream]!.contains(topic)) {
          topicUsedElsewhere = true;
          break;
        }
      }

      // If topic is not used anywhere else, remove its subtopics and chapters
      if (!topicUsedElsewhere) {
        topicSubtopics.remove(topic);
        topicChapters.remove(topic);
        await _firestore
            .collection('metadata')
            .doc('topic_subtopics')
            .set(topicSubtopics);
        await _firestore
            .collection('metadata')
            .doc('topic_chapters')
            .set(topicChapters);
      }
    }
  }

  Future<void> removeSubtopicFromTopic(String topic, String subtopic) async {
    if (topicSubtopics[topic] != null) {
      topicSubtopics[topic]!.remove(subtopic);
      await _firestore
          .collection('metadata')
          .doc('topic_subtopics')
          .set(topicSubtopics);
    }
  }

  Future<void> removeChapterFromTopic(String topic, String chapter) async {
    if (topicChapters[topic] != null) {
      topicChapters[topic]!.remove(chapter);
      await _firestore
          .collection('metadata')
          .doc('topic_chapters')
          .set(topicChapters);
    }
  }

  Future<void> removeLevel(String value) async {
    levels.remove(value);
    await _firestore
        .collection('metadata')
        .doc('levels')
        .set({'values': levels});
  }

  Future<void> removeLanguage(String value) async {
    languages.remove(value);
    await _firestore
        .collection('metadata')
        .doc('languages')
        .set({'values': languages});
  }

  Future<void> removeType(String value) async {
    types.remove(value);
    await _firestore.collection('metadata').doc('types').set({'values': types});
  }

  // Legacy add/remove methods for backward compatibility
  Future<void> addItem(String collection, String value) async {
    switch (collection) {
      case 'streams':
        await addStream(value);
        break;
      case 'levels':
        await addLevel(value);
        break;
      case 'languages':
        await addLanguage(value);
        break;
      case 'types':
        await addType(value);
        break;
      case 'tags':
        await addTag(value);
        break;
    }
  }

  Future<void> removeItem(String collection, String value) async {
    switch (collection) {
      case 'streams':
        await removeStream(value);
        break;
      case 'levels':
        await removeLevel(value);
        break;
      case 'languages':
        await removeLanguage(value);
        break;
      case 'types':
        await removeType(value);
        break;
      case 'tags':
        await removeTag(value);
        break;
    }
  }

  // Get hierarchy validation
  bool isValidHierarchy(
      String? stream, String? topic, String? subtopic, String? chapter) {
    if (stream == null || topic == null) return false;

    // Check if topic belongs to stream
    final streamTopicList = getTopicsForStream(stream);
    if (!streamTopicList.contains(topic)) return false;

    // Check if subtopic belongs to topic (if subtopic is provided)
    if (subtopic != null) {
      final topicSubtopicList = getSubtopicsForTopic(topic);
      if (!topicSubtopicList.contains(subtopic)) return false;
    }

    // Check if chapter belongs to topic (if chapter is provided)
    if (chapter != null) {
      final topicChapterList = getChaptersForTopic(topic);
      if (!topicChapterList.contains(chapter)) return false;
    }

    return true;
  }

  // Get suggested values based on current selection
  Map<String, List<String>> getSuggestedValues(
      String? selectedStream, String? selectedTopic) {
    return {
      'topics':
          selectedStream != null ? getTopicsForStream(selectedStream) : [],
      'subtopics':
          selectedTopic != null ? getSubtopicsForTopic(selectedTopic) : [],
      'chapters':
          selectedTopic != null ? getChaptersForTopic(selectedTopic) : [],
      'tags': tags, // All available tags
    };
  }
}
