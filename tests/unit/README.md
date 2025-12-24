# Unit Tests

## Overview

Unit tests for JavaScript game logic and components.

## Structure

```
tests/unit/
├── README.md                 # This file
├── game-logic.test.js        # Game logic unit tests
├── helpers.test.js           # Helper functions tests
└── setup.js                  # Test setup and configuration
```

## Running Unit Tests

```bash
# Run all unit tests
npm run test:unit

# Run with coverage
npm run test:unit:coverage

# Watch mode for development
npm run test:unit:watch
```

## Writing Unit Tests

### Test Structure

```javascript
const { describe, test, expect } = require('@jest/globals');

describe('Feature Name', () => {
  test('should do something specific', () => {
    // Arrange
    const input = 'test';

    // Act
    const result = someFunction(input);

    // Assert
    expect(result).toBe('expected');
  });
});
```

### Best Practices

1. **Test one thing at a time** - Each test should verify a single behavior
2. **Use descriptive names** - Test names should describe what they verify
3. **Arrange-Act-Assert** - Structure tests in three clear phases
4. **Mock external dependencies** - Keep tests isolated
5. **Test edge cases** - Don't just test the happy path

## Coverage Goals

- **Statements**: > 80%
- **Branches**: > 75%
- **Functions**: > 80%
- **Lines**: > 80%

## Future Additions

When the actual 2048 game is integrated, add tests for:

- Grid initialization
- Tile movement logic
- Score calculation
- Game over detection
- Win condition detection
- Keyboard input handling
- Touch gesture handling
- Animation timing
