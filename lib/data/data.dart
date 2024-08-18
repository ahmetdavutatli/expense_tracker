import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

List<Map<String, dynamic>> transactionsData = [
  {
    'icons': const FaIcon(FontAwesomeIcons.burger, color: Colors.white,),
    'color': Colors.yellow[700],
    'name': 'Food',
    'totalAmount': '-\$45.00',
    'date': 'Today'
  },
  {
    'icons': const FaIcon(FontAwesomeIcons.tshirt, color: Colors.white,),
    'color': Colors.purple[700],
    'name': 'Clothes',
    'totalAmount': '-\$100.00',
    'date': 'Today'
  },
  {
    'icons': const FaIcon(FontAwesomeIcons.gasPump, color: Colors.white,),
    'color': Colors.red[700],
    'name': 'Fuel',
    'totalAmount': '-\$50.00',
    'date': 'Today'
  },
  {
    'icons': const FaIcon(FontAwesomeIcons.shoppingCart, color: Colors.white,),
    'color': Colors.green[700],
    'name': 'Shopping',
    'totalAmount': '-\$200.00',
    'date': 'Today'
  },
  {
    'icons': const FaIcon(FontAwesomeIcons.burger, color: Colors.white,),
    'color': Colors.yellow[700],
    'name': 'Food',
    'totalAmount': '-\$45.00',
    'date': 'Yesterday'
  },
  {
    'icons': const FaIcon(FontAwesomeIcons.tshirt, color: Colors.white,),
    'color': Colors.purple[700],
    'name': 'Clothes',
    'totalAmount': '-\$100.00',
    'date': 'Yesterday'
  },
];