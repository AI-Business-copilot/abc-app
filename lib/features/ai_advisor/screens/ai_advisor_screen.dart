import 'package:flutter/material.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import '../models/ai_message_model.dart';
import '../services/ai_advisor_service.dart';

class AiAdvisorScreen extends StatefulWidget {
  const AiAdvisorScreen({super.key});

  @override
  State<AiAdvisorScreen> createState() => _AiAdvisorScreenState();
}

class _AiAdvisorScreenState extends State<AiAdvisorScreen> {
  final _advisorService = AiAdvisorService();
  final _textController = TextEditingController();
  final List<AiMessage> _messages = [
    AiMessage(
      text: 'Chào bạn! Tôi là AI Business Copilot. Bạn có thể hỏi tôi về doanh thu, tồn kho, các mặt hàng cần nhập hoặc lô hàng sắp hết hạn.',
      isUser: false,
      timestamp: DateTime.now(),
    ),
  ];
  bool _isReplying = false;

  Future<void> _sendMessage(String query) async {
    final text = query.trim();
    if (text.isEmpty) return;

    _textController.clear();
    setState(() {
      _messages.add(AiMessage(text: text, isUser: true, timestamp: DateTime.now()));
      _isReplying = true;
    });

    final reply = await _advisorService.askAdvisor(text);
    if (mounted) {
      setState(() {
        _messages.add(AiMessage(text: reply, isUser: false, timestamp: DateTime.now()));
        _isReplying = false;
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('AI Business Advisor (MOB-07)'),
      ),
      body: Column(
        children: [
          // Chat history
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final msg = _messages[idx];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: msg.isUser ? AppTheme.primary : AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: msg.isUser ? null : Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: msg.isUser ? Colors.white : AppTheme.primary,
                        height: 1.35,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isReplying)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
              ),
            ),

          // Quick Questions
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                _buildQuickChip('Doanh thu hôm nay'),
                _buildQuickChip('Tồn kho thế nào?'),
                _buildQuickChip('Lô nào sắp hết hạn?'),
                _buildQuickChip('Gợi ý nhập hàng'),
              ],
            ),
          ),

          // Input Row
          Container(
            padding: const EdgeInsets.all(10),
            color: AppTheme.surface,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(fontSize: 13.5),
                      decoration: const InputDecoration(
                        hintText: 'Hỏi AI về kinh doanh, tồn kho...',
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () => _sendMessage(_textController.text),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    style: IconButton.styleFrom(backgroundColor: AppTheme.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11.5)),
        onPressed: () => _sendMessage(label),
      ),
    );
  }
}
