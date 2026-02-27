#import "Keyboard.hpp"

namespace BH::Keyboard {

std::array<bool, 128> keys;

void keyPressed(uint16_t code) {
    keys[code] = true;
}

void keyReleased(uint16_t code) {
    keys[code] = false;
}

void flagsChanged(uint64_t flags) {
    keys[keyCommand] = flags & flagCommand;
    keys[keyShift] = flags & flagShift;
    keys[keyOption] = flags & flagOption;
    keys[keyControl] = flags & flagControl;
}

} // namespace BH::Keyboard
