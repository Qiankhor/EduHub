import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class QualificationScreen extends StatefulWidget {
  @override
  _QualificationScreenState createState() => _QualificationScreenState();
}

class _QualificationScreenState extends State<QualificationScreen> {
  String? selectedGender;
  List<String> selectedDays = [];
  List<bool> selectedTimeSlots = List.generate(10, (_) => false);
  final TextEditingController nameController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController qualificationController = TextEditingController();
  final TextEditingController institutionController = TextEditingController();
  final TextEditingController graduationYearController =
      TextEditingController();
  final TextEditingController experienceYearsController =
      TextEditingController();
  final TextEditingController aboutController = TextEditingController();
  final TextEditingController rateController = TextEditingController();
  bool isUpdating = false;

  String? userId;

  @override
  void initState() {
    super.initState();
    _fetchUserId(); // Fetch user ID before loading existing data
  }

  Future<void> _fetchUserId() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          userId = user.uid;
        });
        _fetchExistingData(); // Load existing data after getting userId
      } else {
        // Handle unauthenticated user case
        Fluttertoast.showToast(
          msg: "User not authenticated",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (error) {
      Fluttertoast.showToast(
        msg: "Failed to get user ID: $error",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  Future<void> _fetchExistingData() async {
    if (userId == null) return;

    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    try {
      DocumentSnapshot existingDoc =
          await firestore.collection('qualifications').doc(userId).get();

      if (existingDoc.exists) {
        // Set form fields with existing data
        Map<String, dynamic> data = existingDoc.data() as Map<String, dynamic>;

        setState(() {
          nameController.text = data['name'] ?? '';
          dobController.text = data['dateOfBirth'] ?? '';
          selectedGender = data['gender'];
          locationController.text = data['location'] ?? '';
          qualificationController.text = data['highestQualification'] ?? '';
          institutionController.text = data['institutionName'] ?? '';
          graduationYearController.text = data['yearOfGraduation'] ?? '';
          experienceYearsController.text = (data['yearsOfExperience'] ?? 0)
              .toString(); // Ensure it's a string
          aboutController.text = data['about'] ?? '';
          rateController.text =
              (data['ratePerHour'] ?? 0.0).toString(); // Ensure it's a string
          selectedDays = List<String>.from(data['availableDays'] ?? []);
          List<dynamic> timeSlots = data['availableTimeSlots'] ?? [];
          selectedTimeSlots =
              List.generate(10, (index) => timeSlots.contains(index));
          isUpdating = true; // Update button label to "Update"
        });
      }
    } catch (error) {
      Fluttertoast.showToast(
        msg: "Failed to load data: $error",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  Future<void> _submitData() async {
    if (userId == null) return;

    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    final Map<String, dynamic> data = {
      'name': nameController.text,
      'dateOfBirth': dobController.text,
      'gender': selectedGender,
      'location': locationController.text,
      'highestQualification': qualificationController.text,
      'institutionName': institutionController.text,
      'yearOfGraduation': graduationYearController.text,
      'yearsOfExperience': int.tryParse(experienceYearsController.text) ?? 0,
      'about': aboutController.text,
      'availableDays': selectedDays,
      'availableTimeSlots': selectedTimeSlots
          .asMap()
          .entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList(),
      'ratePerHour': double.tryParse(rateController.text) ?? 0.0,
      'qualificationStatus': 'Pending',
    };

    try {
      DocumentSnapshot existingDoc =
          await firestore.collection('qualifications').doc(userId).get();

      if (existingDoc.exists) {
        // Update the existing document
        await firestore.collection('qualifications').doc(userId).update(data);
        Fluttertoast.showToast(
          msg: "Qualification Form updated successfully!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.blue,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      } else {
        // Add new qualification document
        await firestore.collection('qualifications').doc(userId).set(data);
        Fluttertoast.showToast(
          msg: "Qualification Form submitted successfully!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.blue,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      Fluttertoast.showToast(
        msg: "Failed to submit form: $error",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6E6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Qualification',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
                label: 'Name',
                hint: 'Enter your full name',
                controller: nameController),
            _buildTextField(
                label: 'Date of Birth',
                hint: 'MM/DD/YYYY',
                isDateField: true,
                controller: dobController),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('Gender', style: TextStyle(fontSize: 16)),
            ),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Male'),
                    value: 'Male',
                    groupValue: selectedGender,
                    onChanged: (value) {
                      setState(() {
                        selectedGender = value;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Female'),
                    value: 'Female',
                    groupValue: selectedGender,
                    onChanged: (value) {
                      setState(() {
                        selectedGender = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            _buildTextField(
                label: 'Location',
                hint: 'Enter your current location',
                controller: locationController),
            _buildTextField(
                label: 'Highest Qualification',
                hint: 'Diploma/Degree/Master in...',
                controller: qualificationController),
            _buildTextField(
                label: 'Name of Institution',
                hint: 'Enter your highest institution name',
                controller: institutionController),
            _buildTextField(
                label: 'Year of Graduation',
                hint: 'Enter your year of graduation',
                controller: graduationYearController),
            _buildTextField(
                label: 'Year of Experience',
                hint: 'Enter your year of teaching experience',
                controller: experienceYearsController),
            _buildTextField(
                label: 'About you',
                hint: 'Write about yourself...',
                maxLines: 3,
                controller: aboutController),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('Available Days', style: TextStyle(fontSize: 16)),
            ),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: [
                SizedBox(
                  width: 110,
                  child: ChoiceChip(
                    label: const Center(child: Text('Select All')),
                    selected: selectedDays.length == 7,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          selectedDays = [
                            'Monday',
                            'Tuesday',
                            'Wednesday',
                            'Thursday',
                            'Friday',
                            'Saturday',
                            'Sunday',
                          ];
                        } else {
                          selectedDays.clear();
                        }
                      });
                    },
                  ),
                ),
                ...[
                  'Monday',
                  'Tuesday',
                  'Wednesday',
                  'Thursday',
                  'Friday',
                  'Saturday',
                  'Sunday'
                ].map((day) {
                  return SizedBox(
                    width: 110,
                    child: ChoiceChip(
                      label: Center(child: Text(day)),
                      selected: selectedDays.contains(day),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedDays.add(day);
                          } else {
                            selectedDays.remove(day);
                          }
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child:
                  Text('Available Time Slots', style: TextStyle(fontSize: 16)),
            ),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: [
                '09:00 AM - 10:00 PM',
                '10:00 AM - 11:00 PM',
                '11:00 AM - 12:00 PM',
                '02:00 PM - 03:00 PM',
                '03:00 PM - 04:00 PM',
                '04:00 PM - 05:00 PM',
                '05:00 PM - 06:00 PM',
                '07:00 PM - 08:00 PM',
                '08:00 PM - 09:00 PM',
                '09:00 PM - 10:00 PM',
              ].asMap().entries.map((entry) {
                int index = entry.key;
                String time = entry.value;
                return SizedBox(
                  width: 180,
                  child: ChoiceChip(
                    label: Text(time),
                    selected: selectedTimeSlots[index],
                    onSelected: (selected) {
                      setState(() {
                        selectedTimeSlots[index] = selected;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
            _buildTextField(
                label: 'Rate per hour', hint: 'RM', controller: rateController),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  _submitData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                child: Text(
                  isUpdating ? 'Update' : 'Submit',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    bool isDateField = false,
    int maxLines = 1,
    required TextEditingController controller,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          TextField(
            controller: controller,
            readOnly: isDateField,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              suffixIcon: isDateField ? const Icon(Icons.calendar_today) : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
                borderSide: BorderSide.none,
              ),
            ),
            onTap: isDateField
                ? () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (pickedDate != null) {
                      controller.text =
                          "${pickedDate.month}/${pickedDate.day}/${pickedDate.year}";
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
