#include <array>

namespace BH::Keyboard {

// Numbers
constexpr uint16_t key0 = 29;
constexpr uint16_t key1 = 18;
constexpr uint16_t key2 = 19;
constexpr uint16_t key3 = 20;
constexpr uint16_t key4 = 21;
constexpr uint16_t key5 = 23;
constexpr uint16_t key6 = 22;
constexpr uint16_t key7 = 26;
constexpr uint16_t key8 = 28;
constexpr uint16_t key9 = 25;

// Letters
constexpr uint16_t keyA = 0;
constexpr uint16_t keyB = 11;
constexpr uint16_t keyC = 8;
constexpr uint16_t keyD = 2;
constexpr uint16_t keyE = 14;
constexpr uint16_t keyF = 3;
constexpr uint16_t keyG = 5;
constexpr uint16_t keyH = 4;
constexpr uint16_t keyI = 34;
constexpr uint16_t keyJ = 38;
constexpr uint16_t keyK = 40;
constexpr uint16_t keyL = 37;
constexpr uint16_t keyM = 46;
constexpr uint16_t keyN = 45;
constexpr uint16_t keyO = 31;
constexpr uint16_t keyP = 35;
constexpr uint16_t keyQ = 12;
constexpr uint16_t keyR = 15;
constexpr uint16_t keyS = 1;
constexpr uint16_t keyT = 17;
constexpr uint16_t keyU = 32;
constexpr uint16_t keyV = 9;
constexpr uint16_t keyW = 13;
constexpr uint16_t keyX = 7;
constexpr uint16_t keyY = 16;
constexpr uint16_t keyZ = 6;

// Special symbols
constexpr uint16_t keyEquals = 24;
constexpr uint16_t keyMinus = 27;
constexpr uint16_t keyRightbracket = 30;
constexpr uint16_t keyLeftbracket = 33;
constexpr uint16_t keyApostrophe = 39;
constexpr uint16_t keySemicolon = 41;
constexpr uint16_t keyFrontslash = 42;
constexpr uint16_t keyComma = 43;
constexpr uint16_t keyBackslash = 44;
constexpr uint16_t keyPeriod = 47;
constexpr uint16_t keyTab = 48;
constexpr uint16_t keySpace = 49;
constexpr uint16_t keyBackapostrophe = 50;

// Modifiers
constexpr uint16_t keyCommand = 55;
constexpr uint16_t keyShift = 56;
constexpr uint16_t keyOption = 58;
constexpr uint16_t keyControl = 59;

// Controls
constexpr uint16_t keyReturn = 36;
constexpr uint16_t keyDelete = 51;
constexpr uint16_t keyEscape = 53;
constexpr uint16_t keyCapslock = 57;

// Arrows
constexpr uint16_t keyLeft = 123;
constexpr uint16_t keyRight = 124;
constexpr uint16_t keyDown = 125;
constexpr uint16_t keyUp = 126;

// Modifier flags
constexpr uint32_t flagCapslock = 1 << 16;   // Set if Caps Lock key is pressed.
constexpr uint32_t flagShift = 1 << 17;      // Set if Shift key is pressed.
constexpr uint32_t flagControl = 1 << 18;    // Set if Control key is pressed.
constexpr uint32_t flagOption = 1 << 19;     // Set if Option or Alternate key is pressed.
constexpr uint32_t flagCommand = 1 << 20;    // Set if Command key is pressed.
constexpr uint32_t flagNumericpad = 1 << 21; // Set if any key in the numeric keypad is pressed.
constexpr uint32_t flagHelp = 1 << 22;       // Set if the Help key is pressed.
constexpr uint32_t flagFunction = 1 << 23;   // Set if any function key is pressed.

extern std::array<bool, 128> keys;

void keyPressed(uint16_t code);

void keyReleased(uint16_t code);

void flagsChanged(uint64_t flags);

} // namespace BH::Keyboard
