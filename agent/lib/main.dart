import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';

import 'src/backend.dart';
import 'src/navigation/app_router.dart';
import 'src/services/device_service.dart';
import 'src/theme/app_theme.dart';
import 'src/logic/auth/auth_cubit.dart';
import 'src/logic/course/course_cubit.dart';
import 'src/logic/lesson/lesson_cubit.dart';
import 'src/logic/qbank/qbank_cubit.dart';
import 'src/logic/stats/stats_cubit.dart';
import 'src/logic/theme/theme_cubit.dart';
import 'src/logic/downloads/downloads_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: HydratedStorageDirectory(
      (await getApplicationDocumentsDirectory()).path,
    ),
  );

  // Replace '192.168.1.x' with your computer's local IP address on the same network
  final deviceId = await DeviceService.getOrCreatePersistentDeviceId();
  final deviceType = DeviceService.getDeviceType();
  const apiUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://main.lec.pxysio.top/api/v1',
  );
  final backend = Backend.create(
    apiUrl,
    deviceId: deviceId,
    deviceType: deviceType,
  );
  runApp(MyApp(backend: backend));
}

class MyApp extends StatelessWidget {
  final Backend backend;

  const MyApp({super.key, required this.backend});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: backend.auth),
        RepositoryProvider.value(value: backend.users),
        RepositoryProvider.value(value: backend.courses),
        RepositoryProvider.value(value: backend.lessons),
        RepositoryProvider.value(value: backend.quizzes),
        RepositoryProvider.value(value: backend.videos),
        RepositoryProvider.value(value: backend.misc),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => AuthCubit(backend.auth, backend)),
          BlocProvider(create: (context) => CourseCubit(backend.courses)),
          BlocProvider(create: (context) => LessonCubit(backend.courses)),
          BlocProvider(create: (context) => QBankCubit(backend.quizzes)),
          BlocProvider(create: (context) => StatsCubit(backend.misc)),
          BlocProvider(create: (context) => ThemeCubit()),
          BlocProvider(
            create: (context) => DownloadsCubit(
              apiClient: backend.auth.apiClient,
              videoRepository: backend.videos,
            )..init(),
          ),
        ],
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) {
            return MaterialApp.router(
              title: 'beIN Med',
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: themeMode,
              routerConfig: AppRouter.router(context.read<AuthCubit>()),
              debugShowCheckedModeBanner: false,
            );
          },
        ),
      ),
    );
  }
}
