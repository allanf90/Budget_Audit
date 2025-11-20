import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppContext extends ChangeNotifier {
  Participant? _currentParticipant;
  Template? _currentTemplate;

  Participant? get currentParticipant => _currentParticipant;
  Template? get currentTemplate => _currentTemplate;

  void setParticipant(Participant participant) {
    _currentParticipant = participant;
    notifyListeners();
  }

  void setCurrentTemplate(Template template) {
    _currentTemplate = template;
    notifyListeners();
  }

  void clearCurrentTemplate() {
    _currentTemplate = null;
    notifyListeners();
  }

  Future<void> clear() async {
    _currentParticipant = null;
    _currentTemplate = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_participant_id');
    await prefs.remove('current_template_id');
    notifyListeners();
  }
}