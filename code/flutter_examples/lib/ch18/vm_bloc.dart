import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'data.dart';
import 'pantry_view.dart';
import 'state.dart';

// #docregion bloc
/// Everything that can happen is an explicit event object.
sealed class PantryEvent {
  const PantryEvent();
}

final class PantryStarted extends PantryEvent {
  const PantryStarted({this.refresh = false});
  final bool refresh;
}

final class PantryToggled extends PantryEvent {
  const PantryToggled(this.index);
  final int index;
}

final class PantryEggsAdded extends PantryEvent {
  const PantryEggsAdded();
}

class PantryBloc extends Bloc<PantryEvent, PantryState> {
  PantryBloc(this._repository) : super(const PantryLoading()) {
    on<PantryStarted>((event, emit) async {
      emit(const PantryLoading());
      final result = await _repository.load(refresh: event.refresh);
      emit(stateFromResult(state, result));
    });
    on<PantryToggled>((event, emit) async {
      final result = await _repository.toggle(event.index);
      emit(stateFromResult(state, result));
    });
    on<PantryEggsAdded>((event, emit) async {
      final result = await _repository.add('Eggs');
      emit(stateFromResult(state, result));
    });
  }

  final PantryRepository _repository;
}
// #enddocregion bloc

// #docregion screen
class BlocPantryScreen extends StatelessWidget {
  const BlocPantryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          PantryBloc(context.read<PantryRepository>())..add(const PantryStarted()),
      child: BlocBuilder<PantryBloc, PantryState>(
        builder: (context, state) {
          final bloc = context.read<PantryBloc>();
          return PantryView(
            state: state,
            onToggle: (i) => bloc.add(PantryToggled(i)),
            onAdd: () => bloc.add(const PantryEggsAdded()),
            onRetry: () => bloc.add(const PantryStarted(refresh: true)),
          );
        },
      ),
    );
  }
}
// #enddocregion screen
