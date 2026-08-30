/// Caller-owned models used by the generated OpenAPI declaration.
final class User {
  const User({required this.id, required this.name});

  factory User.fromJson(Object? value) {
    final json = (value! as Map<Object?, Object?>).cast<String, Object?>();
    return User(
      id: (json['id']! as num).toInt(),
      name: json['name']! as String,
    );
  }

  final int id;
  final String name;
}

final class CreateUser {
  const CreateUser(this.name);

  final String name;

  Map<String, Object?> toJson() => <String, Object?>{'name': name};
}
