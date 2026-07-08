import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dots_indicator/dots_indicator.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      'title': 'Interactive Lectures',
      'description': 'Watch high-quality medical lectures with synchronized notes.',
    },
    {
      'title': 'Clinical QBank',
      'description': 'Practice with UWorld-style clinical scenarios and detailed rationales.',
    },
    {
      'title': 'Advanced Analytics',
      'description': 'Track your progress and identify areas for improvement.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 200,
                        width: 200,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          index == 0 ? Icons.video_library : index == 1 ? Icons.quiz : Icons.bar_chart,
                          size: 100,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        _pages[index]['title']!,
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 24),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _pages[index]['description']!,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DotsIndicator(
                  dotsCount: _pages.length,
                  position: _currentPage,
                  decorator: DotsDecorator(
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentPage < _pages.length - 1) {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeIn,
                        );
                      } else {
                        context.go('/login');
                      }
                    },
                    child: Text(_currentPage < _pages.length - 1 ? 'Next' : 'Get Started'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
