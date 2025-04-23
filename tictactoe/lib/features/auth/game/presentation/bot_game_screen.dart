import 'package:flutter/material.dart';
import 'dart:math';

class BotGameScreen extends StatefulWidget {
  const BotGameScreen({super.key});

  @override
  State<BotGameScreen> createState() => _BotGameScreenState();
}

class _BotGameScreenState extends State<BotGameScreen> {
  List<String> board = List.filled(9, '');
  String currentTurn = 'X';
  String? winner;

  void makeMove(int index) {
    if (board[index] == '' && winner == null) {
      setState(() {
        board[index] = currentTurn;
        winner = checkWinner();
        currentTurn = currentTurn == 'X' ? 'O' : 'X';
      });

      if (currentTurn == 'O' && winner == null) {
        Future.delayed(const Duration(milliseconds: 400), botMove);
      }
    }
  }

  void botMove() {
    final empty = <int>[];
    for (int i = 0; i < board.length; i++) {
      if (board[i] == '') empty.add(i);
    }
    if (empty.isNotEmpty) {
      final move = empty[Random().nextInt(empty.length)];
      makeMove(move);
    }
  }

  String? checkWinner() {
    const wins = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8],
      [0, 3, 6], [1, 4, 7], [2, 5, 8],
      [0, 4, 8], [2, 4, 6],
    ];
    for (var line in wins) {
      final a = line[0], b = line[1], c = line[2];
      if (board[a] != '' && board[a] == board[b] && board[a] == board[c]) {
        return board[a];
      }
    }
    if (!board.contains('')) return 'draw';
    return null;
  }

  void resetGame() {
    setState(() {
      board = List.filled(9, '');
      currentTurn = 'X';
      winner = null;
    });
  }

  Widget buildCell(int i) {
    final color = board[i] == 'X'
        ? Colors.deepPurple
        : board[i] == 'O'
            ? Colors.pink
            : Colors.grey.shade300;

    return GestureDetector(
      onTap: () => makeMove(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          border: Border.all(color: Colors.black26),
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              board[i],
              key: ValueKey(board[i]),
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Play vs Bot"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: resetGame,
          )
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            winner == null
                ? "Your turn"
                : winner == 'X'
                    ? "🎉 You won!"
                    : winner == 'O'
                        ? "Bot won 😢"
                        : "Draw 🤝",
            style: const TextStyle(fontSize: 22),
          ),
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: 1,
            child: GridView.builder(
              itemCount: 9,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
              itemBuilder: (_, i) => buildCell(i),
            ),
          )
        ],
      ),
    );
  }
}
