import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MainInventory {
  CollectionReference inventory =
      FirebaseFirestore.instance.collection("Inventory");

  // INSERT
  Future<void> insert(String name, String quantity, String cost, String price,String color) {
    return inventory.add({
      'Name': name,
      'Quantity': quantity,
      'Cost': cost,
      'Price': price,
      'Color':color,
      'Time': DateTime.timestamp()
    });
  }

// UPDATE
  Future<void> update(String docID, String name, String quantity, String cost, String price) {
    return inventory.doc(docID).update({
      'Name': name,
      'Quantity': quantity,
      'Cost': cost,
      'Price': price,
      'Time': DateTime.timestamp()
    });
  }

// REMOVE
  Future<void> remove(String docID) {
    return inventory.doc(docID).delete();
  }

// FETCH
  Stream<QuerySnapshot> read() {
    final data = inventory.orderBy('Time', descending: true).snapshots();
    return data;
  }
}

