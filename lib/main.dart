import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const ETactixApp());
}

class ETactixApp extends StatelessWidget {
  const ETactixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'eTactix AI Platform',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          secondary: Color(0xFF8B5CF6),
          surface: Color(0xFF1E293B),
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  void _changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      DashboardTab(onNavigate: _changeTab),
      const AgentsTab(),
      const CodeGeneratorTab(),
      const AnalyticsTab(),
      const SettingsTab(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _changeTab,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: const Color(0xFF3B82F6),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy_rounded), label: 'الوكلاء'),
          BottomNavigationBarItem(icon: Icon(Icons.code_rounded), label: 'توليد كود'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'التحليلات'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'الإعدادات'),
        ],
      ),
    );
  }
}

// ==================== 1. DASHBOARD TAB ====================
class DashboardTab extends StatelessWidget {
  final Function(int) onNavigate;
  const DashboardTab({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('eTactix AI Workspace'),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('محرك الذكاء الاصطناعي نشط 🚀', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: 8),
                  Text('جاهز لتنفيذ المهام، توليد البرمجيات، وإدارة الوكلاء التلقائية.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('انقر للذهاب إلى القسم المطلوب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildActionCard('AI Agents', 'إدارة الوكلاء والشات', Icons.smart_toy, Colors.blue, () => onNavigate(1)),
                _buildActionCard('Code Generator', 'توليد وتدقيق الكود', Icons.code, Colors.purple, () => onNavigate(2)),
                _buildActionCard('Analytics', 'تحليلات النظام', Icons.bar_chart, Colors.amber, () => onNavigate(3)),
                _buildActionCard('Settings', 'المفاتيح والإعدادات', Icons.settings, Colors.teal, () => onNavigate(4)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 36),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== 2. AI AGENTS TAB ====================
class AgentsTab extends StatefulWidget {
  const AgentsTab({super.key});

  @override
  State<AgentsTab> createState() => _AgentsTabState();
}

class _AgentsTabState extends State<AgentsTab> {
  final List<Map<String, String>> _messages = [
    {'sender': 'agent', 'text': 'مرحباً! أنا وكيل eTactix الذكي. كيف يمكنني مساعدتك اليوم؟'}
  ];
  final TextEditingController _controller = TextEditingController();

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    final userText = _controller.text;
    setState(() {
      _messages.add({'sender': 'user', 'text': userText});
      _controller.clear();
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _messages.add({'sender': 'agent', 'text': 'تم استلام الأمر: "$userText". جاري المعالجة...'});
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الوكلاء التلقائية'), backgroundColor: const Color(0xFF1E293B)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['sender'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: isUser ? null : Border.all(color: Colors.white10),
                    ),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    child: Text(msg['text']!, style: const TextStyle(color: Colors.white)),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'أرسل توجيهاً للوكيل...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Color(0xFF3B82F6)),
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

// ==================== 3. CODE GENERATOR TAB ====================
class CodeGeneratorTab extends StatefulWidget {
  const CodeGeneratorTab({super.key});

  @override
  State<CodeGeneratorTab> createState() => _CodeGeneratorTabState();
}

class _CodeGeneratorTabState extends State<CodeGeneratorTab> {
  final TextEditingController _promptController = TextEditingController();
  String _generatedCode = '// اكتب وصفك أعلاه ثم اضغط على زر التوليد...';

  void _generateCode() {
    if (_promptController.text.trim().isEmpty) return;
    setState(() {
      _generatedCode = '// كود مُولد بناءً على: "${_promptController.text}"\n\n'
          'void executeTask() {\n'
          '  print("Running AI Task...");\n'
          '}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('توليد الكود البرمجي'), backgroundColor: const Color(0xFF1E293B)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _promptController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'وصف السكريبت المطلوب...',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6)),
                  onPressed: _generateCode,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF020617),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _generatedCode,
                    style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 13),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _generatedCode));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الكود!')));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                minimumSize: const Size(double.infinity, 48),
              ),
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('نسخ الكود'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 4. ANALYTICS TAB ====================
class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تحليلات النظام والموارد'), backgroundColor: const Color(0xFF1E293B)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMetricBar('استهلاك المعالج (CPU)', 0.35, Colors.blue),
          const SizedBox(height: 16),
          _buildMetricBar('استهلاك الذاكرة (RAM)', 0.62, Colors.purple),
          const SizedBox(height: 16),
          _buildMetricBar('استجابة الـ API (Latency)', 0.18, Colors.green),
        ],
      ),
    );
  }

  Widget _buildMetricBar(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
            Text('${(value * 100).toInt()}%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: value, color: color, backgroundColor: const Color(0xFF1E293B), minHeight: 8),
      ],
    );
  }
}

// ==================== 5. SETTINGS TAB ====================
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات والربط'), backgroundColor: const Color(0xFF1E293B)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInputField('Gemini API Key', '••••••••••••••••', Icons.key),
          const SizedBox(height: 12),
          _buildInputField('GitHub Personal Access Token', '••••••••••••••••', Icons.code),
        ],
      ),
    );
  }

  Widget _buildInputField(String label, String placeholder, IconData icon) {
    return TextField(
      obscureText: true,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: const Color(0xFF3B82F6)),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
