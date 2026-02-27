namespace BH::Mouse {

extern bool buttonLeft;
extern bool buttonRight;

void leftButtonPressed();
void leftButtonReleased();
void rightButtonPressed();
void rightButtonReleased();
void moved(float dx, float dy);
void scrolled(float dx, float dy);

} // namespace BH::Mouse
