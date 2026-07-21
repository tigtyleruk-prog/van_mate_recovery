import 'package:flutter/foundation.dart';

import '../models/van_custom_job_question.dart';
import '../models/van_job_service.dart';
import '../models/van_service_configuration_draft.dart';

class VanServiceConfigurationController extends ChangeNotifier {
  VanServiceConfigurationController({
    required List<VanServiceConfigurationDraft> drafts,
    this.initialStage = VanServiceConfigurationStage.features,
  }) : assert(drafts.isNotEmpty),
       _drafts = List<VanServiceConfigurationDraft>.of(drafts),
       _stage = initialStage;

  final VanServiceConfigurationStage initialStage;
  final List<VanServiceConfigurationDraft> _drafts;
  int _serviceIndex = 0;
  late VanServiceConfigurationStage _stage;

  List<VanServiceConfigurationDraft> get drafts => List.unmodifiable(_drafts);
  int get serviceIndex => _serviceIndex;
  int get serviceCount => _drafts.length;
  bool get isMultiService => _drafts.length > 1;
  VanServiceConfigurationStage get stage => _stage;
  VanServiceConfigurationDraft get activeDraft => _drafts[_serviceIndex];

  void replaceService(VanJobService service) {
    if (service.id != activeDraft.service.id) {
      throw ArgumentError.value(service.id, 'service.id', 'Wrong service');
    }
    _drafts[_serviceIndex] = activeDraft.copyWith(service: service);
    notifyListeners();
  }

  void replaceQuestions(Map<String, VanCustomJobQuestion> questions) {
    _drafts[_serviceIndex] = activeDraft.copyWith(questions: questions);
    notifyListeners();
  }

  bool moveNext() {
    if (_stage.index < VanServiceConfigurationStage.values.length - 1) {
      _stage = VanServiceConfigurationStage.values[_stage.index + 1];
      notifyListeners();
      return true;
    }
    if (_serviceIndex >= _drafts.length - 1) return false;
    _serviceIndex++;
    _stage = VanServiceConfigurationStage.features;
    notifyListeners();
    return true;
  }

  bool moveBack() {
    if (_stage.index > 0) {
      _stage = VanServiceConfigurationStage.values[_stage.index - 1];
      notifyListeners();
      return true;
    }
    if (_serviceIndex == 0) return false;
    _serviceIndex--;
    _stage = VanServiceConfigurationStage.availability;
    notifyListeners();
    return true;
  }
}
