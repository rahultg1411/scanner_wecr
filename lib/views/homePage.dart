import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:contacts_service/contacts_service.dart';

enum AppState {
  free,
  picked,
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TextEditingController fName;
  TextEditingController sName;
  TextEditingController pNumber;
  Permission permission;
  Contact contact;
  AppState state;
  File _image;
  final picker = ImagePicker();
  String _exp = '';

  @override
  void initState() {
    super.initState();
    state = AppState.free;
    fName = TextEditingController();
    sName = TextEditingController();
    pNumber = TextEditingController();
    permission = Permission.contacts;
  }

  Future getImage() async {
    final pickedFile = await picker.getImage(source: ImageSource.camera);
    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
        setState(() {
          state = AppState.picked;
        });
      } else {
        print('No image selected.');
      }
    });
  }

  TextEditingController script = TextEditingController();

  Future readText(File image) async {
    FirebaseVisionImage ourImage = FirebaseVisionImage.fromFile(image);
    TextRecognizer recognizeText = FirebaseVision.instance.textRecognizer();
    VisionText readText = await recognizeText.processImage(ourImage);
    script.clear();
    for (TextBlock block in readText.blocks) {
      for (TextLine line in block.lines) {
        for (TextElement word in line.elements) {
          setState(() {
            script.text = script.text + " " + word.text;
          });
        }
        script.text = script.text + '\n';
      }
    }
    _exp = script.text;
    print(_exp);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey[900],
        title: Text('Scanner'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (state == AppState.free) {
            getImage();
          } else if (state == AppState.picked) {
            getText();
          }
        },
        child: buildButtonIcon(),
      ),
      body: Container(
        color: Colors.blueGrey[600],
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 20),
              _image == null
                  ? Text(
                      'No image selected.',
                      style: TextStyle(fontSize: 20, color: Colors.white),
                    )
                  : Container(
                      height: 300, width: 300, child: Image.file(_image)),
              SizedBox(height: 20),
              script.text != null
                  ? Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: TextFormField(
                        controller: script,
                        minLines: 5,
                        maxLines: 100,
                        style: TextStyle(color: Colors.black, fontSize: 16),
                        onChanged: (val) {
                          setState(() {});
                        },
                      ),
                    )
                  : Text("No Text found"),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildButtonIcon() {
    if (state == AppState.free)
      return Icon(
        Icons.add,
        color: Colors.white,
      );
    else if (state == AppState.picked)
      return Icon(
        Icons.arrow_right,
        color: Colors.white,
      );
    else
      return Container();
  }

  _launchURL(String url) async {
    print("Launching");
    print(_exp);
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void _launchPhno(String phno) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Add Contact",
        ),
        content: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            TextField(
              controller: fName,
              autofocus: true,
              decoration: InputDecoration(labelText: "First Name"),
            ),
            TextField(
              controller: sName,
              decoration: InputDecoration(labelText: "Last Name"),
            ),
          ],
        ),
        actions: <Widget>[
          ElevatedButton(
            onPressed: () async {
              if (fName.text.isNotEmpty || sName.text.isNotEmpty) {
                setState(() {
                  contact = Contact(
                    givenName: fName.text,
                    familyName: sName.text,
                    phones: [Item(value: phno)],
                  );
                });
                await ContactsService.addContact(contact);
              }
              Navigator.pop(context);

              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  content: Text(
                    "Contact added",
                  ),
                  actions: <Widget>[
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        "Ok",
                      ),
                    )
                  ],
                ),
              );
            },
            child: Text(
              "Add",
            ),
          )
        ],
      ),
    );
  }

  void getText() async {
    await readText(_image);
    RegExp urlExp;
    RegExp phoneExp;

    urlExp = RegExp(
        r"^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$",
        caseSensitive: false);
    phoneExp =
        RegExp(r"^(\+91[\-\s]?)?[0]?(91)?[789]\d{9}$", caseSensitive: false);

    //_launchPhno(_exp.replaceAll(' ', '').toLowerCase());

    if (urlExp.hasMatch(_exp.replaceAll(' ', '').toLowerCase())) {
      _launchURL(_exp.replaceAll(' ', '').toLowerCase());
    }

    if (phoneExp.hasMatch(_exp.replaceAll(' ', '').toLowerCase())) {
      _launchPhno(_exp.replaceAll(' ', '').toLowerCase());
    }

    setState(() {
      state = AppState.free;
    });
  }
}
