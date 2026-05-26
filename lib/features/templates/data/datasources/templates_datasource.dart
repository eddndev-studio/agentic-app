import 'package:dio/dio.dart';

import '../../domain/entities/template.dart';
import '../../domain/entities/variable_def.dart';
import '../../domain/failures/templates_failure.dart';
import '../dto/template_dto.dart';
import '../dto/var_def_dto.dart';
import '../mappers/templates_mapper.dart';
import '../mappers/var_defs_mapper.dart';

/// Puerto de datos para los endpoints de Template (S03).
///
/// Las implementaciones lanzan `TemplatesFailure` tipadas; nunca
/// DioException cruda. El repositorio y el bloc consumen failures de
/// dominio. Drift de contrato del backend (proveedor IA desconocido) NO
/// se mapea a una failure — propaga el `ArgumentError` del enum fail-loud
/// para detectar el bug en boot, no degradarlo a un spinner reintentable.
abstract interface class TemplatesDatasource {
  /// `GET /templates` org-scoped. El AuthInterceptor inyecta el Bearer;
  /// aquí no se gestiona. RBAC del backend rechaza con 403 si el rol no
  /// alcanza (CRUD de Template = ADMIN+).
  Future<List<Template>> list();

  /// `GET /templates/:id` org-scoped. 404 si el id no existe en la org
  /// del operador — mapea a `TemplatesNotFoundFailure`.
  Future<Template> byId(String id);

  /// `POST /templates` body `{name}`. 422 si el nombre viola la validación
  /// del dominio (vacío, longitud) — mapea a `TemplatesInvalidNameFailure`.
  /// El backend devuelve la Template ya creada con la AIConfig default.
  Future<Template> create(String name);

  /// `GET /templates/:id/variable-definitions` org-scoped. 404 si la
  /// Template padre no existe en la org (mapea a NotFound). Devuelve la
  /// lista en el orden del backend junto con la `version` vigente del
  /// Template — el CRUD de var-defs la usa como CAS optimista en las
  /// mutaciones (POST/PATCH/DELETE no devuelven la nueva version, así
  /// que cada mutación termina con un refetch del listado).
  Future<({int version, List<VariableDef> defs})> listVarDefs(String id);

  /// `POST /templates/:id/variable-definitions` body
  /// `{name, type, default, description, version}` con CAS optimista
  /// sobre el Template padre. Devuelve la VariableDef recién creada
  /// (con id opaco del servidor). El backend NO devuelve la nueva
  /// version del Template — el llamador debe refetchar el listado para
  /// el siguiente CAS.
  ///
  /// 409 (`ErrTemplateConflict`/`ErrVariableNameDuplicated`/`ErrVariableInUse`)
  /// ⇒ `TemplatesConflictFailure`. El backend no discrimina entre
  /// version stale y duplicate name; el cliente trata todos como
  /// "recarga y vuelve a intentar".
  ///
  /// 422 (`ErrInvalidVariableName`/`ErrInvalidVariableType`) ⇒
  /// `TemplatesInvalidUpdateFailure`. Aterriza cuando un nombre rompe
  /// la regex del backend o cuando el tipo no es válido (v1 sólo `text`,
  /// pero si el cliente avanza con un tipo nuevo antes que el backend
  /// el 422 lo atrapa).
  Future<VariableDef> addVarDef({
    required String templateId,
    required String name,
    required VarType type,
    required String defaultValue,
    required String description,
    required int version,
  });

  /// `PATCH /variable-definitions/:id` body con SÓLO los campos a
  /// cambiar + `version` para CAS optimista sobre el Template padre.
  /// El path NO lleva templateId — el backend resuelve la Template
  /// desde el id opaco del var-def en el dominio.
  ///
  /// Patch only-changed: argumento `null` ⇒ no aparece en el body
  /// (no-op del campo). Cadena vacía es set explícito (clear). El
  /// backend devuelve 200 con body vacío; no hay snapshot que parsear.
  ///
  /// Mismos cubos de error que addVarDef. El 409 aquí incluye el
  /// rename "in use" (renombrar una variable activa con valores
  /// asignados en algún bot — el dominio lo bloquea con E2).
  Future<void> updateVarDef({
    required String varDefId,
    required int version,
    String? name,
    String? defaultValue,
    String? description,
  });

  /// `PUT /templates/:id` body `{name, version, ai?}` con concurrencia
  /// optimista (CAS). 409 (`ErrTemplateConflict`) ⇒ `TemplatesConflictFailure`
  /// — la version del cliente está desfasada; el operador debe recargar el
  /// detalle y reintentar (mismo PUT con misma version vuelve a fallar).
  /// 422 (`ErrInvalidTemplate`/`ErrInvalidAIConfig`) ⇒
  /// `TemplatesInvalidUpdateFailure`. `ai==null` omite la clave en el wire
  /// (omitempty del backend ⇒ config IA intacta). Devuelve la Template
  /// actualizada con la version nueva.
  Future<Template> update({
    required String id,
    required String name,
    required int version,
    required AIConfig? ai,
  });
}

class DioTemplatesDatasource implements TemplatesDatasource {
  DioTemplatesDatasource(this._dio);

  final Dio _dio;

  @override
  Future<List<Template>> list() async {
    try {
      final res = await _dio.get<List<dynamic>>('/templates');
      final body = res.data;
      if (body == null) {
        throw const UnknownTemplatesFailure();
      }
      return body
          .cast<Map<String, dynamic>>()
          .map(TemplateResp.fromJson)
          .map(TemplatesMapper.templateRespToEntity)
          .toList(growable: false);
    } on TemplatesFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownTemplatesFailure();
    } on TypeError {
      // `cast<Map<String,dynamic>>` puede romper si el wire mete un tipo
      // inesperado; el contrato dice array de objetos.
      throw const UnknownTemplatesFailure();
    }
  }

  @override
  Future<Template> byId(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/templates/$id');
      final body = res.data;
      if (body == null) {
        throw const UnknownTemplatesFailure();
      }
      return TemplatesMapper.templateRespToEntity(TemplateResp.fromJson(body));
    } on TemplatesFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownTemplatesFailure();
    } on TypeError {
      throw const UnknownTemplatesFailure();
    }
  }

  @override
  Future<Template> create(String name) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/templates',
        data: <String, dynamic>{'name': name},
      );
      final body = res.data;
      if (body == null) {
        throw const UnknownTemplatesFailure();
      }
      return TemplatesMapper.templateRespToEntity(TemplateResp.fromJson(body));
    } on TemplatesFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownTemplatesFailure();
    } on TypeError {
      throw const UnknownTemplatesFailure();
    }
  }

  @override
  Future<Template> update({
    required String id,
    required String name,
    required int version,
    required AIConfig? ai,
  }) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/templates/$id',
        data: <String, dynamic>{
          'name': name,
          'version': version,
          if (ai != null)
            'ai': <String, dynamic>{
              'enabled': ai.enabled,
              'provider': ai.provider.toWire(),
              'model': ai.model,
              'temperature': ai.temperature,
              'thinking_level': ai.thinkingLevel.toWire(),
              'system_prompt': ai.systemPrompt,
              'context_messages': ai.contextMessages,
            },
        },
      );
      final body = res.data;
      if (body == null) {
        throw const UnknownTemplatesFailure();
      }
      return TemplatesMapper.templateRespToEntity(TemplateResp.fromJson(body));
    } on TemplatesFailure {
      rethrow;
    } on DioException catch (e) {
      // PUT necesita override del mapeo de 422 (InvalidUpdate, no
      // InvalidName) y de 409 (Conflict, no aplica a otros métodos).
      // Override inline mantiene `_mapDioException` simple para los demás
      // callers; refactor a mapper parametrizado entra cuando un cuarto
      // método con cubos distintos lo justifique.
      if (e.type == DioExceptionType.badResponse) {
        final status = e.response?.statusCode;
        if (status == 409) throw const TemplatesConflictFailure();
        if (status == 422) throw const TemplatesInvalidUpdateFailure();
      }
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownTemplatesFailure();
    } on TypeError {
      throw const UnknownTemplatesFailure();
    }
  }

  @override
  Future<({int version, List<VariableDef> defs})> listVarDefs(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/templates/$id/variable-definitions',
      );
      final body = res.data;
      if (body == null) {
        throw const UnknownTemplatesFailure();
      }
      return VarDefsMapper.listToLoaded(ListVarDefsResp.fromJson(body));
    } on TemplatesFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownTemplatesFailure();
    } on TypeError {
      throw const UnknownTemplatesFailure();
    }
  }

  @override
  Future<VariableDef> addVarDef({
    required String templateId,
    required String name,
    required VarType type,
    required String defaultValue,
    required String description,
    required int version,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/templates/$templateId/variable-definitions',
        data: <String, dynamic>{
          'name': name,
          'type': type.toWire(),
          'default': defaultValue,
          'description': description,
          'version': version,
        },
      );
      final body = res.data;
      if (body == null) {
        throw const UnknownTemplatesFailure();
      }
      return VarDefsMapper.varDefRespToEntity(VarDefResp.fromJson(body));
    } on TemplatesFailure {
      rethrow;
    } on DioException catch (e) {
      // Mismo patrón del PUT: las mutaciones tienen cubos distintos a los
      // GET para 409 (Conflict) y 422 (InvalidUpdate, no InvalidName).
      if (e.type == DioExceptionType.badResponse) {
        final status = e.response?.statusCode;
        if (status == 409) throw const TemplatesConflictFailure();
        if (status == 422) throw const TemplatesInvalidUpdateFailure();
      }
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownTemplatesFailure();
    } on TypeError {
      throw const UnknownTemplatesFailure();
    }
  }

  @override
  Future<void> updateVarDef({
    required String varDefId,
    required int version,
    String? name,
    String? defaultValue,
    String? description,
  }) async {
    try {
      // Patch only-changed: el body sólo incluye claves para los campos
      // provistos. Argumento `null` ⇒ no aparece (equivalente al `*string`
      // nil del backend). Cadena vacía es set explícito.
      final body = <String, dynamic>{'version': version};
      if (name != null) body['name'] = name;
      if (defaultValue != null) body['default'] = defaultValue;
      if (description != null) body['description'] = description;

      await _dio.patch<dynamic>(
        '/variable-definitions/$varDefId',
        data: body,
      );
    } on TemplatesFailure {
      rethrow;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.badResponse) {
        final status = e.response?.statusCode;
        if (status == 409) throw const TemplatesConflictFailure();
        if (status == 422) throw const TemplatesInvalidUpdateFailure();
      }
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownTemplatesFailure();
    } on TypeError {
      throw const UnknownTemplatesFailure();
    }
  }

  /// Traduce DioException a la jerarquía sellada de TemplatesFailure.
  /// Duplica el patrón de BotsFailure._mapDioException; cuando aterrice
  /// la tercera feature con el mismo patrón, extraer a un helper
  /// compartido en `core/network/` (regla de tres).
  TemplatesFailure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TemplatesTimeoutFailure();
      case DioExceptionType.connectionError:
        return const TemplatesNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 403) return const TemplatesForbiddenFailure();
        if (status == 404) return const TemplatesNotFoundFailure();
        if (status == 422) return const TemplatesInvalidNameFailure();
        if (status >= 500 && status < 600) {
          return const TemplatesServerFailure();
        }
        return const UnknownTemplatesFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownTemplatesFailure();
    }
  }
}
