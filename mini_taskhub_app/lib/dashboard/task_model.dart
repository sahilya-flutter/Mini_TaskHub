class Task {
  final String id;
  final String title;
  final String description;
  final bool isCompleted;
  final DateTime createdAt;
  final String userId;

  Task({
    required this.id,
    required this.title,
    this.description = "",
    this.isCompleted = false,
    required this.createdAt,
    required this.userId,
  });

  // Create a Task from JSON data
  factory Task.fromJson(Map<String, dynamic> json) {
    final description = json['description'];
    print(
        'Parsing JSON for task ${json['id']}, description raw value: $description');

    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      description: description != null ? description.toString() : "",
      isCompleted: json['is_completed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      userId: json['user_id'] as String,
    );
  }

  // Convert a Task to JSON data
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'is_completed': isCompleted,
      'created_at': createdAt.toIso8601String(),
      'user_id': userId,
    };
  }

  // Create a copy of the current task with modified properties
  Task copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? createdAt,
    String? userId,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
    );
  }
}
