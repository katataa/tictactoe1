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
  String currentTurn = 'X';
  String? winner;
  bool isMyTurn = false;
  bool gameEnded = false;

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
      if (!gameEnded && isMyTurn && mounted && myTime.inSeconds > 0) {
        setState(() => myTime -= const Duration(seconds: 1));
      }
    });

    opponentTicker = Ticker((_) {
      if (!gameEnded && !isMyTurn && mounted && opponentTime.inSeconds > 0) {
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
            isMyTurn = currentTurn == widget.symbol;
            if (winner != null) {
              gameEnded = true;
            }
          });
          break;

        case 'restart_prompt':
          if (!mounted) return;
          if (widget.symbol == 'O') {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Rematch Requested'),
                content: const Text('Opponent wants to rematch. Accept?'),
                actions: [
                  TextButton(
                    onPressed: () {
                      widget.socket.acceptRestart();
                      Navigator.pop(context);
                    },
                    child: const Text('Yes'),
                  ),
                  TextButton(
                    onPressed: () {
                      widget.socket.declineRestart();
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    child: const Text('No'),
                  ),
                ],
              ),
            );
          }
          break;

        case 'restart_confirmed':
          setState(() {
            board = List.filled(9, '');
            currentTurn = 'X';
            winner = null;
            isMyTurn = widget.symbol == 'X';
            myTime = widget.timeControl;
            opponentTime = widget.timeControl;
            gameEnded = false;
          });
          break;

        case 'restart_declined':
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Rematch Declined'),
              content: const Text('Opponent declined rematch. Returning to lobby...'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          break;

        case 'disconnect_timeout':
          setState(() => winner = msg['winner']);
          gameEnded = true;
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

  void confirmBackToLobby() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave Game?'),
        content: const Text('Are you sure you want to go back to the lobby?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
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

  Widget buildTimer() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Your time'),
          Text(
            '${myTime.inMinutes}:${(myTime.inSeconds % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tic Tac Toe"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: confirmBackToLobby,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: winner != null ? widget.socket.requestRestart : null,
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            gameStatus(),
            const SizedBox(height: 16),
            buildTimer(),
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
