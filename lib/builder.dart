import 'dart:async';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:source_gen/source_gen.dart';
import 'dart:convert';
import 'annotations.dart';

enum DataClassType {
  jsonSerializable,
  freezed,
  unsupported,
}

class PropertyInfo {
  final String name;
  final DartType type;
  final bool isRequired;
  final DartObject? defaultValue;
  final String? description;

  const PropertyInfo(
    this.name,
    this.type, {
    required this.isRequired,
    this.defaultValue,
    this.description,
  });
}

class SotiSchemaGenerator extends GeneratorForAnnotation<SotiSchema> {
  static const _typeCheckers = TypeCheckers();

  final _schemaGenerator = JsonSchemaGenerator();

  @override
  FutureOr<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
          'Generator cannot target `${element.displayName}`.');
    }

    final buffer = StringBuffer();

    for (final accessor
        in element.accessors.where((f) => f.isStatic && f.isGetter)) {
      if (_typeCheckers.jsonSchemaChecker.hasAnnotationOf(accessor)) {
        final schema = _schemaGenerator.generateSchema(element);
        final name = await _getRedirectedVariableName(accessor, buildStep);
        if (name == null) {
          throw InvalidGenerationSourceError(
              'Failed to extract redirected variable name for ${accessor.displayName}.');
        }
        _writeSchemaToBuffer(buffer, name, accessor.returnType, schema);
      }
      // Add conditions for other schema types here
    }
    return buffer.toString();
  }

  void _writeSchemaToBuffer(StringBuffer buffer, String name, DartType type,
      Map<String, dynamic> schema) {
    if (_typeCheckers.stringChecker.isExactlyType(type)) {
      buffer.writeln('const $name = r\'${jsonEncode(schema)}\';');
    } else if (_isMapStringDynamic(type)) {
      buffer.writeln('const $name = ${_generateMapLiteral(schema)};');
    } else {
      throw InvalidGenerationSourceError(
          'Failed to generate schema for $name. Only support String or Map<String, dynamic>.');
    }
  }

  String _generateMapLiteral(Map<String, dynamic> map) {
    return '<String, dynamic>${_convertMapToString(map)}';
  }

  String _convertMapToString(Map<String, dynamic> map) {
    return '{${map.entries.map((e) => '${_escapeKey(e.key)}: ${_convertValueToString(e.value)}').join(', ')}}';
  }

  String _escapeKey(String key) {
    return 'r\'$key\'';
  }

  String _convertValueToString(dynamic value) {
    if (value is Map<String, dynamic>) {
      return _convertMapToString(value);
    } else if (value is List) {
      return _convertListToString(value);
    } else if (value is String) {
      return 'r\'$value\'';
    } else {
      return value.toString();
    }
  }

  String _convertListToString(List list) {
    return '[${list.map((e) => _convertValueToString(e)).join(', ')}]';
  }

  bool _isMapStringDynamic(DartType type) {
    if (type is ParameterizedType &&
        _typeCheckers.mapChecker.isExactlyType(type)) {
      var typeArguments = type.typeArguments;
      return typeArguments.length == 2 &&
          _typeCheckers.stringChecker.isExactlyType(typeArguments[0]) &&
          typeArguments[1] is DynamicType;
    }
    return false;
  }

  Future<String?> _getRedirectedVariableName(
      PropertyAccessorElement getter, BuildStep buildStep) async {
    final parsedLibrary = await _getParsedLibrary(getter, buildStep);
    final node = _findGetterDeclaration(parsedLibrary, getter);
    return node != null ? _extractGetterBody(node) : null;
  }

  Future<ParsedLibraryResult> _getParsedLibrary(
      Element element, BuildStep buildStep) async {
    final assetId = buildStep.inputId;
    final resolver = buildStep.resolver;
    final library = await resolver.libraryFor(assetId);
    final parsedLibrary =
        library.session.getParsedLibraryByElement(element.library!);
    if (parsedLibrary is! ParsedLibraryResult) {
      throw InvalidGenerationSourceError(
          'Failed to parse library for ${element.displayName}');
    }
    return parsedLibrary;
  }

  MethodDeclaration? _findGetterDeclaration(
      ParsedLibraryResult parsedLibrary, PropertyAccessorElement getter) {
    final result = parsedLibrary.getElementDeclaration(getter);
    return (result?.node is MethodDeclaration)
        ? result!.node as MethodDeclaration
        : null;
  }

  String? _extractGetterBody(MethodDeclaration getterDeclaration) {
    final body = getterDeclaration.body;
    if (body is ExpressionFunctionBody) {
      final expression = body.expression;
      if (expression is SimpleIdentifier) {
        return expression.name;
      }
    }
    return null;
  }
}

class JsonSchemaGenerator {
  final _typeCheckers = TypeCheckers();
  final _generatedSchemas = <String, Map<String, dynamic>>{};

  Map<String, dynamic> generateSchema(ClassElement element) {
    _generatedSchemas.clear();
    final mainSchema = _getPropertySchema(element.thisType, isRoot: true);

    return {
      r'$schema': 'https://json-schema.org/draft/2020-12/schema',
      ...mainSchema,
      r'$defs': _generatedSchemas,
    };
  }

  Map<String, dynamic> _getPropertySchema(DartType type,
      {bool isRoot = false, Set<DartType> seenTypes = const {}}) {
    if (!isRoot && seenTypes.contains(type)) {
      return {r'$ref': '#/\$defs/${type.element!.name}'};
    }

    var newSeenTypes = Set<DartType>.from(seenTypes)..add(type);

    if (_typeCheckers.stringChecker.isExactlyType(type)) {
      return {'type': 'string'};
    }
    if (_typeCheckers.intChecker.isExactlyType(type)) {
      return {'type': 'integer'};
    }
    if (_typeCheckers.doubleChecker.isExactlyType(type)) {
      return {'type': 'number'};
    }
    if (_typeCheckers.boolChecker.isExactlyType(type)) {
      return {'type': 'boolean'};
    }
    if (_typeCheckers.dateTimeChecker.isExactlyType(type)) {
      return {'type': 'string', 'format': 'date-time'};
    }
    if (_typeCheckers.uriChecker.isExactlyType(type)) {
      return {'type': 'string', 'format': 'uri'};
    }

    if (_typeCheckers.iterableChecker.isAssignableFromType(type)) {
      final itemType = _getGenericType(type);
      return {
        'type': 'array',
        'items': _getPropertySchema(itemType, seenTypes: newSeenTypes),
      };
    }

    if (_typeCheckers.mapChecker.isAssignableFromType(type)) {
      final valueType = _getGenericType(type, 1);
      return {
        'type': 'object',
        'additionalProperties':
            _getPropertySchema(valueType, seenTypes: newSeenTypes),
      };
    }

    if (type is InterfaceType &&
        !_typeCheckers.objectChecker.isExactlyType(type)) {
      return _generateComplexTypeSchema(type, isRoot, newSeenTypes);
    }

    return {'type': 'object'};
  }

  Map<String, dynamic> _generateComplexTypeSchema(
      InterfaceType type, bool isRoot, Set<DartType> seenTypes) {
    final typeName = type.element.name;
    if (!isRoot && _generatedSchemas.containsKey(typeName)) {
      return {r'$ref': '#/\$defs/$typeName'};
    }

    final classElement = type.element;
    final dataClassType = _identifyDataClassType(classElement);
    final properties = _getProperties(classElement, dataClassType);

    final schemaProperties = <String, dynamic>{};
    final required = <String>[];

    for (final property in properties) {
      final propertySchema =
          _getPropertySchema(property.type, seenTypes: seenTypes);

      if (property.description != null) {
        propertySchema['description'] = property.description;
      }

      if (property.defaultValue != null) {
        if (_typeCheckers.stringChecker.isAssignableFromType(property.type)) {
          propertySchema['default'] = property.defaultValue!.toStringValue();
        } else if (_typeCheckers.intChecker
            .isAssignableFromType(property.type)) {
          propertySchema['default'] = property.defaultValue!.toIntValue();
        } else if (_typeCheckers.doubleChecker
            .isAssignableFromType(property.type)) {
          propertySchema['default'] = property.defaultValue!.toDoubleValue();
        } else if (_typeCheckers.boolChecker
            .isAssignableFromType(property.type)) {
          propertySchema['default'] = property.defaultValue!.toBoolValue();
        } else if (_typeCheckers.iterableChecker
            .isAssignableFromType(property.type)) {
          propertySchema['default'] = property.defaultValue!.toListValue();
        } else if (_typeCheckers.mapChecker
            .isAssignableFromType(property.type)) {
          propertySchema['default'] = property.defaultValue!.toMapValue();
        } else {
          throw UnsupportedError(
              'Unsupported default value type for property ${property.name}');
        }
      }

      schemaProperties[property.name] = propertySchema;

      if (property.isRequired) {
        required.add(property.name);
      }
    }

    final schema = {
      'type': 'object',
      'properties': schemaProperties,
      if (required.isNotEmpty) 'required': required,
    };

    if (!isRoot) {
      _generatedSchemas[typeName] = schema;
      return {r'$ref': '#/\$defs/$typeName'};
    }

    return schema;
  }

  DataClassType _identifyDataClassType(InterfaceElement element) {
    if (_typeCheckers.jsonSerializableChecker.hasAnnotationOf(element)) {
      return DataClassType.jsonSerializable;
    } else if (_typeCheckers.freezedChecker.hasAnnotationOf(element)) {
      return DataClassType.freezed;
    } else {
      return DataClassType.unsupported;
    }
  }

  DartType _getGenericType(DartType type, [int index = 0]) {
    return (type is InterfaceType && type.typeArguments.isNotEmpty)
        ? type.typeArguments[index]
        : type;
  }

  List<PropertyInfo> _getProperties(
      InterfaceElement element, DataClassType dataClassType) {
    switch (dataClassType) {
      case DataClassType.jsonSerializable:
        return _getJsonSerializableProperties(element);
      case DataClassType.freezed:
        return _getFreezedProperties(element);
      case DataClassType.unsupported:
        throw UnsupportedError(
            'Unsupported data class type. Use @JsonSerializable or @freezed annotation.');
    }
  }

  List<PropertyInfo> _getJsonSerializableProperties(InterfaceElement element) {
    final properties = <PropertyInfo>[];

    for (var field in element.fields) {
      if (field.isStatic || !field.isPublic) continue;

      final jsonKey = _typeCheckers.jsonKeyChecker.firstAnnotationOf(field);
      final reader = jsonKey != null ? ConstantReader(jsonKey) : null;

      final includeFromJson = reader?.read('includeFromJson').boolValue ?? true;
      final includeToJson = reader?.read('includeToJson').boolValue ?? true;

      if (!includeFromJson || !includeToJson) continue;

      final isRequired = field.isFinal &&
          field.type.nullabilitySuffix == NullabilitySuffix.none;
      final defaultValue = reader?.read('defaultValue').objectValue;
      final description = _getDescription(field);

      properties.add(PropertyInfo(
        field.name,
        field.type,
        isRequired: isRequired,
        defaultValue: defaultValue,
        description: description,
      ));
    }

    return properties;
  }

  List<PropertyInfo> _getFreezedProperties(InterfaceElement element) {
    final properties = <PropertyInfo>[];
    final constructor = element.unnamedConstructor;

    if (constructor == null) {
      throw StateError(
          'No unnamed constructor found for freezed class ${element.name}');
    }

    for (var parameter in constructor.parameters) {
      final defaultValueAnnotation =
          _typeCheckers.defaultChecker.firstAnnotationOf(parameter);
      final defaultValue = defaultValueAnnotation != null
          ? ConstantReader(defaultValueAnnotation)
              .read('defaultValue')
              .objectValue
          : null;

      final description = _getDescription(parameter);

      properties.add(PropertyInfo(
        parameter.name,
        parameter.type,
        isRequired: parameter.isRequired,
        defaultValue: defaultValue,
        description: description,
      ));
    }

    return properties;
  }

  String? _getDescription(Element element) {
    // First, check for a custom description annotation
    final descriptionAnnotation =
        _typeCheckers.descriptionChecker.firstAnnotationOf(element);
    if (descriptionAnnotation != null) {
      final reader = ConstantReader(descriptionAnnotation);
      return reader.read('value').stringValue;
    }

    // Fallback to doc comment
    final docComment = element.documentationComment;
    if (docComment != null && docComment.isNotEmpty) {
      return docComment
          .replaceAll(
              RegExp(r'^\s*\/\*\*\s*|\s*\*\/\s*$|\s*\*\s?', multiLine: true),
              '')
          .trim();
    }

    return null;
  }

  Map<String, dynamic>? _handleEnum(DartType type) {
    if (type.element is EnumElement) {
      final enumElement = type.element as EnumElement;
      final enumValues = enumElement.fields
          .where((field) => field.isEnumConstant)
          .map((field) => field.name)
          .toList();

      return {
        'type': 'string',
        'enum': enumValues,
      };
    }
    return null;
  }
}

class TypeCheckers {
  final jsonKeyChecker = const TypeChecker.fromRuntime(JsonKey);
  final stringChecker = const TypeChecker.fromRuntime(String);
  final intChecker = const TypeChecker.fromRuntime(int);
  final doubleChecker = const TypeChecker.fromRuntime(double);
  final boolChecker = const TypeChecker.fromRuntime(bool);
  final iterableChecker = const TypeChecker.fromRuntime(Iterable);
  final mapChecker = const TypeChecker.fromRuntime(Map);
  final dateTimeChecker = const TypeChecker.fromRuntime(DateTime);
  final uriChecker = const TypeChecker.fromRuntime(Uri);
  final objectChecker = const TypeChecker.fromRuntime(Object);
  final jsonSchemaChecker = const TypeChecker.fromRuntime(JsonSchema);
  final descriptionChecker = const TypeChecker.fromRuntime(Description);
  final defaultValueChecker = const TypeChecker.fromRuntime(DefaultValue);
  final jsonSerializableChecker =
      const TypeChecker.fromRuntime(JsonSerializable);
  final freezedChecker = const TypeChecker.fromRuntime(Freezed);
  final defaultChecker = const TypeChecker.fromRuntime(Default);

  const TypeCheckers();
}

Builder sotiSchemaBuilder(BuilderOptions options) => SharedPartBuilder(
      [SotiSchemaGenerator()],
      'soti_schema',
    );
