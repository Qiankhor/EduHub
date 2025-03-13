import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_education/screens/edumart_detail_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';

class EduMartPage extends StatefulWidget {
  @override
  _EduMartPageState createState() => _EduMartPageState();
}

class _EduMartPageState extends State<EduMartPage>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _database =
      FirebaseDatabase.instance.ref().child('transactions');
  Future<DataSnapshot>? _futureData;
  late TabController _tabController; // Add TabController

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 2, vsync: this); // Initialize TabController
    _fetchData(); // Fetch data when the page is first created
  }

  // Function to fetch data from Firebase
  Future<void> _fetchData() async {
    setState(() {
      _futureData = _database.once().then((event) => event.snapshot);
    });
  }

  // Function to check if the current user is blocked
  Future<bool> _isUserBlocked() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists && userDoc['status'] == 'block' ||
          userDoc['userType'] == 'admin') {
        return true; // User is blocked
      }
    }
    return false; // User is not blocked
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: Text('EduMart', style: GoogleFonts.poppins()),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                bool isBlocked = await _isUserBlocked();
                if (isBlocked) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Access Denied'),
                      content: Text(
                          'Your account has been blocked from adding transactions.'),
                      actions: <Widget>[
                        TextButton(
                          child: Text('OK'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddTransactionPage(),
                    ),
                  ).then((_) => _fetchData());
                }
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                text: 'All',
              ),
              Tab(text: 'My Items'),
            ],
            indicatorColor: Colors.orange.shade700, // 指示器的颜色
            labelColor: Colors.black, // 选中的标签颜色
            unselectedLabelColor: Colors.grey[400],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAllTransactions(), // All transactions view
            _buildMyTransactions(), // My transactions view
          ],
        ),
      ),
    );
  }

  // Build the All Transactions view
  Widget _buildAllTransactions() {
    return FutureBuilder<DatabaseEvent>(
      future: _database.once(),
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasData) {
          DataSnapshot dataSnapshot = snapshot.data!.snapshot;

          if (dataSnapshot.value == null) {
            return Center(
              child: Text("No items available for sale.",
                  style: TextStyle(color: Colors.grey)),
            );
          }

          Map<dynamic, dynamic> data =
              dataSnapshot.value as Map<dynamic, dynamic>;
          List items = data.entries.map((e) => e.value).toList();

          return _buildGridView(items);
        }

        return Center(child: Text("Failed to load data."));
      },
    );
  }

  Widget _buildMyTransactions() {
    return FutureBuilder<DatabaseEvent>(
      future: _database.once(),
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasData) {
          DataSnapshot dataSnapshot = snapshot.data!.snapshot;

          if (dataSnapshot.value == null) {
            return Center(
              child: Text("No items available for sale",
                  style: TextStyle(color: Colors.grey)),
            );
          }

          Map<dynamic, dynamic> data =
              dataSnapshot.value as Map<dynamic, dynamic>;
          List items = data.entries.map((e) => e.value).toList();

          // Get current user ID
          User? currentUser = FirebaseAuth.instance.currentUser;
          String userId = currentUser?.uid ?? '';
          print("Current User ID: $userId"); // Debug print

          // Filter items based on provider matching current user ID
          List myItems =
              items.where((item) => item['provider'] == userId).toList();
          print("My Items: ${myItems.length} items found."); // Debug print

          if (myItems.isEmpty) {
            return Center(
              child: Text("You haven't published any transactions yet.",
                  style: TextStyle(color: Colors.grey)),
            );
          }

          return _buildGridView(myItems);
        }

        return Center(child: Text("Failed to load data."));
      },
    );
  }

  // Build GridView for displaying items
  Widget _buildGridView(List items) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10.0,
        mainAxisSpacing: 10.0,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        var item = items[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EduMartDetailPage(transactionData: item),
              ),
            ).then((_) {
              _fetchData(); // Fetch data again after returning from detail page
            });
          },
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16.0),
                    topRight: Radius.circular(16.0),
                  ),
                  child: AspectRatio(
                    aspectRatio: 3 / 1.7,
                    child: Image.network(
                      item['imageUrls'][0],
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'] ?? 'No title',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${item['transactionMethod'] ?? 'No method'}${item['location']?.isNotEmpty == true ? ' (${item['location']})' : ''}',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'RM ${item['price'] ?? '0.00'}',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AddTransactionPage extends StatefulWidget {
  @override
  _AddTransactionPageState createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  User? currentUser;
  String? _description;
  String? _title;
  String? _price;
  String? _transactionMethod;
  String? _location;
  List<File> _images = [];
  final ImagePicker _picker = ImagePicker();
  final DatabaseReference _database =
      FirebaseDatabase.instance.ref().child('transactions');
  String _selectedMethod = 'Online'; // Default selection
  TextEditingController _descriptionController = TextEditingController();
  TextEditingController _titleController = TextEditingController();
  TextEditingController _locationController = TextEditingController();
  TextEditingController _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Get current user
    currentUser = FirebaseAuth.instance.currentUser;
  }

  // Method to pick an image
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _images.add(File(pickedFile.path));
      });
    }
  }

  Future<void> _uploadImagesAndSaveData() async {
    // 检查必要字段是否为空
    if (_descriptionController.text.isEmpty ||
        _titleController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _selectedMethod == null ||
        (_transactionMethod == 'Face to face' &&
            _locationController.text.isEmpty) ||
        _images.isEmpty) {
      // 显示 Toast 提示
      Fluttertoast.showToast(
        msg: 'Please fill in all required fields.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        fontSize: 16.0,
      );
      return; // 退出函数，避免继续执行
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible:
          false, // Prevent dismissing the dialog by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Uploading...'),
            ],
          ),
        );
      },
    );

    try {
      List<String> imageUrls = [];
      for (File image in _images) {
        String fileName = DateTime.now().millisecondsSinceEpoch.toString();
        Reference ref = FirebaseStorage.instanceFor(
          bucket: "myeducation-865f1.appspot.com",
        ).ref().child('edumart/$fileName');
        await ref.putFile(image);
        String imageUrl = await ref.getDownloadURL();
        imageUrls.add(imageUrl);
      }

      // Update state variables with user input
      setState(() {
        _description = _descriptionController.text;
        _title = _titleController.text;
        _price = _priceController.text;
        _transactionMethod = _selectedMethod;
        _location = _locationController.text;
      });

      // Save data to Firebase
      if (currentUser != null) {
        String userId = currentUser!.uid;

        // Generate a new key
        DatabaseReference newTransactionRef = _database.push();
        String transactionKey = newTransactionRef.key!; // Get the key

        // Save data with the new key
        await newTransactionRef.set({
          'id': transactionKey,
          'description': _description,
          'title': _title,
          'price': double.parse(_price ?? '0.00').toStringAsFixed(2),
          'transactionMethod': _transactionMethod,
          'location': _transactionMethod == 'Face to face' ? _location : '',
          'imageUrls': imageUrls,
          'dateTime': DateTime.now().toIso8601String(),
          'provider': userId,
        });
      }
      Navigator.pop(context); // 返回到前一个页面
    } catch (e) {
      // Handle any errors (e.g., show an error message)
      print("Error uploading data: $e");
    } finally {
      // Dismiss the loading dialog
      Navigator.pop(context); // Close the loading dialog
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add Items',
        ),
        centerTitle: true,
        leading: null,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.orange.shade700, width: 2.0),
                  ),
                  hintText: "Title",
                ),
                minLines: 1,
                maxLines: null,
              ),
              SizedBox(height: 20),
              // Text input for description
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.orange.shade700, width: 2.0),
                  ),
                  hintText: "Description",
                ),
                minLines: 3,
                maxLines: null,
              ),
              SizedBox(height: 20),

              // Grid view for displaying selected images
              SizedBox(
                height: 200, // Set a fixed height to ensure proper sizing
                child: GridView.builder(
                  itemCount: _images.length < 9 ? _images.length + 1 : 9,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (context, index) {
                    if (index == _images.length && _images.length < 9) {
                      return GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          color: Colors.grey[300],
                          child: Icon(Icons.add),
                        ),
                      );
                    } else {
                      return Image.file(_images[index], fit: BoxFit.cover);
                    }
                  },
                ),
              ),

              // Dropdown for selecting Method (e.g., f2f, Online, etc.)
              DropdownButton<String>(
                value: _selectedMethod,
                items: <String>['Face to face', 'Online'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedMethod = newValue!;
                  });
                },
              ),
              SizedBox(height: 20),

              // Show location input if 'Face to face' is selected
              if (_selectedMethod == 'Face to face') ...[
                TextField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: Colors.orange.shade700, width: 2.0),
                    ),
                    labelText: 'Location',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
                SizedBox(height: 20),
              ],

              // Price input field
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.orange.shade700, width: 2.0),
                  ),
                  labelText: 'Price',
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
              SizedBox(height: 20),

              Container(
                margin: EdgeInsets.fromLTRB(0, 32, 0, 15),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                  ),
                  onPressed: _uploadImagesAndSaveData,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 12),
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        'Publish',
                        style: GoogleFonts.getFont(
                          'Poppins',
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          height: 1.4,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
