import 'package:cloud_firestore/cloud_firestore.dart';

class MetadataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<String> streams = [];
  List<String> levels = [];
  List<String> topics = [];
  List<String> subtopics = [];
  List<String> languages = [];
  List<String> chapters = [];
  List<String> types = [];

  Future<void> loadAllMetadata() async {
    await Future.wait([
      loadStreams(),
      loadLevels(),
      loadTopics(),
      loadSubtopics(),
      loadLanguages(),
      loadChapters(),
      loadTypes(),
    ]);
  }

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

  Future<void> loadTopics() async {
    final snapshot =
        await _firestore.collection('metadata').doc('topics').get();
    if (snapshot.exists && snapshot.data()?['values'] != null) {
      topics = List<String>.from(snapshot.data()!['values']);
    } else {
      topics = ['Physics', 'Chemistry', 'Mathematics', 'Biology'];
      await _firestore
          .collection('metadata')
          .doc('topics')
          .set({'values': topics});
    }
  }

  Future<void> loadSubtopics() async {
    final snapshot =
        await _firestore.collection('metadata').doc('subtopics').get();
    if (snapshot.exists && snapshot.data()?['values'] != null) {
      subtopics = List<String>.from(snapshot.data()!['values']);
    } else {
      subtopics = [
        'Mechanics',
        'Thermodynamics',
        'Electromagnetism',
        'Optics',
        'Modern Physics'
      ];
      await _firestore
          .collection('metadata')
          .doc('subtopics')
          .set({'values': subtopics});
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

  Future<void> loadChapters() async {
    final snapshot =
        await _firestore.collection('metadata').doc('chapters').get();
    if (snapshot.exists && snapshot.data()?['values'] != null) {
      chapters = List<String>.from(snapshot.data()!['values']);
    } else {
      chapters = [
        'Chapter 1',
        'Chapter 2',
        'Chapter 3',
        'Chapter 4',
        'Chapter 5'
      ];
      await _firestore
          .collection('metadata')
          .doc('chapters')
          .set({'values': chapters});
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

  Future<void> addItem(String collection, String value) async {
    switch (collection) {
      case 'streams':
        if (!streams.contains(value)) {
          streams.add(value);
          await _firestore
              .collection('metadata')
              .doc('streams')
              .set({'values': streams});
        }
        break;
      case 'levels':
        if (!levels.contains(value)) {
          levels.add(value);
          await _firestore
              .collection('metadata')
              .doc('levels')
              .set({'values': levels});
        }
        break;
      case 'topics':
        if (!topics.contains(value)) {
          topics.add(value);
          await _firestore
              .collection('metadata')
              .doc('topics')
              .set({'values': topics});
        }
        break;
      case 'subtopics':
        if (!subtopics.contains(value)) {
          subtopics.add(value);
          await _firestore
              .collection('metadata')
              .doc('subtopics')
              .set({'values': subtopics});
        }
        break;
      case 'languages':
        if (!languages.contains(value)) {
          languages.add(value);
          await _firestore
              .collection('metadata')
              .doc('languages')
              .set({'values': languages});
        }
        break;
      case 'chapters':
        if (!chapters.contains(value)) {
          chapters.add(value);
          await _firestore
              .collection('metadata')
              .doc('chapters')
              .set({'values': chapters});
        }
        break;
      case 'types':
        if (!types.contains(value)) {
          types.add(value);
          await _firestore
              .collection('metadata')
              .doc('types')
              .set({'values': types});
        }
        break;
    }
  }

  Future<void> removeItem(String collection, String value) async {
    switch (collection) {
      case 'streams':
        streams.remove(value);
        await _firestore
            .collection('metadata')
            .doc('streams')
            .set({'values': streams});
        break;
      case 'levels':
        levels.remove(value);
        await _firestore
            .collection('metadata')
            .doc('levels')
            .set({'values': levels});
        break;
      case 'topics':
        topics.remove(value);
        await _firestore
            .collection('metadata')
            .doc('topics')
            .set({'values': topics});
        break;
      case 'subtopics':
        subtopics.remove(value);
        await _firestore
            .collection('metadata')
            .doc('subtopics')
            .set({'values': subtopics});
        break;
      case 'languages':
        languages.remove(value);
        await _firestore
            .collection('metadata')
            .doc('languages')
            .set({'values': languages});
        break;
      case 'chapters':
        chapters.remove(value);
        await _firestore
            .collection('metadata')
            .doc('chapters')
            .set({'values': chapters});
        break;
      case 'types':
        types.remove(value);
        await _firestore
            .collection('metadata')
            .doc('types')
            .set({'values': types});
        break;
    }
  }
}
