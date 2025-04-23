import 'package:flutter_riverpod/flutter_riverpod.dart';

final gameStateProvider = StateNotifierProvider<GameController, List<String>>((ref) {
  return GameController();
});

class GameController extends StateNotifier<List<String>> {
  GameController() : super(List.filled(9, ''));

  void makeMove(int index, String symbol) {
    if (state[index] == '') {
      final newState = [...state];
      newState[index] = symbol;
      state = newState;
    }
  }

  void resetBoard() {
    state = List.filled(9, '');
  }

  String? checkWinner() {
    const wins = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8],
      [0, 3, 6], [1, 4, 7], [2, 5, 8],
      [0, 4, 8], [2, 4, 6],
    ];
    for (var line in wins) {
      final a = line[0], b = line[1], c = line[2];
      if (state[a] != '' && state[a] == state[b] && state[a] == state[c]) {
        return state[a];
      }
    }
    if (!state.contains('')) return 'draw';
    return null;
  }
}
