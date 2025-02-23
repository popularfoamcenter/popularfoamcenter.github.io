import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class InvoiceDetailPage extends StatelessWidget {
  final Map<String, dynamic> invoiceData;

  const InvoiceDetailPage({super.key, required this.invoiceData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Scaffold(
        body: Center(
          child: FittedBox(
            child: Container(
              padding: EdgeInsets.all(10),
              color: Color(0xFF2e3440),
              child: Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 20,),
                    Text(
                      "Receipt # ${invoiceData['ReceiptNumber']}",
                      style: GoogleFonts.lexendGiga(
                          fontWeight: FontWeight.bold,
                          fontSize: 30,
                          color: Color(0xFFfb8500)),
                    ),
                    const SizedBox(height: 50),
                    Text(
                      "${invoiceData['CustomerName']}",
                      style:
                          GoogleFonts.abel(fontSize: 15, color: Colors.white),
                    ),
                    Text(
                      "${invoiceData['Contact']}",
                      style:
                          GoogleFonts.abel(fontSize: 15, color: Colors.white),
                    ),
                    Text(
                      "${invoiceData['Address']}",
                      style:
                          GoogleFonts.abel(fontSize: 15, color: Colors.white),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Text(
                          "ITEMS",
                          style: GoogleFonts.lexendGiga(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFfb8500)),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...buildItemList(invoiceData['Items']),
                    const SizedBox(height: 30),
                    Text(
                      "SubTotal: Rs.${invoiceData['SubTotal']}",
                      style:
                          GoogleFonts.abel(fontSize: 18, color: Colors.white),
                    ),
                    Text(
                      "Discount: Rs.${invoiceData['Discount']}",
                      style:
                          GoogleFonts.abel(fontSize: 18, color: Colors.white),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Total: Rs.${invoiceData['Total']}",
                          style: GoogleFonts.oswald(
                              fontSize: 25,
                              color: redb,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> buildItemList(List<dynamic> items) {
    List<Widget> itemWidgets = [];
    for (var item in items) {
      itemWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Text(
            "${item['Name']} - Qty : ${item['Qty']} - Rs.${item['Price']}",
            style: GoogleFonts.abel(fontSize: 16, color: Colors.white),
          ),
        ),
      );
    }
    return itemWidgets;
  }
}
