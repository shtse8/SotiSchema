# SotiSchema

Welcome to **SotiSchema** – your ultimate tool for generating schemas directly from your Dart data classes. Whether you're working with `freezed` or `json_serializable`, SotiSchema simplifies the process, enabling seamless integration with AI models, robust data validation, and more.

---

## 🎯 Why SotiSchema?

**SotiSchema** is designed for developers who value efficiency and precision. If you're tired of manually maintaining schemas and ensuring they stay in sync with your code, SotiSchema is the solution you've been waiting for.

### **Key Benefits:**

- **Effortless Schema Generation:** Simply annotate your Dart classes, and SotiSchema does the rest.
- **AI-Powered Applications:** Generate schemas that enforce structured responses from AI models.
- **Future-Proof:** Prepare for upcoming support of various schema formats, including Protocol Buffers, Avro, and Thrift.
- **Seamless Integration:** Perfectly complements your existing tools, whether you're using `freezed`, `json_serializable`, or custom Dart types.

---

## 🚀 Getting Started

### Installation

Get started with SotiSchema in just one step:

```bash
dart pub add soti_schema
```

This command will add SotiSchema to your project, ready for immediate use.

### Configuration

To make SotiSchema work harmoniously with `freezed` and `json_serializable`, configure your `build.yaml` file like this:

```yaml
targets:
  $default:
    builders:
      json_serializable:
        options:
          explicit_to_json: true

global_options:
  freezed|freezed:
    runs_before:
      - soti_schema|openApiBuilder
```

### Why This Configuration?

- **`explicit_to_json: true`** ensures that nested objects are correctly serialized by generating explicit `toJson` methods.
- **`runs_before`** guarantees that `freezed` runs before SotiSchema, ensuring that everything is in place when SotiSchema processes your classes.

---

## 💡 How to Use SotiSchema

### Example with `freezed`

Here’s how to generate a JSON schema using SotiSchema with a `freezed` class:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:soti_schema/soti_schema.dart';

part 'example_model.freezed.dart';
part 'example_model.g.dart';

@freezed
@SotiSchema()
class ExampleModel with _$ExampleModel {
  const factory ExampleModel({
    @Default('') String name,
    @Default(0) int age,
    @Default([]) List<String> hobbies,
  }) = _ExampleModel;

  factory ExampleModel.fromJson(Map<String, dynamic> json) =>
      _$ExampleModelFromJson(json);

  @jsonSchema
  static String get schema => _$ExampleModelSchema;
}
```

### Example with `json_serializable`

Prefer `json_serializable`? SotiSchema has you covered:

```dart
import 'package:json_annotation/json_annotation.dart';
import 'package:soti_schema/soti_schema.dart';

part 'example_model.g.dart';

@SotiSchema()
@JsonSerializable()
class ExampleModel {
  final String name;
  final int age;
  final List<String> hobbies;

  ExampleModel({
    this.name = '',
    this.age = 0,
    this.hobbies = const [],
  });

  factory ExampleModel.fromJson(Map<String, dynamic> json) =>
      _$ExampleModelFromJson(json);

  Map<String, dynamic> toJson() => _$ExampleModelToJson(this);

  @jsonSchema
  static String get schema => _$ExampleModelSchema;

  @jsonSchema
  static Map<String, dynamic> get schemaMap => _$ExampleModelSchemaMap;
}
```

### Flexible Schema Naming

With SotiSchema, you have the freedom to name your schema methods however you like and choose between returning a `String` or `Map<String, dynamic>`. SotiSchema adapts to your needs:

```dart
@jsonSchema
static String get customSchemaName => _$ExampleModelSchema;

@jsonSchema
static Map<String, dynamic> get anotherSchema => _$ExampleModelSchemaMap;
```

---

## 📋 Supported Dart Data Types

SotiSchema currently supports:

- **`freezed`**: ✔️ Supported
- **`json_serializable`**: ✔️ Supported

### Coming Soon:

- **Custom Data Types**: 🛠 Planned
- **Protocol Buffers**: 🛠 Planned
- **Avro**: 🛠 Planned
- **Thrift**: 🛠 Planned

---

## 🌟 Why Developers Love SotiSchema

**"SotiSchema has completely transformed how we handle data validation and AI integrations. The ease of generating accurate schemas directly from our Dart classes is unmatched."**  
– *Satisfied Developer*

---

## 💼 Real-World Use Case

### AI Integration Example

Imagine you’re building an AI-powered application. SotiSchema helps ensure that AI responses adhere to the strict structure defined by your schemas:

```dart
import 'package:langchain/langchain.dart';
import 'package:your_project/example_model.dart'; // Assuming this is where your ExampleModel class is defined

void main() {
  final openaiApiKey = 'your-openai-api-key';

  final model = ChatOpenAI(
    apiKey: openaiApiKey,
    defaultOptions: const ChatOpenAIOptions(
      responseFormat: ChatOpenAIResponseFormat(
        type: ChatOpenAIResponseFormatType.jsonObject,
      ),
    ),
  );

  final parser = JsonOutputParser<ChatResult>();
  final mapper = Runnable.mapInputStream(
    (Stream<Map<String, dynamic>> inputStream) => inputStream.map((input) {
      return ExampleModel.fromJson(input);
    }).distinct(),
  );

  final chain = model.pipe(parser).pipe(mapper);

  final stream = chain.stream(
    PromptValue.string('''
Describe a person using the schema provided.
${ExampleModel.schema}
    '''),
  );

  stream.listen((response) {
    print(response);  // This response will be a JSON object that matches your schema
  });
}
```

---

## 🤝 Get Involved

We welcome contributions! If you have ideas for new features, enhancements, or bug fixes, please check out our [contributing guidelines](CONTRIBUTING.md).

---

## 📄 License

SotiSchema is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.

---

Thank you for choosing SotiSchema! We’re excited to see what you create with it. If you have any questions or suggestions, don’t hesitate to open an issue or contribute to the project. Happy coding!