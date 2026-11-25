#include "sleep_pir.h"
#include "config.h"
#include "device_state.h"

#include <esp_sleep.h>
#if !CONFIG_IDF_TARGET_ESP32C3
#include <driver/rtc_io.h>
#endif

// Po co ustawiono budzik timera przed ostatnim snem (pamięć RTC przetrwa deep sleep)
enum TimerPurpose : uint8_t { TIMER_NONE = 0, TIMER_ADV = 1, TIMER_REARM = 2 };
RTC_DATA_ATTR static uint8_t s_timerPurpose = TIMER_NONE;

static WakeReason s_reason = WAKE_POWER_ON;
static bool       s_reasonKnown = false;

void pir_begin() {
  pinMode(PIR_PIN, INPUT_PULLDOWN);  // HC-SR501 steruje wyjściem aktywnie; pull-down na wypadek odłączenia
}

bool pir_active() { return digitalRead(PIR_PIN) == HIGH; }

WakeReason sleep_wake_reason() {
  if (s_reasonKnown) return s_reason;
  switch (esp_sleep_get_wakeup_cause()) {
#if CONFIG_IDF_TARGET_ESP32C3
    case ESP_SLEEP_WAKEUP_GPIO:
#else
    case ESP_SLEEP_WAKEUP_EXT0:
#endif
      s_reason = WAKE_PIR;
      break;
    case ESP_SLEEP_WAKEUP_TIMER:
      s_reason = (s_timerPurpose == TIMER_ADV) ? WAKE_ADV : WAKE_REARM;
      break;
    default:
      s_reason = WAKE_POWER_ON;
      break;
  }
  s_timerPurpose = TIMER_NONE;
  s_reasonKnown = true;
  return s_reason;
}

const char* wake_reason_name(WakeReason r) {
  switch (r) {
    case WAKE_PIR:   return "pir";
    case WAKE_ADV:   return "adv";
    case WAKE_REARM: return "rearm";
    default:         return "boot";
  }
}

static void arm_pir_wakeup() {
#if CONFIG_IDF_TARGET_ESP32C3
  // ESP32-C3: tylko GPIO0–5 mogą wybudzać z deep sleep
  esp_deep_sleep_enable_gpio_wakeup(1ULL << PIR_PIN, ESP_GPIO_WAKEUP_GPIO_HIGH);
#else
  rtc_gpio_pullup_dis((gpio_num_t)PIR_PIN);
  rtc_gpio_pulldown_en((gpio_num_t)PIR_PIN);
  esp_sleep_enable_ext0_wakeup((gpio_num_t)PIR_PIN, 1);
#endif
}

void sleep_now(uint16_t cooldownS, uint16_t advMin) {
  esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_ALL);
  uint64_t timerS = 0;

  if (cooldownS > 0) {
    // Cooldown: PIR nie budzi, po upływie czasu wstajemy tylko po to, by go uzbroić
    timerS = cooldownS;
    s_timerPurpose = TIMER_REARM;
    Serial.printf("[SLEEP] cooldown %u s (PIR nieaktywny)\n", cooldownS);
  } else {
    // HC-SR501 trzyma stan wysoki przez czas ustawiony potencjometrem. Gdybyśmy
    // zasnęli przy HIGH, wybudzilibyśmy się natychmiast – czekamy, aż opadnie.
    uint32_t t0 = millis();
    while (pir_active() && millis() - t0 < PIR_LOW_WAIT_MS) delay(50);

    if (pir_active()) {
      state_set_flag(ERR_PIR_STUCK, true);
      timerS = PIR_STUCK_RETRY_S;
      s_timerPurpose = TIMER_REARM;
      Serial.printf("[SLEEP] PIR wciaz HIGH – sprawdze ponownie za %d s\n", PIR_STUCK_RETRY_S);
    } else {
      state_set_flag(ERR_PIR_STUCK, false);
      arm_pir_wakeup();
      if (advMin > 0) {
        timerS = (uint64_t)advMin * 60ULL;
        s_timerPurpose = TIMER_ADV;
      } else {
        s_timerPurpose = TIMER_NONE;
      }
      Serial.printf("[SLEEP] deep sleep, budzi PIR (GPIO%d)%s\n", PIR_PIN,
                    advMin ? (String(" lub timer ") + advMin + " min").c_str() : "");
    }
  }

  if (timerS > 0) esp_sleep_enable_timer_wakeup(timerS * 1000000ULL);

  Serial.flush();
  esp_deep_sleep_start();
  while (true) {}  // nieosiągalne
}
