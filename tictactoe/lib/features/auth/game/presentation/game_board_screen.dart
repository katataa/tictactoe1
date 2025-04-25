import 'dart:async';

import 'package:flutter/material.dart';
import '../data/websocket_service.dart';

class GameBoardScreen extends StatefulWidget {
  final String username;
  final String opponent;
  final String symbol;
  final String gameId;
  final WebSocketService socket;
  final Duration timeControl;

  const GameBoardScreen({
    super.key,
    required this.username,
    required this.opponent,
    required this.symbol,
    required this.gameId,
    required this.socket,
    this.timeControl = const Duration(minutes: 5),
  });

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  List<String> board = List.filled(9, '');
  List<String> moveHistory = [];
  String currentTurn = 'X';
  String? winner;
  bool isMyTurn = false;

  late Duration myTime;
  late Duration opponentTime;
  late final Ticker myTicker;
  late final Ticker opponentTicker;

  @override
  void initState() {
    super.initState();
    widget.socket.joinGame(widget.gameId, widget.symbol);

    myTime = widget.timeControl;
    opponentTime = widget.timeControl;

    myTicker = Ticker((_) {
      if (isMyTurn && mounted && myTime.inSeconds > 0) {
        setState(() => myTime -= const Duration(seconds: 1));
      }
    });

    opponentTicker = Ticker((_) {
      if (!isMyTurn && mounted && opponentTime.inSeconds > 0) {
        setState(() => opponentTime -= const Duration(seconds: 1));
      }
    });

    widget.socket.onMessage = (msg) {
      switch (msg['type']) {
        case 'move':
          setState(() {
            board = List<String>.from(msg['board']);
            currentTurn = msg['nextTurn'];
            winner = msg['winner'];
            moveHistory.add('${msg['by']} -> ${msg['cell']}');
            isMyTurn = currentTurn == widget.symbol;
          });
          break;

        case 'restart_prompt':
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Restart Requested'),
              content: const Text('Opponent wants to restart the game. Accept?'),
              actions: [
                TextButton(
                  onPressed: () {
                    widget.socket.acceptRestart();
                    Navigator.pop(context);
                  },
                  child: const Text('Yes'),
                ),
              ],
            ),
          );
          break;

        case 'restart_confirmed':
          setState(() {
            board = List.filled(9, '');
            currentTurn = 'X';
            winner = null;
            moveHistory.clear();
            isMyTurn = widget.symbol == 'X';
            myTime = widget.timeControl;
            opponentTime = widget.timeControl;
          });
          break;

        case 'disconnect_timeout':
          setState(() => winner = msg['winner']);
          break;
      }
    };

    isMyTurn = widget.symbol == 'X';
    myTicker.start();
    opponentTicker.start();
  }

  @override
  void dispose() {
    myTicker.dispose();
    opponentTicker.dispose();
    widget.socket.disconnect();
    super.dispose();
  }

  void makeMove(int index) {
    if (board[index] == '' && isMyTurn && winner == null) {
      widget.socket.sendMove(index);
      setState(() => isMyTurn = false);
    }
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

  Widget gameStatus() {
    if (winner == widget.symbol) {
      return const Text("🎉 You won!", style: TextStyle(fontSize: 22));
    } else if (winner == 'draw') {
      return const Text("It's a draw 🤝", style: TextStyle(fontSize: 22));
    } else if (winner != null) {
      return const Text("You lost 💔", style: TextStyle(fontSize: 22));
    } else {
      return Text(
        isMyTurn ? "Your turn (${widget.symbol})" : "${widget.opponent}'s turn",
        style: const TextStyle(fontSize: 18),
      );
    }
  }

  Widget buildTimers() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              const Text('You'),
              Text('${myTime.inMinutes}:${(myTime.inSeconds % 60).toString().padLeft(2, '0')}'),
            ],
          ),
          Column(
            children: [
              Text(widget.opponent),
              Text('${opponentTime.inMinutes}:${(opponentTime.inSeconds % 60).toString().padLeft(2, '0')}'),
            ],
          )
        ],
      );

  Widget buildMoveHistory() => Container(
        width: 150,
        color: Colors.grey.shade100,
        padding: const EdgeInsets.all(8),
        child: ListView.builder(
          itemCount: moveHistory.length,
          itemBuilder: (_, i) => Text(moveHistory[i]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tic Tac Toe"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: winner != null ? widget.socket.requestRestart : null,
          )
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                gameStatus(),
                const SizedBox(height: 16),
                buildTimers(),
                const SizedBox(height: 16),
                AspectRatio(
                  aspectRatio: 1,
                  child: GridView.builder(
                    itemCount: 9,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
                    itemBuilder: (_, i) => buildCell(i),
                  ),
                ),
              ],
            ),
          ),
          buildMoveHistory(),
        ],
      ),
    );
  }
}

class Ticker {
  final void Function(Duration) onTick;
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  Ticker(this.onTick);

  void start() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsed += const Duration(seconds: 1);
      onTick(_elapsed);
    });
  }

  void dispose() {
    _timer?.cancel();
  }
}