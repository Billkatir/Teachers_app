import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'screens/add_student_screen.dart';
import 'screens/student_info_screen.dart';
import 'screens/color_palette_screen.dart';

void main() {
  runApp(StudentApp());
}

class StudentApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Database _database;
  List<Map<String, dynamic>> _students = [];
  List<Lesson> allLessons = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initDatabase().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadData();
      });
    });
  }

  Future<void> _initDatabase() async {
    try {
      _database = await openDatabase(
        path.join(await getDatabasesPath(), 'students.db'),
        version: 1,
        onCreate: (db, version) {
          // Create the students table if it doesn't exist
          return db.execute('''
          CREATE TABLE students(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            surname TEXT,
            parent_name TEXT,
            parent_surname TEXT,
            student_phone TEXT,
            parent_phone TEXT,
            color INTEGER
          )
          ''');
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize database: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    try {
      final db = await _database; // Ensure _database is initialized
      final students = await db.query('students'); // Query the students table

      // Clear previous data if necessary
      setState(() {
        _students.clear();
        allLessons.clear();
      });

      for (var studentMap in students) {
        int studentId = studentMap['id'] as int; // Cast the value to int

        // Fetch lessons for this student
        List<Lesson> studentLessons = await DatabaseHelper.instance
            .getLessonsForStudent(studentId);

        setState(() {
          _students.add(studentMap);
          allLessons.addAll(studentLessons);
        });
      }

      setState(() {
        _isLoading = false; // Once data is loaded, stop loading
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'No Students press + to Add a student';
        _isLoading = false;
      });
    }
  }

  Future<void> _addStudent(Map<String, dynamic> student) async {
    try {
      await _database.insert('students', student);
      _loadData();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to add student: ${e.toString()}';
      });
    }
  }

  Future<void> _updateStudent(Map<String, dynamic> student) async {
    try {
      await _database.update(
        'students',
        student,
        where: 'id = ?',
        whereArgs: [student['id']],
      );
      _loadData();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update student: ${e.toString()}';
      });
    }
  }

  Widget _buildScheduleGrid() {
    final daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final timeSlots = List.generate(14, (index) => 8 + index); // 8:00 to 21:00

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          children: [
            // Header Row for Days of the Week
            Row(
              children: [
                Container(width: 40), // Space for time labels
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
            Column(
              children:
                  timeSlots.map((hour) {
                    return Row(
                      children: [
                        Container(
                          width: 40,
                          alignment: Alignment.centerRight,
                          child: Text('$hour:00'),
                        ),
                        Expanded(
                          child: Row(
                            children:
                                daysOfWeek.map((day) {
                                  // Find the lesson that matches this time slot and day
                                  var matchingLesson = allLessons.firstWhere(
                                    (lesson) =>
                                        lesson.dayOfWeek == day &&
                                        lesson.startTime == hour,
                                    orElse:
                                        () => Lesson(
                                          studentId:
                                              -1, // Set an invalid student ID for empty lessons
                                          dayOfWeek: day,
                                          startTime: hour,
                                          endTime: hour + 1, // Default end time
                                          lessonName:
                                              'No lesson', // Default lesson name
                                        ),
                                  );

                                  // Default color for empty lessons
                                  Color lessonColor = Colors.white;

                                  // Only proceed if the lesson belongs to an actual student
                                  if (matchingLesson.studentId != -1) {
                                    var student = _students.firstWhere(
                                      (s) =>
                                          s['id'] == matchingLesson.studentId,
                                      orElse:
                                          () =>
                                              {}, // Return an empty map if no student is found
                                    );

                                    // Make sure student is not empty and contains 'color'
                                    if (student.isNotEmpty &&
                                        student.containsKey('color')) {
                                      lessonColor = Color(student['color']);
                                    }

                                    return Expanded(
                                      child: GestureDetector(
                                        onTap: () async {
                                          // Navigate to the Student Info screen
                                          final selectedStudent = _students
                                              .firstWhere(
                                                (s) =>
                                                    s['id'] ==
                                                    matchingLesson.studentId,
                                              );
                                          final updatedStudent =
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) =>
                                                          StudentInfoScreen(
                                                            student:
                                                                selectedStudent,
                                                          ),
                                                ),
                                              );
                                          _loadData(); // Refresh the data after returning
                                        },
                                        child: Container(
                                          margin: EdgeInsets.all(2),
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color:
                                                lessonColor, // Use the determined lesson color
                                            border: Border.all(
                                              color: Colors.grey,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  } else {
                                    return Expanded(
                                      child: Container(
                                        margin: EdgeInsets.all(2),
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color:
                                              lessonColor, // Use the default empty lesson color
                                          border: Border.all(
                                            color: Colors.grey,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                }).toList(),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Students'),
        actions: [IconButton(icon: Icon(Icons.refresh), onPressed: _loadData)],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : ListView(
                padding: EdgeInsets.all(16),
                children: [
                  _buildScheduleGrid(),
                  ..._students.map((student) {
                    return Card(
                      elevation: 4,
                      margin: EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              student['color'] != null
                                  ? Color(student['color'])
                                  : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(16),
                          leading: Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.black,
                          ),
                          title: Text(
                            '${student['name']} ${student['surname']}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Student Phone: ${student['student_phone']}',
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.edit, color: Colors.black),
                            onPressed: () async {
                              final selectedColor = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ColorPaletteScreen(),
                                ),
                              );
                              if (selectedColor != null) {
                                final updatedStudent =
                                    Map<String, dynamic>.from(student);
                                updatedStudent['color'] = selectedColor.value;
                                _updateStudent(updatedStudent);
                              }
                            },
                          ),
                          onTap: () async {
                            final updatedStudent = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        StudentInfoScreen(student: student),
                              ),
                            );
                            _loadData();
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final student = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddStudentScreen()),
          );
          if (student != null) {
            _addStudent(student);
          }
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
