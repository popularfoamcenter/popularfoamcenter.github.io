import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pfc/Home.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeModeProvider(),
      child: const MyApp(),
    ),
  );
}

class ThemeModeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeModeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            textTheme: GoogleFonts.poppinsTextTheme(),
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D6EFD)),
            brightness: Brightness.light,
            scaffoldBackgroundColor: Colors.white,
          ),
          darkTheme: ThemeData(
            textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0D6EFD),
              brightness: Brightness.dark,
            ),
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF1A1A2F),
          ),
          themeMode: themeProvider.themeMode,
          home: const LoginPage(),
        );
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  bool _obscureText = true;
  bool _isLoading = false;
  bool _rememberMe = false;

  // Color Scheme
  Color get _primaryColor => const Color(0xFF0D6EFD);

  @override
  void initState() {
    super.initState();
    // Request focus on email field when widget initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_emailFocus);
    });
  }

  @override
  void dispose() {
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? "Authentication Error"),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleDarkMode() {
    final themeProvider = Provider.of<ThemeModeProvider>(context, listen: false);
    themeProvider.setThemeMode(themeProvider.themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final secondaryTextColor = isDarkMode ? const Color(0xFFB0B0C0) : Colors.black54;
    final surfaceColor = isDarkMode ? const Color(0xFF252541) : Colors.grey[100]!;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isWideScreen = constraints.maxWidth > 700;

          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isWideScreen)
                      Expanded(
                        flex: 1,
                        child: Container(
                          color: _primaryColor,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Popular Foam Center",
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              Image.asset(
                                'assets/images/freee.png',
                                height: constraints.maxHeight * 0.3,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.error,
                                    color: Colors.white,
                                    size: 50,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: isWideScreen ? 40.0 : 20.0),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Welcome Back!",
                                        style: GoogleFonts.poppins(
                                          fontSize: isWideScreen ? 30 : 24,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        "Please login to your account",
                                        style: GoogleFonts.poppins(
                                          fontSize: isWideScreen ? 16 : 14,
                                          color: secondaryTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      isDarkMode ? Icons.light_mode : Icons.dark_mode,
                                      color: secondaryTextColor,
                                    ),
                                    onPressed: _toggleDarkMode,
                                    tooltip: 'Toggle Dark Mode',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _buildEmailField(textColor, secondaryTextColor, surfaceColor),
                              const SizedBox(height: 15),
                              _buildPasswordField(textColor, secondaryTextColor, surfaceColor),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _rememberMe,
                                        onChanged: (value) => setState(() => _rememberMe = value!),
                                        activeColor: _primaryColor,
                                        checkColor: Colors.white,
                                        side: BorderSide(color: secondaryTextColor),
                                      ),
                                      Text(
                                        "Remember me",
                                        style: GoogleFonts.poppins(color: textColor),
                                      ),
                                    ],
                                  ),
                                  TextButton(
                                    onPressed: () {/* Add forgot password logic */},
                                    child: Text(
                                      "Forgot Password?",
                                      style: GoogleFonts.poppins(
                                        color: _primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _buildLoginButton(),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("Don't have an account? ", style: GoogleFonts.poppins(color: secondaryTextColor)),
                                  TextButton(
                                    onPressed: () {/* Add sign up navigation */},
                                    child: Text(
                                      "Sign Up",
                                      style: GoogleFonts.poppins(
                                        color: _primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmailField(Color textColor, Color secondaryTextColor, Color surfaceColor) {
    return TextField(
      controller: _emailController,
      focusNode: _emailFocus,
      decoration: InputDecoration(
        hintText: "Email Address",
        filled: true,
        fillColor: surfaceColor,
        hintStyle: GoogleFonts.poppins(color: secondaryTextColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      style: TextStyle(color: textColor),
      textInputAction: TextInputAction.next,
      onSubmitted: (_) {
        FocusScope.of(context).requestFocus(_passwordFocus);
      },
    );
  }

  Widget _buildPasswordField(Color textColor, Color secondaryTextColor, Color surfaceColor) {
    return TextField(
      controller: _passwordController,
      focusNode: _passwordFocus,
      obscureText: _obscureText,
      decoration: InputDecoration(
        hintText: "Password",
        filled: true,
        fillColor: surfaceColor,
        hintStyle: GoogleFonts.poppins(color: secondaryTextColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureText ? Icons.visibility_off : Icons.visibility,
            color: secondaryTextColor,
          ),
          onPressed: () => setState(() => _obscureText = !_obscureText),
        ),
      ),
      style: TextStyle(color: textColor),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _signIn(),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: _isLoading ? null : _signIn,
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text("Login", style: GoogleFonts.poppins(fontSize: 18, color: Colors.white)),
      ),
    );
  }
}