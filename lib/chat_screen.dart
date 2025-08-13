import 'package:flutter/material.dart';
import 'chatbot_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatbotEvacuacionESPE _chatbotService = ChatbotEvacuacionESPE();
  final TextEditingController _controller = TextEditingController();
  final List<_ChatMessage> _messages = [];

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
    });

    _controller.clear();

    final intent = _chatbotService.detectarIntencion(text);
    final response = _chatbotService.responder(intent);

    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() {
        _messages.add(_ChatMessage(text: response, isUser: false));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistente de Evacuación'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: msg.isUser ? Colors.blueAccent : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        color: msg.isUser ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: _sendMessage,
                      decoration: const InputDecoration(
                        hintText: 'Escribe tu pregunta aquí...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _sendMessage(_controller.text),
                    child: const Text('Enviar'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;

  _ChatMessage({required this.text, required this.isUser});
}
