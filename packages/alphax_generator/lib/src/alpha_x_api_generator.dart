import 'dart:convert';

import 'package:alphax/annotations.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:source_gen/source_gen.dart';

/// Generates a direct AlphaX implementation for each annotated API class.
final class AlphaXApiGenerator extends GeneratorForAnnotation<AlphaXApi> {
  /// Creates the AlphaX API generator.
  const AlphaXApiGenerator() : super(inPackage: 'alphax');

  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@AlphaXApi must annotate an abstract class.',
        element: element,
        todo: 'Move @AlphaXApi to an abstract class declaration.',
      );
    }

    final spec = _ApiSpec.fromElement(element, annotation);
    final source = _SourceEmitter(spec).emit();
    return DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
      pageWidth: 100,
    ).format(source);
  }
}

final class _ApiSpec {
  _ApiSpec({
    required this.element,
    required this.baseUrl,
    required this.staticHeaders,
    required this.methods,
    required this.factory,
  });

  final ClassElement element;
  final Uri baseUrl;
  final Map<String, String> staticHeaders;
  final List<_MethodSpec> methods;
  final ConstructorElement factory;

  String get name => element.name!;

  static _ApiSpec fromElement(ClassElement element, ConstantReader annotation) {
    if (!element.isAbstract) {
      _fail(
        '@AlphaXApi requires an abstract class.',
        element,
        'Make the API declaration abstract.',
      );
    }
    if (element.typeParameters.isNotEmpty) {
      _fail(
        'AlphaX API `$element` cannot declare type parameters yet.',
        element,
        'Use a concrete API declaration and keep generic model types in method signatures.',
      );
    }

    final baseUrlText = annotation.read('baseUrl').stringValue;
    final baseUrl = Uri.tryParse(baseUrlText);
    if (baseUrl == null ||
        !baseUrl.isAbsolute ||
        (baseUrl.scheme != 'http' && baseUrl.scheme != 'https') ||
        baseUrl.host.isEmpty) {
      _fail(
        'AlphaX API `${element.name}` has an invalid base URL `$baseUrlText`.',
        element,
        'Use an absolute http:// or https:// base URL.',
      );
    }

    final staticHeaders = _readStringMap(annotation, 'headers', element);
    _validateHeaders(staticHeaders, element);

    final factory = _findClientFactory(element);
    final methods = <_MethodSpec>[];
    for (final method in element.methods) {
      final http = _readHttpMethod(method);
      if (http == null) {
        if (method.isAbstract && !method.isStatic && method.isOriginDeclaration) {
          _fail(
            'AlphaX API `${element.name}` has an unannotated abstract method `${method.name}`.',
            method,
            'Add one AlphaX HTTP method annotation or remove the abstract method.',
          );
        }
        continue;
      }
      methods.add(_MethodSpec.fromElement(method, http, element));
    }
    if (methods.isEmpty) {
      _fail(
        'AlphaX API `${element.name}` has no annotated HTTP methods.',
        element,
        'Add @AlphaXGet, @AlphaXPost, @AlphaXPut, @AlphaXPatch, @AlphaXDelete, or @AlphaXHead.',
      );
    }

    return _ApiSpec(
      element: element,
      baseUrl: baseUrl,
      staticHeaders: staticHeaders,
      methods: methods,
      factory: factory,
    );
  }
}

final class _MethodSpec {
  _MethodSpec({
    required this.element,
    required this.http,
    required this.parameters,
    required this.decoder,
    required this.returnSpec,
  });

  final MethodElement element;
  final _HttpMethodSpec http;
  final List<_ParameterSpec> parameters;
  final String? decoder;
  final _ReturnSpec returnSpec;

  String get name => element.name!;

  _ParameterSpec? get body => _first(_ParameterKind.body);

  _ParameterSpec? get options => _first(_ParameterKind.options);

  _ParameterSpec? get cancellation => _first(_ParameterKind.cancellation);

  _ParameterSpec? get fileSource => _first(_ParameterKind.fileSource);

  _ParameterSpec? get fileTarget => _first(_ParameterKind.fileTarget);

  Iterable<_ParameterSpec> get pathParameters => _where(_ParameterKind.path);

  Iterable<_ParameterSpec> get queryParameters => _where(_ParameterKind.query);

  Iterable<_ParameterSpec> get headerParameters => _where(_ParameterKind.header);

  _ParameterSpec? _first(_ParameterKind kind) {
    for (final parameter in parameters) {
      if (parameter.kind == kind) {
        return parameter;
      }
    }
    return null;
  }

  Iterable<_ParameterSpec> _where(_ParameterKind kind) sync* {
    for (final parameter in parameters) {
      if (parameter.kind == kind) {
        yield parameter;
      }
    }
  }

  static _MethodSpec fromElement(MethodElement method, _HttpMethodSpec http, ClassElement api) {
    if (method.isStatic || !method.isAbstract) {
      _fail(
        'AlphaX API `${api.name}` method `${method.name}` must be an abstract instance method.',
        method,
        'Declare the endpoint method abstract and omit static.',
      );
    }
    if (method.typeParameters.isNotEmpty) {
      _fail(
        'AlphaX API `${api.name}` method `${method.name}` cannot be generic yet.',
        method,
        'Use a concrete return type and model decoder.',
      );
    }

    final decoderReader = _annotation(method, AlphaXDecode);
    final decoder = decoderReader?.read('expression').stringValue.trim();
    if (decoder != null && !_validDecoderExpression.hasMatch(decoder)) {
      _fail(
        'AlphaX API method `${api.name}.${method.name}` has an invalid decoder expression `$decoder`.',
        method,
        'Use a callable name such as User.fromJson or parseUser.',
      );
    }

    final parameters = <_ParameterSpec>[];
    for (final parameter in method.formalParameters) {
      parameters.add(_ParameterSpec.fromElement(parameter, method, api));
    }
    _ensureAtMostOne(parameters, _ParameterKind.body, method, api);
    _ensureAtMostOne(parameters, _ParameterKind.options, method, api);
    _ensureAtMostOne(parameters, _ParameterKind.cancellation, method, api);
    _ensureAtMostOne(parameters, _ParameterKind.fileSource, method, api);
    _ensureAtMostOne(parameters, _ParameterKind.fileTarget, method, api);
    if (parameters.any((parameter) => parameter.kind == _ParameterKind.options) &&
        parameters.any((parameter) => parameter.kind == _ParameterKind.cancellation)) {
      _fail(
        'AlphaX API method `${api.name}.${method.name}` cannot combine AlphaXRequestOptions with a separate cancellation parameter.',
        method,
        'Use AlphaXRequestOptions.cancellationToken or annotate a standalone AlphaXCancellationToken, not both.',
      );
    }

    final pathParameters = parameters.where((parameter) => parameter.kind == _ParameterKind.path);
    final placeholders = <String>{
      for (final match in _placeholderPattern.allMatches(http.path)) match.group(1)!,
    };
    if (http.path.contains('{') || http.path.contains('}')) {
      for (final match in _placeholderPattern.allMatches(http.path)) {
        if (match.group(0)!.contains('{') && match.group(1) == null) {
          _fail(
            'AlphaX API method `${api.name}.${method.name}` has an invalid path placeholder.',
            method,
            'Use placeholders in the form {name}.',
          );
        }
      }
      final withoutPlaceholders = http.path.replaceAll(_placeholderPattern, '');
      if (withoutPlaceholders.contains('{') || withoutPlaceholders.contains('}')) {
        _fail(
          'AlphaX API method `${api.name}.${method.name}` has an invalid path placeholder.',
          method,
          'Use placeholders in the form {name}.',
        );
      }
    }
    final mappings = <String, _ParameterSpec>{};
    for (final parameter in pathParameters) {
      final name = parameter.bindingName!;
      if (!placeholders.contains(name)) {
        _fail(
          'AlphaX API method `${api.name}.${method.name}` binds unused path parameter `$name`.',
          parameter.element,
          'Add {$name} to the endpoint path or remove the binding.',
        );
      }
      if (parameter.isNullable) {
        _fail(
          'AlphaX API method `${api.name}.${method.name}` uses nullable path parameter `$name`.',
          parameter.element,
          'Make path parameters non-nullable so a missing segment cannot be generated.',
        );
      }
      if (mappings[name] != null) {
        _fail(
          'AlphaX API method `${api.name}.${method.name}` maps path placeholder `$name` more than once.',
          parameter.element,
          'Keep exactly one @AlphaXPath("$name") parameter.',
        );
      }
      mappings[name] = parameter;
    }
    for (final placeholder in placeholders) {
      if (!mappings.containsKey(placeholder)) {
        _fail(
          'AlphaX API method `${api.name}.${method.name}` has no parameter for path placeholder {$placeholder}.',
          method,
          'Add exactly one @AlphaXPath("$placeholder") parameter.',
        );
      }
    }

    final body = parameters.where((parameter) => parameter.kind == _ParameterKind.body).toList();
    final fileSource = parameters
        .where((parameter) => parameter.kind == _ParameterKind.fileSource)
        .toList();
    final fileTarget = parameters
        .where((parameter) => parameter.kind == _ParameterKind.fileTarget)
        .toList();
    if (fileSource.isNotEmpty && body.isNotEmpty) {
      _fail(
        'AlphaX API method `${api.name}.${method.name}` cannot combine a file source with a request body.',
        method,
        'Use AlphaXFileSourceParam for a direct upload or AlphaXBodyParam for another body shape.',
      );
    }
    if (fileSource.isNotEmpty && fileTarget.isNotEmpty) {
      _fail(
        'AlphaX API method `${api.name}.${method.name}` cannot upload and download in one operation.',
        method,
        'Declare one transfer direction per method.',
      );
    }
    if (fileTarget.isNotEmpty && http.method != 'get') {
      _fail(
        'AlphaX API method `${api.name}.${method.name}` uses a file target with ${http.method.toUpperCase()}.',
        method,
        'Use GET for generated downloads.',
      );
    }

    final returnSpec = _ReturnSpec.fromType(method.returnType, method, api);
    if (returnSpec.isWrapper &&
        (returnSpec.isRawResponse ||
            returnSpec.isTransfer ||
            returnSpec.isVoid ||
            returnSpec.isFutureStream)) {
      _fail(
        'AlphaX API method `${api.name}.${method.name}` uses AlphaXApiResponse with an unsupported inner type `${returnSpec.valueTypeDisplay}`.',
        method,
        'Use AlphaXApiResponse<T> for a decoded body type, or return the raw/streamed type directly.',
      );
    }
    if (returnSpec.isTransfer && fileSource.isEmpty && fileTarget.isEmpty) {
      _fail(
        'AlphaX API method `${api.name}.${method.name}` returns AlphaXTransferResult without a file operation.',
        method,
        'Add a file source/target binding or return AlphaXResponse/a decoded body.',
      );
    }
    if ((fileSource.isNotEmpty || fileTarget.isNotEmpty) && !returnSpec.isTransfer) {
      _fail(
        'AlphaX API method `${api.name}.${method.name}` must return Future<AlphaXTransferResult> for file operations.',
        method,
        'Change the return type to Future<AlphaXTransferResult>.',
      );
    }
    if (returnSpec.requiresDecoder && decoder == null) {
      _fail(
        'AlphaX API method `${api.name}.${method.name}` returns `${returnSpec.valueTypeDisplay}` without a decoder.',
        method,
        'Add @AlphaXDecode("Type.fromJson") or use a directly supported JSON type.',
      );
    }
    if (decoder != null && !returnSpec.acceptsDecoder) {
      _fail(
        'AlphaX API method `${api.name}.${method.name}` declares a decoder for unsupported return type `${returnSpec.returnTypeDisplay}`.',
        method,
        'Use a typed Future return or remove @AlphaXDecode.',
      );
    }
    if (returnSpec.isStream && (fileSource.isNotEmpty || fileTarget.isNotEmpty)) {
      _fail(
        'AlphaX API method `${api.name}.${method.name}` cannot stream and perform a file transfer together.',
        method,
        'Return one representation per endpoint.',
      );
    }

    return _MethodSpec(
      element: method,
      http: http,
      parameters: parameters,
      decoder: decoder,
      returnSpec: returnSpec,
    );
  }
}

final class _ParameterSpec {
  _ParameterSpec({
    required this.element,
    required this.kind,
    this.bindingName,
    this.bodyEncoding,
    this.contentType,
  });

  final FormalParameterElement element;
  final _ParameterKind kind;
  final String? bindingName;
  final int? bodyEncoding;
  final String? contentType;

  String get name => element.displayName;

  DartType get type => element.type;

  String get typeDisplay => type.getDisplayString();

  bool get isNullable => type.nullabilitySuffix == NullabilitySuffix.question;

  String get declaration {
    final defaultValue = element.defaultValueCode;
    final defaultSuffix = defaultValue == null ? '' : ' = $defaultValue';
    if (element.isNamed) {
      return '${element.isRequiredNamed ? 'required ' : ''}$typeDisplay $name$defaultSuffix';
    }
    if (element.isOptionalPositional) {
      return '$typeDisplay $name$defaultSuffix';
    }
    return '$typeDisplay $name';
  }

  static _ParameterSpec fromElement(
    FormalParameterElement parameter,
    MethodElement method,
    ClassElement api,
  ) {
    final bindings = <_ParameterKind, Object?>{};
    final path = _annotation(parameter, AlphaXPath);
    if (path != null) {
      bindings[_ParameterKind.path] = path.read('name').stringValue;
    }
    final query = _annotation(parameter, AlphaXQuery);
    if (query != null) {
      bindings[_ParameterKind.query] = query.read('name').stringValue;
    }
    final header = _annotation(parameter, AlphaXHeader);
    if (header != null) {
      bindings[_ParameterKind.header] = header.read('name').stringValue;
    }
    final body = _annotation(parameter, AlphaXBodyParam);
    if (body != null) {
      final encoding = body.read('encoding').objectValue.getField('index')?.toIntValue();
      if (encoding == null || encoding < 0 || encoding > 5) {
        _fail(
          'AlphaX API method `${api.name}.${method.name}` has an unreadable body encoding on `${parameter.displayName}`.',
          parameter,
          'Use one of AlphaXBodyEncoding.json, text, bytes, stream, file, or multipart.',
        );
      }
      bindings[_ParameterKind.body] = encoding;
    }
    final options = _annotation(parameter, AlphaXOptions);
    if (options != null) {
      bindings[_ParameterKind.options] = null;
    }
    final cancellation = _annotation(parameter, AlphaXCancellation);
    if (cancellation != null) {
      bindings[_ParameterKind.cancellation] = null;
    }
    final fileSource = _annotation(parameter, AlphaXFileSourceParam);
    if (fileSource != null) {
      bindings[_ParameterKind.fileSource] = null;
    }
    final fileTarget = _annotation(parameter, AlphaXFileTargetParam);
    if (fileTarget != null) {
      bindings[_ParameterKind.fileTarget] = null;
    }

    if (bindings.length != 1) {
      _fail(
        'AlphaX API method `${api.name}.${method.name}` parameter `${parameter.displayName}` must have exactly one AlphaX binding.',
        parameter,
        'Annotate it with one of @AlphaXPath, @AlphaXQuery, @AlphaXHeader, @AlphaXBodyParam, '
            '@AlphaXOptions, @AlphaXCancellation, @AlphaXFileSourceParam, or @AlphaXFileTargetParam.',
      );
    }
    final kind = bindings.keys.single;
    final bindingName = bindings[kind] is String ? bindings[kind]! as String : null;
    if (kind == _ParameterKind.path &&
        (bindingName == null || !_validBindingName.hasMatch(bindingName))) {
      _fail(
        'AlphaX API method `${api.name}.${method.name}` has an invalid path binding name `${bindingName ?? ''}`.',
        parameter,
        'Use a Dart identifier matching the endpoint placeholder, such as @AlphaXPath("id").',
      );
    }
    if (kind == _ParameterKind.query && (bindingName == null || bindingName.isEmpty)) {
      _fail(
        'AlphaX API method `${api.name}.${method.name}` has an empty query binding name.',
        parameter,
        'Use a non-empty @AlphaXQuery("name") binding.',
      );
    }
    if (kind == _ParameterKind.header && (bindingName == null || !_validHeaderName(bindingName))) {
      _fail(
        'AlphaX API method `${api.name}.${method.name}` has an invalid dynamic header name `${bindingName ?? ''}`.',
        parameter,
        'Use a non-empty HTTP header token in @AlphaXHeader("Name").',
      );
    }
    if (kind == _ParameterKind.path && _isNullableType(parameter.type)) {
      _fail(
        'AlphaX API method `${api.name}.${method.name}` path parameter `${parameter.displayName}` cannot be nullable.',
        parameter,
        'Use a non-nullable path parameter.',
      );
    }
    if (kind == _ParameterKind.options && _bareTypeName(parameter.type) != 'AlphaXRequestOptions') {
      _fail(
        'AlphaX API method `${api.name}.${method.name}` options parameter `${parameter.displayName}` must be AlphaXRequestOptions.',
        parameter,
        'Use @AlphaXOptions() AlphaXRequestOptions? options.',
      );
    }
    if (kind == _ParameterKind.cancellation &&
        _bareTypeName(parameter.type) != 'AlphaXCancellationToken') {
      _fail(
        'AlphaX API method `${api.name}.${method.name}` cancellation parameter `${parameter.displayName}` must be AlphaXCancellationToken.',
        parameter,
        'Use @AlphaXCancellation() AlphaXCancellationToken? cancellation.',
      );
    }
    if (kind == _ParameterKind.fileSource &&
        (_bareTypeName(parameter.type) != 'AlphaXFileSource' || _isNullableType(parameter.type))) {
      _fail(
        'AlphaX API method `${api.name}.${method.name}` file source `${parameter.displayName}` must be non-nullable AlphaXFileSource.',
        parameter,
        'Use @AlphaXFileSourceParam() AlphaXFileSource source.',
      );
    }
    if (kind == _ParameterKind.fileTarget &&
        (_bareTypeName(parameter.type) != 'AlphaXFileTarget' || _isNullableType(parameter.type))) {
      _fail(
        'AlphaX API method `${api.name}.${method.name}` file target `${parameter.displayName}` must be non-nullable AlphaXFileTarget.',
        parameter,
        'Use @AlphaXFileTargetParam() AlphaXFileTarget target.',
      );
    }
    if (kind == _ParameterKind.body) {
      final bodyReader = body!;
      final contentTypeReader = bodyReader.peek('contentType');
      final contentType = contentTypeReader?.stringValue;
      if (contentType?.contains(RegExp(r'[\r\n]')) ?? false) {
        _fail(
          'AlphaX API method `${api.name}.${method.name}` has a body content type containing a newline.',
          parameter,
          'Use an HTTP media type without CR or LF.',
        );
      }
      if (bindings[kind] == 0 && contentType != null) {
        _fail(
          'AlphaX API method `${api.name}.${method.name}` cannot override JSON content type.',
          parameter,
          'Remove contentType or select a raw body encoding.',
        );
      }
      if (bindings[kind] == 5 && contentType != null) {
        _fail(
          'AlphaX API method `${api.name}.${method.name}` cannot override multipart content type.',
          parameter,
          'Let AlphaXMultipartBody provide its boundary and content type.',
        );
      }
      if (bindings[kind] == 4 && _isNullableType(parameter.type)) {
        _fail(
          'AlphaX API method `${api.name}.${method.name}` file body `${parameter.displayName}` cannot be nullable.',
          parameter,
          'Use a non-nullable AlphaXFileSource.',
        );
      }
      if (bindings[kind] == 1 &&
          (_bareTypeName(parameter.type) != 'String' || _isNullableType(parameter.type))) {
        _fail(
          'AlphaX API method `${api.name}.${method.name}` text body `${parameter.displayName}` must be a non-nullable String.',
          parameter,
          'Use @AlphaXBodyParam(encoding: AlphaXBodyEncoding.text) String body.',
        );
      }
      if (bindings[kind] == 2 &&
          (_isNullableType(parameter.type) ||
              !(_isByteList(parameter.type) ||
                  _bareTypeName(parameter.type) == 'Uint8List' ||
                  _bareTypeName(parameter.type) == 'AlphaXBody'))) {
        _fail(
          'AlphaX API method `${api.name}.${method.name}` byte body `${parameter.displayName}` must be List<int>, Uint8List, or AlphaXBody.',
          parameter,
          'Use @AlphaXBodyParam(encoding: AlphaXBodyEncoding.bytes) List<int> body.',
        );
      }
      if (bindings[kind] == 3 && !_isByteStream(parameter.type)) {
        _fail(
          'AlphaX API method `${api.name}.${method.name}` stream body `${parameter.displayName}` must be Stream<List<int>>.',
          parameter,
          'Use @AlphaXBodyParam(encoding: AlphaXBodyEncoding.stream) Stream<List<int>> body.',
        );
      }
      if (bindings[kind] == 4 && _bareTypeName(parameter.type) != 'AlphaXFileSource') {
        _fail(
          'AlphaX API method `${api.name}.${method.name}` file body `${parameter.displayName}` must be AlphaXFileSource.',
          parameter,
          'Use @AlphaXBodyParam(encoding: AlphaXBodyEncoding.file) AlphaXFileSource body.',
        );
      }
      if (bindings[kind] == 5 && _bareTypeName(parameter.type) != 'AlphaXMultipartBody') {
        _fail(
          'AlphaX API method `${api.name}.${method.name}` multipart body `${parameter.displayName}` must be AlphaXMultipartBody.',
          parameter,
          'Construct AlphaXMultipartBody with AlphaXMultipartField/AlphaXMultipartFile parts.',
        );
      }
      if (_bareTypeName(parameter.type) == 'AlphaXBody' && bindings[kind] != 0) {
        _fail(
          'AlphaX API method `${api.name}.${method.name}` cannot apply a body encoding to an existing AlphaXBody parameter `${parameter.displayName}`.',
          parameter,
          'Use the default JSON annotation with AlphaXBody, or provide the underlying value.',
        );
      }
    }
    final binding = bindings[kind];
    return _ParameterSpec(
      element: parameter,
      kind: kind,
      bindingName: binding is String ? binding : null,
      bodyEncoding: binding is int ? binding : null,
      contentType: kind == _ParameterKind.body ? body!.peek('contentType')?.stringValue : null,
    );
  }
}

enum _ParameterKind { path, query, header, body, options, cancellation, fileSource, fileTarget }

final class _HttpMethodSpec {
  const _HttpMethodSpec({required this.method, required this.path, required this.headers});

  final String method;
  final String path;
  final Map<String, String> headers;
}

final class _ReturnSpec {
  _ReturnSpec({
    required this.returnTypeDisplay,
    required this.valueType,
    required this.valueTypeDisplay,
    required this.isStream,
    required this.isFutureStream,
    required this.isRawResponse,
    required this.isTransfer,
    required this.isWrapper,
    required this.isVoid,
    required this.requiresDecoder,
  });

  final String returnTypeDisplay;
  final DartType? valueType;
  final String valueTypeDisplay;
  final bool isStream;
  final bool isFutureStream;
  final bool isRawResponse;
  final bool isTransfer;
  final bool isWrapper;
  final bool isVoid;
  final bool requiresDecoder;

  bool get isNullable => valueType?.nullabilitySuffix == NullabilitySuffix.question;

  bool get acceptsDecoder => valueType != null && !isRawResponse && !isTransfer && !isVoid;

  static _ReturnSpec fromType(DartType type, MethodElement method, ClassElement api) {
    final returnTypeDisplay = type.getDisplayString();
    if (type is! InterfaceType || !type.isDartAsyncFuture && !type.isDartAsyncStream) {
      _fail(
        'AlphaX API method `${api.name}.${method.name}` must return Future<T> or Stream<List<int>>.',
        method,
        'Use Future<T> for decoded responses, Future<AlphaXResponse> for raw metadata, or Stream<List<int>> for a body stream.',
      );
    }
    final isStream = type.isDartAsyncStream;
    final valueType = type.typeArguments.single;
    if (isStream) {
      if (!_isByteList(valueType)) {
        _fail(
          'AlphaX API method `${api.name}.${method.name}` only supports Stream<List<int>> response bodies.',
          method,
          'Use Stream<List<int>> or Future<AlphaXResponse>.',
        );
      }
      return _ReturnSpec(
        returnTypeDisplay: returnTypeDisplay,
        valueType: valueType,
        valueTypeDisplay: valueType.getDisplayString(),
        isStream: true,
        isFutureStream: false,
        isRawResponse: false,
        isTransfer: false,
        isWrapper: false,
        isVoid: false,
        requiresDecoder: false,
      );
    }

    var futureValue = valueType;
    var wrapper = false;
    if (futureValue is InterfaceType && futureValue.element.name == 'AlphaXApiResponse') {
      if (futureValue.typeArguments.length != 1) {
        _fail(
          'AlphaX API method `${api.name}.${method.name}` has an invalid AlphaXApiResponse return type.',
          method,
          'Use AlphaXApiResponse<T>.',
        );
      }
      wrapper = true;
      futureValue = futureValue.typeArguments.single;
    }
    final futureStream = futureValue is InterfaceType && futureValue.isDartAsyncStream;
    if (futureStream) {
      final streamType = futureValue.typeArguments.single;
      if (!_isByteList(streamType)) {
        _fail(
          'AlphaX API method `${api.name}.${method.name}` only supports Future<Stream<List<int>>> for streamed responses.',
          method,
          'Use Future<Stream<List<int>>> or Future<AlphaXResponse>.',
        );
      }
    }
    final isRawResponse = _isNamed(futureValue, 'AlphaXResponse');
    final isTransfer = _isNamed(futureValue, 'AlphaXTransferResult');
    final isVoid = futureValue is VoidType;
    final requiresDecoder =
        _requiresDecoder(futureValue) && !isRawResponse && !isTransfer && !isVoid && !futureStream;
    return _ReturnSpec(
      returnTypeDisplay: returnTypeDisplay,
      valueType: futureValue,
      valueTypeDisplay: futureValue.getDisplayString(),
      isStream: false,
      isFutureStream: futureStream,
      isRawResponse: isRawResponse,
      isTransfer: isTransfer,
      isWrapper: wrapper,
      isVoid: isVoid,
      requiresDecoder: requiresDecoder,
    );
  }
}

final class _SourceEmitter {
  _SourceEmitter(this.spec);

  final _ApiSpec spec;

  String emit() {
    final buffer = StringBuffer()
      ..writeln('class _${spec.name} implements ${spec.name} {')
      ..writeln('  _${spec.name}(this._client);')
      ..writeln()
      ..writeln('  final AlphaXClient _client;')
      ..writeln()
      ..writeln(
        '  Uri _resolveUri(String endpoint, Map<String, Iterable<String>> queryParameters) {',
      )
      ..writeln('    final base = Uri.parse(${_literal(spec.baseUrl.toString())});')
      ..writeln('    final parsed = Uri.parse(endpoint);')
      ..writeln('    final resolved = parsed.isAbsolute ? parsed : base.resolveUri(parsed);')
      ..writeln('    final merged = <String, Iterable<String>>{};')
      ..writeln('    if (!parsed.isAbsolute) {')
      ..writeln('      for (final entry in base.queryParametersAll.entries) {')
      ..writeln('        merged[entry.key] = <String>[...entry.value];')
      ..writeln('      }')
      ..writeln('    }')
      ..writeln('    for (final entry in resolved.queryParametersAll.entries) {')
      ..writeln('      merged[entry.key] = <String>[')
      ..writeln('        ...(merged[entry.key] ?? const <String>[]),')
      ..writeln('        ...entry.value,')
      ..writeln('      ];')
      ..writeln('    }')
      ..writeln('    for (final entry in queryParameters.entries) {')
      ..writeln('      merged[entry.key] = <String>[')
      ..writeln('        ...(merged[entry.key] ?? const <String>[]),')
      ..writeln('        ...entry.value,')
      ..writeln('      ];')
      ..writeln('    }')
      ..writeln('    if (merged.isEmpty) {')
      ..writeln('      return resolved;')
      ..writeln('    }')
      ..writeln('    return resolved.replace(queryParameters: <String, dynamic>{')
      ..writeln('      for (final entry in merged.entries) entry.key: entry.value,')
      ..writeln('    });')
      ..writeln('  }')
      ..writeln();

    for (final method in spec.methods) {
      _emitMethod(buffer, method);
      buffer.writeln();
    }
    buffer.write('}');
    return buffer.toString();
  }

  void _emitMethod(StringBuffer buffer, _MethodSpec method) {
    final parameters = _parameterList(method.parameters);
    final returnType = method.returnSpec.returnTypeDisplay;
    buffer
      ..writeln('  @override')
      ..writeln('  $returnType ${method.name}($parameters)');
    if (method.returnSpec.isStream) {
      buffer.writeln('async* {');
    } else {
      buffer.writeln('async {');
    }

    _emitUri(buffer, method);
    _emitHeaders(buffer, method);
    if (method.fileTarget != null) {
      _emitDownload(buffer, method);
    } else if (method.fileSource != null) {
      _emitUpload(buffer, method);
    } else {
      _emitRequest(buffer, method);
      if (method.returnSpec.isStream) {
        buffer
          ..writeln('    final response = await _client.send(request);')
          ..writeln('    yield* response.stream;');
      } else if (method.returnSpec.isFutureStream) {
        buffer
          ..writeln('    final response = await _client.send(request);')
          ..writeln('    return response.stream;');
      } else {
        _emitDecodedResponse(buffer, method);
      }
    }
    buffer.writeln('  }');
  }

  String _parameterList(List<_ParameterSpec> parameters) {
    final requiredPositional = <String>[];
    final optionalPositional = <String>[];
    final named = <String>[];
    for (final parameter in parameters) {
      if (parameter.element.isNamed) {
        named.add(parameter.declaration);
      } else if (parameter.element.isOptionalPositional) {
        optionalPositional.add(parameter.declaration);
      } else {
        requiredPositional.add(parameter.declaration);
      }
    }
    final groups = <String>[...requiredPositional];
    if (optionalPositional.isNotEmpty) {
      groups.add('[${optionalPositional.join(', ')}]');
    }
    if (named.isNotEmpty) {
      groups.add('{${named.join(', ')}}');
    }
    return groups.join(', ');
  }

  void _emitUri(StringBuffer buffer, _MethodSpec method) {
    final pathExpression = _pathExpression(method.http.path, method.pathParameters);
    final query = method.queryParameters.toList();
    if (query.isEmpty) {
      buffer.writeln(
        '    final uri = _resolveUri($pathExpression, const <String, Iterable<String>>{});',
      );
      return;
    }
    buffer.writeln('    final queryParameters = <String, Iterable<String>>{};');
    for (final parameter in query) {
      if (parameter.type is InterfaceType && (parameter.type as InterfaceType).isDartCoreMap) {
        _fail(
          'AlphaX API method `${method.element.name}` does not support query maps yet.',
          parameter.element,
          'Declare individual @AlphaXQuery parameters.',
        );
      }
      final value = parameter.name;
      final condition = parameter.isNullable ? '$value != null' : 'true';
      if (_isIterable(parameter.type)) {
        final elementType = (parameter.type as InterfaceType).typeArguments.single;
        final valueExpression = _queryValueExpression(elementType, 'value');
        buffer
          ..writeln('    if ($condition) {')
          ..writeln(
            "      queryParameters[${_literal(parameter.bindingName!)}] = $value.map((value) => $valueExpression);",
          )
          ..writeln('    }');
      } else {
        final expression = _queryValueExpression(parameter.type, value);
        buffer
          ..writeln('    if ($condition) {')
          ..writeln(
            "      queryParameters[${_literal(parameter.bindingName!)}] = <String>[$expression];",
          )
          ..writeln('    }');
      }
    }
    buffer.writeln('    final uri = _resolveUri($pathExpression, queryParameters);');
  }

  void _emitHeaders(StringBuffer buffer, _MethodSpec method) {
    final staticHeaders = <String, String>{};
    for (final entry in <Map<String, String>>[spec.staticHeaders, method.http.headers]) {
      for (final header in entry.entries) {
        // AlphaXHeaders is case-insensitive. Normalize static keys here so a
        // method-level header replaces an API-level header regardless of case.
        staticHeaders[_normalizeHeaderName(header.key)] = header.value;
      }
    }
    final dynamicHeaders = method.headerParameters.toList();
    if (staticHeaders.isEmpty && dynamicHeaders.isEmpty) {
      buffer.writeln('    var headers = const AlphaXHeaders.empty();');
      return;
    }
    buffer.writeln('    var headers = const AlphaXHeaders.empty();');
    for (final entry in staticHeaders.entries) {
      buffer.writeln(
        '    headers = headers.set(${_literal(entry.key)}, ${_literal(entry.value)});',
      );
    }
    for (final parameter in dynamicHeaders) {
      final condition = parameter.isNullable ? '${parameter.name} != null' : 'true';
      buffer
        ..writeln('    if ($condition) {')
        ..writeln(
          '      headers = headers.set(${_literal(parameter.bindingName!)}, ${parameter.name}.toString());',
        )
        ..writeln('    }');
    }
  }

  void _emitRequest(StringBuffer buffer, _MethodSpec method) {
    final options = method.options;
    final cancellation = method.cancellation;
    final body = method.body;
    final bodyExpression = body == null ? 'const AlphaXEmptyBody()' : _bodyExpression(body);
    final cancellationExpression = cancellation == null
        ? _option(options, 'cancellationToken', 'null')
        : cancellation.name;
    buffer
      ..writeln('    final request = AlphaXRequest(')
      ..writeln('      method: HttpMethod.${method.http.method},')
      ..writeln('      uri: uri,')
      ..writeln('      headers: headers,')
      ..writeln('      body: $bodyExpression,')
      ..writeln('      timeouts: ${_option(options, 'timeouts', 'const AlphaXTimeouts()')},')
      ..writeln('      cancellationToken: $cancellationExpression,')
      ..writeln(
        '      protocolPreference: ${_option(options, 'protocolPreference', 'AlphaXProtocolPreference.auto')},',
      )
      ..writeln('      protocolRequirement: ${_option(options, 'protocolRequirement', 'null')},')
      ..writeln(
        '      redirectPolicy: ${_option(options, 'redirectPolicy', 'const AlphaXRedirectPolicy()')},',
      )
      ..writeln('      priority: ${_option(options, 'priority', 'AlphaXPriority.normal')},')
      ..writeln('      onUploadProgress: ${_option(options, 'onUploadProgress', 'null')},')
      ..writeln('      onDownloadProgress: ${_option(options, 'onDownloadProgress', 'null')},')
      ..writeln('    );');
  }

  void _emitDownload(StringBuffer buffer, _MethodSpec method) {
    final options = method.options;
    final target = method.fileTarget!.name;
    buffer.writeln('    return _client.download(');
    buffer
      ..writeln('      uri,')
      ..writeln('      to: $target,')
      ..writeln('      headers: headers,')
      ..writeln('      timeout: ${_option(options, 'timeouts', 'null')},')
      ..writeln('      cancellationToken: ${_cancellation(options, method.cancellation)},')
      ..writeln(
        '      protocolPreference: ${_option(options, 'protocolPreference', 'AlphaXProtocolPreference.auto')},',
      )
      ..writeln('      protocolRequirement: ${_option(options, 'protocolRequirement', 'null')},')
      ..writeln(
        '      redirectPolicy: ${_option(options, 'redirectPolicy', 'const AlphaXRedirectPolicy()')},',
      )
      ..writeln('      onDownloadProgress: ${_option(options, 'onDownloadProgress', 'null')},')
      ..writeln('    );');
  }

  void _emitUpload(StringBuffer buffer, _MethodSpec method) {
    final options = method.options;
    final source = method.fileSource!.name;
    buffer.writeln('    return _client.upload(');
    buffer
      ..writeln('      uri,')
      ..writeln('      from: $source,')
      ..writeln('      method: HttpMethod.${method.http.method},')
      ..writeln('      headers: headers,')
      ..writeln('      timeout: ${_option(options, 'timeouts', 'null')},')
      ..writeln('      cancellationToken: ${_cancellation(options, method.cancellation)},')
      ..writeln(
        '      protocolPreference: ${_option(options, 'protocolPreference', 'AlphaXProtocolPreference.auto')},',
      )
      ..writeln('      protocolRequirement: ${_option(options, 'protocolRequirement', 'null')},')
      ..writeln(
        '      redirectPolicy: ${_option(options, 'redirectPolicy', 'const AlphaXRedirectPolicy()')},',
      )
      ..writeln('      onUploadProgress: ${_option(options, 'onUploadProgress', 'null')},')
      ..writeln('    );');
  }

  void _emitDecodedResponse(StringBuffer buffer, _MethodSpec method) {
    final response = method.returnSpec;
    buffer.writeln('    final response = await _client.send(request);');
    if (response.isRawResponse) {
      buffer.writeln('    return response;');
      return;
    }
    if (response.isVoid) {
      buffer
        ..writeln('    await response.readAsBytes();')
        ..writeln('    return;');
      return;
    }
    final decoded = _decodedValue(buffer, method, 'response');
    if (response.isWrapper) {
      buffer
        ..writeln('    return AlphaXApiResponse<${response.valueTypeDisplay}>(')
        ..writeln('      data: $decoded,')
        ..writeln('      response: response,')
        ..writeln('    );');
    } else {
      buffer.writeln('    return $decoded;');
    }
  }

  String _decodedValue(StringBuffer buffer, _MethodSpec method, String responseName) {
    final returnSpec = method.returnSpec;
    final valueType = returnSpec.valueType!;
    if (returnSpec.isFutureStream) {
      return '$responseName.stream';
    }
    if (_isNamed(valueType, 'String')) {
      return returnSpec.isNullable
          ? 'await $responseName.readAsStringOrNull()'
          : 'await $responseName.readAsString()';
    }
    if (_isByteList(valueType)) {
      return returnSpec.isNullable
          ? 'await $responseName.readAsBytesOrNull()'
          : 'await $responseName.readAsBytes()';
    }
    if (returnSpec.isVoid) {
      return 'null';
    }
    if (method.decoder != null) {
      final nullable = returnSpec.isNullable;
      buffer.writeln(
        '    final dynamic json = await $responseName.readAsJson${nullable ? 'OrNull' : ''}();',
      );
      if (nullable) {
        buffer.writeln('    if (json == null) {');
        buffer.writeln('      return null;');
        buffer.writeln('    }');
      }
      if (_isListOfCustomType(valueType)) {
        final elementType = (valueType as InterfaceType).typeArguments.single;
        return '(json as List<dynamic>).map<${elementType.getDisplayString()}>'
            '((item) => ${method.decoder}(item)).toList(growable: false)';
      }
      return '${method.decoder}(json)';
    }
    final json = returnSpec.isNullable
        ? 'await $responseName.readAsJsonOrNull()'
        : 'await $responseName.readAsJson()';
    if (valueType is DynamicType || valueType.getDisplayString() == 'Object?') {
      return json;
    }
    return '($json) as ${valueType.getDisplayString()}';
  }

  String _bodyExpression(_ParameterSpec parameter) {
    final name = parameter.name;
    final contentType = parameter.contentType;
    if (_bareTypeName(parameter.type) == 'AlphaXBody') {
      return name;
    }
    return switch (parameter.bodyEncoding) {
      0 => _jsonBodyExpression(parameter),
      1 =>
        'AlphaXBody.text($name${contentType == null ? '' : ', contentType: ${_literal(contentType)}'})',
      2 =>
        'AlphaXBody.bytes($name${contentType == null ? '' : ', contentType: ${_literal(contentType)}'})',
      3 =>
        'AlphaXStreamBody($name${contentType == null ? '' : ', contentType: ${_literal(contentType)}'})',
      4 =>
        'AlphaXFileBody($name${contentType == null ? '' : ', contentType: ${_literal(contentType)}'})',
      5 => name,
      _ => 'const AlphaXEmptyBody()',
    };
  }

  String _jsonBodyExpression(_ParameterSpec parameter) {
    final type = parameter.type;
    if (_isJsonSafe(type)) {
      return 'AlphaXBody.json(${parameter.name})';
    }
    final element = type.element;
    if (element is InterfaceElement && element.getMethod('toJson') == null) {
      _fail(
        'AlphaX request body `${parameter.name}` has type `${parameter.typeDisplay}` without toJson().',
        parameter.element,
        'Add a zero-argument toJson() method or use a JSON-safe value.',
      );
    }
    return 'AlphaXBody.json(${parameter.name}${parameter.isNullable ? '?' : ''}.toJson())';
  }

  String _option(_ParameterSpec? options, String field, String fallback) {
    if (options == null) {
      return fallback;
    }
    if (!options.isNullable) {
      return '${options.name}.$field';
    }
    if (fallback == 'null') {
      return '${options.name}?.$field';
    }
    return '${options.name}?.$field ?? $fallback';
  }

  String _cancellation(_ParameterSpec? options, _ParameterSpec? cancellation) =>
      cancellation?.name ?? _option(options, 'cancellationToken', 'null');
}

final RegExp _placeholderPattern = RegExp(r'\{([A-Za-z_][A-Za-z0-9_]*)\}');
final RegExp _validBindingName = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
final RegExp _validDecoderExpression = RegExp(
  r'^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*$',
);

_HttpMethodSpec? _readHttpMethod(MethodElement method) {
  final values = <_HttpMethodSpec>[];
  for (final entry in <(Type, String)>[
    (AlphaXGet, 'get'),
    (AlphaXPost, 'post'),
    (AlphaXPut, 'put'),
    (AlphaXPatch, 'patch'),
    (AlphaXDelete, 'delete'),
    (AlphaXHead, 'head'),
  ]) {
    final annotation = _annotation(method, entry.$1);
    if (annotation != null) {
      final path = annotation.read('path').stringValue;
      if (path.isEmpty || !_validEndpointPath(path)) {
        _fail(
          'AlphaX API method `${method.name}` has an invalid endpoint path `$path`.',
          method,
          'Use a valid relative path or absolute http:// or https:// URI.',
        );
      }
      final headers = _readStringMap(annotation, 'headers', method);
      _validateHeaders(headers, method);
      values.add(_HttpMethodSpec(method: entry.$2, path: path, headers: headers));
    }
  }
  if (values.length > 1) {
    _fail(
      'AlphaX API method `${method.name}` has more than one HTTP method annotation.',
      method,
      'Keep exactly one AlphaX HTTP method annotation.',
    );
  }
  return values.isEmpty ? null : values.single;
}

ConstructorElement _findClientFactory(ClassElement element) {
  final factories = element.constructors.where(
    (constructor) => constructor.isFactory && constructor.name == 'new',
  );
  if (factories.length != 1) {
    _fail(
      'AlphaX API `${element.name}` must declare one unnamed redirecting factory that accepts AlphaXClient.',
      element,
      'Add factory ${element.name}(AlphaXClient client) = _${element.name};',
    );
  }
  final factory = factories.single;
  if (factory.formalParameters.length != 1 ||
      factory.formalParameters.single.isNamed ||
      _bareTypeName(factory.formalParameters.single.type) != 'AlphaXClient') {
    _fail(
      'AlphaX API `${element.name}` factory must accept exactly one positional AlphaXClient.',
      factory,
      'Use factory ${element.name}(AlphaXClient client) = _${element.name};',
    );
  }
  return factory;
}

ConstantReader? _annotation(Element element, Type type) {
  final object = TypeChecker.typeNamed(type, inPackage: 'alphax').firstAnnotationOf(element);
  return object == null ? null : ConstantReader(object);
}

Map<String, String> _readStringMap(ConstantReader reader, String field, Element element) {
  final values = <String, String>{};
  for (final entry in reader.read(field).mapValue.entries) {
    final key = entry.key?.toStringValue();
    final value = entry.value?.toStringValue();
    if (key == null || value == null) {
      _fail(
        'AlphaX annotation on `${element.name}` contains a non-string `$field` entry.',
        element,
        'Use a const Map<String, String>.',
      );
    }
    values[key] = value;
  }
  return values;
}

void _validateHeaders(Map<String, String> headers, Element element) {
  for (final entry in headers.entries) {
    if (entry.key.trim().isEmpty || entry.key.contains(RegExp(r'[\s:]'))) {
      _fail(
        'AlphaX annotation on `${element.name}` contains invalid header name `${entry.key}`.',
        element,
        'Use a non-empty HTTP header token.',
      );
    }
    if (entry.value.contains(RegExp(r'[\r\n]'))) {
      _fail(
        'AlphaX annotation on `${element.name}` contains a header value with a newline.',
        element,
        'Remove CR/LF from static header values.',
      );
    }
  }
}

void _ensureAtMostOne(
  List<_ParameterSpec> parameters,
  _ParameterKind kind,
  MethodElement method,
  ClassElement api,
) {
  final count = parameters.where((parameter) => parameter.kind == kind).length;
  if (count > 1) {
    _fail(
      'AlphaX API method `${api.name}.${method.name}` declares more than one ${kind.name} parameter.',
      method,
      'Keep at most one ${kind.name} binding.',
    );
  }
}

String _pathExpression(String path, Iterable<_ParameterSpec> parameters) {
  final mappings = <String, String>{
    for (final parameter in parameters) parameter.bindingName!: parameter.name,
  };
  final buffer = StringBuffer("'");
  var offset = 0;
  for (final match in _placeholderPattern.allMatches(path)) {
    buffer.write(_escapeSingle(path.substring(offset, match.start)));
    buffer.write(r'${Uri.encodeComponent(');
    buffer.write(mappings[match.group(1)]!);
    buffer.write(')}');
    offset = match.end;
  }
  buffer
    ..write(_escapeSingle(path.substring(offset)))
    ..write("'");
  return buffer.toString();
}

String _queryValueExpression(DartType type, String expression) {
  if (type is InterfaceType && type.element is EnumElement) {
    return '$expression.name';
  }
  return '$expression.toString()';
}

bool _validEndpointPath(String path) {
  final withoutPlaceholders = path.replaceAll(_placeholderPattern, 'placeholder');
  final uri = Uri.tryParse(withoutPlaceholders);
  if (uri == null) {
    return false;
  }
  if (uri.isAbsolute) {
    return (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
  }
  return !path.startsWith('//');
}

bool _isDirectlySupportedResponse(DartType type) {
  if (type is DynamicType || type is VoidType) {
    return true;
  }
  if (type.isDartCoreString ||
      type.isDartCoreBool ||
      type.isDartCoreInt ||
      type.isDartCoreDouble ||
      type.isDartCoreNum ||
      type.isDartCoreObject ||
      type.isDartCoreMap ||
      type.isDartCoreList) {
    return true;
  }
  return false;
}

bool _isJsonSafe(DartType type) {
  if (type is DynamicType ||
      type.isDartCoreString ||
      type.isDartCoreBool ||
      type.isDartCoreInt ||
      type.isDartCoreDouble ||
      type.isDartCoreNum ||
      type.isDartCoreMap ||
      type.isDartCoreList) {
    return true;
  }
  return _bareTypeName(type) == 'AlphaXBody';
}

bool _requiresDecoder(DartType type) {
  if (_isListOfCustomType(type)) {
    return true;
  }
  return !_isDirectlySupportedResponse(type);
}

bool _isByteList(DartType type) {
  if (type is! InterfaceType || !type.isDartCoreList || type.typeArguments.length != 1) {
    return false;
  }
  return type.typeArguments.single.isDartCoreInt;
}

bool _isByteStream(DartType type) {
  if (type is! InterfaceType || !type.isDartAsyncStream || type.typeArguments.length != 1) {
    return false;
  }
  return _isByteList(type.typeArguments.single);
}

bool _validHeaderName(String name) => name.isNotEmpty && !name.contains(RegExp(r'[\s:]'));

String _normalizeHeaderName(String name) => name.trim().toLowerCase();

bool _isListOfCustomType(DartType type) {
  if (type is! InterfaceType || !type.isDartCoreList || type.typeArguments.length != 1) {
    return false;
  }
  final element = type.typeArguments.single;
  return !_isDirectlySupportedResponse(element) && !element.isDartCoreInt;
}

bool _isIterable(DartType type) =>
    type is InterfaceType && (type.isDartCoreIterable || type.isDartCoreList || type.isDartCoreSet);

bool _isNullableType(DartType type) => type.nullabilitySuffix == NullabilitySuffix.question;

bool _isNamed(DartType? type, String name) => type is InterfaceType && type.element.name == name;

String _bareTypeName(DartType type) {
  if (type is InterfaceType) {
    return type.element.name!;
  }
  return type.getDisplayString();
}

String _literal(String value) => jsonEncode(value).replaceAll(r'$', r'\$');

String _escapeSingle(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll("'", r"\'")
    .replaceAll(r'$', r'\$')
    .replaceAll('\n', r'\n')
    .replaceAll('\r', r'\r');

Never _fail(String message, Element element, String todo) {
  throw InvalidGenerationSourceError(message, element: element, todo: todo);
}
