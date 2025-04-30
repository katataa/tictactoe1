// lib/features/game/presentation/game_board_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/websocket_service.dart';

class GameBoardScreen extends StatefulWidget {
  final String username;
  final String opponent;
  final String symbol;
  final String gameId;
  final WebSocketService socket;
  final Duration timeControl;

  const GameBoardScreen({
    Key? key,
    required this.username,
    required this.opponent,
    required this.symbol,
    required this.gameId,
    required this.socket,
    this.timeControl = const Duration(minutes: 5),
  }) : super(key: key);

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  late List<String> board;
  List<String> moveHistory = [];
  late String currentTurn;

  String? winner;
  bool isMyTurn = false;
  bool gameEnded = false;
  bool opponentDisconnected = false;
  int disconnectSecondsLeft = 120;

  late Duration myTime;
  late Duration opponentTime;
  late final Ticker myTicker;
  late final Ticker opponentTicker;

  Timer? restartTimer;
  Timer? disconnectTimer;

  @override
  void initState() {
    super.initState();

    widget.socket.joinGame(widget.gameId, widget.symbol); // ✅ passes both



    board = List.filled(9, '');
    currentTurn = 'X';
    isMyTurn = (widget.symbol == currentTurn);

    myTime = widget.timeControl;
    opponentTime = widget.timeControl;

    myTicker = Ticker((_) {
      if (!gameEnded && isMyTurn && mounted) {
        if (myTime.inSeconds > 0) {
          setState(() => myTime -= const Duration(seconds: 1));
        } else {
          _endGame(lost: true);
        }
      }
    });

    opponentTicker = Ticker((_) {
      if (!gameEnded && !isMyTurn && mounted && !opponentDisconnected) {
        if (opponentTime.inSeconds > 0) {
          setState(() => opponentTime -= const Duration(seconds: 1));
        } else {
          _endGame(lost: false);
        }
      }
    });

    widget.socket.onMessage = _handleMessage;

    myTicker.start();
    opponentTicker.start();
  }

  void _handleMessage(Map<String, dynamic> msg) {
    if (!mounted) return;
    switch (msg['type']) {
      case 'move':
        setState(() {
          board = List<String>.from(msg['board']);
          moveHistory.add('${msg['by']} → cell ${msg['cell']}');
          currentTurn = msg['nextTurn'];
          winner = msg['winner'];
          isMyTurn = (currentTurn == widget.symbol);
          if (winner != null && !gameEnded) {
            gameEnded = true;
            _persistStats();
          }
        });
        break;

      case 'restart_prompt':
        _showRestartDialog();
        break;

      case 'restart_confirmed':
        _restartGame();
        break;

      case 'restart_declined':
        _showDeclinedDialog();
        break;

      case 'player_left':
  if (!gameEnded) {
    if (msg['voluntary'] == true) {
      _endGame(lost: false); // you win
      _persistStats();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Opponent Left'),
          content: const Text('Your opponent left the match. You win!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      _handlePlayerLeft(); // fallback disconnect countdown
    }
  }
  break;


      case 'disconnect_timeout':
        if (!gameEnded) _showDisconnectedDialog();
        break;
    }
  }

  Future<void> _persistStats() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final usersRef = FirebaseFirestore.instance.collection('users');
    final meDoc = usersRef.doc(me.uid);

    final q = await usersRef
        .where('username', isEqualTo: widget.opponent)
        .limit(1)
        .get();
    final oppUid = q.docs.isNotEmpty ? q.docs.first.id : null;

    if (winner == widget.symbol) {
      await meDoc.update({'wins': FieldValue.increment(1)});
      if (oppUid != null) {
        await usersRef.doc(oppUid).update({'losses': FieldValue.increment(1)});
      }
    } else if (winner != null && winner != 'draw') {
      await meDoc.update({'losses': FieldValue.increment(1)});
      if (oppUid != null) {
        await usersRef.doc(oppUid).update({'wins': FieldValue.increment(1)});
      }
    }
  }

  void _endGame({required bool lost}) {
    setState(() {
      winner = lost
          ? (widget.symbol == 'X' ? 'O' : 'X')
          : widget.symbol;
      gameEnded = true;
    });
    _persistStats();
  }

  void _restartGame() {
    setState(() {
      board = List.filled(9, '');
      moveHistory.clear();
      currentTurn = 'X';
      winner = null;
      isMyTurn = (widget.symbol == 'X');
      myTime = widget.timeControl;
      opponentTime = widget.timeControl;
      gameEnded = false;
      opponentDisconnected = false;
    });
    restartTimer?.cancel();
  }

  void _showRestartDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Rematch Requested'),
        content: CountdownText(seconds: 30, text: 'Accept within'),
        actions: [
          TextButton(
            onPressed: () {
              widget.socket.acceptRestart();
              Navigator.of(context).pop();
            },
            child: const Text('Accept'),
          ),
          TextButton(
            onPressed: () {
              widget.socket.declineRestart();
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    restartTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      }
    });
  }

  void _showDeclinedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rematch Declined'),
        content: const Text('Opponent declined. Returning to lobby...'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handlePlayerLeft() {
  if (gameEnded) return;

  setState(() {
    winner = widget.symbol; // you win!
    gameEnded = true;
    opponentDisconnected = false; // not a network issue
  });

  _persistStats(); // record win

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: const Text('Opponent Left'),
      content: const Text('Your opponent left the game. You win!'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // close dialog
            Navigator.of(context).pop(); // back to lobby
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}


  void _showDisconnectedDialog() {
    _persistStats();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Opponent Disconnected'),
        content: const Text('Opponent did not return in 2 minutes. You win!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _confirmBack() {
  if (gameEnded) {
    widget.socket.leaveGame();
    Navigator.of(context).pop();
    return;
  }

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Leave Game?'),
      content: const Text('Are you sure? You will forfeit this match.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            widget.socket.leaveGame();
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
          child: const Text('Leave'),
        ),
      ],
    ),
  );
}


  @override
  void dispose() {
    myTicker.dispose();
    opponentTicker.dispose();
    restartTimer?.cancel();
    disconnectTimer?.cancel();
    super.dispose();
  }

  void _makeMove(int idx) {
    if (board[idx] == '' && isMyTurn && winner == null) {
      widget.socket.sendMove(idx);
      setState(() => isMyTurn = false);
    }
  }

  Widget _buildCell(int i) {
    final color = board[i] == 'X'
        ? Colors.deepPurple
        : board[i] == 'O'
            ? Colors.pink
            : Colors.grey.shade300;

    return GestureDetector(
      onTap: () => _makeMove(i),
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
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gameStatus() {
    if (opponentDisconnected && !gameEnded) {
      return Text("Opponent disconnected… $disconnectSecondsLeft s",
          style: const TextStyle(fontSize: 18, color: Colors.red));
    }
    if (winner == widget.symbol) {
      return const Text("🎉 You won!", style: TextStyle(fontSize: 22));
    } else if (winner == 'draw') {
      return const Text("It's a draw 🤝", style: TextStyle(fontSize: 22));
    } else if (winner != null) {
      return const Text("You lost 💔", style: TextStyle(fontSize: 22));
    }
    return Text(
      isMyTurn ? "Your turn (${widget.symbol})" : "${widget.opponent}'s turn",
      style: const TextStyle(fontSize: 18),
    );
  }

  Widget _buildTimers() {
    String fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(children: [const Text('Your time'), Text(fmt(myTime), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))]),
        Column(children: [const Text('Opponent time'), Text(fmt(opponentTime), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))]),
      ],
    );
  }

  void _showHistory() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Move History'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: moveHistory.length,
            itemBuilder: (_, i) => ListTile(title: Text(moveHistory[i])),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tic Tac Toe"),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _confirmBack),
        actions: [
          IconButton(icon: const Icon(Icons.history), onPressed: _showHistory),
          IconButton(icon: const Icon(Icons.refresh), onPressed: winner != null ? () => widget.socket.requestRestart() : null),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _gameStatus(),
            const SizedBox(height: 16),
            _buildTimers(),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1,
              child: GridView.builder(
                itemCount: 9,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
                itemBuilder: (_, i) => _buildCell(i),
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
  void start() => _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        _elapsed += const Duration(seconds: 1);
        onTick(_elapsed);
      });
  void dispose() => _timer?.cancel();
}

class CountdownText extends StatefulWidget {
  final int seconds;
  final String text;
  const CountdownText({Key? key, required this.seconds, required this.text}) : super(key: key);

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  late int secondsLeft;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    secondsLeft = widget.seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || secondsLeft <= 0) {
        t.cancel();
      } else {
        setState(() => secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text('${widget.text}: $secondsLeft', style: const TextStyle(fontSize: 16));
  }
}
