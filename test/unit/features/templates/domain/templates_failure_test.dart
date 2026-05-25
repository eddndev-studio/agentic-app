import 'package:agentic/features/templates/domain/failures/templates_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TemplatesFailure (sealed)', () {
    test('todas las variantes son subtipos de TemplatesFailure y Exception', () {
      // Sellar la jerarquía obliga a que un switch del bloc cubra todos los
      // casos; un nuevo failure rompe el build en lugar de colarse silencioso.
      // NotFound aterriza con el endpoint de detalle por id: GET
      // /templates/:id sí responde 404 si el id no existe en la org.
      const failures = <TemplatesFailure>[
        TemplatesNetworkFailure(),
        TemplatesTimeoutFailure(),
        TemplatesForbiddenFailure(),
        TemplatesNotFoundFailure(),
        TemplatesServerFailure(),
        UnknownTemplatesFailure(),
      ];

      for (final f in failures) {
        expect(f, isA<TemplatesFailure>());
        expect(f, isA<Exception>());
      }
    });
  });
}
