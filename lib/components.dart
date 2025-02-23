import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pfc/backend.dart';
import 'dart:ui';
import 'package:pfc/colors.dart';

TextEditingController item = TextEditingController();
TextEditingController qty = TextEditingController();
TextEditingController cost = TextEditingController();
TextEditingController price = TextEditingController();
Widget Button1(String a) {
  return Container(
    margin: EdgeInsets.all(10),
    padding: EdgeInsets.all(10),
    width: double.infinity,
    decoration: BoxDecoration(
        border: Border.all(
      color: accent,
      width: 2,
    )),
    child: Center(
      child: FittedBox(
        child: Row(
          children: [
            Text(
              a,
              style: GoogleFonts.roboto(
                  fontSize: 15, color: accent, fontWeight: FontWeight.bold),
            )
          ],
        ),
      ),
    ),
  );
}

Widget Button2(IconData a) {
  return Container(
      margin: EdgeInsets.all(10),
      height: 60,
      width: 60,
      decoration:
          BoxDecoration(color: purple, borderRadius: BorderRadius.circular(20)),
      child: Center(
        child: Icon(
          a,
          color: Colors.white,
        ),
      ));
}

Widget Button3() {
  return Container(
      padding: EdgeInsets.all(10),
      margin: EdgeInsets.all(10),
      height: 60,
      width: 150,
      decoration: BoxDecoration(
          color: primary, borderRadius: BorderRadius.circular(20)),
      child: Center(
        child: Text(
          "ADD NEW",
          style: GoogleFonts.archivoBlack(color: Colors.white, fontSize: 20),
        ),
      ));
}

Widget SearchButton1(String a, TextEditingController b) {
  return TextField(
    cursorColor: primary,
    style: GoogleFonts.archivo(fontSize: 20, color: primary),
    controller: b,
    textAlign: TextAlign.left,
    decoration: InputDecoration(
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide(color: purple, width: 4)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide(color: blue, width: 4)),
      contentPadding: EdgeInsets.all(20),
      labelText: a,
      border: InputBorder.none,
      floatingLabelStyle:
          GoogleFonts.archivoBlack(color: primary, fontSize: 20),
      floatingLabelAlignment: FloatingLabelAlignment.center,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
    ),
  );
}

Widget AddprodDialogue(TextEditingController a, TextEditingController b,
    TextEditingController c, TextEditingController d,BuildContext context,TextEditingController e) {
  return AlertDialog(
      backgroundColor: Color(0xFF232323),
      contentPadding: EdgeInsets.all(30),
      content: Flexible(
          child: Container(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
                flex: 3,
                child: Text(
                  "  NEW PRODUCT  ",
                  style: GoogleFonts.archivoBlack(color: Color(0xFFff9b42), fontSize: 50),
                )),
            Flexible(
              child: Container(
                height: 70,
              ),
            ),
            Flexible(
                flex: 2,
                child: Container(
                  padding: EdgeInsets.all(15),
                  child: TextField(
                    autocorrect: false,
                    cursorColor: Color(0xFFff9b42),
                    style: GoogleFonts.archivo(fontSize: 30, color: Colors.white),
                    controller: a,
                    textAlign: TextAlign.left,
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(color: Color(0xFFff9b42), width: 4)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(color: Color(0xFFff9b42), width: 4)),
                      contentPadding: EdgeInsets.all(30),
                      labelText: " Product Name ",
                      border: InputBorder.none,
                      floatingLabelStyle: GoogleFonts.archivoBlack(
                          color: Colors.white, fontSize: 30),
                      floatingLabelAlignment: FloatingLabelAlignment.center,
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                    ),
                  ),
                )),
            Flexible(
                flex: 2,
                child: Container(
                  padding: EdgeInsets.all(15),
                  child: TextField(
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autocorrect: false,
                    cursorColor: Color(0xFFff9b42),
                    style: GoogleFonts.archivo(fontSize: 30, color: Colors.white),
                    controller: b,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(color: Color(0xFFff9b42), width: 4)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(color: Color(0xFFff9b42), width: 4)),
                      contentPadding: EdgeInsets.all(30),
                      labelText: " Quantity ",
                      border: InputBorder.none,
                      floatingLabelStyle: GoogleFonts.archivoBlack(
                          color: Colors.white, fontSize: 30),
                      floatingLabelAlignment: FloatingLabelAlignment.center,
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                    ),
                  ),
                )),
            Flexible(
                flex: 2,
                child: Container(
                  padding: EdgeInsets.all(15),
                  child: TextField(
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autocorrect: false,
                    cursorColor: Color(0xFFff9b42),
                    style: GoogleFonts.archivo(fontSize: 30, color: Colors.white),
                    controller: c,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(color: Color(0xFFff9b42), width: 4)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(color: Color(0xFFff9b42), width: 4)),
                      contentPadding: EdgeInsets.all(30),
                      labelText: " Cost ",
                      border: InputBorder.none,
                      floatingLabelStyle: GoogleFonts.archivoBlack(
                          color: Colors.white, fontSize: 30),
                      floatingLabelAlignment: FloatingLabelAlignment.center,
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                    ),
                  ),
                )),
            Flexible(
                flex: 2,
                child: Container(
                  padding: EdgeInsets.all(15),
                  child: TextField(
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autocorrect: false,
                    cursorColor: Color(0xFFff9b42),
                    style: GoogleFonts.archivo(fontSize: 30, color: Colors.white),
                    controller: d,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(color: Color(0xFFff9b42), width: 4)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(color: Color(0xFFff9b42), width: 4)),
                      contentPadding: EdgeInsets.all(30),
                      labelText: " Price ",
                      border: InputBorder.none,
                      floatingLabelStyle: GoogleFonts.archivoBlack(
                          color: Colors.white, fontSize: 30),
                      floatingLabelAlignment: FloatingLabelAlignment.center,
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                    ),
                  ),
                )),
            Flexible(
                flex: 2,
                child: Container(
                  padding: EdgeInsets.all(15),
                  child: TextField(
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autocorrect: false,
                    cursorColor: Color(0xFFff9b42),
                    style: GoogleFonts.archivo(fontSize: 30, color: Colors.white),
                    controller: e,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(color: Color(0xFFff9b42), width: 4)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(color: Color(0xFFff9b42), width: 4)),
                      contentPadding: EdgeInsets.all(30),
                      labelText: " COLOR ",
                      border: InputBorder.none,
                      floatingLabelStyle: GoogleFonts.archivoBlack(
                          color: Colors.white, fontSize: 30),
                      floatingLabelAlignment: FloatingLabelAlignment.center,
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                    ),
                  ),
                )),
            Flexible(
                flex: 2,
                child: GestureDetector(
                  onTap: () {
                    MainInventory x = MainInventory();
                    x.insert(a.text, b.text, c.text, d.text,e.text);
                   a.clear();
                   b.clear();
                   c.clear();
                   d.clear();
                   e.clear();
                   Navigator.pop(context);
                  },
                  child: Container(
                      padding: EdgeInsets.all(25),
                      margin: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: grnb,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Center(
                        child: Text(
                          "SAVE",
                          style: GoogleFonts.lexendGiga(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.bold),
                        ),
                      )),
                ))
          ],
        ),
      )));
}

Widget Inventory_Tile(String a, String b, String c, String d, BuildContext context, String id) {
  return Container(
    margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Container(width: 20,),
        Expanded(
          flex: 2,
          child: Text(
            a,
            style: GoogleFonts.lexendGiga(
              fontSize: 20,
              color: Color(0xFF37323e),
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            b,
            textAlign: TextAlign.center,
            style: GoogleFonts.lexend(
              fontSize: 20,
              color: purple,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            c,
            textAlign: TextAlign.center,
            style: GoogleFonts.lexendGiga(
              fontSize: 20,
              color: Colors.black,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            d,
            textAlign: TextAlign.center,
            style: GoogleFonts.lexendGiga(
              fontSize: 20,
              color: purple,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: UpdateprodDialogue(item, qty, cost, price, context, id),
                      );
                    },
                  );
                },
                child: Container(
                  padding: EdgeInsets.all(10),
                  margin: EdgeInsets.symmetric(horizontal: 10),
                  height: 40,
                  decoration: BoxDecoration(
                    color: grnb,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      " UPDATE ",
                      style: GoogleFonts.lexendGiga(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  MainInventory x = MainInventory();
                  x.remove(id);
                },
                icon: Icon(
                  Icons.delete_forever_rounded,
                  color: redb,
                  size: 50,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget Invoice_Tile(String a, String b, String c) {
  return Container(
    margin: EdgeInsets.all(5),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
    child: Row(
      children: [
        Container(
          width: 35,
        ),
        Expanded(
          flex: 2,
          child: Text(
            a,
            style: GoogleFonts.lexendGiga(fontSize: 20, color: grnb),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            b,
            textAlign: TextAlign.center,
            style: GoogleFonts.lexend(fontSize: 20, color: purple),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            c,
            textAlign: TextAlign.center,
            style: GoogleFonts.lexendGiga(fontSize: 20, color: Colors.black),
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: Icon(
            Icons.delete_forever_rounded,
            color: redb,
            size: 50,
          ),
        )
      ],
    ),
  );
}


Widget UpdateprodDialogue(TextEditingController a, TextEditingController b,
    TextEditingController c, TextEditingController d,BuildContext context ,String id) {
  return AlertDialog(
      backgroundColor: Color(0xFF232323),
      contentPadding: EdgeInsets.all(30),
      content: Flexible(
          child: Container(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                    flex: 3,
                    child: Text(
                      "  UPDATE PRODUCT  ",
                      style: GoogleFonts.archivoBlack(color: Color(0xFFff9b42), fontSize: 50),
                    )),
                Flexible(
                  child: Container(
                    height: 70,
                  ),
                ),
                Flexible(
                    flex: 2,
                    child: Container(
                      padding: EdgeInsets.all(15),
                      child: TextField(
                        autocorrect: false,
                        cursorColor: Color(0xFFff9b42),
                        style: GoogleFonts.archivo(fontSize: 30, color: Colors.white),
                        controller: a,
                        textAlign: TextAlign.left,
                        decoration: InputDecoration(
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(color: Color(0xFFff9b42), width: 4)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(color: Color(0xFFff9b42), width: 4)),
                          contentPadding: EdgeInsets.all(30),
                          labelText: " Product Name ",
                          border: InputBorder.none,
                          floatingLabelStyle: GoogleFonts.archivoBlack(
                              color: Colors.white, fontSize: 30),
                          floatingLabelAlignment: FloatingLabelAlignment.center,
                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                        ),
                      ),
                    )),
                Flexible(
                    flex: 2,
                    child: Container(
                      padding: EdgeInsets.all(15),
                      child: TextField(
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        autocorrect: false,
                        cursorColor: Color(0xFFff9b42),
                        style: GoogleFonts.archivo(fontSize: 30, color: Colors.white),
                        controller: b,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(color: Color(0xFFff9b42), width: 4)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(color: Color(0xFFff9b42), width: 4)),
                          contentPadding: EdgeInsets.all(30),
                          labelText: " Quantity ",
                          border: InputBorder.none,
                          floatingLabelStyle: GoogleFonts.archivoBlack(
                              color: Colors.white, fontSize: 30),
                          floatingLabelAlignment: FloatingLabelAlignment.center,
                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                        ),
                      ),
                    )),
                Flexible(
                    flex: 2,
                    child: Container(
                      padding: EdgeInsets.all(15),
                      child: TextField(
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        autocorrect: false,
                        cursorColor: Color(0xFFff9b42),
                        style: GoogleFonts.archivo(fontSize: 30, color: Colors.white),
                        controller: c,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(color: Color(0xFFff9b42), width: 4)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(color: Color(0xFFff9b42), width: 4)),
                          contentPadding: EdgeInsets.all(30),
                          labelText: " Cost ",
                          border: InputBorder.none,
                          floatingLabelStyle: GoogleFonts.archivoBlack(
                              color: Colors.white, fontSize: 30),
                          floatingLabelAlignment: FloatingLabelAlignment.center,
                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                        ),
                      ),
                    )),
                Flexible(
                    flex: 2,
                    child: Container(
                      padding: EdgeInsets.all(15),
                      child: TextField(
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        autocorrect: false,
                        cursorColor: Color(0xFFff9b42),
                        style: GoogleFonts.archivo(fontSize: 30, color: Colors.white),
                        controller: d,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(color: Color(0xFFff9b42), width: 4)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(color: Color(0xFFff9b42), width: 4)),
                          contentPadding: EdgeInsets.all(30),
                          labelText: " Price ",
                          border: InputBorder.none,
                          floatingLabelStyle: GoogleFonts.archivoBlack(
                              color: Colors.white, fontSize: 30),
                          floatingLabelAlignment: FloatingLabelAlignment.center,
                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                        ),
                      ),
                    )),
                Flexible(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () {
                        MainInventory x = MainInventory();
                        x.update(id, a.text, b.text, c.text, d.text);
                        a.clear();
                        b.clear();
                        c.clear();
                        d.clear();
                        Navigator.pop(context);
                      },
                      child: Container(
                          padding: EdgeInsets.all(25),
                          margin: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: grnb,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Center(
                            child: Text(
                              "UPDATE",
                              style: GoogleFonts.lexendGiga(
                                  color: Colors.white,
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold),
                            ),
                          )),
                    ))
              ],
            ),
          )));
}
