import 'dart:async'; // For debounce
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'colors.dart';
import 'package:google_fonts/google_fonts.dart';

class InvoicePage extends StatefulWidget {
  const InvoicePage({super.key});

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  final CollectionReference invoices =
  FirebaseFirestore.instance.collection("Invoices");
  final CollectionReference inventory =
  FirebaseFirestore.instance.collection("Inventory");

  final TextEditingController customerName = TextEditingController();
  final TextEditingController contact = TextEditingController();
  final TextEditingController address = TextEditingController();
  final TextEditingController search = TextEditingController();
  final TextEditingController discount = TextEditingController();

  final List<Map<String, dynamic>> cart = [];
  double subTotal = 0;
  double total = 0;
  List<DocumentSnapshot> searchResults = [];
  Timer? _debounce;

  void calculateTotals() {
    subTotal = cart.fold(
        0, (sum, item) => sum + (double.parse(item['Price']) * item['Qty']));
    double discountAmount = double.tryParse(discount.text) ?? 0;
    total = subTotal - discountAmount;
    setState(() {});
  }

  Future<void> saveInvoice() async {
    int receiptNumber = (await invoices.get()).docs.length + 1;

    // Update stock in inventory
    for (var item in cart) {
      DocumentSnapshot itemDoc = await inventory
          .where('Name', isEqualTo: item['Name'])
          .limit(1)
          .get()
          .then((query) => query.docs.first);

      int currentStock = int.parse(itemDoc['Quantity']);
      int qtySold = item['Qty'];

      if (currentStock < qtySold) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Insufficient stock for ${item['Name']}")));
        return;
      }

      await inventory.doc(itemDoc.id).update({
        'Quantity': (currentStock - qtySold).toString(),
      });
    }

    // Save invoice
    await invoices.add({
      'ReceiptNumber': receiptNumber,
      'CustomerName': customerName.text,
      'Contact': contact.text,
      'Address': address.text,
      'Items': cart,
      'SubTotal': subTotal,
      'Discount': discount.text,
      'Total': total,
      'Time': DateTime.now(),
    });

    clearForm();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Invoice saved successfully!")));
  }

  void clearForm() {
    customerName.clear();
    contact.clear();
    address.clear();
    search.clear();
    cart.clear();
    discount.text = "0";
    searchResults.clear();
    calculateTotals();
  }

  void searchItems(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        setState(() {
          searchResults = [];
        });
        return;
      }
      var snapshot = await inventory.get();
      List<DocumentSnapshot> items = snapshot.docs.where((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['Name']
            .toString()
            .toLowerCase()
            .contains(query.toLowerCase());
      }).toList();

      setState(() {
        searchResults = items;
      });
    });
  }

  void addItemToCart(DocumentSnapshot itemDoc) {
    var itemData = itemDoc.data() as Map<String, dynamic>;
    int stockQty = int.parse(itemData['Quantity']);
    if (stockQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Item ${itemData['Name']} is out of stock!")));
      return;
    }

    int index = cart.indexWhere((item) => item['Name'] == itemData['Name']);
    if (index >= 0) {
      setState(() {
        if (cart[index]['Qty'] < stockQty) {
          cart[index]['Qty'] += 1;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  "Only $stockQty units of ${itemData['Name']} available!")));
        }
      });
    } else {
      setState(() {
        cart.add({
          'Name': itemData['Name'],
          'Price': itemData['Price'],
          'Qty': 1,
        });
      });
    }
    calculateTotals();
    search.clear();
    searchResults.clear();
  }

  void updateItemQuantity(int index, int change) {
    setState(() {
      cart[index]['Qty'] += change;
      if (cart[index]['Qty'] <= 0) {
        cart.removeAt(index);
      }
      calculateTotals();
    });
  }

  @override
  void initState() {
    super.initState();
    search.addListener(() {
      searchItems(search.text);
    });
    discount.addListener(calculateTotals);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: FloatingActionButton(
          child: Container(
            height: 60,
            width: 200,
            decoration: BoxDecoration(
                color: purple, borderRadius: BorderRadius.circular(10)),
            child: Center(
              child: Icon(Icons.save, color: Colors.white, size: 40),
            ),
          ),
          onPressed: () {
            saveInvoice();
          }),
      body: SingleChildScrollView(
        child: Column(
          children: [

            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(gradient: Primary_Gradient),
              child: Center(
                child: FittedBox(
                  child: Text(
                    "INVOICE",
                    style: GoogleFonts.archivoBlack(
                        color: Colors.white, fontSize: 20),
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 500,
                margin: EdgeInsets.all(30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 10),
                    buildTextField(customerName, "Customer Name"),
                    Container(height: 15),
                    buildTextField(contact, "Contact"),
                    Container(height: 15),
                    buildTextField(address, "Address"),
                    Container(height: 15),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Center(
                          child: Text(
                            "CART",
                            style: GoogleFonts.archivoBlack(
                                fontSize: 40, color: grnb),
                          ),
                        ),
                        const SizedBox(height: 20),
                        buildSearchField(),
                        if (searchResults.isNotEmpty) buildSearchResults(),
                        const SizedBox(height: 20),
                        ListView.builder(
                          shrinkWrap: true,
                          itemCount: cart.length,
                          itemBuilder: (context, index) {
                            var item = cart[index];
                            return Card(
                              child: ListTile(
                                title: Text(
                                  item['Name'],
                                  style: GoogleFonts.roboto(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  "Price Per Unit = Rs.${item['Price']}",
                                  style: GoogleFonts.roboto(color: dark),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon:
                                      Icon(Icons.remove, color: Colors.red),
                                      onPressed: () =>
                                          updateItemQuantity(index, -1),
                                    ),
                                    Text('${item['Qty']}'),
                                    IconButton(
                                      icon: Icon(Icons.add, color: Colors.green),
                                      onPressed: () =>
                                          updateItemQuantity(index, 1),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        Container(height: 10,),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: primary),
                              padding: EdgeInsets.all(14),
                              child: Text(
                                "SubTotal = $subTotal",
                                style: GoogleFonts.roboto(
                                    fontSize: 15,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            SizedBox(
                              width: 100,
                              child: TextField(
                                autocorrect: false,
                                cursorColor: purple,
                                style: GoogleFonts.archivo(
                                    fontSize: 15, color: Colors.black),
                                controller: discount,
                                textAlign: TextAlign.left,
                                decoration: InputDecoration(
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(11),
                                      borderSide:
                                      BorderSide(color: purple, width: 4)),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide:
                                      BorderSide(color: purple, width: 4)),
                                  contentPadding: EdgeInsets.all(10),
                                  labelText: " Discount ",
                                  border: InputBorder.none,
                                  floatingLabelStyle: GoogleFonts.archivoBlack(
                                      color: purple, fontSize: 15),
                                  floatingLabelAlignment:
                                  FloatingLabelAlignment.start,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: Primary_Gradient),
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            "TOTAL = $total",
                            style: GoogleFonts.archivoBlack(
                                fontSize: 25, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget buildTextField(TextEditingController controller, String label) {
    return TextField(
      autocorrect: false,
      cursorColor: purple,
      style: GoogleFonts.archivo(fontSize: 15, color: Colors.black),
      controller: controller,
      textAlign: TextAlign.left,
      decoration: InputDecoration(
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide(color: purple, width: 4)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: purple, width: 4)),
        contentPadding: EdgeInsets.all(10),
        labelText: label,
        border: InputBorder.none,
        floatingLabelStyle:
        GoogleFonts.archivoBlack(color: purple, fontSize: 15),
        floatingLabelAlignment: FloatingLabelAlignment.start,
      ),
    );
  }

  Widget buildSearchField() {
    return TextField(
      autocorrect: false,
      cursorColor: purple,
      style: GoogleFonts.archivo(fontSize: 15, color: Colors.black),
      controller: search,
      textAlign: TextAlign.left,
      decoration: InputDecoration(
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide(color: purple, width: 4)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: purple, width: 4)),
        contentPadding: EdgeInsets.all(10),
        labelText: " Search ",
        border: InputBorder.none,
        floatingLabelStyle:
        GoogleFonts.archivoBlack(color: purple, fontSize: 15),
        floatingLabelAlignment: FloatingLabelAlignment.start,
      ),
    );
  }

  Widget buildSearchResults() {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        var item = searchResults[index].data() as Map<String, dynamic>;
        return Card(
          child: ListTile(
            title: Text(item['Name']),
            subtitle: Text("Price: Rs.${item['Price']} - Qty: ${item['Quantity']}"),
            trailing: IconButton(
              icon: Icon(Icons.add),
              onPressed: () {
                addItemToCart(searchResults[index]);
              },
            ),
          ),
        );
      },
    );
  }
}
