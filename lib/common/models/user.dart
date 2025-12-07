import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String? name;
  final String? email;
  final String defaultCurrency;

  const User({
    required this.id,
    this.name,
    this.email,
    this.defaultCurrency = 'USD',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      defaultCurrency: json['defaultCurrency'] as String? ?? 'USD',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'defaultCurrency': defaultCurrency,
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? defaultCurrency,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
    );
  }

  @override
  List<Object?> get props => [id, name, email, defaultCurrency];
}
