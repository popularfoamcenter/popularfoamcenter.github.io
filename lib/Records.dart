import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';
import 'InvoiceDetailPage.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  final CollectionReference invoices =
      FirebaseFirestore.instance.collection("Invoices");

  Future<double> calculateProfit(DateTime startDate, DateTime endDate) async {
    double profit = 0;

    var snapshot = await invoices
        .where('Time', isGreaterThanOrEqualTo: startDate)
        .where('Time', isLessThanOrEqualTo: endDate)
        .get();

    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      profit += data['Total'] ?? 0;
    }

    return profit;
  }

  void showProfitPopup() async {
    DateTime today = DateTime.now();
    DateTime last30Days = today.subtract(Duration(days: 30));
    DateTime lastYear = DateTime(today.year - 1, today.month, today.day);

    double todayProfit = await calculateProfit(
        DateTime(today.year, today.month, today.day), today);
    double last30DaysProfit = await calculateProfit(last30Days, today);
    double lastYearProfit = await calculateProfit(lastYear, today);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Container(
          height: 400,
          width: 500,
          child: Container(
            margin: EdgeInsets.all(10),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                color: Color(0xFF023047)),
            child: Column(
              children: [
                Container(
                  height: 30,
                ),
                Center(
                  child: Text(
                    "Profits",
                    style: GoogleFonts.archivoBlack(
                        color: Colors.white, fontSize: 80),
                  ),
                ),
                Container(
                  height: 60,
                ),
                Text(
                  "Day = Rs.${todayProfit}",
                  style: GoogleFonts.oswald(color: Colors.white, fontSize: 25),
                ),
                Text(
                  "Month = Rs.${last30DaysProfit}",
                  style: GoogleFonts.oswald(color: Colors.white, fontSize: 25),
                ),
                Text(
                  "Year = Rs.${lastYearProfit}",
                  style: GoogleFonts.oswald(color: Colors.white, fontSize: 25),
                )
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: GoogleFonts.roboto(fontSize: 18, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
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
                    "RECORDS",
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
                    const SizedBox(height: 20),
                    buildInvoiceList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: showProfitPopup,
        backgroundColor: Colors.blueAccent,
        child: Icon(
          Icons.show_chart,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget buildInvoiceList() {
    return StreamBuilder<QuerySnapshot>(
      stream: invoices.orderBy('Time', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No records found.'));
        }

        var invoiceDocs = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          itemCount: invoiceDocs.length,
          itemBuilder: (context, index) {
            var invoiceData = invoiceDocs[index].data() as Map<String, dynamic>;
            return Card(
              child: ListTile(
                title: Text(
                  "Receipt No : ${invoiceData['ReceiptNumber']}",
                  style: GoogleFonts.oswald(
                      fontWeight: FontWeight.bold, fontSize: 25),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${invoiceData['CustomerName']}",
                      style:
                          GoogleFonts.abel(color: Colors.black, fontSize: 18),
                    ),
                    Text(
                      "Total: Rs.${invoiceData['Total']}",
                      style:
                          GoogleFonts.abel(color: Colors.green, fontSize: 18),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(Icons.print, color: Colors.blue),
                  onPressed: () {},
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InvoiceDetailPage(
                        invoiceData: invoiceData,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
