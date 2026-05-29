import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) =>
        context.read<AcademicProvider>().fetchSemesters(widget.level.id));
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AcademicProvider>();
    return Scaffold(
      appBar: AppBar(title: Text('${widget.level.emoji} ${widget.level.levelName}')),
      body: a.loading ? const LoadingView()
          : a.error != null ? ErrorView(message: a.error!,
              onRetry: () => context.read<AcademicProvider>().fetchSemesters(widget.level.id))
          : a.semesters.isEmpty
              ? const Center(child: Text('No semesters available yet.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: a.semesters.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final sem = a.semesters[i];
                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.calendar_today_rounded,
                              color: Theme.of(context).colorScheme.primary, size: 20),
                        ),
                        title: Text(sem.semesterName,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: () => Navigator.push(ctx, MaterialPageRoute(
                            builder: (_) => SemestersScreen(semester: sem))),
                      ),
                    );
                  },
                ),
    );
  }
}
