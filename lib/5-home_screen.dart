import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '7-profile_screen.dart';
import 'detail.dart';
import '6-checkout.dart';
import '8-tim.dart';

class HomeScreen extends StatefulWidget {
  final String name;
  final String email;
  // cart and orderHistory will now be primarily managed via Firestore and fetched
  // but we can keep them for initial data or if not logged in (though Firestore ops need login)
  final List<Map<String, dynamic>> initialCart;
  final List<Map<String, dynamic>> initialOrderHistory;

  HomeScreen({
    Key? key, // Added Key for good practice
    required this.name,
    required this.email,
    List<Map<String, dynamic>>? cart, // Made nullable
    List<Map<String, dynamic>>? orderHistory, // Made nullable
  })  : this.initialCart = cart ?? [],
        this.initialOrderHistory = orderHistory ?? [],
        super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> cart = []; // This will be populated from Firestore
  List<Map<String, dynamic>> orderHistory = []; // This will be populated from Firestore
  List<Map<String, dynamic>> _allProducts = [];
  String selectedCategory = "Food";
  bool _isLoadingProducts = true;
  bool _isLoadingCart = true;

  // Added from new navigation code for color consistency
  final Color yellowColor = const Color(0xFFFFD428);

  String _extractVideoId(dynamic ytbField) {
    if (ytbField == null) return '';
    final url = ytbField.toString();
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : '';
    }
    if (uri.host.contains('youtube.com')) {
      return uri.queryParameters['v'] ?? '';
    }
    return '';
  }

  Future<void> _fetchProductsFromFirestore() async {
    if (!mounted) return;
    setState(() {
      _isLoadingProducts = true;
    });
    try {
      QuerySnapshot querySnapshot =
          await _firestore.collection('products').get();
      final List<Map<String, dynamic>> fetchedProducts =
          querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id, // Firestore Document ID of the product
          'name': data['name'] ?? 'No Name',
          'price': (data['price'] ?? 0).toInt(),
          'image': data['image'] ?? '',
          'category': data['category'] ?? 'Uncategorized',
          'description': data['description'] ?? 'No description available.',
          'ytb': data['ytb'], // Keep raw ytb field
          'youtubeVideoId': _extractVideoId(data['ytb']),
        };
      }).toList();

      if (mounted) {
        setState(() {
          _allProducts = fetchedProducts;
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      print("Error fetching products: $e");
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Gagal memuat produk: ${e.toString()}")));
      }
    }
  }

  Future<void> _fetchCartFromFirestore() async {
    User? user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingCart = false);
      return;
    }
    if (!mounted) return;
    setState(() => _isLoadingCart = true);

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
          'cartDocId': doc.id, // Firestore document ID for the cart item
        };
      }).toList();

      if (mounted) {
        setState(() {
          cart = fetchedCart;
          _isLoadingCart = false;
        });
      }
    } catch (e) {
      print("Error fetching cart: $e");
      if (mounted) {
        setState(() => _isLoadingCart = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Gagal memuat keranjang: ${e.toString()}")));
      }
    }
  }

  Future<void> _fetchOrderHistoryFromFirestore() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    try {
      QuerySnapshot historySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('orders')
          .orderBy('orderDate', descending: true)
          .get();

      final List<Map<String, dynamic>> fetchedHistory =
          historySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          ...data,
          'orderId': doc.id,
        };
      }).toList();

      if (mounted) {
        setState(() {
          orderHistory = fetchedHistory;
        });
      }
    } catch (e) {
      print("Error fetching order history: $e");
      // Handle error appropriately
    }
  }

  @override
  void initState() {
    super.initState();
    cart =
        List<Map<String, dynamic>>.from(widget.initialCart); // Use initial if provided
    orderHistory = List<Map<String, dynamic>>.from(
        widget.initialOrderHistory);

    _fetchProductsFromFirestore();
    if (_auth.currentUser != null) {
      _fetchCartFromFirestore();
      _fetchOrderHistoryFromFirestore();
    } else {
      _isLoadingCart =
          false; // Not logged in, so cart won't be fetched from Firestore
    }

    // Listen to auth state changes to refetch cart if user logs in/out
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _fetchCartFromFirestore();
        _fetchOrderHistoryFromFirestore();
      } else {
        if (mounted) {
          setState(() {
            cart = []; // Clear cart if user logs out
            orderHistory = [];
            _isLoadingCart = false;
          });
        }
      }
    });
  }

  // Call this when an item is added from DetailScreen
  Future<void> addItemToCartFromDetail(
      Map<String, dynamic> itemFromDetail) async {
    User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Silakan login untuk menambah ke keranjang.")));
      return;
    }

    String productId =
        itemFromDetail['id'] as String; // This is the PRODUCT's Firestore ID
    int quantityToAdd = itemFromDetail['quantity'] as int? ?? 1;

    // Check if item already exists in Firestore cart
    QuerySnapshot existingCartItemQuery = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('cart')
        .where('id', isEqualTo: productId) // Query by product ID
        .limit(1)
        .get();

    if (existingCartItemQuery.docs.isNotEmpty) {
      // Item exists, update quantity
      DocumentSnapshot cartDoc = existingCartItemQuery.docs.first;
      int currentQuantity = cartDoc['quantity'] as int? ?? 0;
      int newQuantity = currentQuantity + quantityToAdd;
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .doc(cartDoc.id)
          .update({'quantity': newQuantity});

      // Update local cart state
      int localCartIndex =
          cart.indexWhere((item) => item['cartDocId'] == cartDoc.id);
      if (localCartIndex != -1 && mounted) {
        setState(() {
          cart[localCartIndex]['quantity'] = newQuantity;
        });
      } else if (mounted) {
        // If not in local cart (e.g. added on another device), fetch again
        _fetchCartFromFirestore();
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${itemFromDetail['name']} kuantitas diupdate.")));
    } else {
      // Item does not exist, add new
      Map<String, dynamic> cartItemData = {
        'id': productId, // Product's Firestore ID
        'name': itemFromDetail['name'],
        'price': itemFromDetail['price'],
        'image': itemFromDetail['image'],
        // 'category': itemFromDetail['category'], // Store if needed
        'quantity': quantityToAdd,
        'addedDate': Timestamp.now(),
        'userId': user.uid,
      };

      DocumentReference docRef = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .add(cartItemData);

      // Add to local cart state
      if (mounted) {
        setState(() {
          cart.add({
            ...cartItemData,
            'cartDocId':
                docRef.id, // IMPORTANT: store the cart item's own document ID
          });
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${itemFromDetail['name']} ditambahkan ke keranjang.")));
    }
  }

  // This is for adding directly from home screen product card (if you have such a button)
  Future<void> addItemToCartFromProductCard(
      Map<String, dynamic> productData) async {
    User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Silakan login untuk menambah ke keranjang.")));
      return;
    }

    String productId = productData['id'] as String; // Product's Firestore ID

    // Check if item already exists in Firestore cart
    QuerySnapshot existingCartItemQuery = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('cart')
        .where('id', isEqualTo: productId)
        .limit(1)
        .get();

    if (existingCartItemQuery.docs.isNotEmpty) {
      DocumentSnapshot cartDoc = existingCartItemQuery.docs.first;
      int currentQuantity = cartDoc['quantity'] as int? ?? 0;
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .doc(cartDoc.id)
          .update({'quantity': currentQuantity + 1});

      int localCartIndex =
          cart.indexWhere((item) => item['cartDocId'] == cartDoc.id);
      if (localCartIndex != -1 && mounted) {
        setState(() {
          cart[localCartIndex]['quantity'] = currentQuantity + 1;
        });
      } else if (mounted) {
        _fetchCartFromFirestore();
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${productData['name']} kuantitas diupdate.")));
    } else {
      Map<String, dynamic> cartItemData = {
        'id': productId,
        'name': productData['name'],
        'price': productData['price'],
        'image': productData['image'],
        'quantity': 1,
        'addedDate': Timestamp.now(),
        'userId': user.uid,
      };
      DocumentReference docRef = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .add(cartItemData);
      if (mounted) {
        setState(() {
          cart.add({...cartItemData, 'cartDocId': docRef.id});
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${productData['name']} ditambahkan ke keranjang.")));
    }
  }

  void changeCategory(String category) {
    if (mounted) {
      setState(() {
        selectedCategory = category;
      });
    }
  }

  void _showYouTubePlayerDialog(BuildContext context, String videoId) {
    if (videoId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Video review tidak tersedia.")));
      return;
    }
    YoutubePlayerController controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: YoutubePlayerFlags(autoPlay: true, mute: false),
    );

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return YoutubePlayerBuilder(
          player: YoutubePlayer(
            controller: controller,
            showVideoProgressIndicator: true,
            progressIndicatorColor: Colors.amber,
            progressColors: ProgressBarColors(
              playedColor: Colors.amber,
              handleColor: Colors.amberAccent,
            ),
          ),
          builder: (playerContext, player) {
            return AlertDialog(
              contentPadding: EdgeInsets.zero,
              content: AspectRatio(aspectRatio: 16 / 9, child: player),
              actions: <Widget>[
                TextButton(
                  child: Text('Tutup'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      controller.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          SizedBox(height: 20),
          _buildCategorySection(),
          SizedBox(height: 10),
          Expanded(child: _buildProductGrid(context)),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context, widget.name, widget.email),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        Container(
          height: 110,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(50),
              bottomRight: Radius.circular(50),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 30, left: 20, right: 20),
          child: Container(
            height: 170,
            decoration: BoxDecoration(
              color: Color(0xFFF9D33C),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: Image.asset(
                      'image/banner.png', // Make sure this asset exists
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Image.asset(
                    'image/logo.png', // Make sure this asset exists
                    height: 50,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("KATEGORI"),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCategoryButton("Food"),
              _buildCategoryButton("Cake"),
              _buildCategoryButton("Drink"),
            ],
          ),
          SizedBox(height: 10),
          _buildSectionTitle("PRODUK"),
        ],
      ),
    );
  }

  Widget _buildCategoryButton(String category) {
    bool isSelected = selectedCategory == category;
    String emoji = category == "Food" ? "🍽" : category == "Cake" ? "🧁" : "🥤";
    return GestureDetector(
      onTap: () => changeCategory(category),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFFF9D33C) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.orange : Colors.grey.shade400,
            width: 2,
          ),
        ),
        child: Text(
          "$emoji $category",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildProductGrid(BuildContext context) {
    if (_isLoadingProducts || _isLoadingCart) {
      return Center(child: CircularProgressIndicator(color: Color(0xFFF9D33C)));
    }
    if (_allProducts.isEmpty) {
      return Center(child: Text("Tidak ada produk tersedia saat ini."));
    }

    List<Map<String, dynamic>> currentProducts = _allProducts
        .where((product) => product['category'] == selectedCategory)
        .toList();

    if (currentProducts.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada produk dalam kategori "$selectedCategory".',
          style: TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(10),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7, // Adjust as needed
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: currentProducts.length,
      itemBuilder: (context, index) {
        final product = currentProducts[index];
        final String? productImage = product['image'];
        final String? youtubeVideoId = product['youtubeVideoId'];

        return GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailScreen(product: product),
              ),
            );

            if (result != null && result is Map<String, dynamic>) {
              await addItemToCartFromDetail(result);
            }
          },
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: (productImage != null && productImage.isNotEmpty)
                        ? Image.network(
                            productImage,
                            fit: BoxFit.contain,
                            loadingBuilder: (BuildContext context, Widget child,
                                ImageChunkEvent? loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                  child: Icon(Icons.broken_image,
                                      size: 40, color: Colors.grey));
                            },
                          )
                        : Center(
                            child: Icon(Icons.image_not_supported,
                                size: 40, color: Colors.grey)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    product['name'],
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    "Rp ${product['price']}",
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (youtubeVideoId != null && youtubeVideoId.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                    child: TextButton.icon(
                      icon: Icon(Icons.play_circle_fill_outlined,
                          size: 18, color: Colors.red),
                      label: Text('Tonton Review',
                          style: TextStyle(
                              fontSize: 10, color: Colors.red.shade700)),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () =>
                          _showYouTubePlayerDialog(context, youtubeVideoId),
                    ),
                  ),
                SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        title,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  // --- START: NEW NAVIGATION BAR CODE ---

  Widget _buildBottomNavigationBar(BuildContext context, String currentUserName, String currentUserEmail) {
    // Since this is the HomeScreen, the 'Home' icon is always the active one here.
    // The ModalRoute check is more for generic components, but we'll use it for consistency.
    final String? currentRouteName = ModalRoute.of(context)?.settings.name;
    // The root route is typically '/', which we'll treat as our home route.
    bool isHomeActive = currentRouteName == '/';
    
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
              _buildNavItem(Icons.home, "Home", context, currentUserName, currentUserEmail, isActive: isHomeActive),
              _buildNavItem(Icons.shopping_cart, "Keranjang", context, currentUserName, currentUserEmail, isActive: false),
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
        // The new color logic from your provided code
        color: isActive ? yellowColor : const Color(0xFFF9D33C),
        size: 24,
      ),
      tooltip: label, // Tooltip untuk aksesibilitas
      onPressed: () async { // Made async to preserve await functionality
        // Hindari navigasi ke halaman yang sama jika sudah aktif
        if (isActive) return;

        if (icon == Icons.person) {
          // PRESERVED: Use Navigator.push to await result and then refresh data.
          await Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/profile'), // Add RouteSettings
              builder: (_) => ProfileScreen(),
            ),
          );
          // PRESERVED: Refresh data after returning from ProfileScreen.
          _fetchCartFromFirestore(); 
          _fetchOrderHistoryFromFirestore();

        } else if (icon == Icons.home) {
          // This button should do nothing if we are already on the home screen,
          // which is handled by the `if (isActive) return;` check above.
          // In a scenario where this nav bar is on another page, this would navigate home.
           Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                  settings: RouteSettings(name: '/'), // Use '/' for home route
                  builder: (_) => HomeScreen(
                    name: currentUserName,
                    email: currentUserEmail,
                    cart: cart, // Pass current state
                    orderHistory: orderHistory,
                  ),
              ),
              (route) => false,
            );

        } else if (icon == Icons.shopping_cart) {
          // PRESERVED: Use Navigator.push to await result and then refresh data.
           await Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/checkout'), // Add RouteSettings
              builder: (_) => CheckoutScreen(
                name: currentUserName,
                email: currentUserEmail,
                // Checkout fetches its own cart data, as per original logic.
              ),
            ),
          );
           // PRESERVED: Refresh data after returning from CheckoutScreen.
           _fetchCartFromFirestore();
           _fetchOrderHistoryFromFirestore();

        } else if (icon == Icons.phone) {
          // Use a simple push so the user can easily return to HomeScreen.
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/team_page'), // Add RouteSettings
              builder: (_) => TeamPage(
                cart: cart, // Pass current state
                name: currentUserName,
                email: currentUserEmail,
                orderHistory: orderHistory, // Pass current state
              ),
            ),
          );
        }
      },
    );
  }
  
  // --- END: NEW NAVIGATION BAR CODE ---
}