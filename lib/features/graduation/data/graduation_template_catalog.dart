import '../models/graduation_template.dart';
import 'templates/ibjjf_adult_2026_template.dart';
import 'templates/ibjjf_kids_2026_template.dart';

class GraduationTemplateCatalog {
  static final List<GraduationTemplate> templates = [
    ibjjfAdult2026Template,
    ibjjfKids2026Template,
  ];

  static List<GraduationTemplate> get activeTemplates {
    return templates
        .where((template) => template.isActive)
        .toList(growable: false);
  }

  static GraduationTemplate? findById(String templateId) {
    for (final template in templates) {
      if (template.id == templateId) {
        return template;
      }
    }

    return null;
  }
}
