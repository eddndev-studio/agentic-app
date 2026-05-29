import 'entities/conditional_time_metadata.dart';
import 'entities/step.dart';

/// Remapea los destinos de los pasos CONDITIONAL_TIME cuando el flow se
/// reordena, para que las flechas sigan apuntando al *paso lógico* destino
/// (el step que el operador eligió) y no a la posición que ocupaba antes.
///
/// `onMatchOrder`/`onElseOrder` son referencias **posicionales** en el wire:
/// guardan el `order` del step destino, no su id. Al reordenar, ese order
/// queda obsoleto y la bifurcación apuntaría al step equivocado en silencio.
/// Esta función recompone los destinos siguiendo la identidad del step.
///
/// - [snapshot]: lista vigente de steps (ordenada por `order` ASC).
/// - [newIdOrder]: ids en el orden destino; el reorder reasigna
///   `order = índice`, de modo que el espacio de orders nuevo es contiguo
///   `0..n-1`.
///
/// El mapeo del estado viejo se indexa por `step.order` (el valor del campo),
/// **no** por el índice de lista: los destinos viven en el espacio de orders
/// y este puede tener huecos (p. ej. si un borrado no renumeró). Indexar por
/// índice mis-apuntaría ante cualquier hueco.
///
/// Devuelve `stepId → nuevo metadataJson` SOLO para los CT cuyos destinos
/// cambiaron — los demás no necesitan PATCH. Un CT con metadata ilegible se
/// omite (se deja intacto; el operador lo verá marcado como inválido y podrá
/// reconfigurarlo). Un destino colgante (sin step en esa posición) se
/// preserva tal cual: no hay paso lógico al que seguir.
///
/// Limitación: solo protege reorders hechos desde este cliente. El wire sigue
/// siendo posicional, así que un reorder fuera de banda (otro cliente, API
/// directa, seed) derivaría igual; el fix robusto es migrar el wire a
/// referencias por id. Además, el remap re-serializa con `toJsonString`, que
/// reconstruye el blob solo desde los campos modelados (tz/windows/destinos):
/// si el backend añadiera una clave nueva al metadata CT, reordenar la
/// perdería. Hoy sin impacto — la entidad es el shape completo conocido.
Map<String, String> remapConditionalTargetsOnReorder(
  List<Step> snapshot,
  List<String> newIdOrder,
) {
  final oldIdByOrder = <int, String>{for (final s in snapshot) s.order: s.id};
  final newOrderById = <String, int>{
    for (var i = 0; i < newIdOrder.length; i++) newIdOrder[i]: i,
  };

  int remapTarget(int oldOrder) {
    final id = oldIdByOrder[oldOrder];
    if (id == null) return oldOrder; // colgante: sin step lógico al que seguir
    return newOrderById[id] ?? oldOrder;
  }

  final result = <String, String>{};
  for (final s in snapshot) {
    if (s.type != StepType.conditionalTime) continue;
    final ConditionalTimeMetadata md;
    try {
      md = ConditionalTimeMetadata.fromJsonString(s.metadataJson);
    } on FormatException {
      continue; // ilegible: no se puede remapear, se deja intacta
    }
    final newMatch = remapTarget(md.onMatchOrder);
    final newElse = remapTarget(md.onElseOrder);
    if (newMatch == md.onMatchOrder && newElse == md.onElseOrder) continue;
    result[s.id] = ConditionalTimeMetadata(
      tz: md.tz,
      windows: md.windows,
      onMatchOrder: newMatch,
      onElseOrder: newElse,
    ).toJsonString();
  }
  return result;
}
