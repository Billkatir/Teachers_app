import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// Define a model for the Lesson
class Lesson {
  int? id;
  int studentId;
  String dayOfWeek;
  int startTime;
  int endTime;
  String lessonName;

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
    _database = await _initDB('lessons.db'); // Pass the correct file name
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

  Future _createDB(Database db, int version) async {
    await db.execute(''' 
    CREATE TABLE lessons(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      student_id INTEGER,
      day_of_week TEXT,
      start_time INTEGER,
      end_time INTEGER,
      lesson_name TEXT
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

  Future<List<Lesson>> getLessonsForAll() async {
    final db = await instance.database;
    final result = await db.query(
      'lessons',
    ); // Query without the student ID filter
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
}

class EditLessons extends StatefulWidget {
  final Map<String, dynamic> student;

  EditLessons({required this.student});

  @override
  _EditLessonsState createState() => _EditLessonsState();
}

class _EditLessonsState extends State<EditLessons> {
  late List<List<String?>> schedule;

  @override
  void initState() {
    super.initState();
    schedule = List.generate(
      6,
      (_) => List.filled(14, null),
    ); // 6 days instead of 7
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    try {
      // Get the current student's lessons
      List<Lesson> studentLessons = await DatabaseHelper.instance
          .getLessonsForStudent(widget.student['id']);

      // Get all lessons (for overlap detection)
      List<Lesson> allLessons =
          await DatabaseHelper.instance.getLessonsForAll();

      for (var lesson in allLessons) {
        int day = _getDayOfWeek(lesson.dayOfWeek);
        if (day == -1) {
          // Skip processing for Sunday
          print("Skipping lesson on Sunday: ${lesson.dayOfWeek}");
          continue;
        }

        int timeSlot = lesson.startTime - 8;
        setState(() {
          schedule[day][timeSlot] = ' ';
        });
        print("aaaaaaa, $lesson");
      }

      // Now load the student's lessons into the schedule
      for (var lesson in studentLessons) {
        int day = _getDayOfWeek(lesson.dayOfWeek);
        if (day == -1) {
          // Skip processing for Sunday
          continue;
        }

        int timeSlot = lesson.startTime - 8;
        setState(() {
          schedule[day][timeSlot] = lesson.lessonName;
        });
      }

      // Now mark overlapping lessons as gray
    } catch (e) {
      print('Error loading lessons: $e');
    }
  }

  int _getDayOfWeek(String day) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']; // Exclude 'Sun'

    // If the day is "Sun", return an invalid index or skip it
    if (day == 'Sun') {
      print("Skipping lesson on Sunday: $day");
      return -1; // Skip the lesson if it's Sunday
    }

    int dayIndex = days.indexOf(day);

    if (dayIndex == -1) {
      print("Invalid day: $day"); // Log invalid day
      return -1; // Return a fallback value or handle error
    }

    return dayIndex;
  }

  void _updateLesson(int day, int timeSlot, String lessonName) async {
    final lesson = Lesson(
      studentId: widget.student['id'],
      dayOfWeek: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][day], // 6 days
      startTime: timeSlot + 8, // Assuming time slots start at 8:00
      endTime: timeSlot + 9, // Assuming each lesson is 1 hour long
      lessonName: lessonName,
    );

    // Check if a lesson already exists at this time slot
    final existingLessons = await DatabaseHelper.instance.getLessonsForStudent(
      widget.student['id'],
    );
    final existingLesson = existingLessons.firstWhere(
      (l) => l.dayOfWeek == lesson.dayOfWeek && l.startTime == lesson.startTime,
      orElse:
          () => Lesson(
            id: null,
            studentId: 0,
            dayOfWeek: '',
            startTime: 0,
            endTime: 0,
            lessonName: '',
          ),
    );

    if (existingLesson.id != null) {
      // Update the existing lesson
      lesson.id = existingLesson.id;
      await DatabaseHelper.instance.updateLesson(lesson);
    } else {
      // Insert a new lesson
      await DatabaseHelper.instance.insertLesson(lesson);
    }

    setState(() {
      schedule[day][timeSlot] = lessonName;
    });
  }

  void _deleteLesson(int day, int timeSlot) async {
    final existingLessons = await DatabaseHelper.instance.getLessonsForStudent(
      widget.student['id'],
    );
    final existingLesson = existingLessons.firstWhere(
      (l) =>
          l.dayOfWeek == ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][day] &&
          l.startTime == timeSlot + 8,
      orElse:
          () => Lesson(
            id: null,
            studentId: 0,
            dayOfWeek: '',
            startTime: 0,
            endTime: 0,
            lessonName: '',
          ),
    );

    if (existingLesson.id != null) {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'lessons',
        where: 'id = ?',
        whereArgs: [existingLesson.id],
      );
    }

    setState(() {
      schedule[day][timeSlot] = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Lessons for ${widget.student['name']}')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Day Labels (Mon, Tue, Wed, etc.)
            Row(
              children: [
                Container(
                  width: 60, // Space for time labels
                  child: Center(child: Text('Time')),
                ),
                Expanded(
                  child: Row(
                    children: List.generate(6, (index) {
                      // 6 days instead of 7
                      return Expanded(
                        child: Center(
                          child: Text(
                            [
                              'Mon',
                              'Tue',
                              'Wed',
                              'Thu',
                              'Fri',
                              'Sat', // Removed 'Sun'
                            ][index],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
            // Schedule Grid
            Expanded(
              child: ListView.builder(
                itemCount: 14, // Number of time slots (8:00 to 21:00)
                itemBuilder: (context, timeSlot) {
                  return Row(
                    children: [
                      // Time Label (e.g., 8:00, 9:00, etc.)
                      Container(
                        width: 60,
                        child: Center(
                          child: Text(
                            '${timeSlot + 8}:00',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      // Day Columns
                      Expanded(
                        child: Row(
                          children: List.generate(6, (dayIndex) {
                            // 6 days instead of 7
                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (schedule[dayIndex][timeSlot] != " ") {
                                    if (schedule[dayIndex][timeSlot] != null) {
                                      _deleteLesson(dayIndex, timeSlot);
                                    } else {
                                      _updateLesson(dayIndex, timeSlot, '');
                                    }
                                  }
                                },
                                child: Container(
                                  margin: EdgeInsets.all(2),
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    color:
                                        schedule[dayIndex][timeSlot] != null
                                            ? (schedule[dayIndex][timeSlot] !=
                                                    ' '
                                                ? Colors.blue
                                                : Colors.grey)
                                            : Colors.transparent,
                                  ),
                                  child: Center(
                                    child: Text(
                                      schedule[dayIndex][timeSlot] ?? '',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
