// PIR HC-SR501 + deep sleep (ESP32-C3: GPIO wakeup, klasyczny ESP32: EXT0).
#pragma once
#include <Arduino.h>

enum WakeReason {
  WAKE_POWER_ON,   // włączenie zasilania / reset / wgranie firmware
  WAKE_PIR,        // ruch
  WAKE_ADV,        // okresowe wybudzenie na rozgłaszanie BLE
  WAKE_REARM,      // koniec cooldownu / PIR był "zawieszony" – tylko ponowne uzbrojenie
};

void       pir_begin();
bool       pir_active();          // stan wysoki = ruch
WakeReason sleep_wake_reason();   // ustalane raz, na starcie
const char* wake_reason_name(WakeReason r);

// Usypia ESP32. Nie wraca.
//   cooldownS – przez ten czas PIR nie wybudza (0 = od razu uzbrojony)
//   advMin    – okresowe wybudzenie na BLE (0 = brak)
[[noreturn]] void sleep_now(uint16_t cooldownS, uint16_t advMin);
