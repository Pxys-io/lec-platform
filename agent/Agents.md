# Agent (Flutter App) - Architecture Specification

## ⚠️ IMPORTANT: DO NOT CHANGE ANY MODEL OR ROUTE OR NAME
This document defines the core architecture for the Agent app. All models, API routes, and component names are fixed. Any modifications must be discussed and approved by the lead architect.

---

## Overview
Flutter mobile application for students, instructors, and admins. Only communicates with Main Server - never directly with Video Server. All video streaming goes through Main Server proxy.

---

## Core Responsibilities
1. **Authentication** - Login, logout, token management
2. **Course Browsing** - Browse, filter, search courses
3. **Lesson Viewing** - Video playback, materials, progress
4. **Quiz Taking** - Answer questions, submit, view results
5. **User Profile** - View/edit profile, view access
6. **Social** - Comments, messaging, reporting
7. **Offline Features** - Continue watching, cache

---

## Data Models (From Main Server)

### User Models
```dart
class User {
  final String id;
  final String email;
  final String phone;
  final String role; // student, instructor, admin, super_admin
  final DateTime createdAt;
  final DateTime? lastLogin;
  final DateTime? bannedUntil;
  final UserProfile profile;
}

class UserProfile {
  final String firstName;
  final String lastName;
  final String? avatarUrl;
}
```

### Course Models
```dart
class Course {
  final String id;
  final String title;
  final String description;
  final String instructorId;
  final List<String> tags;
  final String visibility; // public, private, restricted
  final String? thumbnailUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

### Lesson Models
```dart
class Lesson {
  final String id;
  final String courseId;
  final String title;
  final String description;
  final int order;
  final String? videoUrl; // HLS manifest URL from Main Server
  final String lockType; // none, previous_lesson, quiz
  final String? quizId;
  final bool isPublished;
  final List<Material> materials;
}

class Material {
  final String id;
  final String lessonId;
  final String type; // pdf, document, link, image
  final String title;
  final String url;
  final int? fileSize;
}
```

### Quiz Models
```dart
class Quiz {
  final String id;
  final String lessonId;
  final String title;
  final String? description;
  final double passingScore;
  final int? timeLimit;
  final List<Question> questions;
}

class Question {
  final String id;
  final String type; // multiple_choice, true_false, short_answer
  final String question;
  final List<String>? options;
  final double points;
  final int order;
}

class QuizAttempt {
  final String id;
  final String quizId;
  final Map<String, String> answers; // questionId -> answer
  final double? score;
  final bool? passed;
  final DateTime startedAt;
  final DateTime? completedAt;
}
```

### Comment Models
```dart
class Comment {
  final String id;
  final String userId;
  final String userName; // from author
  final String? userAvatar; // from author
  final String lessonId;
  final String content;
  final String? parentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Comment> replies;
}
```

### Access Code Models
```dart
class AccessCode {
  final String code;
  final String? courseId;
  final String? courseName;
  final String? lessonId;
  final String? accessType;
  final int? accessDuration;
  final DateTime? expiresAt;
  final int? maxUses;
  final int currentUses;
}
```

---

## API Integration

### Base URL Configuration
```dart
// Environment configuration
class ApiConfig {
  static String baseUrl = 'http://localhost:8000';  // Default for development
  static String apiVersion = '/api/v1';
  static String wsUrl = 'ws://localhost:8000';  // WebSocket for real-time

  // Change for different environments
  // Set to 'https://api.LEC.com' for production
}

// Quick config change:
void setApiBaseUrl(String url) {
  ApiConfig.baseUrl = url;
}
```

### HTTP Client Setup
```dart
class ApiClient {
  late Dio _dio;
  String? _accessToken;
  String? _refreshToken;

  void init() {
    _dio = Dio(BaseOptions(
      baseUrl: '${ApiConfig.baseUrl}${ApiConfig.apiVersion}',
      connectTimeout: 30 seconds,
      receiveTimeout: 30 seconds,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_accessToken != null) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Try refresh token
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry request
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                error: 'Token refresh failed',
              ),
            );
          }
        }
        return handler.next(error);
      },
    ));
  }
}
```

### API Endpoints (Consumed from Main Server)

#### Auth Endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /auth/login | Login |
| POST | /auth/logout | Logout |
| POST | /auth/refresh | Refresh token |
| GET | /auth/me | Get profile |
| PUT | /auth/me | Update profile |

#### Course Endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /courses | List courses |
| GET | /courses/{id} | Course details |
| GET | /courses/{id}/lessons | Course lessons |

#### Lesson Endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /lessons/{id} | Lesson details |
| GET | /lessons/{id}/materials | Lesson materials |
| GET | /lessons/{id}/comments | Lesson comments |
| POST | /lessons/{id}/comments | Add comment |

#### Quiz Endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /quizzes/{id} | Get quiz |
| POST | /quizzes/{id}/submit | Submit answers |
| GET | /quizzes/{id}/results | Get results |

#### Video Endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /videos/{lesson_id}/manifest | Get HLS URL |
| GET | /videos/{lesson_id}/stream | Get stream URL |

#### Code Endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /codes/validate | Validate code |

#### Stats Endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /stats/watch | Record watch progress |

---

## Video Playback

### Architecture
```
Agent (Flutter)
    ↓
Main Server (proxy request)
    ↓
Video Server (serve segments)
```

### Video Player Implementation
```dart
class VideoPlayerService {
  String? _manifestUrl;

  Future<void> initialize(String lessonId) async {
    // Get HLS manifest from Main Server
    final response = await apiClient.get('/videos/$lessonId/manifest');
    _manifestUrl = response.data['manifest_url'];

    // Initialize video player with manifest
    await _videoPlayerController.initialize(VideoSource.network(_manifestUrl!));
  }

  // Player shows video with watermark segments embedded
  // Watermark is baked into HLS stream by Video Server
}
```

### Continue Watching Feature
```dart
class ContinueWatchingService {
  // Local storage for offline progress
  static const String _key = 'continue_watching';

  Future<void> saveProgress(String lessonId, double position) async {
    final prefs = await SharedPreferences.getInstance();
    final progress = {
      'lessonId': lessonId,
      'position': position,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_key, jsonEncode(progress));
  }

  Future<List<WatchProgress>> getContinueWatching() async {
    // Returns lessons with recent watch activity
    // Shown on home screen
  }
}
```

---

## Screen Structure

### Navigation
```
/ (home)
├── /login
├── /register
├── /courses
│   ├── /courses/:id (course detail)
│   │   ├── /courses/:id/lessons/:lessonId (lesson)
│   │   │   ├── /courses/:id/lessons/:lessonId/video (video player)
│   │   │   ├── /courses/:id/lessons/:lessonId/materials
│   │   │   └── /courses/:id/lessons/:lessonId/quiz
│   │   └── /courses/:id/members (for instructors)
│   ├── /quizzes/:id
│   ├── /profile
│   │   ├── /profile/edit
│   │   └── /profile/courses (my courses)
│   ├── /messages
│   │   └── /messages/:userId (chat)
│   └── /admin (admin only)
│       ├── /admin/users
│       ├── /admin/courses
│       ├── /admin/reports
│       └── /admin/stats
```

---

## Local Storage

### SharedPreferences Keys
```dart
class LocalStorageKeys {
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String user = 'user_data';
  static const String continueWatching = 'continue_watching';
  static const String recentSearches = 'recent_searches';
  static const String downloadedLessons = 'downloaded_lessons';
}
```

### Offline Features
1. **Continue Watching** - Last watched position saved locally
2. **Recent Searches** - Course search history
3. **Downloaded Materials** - PDF/document caching (future)

---

## State Management

### Recommended: BLoC or Riverpod
```dart
// auth_bloc.dart - Authentication state
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  // States: initial, loading, authenticated, unauthenticated, error
  // Events: login, logout, refresh, checkAuth
}

// courses_bloc.dart - Courses state
class CoursesBloc extends Bloc<CoursesEvent, CoursesState> {
  // States: initial, loading, loaded, error
  // Events: loadCourses, filterCourses, searchCourses
}

// video_player_bloc.dart - Video playback state
class VideoPlayerBloc extends Bloc<VideoEvent, VideoState> {
  // States: initial, loading, playing, paused, completed, error
  // Events: loadVideo, play, pause, seek, updateProgress
}
```

---

## Dependency Injection

### Services
```dart
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;

  late ApiClient apiClient;
  late VideoPlayerService videoPlayer;
  late LocalStorageService storage;
  late WatchProgressService watchProgress;

  void init({String? baseUrl}) {
    // Initialize with optional baseUrl override
    apiClient = ApiClient(baseUrl: baseUrl);
    videoPlayer = VideoPlayerService(apiClient);
    storage = LocalStorageService();
    watchProgress = WatchProgressService(storage);
  }
}
```

---

## Development Configuration

### Environment Setup
```dart
void main() {
  // Development mode - default to localhost
  ServiceLocator().init();

  // Or override for testing
  // ServiceLocator().init(baseUrl: 'https://test.LEC.com');

  runApp(LecApp());
}
```

### Quick Config Change
```dart
// From environment variable or config file
ServiceLocator().init(
  baseUrl: Platform.environment['API_URL'] ?? 'http://localhost:8000',
);
```

---

## UI Conventions

### Component Library
- Use consistent design system
- Follow material design 3
- Course cards: thumbnail, title, instructor, progress
- Video player: custom controls, progress bar, fullscreen

### Simple UI Requirements
1. Clean, minimal design
2. Fast navigation
3. Clear progress indicators
4. Offline-friendly (show continue watching)

---

## Development Prompt

You are a Flutter mobile developer working on the Agent app.

### Your Task
Implement the mobile application that consumes Main Server APIs and displays video content as defined in this document.

### Key Requirements
1. **DO NOT CHANGE** any model, route, or component name
2. Start with the default local configuration:
   - `baseUrl = 'http://localhost:8000'` (Main Server)
   - All API calls go through Main Server proxy
3. To change the API URL for testing/production:
   ```dart
   ServiceLocator().init(baseUrl: 'https://api.LEC.com');
   ```
4. NEVER communicate directly with Video Server - only through Main Server
5. Implement continue watching feature with local storage
6. Simple UI following material design 3

### Dependencies
- Flutter SDK
- Dio (HTTP client)
- Video player (video_player or chewie)
- flutter_secure_storage (tokens)
- BLoC or Riverpod (state management)

### Quick Start
```bash
cd /home/pxy/projects/lec/agent
flutter pub get
flutter run
```

### Important Notes
- Video manifest URL comes from Main Server, not Video Server
- Watermarks are embedded in HLS stream
- All course/lesson access validated by Main Server

---

## Security Notes
- Store tokens securely (flutter_secure_storage)
- Never store user_id/phone in plain text
- Clear data on logout
- Validate access before every request

---

## Models NOT to Change
- API response models
- Route endpoints
- Authentication flow
- Token storage keys
- Video player integration
- Local storage keys