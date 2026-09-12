#include <Adafruit_TinyUSB.h>
// TTP223: VCC=3V3, GND=GND, OUT=D0. Default active-high momentary mode.
const uint8_t TOUCH_PIN = D0;
bool rawTouch = false, stableTouch = true;
uint32_t changedAt = 0, lastTouch = 0, lastHello = 0;
void setup() {
  pinMode(TOUCH_PIN, INPUT);
  Serial.begin(115200);
  delay(1000); // Allow sensor calibration; require release before first touch.
}
void loop() {
  uint32_t now = millis();
  bool touch = digitalRead(TOUCH_PIN) == HIGH;
  if (touch != rawTouch) { rawTouch = touch; changedAt = now; }
  if (now - changedAt >= 50 && stableTouch != rawTouch) {
    stableTouch = rawTouch;
    if (stableTouch && now - lastTouch >= 1500) {
      lastTouch = now;
      if (Serial) Serial.println("TOUCH_SWITCHER_TOUCH_V1");
    }
  }
  if (Serial && now - lastHello >= 1000) {
    lastHello = now;
    Serial.println("TOUCH_SWITCHER_READY_V1");
  }
  delay(5);
}
