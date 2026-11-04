enum GameCategory {
  turnBased,
  realTimePhysics,
}

enum GameType {
  // Category A: Turn-based
  ticTacToe(
    id: 'tic_tac_toe',
    title: 'Tic Tac Toe',
    category: GameCategory.turnBased,
    maxPlayers: 2,
    description: 'Classic 3x3 strategic battle with 15s turn timer',
    iconName: 'grid_3x3',
  ),
  snakesAndLadders(
    id: 'snakes_and_ladders',
    title: 'Snakes & Ladders',
    category: GameCategory.turnBased,
    maxPlayers: 4,
    description: '100-tile race with 3D dice and obstacle climbs',
    iconName: 'stairs',
  ),
  ludo(
    id: 'ludo',
    title: 'Ludo Party',
    category: GameCategory.turnBased,
    maxPlayers: 4,
    description: '4-Player royal board duel with captures and safe zones',
    iconName: 'casino',
  ),
  bowling(
    id: 'bowling',
    title: 'Arcade Bowling',
    category: GameCategory.turnBased,
    maxPlayers: 2,
    description: 'Swipe-velocity vector throw with 10-pin physics',
    iconName: 'sports_baseball',
  ),

  // Category B: High-Tick Real-Time
  flappyBird(
    id: 'flappy_bird',
    title: 'Flappy Bird Live',
    category: GameCategory.realTimePhysics,
    maxPlayers: 2,
    description: 'Seeded pipe obstacles with live ghost opponent',
    iconName: 'flight',
  ),
  tableTennis(
    id: 'table_tennis',
    title: 'Table Tennis 2.5D',
    category: GameCategory.realTimePhysics,
    maxPlayers: 2,
    description: 'Isometric perspective with ping-compensated paddle curve',
    iconName: 'sports_tennis',
  ),
  airHockey(
    id: 'air_hockey',
    title: 'Air Hockey Duel',
    category: GameCategory.realTimePhysics,
    maxPlayers: 2,
    description: '60 FPS rigid puck physics with dead-reckoning interpolation',
    iconName: 'sports_hockey',
  ),
  stickFootball(
    id: 'stick_football',
    title: 'Stick Football',
    category: GameCategory.realTimePhysics,
    maxPlayers: 2,
    description: 'Turn-based slingshot flick soccer with impulse physics',
    iconName: 'sports_soccer',
  ),
  stackAnimals(
    id: 'stack_animals',
    title: 'Stack Animals',
    category: GameCategory.realTimePhysics,
    maxPlayers: 2,
    description: 'Physics balance crane drop with center-of-mass collapse',
    iconName: 'layers',
  ),
  bananaMonkey(
    id: 'banana_monkey',
    title: 'Banana Monkey',
    category: GameCategory.realTimePhysics,
    maxPlayers: 2,
    description: 'Speed-escalating falling item catcher with live duel score',
    iconName: 'pets',
  ),
  colorRush(
    id: 'color_rush',
    title: 'Color Rush',
    category: GameCategory.realTimePhysics,
    maxPlayers: 2,
    description: 'Stroop effect rapid reaction with millisecond scoring',
    iconName: 'palette',
  ),
  streetDash(
    id: 'street_dash',
    title: 'Street Dash',
    category: GameCategory.realTimePhysics,
    maxPlayers: 2,
    description: '3-lane endless runner with deterministic obstacles',
    iconName: 'directions_run',
  );

  final String id;
  final String title;
  final GameCategory category;
  final int maxPlayers;
  final String description;
  final String iconName;

  const GameType({
    required this.id,
    required this.title,
    required this.category,
    required this.maxPlayers,
    required this.description,
    required this.iconName,
  });

  static GameType fromId(String id) {
    return GameType.values.firstWhere(
      (e) => e.id == id,
      orElse: () => GameType.ludo,
    );
  }
}

