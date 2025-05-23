import 'package:flutter/material.dart';

class AddStudentScreen extends StatefulWidget {
  final Map<String, dynamic>? student;

  AddStudentScreen({this.student});

  @override
  _AddStudentScreenState createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _student = {};

  @override
  void initState() {
    super.initState();
    if (widget.student != null) {
      _student.addAll(widget.student!);
    }
  }

  String? _validateField(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return 'Please enter the $fieldName';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.student == null ? 'Add Student' : 'Edit Student'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextField('Student Name', 'name', Icons.person),
              _buildTextField(
                'Student Surname',
                'surname',
                Icons.person_outline,
              ),
              _buildTextField(
                'Parent Name',
                'parent_name',
                Icons.supervised_user_circle,
              ),
              _buildTextField(
                'Parent Surname',
                'parent_surname',
                Icons.supervised_user_circle_outlined,
              ),
              _buildTextField(
                'Student Phone Number',
                'student_phone',
                Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              _buildTextField(
                'Parent Phone Number',
                'parent_phone',
                Icons.phone_android,
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('Cancel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.black,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState?.save();
                        Navigator.pop(context, _student);
                      }
                    },
                    child: Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String field,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        initialValue: _student[field],
        validator: (value) => _validateField(value, label.toLowerCase()),
        onSaved: (value) => _student[field] = value,
        keyboardType: keyboardType,
      ),
    );
  }
}
