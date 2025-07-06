// detail.dart
import 'package:flutter/material.dart';

class DetailScreen extends StatefulWidget {
  final Map<String, dynamic> product; // Product map now includes 'id' from Firestore document ID of the product

  DetailScreen({required this.product});

  @override
  _DetailScreenState createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  int quantity = 1;

  @override
  Widget build(BuildContext context) {
    // Variabel dari kode asli Anda untuk null-safety
    final String? productImage = widget.product['image'];
    final String productName = widget.product['name'] ?? 'Nama Produk Tidak Tersedia';
    final int productPrice = widget.product['price'] as int? ?? 0;
    final String? productId = widget.product['id'] as String?; // This is the PRODUCT's Firestore ID

    // Fungsionalitas error handling dari kode asli Anda
    if (productId == null) {
      print("ERROR: Product ID is null in DetailScreen.");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ID produk tidak ditemukan.')),
        );
        Navigator.pop(context);
      });
      return Scaffold(body: Center(child: Text("Error memuat detail produk.")));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFFF9D33C)),
          onPressed: () => Navigator.pop(context),
        ),
        // Title dihapus sesuai layout target
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFFF9D33C),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(50),
                      topRight: Radius.circular(50),
                    ),
                  ),
                  margin: EdgeInsets.only(top: 120),
                  child: SingleChildScrollView( // Mempertahankan SingleChildScrollView dari kode asli
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Spasi untuk mendorong konten ke bawah gambar, sesuai layout target
                        SizedBox(height: 100), 
                        
                        // Teks dari kode asli Anda
                        Text(productName, style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.black)),
                        SizedBox(height: 8),
                        Text("Rp $productPrice", style: TextStyle(fontSize: 25, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                        SizedBox(height: 15),
                        
                        // Deskripsi dari kode asli Anda (lebih dinamis)
                        Text(
                          widget.product['description'] ??
                          "Nikmati ${productName} ini yang memanjakan lidah anda. "
                          "Disajikan dengan bahan berkualitas tinggi, menghasilkan cita rasa autentik. "
                          "Hidangan ini cocok untuk dinikmati kapan saja, baik saat bersantai maupun saat berkumpul bersama keluarga dan teman-teman. "
                          "Jangan lewatkan kesempatan untuk mencicipi kelezatan yang tak terlupakan! 🍛✨",
                          style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.4, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 10),
                        
                        // Cara memesan dari kode asli Anda
                        Text(
                          "Cara Memesan:\n"
                          "1. Pilih kuantitas yang diinginkan.\n"
                          "2. Klik tombol 'Masukkan Keranjang'.\n"
                          "3. Lanjutkan ke halaman checkout untuk pembayaran.",
                          style: TextStyle(fontSize: 14, color: Colors.black),
                        ),
                        SizedBox(height: 20),

                        // Quantity selector dari kode asli, disederhanakan tampilannya
                        Row(
                           mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove, color: Colors.black),
                              onPressed: () {
                                if (quantity > 1) setState(() => quantity--);
                              },
                            ),
                            Text('$quantity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                            IconButton(
                              icon: Icon(Icons.add, color: Colors.black),
                              onPressed: () => setState(() => quantity++),
                            ),
                          ],
                        ),
                        SizedBox(height: 30),

                        // Tombol-tombol baru sesuai layout target
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Tombol Chat (fungsi kosong sesuai target)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              onPressed: () {},
                              child: Icon(Icons.chat, color: Colors.white),
                            ),
                            // Tombol Masukkan Keranjang
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 10.0),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    padding: EdgeInsets.symmetric(vertical: 15),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  // PENTING: Logika onPressed ini diambil dari kode asli Anda
                                  // untuk memastikan fungsionalitas penambahan ke keranjang tetap berjalan dengan benar.
                                  onPressed: () {
                                    Navigator.pop(context, {
                                      'id': productId,
                                      'name': productName,
                                      'price': productPrice,
                                      'image': productImage ?? '',
                                      'quantity': quantity,
                                      'category': widget.product['category'],
                                      'description': widget.product['description'],
                                    });
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.shopping_cart, color: Colors.white),
                                      SizedBox(width: 10),
                                      Text("Masukkan Keranjang", style: TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 20, 
                  // Menggunakan Image.network dan Hero dari kode asli Anda untuk menjaga fungsionalitas
                  child: Hero( 
                    tag: productId, 
                    child: (productImage != null && productImage.isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.network(
                              productImage,
                              height: 200, 
                              width: 200,  
                              fit: BoxFit.cover,
                              loadingBuilder: (ctx, child, progress) => progress == null ? child : Container(height: 200, width: 200, child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.black)))),
                              errorBuilder: (ctx, err, trace) => Container(height: 200, width: 200, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(15)), child: Center(child: Icon(Icons.broken_image, size: 80, color: Colors.grey[600]))),
                            ),
                          )
                        : Container(height: 200, width: 200, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(15)), child: Center(child: Icon(Icons.image_not_supported, size: 80, color: Colors.grey[600]))),
                  ),
                ),
              ],
            ),
          ),
          // Container bawah dari kode asli dihapus karena tombol sudah dipindahkan ke atas
        ],
      ),
    );
  }
}