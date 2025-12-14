import 'package:flutter/material.dart';

/// Border radius система
class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 999;
  
  static BorderRadius get radiusSM => BorderRadius.circular(sm);
  static BorderRadius get radiusMD => BorderRadius.circular(md);
  static BorderRadius get radiusLG => BorderRadius.circular(lg);
  static BorderRadius get radiusXL => BorderRadius.circular(xl);
  static BorderRadius get radiusFull => BorderRadius.circular(full);
  
  // Top only
  static BorderRadius get radiusTopSM => BorderRadius.vertical(top: Radius.circular(sm));
  static BorderRadius get radiusTopMD => BorderRadius.vertical(top: Radius.circular(md));
  static BorderRadius get radiusTopLG => BorderRadius.vertical(top: Radius.circular(lg));
  
  // Bottom only
  static BorderRadius get radiusBottomSM => BorderRadius.vertical(bottom: Radius.circular(sm));
  static BorderRadius get radiusBottomMD => BorderRadius.vertical(bottom: Radius.circular(md));
  static BorderRadius get radiusBottomLG => BorderRadius.vertical(bottom: Radius.circular(lg));
}









