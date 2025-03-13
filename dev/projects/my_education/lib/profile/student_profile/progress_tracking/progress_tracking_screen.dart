import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProgressTrackingScreen extends StatefulWidget {
  const ProgressTrackingScreen({Key? key}) : super(key: key);

  @override
  _ProgressTrackingScreenState createState() => _ProgressTrackingScreenState();
}

class _ProgressTrackingScreenState extends State<ProgressTrackingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = true;
  bool hasData = false;
  String currentTab = 'Primary';
  List<Map<String, dynamic>> subjects = [];
  String? userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        currentTab = _tabController.index == 0 ? 'Primary' : 'Secondary';
        _loadSubjects();
      });
    });
    _fetchUserId();
  }

  Future<void> _fetchUserId() async {
    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        userId = user.uid;
        await _loadSubjects();
      } else {
        // Handle case when user is not logged in
        print('No user logged in');
      }
    } catch (e) {
      print('Error fetching user ID: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadSubjects() async {
    if (userId == null) return;

    setState(() => isLoading = true);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('progress')
          .doc(currentTab.toLowerCase())
          .collection('subjects')
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          subjects = [];
          hasData = false;
        });
      } else {
        setState(() {
          subjects = querySnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'],
              'scores': List<int?>.from(data['scores']),
              'color': Color(data['color']),
            };
          }).toList();
          hasData = true;
        });
      }
    } catch (e) {
      print('Error loading subjects: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _addSubject(String name, Color color) async {
    if (userId == null) return;

    final subjectData = {
      'name': name,
      'scores': [0, 0, 0, 0, 0],
      'color': color.value,
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('progress')
          .doc(currentTab.toLowerCase())
          .collection('subjects')
          .add(subjectData);

      _loadSubjects();
    } catch (e) {
      print('Error adding subject: $e');
    }
  }

  Future<void> _updateScores(String subjectId, List<int> scores) async {
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('progress')
          .doc(currentTab.toLowerCase())
          .collection('subjects')
          .doc(subjectId)
          .update({'scores': scores});

      _loadSubjects();
    } catch (e) {
      print('Error updating scores: $e');
    }
  }

  Future<void> _updateSubject(
      String subjectId, String name, Color color) async {
    if (userId == null) return;

    try {
      // Show loading indicator or something similar if required
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('progress')
          .doc(currentTab.toLowerCase())
          .collection('subjects')
          .doc(subjectId)
          .update({
        'name': name,
        'color': color.value,
      });

      // Reload subjects after successful update
      await _loadSubjects();
    } catch (e) {
      // Handle errors
      print('Error updating subject: $e');
      // You can also show an error message to the user here
    }
  }

  Future<void> _deleteSubject(String subjectId) async {
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('progress')
          .doc(currentTab.toLowerCase())
          .collection('subjects')
          .doc(subjectId)
          .delete();

      _loadSubjects();
    } catch (e) {
      print('Error deleting subject: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Tracking'),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Primary Level'),
            Tab(text: 'Secondary Level'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : hasData
              ? Column(
                  children: [
                    _buildLineChart(),
                    Expanded(child: _buildSubjectList()),
                  ],
                )
              : const Center(child: Text('No data')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSubjectDialog(context),
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildLineChart() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                minX: 1,
                maxX: 5,
                minY: 0,
                maxY: 100,
                lineBarsData: subjects
                    .map((subject) {
                      // Filter scores that are non-zero
                      final spots = List.generate(
                        subject['scores'].length,
                        (index) {
                          final score = subject['scores'][index];
                          return score != null && score > 0
                              ? FlSpot(index + 1, score.toDouble())
                              : null;
                        },
                      ).whereType<FlSpot>().toList();

                      // Skip subjects with no valid scores
                      if (spots.isEmpty) return null;

                      return LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        barWidth: 4,
                        color: subject['color'],
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(show: false),
                      );
                    })
                    .whereType<LineChartBarData>()
                    .toList(),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.grey.withOpacity(0.3),
                    strokeWidth: 1,
                  ),
                  getDrawingVerticalLine: (_) => FlLine(
                    color: Colors.grey.withOpacity(0.3),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 25,
                      reservedSize: 40,
                      getTitlesWidget: (value, _) => Text(
                        '${value.toInt()}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        // Map x-values to test labels
                        switch (value.toInt()) {
                          case 1:
                            return const Text('Test 1');
                          case 2:
                            return const Text('Test 2');
                          case 3:
                            return const Text('Test 3');
                          case 4:
                            return const Text('Test 4');
                          case 5:
                            return const Text('Test 5');
                          default:
                            return const Text('');
                        }
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles:
                        SideTitles(showTitles: false), // Removed top scale
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles:
                        SideTitles(showTitles: false), // Removed right scale
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectList() {
    return ListView.builder(
      itemCount: subjects.length,
      itemBuilder: (context, index) {
        final subject = subjects[index];
        return Dismissible(
          key: Key(subject['id']), // Use the subject's ID as the key
          direction: DismissDirection.endToStart, // Swipe from left to right
          confirmDismiss: (direction) async {
            // Show the confirmation dialog before dismissing
            bool? confirmed = await _showDeleteConfirmationDialog(
                context, subject['id'], subject['name']);
            return confirmed ?? false; // If user cancels, don't dismiss
          },
          background: Container(
            color: Colors.red, // Red background for delete action
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: const Icon(
              Icons.delete,
              color: Colors.white,
              size: 36.0,
            ),
          ),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(subject['name']),
              trailing: Icon(Icons.bar_chart, color: subject['color']),
              onTap: () => _showEditScoresDialog(subject),
              onLongPress: () => _showEditSubjectDialog(context, subject),
            ),
          ),
        );
      },
    );
  }

  Future<bool?> _showDeleteConfirmationDialog(
      BuildContext context, String subjectId, String subjectName) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text(
              'Are you sure you want to delete the subject "$subjectName"?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // Close dialog and cancel
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteSubject(subjectId); // Proceed with deletion
                Navigator.of(context).pop(true); // Close dialog after deletion
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$subjectName deleted')),
                );
              },
              child: const Text('Delete'),
              style: ElevatedButton.styleFrom(iconColor: Colors.red),
            ),
          ],
        );
      },
    );
  }

  void _showAddSubjectDialog(BuildContext context) {
    final TextEditingController _subjectController = TextEditingController();
    Color selectedColor = Colors.grey;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Subject'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Subject Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      _showColorPicker(context, selectedColor, (color) {
                        setDialogState(() {
                          selectedColor = color;
                        });
                      });
                    },
                    child: Row(
                      children: [
                        const Text('Pick a Color:'),
                        const SizedBox(width: 10),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: selectedColor,
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    final name = _subjectController.text.trim();
                    if (name.isNotEmpty &&
                        !subjects.any((s) => s['name'] == name)) {
                      _addSubject(name, selectedColor);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Add'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showColorPicker(
    BuildContext context,
    Color initialColor,
    Function(Color) onColorSelected,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        Color tempColor = initialColor;
        return AlertDialog(
          title: const Text('Pick a Color'),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: initialColor,
              onColorChanged: (color) => tempColor = color,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onColorSelected(tempColor);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  void _showEditScoresDialog(Map<String, dynamic> subject) {
    final List<TextEditingController> controllers = List.generate(
      5,
      (index) => TextEditingController(
        text: index < subject['scores'].length
            ? subject['scores'][index].toString()
            : '',
      ),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Scores for ${subject['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              return TextField(
                controller: controllers[index],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Score ${index + 1}'),
              );
            }),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                final updatedScores = controllers.map((c) {
                  final text = c.text.trim();
                  return text.isEmpty ? 0 : int.parse(text);
                }).toList();

                _updateScores(subject['id'], updatedScores);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showEditSubjectDialog(
      BuildContext context, Map<String, dynamic> subject) {
    final TextEditingController _editController =
        TextEditingController(text: subject['name']);
    Color selectedColor = subject['color'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Subject'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _editController,
                    decoration: const InputDecoration(
                      labelText: 'New Subject Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      _showColorPicker(context, selectedColor, (color) {
                        setDialogState(() {
                          selectedColor = color;
                        });
                      });
                    },
                    child: Row(
                      children: [
                        const Text("Pick a Color: "),
                        const SizedBox(width: 10),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: selectedColor,
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    final newName = _editController.text.trim();
                    if (newName.isNotEmpty) {
                      _updateSubject(
                        subject['id'], // subjectId
                        newName, // new name
                        selectedColor, // new color
                      );
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Save'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
