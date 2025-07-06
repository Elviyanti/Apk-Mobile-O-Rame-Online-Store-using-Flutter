import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import '7-profile_screen.dart'; 
import 'package:uas/custom_splash_screen.dart'; // Pastikan path ini benar
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderPage extends StatefulWidget {
  final List<Map<String, dynamic>> selectedCart;
  final String name;
  final String email;

  const OrderPage({
    Key? key,
    required this.selectedCart,
    required this.name,
    required this.email,
  }) : super(key: key);

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  // --- SEMUA STATE DAN CONTROLLER DARI KODE ASLI ANDA TETAP DIPERTAHANKAN ---
  String? _paymentMethod;
  LatLng? _selectedLocation;
  String? _selectedAddress;
  final MapController _mapController = MapController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  bool _isProcessingOrder = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _noteController.dispose();
    _addressController.dispose();
    super.dispose();
  }
  
  // --- SEMUA LOGIKA FUNGSI DARI KODE ASLI ANDA TETAP DIPERTAHANKAN ---

  Future<void> _getAddressFromLatLng(LatLng latlng) async {
    if (!mounted) return;
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latlng.latitude,
        latlng.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        setState(() {
          _selectedAddress =
              '${place.street ?? ''}${place.street != null && (place.subLocality != null || place.locality != null) ? ', ' : ''}${place.subLocality ?? ''}${place.subLocality != null && place.locality != null ? ', ' : ''}${place.locality ?? ''}${place.locality != null && place.administrativeArea != null ? ', ' : ''}${place.administrativeArea ?? ''}${place.administrativeArea != null && place.country != null ? ', ' : ''}${place.country ?? ''}'
                  .trim()
                  .replaceAll(RegExp(r'^, |,$'), '');
          _addressController.text = _selectedAddress!;
        });
      }
    } catch (e) {
      print('Gagal mengambil alamat dari peta: $e');
      if (mounted) {
        showMessage('Gagal mengambil alamat dari peta. Silakan isi manual.');
      }
    }
  }

  void _showConfirmationDialog(BuildContext context) {
    // Logika validasi dan dialog dari kode asli Anda dipertahankan.
    // Ditambahkan koneksi ke Firebase dan proses order.
    showDialog(
      context: context,
      barrierDismissible: !_isProcessingOrder,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.black,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Pastikan semua informasi sudah benar sebelum melanjutkan!',
                    style: TextStyle(
                        color: Color(0xFFF9D33C),
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  if (_isProcessingOrder)
                    const CircularProgressIndicator(color: Color(0xFFFFC727))
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFC727),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20))),
                          onPressed: () async {
                            final String name = _nameController.text.trim();
                            final String contact = _contactController.text.trim();
                            final String address = _addressController.text.trim();

                            if (name.isEmpty) { showMessage("Nama penerima tidak boleh kosong!"); return; }
                            if (address.isEmpty) { showMessage("Alamat tidak boleh kosong! Pilih di peta atau isi manual."); return; }
                            if (contact.isEmpty) { showMessage("Kontak tidak boleh kosong!"); return; }
                            if (_paymentMethod == null) { showMessage("Pilih metode pembayaran terlebih dahulu!"); return; }

                            final User? user = FirebaseAuth.instance.currentUser;
                            if (user == null) {
                              showMessage("Sesi login Anda berakhir. Silakan login kembali.");
                              if (mounted) Navigator.pop(dialogContext);
                              return;
                            }

                            if (mounted) { setState(() { _isProcessingOrder = true; }); }
                            setDialogState(() {});

                            try {
                              List<Map<String, dynamic>> itemsForFirestore = widget.selectedCart.map((item) {
                                return {
                                  'productId': item['id'] ?? 'unknown_product_${DateTime.now().millisecondsSinceEpoch}',
                                  'productName': item['name'] ?? 'Unknown Product', 'price': item['price'] ?? 0,
                                  'quantity': item['quantity'] ?? 1, 'image': item['image'] ?? '',
                                };
                              }).toList();
                              int totalAmount = 0;
                              for (var item in widget.selectedCart) { totalAmount += (item['price'] as int? ?? 0) * (item['quantity'] as int? ?? 1); }
                              Map<String, dynamic> orderData = {
                                'userId': user.uid, 'userName': name, 'userEmail': widget.email,
                                'shippingAddress': address, 'contactNumber': contact, 'notes': _noteController.text.trim(),
                                'paymentMethod': _paymentMethod, 'items': itemsForFirestore, 'totalAmount': totalAmount,
                                'orderDate': Timestamp.now(), 'status': 'Pending',
                                'location': _selectedLocation != null ? GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude) : null,
                              };
                              DocumentReference orderRef = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('orders').add(orderData);
                              WriteBatch batch = FirebaseFirestore.instance.batch();
                              bool hasItemsToRemove = false;
                              for (var orderedItem in widget.selectedCart) {
                                String? cartDocId = orderedItem['cartDocId'] as String?;
                                if (cartDocId != null && cartDocId.isNotEmpty) {
                                  DocumentReference cartItemRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('cart').doc(cartDocId);
                                  batch.delete(cartItemRef);
                                  hasItemsToRemove = true;
                                }
                              }
                              if (hasItemsToRemove) { await batch.commit(); }
                              final String createdOrderId = orderRef.id;
                              final int createdOrderTotalAmount = totalAmount;
                              final List<Map<String, dynamic>> createdOrderItemsSummary = List.from(itemsForFirestore);
                              if (mounted) { Navigator.pop(dialogContext); }
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CustomSplashScreen(
                                    nextScreen: ProfileScreen(
                                      newlyCreatedOrderId: createdOrderId,
                                      newlyCreatedOrderTotal: createdOrderTotalAmount,
                                      newlyCreatedOrderItems: createdOrderItemsSummary,
                                    ),
                                  ),
                                ), (route) => false);
                            } catch (e) {
                              print("Error processing order: $e");
                              if (mounted) { showMessage("Gagal memproses pesanan: ${e.toString()}"); }
                            } finally {
                              if (mounted) { setState(() { _isProcessingOrder = false; }); }
                               setDialogState(() {});
                            }
                          },
                          child: const Text('Konfirmasi Pesanan'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white, foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                          onPressed: () { if (!_isProcessingOrder) Navigator.pop(dialogContext); },
                          child: const Text('Kembali'),
                        ),
                      ],
                    ),
                ],
              );
            }
          ),
        ),
      ),
    );
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Tampilan `build` method diganti total agar sesuai dengan kode target.
      body: Stack(
        children: [
          // Background dari kode target
          Align(
            alignment: Alignment.topLeft,
            child: Container(
              height: 220,
              decoration: const BoxDecoration(
                color: Color(0xFFFFC727), // Warna kuning dari target
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(80)),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              height: 210,
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(topRight: Radius.circular(80)),
              ),
            ),
          ),
          // Konten utama dari kode target
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 8),
                      const Text('Order',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 30),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        // Box shadow dari kode asli Anda (lebih halus)
                        boxShadow: [
                            BoxShadow(
                                color: Colors.grey.withOpacity(0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 5))
                          ]
                      ),
                      child: Column(
                        children: [
                          Image.asset(
                            'image/logo2.png', // path dari kode target
                            width: 180, height: 140,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.image_not_supported, size: 100, color: Colors.grey);
                            },
                          ),
                          const SizedBox(height: 10),
                          _buildLabel('Penerima'),
                          _buildTextField('Masukkan Nama',
                              icon: Icons.person, controller: _nameController),
                          const SizedBox(height: 12),
                          _buildLabel('Alamat Pengiriman'),
                          _buildTextField('Masukkan Alamat Lengkap',
                              icon: Icons.location_on,
                              controller: _addressController,
                              maxLines: 2),
                          const SizedBox(height: 12),
                          _buildLabel('Pilih Lokasi di Peta'),
                          const SizedBox(height: 8),
                          // UI untuk menampilkan alamat terpilih dari map (dipertahankan dari kode asli)
                          if (_selectedAddress != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300)),
                              child: Row(children: [
                                const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text("Peta: $_selectedAddress", style: const TextStyle(fontSize: 12))),
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18, color: Colors.redAccent),
                                  onPressed: () => setState(() { _selectedAddress = null; _selectedLocation = null; }),
                                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                                )
                              ]),
                            ),
                          ],
                          // Map dipertahankan dari kode asli
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12.0),
                            child: SizedBox(
                              height: 200,
                              child: FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: _selectedLocation ?? LatLng(-6.200000, 106.816666),
                                  initialZoom: 13.0,
                                  onTap: (tapPosition, latlng) {
                                    _getAddressFromLatLng(latlng);
                                    setState(() {
                                      _selectedLocation = latlng;
                                      if (_mapController.camera.zoom < 15) { _mapController.move(latlng, 15.0); } 
                                      else { _mapController.move(latlng, _mapController.camera.zoom); }
                                    });
                                  },
                                ),
                                children: [
                                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                                  if (_selectedLocation != null)
                                    MarkerLayer(markers: [
                                      Marker(point: _selectedLocation!,
                                          width: 40, height: 40,
                                          child: const Icon(Icons.location_pin, color: Colors.red, size: 40))
                                    ])
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildLabel('Kontak Penerima'),
                          _buildTextField('Masukkan Nomor Telepon',
                              icon: Icons.phone,
                              controller: _contactController,
                              keyboardType: TextInputType.phone),
                          const SizedBox(height: 12),
                          _buildLabel('Catatan (Opsional)'),
                          _buildTextField('Misal: Pagar warna hitam, dll.',
                              icon: Icons.note,
                              controller: _noteController,
                              maxLines: 3),
                          const SizedBox(height: 12),
                          _buildLabel('Pembayaran'),
                          // Opsi pembayaran dari kode target
                          Row(
                            children: [
                              Radio<String>(
                                value: 'COD',
                                groupValue: _paymentMethod,
                                onChanged: (value) => setState(() => _paymentMethod = value),
                                activeColor: const Color(0xFFFFC727),
                              ),
                              const Text('COD'),
                              const SizedBox(width: 20),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Tombol order dari kode target, tapi dengan fungsionalitas dari kode asli
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFC727),
                              minimumSize: const Size.fromHeight(45),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                            ),
                            onPressed: _isProcessingOrder ? null : () => _showConfirmationDialog(context),
                            child: _isProcessingOrder
                                ? const SizedBox(
                                    height: 24, width: 24,
                                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3))
                                : const Text('Order', style: TextStyle(color: Colors.black)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- HELPER WIDGETS DIGANTI AGAR SESUAI TAMPILAN TARGET ---

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
        child: Text(text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTextField(String hint,
      {IconData? icon,
      TextEditingController? controller,
      int maxLines = 1, // Parameter ini ditambahkan kembali
      TextInputType? keyboardType}) { // Parameter ini ditambahkan kembali
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        prefixIcon: icon != null ? Icon(icon) : null,
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade200,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}