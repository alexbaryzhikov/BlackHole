namespace BH::Mouse {

extern bool buttonLeft;
extern bool buttonRight;

void leftButtonDown();
void leftButtonUp();
void rightButtonDown();
void rightButtonUp();
void moved(float dx, float dy);
void scrolled(float dx, float dy);

} // namespace BH::Mouse
