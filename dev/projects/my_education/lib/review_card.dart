import 'package:my_education/tutor.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.tutor,
  });

  final Tutor tutor;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      // Fetching all the reviews from the ratings subcollection of the tutor
      future: FirebaseFirestore.instance
          .collection(
              'users') // Assuming tutor is stored under 'tutors' collection
          .doc(tutor.id) // Fetch tutor by their ID
          .collection('ratings') // Access the ratings subcollection
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink(); // Empty widget if no reviews found
        }

        return SizedBox(
          height: 150, // Set the height of the horizontal scroll area
          child: ListView.builder(
            scrollDirection:
                Axis.horizontal, // Set scroll direction to horizontal
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var reviewData =
                  snapshot.data!.docs[index].data() as Map<String, dynamic>;

              // Fetch user details from the users collection using userId
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users') // Fetch user details
                    .doc(reviewData['userId'])
                    .get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }

                  if (userSnapshot.hasError) {
                    return Text('Error: ${userSnapshot.error}');
                  }

                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return const SizedBox
                        .shrink(); // Empty widget if no user data
                  }

                  var userData =
                      userSnapshot.data!.data() as Map<String, dynamic>;

                  return Container(
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(10))),
                    width: 370, // Set a width for each review card
                    padding: const EdgeInsets.all(15),
                    margin: const EdgeInsets.only(
                        right: 10), // Spacing between review cards
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              reviewData['userName'], // Display user's name
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Text(
                                userData['level'] ?? 'Level not found',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Text(
                                userData['standardForm'] ??
                                    'Standard/Form not found',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        // Display the exact rating value and one star icon
                        Row(
                          children: List.generate(5, (index) {
                            // Check if the rating is greater than or equal to the current star index
                            if (reviewData['rating'] >= index + 1) {
                              return const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 20,
                              );
                            }
                            // Check if the rating is between the current index and the next one for half star
                            else if (reviewData['rating'] > index &&
                                reviewData['rating'] < index + 1) {
                              return const Icon(
                                Icons.star_half,
                                color: Colors.amber,
                                size: 20,
                              );
                            }
                            // Default case for empty stars
                            else {
                              return const Icon(
                                Icons.star_border,
                                color: Colors.amber,
                                size: 20,
                              );
                            }
                          }),
                        ),

                        const SizedBox(
                          height: 5,
                        ),
                        // Make the review content scrollable
                        Expanded(
                          child: SingleChildScrollView(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              height: 50,
                              width: double.infinity,
                              child: Text(
                                reviewData['review']?.isEmpty ?? true
                                    ? 'No review provided'
                                    : reviewData['review'], // Review text
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
