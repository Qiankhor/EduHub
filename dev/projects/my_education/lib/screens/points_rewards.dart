import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PointsToRewardsPage extends StatefulWidget {
  @override
  _PointsToRewardsPageState createState() => _PointsToRewardsPageState();
}

class _PointsToRewardsPageState extends State<PointsToRewardsPage> {
  late DocumentReference userRef;
  int userPoints = 0; 

List<Map<String, dynamic>> rewards = [
  {
    'name': 'Gift Card',
    'points': 200,
    'imagePath': 'images/gift_card.png',
  },
  {
    'name': 'Discount Coupon',
    'points': 100,
    'imagePath': 'images/discount_coupon.png',
  },
  {
    'name': 'Free Coffee',
    'points': 50,
    'imagePath': 'images/free_coffee.png',
  },
  {
    'name': 'Movie Ticket',
    'points': 150,
    'imagePath': 'images/movie_ticket.png',
  },
  {
    'name': 'Gym Pass',
    'points': 120,
    'imagePath': 'images/gym_pass.png',
  },
  {
    'name': 'Lunch Voucher',
    'points': 60,
    'imagePath': 'images/lunch_voucher.png',
  },
  {
    'name': 'Headphones Discount',
    'points': 250,
    'imagePath': 'images/headphones_discount.png',
  },
  {
    'name': 'Spa Treatment',
    'points': 300,
    'imagePath': 'images/spa_treatment.png',
  },
  {
    'name': 'Travel Discount',
    'points': 500,
    'imagePath': 'images/travel_discount.png',
  },
  {
    'name': 'Bookstore Coupon',
    'points': 70,
    'imagePath': 'images/bookstore_coupon.png',
  }, 
];

  @override
  void initState() {
    super.initState();
    _initializeUserRef(); // 初始化用户引用
  }

  // 初始化用户引用并获取积分
  void _initializeUserRef() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      userRef = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
      _getUserPoints(); // 获取用户积分
    } else {
      _showDialog('Error', 'User not logged in.');
    }
  }

  // 实时监听用户积分的变化
  void _getUserPoints() {
    userRef.snapshots().listen((snapshot) {
      if (snapshot.exists) {
        setState(() {
          userPoints = snapshot['points'] ?? 0;
        });
      }
    });
  }

  // 兑换奖励时更新用户积分
  Future<void> _redeemReward(String rewardName, int rewardPoints) async {
    if (userPoints >= rewardPoints) {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(userRef);

        if (snapshot.exists) {
          int currentPoints = snapshot['points'] ?? 0;
          if (currentPoints >= rewardPoints) {
            transaction.update(userRef, {'points': currentPoints - rewardPoints});
            _showDialog('Success', 'You have redeemed $rewardName!');
          } else {
            _showDialog('Error', 'Insufficient points to redeem this reward.');
          }
        }
      });
    } else {
      _showDialog('Error', 'Insufficient points to redeem this reward.');
    }
  }

  // 显示弹窗
  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Redeem Rewards'),
      centerTitle: true,
    ),
    body: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            child: Text(
              'Your Points: $userPoints',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: rewards.length,
              itemBuilder: (context, index) {
                var reward = rewards[index];
                bool canRedeem = userPoints >= reward['points'];

                return Card(
                  elevation: 2, 
                  margin: EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0), // 内边距
                    child: Row(
                      children: [
                        // 突出显示的图片
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                          /*  boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.5),
                                spreadRadius: 2,
                                blurRadius: 3,
                                offset: Offset(0, 3), // 阴影偏移
                              ),
                            ],*/ 
                            image: DecorationImage(
                              image: AssetImage(reward['imagePath']),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        SizedBox(width: 16), // 图片和文字之间的间距
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reward['name'],
                                style: TextStyle(
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${reward['points']} Points',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            backgroundColor: canRedeem ? Colors.orange.shade700 : Colors.grey,
                           
                          ),
                          onPressed: canRedeem
                              ? () => _redeemReward(reward['name'], reward['points'])
                              : null,
                          child: Text('Redeem', style: TextStyle(color: Colors.white),),
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
  );
}

}