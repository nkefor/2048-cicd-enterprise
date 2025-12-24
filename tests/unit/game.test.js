/**
 * Unit tests for 2048 Game Logic
 */

const Game2048 = require('../../2048/www/js/game.js');

describe('Game2048 - Initialization', () => {
  test('should initialize with 4x4 board by default', () => {
    const game = new Game2048();
    expect(game.size).toBe(4);
    expect(game.board.length).toBe(4);
    expect(game.board[0].length).toBe(4);
  });

  test('should initialize with custom board size', () => {
    const game = new Game2048(5);
    expect(game.size).toBe(5);
    expect(game.board.length).toBe(5);
  });

  test('should start with score of 0', () => {
    const game = new Game2048();
    expect(game.getScore()).toBe(0);
  });

  test('should not be won or over at start', () => {
    const game = new Game2048();
    expect(game.isWon()).toBe(false);
    expect(game.isOver()).toBe(false);
  });

  test('should have exactly 2 tiles after initialization', () => {
    const game = new Game2048();
    let tileCount = 0;
    for (let row = 0; row < game.size; row++) {
      for (let col = 0; col < game.size; col++) {
        if (game.board[row][col] !== 0) {
          tileCount++;
        }
      }
    }
    expect(tileCount).toBe(2);
  });

  test('should only have 2 or 4 value tiles at start', () => {
    const game = new Game2048();
    for (let row = 0; row < game.size; row++) {
      for (let col = 0; col < game.size; col++) {
        const value = game.board[row][col];
        if (value !== 0) {
          expect([2, 4]).toContain(value);
        }
      }
    }
  });
});

describe('Game2048 - Board Operations', () => {
  test('should get board copy, not reference', () => {
    const game = new Game2048();
    const board1 = game.getBoard();
    const board2 = game.getBoard();

    expect(board1).toEqual(board2);
    expect(board1).not.toBe(board2);
  });

  test('should set board state correctly', () => {
    const game = new Game2048();
    const testBoard = [
      [2, 0, 0, 0],
      [0, 4, 0, 0],
      [0, 0, 8, 0],
      [0, 0, 0, 16]
    ];
    game.setBoard(testBoard);
    expect(game.getBoard()).toEqual(testBoard);
  });

  test('should throw error for invalid board size', () => {
    const game = new Game2048();
    const invalidBoard = [[2, 4], [8, 16]];
    expect(() => game.setBoard(invalidBoard)).toThrow();
  });

  test('should get column correctly', () => {
    const game = new Game2048();
    game.setBoard([
      [1, 2, 3, 4],
      [5, 6, 7, 8],
      [9, 10, 11, 12],
      [13, 14, 15, 16]
    ]);
    expect(game.getColumn(0)).toEqual([1, 5, 9, 13]);
    expect(game.getColumn(1)).toEqual([2, 6, 10, 14]);
    expect(game.getColumn(3)).toEqual([4, 8, 12, 16]);
  });

  test('should set column correctly', () => {
    const game = new Game2048();
    game.setBoard([
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0]
    ]);
    game.setColumn(0, [1, 2, 3, 4]);
    expect(game.board[0][0]).toBe(1);
    expect(game.board[1][0]).toBe(2);
    expect(game.board[2][0]).toBe(3);
    expect(game.board[3][0]).toBe(4);
  });
});

describe('Game2048 - Tile Merging', () => {
  test('should merge two equal tiles', () => {
    const game = new Game2048();
    const result = game.mergeTiles([2, 2, 0, 0]);
    expect(result).toEqual([4, 0, 0, 0]);
  });

  test('should merge multiple pairs', () => {
    const game = new Game2048();
    const result = game.mergeTiles([2, 2, 4, 4]);
    expect(result).toEqual([4, 8, 0, 0]);
  });

  test('should not merge different tiles', () => {
    const game = new Game2048();
    const result = game.mergeTiles([2, 4, 0, 0]);
    expect(result).toEqual([2, 4, 0, 0]);
  });

  test('should merge only once per move', () => {
    const game = new Game2048();
    const result = game.mergeTiles([2, 2, 2, 0]);
    expect(result).toEqual([4, 2, 0, 0]);
  });

  test('should compact tiles to the left', () => {
    const game = new Game2048();
    const result = game.mergeTiles([0, 2, 0, 4]);
    expect(result).toEqual([2, 4, 0, 0]);
  });

  test('should handle all zeros', () => {
    const game = new Game2048();
    const result = game.mergeTiles([0, 0, 0, 0]);
    expect(result).toEqual([0, 0, 0, 0]);
  });

  test('should update score when merging', () => {
    const game = new Game2048();
    game.setScore(0);
    game.mergeTiles([2, 2, 0, 0]);
    expect(game.getScore()).toBe(4);
  });

  test('should add correct score for multiple merges', () => {
    const game = new Game2048();
    game.setScore(0);
    game.mergeTiles([2, 2, 4, 4]);
    expect(game.getScore()).toBe(12); // 4 + 8
  });
});

describe('Game2048 - Movement', () => {
  test('should move tiles left correctly', () => {
    const game = new Game2048();
    game.setBoard([
      [0, 2, 0, 0],
      [0, 0, 4, 0],
      [0, 0, 0, 8],
      [0, 0, 0, 0]
    ]);
    game.moveLeft();
    expect(game.board[0]).toEqual([2, 0, 0, 0]);
    expect(game.board[1]).toEqual([4, 0, 0, 0]);
    expect(game.board[2]).toEqual([8, 0, 0, 0]);
  });

  test('should move tiles right correctly', () => {
    const game = new Game2048();
    game.setBoard([
      [2, 0, 0, 0],
      [0, 4, 0, 0],
      [0, 0, 8, 0],
      [0, 0, 0, 0]
    ]);
    game.moveRight();
    expect(game.board[0]).toEqual([0, 0, 0, 2]);
    expect(game.board[1]).toEqual([0, 0, 0, 4]);
    expect(game.board[2]).toEqual([0, 0, 0, 8]);
  });

  test('should move tiles up correctly', () => {
    const game = new Game2048();
    game.setBoard([
      [0, 0, 0, 0],
      [2, 0, 0, 0],
      [0, 4, 0, 0],
      [0, 0, 8, 0]
    ]);
    game.moveUp();
    expect(game.getColumn(0)).toEqual([2, 0, 0, 0]);
    expect(game.getColumn(1)).toEqual([4, 0, 0, 0]);
    expect(game.getColumn(2)).toEqual([8, 0, 0, 0]);
  });

  test('should move tiles down correctly', () => {
    const game = new Game2048();
    game.setBoard([
      [2, 0, 0, 0],
      [0, 4, 0, 0],
      [0, 0, 8, 0],
      [0, 0, 0, 0]
    ]);
    game.moveDown();
    expect(game.getColumn(0)).toEqual([0, 0, 0, 2]);
    expect(game.getColumn(1)).toEqual([0, 0, 0, 4]);
    expect(game.getColumn(2)).toEqual([0, 0, 0, 8]);
  });

  test('should merge tiles when moving left', () => {
    const game = new Game2048();
    game.setBoard([
      [2, 2, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0]
    ]);
    game.moveLeft();
    expect(game.board[0]).toEqual([4, 0, 0, 0]);
  });

  test('should merge tiles when moving right', () => {
    const game = new Game2048();
    game.setBoard([
      [0, 0, 2, 2],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0]
    ]);
    game.moveRight();
    expect(game.board[0]).toEqual([0, 0, 0, 4]);
  });

  test('should return true if board changed', () => {
    const game = new Game2048();
    game.setBoard([
      [2, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0]
    ]);
    const changed = game.move('right');
    expect(changed).toBe(true);
  });

  test('should return false if board did not change', () => {
    const game = new Game2048();
    game.setBoard([
      [2, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0]
    ]);
    const changed = game.move('left');
    expect(changed).toBe(false);
  });

  test('should handle invalid direction', () => {
    const game = new Game2048();
    const changed = game.move('invalid');
    expect(changed).toBe(false);
  });
});

describe('Game2048 - Random Tile Addition', () => {
  test('should add tile to empty cell', () => {
    const game = new Game2048();
    game.setBoard([
      [2, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0]
    ]);

    const added = game.addRandomTile();
    expect(added).toBe(true);

    // Count non-zero tiles
    let count = 0;
    for (let row = 0; row < game.size; row++) {
      for (let col = 0; col < game.size; col++) {
        if (game.board[row][col] !== 0) count++;
      }
    }
    expect(count).toBe(2);
  });

  test('should not add tile to full board', () => {
    const game = new Game2048();
    game.setBoard([
      [2, 4, 8, 16],
      [32, 64, 128, 256],
      [512, 1024, 2048, 4096],
      [8192, 16384, 32768, 65536]
    ]);

    const added = game.addRandomTile();
    expect(added).toBe(false);
  });

  test('should add tile with value 2 or 4', () => {
    const game = new Game2048();
    game.setBoard([
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0]
    ]);

    for (let i = 0; i < 10; i++) {
      game.addRandomTile();
    }

    for (let row = 0; row < game.size; row++) {
      for (let col = 0; col < game.size; col++) {
        const value = game.board[row][col];
        if (value !== 0) {
          expect([2, 4]).toContain(value);
        }
      }
    }
  });
});

describe('Game2048 - Win/Lose Conditions', () => {
  test('should detect win when 2048 tile exists', () => {
    const game = new Game2048();
    game.setBoard([
      [2048, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0]
    ]);
    game.checkWinCondition();
    expect(game.isWon()).toBe(true);
  });

  test('should not detect win without 2048 tile', () => {
    const game = new Game2048();
    game.setBoard([
      [1024, 512, 256, 128],
      [64, 32, 16, 8],
      [4, 2, 0, 0],
      [0, 0, 0, 0]
    ]);
    game.checkWinCondition();
    expect(game.isWon()).toBe(false);
  });

  test('should detect game over when no moves possible', () => {
    const game = new Game2048();
    game.setBoard([
      [2, 4, 8, 16],
      [16, 8, 4, 2],
      [2, 4, 8, 16],
      [16, 8, 4, 2]
    ]);
    game.checkGameOver();
    expect(game.isOver()).toBe(true);
  });

  test('should not detect game over when moves are possible', () => {
    const game = new Game2048();
    game.setBoard([
      [2, 2, 8, 16],
      [16, 8, 4, 2],
      [2, 4, 8, 16],
      [16, 8, 4, 2]
    ]);
    game.checkGameOver();
    expect(game.isOver()).toBe(false);
  });

  test('should not detect game over with empty cells', () => {
    const game = new Game2048();
    game.setBoard([
      [2, 4, 8, 16],
      [16, 8, 4, 2],
      [2, 4, 8, 0],
      [16, 8, 4, 2]
    ]);
    game.checkGameOver();
    expect(game.isOver()).toBe(false);
  });

  test('should detect moves available with empty cells', () => {
    const game = new Game2048();
    game.setBoard([
      [2, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0]
    ]);
    expect(game.canMove()).toBe(true);
  });

  test('should detect moves available with adjacent equal tiles', () => {
    const game = new Game2048();
    game.setBoard([
      [2, 2, 4, 8],
      [4, 8, 16, 32],
      [8, 16, 32, 64],
      [16, 32, 64, 128]
    ]);
    expect(game.canMove()).toBe(true);
  });

  test('should detect no moves available', () => {
    const game = new Game2048();
    game.setBoard([
      [2, 4, 8, 16],
      [16, 8, 4, 2],
      [2, 4, 8, 16],
      [16, 8, 4, 2]
    ]);
    expect(game.canMove()).toBe(false);
  });
});

describe('Game2048 - Score Tracking', () => {
  test('should increase score when tiles merge', () => {
    const game = new Game2048();
    game.setScore(0);
    game.setBoard([
      [2, 2, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0]
    ]);
    game.moveLeft();
    expect(game.getScore()).toBeGreaterThan(0);
  });

  test('should not increase score without merges', () => {
    const game = new Game2048();
    game.setScore(0);
    game.setBoard([
      [2, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0]
    ]);
    game.moveRight();
    expect(game.getScore()).toBe(0);
  });

  test('should accumulate score correctly', () => {
    const game = new Game2048();
    game.setScore(0);
    game.setBoard([
      [2, 2, 4, 4],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0]
    ]);
    game.moveLeft();
    expect(game.getScore()).toBe(12); // 4 + 8
  });
});

describe('Game2048 - Reset', () => {
  test('should reset game state', () => {
    const game = new Game2048();
    game.setScore(100);
    game.gameWon = true;
    game.gameOver = true;

    game.reset();

    expect(game.getScore()).toBe(0);
    expect(game.isWon()).toBe(false);
    expect(game.isOver()).toBe(false);
  });

  test('should have 2 tiles after reset', () => {
    const game = new Game2048();
    game.setBoard([
      [2, 4, 8, 16],
      [32, 64, 128, 256],
      [512, 1024, 0, 0],
      [0, 0, 0, 0]
    ]);

    game.reset();

    let count = 0;
    for (let row = 0; row < game.size; row++) {
      for (let col = 0; col < game.size; col++) {
        if (game.board[row][col] !== 0) count++;
      }
    }
    expect(count).toBe(2);
  });
});

describe('Game2048 - Board Equality', () => {
  test('should detect equal boards', () => {
    const game = new Game2048();
    const board1 = [
      [2, 4, 8, 16],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0]
    ];
    const board2 = [
      [2, 4, 8, 16],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0]
    ];
    expect(game.boardsEqual(board1, board2)).toBe(true);
  });

  test('should detect different boards', () => {
    const game = new Game2048();
    const board1 = [
      [2, 4, 8, 16],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0]
    ];
    const board2 = [
      [2, 4, 8, 32],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0]
    ];
    expect(game.boardsEqual(board1, board2)).toBe(false);
  });
});
