import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_service.dart';
import '2-welcome_screen.dart';
import '5-home_screen.dart';
import '6-checkout.dart';
import '8-tim.dart';

class ProfileScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? initialCart;
  final String? newlyCreatedOrderId;
  final int? newlyCreatedOrderTotal;
  final List<Map<String, dynamic>>? newlyCreatedOrderItems;

  const ProfileScreen({
    Key? key,
    this.initialCart,
    this.newlyCreatedOrderId,
    this.newlyCreatedOrderTotal,
    this.newlyCreatedOrderItems,
  }) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // --- SEMUA STATE DAN LOGIKA DARI KODE ASLI ANDA TETAP DIPERTAHANKAN ---
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  Map<String, dynamic>? _userDataFromFirestore;

  String _displayName = 'Loading...';
  String _displayEmail = 'Loading...';

  List<Map<String, dynamic>> _orderHistoryFromFirestore = [];
  bool _isLoadingOrders = true;

  int _currentPage = 0;
  final int _itemsPerPage = 3;

  List<Map<String, dynamic>> _currentCart = [];

  final Color yellowColor = const Color(0xFFFFD428);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadUserData();
    await _fetchOrderHistory();
    await _fetchCart();

    if (widget.newlyCreatedOrderId != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order #${widget.newlyCreatedOrderId!.substring(0, 8)}... berhasil dibuat! Total: Rp ${widget.newlyCreatedOrderTotal}',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      });
    }
  }

  Future<void> _loadUserData() async {
    _currentUser = _firebaseService.currentUser;
    if (_currentUser != null) {
      _userDataFromFirestore = await _firebaseService.getUserData(
        _currentUser!.uid,
      );
      if (mounted) {
        setState(() {
          _displayName =
              _userDataFromFirestore?['name'] ??
              _currentUser?.displayName ??
              _currentUser?.email?.split('@').first ??
              'User';
          _displayEmail = _currentUser?.email ?? 'Tidak ada email';
        });
      }
    } else {
      if (mounted) {
        // ... (logika jika tidak login tetap sama)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => WelcomeScreen()),
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  Future<void> _fetchOrderHistory() async {
    // ... (Fungsi ini tetap sama persis)
    if (_currentUser == null) {
      if (mounted) setState(() => _isLoadingOrders = false);
      return;
    }
    if (!mounted) return;
    setState(() => _isLoadingOrders = true);
    try {
      QuerySnapshot orderSnapshot =
          await _firestore
              .collection('users')
              .doc(_currentUser!.uid)
              .collection('orders')
              .orderBy('orderDate', descending: true)
              .get();
      _orderHistoryFromFirestore =
          orderSnapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            return {'orderId': doc.id, ...data};
          }).toList();
    } catch (e) {
      print("Error fetching order history: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingOrders = false);
      }
    }
  }

  Future<void> _fetchCart() async {
    // ... (Fungsi ini tetap sama persis)
    if (_currentUser == null) return;
    if (widget.initialCart != null) {
      if (mounted)
        setState(() => _currentCart = List.from(widget.initialCart!));
      return;
    }
    try {
      QuerySnapshot cartSnapshot =
          await _firestore
              .collection('users')
              .doc(_currentUser!.uid)
              .collection('cart')
              .get();
      _currentCart =
          cartSnapshot.docs.map((doc) {
            return {'cartDocId': doc.id, ...doc.data() as Map<String, dynamic>};
          }).toList();
      if (mounted) setState(() {});
    } catch (e) {
      print("Error fetching cart in ProfileScreen: $e");
    }
  }

  List<Map<String, dynamic>> getPaginatedOrders() {
    // ... (Fungsi ini tetap sama persis)
    int startIndex = _currentPage * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (_orderHistoryFromFirestore.isEmpty ||
        startIndex >= _orderHistoryFromFirestore.length)
      return [];
    return _orderHistoryFromFirestore.sublist(
      startIndex,
      endIndex > _orderHistoryFromFirestore.length
          ? _orderHistoryFromFirestore.length
          : endIndex,
    );
  }

  Future<void> _handleLogout() async {
    // ... (Fungsi ini tetap sama persis)
    await _firebaseService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => WelcomeScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- UI DARI SINI DIUBAH TOTAL AGAR SESUAI TARGET ---
    return Scaffold(
      backgroundColor: Color(0xFFF9D33C),
      // Navigasi Bottom Bar dari kode asli Anda dipertahankan karena lebih fungsional
      bottomNavigationBar: _buildBottomNavigationBar(
        context,
        _displayName,
        _displayEmail,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header dari kode target
            ClipRRect(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(60),
                bottomRight: Radius.circular(60),
              ),
              child: Container(
                color: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                child: Column(
                  children: [
                    SizedBox(height: 25),
                    Row(
                      children: [
                        // ========== PERUBAHAN DI SINI ==========
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: Colors.black),
                          onPressed: () {
                            // Cek jika bisa kembali, maka kembali. Jika tidak, navigasi ke home.
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              // Fallback ke HomeScreen jika tidak ada halaman sebelumnya
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => HomeScreen(
                                        name: _displayName,
                                        email: _displayEmail,
                                        cart: _currentCart,
                                        orderHistory:
                                            _orderHistoryFromFirestore,
                                      ),
                                ),
                              );
                            }
                          },
                        ),
                        // =======================================
                        Text(
                          'Profile',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Center(
                      child: Image.asset(
                        'image/logo2.png',
                        height: 80,
                        errorBuilder:
                            (context, error, stackTrace) =>
                                Icon(Icons.error, size: 50),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 70),

            // Stack Avatar + Info dari kode target
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 30),
                  padding: EdgeInsets.only(top: 70, bottom: 30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Text(
                          "Nama Pengguna",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                            fontSize: 16,
                          ),
                        ),
                      ),
                      SizedBox(height: 5),
                      // Menggunakan data dinamis dari state
                      buildInfoField(Icons.person, _displayName),
                      SizedBox(height: 15),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Text(
                          "Email",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                            fontSize: 16,
                          ),
                        ),
                      ),
                      SizedBox(height: 5),
                      // Menggunakan data dinamis dari state
                      buildInfoField(Icons.email, _displayEmail),
                      SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: ElevatedButton.icon(
                          // Menggunakan fungsi logout dari state
                          onPressed: _handleLogout,
                          icon: Icon(Icons.logout),
                          label: Text(
                            "Logout",
                            style: TextStyle(fontFamily: 'Inter'),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFF9D33C),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            minimumSize: Size(double.infinity, 45),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: -40,
                  left: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 40,
                      // Menggunakan gambar profil dinamis dari state
                      backgroundImage:
                          _currentUser?.photoURL != null
                              ? NetworkImage(_currentUser!.photoURL!)
                              : AssetImage('image/profile.png')
                                  as ImageProvider,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 40),

            // Kartu detail order baru (dipertahankan dari kode asli)
            if (widget.newlyCreatedOrderId != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 10,
                ),
                child: Card(
                  color: Colors.green[50],
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Detail Order Baru (ID: ${widget.newlyCreatedOrderId})",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                        ),
                        SizedBox(height: 8),
                        if (widget.newlyCreatedOrderItems != null)
                          ...widget.newlyCreatedOrderItems!
                              .map(
                                (item) => Text(
                                  "- ${item['productName']} (Qty: ${item['quantity'] ?? 0})",
                                  style: TextStyle(fontSize: 14),
                                ),
                              )
                              .toList(),
                        SizedBox(height: 8),
                        Text(
                          "Total Item: ${widget.newlyCreatedOrderItems?.fold<int>(0, (sum, item) => sum + (item['quantity'] as int? ?? 0)) ?? 0} pcs",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          "Total Pembayaran: Rp ${widget.newlyCreatedOrderTotal ?? 0}",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Riwayat Pembelian dari kode target
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Riwayat Pembelian",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
            SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child:
                    _isLoadingOrders
                        ? Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFF9D33C),
                          ),
                        )
                        : _orderHistoryFromFirestore.isEmpty
                        ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(height: 20),
                            // Icon empty state dari kode target
                            Icon(
                              Icons.restaurant_menu_outlined,
                              size: 40,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 5),
                            Text(
                              "Kamu belum melakukan pembelian",
                              style: TextStyle(
                                color: Colors.grey,
                                fontFamily: 'Inter',
                              ),
                            ),
                            SizedBox(height: 20),
                          ],
                        )
                        : Column(
                          children: [
                            // Tampilan item history dari kode asli (lebih detail)
                            ...getPaginatedOrders().map((order) {
                              String orderId = order['orderId'] ?? 'N/A';
                              int totalAmount =
                                  order['totalAmount'] as int? ?? 0;
                              Timestamp orderDate =
                                  order['orderDate'] as Timestamp? ??
                                  Timestamp.now();
                              List<dynamic> itemsInOrder =
                                  order['items'] as List<dynamic>? ?? [];
                              int totalQuantityInOrder = itemsInOrder.fold(
                                0,
                                (sum, item) =>
                                    sum + (item['quantity'] as int? ?? 0),
                              );
                              String firstItemName =
                                  itemsInOrder.isNotEmpty
                                      ? (itemsInOrder.first['productName'] ??
                                          "Produk tidak ada")
                                      : "Item tidak ada";
                              String firstItemImage =
                                  itemsInOrder.isNotEmpty
                                      ? (itemsInOrder.first['image'] ??
                                          'image/placeholder.png')
                                      : 'image/placeholder.png';

                              return Container(
                                margin: EdgeInsets.only(bottom: 12),
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child:
                                          (firstItemImage.startsWith('http'))
                                              ? Image.network(
                                                firstItemImage,
                                                width: 80,
                                                height: 80,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (c, e, s) => Container(
                                                      width: 80,
                                                      height: 80,
                                                      color: Colors.grey[200],
                                                      child: Icon(
                                                        Icons.broken_image,
                                                      ),
                                                    ),
                                              )
                                              : Image.asset(
                                                firstItemImage,
                                                width: 80,
                                                height: 80,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (c, e, s) => Container(
                                                      width: 80,
                                                      height: 80,
                                                      color: Colors.grey[200],
                                                      child: Icon(
                                                        Icons.broken_image,
                                                      ),
                                                    ),
                                              ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            itemsInOrder.length > 1
                                                ? "$firstItemName (dan ${itemsInOrder.length - 1} lainnya)"
                                                : firstItemName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Inter',
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            "Order ID: #...${orderId.substring(orderId.length - 5)}",
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          Text(
                                            "Tgl: ${orderDate.toDate().day}/${orderDate.toDate().month}/${orderDate.toDate().year}",
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            "Total Item: $totalQuantityInOrder pcs",
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                            ),
                                          ),
                                          Text(
                                            "Total: Rp $totalAmount",
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              color: Colors.green[800],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),

                            // Paginasi dari kode target
                            if ((_orderHistoryFromFirestore.length /
                                        _itemsPerPage)
                                    .ceil() >
                                1)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed:
                                        _currentPage > 0
                                            ? () =>
                                                setState(() => _currentPage--)
                                            : null,
                                    icon: Icon(Icons.arrow_back_ios, size: 16),
                                  ),
                                  // Membuat tombol bernomor
                                  ...List.generate(
                                    (_orderHistoryFromFirestore.length /
                                            _itemsPerPage)
                                        .ceil(),
                                    (index) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: ElevatedButton(
                                        onPressed:
                                            () => setState(
                                              () => _currentPage = index,
                                            ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              _currentPage == index
                                                  ? Colors.black
                                                  : Colors.grey[300],
                                          foregroundColor:
                                              _currentPage == index
                                                  ? Colors.white
                                                  : Colors.black,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          minimumSize: Size(35, 35),
                                          padding: EdgeInsets.zero,
                                        ),
                                        child: Text("${index + 1}"),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed:
                                        (_currentPage + 1) * _itemsPerPage <
                                                _orderHistoryFromFirestore
                                                    .length
                                            ? () =>
                                                setState(() => _currentPage++)
                                            : null,
                                    icon: Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Helper widget untuk info field dari kode target
  Widget buildInfoField(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: TextField(
        enabled: false,
        readOnly: true,
        // Menggunakan controller dari kode asli, lebih baik daripada hintText
        controller: TextEditingController(text: value),
        style: TextStyle(color: Colors.black, fontFamily: 'Inter'),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey),
          filled: true,
          fillColor: Colors.grey[200],
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        ),
      ),
    );
  }

  // --- Navigasi Bottom Bar dari kode asli ANDA TETAP DIGUNAKAN KARENA LEBIH BAIK ---
  Widget _buildBottomNavigationBar(
    BuildContext context,
    String currentUserName,
    String currentUserEmail,
  ) {
    return BottomAppBar(
      color: Colors.transparent,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                Icons.phone,
                "Tim",
                context,
                currentUserName,
                currentUserEmail,
                isActive: false,
              ),
              _buildNavItem(
                Icons.home,
                "Home",
                context,
                currentUserName,
                currentUserEmail,
                isActive: false,
              ),
              _buildNavItem(
                Icons.shopping_cart,
                "Keranjang",
                context,
                currentUserName,
                currentUserEmail,
                isActive: false,
              ),
              _buildNavItem(
                Icons.person,
                "Profil",
                context,
                currentUserName,
                currentUserEmail,
                isActive: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    BuildContext context,
    String currentUserName,
    String currentUserEmail, {
    required bool isActive,
  }) {
    return IconButton(
      icon: Icon(
        icon,
        color: isActive ? yellowColor : const Color(0xFFF9D33C),
        size: 24,
      ),
      tooltip: label,
      onPressed: () async {
        if (isActive) return;
        if (icon == Icons.person) {
          /* Do nothing */
        } else if (icon == Icons.home) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder:
                  (_) => HomeScreen(
                    name: currentUserName,
                    email: currentUserEmail,
                    cart: _currentCart,
                    orderHistory: _orderHistoryFromFirestore,
                  ),
            ),
            (route) => false,
          );
        } else if (icon == Icons.shopping_cart) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => CheckoutScreen(
                    name: currentUserName,
                    email: currentUserEmail,
                  ),
            ),
          );
          _fetchCart();
          _fetchOrderHistory();
        } else if (icon == Icons.phone) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => TeamPage(
                    cart: _currentCart,
                    name: currentUserName,
                    email: currentUserEmail,
                    orderHistory: _orderHistoryFromFirestore,
                  ),
            ),
          );
        }
      },
    );
  }
}
