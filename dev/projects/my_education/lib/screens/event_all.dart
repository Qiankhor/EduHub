import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_education/models/Teachers.dart';
import 'package:my_education/screens/home_page.dart';
import 'package:url_launcher/url_launcher.dart';

class EventAll extends StatefulWidget {
  @override
  _EventAllState createState() => _EventAllState();
}

class _EventAllState extends State<EventAll> {
  final DatabaseReference _promotionalEventRef =
      FirebaseDatabase.instance.ref().child('promotionalEvent');

  String searchQuery = ''; // Variable to hold the search query
List<Map<String, dynamic>> eventData = [];

Future<void> _fetchEventData() async {
  try {
    DataSnapshot snapshot = await _promotionalEventRef.get();
    if (snapshot.exists) {
      Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      if (mounted) {
        setState(() {
          eventData = data.entries
              .map((entry) {
                final item = {
                  'key': entry.key,
                  ...Map<String, dynamic>.from(entry.value as Map<dynamic, dynamic>)
                };

                // 打印 item 的值来调试
                print('Fetched item: $item');

                return item;
              })
              .where((item) => item['approve'] == true) // Filter for approved items
              .toList();
        });
      }
    } else {
      print('No data found.');
      setState(() {
        eventData = [];
      });
    }
  } catch (e) {
    print('Error fetching data: $e');
    setState(() {
      eventData = [];
    });
  }
}


  // Function to filter events based on search query
  List<Map<String, dynamic>> _filterEvents(List<Map<String, dynamic>> events) {
    if (searchQuery.isEmpty) return events;
    return events.where((event) {
      return (event['eventName'] as String).toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();
  }
 @override
  void initState() {
    super.initState();
    _fetchEventData(); // Fetch data when the widget initializes
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HomePage(
                  Teacher(
                    name: '',
                    university: '',
                    imageAsset: '',
                    rating: 0.0,
                    reviews: 0,
                  ),
                ),
              ),
            );
          },
        ),
        title: Text('Latest Event'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value; // Update the search query
                  });
                },
                decoration: InputDecoration(
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.orange.shade700),
                  ),
                  border: OutlineInputBorder(),
                  labelText: 'Search',
                  suffixIcon: Icon(Icons.search),
                ),
              ),
            ),
            SingleChildScrollView(
  scrollDirection: Axis.vertical,
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
    child: _filterEvents(eventData).isEmpty
      ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Icon(
                Icons.search_off_rounded,
                size: 56,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                "No events found.", style: GoogleFonts.poppins(color: Colors.grey
              ),
          )],
          ),
        )
      : Wrap(
          spacing: 12.0,
          runSpacing: 16.0,
          children: _filterEvents(eventData).map((item) {
            return SizedBox(
              width: MediaQuery.of(context).size.width / 2 - 14,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventDetailPage(eventData: item,),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image container with rounded corners
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item['imagePath'] != null && item['imagePath'].isNotEmpty
                        ? Container(
                            height: 180,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: NetworkImage(item['imagePath']),
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        : Container(
                            height: 180,
                            width: double.infinity,
                            color: Colors.grey[200],
                          ),
                    ),
                    const SizedBox(height: 8),
                    // Title with ellipsis
                    Text(
                      item['eventName'] ?? 'Unknown Name',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF171A1F),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Target audience row
                    Row(
                      children: [
                        Icon(
                          Icons.person_2_outlined,
                          color: Colors.grey[600],
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${item['targetAudience'] ?? 'Unknown'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w400,
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    // Fee row
                    Row(
                      children: [
                        Icon(
                          Icons.attach_money_rounded,
                          color: Colors.grey[600],
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${item['participationFee']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w400,
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
  ),
)
                               ],
        
        ),
      ),
    );
  }
}


class EventDetailPage extends StatelessWidget {
  final Map<String, dynamic> eventData;

  EventDetailPage({required this.eventData});

  Future<void> _launchURL(String url) async {
  try {
    final Uri uri = Uri.parse(url);
     await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    print('Error: $e');
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
      ),
      body:  SingleChildScrollView(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display event image
             // Display event image
        eventData['imagePath'] != null
            ? Image.network(
          eventData['imagePath'],
          fit: BoxFit.contain, // 显示完整图片
          width: double.infinity, // 宽度适应屏幕
        )
            : Container(height: 200, color: Colors.grey), // Placeholder if no image
        
        
              SizedBox(height: 16),
        
              // Event name
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  eventData['eventName'] ?? 'Unknown Event',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 8),
        
              // Target audience
              // Target audience
        Padding(
          padding: const EdgeInsets.only(left: 8, right: 8),
          child: RichText(
            text: TextSpan(
        children: [
          TextSpan(
            text: 'Target Audience\n',
            style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold, color: Colors.black), // Target Audience的颜色
          ),
          TextSpan(
            text: '${eventData['targetAudience'] ?? 'Unknown'}',
            style: TextStyle(fontSize: 20, color: Colors.grey[600]), // 值的颜色
          ),
        ],
            ),
          ),
        ),
        
              SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 8, right: 8),
          child: RichText(
            text: TextSpan(
        children: [
          TextSpan(
            text: 'Participation Fee\n',
            style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold, color: Colors.black), // 字段名的颜色
          ),
          TextSpan(
            text: '${eventData['participationFee'] ?? '0.00'}',
            style: TextStyle(fontSize: 20, color: Colors.grey[600]), // 值的颜色
          ),
        ],
            ),
          ),
        ),
        
              SizedBox(height: 16),
        
              Align(
                child: Padding(
                padding: const EdgeInsets.only(left: 8, right: 8),
                child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5)
                  ),
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white
                ),
                  onPressed: () {
                    _launchURL(eventData['URL'] ?? '');
                  },
                  child: Text('View Details'),
                ),
                            ),
              ),
            SizedBox(height:32),   
            ],
          ),
      ),
      
    );
  }
}