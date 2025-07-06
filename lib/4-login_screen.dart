import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import '3-signin_screen.dart'; 
import '5-home_screen.dart';   
import 'firebase_service.dart'; 
import '10-password_reset_screen.dart'; // <-- TAMBAHKAN IMPORT INI

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  
  final FirebaseService _firebaseService = FirebaseService(); 
  
  bool _isLoading = false;

  void _showErrorSnackBar(String message) {
    if (!mounted) return; 
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green, 
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }


  Future<void> _loginWithEmail() async {
    // ... (kode _loginWithEmail Anda tetap sama) ...
     print("[LoginScreen] Tombol Login Email ditekan.");
    String email = emailController.text.trim();
    String password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showErrorSnackBar("Email dan password tidak boleh kosong");
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      print("[LoginScreen] Memanggil FirebaseAuth.instance.signInWithEmailAndPassword...");
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (!mounted) {
        print("[LoginScreen] Widget sudah di-unmount setelah await signInWithEmailAndPassword.");
        return;
      }

      print("[LoginScreen] Login Email Berhasil! User ID: ${userCredential.user?.uid}");
      _showSuccessSnackBar("Login Berhasil!"); 
      
      String userName = userCredential.user?.displayName ?? userCredential.user?.email?.split('@').first ?? 'User';
      String userEmail = userCredential.user?.email ?? 'Tidak ada email';

      print("[LoginScreen] Menyiapkan navigasi ke HomeScreen (dari login email) dengan name: $userName, email: $userEmail");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            name: userName,
            email: userEmail,
            cart: [], 
            orderHistory: [], 
          ),
        ),
      );
      print("[LoginScreen] Navigasi ke HomeScreen (dari login email) selesai dipanggil.");
    } on FirebaseAuthException catch (e, s) {
      print("[LoginScreen] FirebaseAuthException saat login email: ${e.message} (Code: ${e.code})");
      print("[LoginScreen] Stack trace: $s");
      String errorMessage = "Terjadi kesalahan saat login";
      if (e.code == 'user-not-found') {
        errorMessage = "Email belum terdaftar";
      } else if (e.code == 'wrong-password') {
        errorMessage = "Password salah";
      } else if (e.code == 'invalid-credential' || e.code == 'INVALID_LOGIN_CREDENTIALS' || e.code == 'invalid-email') {
        errorMessage = "Email atau password salah.";
      }
      if (mounted) _showErrorSnackBar(errorMessage);
    } catch (e, s) {
      print("[LoginScreen] Error umum saat login email: $e");
      print("[LoginScreen] Stack trace: $s");
      if (mounted) _showErrorSnackBar("Terjadi kesalahan: ${e.toString()}");
    } finally {
      if (mounted) {
        print("[LoginScreen] Proses login email selesai, isLoading diatur ke false.");
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    // ... (kode _signInWithGoogle Anda tetap sama) ...
    print("[LoginScreen] Tombol Login Google ditekan.");
    setState(() => _isLoading = true);
    try {
      print("[LoginScreen] Memanggil _firebaseService.signInWithGoogle()...");
      User? user = await _firebaseService.signInWithGoogle(); 
      
      if (!mounted) {
        print("[LoginScreen] Widget sudah di-unmount setelah await signInWithGoogle.");
        return;
      }

      if (user != null) {
        print("[LoginScreen] Login Google Berhasil! User ID: ${user.uid}, Display Name: ${user.displayName}, Email: ${user.email}");
        
        _showSuccessSnackBar("Login Google Berhasil!");

        String userName = user.displayName ?? user.email?.split('@').first ?? 'User';
        String userEmail = user.email ?? 'Tidak ada email'; 
        
        print("[LoginScreen] Menyiapkan navigasi ke HomeScreen (dari login Google) dengan name: $userName, email: $userEmail");

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              name: userName,
              email: userEmail,
              cart: [], 
              orderHistory: [], 
            ),
          ),
        );
        print("[LoginScreen] Navigasi ke HomeScreen (dari login Google) selesai dipanggil.");
      } else {
        print("[LoginScreen] Login Google gagal atau dibatalkan (user adalah null dari service).");
        if (mounted) _showErrorSnackBar("Login Google gagal atau dibatalkan oleh pengguna.");
      }
    } catch (e, s) { 
      print("[LoginScreen] Error saat login dengan Google di UI: $e");
      print("[LoginScreen] Stack trace: $s");
      if (mounted) {
        _showErrorSnackBar("Terjadi kesalahan saat login dengan Google: ${e.toString()}");
      }
    } finally {
      if (mounted) {
        print("[LoginScreen] Proses login Google selesai, isLoading diatur ke false.");
        setState(() => _isLoading = false);
      }
    }
  }

  // HAPUS METODE _showForgotPasswordDialog() DARI SINI JIKA ADA
  // void _showForgotPasswordDialog() { ... }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF9D33C),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ... (Bagian atas UI Anda tetap sama) ...
             SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: _isLoading ? null : () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 35),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 30),
                    Text(
                      "Login",
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Silakan masuk untuk mengakses akun dan melanjutkan transaksi Anda!",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 50),

            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(50),
                  topRight: Radius.circular(50),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20),
                    buildTextField("Email", Icons.email, emailController),
                    SizedBox(height: 18),
                    buildTextField("Password", Icons.lock, passwordController, obscureText: true),
                    SizedBox(height: 15),
                    
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading 
                            ? null 
                            : () {
                                print("[LoginScreen] Tombol 'Lupa Password?' ditekan. Navigasi ke PasswordResetScreen.");
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => PasswordResetScreen()), // <-- NAVIGASI KE LAYAR BARU
                                );
                              },
                        child: Text(
                          "Lupa Password?",
                          style: TextStyle(
                            color: Color(0xFFF9D33C),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 40),
                    
                    // ... (Sisa tombol dan UI Anda tetap sama) ...
                     ElevatedButton(
                      onPressed: _isLoading ? null : _loginWithEmail, 
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 15),
                        minimumSize: Size(double.infinity, 60),
                      ),
                      child: _isLoading 
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              "Login",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontFamily: 'Inter',
                              ),
                            ),
                    ),
                    SizedBox(height: 25),
                    
                    GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () {
                              print("[LoginScreen] Tombol Register ditekan, navigasi ke SignInScreen.");
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SignInScreen(), 
                                ),
                              );
                            },
                      child: Center(
                        child: Text.rich(
                          TextSpan(
                            text: "Belum memiliki akun? ",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black,
                              fontFamily: 'Inter',
                            ),
                            children: [
                              TextSpan(
                                text: "Register",
                                style: TextStyle(
                                  color: Color(0xFFF9D33C),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 30),
                    
                    ElevatedButton(
                      onPressed: _isLoading ? null : _signInWithGoogle, 
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, 
                        foregroundColor: Colors.black, 
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: BorderSide(color: Colors.grey.shade300), 
                        ),
                        padding: EdgeInsets.symmetric(vertical: 15), 
                        minimumSize: Size(double.infinity, 60),
                      ),
                      child: _isLoading 
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.black, 
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'image/google.png', 
                                  height: 24,
                                  errorBuilder: (context, error, stackTrace) {
                                    print("[LoginScreen] Error memuat image/google.png: $error");
                                    return Icon(Icons.login, color: Colors.red); 
                                  },
                                ),
                                SizedBox(width: 12), 
                                Text(
                                  "Login dengan Google",
                                  style: TextStyle(
                                    color: Colors.black, 
                                    fontSize: 18,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                    ),
                    SizedBox(height: 20), 
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTextField(String label, IconData icon, TextEditingController controller, {bool obscureText = false}) {
    // ... (kode buildTextField Anda tetap sama) ...
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.black,
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 5),
        TextField(
          controller: controller,
          obscureText: obscureText,
          enabled: !_isLoading, 
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.black54),
            hintText: "Masukkan $label Anda", 
            hintStyle: TextStyle(color: Colors.black38, fontFamily: 'Inter', fontSize: 14),
            floatingLabelBehavior: FloatingLabelBehavior.never, 
            filled: true,
            fillColor: Colors.grey[200],
            contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            disabledBorder: OutlineInputBorder( 
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
             focusedBorder: OutlineInputBorder( 
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Color(0xFFF9D33C), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    // ... (kode dispose Anda tetap sama) ...
    print("[LoginScreen] Dispose dipanggil.");
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}