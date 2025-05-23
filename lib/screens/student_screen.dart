import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart'; // For making phone calls
import 'add_student_screen.dart';

class StudentScreen extends StatefulWidget {
  final Map<String, dynamic> student;

  StudentScreen({required this.student});

  @override
  _StudentScreenState createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  late Database _database;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    try {
      _database = await openDatabase(
        path.join(await getDatabasesPath(), 'students.db'),
        version: 1,
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize database: ${e.toString()}';
      });
    }
  }

  Future<void> _deleteStudent() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _database.delete(
        'students',
        where: 'id = ?',
        whereArgs: [widget.student['id']],
      );
      // Reload the student list before navigating back
      Navigator.pop(context, true); // Return true to indicate deletion
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to delete student: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _editStudent() async {
    final updatedStudent = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddStudentScreen(student: widget.student),
      ),
    );
    if (updatedStudent != null) {
      // Update the student in the database
      await _updateStudentInDatabase(updatedStudent);

      // Pass updated data back
      Navigator.pop(context, updatedStudent);
    }
  }

  Future<void> _updateStudentInDatabase(
    Map<String, dynamic> updatedStudent,
  ) async {
    try {
      await _database.update(
        'students', // Table name
        updatedStudent, // The updated data map
        where: 'id = ?', // Condition to find the correct record
        whereArgs: [updatedStudent['id']], // The student's id to match
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update student: ${e.toString()}';
      });
    }
  }

  // Function to launch a phone call
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunch(phoneUri.toString())) {
      await launch(phoneUri.toString());
    } else {
      throw 'Could not launch phone call';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Student Details'),
        actions: [
          IconButton(icon: Icon(Icons.edit), onPressed: _editStudent),
          IconButton(icon: Icon(Icons.delete), onPressed: _deleteStudent),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNameRow(
                      'Name',
                      '${widget.student['name']} ${widget.student['surname']}',
                      widget.student['student_phone'],
                    ),
                    _buildNameRow(
                      'Parent Name',
                      '${widget.student['parent_name']} ${widget.student['parent_surname']}',
                      widget.student['parent_phone'],
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildNameRow(String label, String name, String phoneNumber) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              SizedBox(height: 4),
              Text(
                name,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.phone, color: Colors.green),
            onPressed: () => _makePhoneCall(phoneNumber),
          ),
        ],
      ),
    );
  }
}
