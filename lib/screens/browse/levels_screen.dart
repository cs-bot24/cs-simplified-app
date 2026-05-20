import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../models/level_model.dart';
import '../../providers/academic_provider.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import 'semesters_screen.dart';

class LevelsScreen extends StatefulWidget {
  final LevelModel level;
  const LevelsScreen({super.key, required this.level});
  @override State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AcademicProvider>().fetchSemesters(widget.level.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final academic = context.watch<AcademicProvider>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.primaryColorValue),
        foregroundColor: Colors.white,
        title: Text('${widget.level.emoji} ${widget.level.levelName}'),
        elevation: 0,
      ),
      body: academic.loading
          ? const LoadingView()
          : academic.error != null
              ? ErrorView(
                  message: academic.error!,
                  onRetry: () => context
                      .read<AcademicProvider>()
                      .fetchSemesters(widget.level.id))
              : academic.semesters.isEmpty
                  ? const Center(
                      child: Text('No semesters available yet.',
                          style: TextStyle(
                              color: Color(AppConstants.textLightValue))))
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: academic.semesters.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final sem = academic.semesters[i];
                        return _SemesterTile(
                          title: sem.semesterName,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      SemestersScreen(semester: sem))),
                        );
                      },
                    ),
    );
  }
}

class _SemesterTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const _SemesterTile({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: const Color(AppConstants.accentColorValue),
      leading: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: const Color(AppConstants.primaryColorValue).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.calendar_today_rounded,
            color: Color(AppConstants.primaryColorValue), size: 20),
      ),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(AppConstants.textDarkValue))),
      trailing: const Icon(Icons.arrow_forward_ios_rounded,
          size: 14, color: Color(AppConstants.textLightValue)),
    );
  }
}
