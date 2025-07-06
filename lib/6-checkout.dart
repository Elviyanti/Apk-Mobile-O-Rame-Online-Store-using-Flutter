import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '7-profile_screen.dart';
import '5-home_screen.dart';
import '9-order_form.dart'; // Your OrderPage (OrderForm)
import '8-tim.dart';

class CheckoutScreen extends StatefulWidget {
  final String name;
  final String email;

  CheckoutScreen({
    Key? key, // Added Key for good practice
    required this.name,
    required this.email,
  }) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> cartItems = [];
  List<bool> checkedItems = [];
  bool _isLoading = true;
  bool _isProcessingOrder = false;
  
  // Added from new navigation code for color consistency
  final Color yellowColor = const Color(0xFFFFD428);

  @override
  void initState() {
    super.initState();
    _fetchCartAndHistory();
  }

  Future<void> _fetchCartAndHistory() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    User? user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Silakan login untuk melihat keranjang.")));
      }
      return;
    }

    try {
      QuerySnapshot cartSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .orderBy('addedDate', descending: true)
          .get();

      final List<Map<String, dynamic>> fetchedCart =
          cartSnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          ...data,
          'cartDocId': doc.id,
          'id': data['id'],
        };
      }).toList();

      if (mounted) {
        setState(() {
          cartItems = fetchedCart;
          checkedItems = List.generate(cartItems.length, (_) => true);
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching data for CheckoutScreen: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Gagal memuat data: ${e.toString()}")));
      }
    }
  }

  Future<void> _deleteItemFromCart(int index) async {
    User? user = _auth.currentUser;
    if (user == null) return;
    if (index < 0 || index >= cartItems.length) return;

    final itemToDelete = cartItems[index];
    final String cartDocId = itemToDelete['cartDocId'] as String;
    final String itemNameToDelete = itemToDelete['name'] ?? 'Item';

    if (mounted) {
      setState(() {
        cartItems.removeAt(index);
        if (index < checkedItems.length) {
          checkedItems.removeAt(index);
        }
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$itemNameToDelete dihapus dari keranjang.")),
    );

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .doc(cartDocId)
          .delete();
    } catch (e) {
      print("Error deleting item from Firestore: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "Gagal menghapus $itemNameToDelete dari server. Muat ulang keranjang.")),
      );
      _fetchCartAndHistory();
    }
  }

  int getTotal() {
    int total = 0;
    for (int i = 0; i < cartItems.length; i++) {
      if (i < checkedItems.length && checkedItems[i]) {
        final price = cartItems[i]['price'] as int? ?? 0;
        final quantity = cartItems[i]['quantity'] as int? ?? 1;
        total += price * quantity;
      }
    }
    return total;
  }

  Future<void> _proceedToOrderForm() async {
    List<Map<String, dynamic>> selectedItemsToOrder = [];
    for (int i = 0; i < cartItems.length; i++) {
      if (i < checkedItems.length && checkedItems[i]) {
        selectedItemsToOrder.add(cartItems[i]);
      }
    }

    if (selectedItemsToOrder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Pilih setidaknya satu item untuk dipesan.")),
      );
      return;
    }

    if (mounted) setState(() => _isProcessingOrder = true);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderPage(
          selectedCart: selectedItemsToOrder,
          name: widget.name,
          email: widget.email,
        ),
      ),
    );

    if (mounted) setState(() => _isProcessingOrder = false);
    // Refresh the cart after returning from the order page.
    await _fetchCartAndHistory();
  }

  void _showConfirmationDialog() {
    List<Map<String, dynamic>> selectedItemsToOrder = [];
    for (int i = 0; i < cartItems.length; i++) {
      if (i < checkedItems.length && checkedItems[i]) {
        selectedItemsToOrder.add(cartItems[i]);
      }
    }

    if (selectedItemsToOrder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Pilih setidaknya satu item untuk dipesan.")),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: !_isProcessingOrder,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.black,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Anda akan melanjutkan ke form pengisian alamat dan pembayaran.\nLanjutkan?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Color(0xFFF9D33C),
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFF9D33C),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20))),
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      await _proceedToOrderForm();
                    },
                    child:
                        Text('Ya, Lanjutkan', style: TextStyle(color: Colors.black)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20))),
                    onPressed: () {
                      if (!_isProcessingOrder) Navigator.pop(dialogContext);
                    },
                    child: Text('Batal', style: TextStyle(color: Colors.black)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- START: NEW NAVIGATION BAR CODE ---

  Widget _buildBottomNavigationBar(BuildContext context, String currentUserName, String currentUserEmail) {
    return BottomAppBar(
      color: Colors.transparent, // Membuat background BottomAppBar transparan
      elevation: 0, // Menghilangkan bayangan bawaan BottomAppBar
      child: Padding(
        padding: const EdgeInsets.all(8.0), // Padding di sekitar container utama
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: Colors.black, // Warna background BottomNavigationBar
            borderRadius: BorderRadius.circular(30), // Membuat sudut melengkung
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround, // Distribusi item merata
            children: [
              _buildNavItem(Icons.phone, "Tim", context, currentUserName, currentUserEmail, isActive: false),
              _buildNavItem(Icons.home, "Home", context, currentUserName, currentUserEmail, isActive: false),
              _buildNavItem(Icons.shopping_cart, "Keranjang", context, currentUserName, currentUserEmail, isActive: true),
              _buildNavItem(Icons.person, "Profil", context, currentUserName, currentUserEmail, isActive: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, BuildContext context, String currentUserName, String currentUserEmail, {required bool isActive}) {
    return IconButton(
      icon: Icon(
        icon,
        color: isActive ? yellowColor : const Color(0xFFF9D33C),
        size: 24,
      ),
      tooltip: label, // Tooltip untuk aksesibilitas
      onPressed: () async {
        // Hindari navigasi ke halaman yang sama jika sudah aktif
        if (isActive) return;

        if (icon == Icons.person) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/profile'),
              builder: (_) => ProfileScreen(),
            ),
          );
          // Refresh cart data after returning from ProfileScreen
          _fetchCartAndHistory(); 

        } else if (icon == Icons.home) {
           Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                  settings: RouteSettings(name: '/'), // Use '/' for home route
                  builder: (_) => HomeScreen(
                    name: currentUserName,
                    email: currentUserEmail,
                    cart: cartItems, // Pass current cart state
                    orderHistory: [], // Checkout doesn't manage history
                  ),
              ),
              (route) => false,
            );

        } else if (icon == Icons.shopping_cart) {
          // Logic for navigating to CheckoutScreen, which is this screen.
          // Since it's handled by 'isActive' check, this block is for completeness
          // and would be used if navigating from another page in a shared component.
           await Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/checkout'),
              builder: (_) => CheckoutScreen(
                name: currentUserName,
                email: currentUserEmail,
              ),
            ),
          );
           // Refresh cart data after returning 
           _fetchCartAndHistory();

        } else if (icon == Icons.phone) {
          // Use a simple push so the user can easily return
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/team_page'),
              builder: (_) => TeamPage(
                cart: cartItems, // Pass current cart state
                name: currentUserName,
                email: currentUserEmail,
                orderHistory: [], // Checkout doesn't manage history
              ),
            ),
          );
        }
      },
    );
  }
  
  // --- END: NEW NAVIGATION BAR CODE ---


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text("CHECK OUT"),
          backgroundColor: Color(0xFFF9D33C),
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22),
          centerTitle: true,
        ),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFF9D33C))),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                      color: Color(0xFFF9D33C),
                      borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(40),
                          bottomRight: Radius.circular(40))),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: Colors.black),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Text("CHECK OUT",
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black)),
                        Image.asset('image/logo.png',
                            height: 40,
                            errorBuilder: (c, e, s) =>
                                Icon(Icons.image_not_supported, size: 40)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: cartItems.isEmpty
                  ? Center(
                      child: Text("Keranjang Anda kosong.",
                          style: TextStyle(fontSize: 18, color: Colors.grey)))
                  : ListView.builder(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      itemCount: cartItems.length,
                      itemBuilder: (context, index) {
                        if (index >= cartItems.length ||
                            index >= checkedItems.length) {
                          return SizedBox.shrink();
                        }
                        final item = cartItems[index];
                        final String? itemImageUrl = item['image'] as String?;
                        final int quantity = item['quantity'] as int? ?? 1;
                        final int price = item['price'] as int? ?? 0;

                        return Container(
                          margin: EdgeInsets.only(bottom: 16),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.grey.shade300,
                                  blurRadius: 8,
                                  offset: Offset(0, 4))
                            ],
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: checkedItems[index],
                                onChanged: (val) {
                                  if (mounted)
                                    setState(
                                        () => checkedItems[index] = val ?? false);
                                },
                                activeColor: Color(0xFFF9D33C),
                              ),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: (itemImageUrl != null &&
                                        itemImageUrl.isNotEmpty)
                                    ? Image.network(
                                        itemImageUrl,
                                        height: 80,
                                        width: 80,
                                        fit: BoxFit.cover,
                                        loadingBuilder:
                                            (ctx, child, progress) =>
                                                progress == null
                                                    ? child
                                                    : Container(
                                                        height: 80,
                                                        width: 80,
                                                        child: Center(
                                                            child: CircularProgressIndicator(
                                                                valueColor:
                                                                    AlwaysStoppedAnimation<
                                                                            Color>(
                                                                        Color(
                                                                            0xFFF9D33C))))),
                                        errorBuilder: (ctx, err, trace) =>
                                            Container(
                                                height: 80,
                                                width: 80,
                                                color: Colors.grey[200],
                                                child: Center(
                                                    child: Icon(
                                                        Icons.broken_image,
                                                        size: 30,
                                                        color: Colors
                                                            .grey[400]))),
                                      )
                                    : Container(
                                        height: 80,
                                        width: 80,
                                        color: Colors.grey[200],
                                        child: Center(
                                            child: Icon(
                                                Icons.image_not_supported,
                                                size: 30,
                                                color: Colors.grey[400]))),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['name'] ?? 'No Name',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                    SizedBox(height: 4),
                                    Text("Rp $price",
                                        style: TextStyle(
                                            color: Colors.deepOrange,
                                            fontWeight: FontWeight.w600)),
                                    Text("Kuantitas : $quantity"),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline,
                                    color: Colors.redAccent),
                                onPressed: () => _deleteItemFromCart(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            if (cartItems.isNotEmpty)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: Offset(0, -2))
                  ],
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Total Dipilih:",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text("Rp.${getTotal()}",
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFF9D33C))),
                      ],
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFF9D33C),
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        elevation: 2,
                      ),
                      onPressed: getTotal() > 0 && !_isProcessingOrder
                          ? _showConfirmationDialog
                          : null,
                      child: _isProcessingOrder
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.black, strokeWidth: 3))
                          : Text(
                              "Order Now (${selectedItemsCount()})",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                  fontSize: 16),
                            ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        bottomNavigationBar:
            _buildBottomNavigationBar(context, widget.name, widget.email),
      ),
    );
  }

  int selectedItemsCount() {
    return checkedItems.where((isChecked) => isChecked).length;
  }
}