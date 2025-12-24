/**
 * 2048 Game Logic Module
 * Core game mechanics for the 2048 game
 */

class Game2048 {
  constructor(size = 4) {
    this.size = size;
    this.board = [];
    this.score = 0;
    this.gameWon = false;
    this.gameOver = false;
    this.initialize();
  }

  /**
   * Initialize the game board with empty cells
   */
  initialize() {
    this.board = Array(this.size).fill(null).map(() => Array(this.size).fill(0));
    this.score = 0;
    this.gameWon = false;
    this.gameOver = false;
    this.addRandomTile();
    this.addRandomTile();
  }

  /**
   * Add a random tile (2 or 4) to an empty cell
   * @returns {boolean} True if tile was added, false if board is full
   */
  addRandomTile() {
    const emptyCells = [];
    for (let row = 0; row < this.size; row++) {
      for (let col = 0; col < this.size; col++) {
        if (this.board[row][col] === 0) {
          emptyCells.push({ row, col });
        }
      }
    }

    if (emptyCells.length === 0) {
      return false;
    }

    const randomCell = emptyCells[Math.floor(Math.random() * emptyCells.length)];
    const value = Math.random() < 0.9 ? 2 : 4;
    this.board[randomCell.row][randomCell.col] = value;
    return true;
  }

  /**
   * Get a copy of the current board state
   * @returns {number[][]} Copy of the board
   */
  getBoard() {
    return this.board.map(row => [...row]);
  }

  /**
   * Get the current score
   * @returns {number} Current score
   */
  getScore() {
    return this.score;
  }

  /**
   * Check if the game is won
   * @returns {boolean} True if 2048 tile exists
   */
  isWon() {
    return this.gameWon;
  }

  /**
   * Check if the game is over
   * @returns {boolean} True if no valid moves remain
   */
  isOver() {
    return this.gameOver;
  }

  /**
   * Move tiles in the specified direction
   * @param {string} direction - 'up', 'down', 'left', or 'right'
   * @returns {boolean} True if the board changed
   */
  move(direction) {
    const previousBoard = this.getBoard();
    const previousScore = this.score;

    switch (direction) {
      case 'up':
        this.moveUp();
        break;
      case 'down':
        this.moveDown();
        break;
      case 'left':
        this.moveLeft();
        break;
      case 'right':
        this.moveRight();
        break;
      default:
        return false;
    }

    // Check if board changed
    const boardChanged = !this.boardsEqual(previousBoard, this.board);

    if (boardChanged) {
      this.addRandomTile();
      this.checkWinCondition();
      this.checkGameOver();
    }

    return boardChanged;
  }

  /**
   * Move tiles up
   */
  moveUp() {
    for (let col = 0; col < this.size; col++) {
      const column = this.getColumn(col);
      const newColumn = this.mergeTiles(column);
      this.setColumn(col, newColumn);
    }
  }

  /**
   * Move tiles down
   */
  moveDown() {
    for (let col = 0; col < this.size; col++) {
      const column = this.getColumn(col);
      const reversed = column.reverse();
      const newColumn = this.mergeTiles(reversed).reverse();
      this.setColumn(col, newColumn);
    }
  }

  /**
   * Move tiles left
   */
  moveLeft() {
    for (let row = 0; row < this.size; row++) {
      const newRow = this.mergeTiles([...this.board[row]]);
      this.board[row] = newRow;
    }
  }

  /**
   * Move tiles right
   */
  moveRight() {
    for (let row = 0; row < this.size; row++) {
      const reversed = [...this.board[row]].reverse();
      const newRow = this.mergeTiles(reversed).reverse();
      this.board[row] = newRow;
    }
  }

  /**
   * Get a column from the board
   * @param {number} col - Column index
   * @returns {number[]} Column values
   */
  getColumn(col) {
    return this.board.map(row => row[col]);
  }

  /**
   * Set a column on the board
   * @param {number} col - Column index
   * @param {number[]} values - New column values
   */
  setColumn(col, values) {
    for (let row = 0; row < this.size; row++) {
      this.board[row][col] = values[row];
    }
  }

  /**
   * Merge tiles in a line (row or column)
   * @param {number[]} line - Array of tile values
   * @returns {number[]} Merged line
   */
  mergeTiles(line) {
    // Remove zeros
    const nonZero = line.filter(val => val !== 0);
    const merged = [];
    let i = 0;

    while (i < nonZero.length) {
      if (i < nonZero.length - 1 && nonZero[i] === nonZero[i + 1]) {
        // Merge tiles
        const mergedValue = nonZero[i] * 2;
        merged.push(mergedValue);
        this.score += mergedValue;
        i += 2;
      } else {
        merged.push(nonZero[i]);
        i++;
      }
    }

    // Fill with zeros to maintain size
    while (merged.length < this.size) {
      merged.push(0);
    }

    return merged;
  }

  /**
   * Check if two boards are equal
   * @param {number[][]} board1 - First board
   * @param {number[][]} board2 - Second board
   * @returns {boolean} True if boards are equal
   */
  boardsEqual(board1, board2) {
    for (let row = 0; row < this.size; row++) {
      for (let col = 0; col < this.size; col++) {
        if (board1[row][col] !== board2[row][col]) {
          return false;
        }
      }
    }
    return true;
  }

  /**
   * Check if the player has reached 2048
   */
  checkWinCondition() {
    if (this.gameWon) return;

    for (let row = 0; row < this.size; row++) {
      for (let col = 0; col < this.size; col++) {
        if (this.board[row][col] === 2048) {
          this.gameWon = true;
          return;
        }
      }
    }
  }

  /**
   * Check if no valid moves remain
   */
  checkGameOver() {
    // Check for empty cells
    for (let row = 0; row < this.size; row++) {
      for (let col = 0; col < this.size; col++) {
        if (this.board[row][col] === 0) {
          return;
        }
      }
    }

    // Check for possible merges horizontally
    for (let row = 0; row < this.size; row++) {
      for (let col = 0; col < this.size - 1; col++) {
        if (this.board[row][col] === this.board[row][col + 1]) {
          return;
        }
      }
    }

    // Check for possible merges vertically
    for (let row = 0; row < this.size - 1; row++) {
      for (let col = 0; col < this.size; col++) {
        if (this.board[row][col] === this.board[row + 1][col]) {
          return;
        }
      }
    }

    this.gameOver = true;
  }

  /**
   * Check if any moves are available
   * @returns {boolean} True if moves are available
   */
  canMove() {
    // Check for empty cells
    for (let row = 0; row < this.size; row++) {
      for (let col = 0; col < this.size; col++) {
        if (this.board[row][col] === 0) {
          return true;
        }
      }
    }

    // Check for adjacent equal tiles
    for (let row = 0; row < this.size; row++) {
      for (let col = 0; col < this.size - 1; col++) {
        if (this.board[row][col] === this.board[row][col + 1]) {
          return true;
        }
      }
    }

    for (let row = 0; row < this.size - 1; row++) {
      for (let col = 0; col < this.size; col++) {
        if (this.board[row][col] === this.board[row + 1][col]) {
          return true;
        }
      }
    }

    return false;
  }

  /**
   * Reset the game
   */
  reset() {
    this.initialize();
  }

  /**
   * Set board state (for testing)
   * @param {number[][]} board - New board state
   */
  setBoard(board) {
    if (board.length !== this.size || board[0].length !== this.size) {
      throw new Error(`Board must be ${this.size}x${this.size}`);
    }
    this.board = board.map(row => [...row]);
  }

  /**
   * Set score (for testing)
   * @param {number} score - New score
   */
  setScore(score) {
    this.score = score;
  }
}

// Export for Node.js (CommonJS)
if (typeof module !== 'undefined' && module.exports) {
  module.exports = Game2048;
}

// Export for browsers (global)
if (typeof window !== 'undefined') {
  window.Game2048 = Game2048;
}
