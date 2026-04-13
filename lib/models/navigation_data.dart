import 'package:flutter/material.dart';

enum NavigationInstruction {
  straight,
  turnLeft,
  turnRight,
  uTurn,
  arrival,
}

class NavigationData {
  final NavigationInstruction instruction;
  final String streetName;
  final double distanceToTurn; // in meters
  final IconData icon;

  NavigationData({
    required this.instruction,
    required this.streetName,
    required this.distanceToTurn,
    required this.icon,
  });

}
