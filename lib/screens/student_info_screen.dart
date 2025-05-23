import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:image_picker/image_picker.dart'; // For picking images
import 'package:share_plus/share_plus.dart'; // For sharing files
import 'dart:io'; // For working with File objects
import 'lesson_edit_screen.dart'; // Import the EditLessons screen
import 'student_screen.dart';

// Define a model for the Lesson
class Lesson {
  int? id;
  int studentId;
  String dayOfWeek;
  int startTime;
  int endTime;
  String lessonName;
  List<Lesson> completedLessons = []; // or an appropriate default value

  Lesson({
    this.id,
    required this.studentId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.lessonName,
  });

  // Convert a Lesson object into a map to save to the database
  Map<String, dynamic> toMap() {
    return {
      'student_id': studentId,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'lesson_name': lessonName,
    };
  }

  // Convert a map into a Lesson object
  static Lesson fromMap(Map<String, dynamic> map) {
    return Lesson(
      id: map['id'],
      studentId: map['student_id'],
      dayOfWeek: map['day_of_week'],
      startTime: map['start_time'],
      endTime: map['end_time'],
      lessonName: map['lesson_name'],
    );
  }
}

// Database helper
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('lessons.db'); // Correct file name
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath =
        await getDatabasesPath(); // Get the default database directory
    final path = join(
      dbPath,
      filePath,
    ); // Join the directory with the file name
    return openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    // Create the 'lessons' table
    await db.execute(''' 
    CREATE TABLE IF NOT EXISTS lessons(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      student_id INTEGER,
      day_of_week TEXT,
      start_time INTEGER,
      end_time INTEGER,
      lesson_name TEXT
    );
  ''');

    // Create the 'student_counters' table with the correct columns
    await db.execute('''
    CREATE TABLE IF NOT EXISTS student_counters (
      student_id INTEGER PRIMARY KEY,
      completed_lessons INTEGER,
      paid_lessons INTEGER
    );
  ''');

    // Create the 'student_photos' table
    await db.execute('''
    CREATE TABLE IF NOT EXISTS student_photos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      student_id INTEGER,
      photo_path TEXT
    );
  ''');
  }

  Future<List<Lesson>> getLessonsForStudent(int studentId) async {
    final db = await instance.database;
    final result = await db.query(
      'lessons',
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
    return result.map((e) => Lesson.fromMap(e)).toList();
  }

  Future<int> insertLesson(Lesson lesson) async {
    final db = await instance.database;
    return await db.insert('lessons', lesson.toMap());
  }

  Future<int> updateLesson(Lesson lesson) async {
    final db = await instance.database;
    return await db.update(
      'lessons',
      lesson.toMap(),
      where: 'id = ?',
      whereArgs: [lesson.id],
    );
  }

  Future<Map<String, int>> getStudentCounters(int studentId) async {
    final db = await instance.database;
    final result = await db.query(
      'student_counters',
      where: 'student_id = ?',
      whereArgs: [studentId],
    );

    if (result.isNotEmpty) {
      return {
        'completed_lessons': result[0]['completed_lessons'] as int,
        'paid_lessons': result[0]['paid_lessons'] as int,
      };
    }

    // If no record exists, return default values
    return {'completed_lessons': 0, 'paid_lessons': 0};
  }

  Future<void> updateStudentCounters(
    int studentId,
    int completedLessons,
    int paidLessons,
  ) async {
    final db = await instance.database;
    await db.insert(
      'student_counters',
      {
        'student_id': studentId,
        'completed_lessons': completedLessons,
        'paid_lessons': paidLessons,
      },
      conflictAlgorithm:
          ConflictAlgorithm.replace, // Update if the record exists
    );
  }

  // Insert a photo
  Future<int> insertPhoto(int studentId, String photoPath) async {
    final db = await instance.database;
    return await db.insert('student_photos', {
      'student_id': studentId,
      'photo_path': photoPath,
    });
  }

  // Retrieve photos for a student with their IDs
  Future<List<Map<String, dynamic>>> getPhotosForStudent(int studentId) async {
    final db = await instance.database;
    final result = await db.query(
      'student_photos',
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
    return result;
  }

  // Delete a photo
  Future<void> deletePhoto(int photoId) async {
    final db = await instance.database;
    await db.delete('student_photos', where: 'id = ?', whereArgs: [photoId]);
  }
}

class StudentInfoScreen extends StatefulWidget {
  final Map<String, dynamic> student;

  StudentInfoScreen({required this.student});

  @override
  _StudentInfoScreenState createState() => _StudentInfoScreenState();
}

class _StudentInfoScreenState extends State<StudentInfoScreen> {
  late Map<String, dynamic> student;
  late int completedLessons;
  late int paidLessons;
  List<Map<String, dynamic>> photos =
      []; // List to store photo data (id and path)
  List<int> selectedPhotoIndices = []; // List to store selected photo indices

  @override
  void initState() {
    super.initState();
    student = widget.student;
    completedLessons = 0; // Initialize with default values
    paidLessons = 0; // Initialize with default values
    _loadCounters(); // Load counters from the database
    _loadPhotos(); // Load photos from the database
  }

  // Load the counters from the database
  Future<void> _loadCounters() async {
    final counters = await DatabaseHelper.instance.getStudentCounters(
      student['id'],
    );
    setState(() {
      completedLessons = counters['completed_lessons']!;
      paidLessons = counters['paid_lessons']!;
    });
  }

  // Update the counters in the database
  Future<void> _updateCounters() async {
    await DatabaseHelper.instance.updateStudentCounters(
      student['id'],
      completedLessons,
      paidLessons,
    );
  }

  // Load photos from the database
  // Load photos from the database
  Future<void> _loadPhotos() async {
    final photoData = await DatabaseHelper.instance.getPhotosForStudent(
      student['id'],
    );

    // Convert the query result into a mutable list
    setState(() {
      photos = List<Map<String, dynamic>>.from(photoData);
    });
  }

  // Upload multiple photos
  Future<void> _uploadPhotos() async {
    final imagePicker = ImagePicker();
    final List<XFile> pickedFiles = await imagePicker.pickMultiImage();

    if (pickedFiles.isNotEmpty) {
      for (var pickedFile in pickedFiles) {
        final photoPath = pickedFile.path;
        await DatabaseHelper.instance.insertPhoto(student['id'], photoPath);
      }
      _loadPhotos(); // Reload photos after uploading
    }
  }

  // Share multiple photos
  Future<void> _sharePhotos(List<String> photoPaths) async {
    await Share.shareXFiles(photoPaths.map((path) => XFile(path)).toList());
  }

  // Delete multiple photos
  // Delete multiple photos
  // Delete multiple photos
  Future<void> _deletePhotos(List<int> indices) async {
    // Sort indices in descending order to avoid index shifting issues
    indices.sort((a, b) => b.compareTo(a));

    for (var index in indices) {
      final photoId = photos[index]['id']; // Get the correct photo ID
      await DatabaseHelper.instance.deletePhoto(photoId);

      // Remove the photo from the list
      setState(() {
        photos.removeAt(index);
      });
    }

    // Clear the selection after deletion
    _clearSelection();
  }

  // Toggle photo selection
  void _togglePhotoSelection(int index) {
    setState(() {
      if (selectedPhotoIndices.contains(index)) {
        selectedPhotoIndices.remove(index);
      } else {
        selectedPhotoIndices.add(index);
      }
    });
  }

  // Clear photo selection
  void _clearSelection() {
    setState(() {
      selectedPhotoIndices.clear();
    });
  }

  @override
  void dispose() {
    // Save the counters to the database when the screen is disposed
    _updateCounters();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${student['name']} ${student['surname']}'),
        actions: [
          if (selectedPhotoIndices.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () {
                _deletePhotos(selectedPhotoIndices);
              },
            ),
          if (selectedPhotoIndices.isNotEmpty)
            IconButton(
              icon: Icon(Icons.share),
              onPressed: () {
                // Extract photo paths as List<String>
                final List<String> photoPaths =
                    selectedPhotoIndices
                        .map(
                          (index) => photos[index]['photo_path'] as String,
                        ) // Cast to String
                        .toList();

                // Share the photos
                _sharePhotos(photoPaths);

                // Clear the selection
                _clearSelection();
              },
            ),
          IconButton(
            icon: Icon(Icons.info),
            onPressed: () async {
              final updatedStudent = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StudentScreen(student: student),
                ),
              );
              if (updatedStudent != null) {
                setState(() {
                  student = updatedStudent;
                });
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Program grid (expanded to fill available space)
          Expanded(
            child: Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                child: FutureBuilder<List<Lesson>>(
                  future: DatabaseHelper.instance.getLessonsForStudent(
                    student['id'],
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else {
                      final lessons = snapshot.data ?? [];
                      return _buildScheduleGrid(lessons, context);
                    }
                  },
                ),
              ),
            ),
          ),
          // Counters and photos (scrollable)
          Container(
            height: 200, // Fixed height for the counters and photos section
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Add counters below the program
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Completed Lessons: $completedLessons'),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove),
                              onPressed: () {
                                setState(() {
                                  if (completedLessons > 0) completedLessons--;
                                });
                                _updateCounters();
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.add),
                              onPressed: () {
                                setState(() {
                                  completedLessons++;
                                });
                                _updateCounters();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Unpaid Lessons: $paidLessons'),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove),
                              onPressed: () {
                                setState(() {
                                  if (paidLessons > 0) paidLessons--;
                                });
                                _updateCounters();
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.add),
                              onPressed: () {
                                setState(() {
                                  paidLessons++;
                                });
                                _updateCounters();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 16), // Add spacing between sections
                    // Add photo upload button
                    ElevatedButton(
                      onPressed: _uploadPhotos,
                      child: Text('Upload Photos'),
                    ),
                    SizedBox(height: 16), // Add spacing between sections
                    // Display photos in a scrollable container
                    Container(
                      height: 150, // Fixed height for the photos container
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length,
                        itemBuilder: (context, index) {
                          final photoPath =
                              photos[index]['photo_path']; // Get the photo path
                          final isSelected = selectedPhotoIndices.contains(
                            index,
                          );
                          return GestureDetector(
                            onTap: () => _togglePhotoSelection(index),
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Stack(
                                children: [
                                  Image.file(
                                    File(photoPath),
                                    width: 150,
                                    height: 150,
                                    fit: BoxFit.cover,
                                    color:
                                        isSelected
                                            ? Colors.black.withOpacity(0.5)
                                            : null,
                                    colorBlendMode:
                                        isSelected
                                            ? BlendMode.darken
                                            : BlendMode.srcOver,
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      right: 0,
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                      ),
                                    ),
                                ],
                              ),
                            ),
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

  Widget _buildScheduleGrid(List<Lesson> lessons, BuildContext context) {
    final daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final timeSlots = List.generate(14, (index) => 8 + index); // 8:00 to 21:00

    // List to store special cells
    List<Map<String, dynamic>> isSpecialCell = [];

    // Populate isSpecialCell based on lesson times
    for (var lesson in lessons) {
      isSpecialCell.add({'day': lesson.dayOfWeek, 'hour': lesson.startTime});
    }

    return GestureDetector(
      onLongPress: () async {
        // Navigate to EditLessons when long pressed anywhere
        final updatedLessons = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditLessons(student: student),
          ),
        );

        _loadCounters(); // Reload counters after editing
      },
      child: Column(
        children: [
          // Header Row for Days of the Week
          Row(
            children: [
              Container(width: 40), // Empty space for time column
              ...daysOfWeek.map(
                (day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          // Grid for Time Slots
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time Column
                Container(
                  width: 40,
                  child: Column(
                    children:
                        timeSlots
                            .map(
                              (hour) => Container(
                                height: 30.9,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '$hour:00     ',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
                // Grid with special red cells for lessons
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: daysOfWeek.length,
                      childAspectRatio: 1.5,
                    ),
                    itemCount: daysOfWeek.length * timeSlots.length,
                    itemBuilder: (context, index) {
                      final dayIndex = index % daysOfWeek.length;
                      final timeIndex = index ~/ daysOfWeek.length;
                      final hour = timeSlots[timeIndex];
                      final day = daysOfWeek[dayIndex];

                      // Check if this cell is in isSpecialCell list
                      final isHighlighted = isSpecialCell.any(
                        (cell) => cell['day'] == day && cell['hour'] == hour,
                      );

                      return Container(
                        margin: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color:
                              isHighlighted
                                  ? Color(student['color']) // Use student color
                                  : Colors.white, // Default color
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    },
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
