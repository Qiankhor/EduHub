import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RobotChatPage extends StatefulWidget {
  const RobotChatPage({super.key});

  @override
  State<RobotChatPage> createState() => _RobotChatPageState();
}

class _RobotChatPageState extends State<RobotChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  GenerativeModel? _model;
  bool _isLoading = false;
  bool _showFaq = true; // Initially show FAQ

  // FAQ data
  final List<Map<String, String>> _faqItems = [
    {
      "question": "How can I earn points?",
      "answer":
          "You can earn points by engaging in various activities:\n-Completing a Survey → 10 Points\n-Uploading Past Year Questions → 15 Points per Set\n-Creating & Uploading a Quiz → 20 Points per Quiz\n-You can also purchase points with cash at RM1 = 100 Points."
    },
    {
      "question": "How many points do I need to distribute a survey?",
      "answer": "You need 50 Points per survey."
    },
    {
      "question": "How many points do I need to distribute an event?",
      "answer": "You need 100 Points per event."
    },
    {
      "question": "What can I do with my points?",
      "answer":
          "You can use your points to:\n✅ Join sharing sessions or classes\n✅ Distribute surveys\n✅ Distribute events\n✅ Exchange for rewards\n✅ Cash out"
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeGemini();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeGemini() async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey != null && apiKey.isNotEmpty) {
      _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
    } else {
      // Handle case where API key is missing
      setState(() {
        _messages.add({
          "bot": "Error: Gemini API key not found. Please check your .env file."
        });
      });
    }
  }

  void _sendFaqQuestion(String question, String answer) {
    setState(() {
      _messages.add({"user": question});
      _messages.add({"bot": answer});
      _showFaq = false; // Hide FAQ after selection
    });
  }

  Future<void> _sendMessage() async {
    final userInput = _controller.text.trim();
    if (userInput.isEmpty) return;

    setState(() {
      _messages.add({"user": userInput});
      _isLoading = true;
      _showFaq = false; // Hide FAQ when sending a message
    });

    _controller.clear();

    try {
      if (_model == null) {
        throw Exception("Gemini model not initialized");
      }

      final content = [Content.text(userInput)];
      final response = await _model!.generateContent(content);
      final botReply = response.text ?? "Sorry, I couldn't understand that.";

      setState(() {
        _messages.add({"bot": botReply});
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({"bot": "Error: ${e.toString()}"});
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Gemini AI Chat",
        ),
        centerTitle: true,
        actions: [
          // Button to toggle FAQ visibility
          IconButton(
            icon: Icon(_showFaq ? Icons.close : Icons.help_outline),
            onPressed: () {
              setState(() {
                _showFaq = !_showFaq;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty && !_showFaq
                ? const Center(
                    child: Text(
                      "Send a message to start chatting",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : Stack(
                    children: [
                      // Chat messages
                      ListView.builder(
                        itemCount: _messages.length,
                        padding: const EdgeInsets.all(10),
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isUser = message.containsKey("user");
                          final text =
                              isUser ? message["user"]! : message["bot"]!;

                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              decoration: BoxDecoration(
                                color:
                                    isUser ? Colors.deepOrange : Colors.black54,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Text(
                                text,
                                style: TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // FAQ Overlay
                      if (_showFaq)
                        Container(
                          color: Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  "Frequently Asked Questions",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Divider(height: 1),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: _faqItems.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    return ListTile(
                                      title: Text(
                                        _faqItems[index]["question"]!,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      trailing: const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16),
                                      onTap: () {
                                        _sendFaqQuestion(
                                          _faqItems[index]["question"]!,
                                          _faqItems[index]["answer"]!,
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(10),
              child: CircularProgressIndicator(),
            ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                    child: TextField(
                  controller: _controller,
                  cursorColor: Colors.black,
                  decoration: InputDecoration(
                    hintText: "Ask something...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide:
                          const BorderSide(color: Colors.black), // Normal state
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide:
                          const BorderSide(color: Colors.black), // When focused
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                )),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.deepOrange),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
