// lib/password_reset_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Tidak perlu import LoginScreen secara eksplisit jika hanya menggunakan Navigator.pop()
// Namun, jika Anda menggunakan pushReplacement, Anda akan membutuhkannya:
// import '2-login_screen.dart'; // Pastikan path ini benar jika Anda butuh pushReplacement

class PasswordResetScreen extends StatefulWidget {
  @override
  _PasswordResetScreenState createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final TextEditingController _emailController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: Duration(seconds: isError ? 3 : 2), // Durasi SnackBar
      ),
    );
  }

  Future<void> _sendPasswordResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnackBar("Masukkan alamat email yang valid.", isError: true);
      return;
    }

    // Periksa apakah widget masih mounted sebelum setState
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      await _auth.sendPasswordResetEmail(email: email);
      _showSnackBar("Link reset password telah dikirim ke email Anda. Silakan periksa inbox (atau folder spam).");

      // Tunggu sebentar agar Snackbar sempat terlihat sebelum navigasi
      Future.delayed(const Duration(seconds: 3), () { // Durasi bisa disesuaikan dengan durasi SnackBar
        if (mounted) {
          // Kembali ke layar sebelumnya (LoginScreen)
          Navigator.of(context).pop();

          // OPSI ALTERNATIF: Jika Anda ingin memastikan PasswordResetScreen dihapus dari stack
          // dan LoginScreen menjadi root baru (misalnya jika ada alur kompleks sebelumnya):
          // Navigator.pushAndRemoveUntil(
          //   context,
          //   MaterialPageRoute(builder: (context) => LoginScreen()), // Pastikan LoginScreen diimport
          //   (Route<dynamic> route) => false,
          // );
          // ATAU hanya mengganti layar saat ini dengan LoginScreen:
          // Navigator.pushReplacement(
          //   context,
          //   MaterialPageRoute(builder: (context) => LoginScreen()), // Pastikan LoginScreen diimport
          // );
        }
      });
      // _isLoading akan di-handle oleh finally atau tidak perlu jika widget di-pop

    } on FirebaseAuthException catch (e) {
      String errorMessage = "Gagal mengirim email reset password.";
      if (e.code == 'user-not-found') {
        errorMessage = "Email tidak terdaftar.";
      } else if (e.code == 'invalid-email'){
        errorMessage = "Format email tidak valid.";
      } else {
        print("FirebaseAuthException on reset: ${e.code} - ${e.message}");
      }
      _showSnackBar(errorMessage, isError: true);
      if (mounted) { // Pastikan widget masih ada
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Generic error on reset: $e");
      _showSnackBar("Terjadi kesalahan: ${e.toString()}", isError: true);
      if (mounted) { // Pastikan widget masih ada
        setState(() {
          _isLoading = false;
        });
      }
    }
    // Tidak perlu setStateisLoading(false) di success case jika navigasi terjadi,
    // karena widget akan di-unmount. Namun, jika menggunakan finally, pastikan mounted.
    // Pada kasus ini, lebih baik membiarkan `finally` menangani _isLoading jika tidak ada navigasi.
    // Jika ada navigasi, `setState` setelah navigasi (jika widget di-pop) akan error.
    // Jadi, kita hanya set _isLoading = false pada blok catch.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF9D33C),
      appBar: AppBar(
        backgroundColor: Colors.white, // Ubah warna AppBar agar konsisten jika diinginkan
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Reset Password",
          style: TextStyle(color: Colors.black, fontFamily: 'Inter', fontWeight: FontWeight.bold),
        ),
        centerTitle: true, // Agar judul di tengah
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 30), // Mengurangi sedikit padding atas
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 35),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Lupa Password Anda?", // Lebih jelas
                      style: TextStyle(
                        fontSize: 28, // Sedikit disesuaikan
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Jangan khawatir! Masukkan email yang terhubung dengan akun Anda dan kami akan mengirimkan link untuk mereset password Anda.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black.withOpacity(0.7),
                        fontFamily: 'Inter',
                        height: 1.4, // Spasi antar baris
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 40), // Mengurangi sedikit padding
            Container( // Tidak perlu width: double.infinity jika parent sudah SingleChildScrollView
              padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0), // Padding container utama
              child: Column(
                children: [
                  _buildEmailTextField("Alamat Email", Icons.email_outlined, _emailController), // Icon lebih modern
                  SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _sendPasswordResetEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 15),
                      minimumSize: Size(double.infinity, 55), // Tinggi tombol disesuaikan
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            "Kirim Link Reset",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17, // Ukuran font disesuaikan
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailTextField(String label, IconData icon, TextEditingController controller) {
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
        SizedBox(height: 8), // Sedikit lebih banyak spasi
        TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.black54, size: 20),
            // labelText: "Masukkan Email", // Bisa diganti dengan hintText
            hintText: "Contoh: email@gmail.com",
            hintStyle: TextStyle(color: Colors.black45, fontFamily: 'Inter', fontSize: 14),
            // floatingLabelBehavior: FloatingLabelBehavior.never, // Hapus jika ingin label naik
            filled: true,
            fillColor: Colors.grey[200], // Warna field
            contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20), // Padding field
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), // Border radius field
              borderSide: BorderSide.none,
            ),
             enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFFF9D33C).withOpacity(0.8), width: 1.5), // Highlight saat fokus
            ),
          ),
          style: TextStyle(fontFamily: 'Inter', fontSize: 15), // Style teks input
        ),
      ],
    );
  }
}