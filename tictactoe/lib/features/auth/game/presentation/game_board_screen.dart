import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GameBoardScreen extends StatefulWidget {
  final String username;
  final String opponent;
  final String opponentEmail;
  final String opponentUid;
  final String symbol;
  final String gameId;
  final Duration timeControl;

  const GameBoardScreen({
    Key? key,
    required this.username,
    required this.opponent,
    required this.opponentEmail,
    required this.opponentUid,
    required this.symbol,
    required this.gameId,
    this.timeControl = const Duration(minutes: 5),
  }) : super(key: key);

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  late List<String> board;
  List<String> moveHistory = [];
  late String currentTurn;
  StreamSubscription<DocumentSnapshot>? _roomSub;

  String? winner;
  bool isMyTurn = false;
  bool gameEnded = false;
  bool opponentDisconnected = false;
  int disconnectSecondsLeft = 120;
  bool _snackBarShown = false;
  bool _statsUpdateInProgress = false;

  late Duration myTime;
  late Duration opponentTime;
  late final Ticker myTicker;
  late final Ticker opponentTicker;

  Timer? restartTimer;
  Timer? disconnectTimer;

  @override
  void initState() {
    super.initState();

    board = List.filled(9, '');
    currentTurn = 'X';
    isMyTurn = (widget.symbol == currentTurn);

    myTime = widget.timeControl;
    opponentTime = widget.timeControl;

   myTicker = Ticker(() {
  if (!gameEnded && isMyTurn && mounted) {
    if (myTime.inSeconds > 0) {
      setState(() => myTime -= const Duration(seconds: 1));
    } else {
      _endGame(lost: true);
    }
  }
});

opponentTicker = Ticker(() {
  if (!gameEnded && !isMyTurn && mounted && !opponentDisconnected) {
    if (opponentTime.inSeconds > 0) {
      setState(() => opponentTime -= const Duration(seconds: 1));
    } else {
      _endGame(lost: false);
    }
  }
});


    myTicker.start();
    opponentTicker.start();

    // Add Firestore listener for real-time board updates
    _roomSub = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.gameId)
        .snapshots()
        .listen(_onRoomUpdate);
  }

  void _onRoomUpdate(DocumentSnapshot doc) async {
    if (!doc.exists) {
      // Room deleted (opponent left or game ended)
      if (mounted) {
        Future.microtask(() async {
          if (_snackBarShown) return;
          _snackBarShown = true;
          while (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
            await Future.delayed(const Duration(milliseconds: 10));
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Game ended or opponent left.')),
            );
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/home', (route) => false);
          }
        });
      }
      return;
    }
    final data = doc.data() as Map<String, dynamic>;
    // Check for status ended/cancelled
    final status = data['status'];
    if (status == 'ended' || status == 'cancelled') {
      if (mounted) {
        Future.microtask(() async {
          if (_snackBarShown) return;
          _snackBarShown = true;
          while (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
            await Future.delayed(const Duration(milliseconds: 10));
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Game ended or cancelled.')),
            );
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/home', (route) => false);
          }
        });
      }
      return;
    }
    final rawRematch = data['rematchRequest'];
    final Map<String, dynamic>? rematch = rawRematch != null
    ? Map<String, dynamic>.from(rawRematch as Map<dynamic, dynamic>)
    : null;


    if (rematch != null &&
        rematch['to'] == FirebaseAuth.instance.currentUser?.uid &&
        rematch['status'] == 'pending') {
      _showRematchRequestDialog(); // receiver sees popup
    }

   if (rematch != null && rematch['status'] == 'accepted') {
  final newBoard = List.filled(9, '');
  final int minutes =
      rematch['timeControlMinutes'] ?? (data['timeControlMinutes'] ?? 5);
  final newTimeControl = Duration(minutes: minutes);

  await FirebaseFirestore.instance.collection('rooms').doc(widget.gameId).update({
    'board': newBoard,
    'currentTurn': 'X',
    'winner': '',
    'moveHistory': [],
    'rematchRequest': FieldValue.delete(),
    'status': 'active',
    'timeControlMinutes': minutes,
  });

  if (mounted) {
    setState(() {
      board = newBoard;
      currentTurn = 'X';
      winner = null;
      moveHistory.clear();
      gameEnded = false;
      isMyTurn = (widget.symbol == 'X');
      myTime = newTimeControl;
      opponentTime = newTimeControl;
    });

    // Reset tickers
    myTicker.pause();
    opponentTicker.pause();
    if (isMyTurn) {
      myTicker.start();
    } else {
      opponentTicker.start();
    }
  }
}

    if (rematch != null && rematch['status'] == 'declined') {
  // Clear rematchRequest field
  await FirebaseFirestore.instance
      .collection('rooms')
      .doc(widget.gameId)
      .update({'rematchRequest': FieldValue.delete()});

  // Navigate both players to lobby after showing alert
  Future.microtask(() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rematch Declined'),
        content: const Text('Opponent declined the rematch.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    }
  });
}


    setState(() {
      board = List<String>.from(data['board'] ?? List.filled(9, ''));
      currentTurn = data['currentTurn'] ?? 'X';
      isMyTurn = (currentTurn == widget.symbol);
      if (isMyTurn) {
  myTicker.start();
  opponentTicker.pause();
} else {
  opponentTicker.start();
  myTicker.pause();
}
      winner = data['winner'];
      gameEnded = winner != null && winner != '';
      moveHistory = List<String>.from(data['moveHistory'] ?? []);
    });

    // Robust win/loss update: only increment if not already updated for this user in this game
    if (gameEnded &&
        !_statsUpdateInProgress &&
        winner != null &&
        winner != '' &&
        winner != 'draw') {
      _statsUpdateInProgress = true;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);
        final roomRef = FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.gameId);
        final statsUpdated =
            (data['statsUpdated'] ?? {}) as Map<String, dynamic>;
        if (statsUpdated[user.uid] != true) {
          try {
            if (winner == widget.symbol) {
              await userRef.update({'wins': FieldValue.increment(1)});
            } else {
              await userRef.update({'losses': FieldValue.increment(1)});
            }
            // Mark as updated in Firestore
            await roomRef.update({'statsUpdated.${user.uid}': true});
          } catch (e) {
            // If update fails, allow retry on next update
            _statsUpdateInProgress = false;
          }
        }
      }
    }
  }

  void _endGame({required bool lost}) {
    setState(() {
      winner = lost ? (widget.symbol == 'X' ? 'O' : 'X') : widget.symbol;
      gameEnded = true;
    });
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

  void _showRematchWaitingDialog() {
    int secondsLeft = 30;
    Timer? countdownTimer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (mounted) {
            setState(() => secondsLeft--);
            if (secondsLeft <= 0) {
              Navigator.of(context).pop();
              t.cancel();
            }
          }
        });

        return StatefulBuilder(
          builder:
              (context, setState) => AlertDialog(
                title: const Text('Waiting for opponent...'),
                content: Text(
                  'Rematch request sent.\nExpires in $secondsLeft seconds.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      countdownTimer?.cancel();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
        );
      },
    ).then((_) => countdownTimer?.cancel());
  }

void _showRematchRequestDialog() {
  int secondsLeft = 30;
  Timer? countdown;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          countdown ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (mounted) {
              setState(() {
                secondsLeft--;
              });
              if (secondsLeft <= 0) {
                FirebaseFirestore.instance
                    .collection('rooms')
                    .doc(widget.gameId)
                    .update({'rematchRequest.status': 'declined'});
                Navigator.of(context).pop();
                t.cancel();
              }
            }
          });

          return AlertDialog(
            title: const Text('Rematch Requested'),
            content: Text(
              'Do you accept the rematch?\nExpires in $secondsLeft seconds.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  FirebaseFirestore.instance
                      .collection('rooms')
                      .doc(widget.gameId)
                      .update({'rematchRequest.status': 'declined'});
                  countdown?.cancel();
                  Navigator.of(context).pop();
                },
                child: const Text('Decline'),
              ),
              ElevatedButton(
                onPressed: () {
                  FirebaseFirestore.instance
                      .collection('rooms')
                      .doc(widget.gameId)
                      .update({'rematchRequest.status': 'accepted'});
                  countdown?.cancel();
                  Navigator.of(context).pop();
                },
                child: const Text('Accept'),
              ),
            ],
          );
        },
      );
    },
  ).then((_) => countdown?.cancel());
}


  void _onRestartPressed() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => AlertDialog(
            title: const Text('Rematch Requested'),
            content: const Text('Waiting for opponent to accept…'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  void _showDeclinedDialog() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
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

  void _showDisconnectedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => AlertDialog(
            title: const Text('Opponent Disconnected'),
            content: const Text(
              'Opponent did not return in 2 minutes. You win!',
            ),
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

  void _showQuitDialog() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Quit Game?'),
            content: const Text(
              'Are you sure you want to quit? You will forfeit this match.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  print('[QUIT] Quit button pressed');
                  Navigator.of(context).pop();
                  final opponentSymbol = widget.symbol == 'X' ? 'O' : 'X';
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    final userRef = FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid);
                    final roomRef = FirebaseFirestore.instance
                        .collection('rooms')
                        .doc(widget.gameId);
                    try {
                      print('[QUIT] Updating room winner and gameEndedBy');
                      await roomRef.update({
                        'winner': opponentSymbol,
                        'gameEndedBy': widget.username,
                      });
                    } catch (e) {
                      print('[QUIT][ERROR] Failed to update room: $e');
                    }
                    try {
                      print('[QUIT] Deleting invites for this room');
                      final invites =
                          await FirebaseFirestore.instance
                              .collection('invites')
                              .where('roomId', isEqualTo: widget.gameId)
                              .get();
                      for (final doc in invites.docs) {
                        await doc.reference.delete();
                      }
                    } catch (e) {
                      print('[QUIT][ERROR] Failed to delete invites: $e');
                    }
                    try {
                      print('[QUIT] Updating stats if needed');
                      final roomSnap = await roomRef.get();
                      final data = roomSnap.data();
                      if (data != null) {
                        final statsUpdated =
                            (data['statsUpdated'] ?? {})
                                as Map<String, dynamic>;
                        if (statsUpdated[user.uid] != true) {
                          try {
                            if (opponentSymbol == widget.symbol) {
                              await userRef.update({
                                'wins': FieldValue.increment(1),
                              });
                            } else {
                              await userRef.update({
                                'losses': FieldValue.increment(1),
                              });
                            }
                            await roomRef.update({
                              'statsUpdated.${user.uid}': true,
                            });
                          } catch (e) {
                            print('[QUIT][ERROR] Failed to update stats: $e');
                          }
                        }
                      }
                    } catch (e) {
                      print(
                        '[QUIT][ERROR] Failed to get room or update stats: $e',
                      );
                    }
                    try {
                      print('[QUIT] Waiting 2 seconds before deleting room');
                      await Future.delayed(const Duration(seconds: 2));
                      print('[QUIT] Deleting room');
                      await roomRef.delete();
                    } catch (e) {
                      print('[QUIT][ERROR] Failed to delete room: $e');
                    }
                    if (mounted) {
                      print('[QUIT] Navigating to home/lobby');
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/home', (route) => false);
                    }
                  } else {
                    print('[QUIT][ERROR] No user found');
                  }
                },
                child: const Text('Quit', style: TextStyle(color: Colors.red)),
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
    _roomSub?.cancel();
    super.dispose();
  }

  void _makeMove(int idx) async {
    if (board[idx] == '' && isMyTurn && (winner == null || winner == '')) {
      final newBoard = List<String>.from(board);
      newBoard[idx] = widget.symbol;
      final nextTurn = widget.symbol == 'X' ? 'O' : 'X';
      final win = _checkWinner(newBoard);
      final move = '${widget.symbol} -> ${_cellName(idx)}';
      final newMoveHistory = List<String>.from(moveHistory)..add(move);
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.gameId)
          .update({
            'board': newBoard,
            'currentTurn': nextTurn,
            'winner': win ?? '',
            'moveHistory': newMoveHistory,
          });
      // Local state will update via Firestore listener
    }
  }

  String? _checkWinner(List<String> b) {
    const wins = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ];
    for (var line in wins) {
      final a = line[0], b1 = line[1], c = line[2];
      if (b[a] != '' && b[a] == b[b1] && b[a] == b[c]) {
        return b[a];
      }
    }
    if (!b.contains('')) return 'draw';
    return null;
  }

  String _cellName(int idx) {
    // Returns a human-readable cell name, e.g. A1, B2, etc.
    final row = idx ~/ 3;
    final col = idx % 3;
    final rowChar = String.fromCharCode('A'.codeUnitAt(0) + row);
    return '$rowChar${col + 1}';
  }

  Widget _buildCell(int i) {
    final color =
        board[i] == 'X'
            ? Colors.deepPurple
            : board[i] == 'O'
            ? Colors.pink
            : Colors.grey.shade300;

    return GestureDetector(
      onTap: () => _makeMove(i),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          border: Border.all(color: Colors.black26),
        ),
        child: Center(
          child: Text(
            board[i],
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _gameStatus() {
    if (opponentDisconnected && !gameEnded) {
      return Text(
        "Opponent disconnected… $disconnectSecondsLeft s",
        style: const TextStyle(fontSize: 18, color: Colors.red),
      );
    }
    if (winner == widget.symbol) {
      return const Text("🎉 You won!", style: TextStyle(fontSize: 22));
    } else if (winner == 'draw') {
      return const Text("It's a draw 🤝", style: TextStyle(fontSize: 22));
    } else if (winner != null && winner != '' && winner != 'draw') {
      return const Text("You lost 💔", style: TextStyle(fontSize: 22));
    }
    if (isMyTurn) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow, color: Colors.green, size: 28),
            const SizedBox(width: 8),
            Text(
              'Your turn (${widget.symbol})',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_empty, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            Text(
              "Waiting for opponent...",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildTimers() {
    String fmt(Duration d) =>
        '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(
          children: [
            const Text('Your time'),
            Text(
              fmt(myTime),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Column(
          children: [
            const Text('Opponent time'),
            Text(
              fmt(opponentTime),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  void _showHistory() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Move History'),
            content: SizedBox(
              width: double.maxFinite,
              child:
                  moveHistory.isEmpty
                      ? const Text('No moves yet.')
                      : ListView.builder(
                        shrinkWrap: true,
                        itemCount: moveHistory.length,
                        itemBuilder:
                            (_, i) => ListTile(title: Text(moveHistory[i])),
                      ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent system back navigation
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Tic Tac Toe"),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.exit_to_app, color: Colors.red),
              tooltip: 'Quit Game',
              onPressed: _showQuitDialog,
            ),
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: _showHistory,
            ),
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
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                  ),
                  itemBuilder: (_, i) => _buildCell(i),
                ),
              ),
              if (gameEnded && winner != null && winner != '')
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Rematch'),
                    onPressed: () async {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        await FirebaseFirestore.instance
                            .collection('rooms')
                            .doc(widget.gameId)
                            .update({
                              'rematchRequest': {
                                'from': user.uid,
                                'to': widget.opponentUid,
                                'status': 'pending',
                                'timeControlMinutes': widget.timeControl.inMinutes,
                              },
                            });
                        _showRematchWaitingDialog();
                      }
                    },
                  ),
                ),

              if (gameEnded && winner == 'draw')
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Rematch'),
                    onPressed: () async {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        await FirebaseFirestore.instance
                            .collection('rooms')
                            .doc(widget.gameId)
                            .update({
                              'rematchRequest': {
                                'from': user.uid,
                                'to': widget.opponentUid,
                                'status': 'pending',
                              },
                            });
                        _showRematchWaitingDialog();
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class Ticker {
  final void Function() onTick;
  Timer? _timer;

  Ticker(this.onTick);

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => onTick());
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    pause();
  }
}

class CountdownText extends StatefulWidget {
  final int seconds;
  final String text;
  const CountdownText({Key? key, required this.seconds, required this.text})
    : super(key: key);

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
    return Text(
      '${widget.text}: $secondsLeft',
      style: const TextStyle(fontSize: 16),
    );
  }
}
