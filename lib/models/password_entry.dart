class PasswordEntry {
  final String id;
  final String title;
  final String username;
  final String password;

  PasswordEntry({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'username': username,
        'password': password,
      };

  factory PasswordEntry.fromJson(Map<String, dynamic> json) => PasswordEntry(
        id: json['id'],
        title: json['title'],
        username: json['username'],
        password: json['password'],
      );
}