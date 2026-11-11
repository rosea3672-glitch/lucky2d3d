import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

void main() {
  runApp(const Lucky2D3DApp());
}

class Lucky2D3DApp extends StatelessWidget {
  const Lucky2D3DApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lucky2D3D',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF100B20),
        primaryColor: const Color(0xFFA855F7),
      ),
      home: const SplashScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// Dart Native HttpClient (Package မလိုဘဲ Firebase Collections Auto ဆောက်ပေးမည့် Engine)
// ---------------------------------------------------------------------------
class FirebaseAutoEngine {
  static const String projectId = "lucky2d3d-859cc";
  static const String baseUrl = "firestore.googleapis.com";
  static const String basePath = "/v1/projects/$projectId/databases/(default)/documents";

  static Future _sendPatch(String endpoint, Map bodyData) async {
    try {
      final client = HttpClient();
      final request = await client.patchUrl(Uri.https(baseUrl, "$basePath$endpoint"));
      request.headers.set('content-type', 'application/json');
      request.add(utf8.encode(jsonEncode(bodyData)));
      final response = await request.close();
      client.close();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future _sendGet(String endpoint) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.https(baseUrl, "$basePath$endpoint"));
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();
      if (response.statusCode == 200) {
        return jsonDecode(responseBody);
      }
    } catch (e) {
      //
    }
    return null;
  }

  static Future initAutoCollections() async {
    _sendPatch("/markets/2D_1201PM", {
      "fields": {
        "marketName": {"stringValue": "12:01 PM (မနက်ပိုင်း)"},
        "isOpen": {"booleanValue": true},
        "closeTime": {"stringValue": "11:55 AM"},
        "multiplier": {"integerValue": "85"},
        "resultNumber": {"stringValue": ""},
        "date": {"stringValue": "2026-11-11"}
      }
    });

    _sendPatch("/markets/2D_0430PM", {
      "fields": {
        "marketName": {"stringValue": "04:30 PM (ညနေပိုင်း)"},
        "isOpen": {"booleanValue": true},
        "closeTime": {"stringValue": "04:20 PM"},
        "multiplier": {"integerValue": "85"},
        "resultNumber": {"stringValue": ""},
        "date": {"stringValue": "2026-11-11"}
      }
    });

    _sendPatch("/markets/3D_MONTHLY", {
      "fields": {
        "marketName": {"stringValue": "MM3D (လစဉ် ၁ ရက်၊ ၁၆ ရက်)"},
        "isOpen": {"booleanValue": true},
        "closeTime": {"stringValue": "03:00 PM"},
        "multiplier": {"integerValue": "600"},
        "resultNumber": {"stringValue": ""},
        "date": {"stringValue": "2026-11-16"}
      }
    });

    _sendPatch("/number_limits/2D_LIMITS", {
      "fields": {
        "maxLimitPerNumber": {"integerValue": "50000"},
        "closedNumbers": {
          "arrayValue": {
            "values": [
              {"stringValue": "18"},
              {"stringValue": "69"},
              {"stringValue": "85"}
            ]
          }
        },
        "nearLimitNumbers": {
          "arrayValue": {
            "values": [
              {"stringValue": "00"},
              {"stringValue": "24"},
              {"stringValue": "77"}
            ]
          }
        }
      }
    });
  }

  static Future fetchUserBalance(String phone) async {
    final data = await _sendGet("/users/$phone");
    if (data != null && data['fields'] != null && data['fields']['balance'] != null) {
      var val = data['fields']['balance']['integerValue'] ?? data['fields']['balance']['doubleValue'];
      return double.tryParse(val.toString()) ?? 15000.0;
    }
    return 15000.0;
  }

  static Future sendVoucherToFirebase(Map vData) async {
    String docId = vData['id'];
    _sendPatch("/vouchers/$docId", {
      "fields": {
        "voucherId": {"stringValue": vData['id']},
        "category": {"stringValue": vData['type']},
        "session": {"stringValue": vData['time']},
        "total": {"integerValue": vData['total'].toString()},
        "status": {"stringValue": vData['status']},
        "numbers": {
          "arrayValue": {
            "values": (vData['numbers'] as List).map((n) => {"stringValue": n.toString()}).toList()
          }
        },
        "createdAt": {"stringValue": DateTime.now().toIso8601String()}
      }
    });
  }
}

// ---------------------------------------------------------------------------
// Global State
// ---------------------------------------------------------------------------
class AppState {
  static bool isLoggedIn = false;
  static String currentUser = "UPaing";
  static String currentPhone = "09683005344";
  static double balance = 15000.0;

  static List adminBannerUrls = [
    "https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=800&q=80",
    "https://images.unsplash.com/photo-1511512578047-dfb367046420?w=800&q=80",
    "https://images.unsplash.com/photo-1579546929518-9e396f3cc809?w=800&q=80",
  ];

  static List vouchers2D = [];
  static List vouchers3D = [];

  static int getNumberLimitStatus(String num) {
    if (num == "18" || num == "69" || num == "85") return 2; // Red (ပိတ်)
    if (num == "00" || num == "24" || num == "77") return 1; // Yellow (ပြည့်ခါနီး)
    return 0; // Green (ရသေး)
  }
}

// ---------------------------------------------------------------------------
// ၁။ Splash Screen
// ---------------------------------------------------------------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _logoSize = 150.0;
  Timer? _animTimer;

  @override
  void initState() {
    super.initState();
    _animTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (!mounted) return;
      setState(() {
        _logoSize = _logoSize == 150.0 ? 165.0 : 150.0;
      });
    });

    FirebaseAutoEngine.initAutoCollections();

    Timer(const Duration(seconds: 3), () async {
      _animTimer?.cancel();
      AppState.balance = await FirebaseAutoEngine.fetchUserBalance(AppState.currentPhone);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AppState.isLoggedIn 
              ? const MainNavigationHolder() 
              : const LoginScreen(),
        ),
      );
    });
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0A1E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              width: _logoSize,
              height: _logoSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEAB308).withOpacity(0.45),
                    blurRadius: 35,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: ClipOval(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFBBF24), width: 3),
                    gradient: const RadialGradient(
                      colors: [Color(0xFF2E1065), Color(0xFF0F172A)],
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.workspace_premium, color: Color(0xFFFBBF24), size: 48),
                      SizedBox(height: 4),
                      Text(
                        "Lucky\n2D3D",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFFBBF24),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 1.2,
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "Lucky2D3D",
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1738),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: const Text(
                "MM2D (85 ဆ)  •  MM3D (600 ဆ)",
                style: TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(Color(0xFFFBBF24)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ၂။ Authentication Panels (Login, Register, Forgot Password)
// ---------------------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController(text: "09683005344");
  final TextEditingController _passwordController = TextEditingController(text: "123456");
  bool _obscurePassword = true;

  void _handleLogin() async {
    if (_phoneController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ဖုန်းနံပါတ်နှင့် လျှို့ဝှက်နံပါတ် ဖြည့်သွင်းပါ")),
      );
      return;
    }

    double b = await FirebaseAutoEngine.fetchUserBalance(_phoneController.text.trim());

    setState(() {
      AppState.isLoggedIn = true;
      AppState.currentPhone = _phoneController.text.trim();
      AppState.balance = b;
    });

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainNavigationHolder()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF1B1333);
    const purpleAccent = Color(0xFFA855F7);
    const goldAccent = Color(0xFFFBBF24);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: goldAccent, width: 2),
                    color: cardBg,
                  ),
                  child: const Icon(Icons.lock_outline, color: goldAccent, size: 40),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  "Lucky2D3D သို့ ဝင်ရောက်ရန်",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(height: 30),

              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "ဖုန်းနံပါတ်",
                  prefixIcon: const Icon(Icons.phone_android, color: Colors.white54),
                  filled: true,
                  fillColor: cardBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "လျှို့ဝှက်နံပါတ် (Password)",
                  prefixIcon: const Icon(Icons.lock, color: Colors.white54),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: cardBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                    );
                  },
                  child: const Text("စကားဝှက်မေ့နေပါသလား?", style: TextStyle(color: goldAccent, fontSize: 12)),
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: purpleAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _handleLogin,
                child: const Text("အကောင့်ဝင်မည်", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("အကောင့်အသစ် မရှိသေးဘူးလား? ", style: TextStyle(color: Colors.white60, fontSize: 13)),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterScreen()),
                      );
                    },
                    child: const Text(
                      "အကောင့်ဖွင့်မည်",
                      style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _handleRegister() {
    if (_nameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("အချက်အလက် အားလုံး ဖြည့်သွင်းပါ")),
      );
      return;
    }

    setState(() {
      AppState.isLoggedIn = true;
      AppState.currentUser = _nameController.text.trim();
      AppState.currentPhone = _phoneController.text.trim();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("အကောင့်ဖွင့်ခြင်း အောင်မြင်ပါသည်")),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MainNavigationHolder()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF1B1333);
    const purpleAccent = Color(0xFFA855F7);

    return Scaffold(
      appBar: AppBar(backgroundColor: const Color(0xFF17102B), elevation: 0, title: const Text("အကောင့်အသစ်ဖွင့်ခြင်း")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: "အမည် (Name)",
                prefixIcon: const Icon(Icons.person, color: Colors.white54),
                filled: true,
                fillColor: cardBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "ဖုန်းနံပါတ်",
                prefixIcon: const Icon(Icons.phone, color: Colors.white54),
                filled: true,
                fillColor: cardBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "လျှို့ဝှက်နံပါတ် သတ်မှတ်ပါ",
                prefixIcon: const Icon(Icons.lock, color: Colors.white54),
                filled: true,
                fillColor: cardBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: purpleAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _handleRegister,
              child: const Text("အကောင့်ဖွင့်မည်", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF1B1333);
    const purpleAccent = Color(0xFFA855F7);

    return Scaffold(
      appBar: AppBar(backgroundColor: const Color(0xFF17102B), elevation: 0, title: const Text("စကားဝှက် ပြန်လည်ရယူခြင်း")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "စကားဝှက် မေ့သွားပါက မိမိအကောင့်ဖွင့်ထားသော ဖုန်းနံပါတ်ကို ထည့်သွင်းပါ သို့မဟုတ် Admin ထံ တိုက်ရိုက်ဆက်သွယ်ပါ။",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "ဖုန်းနံပါတ်",
                prefixIcon: const Icon(Icons.phone, color: Colors.white54),
                filled: true,
                fillColor: cardBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: purpleAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Admin ထံ စကားဝှက်ပြန်ယူရန် တောင်းဆိုမှု ပေးပို့လိုက်ပါပြီ")),
                );
                Navigator.pop(context);
              },
              child: const Text("စကားဝှက် ပြန်လည်တောင်းဆိုမည်", style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ၃။ Live Marquee Text Widget (ဘယ်မှညာသို့ အမြဲပြေးနေမည့် စာကြောင်း)
// ---------------------------------------------------------------------------
class MarqueeTextWidget extends StatefulWidget {
  final String text;
  const MarqueeTextWidget({super.key, required this.text});

  @override
  State<MarqueeTextWidget> createState() => _MarqueeTextWidgetState();
}

class _MarqueeTextWidgetState extends State<MarqueeTextWidget> {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScrolling();
    });
  }

  void _startScrolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (_scrollController.hasClients) {
        double maxScroll = _scrollController.position.maxScrollExtent;
        double currentScroll = _scrollController.offset;
        if (currentScroll >= maxScroll) {
          _scrollController.jumpTo(0.0);
        } else {
          _scrollController.jumpTo(currentScroll + 1.5);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1738),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign, color: Color(0xFFFBBF24), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: ListView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                Center(
                  child: Text(
                    widget.text,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ၄။ Main Navigation Holder
// ---------------------------------------------------------------------------
class MainNavigationHolder extends StatefulWidget {
  const MainNavigationHolder({super.key});

  @override
  State<MainNavigationHolder> createState() => _MainNavigationHolderState();
}

class _MainNavigationHolderState extends State<MainNavigationHolder> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List pages = [
      HomeScreen(onRefresh: () => setState(() {})),
      const VoucherTabsScreen(),
      WalletScreen(onRefresh: () => setState(() {})),
      const Center(child: Text("သတင်းနှင့် အသိပေးချက်များ မရှိသေးပါ", style: TextStyle(color: Colors.white70))),
      ProfileScreen(onRefresh: () => setState(() {})),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white10, width: 0.8)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: const Color(0xFF17102B),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFA855F7),
          unselectedItemColor: Colors.white38,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "ပင်မ"),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: "ဘောင်ချာ"),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: "ပိုက်ဆံအိတ်"),
            BottomNavigationBarItem(icon: Icon(Icons.notifications_active), label: "သတင်း"),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "ကျွန်ုပ်"),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ၅။ Home Screen
// ---------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  final VoidCallback onRefresh;
  const HomeScreen({super.key, required this.onRefresh});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _bannerController = PageController();
  int _bannerIndex = 0;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_bannerController.hasClients && AppState.adminBannerUrls.isNotEmpty) {
        _bannerIndex = (_bannerIndex + 1) % AppState.adminBannerUrls.length;
        _bannerController.animateToPage(
          _bannerIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const purpleAccent = Color(0xFFA855F7);
    const goldAccent = Color(0xFFFBBF24);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF17102B),
        elevation: 0,
        title: const Text("Lucky2D3D", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1.2)),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.white70), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 170,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: PageView.builder(
                  controller: _bannerController,
                  itemCount: AppState.adminBannerUrls.length,
                  itemBuilder: (context, index) {
                    return Image.network(
                      AppState.adminBannerUrls[index],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF261947),
                        child: const Center(
                          child: Text("Lucky2D3D Poster Banner", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),

            const MarqueeTextWidget(
              text: "★ Lucky2D3D မှ ကြိုဆိုပါသည် ★ MM2D (၈၅ ဆ) နေ့စဉ် ၁၂:၀၁ နံနက်ပိုင်းနှင့် ၀၄:၃၀ ညနေပိုင်း ထွက်ပါသည် ★ MM3D (၆၀၀ ဆ) လစဉ် ၁ ရက် နှင့် ၁၆ ရက်တွင် ထွက်ပါသည် ★ KPay / WavePay ဖြင့် အချိန်မရွေး ငွေသွင်း/ထုတ် ပြုလုပ်နိုင်ပါသည် ★",
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF261947), Color(0xFF191032)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: purpleAccent.withOpacity(0.35)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.account_balance_wallet, color: goldAccent, size: 24),
                      SizedBox(width: 10),
                      Text("အကောင့်လက်ကျန်ငွေ", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Text(
                    "${AppState.balance.toStringAsFixed(0)} Ks",
                    style: const TextStyle(color: goldAccent, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text("2D/3D ထိုးရန်ရွေးချယ်ပါ", style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),

            _buildMarketCard(
              title: "MYANMAR 2D",
              multiplierText: "အလျော် (၈၅) ဆ",
              scheduleText: "12:01 PM  |  04:30 PM (မနက်/ညနေ)",
              badgeText: "2D",
              badgeColors: const [Color(0xFFFACC15), Color(0xFF22C55E), Color(0xFFEF4444), Color(0xFFFACC15)],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Myanmar2DSessionsScreen()),
                ).then((_) {
                  setState(() {});
                  widget.onRefresh();
                });
              },
            ),
            const SizedBox(height: 16),

            _buildMarketCard(
              title: "MYANMAR 3D",
              multiplierText: "အလျော် (၆၀၀) ဆ",
              scheduleText: "၁ ရက် ၊ ၁၆ ရက် (03:30 PM)",
              badgeText: "3D",
              badgeColors: const [Color(0xFFFFFFFF), Color(0xFF38BDF8), Color(0xFF1D4ED8), Color(0xFFFFFFFF)],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Myanmar3DPadScreen()),
                ).then((_) {
                  setState(() {});
                  widget.onRefresh();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketCard({
    required String title,
    required String multiplierText,
    required String scheduleText,
    required String badgeText,
    required List badgeColors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1333),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(colors: [badgeColors[0], badgeColors[1], badgeColors[2], badgeColors[3]]),
              ),
              padding: const EdgeInsets.all(3.5),
              child: Container(
                decoration: const BoxDecoration(color: Color(0xFF140D26), shape: BoxShape.circle),
                child: Center(
                  child: Text(badgeText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(multiplierText, style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(scheduleText, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ၆။ MM2D Session Screen
// ---------------------------------------------------------------------------
class Myanmar2DSessionsScreen extends StatelessWidget {
  const Myanmar2DSessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF17102B),
        elevation: 0,
        title: const Text("MM2D ပွဲစဉ် ရွေးချယ်ပါ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSessionTile(
              context: context,
              sessionName: "12:01 PM (မနက်ပိုင်းပွဲစဉ်)",
              closeTimeText: "ထီပိတ်ချိန်: 11:55 AM",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Myanmar2DGridScreen(sessionName: "12:01 PM")),
                );
              },
            ),
            const SizedBox(height: 14),
            _buildSessionTile(
              context: context,
              sessionName: "04:30 PM (ညနေပိုင်းပွဲစဉ်)",
              closeTimeText: "ထီပိတ်ချိန်: 04:20 PM",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Myanmar2DGridScreen(sessionName: "04:30 PM")),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTile({
    required BuildContext context,
    required String sessionName,
    required String closeTimeText,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1333),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sessionName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text(closeTimeText, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
              ),
              child: const Text("ထိုး၍ရပါသည်", style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ၇။ Myanmar 2D Grid Screen (အမြန်ရွေး၊ ခွေထိုး၊ လိမစ်များ၊ Pop-up ပြေစာ)
// ---------------------------------------------------------------------------
class Myanmar2DGridScreen extends StatefulWidget {
  final String sessionName;
  const Myanmar2DGridScreen({super.key, required this.sessionName});

  @override
  State<Myanmar2DGridScreen> createState() => _Myanmar2DGridScreenState();
}

class _Myanmar2DGridScreenState extends State<Myanmar2DGridScreen> {
  final Set _selected = {};
  final TextEditingController _amountController = TextEditingController(text: "500");
  int _activePanel = 0; 
  final Set _khwayDigits = {};

  void _applyQuickSelect(String type) {
    setState(() {
      for (int i = 0; i <= 99; i++) {
        String num = i.toString().padLeft(2, '0');
        if (AppState.getNumberLimitStatus(num) == 2) continue;
        
        int d1 = int.parse(num[0]);
        int d2 = int.parse(num[1]);

        switch (type) {
          case 'အပူး':
            if (d1 == d2) _selected.add(num);
            break;
          case 'ပါဝါ':
            if ((d1 + 5) % 10 == d2 || (d2 + 5) % 10 == d1) _selected.add(num);
            break;
          case 'နတ်ခတ်':
            List natKhat = ['07', '70', '18', '81', '24', '42', '35', '53', '69', '96'];
            if (natKhat.contains(num)) _selected.add(num);
            break;
          case 'ညီကို':
            if ((d1 + 1) % 10 == d2 || (d2 + 1) % 10 == d1) _selected.add(num);
            break;
          case 'စုံစုံ':
            if (d1 % 2 == 0 && d2 % 2 == 0) _selected.add(num);
            break;
          case 'မမ':
            if (d1 % 2 != 0 && d2 % 2 != 0) _selected.add(num);
            break;
          case 'စုံမ':
            if (d1 % 2 == 0 && d2 % 2 != 0) _selected.add(num);
            break;
          case 'မစုံ':
            if (d1 % 2 != 0 && d2 % 2 == 0) _selected.add(num);
            break;
        }
      }
    });
  }

  void _applyHteik(int digit) {
    setState(() {
      for (int i = 0; i <= 9; i++) {
        String num = "$digit$i";
        if (AppState.getNumberLimitStatus(num) != 2) _selected.add(num);
      }
    });
  }

  void _applyPate(int digit) {
    setState(() {
      for (int i = 0; i <= 9; i++) {
        String num = "$i$digit";
        if (AppState.getNumberLimitStatus(num) != 2) _selected.add(num);
      }
    });
  }

  void _applyBrake(int brakeVal) {
    setState(() {
      for (int i = 0; i <= 99; i++) {
        String num = i.toString().padLeft(2, '0');
        int sum = int.parse(num[0]) + int.parse(num[1]);
        if (sum % 10 == brakeVal) {
          if (AppState.getNumberLimitStatus(num) != 2) _selected.add(num);
        }
      }
    });
  }

  void _generateKhway(bool withPair) {
    if (_khwayDigits.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ခွေထိုးရန် အနည်းဆုံး ဂဏန်း ၂ လုံး ရွေးပေးပါ")),
      );
      return;
    }

    List list = _khwayDigits.toList();
    setState(() {
      for (int i = 0; i < list.length; i++) {
        for (int j = 0; j < list.length; j++) {
          if (!withPair && i == j) continue;
          String num = "${list[i]}${list[j]}";
          if (AppState.getNumberLimitStatus(num) != 2) {
            _selected.add(num);
          }
        }
      }
    });
  }

  void _show2DVoucherModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF17102B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("2D ဘောင်ချာများ (${widget.sessionName})", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text("လက်ကျန်: ${AppState.balance.toStringAsFixed(0)} Ks", style: const TextStyle(color: Color(0xFFFBBF24))),
              ],
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: AppState.vouchers2D.isEmpty
                  ? const Center(child: Text("2D ဘောင်ချာ မရှိသေးပါ", style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      itemCount: AppState.vouchers2D.length,
                      itemBuilder: (ctx, i) {
                        final v = AppState.vouchers2D[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text("${v['id']} | ${v['time']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text("ဂဏန်း: ${v['numbers'].join(', ')}"),
                          trailing: Text("${v['total']} Ks", style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitBet() {
    int amt = int.tryParse(_amountController.text) ?? 0;
    int total = _selected.length * amt;

    if (AppState.balance < total) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("လက်ကျန်ငွေ မလုံလောက်ပါ။ ပိုက်ဆံအိတ်တွင် ငွေဖြည့်ပါ။")));
      return;
    }

    final newVoucher = {
      "id": "2D-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}",
      "type": "MM2D (၈၅ ဆ)",
      "numbers": _selected.toList(),
      "total": total,
      "time": widget.sessionName,
      "status": "စောင့်ဆိုင်းဆဲ",
    };

    FirebaseAutoEngine.sendVoucherToFirebase(newVoucher);

    setState(() {
      AppState.balance -= total;
      AppState.vouchers2D.insert(0, newVoucher);
      _selected.clear();
      _khwayDigits.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("2D ထိုးပြီးပါပြီ။ Database ထဲသို့ တိုက်ရိုက်သိမ်းဆည်းလိုက်ပါပြီ။")));
  }

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF1B1333);
    const goldAccent = Color(0xFFFBBF24);
    const purpleAccent = Color(0xFFA855F7);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF17102B),
        elevation: 0,
        title: Text("MM2D - ${widget.sessionName}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: _show2DVoucherModal,
            icon: const Icon(Icons.receipt_long, color: goldAccent, size: 18),
            label: const Text("ဘောင်ချာ", style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF140D26),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activePanel = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _activePanel == 0 ? purpleAccent : cardBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Text("အမြန်ရွေး", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activePanel = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _activePanel == 1 ? purpleAccent : cardBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Text("ခွေထိုး", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          _activePanel == 0 ? _buildQuickSelectPanel() : _buildKhwayPanel(),

          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 1.35,
              ),
              itemCount: 100,
              itemBuilder: (context, index) {
                final numStr = index.toString().padLeft(2, '0');
                final isSelected = _selected.contains(numStr);
                final limitStatus = AppState.getNumberLimitStatus(numStr);

                Color lineIndicatorColor = const Color(0xFF10B981);
                if (limitStatus == 1) lineIndicatorColor = const Color(0xFFFBBF24);
                if (limitStatus == 2) lineIndicatorColor = const Color(0xFFFF4646);

                return GestureDetector(
                  onTap: () {
                    if (limitStatus == 2) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$numStr ဂဏန်း ပိတ်ထားပါသည်")));
                      return;
                    }
                    setState(() {
                      if (isSelected) {
                        _selected.remove(numStr);
                      } else {
                        _selected.add(numStr);
                      }
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? goldAccent : cardBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? goldAccent : Colors.white10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          numStr,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.black : (limitStatus == 2 ? Colors.white38 : Colors.white),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 24,
                          height: 3,
                          decoration: BoxDecoration(
                            color: lineIndicatorColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(14),
            color: const Color(0xFF17102B),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("ရွေးပြီး: ${_selected.length} ကွက် | ${widget.sessionName}", style: const TextStyle(color: Colors.white60, fontSize: 11)),
                      Text(
                        "${_selected.length * (int.tryParse(_amountController.text) ?? 0)} Ks",
                        style: const TextStyle(color: goldAccent, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 85,
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: cardBg,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: goldAccent, foregroundColor: Colors.black),
                  onPressed: _selected.isEmpty ? null : _submitBet,
                  child: const Text("ထိုးမည်", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQuickSelectPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: const Color(0xFF1B1333),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickBtn("အပူး", () => _applyQuickSelect("အပူး")),
                _buildQuickBtn("ပါဝါ", () => _applyQuickSelect("ပါဝါ")),
                _buildQuickBtn("နတ်ခတ်", () => _applyQuickSelect("နတ်ခတ်")),
                _buildQuickBtn("ညီကို", () => _applyQuickSelect("ညီကို")),
                _buildQuickBtn("စုံစုံ", () => _applyQuickSelect("စုံစုံ")),
                _buildQuickBtn("မမ", () => _applyQuickSelect("မမ")),
                _buildQuickBtn("စုံမ", () => _applyQuickSelect("စုံမ")),
                _buildQuickBtn("မစုံ", () => _applyQuickSelect("မစုံ")),
                TextButton(
                  onPressed: () => setState(() => _selected.clear()),
                  child: const Text("ရှင်းထုတ်", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                )
              ],
            ),
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPopupSelectBtn("ထိပ်", (digit) => _applyHteik(digit)),
                _buildPopupSelectBtn("ပိတ်", (digit) => _applyPate(digit)),
                _buildPopupSelectBtn("ဘရိတ်", (digit) => _applyBrake(digit)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildKhwayPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFF1B1333),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("ရွေးထားသောဂဏန်း: ${_khwayDigits.join(', ')}", style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold, fontSize: 13)),
              TextButton(
                onPressed: () => setState(() => _khwayDigits.clear()),
                child: const Text("ဖျက်မည်", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
              )
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(10, (i) {
                bool isDigitSelected = _khwayDigits.contains(i);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isDigitSelected) {
                        _khwayDigits.remove(i);
                      } else {
                        _khwayDigits.add(i);
                      }
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDigitSelected ? const Color(0xFFA855F7) : const Color(0xFF100B20),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white24),
                    ),
                    alignment: Alignment.center,
                    child: Text("$i", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  onPressed: () => _generateKhway(true),
                  child: const Text("ခွေပူး", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4646)),
                  onPressed: () => _generateKhway(false),
                  child: const Text("ခွေသီးသန့်", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildQuickBtn(String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white24),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: onTap,
        child: Text(title, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ),
    );
  }

  Widget _buildPopupSelectBtn(String label, Function(int) onSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF261947),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF17102B),
              title: Text("$label ရွေးချယ်ပါ", style: const TextStyle(fontSize: 16)),
              content: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(10, (digit) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA855F7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      onSelected(digit);
                    },
                    child: Text("$digit $label", style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                }),
              ),
            ),
          );
        },
        child: Text("$label ရွေးရန်", style: const TextStyle(fontSize: 12, color: Color(0xFFFBBF24))),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ၈။ Myanmar 3D Pad Screen
// ---------------------------------------------------------------------------
class Myanmar3DPadScreen extends StatefulWidget {
  const Myanmar3DPadScreen({super.key});

  @override
  State<Myanmar3DPadScreen> createState() => _Myanmar3DPadScreenState();
}

class _Myanmar3DPadScreenState extends State<Myanmar3DPadScreen> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _amountController = TextEditingController(text: "500");
  final List _numbersList = [];

  void _show3DVoucherModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF17102B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("3D ဘောင်ချာများ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text("လက်ကျန်: ${AppState.balance.toStringAsFixed(0)} Ks", style: const TextStyle(color: Color(0xFFFBBF24))),
              ],
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: AppState.vouchers3D.isEmpty
                  ? const Center(child: Text("3D ဘောင်ချာ မရှိသေးပါ", style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      itemCount: AppState.vouchers3D.length,
                      itemBuilder: (ctx, i) {
                        final v = AppState.vouchers3D[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text("${v['id']} | ${v['time']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text("ဂဏန်း: ${v['numbers'].join(', ')}"),
                          trailing: Text("${v['total']} Ks", style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _calculateReverse() {
    String text = _inputController.text.trim();
    if (text.length != 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ဂဏန်း ၃ လုံး တိတိ ရိုက်ပါ")));
      return;
    }

    List digits = text.split('');
    Set permutations = {};

    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        for (int k = 0; k < 3; k++) {
          if (i != j && j != k && i != k) {
            permutations.add("${digits[i]}${digits[j]}${digits[k]}");
          }
        }
      }
    }

    setState(() {
      for (var p in permutations) {
        if (!_numbersList.contains(p)) _numbersList.add(p);
      }
      _inputController.clear();
    });
  }

  void _addSingle() {
    String text = _inputController.text.trim();
    if (text.length == 3 && !_numbersList.contains(text)) {
      setState(() {
        _numbersList.add(text);
        _inputController.clear();
      });
    }
  }

  void _submit3DBet() {
    int amt = int.tryParse(_amountController.text) ?? 0;
    int total = _numbersList.length * amt;

    if (AppState.balance < total) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("လက်ကျန်ငွေ မလုံလောက်ပါ။ ပိုက်ဆံအိတ်တွင် ငွေဖြည့်ပါ။")));
      return;
    }

    final newVoucher = {
      "id": "3D-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}",
      "type": "MM3D (၆၀၀ ဆ)",
      "numbers": List.from(_numbersList),
      "total": total,
      "time": "03:30 PM",
      "status": "စောင့်ဆိုင်းဆဲ",
    };

    FirebaseAutoEngine.sendVoucherToFirebase(newVoucher);

    setState(() {
      AppState.balance -= total;
      AppState.vouchers3D.insert(0, newVoucher);
      _numbersList.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("3D အောင်မြင်စွာ ထိုးပြီးပါပြီ။ Database သို့ သိမ်းဆည်းလိုက်ပါပြီ။")));
  }

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF1B1333);
    const coralRed = Color(0xFFFF4646);
    const goldAccent = Color(0xFFFBBF24);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF17102B),
        elevation: 0,
        title: const Text("MYANMAR 3D (၆၀၀ ဆ)", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: _show3DVoucherModal,
            icon: const Icon(Icons.receipt_long, color: goldAccent, size: 18),
            label: const Text("ဘောင်ချာ", style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    keyboardType: TextInputType.number,
                    maxLength: 3,
                    decoration: InputDecoration(
                      counterText: "",
                      hintText: "ဂဏန်း ၃ လုံး (ဥပမာ-368)",
                      filled: true,
                      fillColor: cardBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  onPressed: _addSingle,
                  child: const Text("ထည့်မည်"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: coralRed),
                  onPressed: _calculateReverse,
                  child: const Text("အပြန် (R)"),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _numbersList.isEmpty
                  ? const Center(child: Text("ရွေးချယ်ထားသော 3D ဂဏန်းများ မရှိသေးပါ", style: TextStyle(color: Colors.white54)))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.5,
                      ),
                      itemCount: _numbersList.length,
                      itemBuilder: (context, i) {
                        return Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: coralRed.withOpacity(0.5)),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_numbersList[i], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              GestureDetector(
                                onTap: () => setState(() => _numbersList.removeAt(i)),
                                child: const Icon(Icons.close, size: 16, color: Colors.white54),
                              )
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF17102B),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("ရွေးပြီး: ${_numbersList.length} ကွက်", style: const TextStyle(color: Colors.white60, fontSize: 11)),
                        Text(
                          "${_numbersList.length * (int.tryParse(_amountController.text) ?? 0)} Ks",
                          style: const TextStyle(color: goldAccent, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 85,
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: cardBg,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: coralRed),
                    onPressed: _numbersList.isEmpty ? null : _submit3DBet,
                    child: const Text("3D ထိုးမည်", style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ၉။ Voucher Tabs Screen
// ---------------------------------------------------------------------------
class VoucherTabsScreen extends StatefulWidget {
  const VoucherTabsScreen({super.key});

  @override
  State<VoucherTabsScreen> createState() => _VoucherTabsScreenState();
}

class _VoucherTabsScreenState extends State<VoucherTabsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF17102B),
        elevation: 0,
        title: const Text("ဘောင်ချာမှတ်တမ်းများ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFA855F7),
          labelColor: const Color(0xFFA855F7),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: "2D ဘောင်ချာများ"),
            Tab(text: "3D ဘောင်ချာများ"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVoucherList(AppState.vouchers2D, "2D"),
          _buildVoucherList(AppState.vouchers3D, "3D"),
        ],
      ),
    );
  }

  Widget _buildVoucherList(List vouchers, String tag) {
    if (vouchers.isEmpty) {
      return Center(child: Text("$tag ဘောင်ချာမှတ်တမ်း မရှိသေးပါ", style: const TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: vouchers.length,
      itemBuilder: (context, index) {
        final v = vouchers[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1333),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("ဘောင်ချာ: ${v['id']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                    child: Text(v['status'], style: const TextStyle(color: Colors.amber, fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text("ကဏ္ဍ: ${v['type']} | အချိန်: ${v['time']}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 4),
              Text("ထိုးဂဏန်းများ: ${v['numbers'].join(', ')}", style: const TextStyle(color: Colors.white)),
              const Divider(color: Colors.white10),
              Align(
                alignment: Alignment.centerRight,
                child: Text("စုစုပေါင်း: ${v['total']} Ks", style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold, fontSize: 15)),
              )
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// ၁၀။ Wallet Screen (KPay / WavePay Logos)
// ---------------------------------------------------------------------------
class WalletScreen extends StatelessWidget {
  final VoidCallback onRefresh;
  const WalletScreen({super.key, required this.onRefresh});

  final String _kpayLogo = "https://play-lh.googleusercontent.com/y14Z4b98vL6P5J1oD-x30rIvdT5h4L4tD9pZ1XG_fF0vKzYnU7fQ-n0tT8L9=w240-h480-rw";
  final String _waveLogo = "https://play-lh.googleusercontent.com/xO4b8L1_bK_9-dJ1s5m0p1z_f6s9v_5=w240-h480-rw";

  @override
  Widget build(BuildContext context) {
    const purpleAccent = Color(0xFFA855F7);
    const goldAccent = Color(0xFFFBBF24);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF17102B),
        elevation: 0,
        title: const Text("ပိုက်ဆံအိတ်", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF261947), Color(0xFF191032)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: purpleAccent.withOpacity(0.4)),
              ),
              child: Column(
                children: [
                  const Text("စုစုပေါင်း လက်ကျန်ငွေ", style: TextStyle(color: Colors.white60, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                    "${AppState.balance.toStringAsFixed(0)} Ks",
                    style: const TextStyle(color: goldAccent, fontSize: 32, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purpleAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text("ငွေဖြည့်မည်", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    onPressed: () {},
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4646),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text("ငွေထုတ်မည်", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text("ငွေသွင်း/ထုတ် နည်းလမ်းများ", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
            const SizedBox(height: 12),

            _buildBankTileWithImage("KBZPay (KPay)", "09-683005344 (Lucky Official)", _kpayLogo, Icons.account_balance),
            const SizedBox(height: 10),
            _buildBankTileWithImage("WavePay", "09-683005344 (Lucky Official)", _waveLogo, Icons.waves),
          ],
        ),
      ),
    );
  }

  Widget _buildBankTileWithImage(String title, String account, String imgUrl, IconData fallbackIcon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1333),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white10,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imgUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(fallbackIcon, color: const Color(0xFFFBBF24)),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 2),
              Text(account, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ၁၁။ Profile Screen (Logout ပါဝင်သည်)
// ---------------------------------------------------------------------------
class ProfileScreen extends StatelessWidget {
  final VoidCallback onRefresh;
  const ProfileScreen({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF1B1333);
    const goldAccent = Color(0xFFFBBF24);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF17102B),
        elevation: 0,
        title: const Text("ကျွန်ုပ် (Profile)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Color(0xFFA855F7),
                    child: Icon(Icons.person, size: 32, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppState.currentUser, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text("Ph: ${AppState.currentPhone}", style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              tileColor: cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.lock_reset, color: goldAccent),
              title: const Text("စကားဝှက် ပြောင်းလဲရန်"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white38),
              onTap: () {},
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4646),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                AppState.isLoggedIn = false;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Center(
                child: Text("အကောင့်မှ ထွက်မည် (Logout)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}