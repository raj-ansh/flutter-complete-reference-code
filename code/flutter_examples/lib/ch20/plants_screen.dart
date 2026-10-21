import 'package:flutter/material.dart';

import 'failure.dart';
import 'plant.dart';
import 'plant_api.dart';

// #docregion screen
/// Shows the first page of plants with loading, empty, error and data states.
class PlantsScreen extends StatefulWidget {
  const PlantsScreen({super.key, required this.api});
  final PlantApi api;

  @override
  State<PlantsScreen> createState() => _PlantsScreenState();
}

class _PlantsScreenState extends State<PlantsScreen> {
  // Created once in initState, never in build: a request made in build would
  // repeat on every rebuild.
  late Future<ApiResult<Paged<Plant>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.list();
  }

  void _retry() {
    setState(() {
      _future = widget.api.list();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ApiResult<Paged<Plant>>>(
      future: _future,
      builder: (context, snapshot) {
        final result = snapshot.data;
        if (result == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return switch (result) {
          ApiErr(:final failure) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  failure is NoConnection
                      ? Icons.wifi_off
                      : Icons.error_outline,
                  size: 48,
                ),
                const SizedBox(height: 8),
                Text(failure.message, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                if (failure.retryable)
                  FilledButton(
                    onPressed: _retry,
                    child: const Text('Try again'),
                  ),
              ],
            ),
          ),
          ApiOk(:final value) when value.items.isEmpty => const Center(
            child: Text('No plants yet'),
          ),
          ApiOk(:final value) => ListView(
            children: [
              for (final p in value.items)
                ListTile(
                  title: Text(p.name),
                  subtitle: Text('${p.light}, ${p.heightCm} cm'),
                ),
            ],
          ),
        };
      },
    );
  }
}
// #enddocregion screen
