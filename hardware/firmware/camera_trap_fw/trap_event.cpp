#include "trap_event.h"
#include "camera_grove.h"
#include "config.h"
#include "sleep_pir.h"

#if RECORD_TARGET == RECORD_TARGET_ESP_SD
#include <SD.h>
#include <SPI.h>
static bool s_sdReady = false;
#endif

// ---------------------------------------------------------------------------
//  Karta SD po stronie ESP32 (opcjonalnie)
// ---------------------------------------------------------------------------
void trap_storage_begin() {
#if RECORD_TARGET == RECORD_TARGET_ESP_SD
  SPI.begin(SD_SCK_PIN, SD_MISO_PIN, SD_MOSI_PIN, SD_CS_PIN);
  s_sdReady = SD.begin(SD_CS_PIN, SPI);
  state_set_flag(ERR_SD, !s_sdReady);
  if (s_sdReady) {
    float freeGb = (float)((double)(SD.totalBytes() - SD.usedBytes()) / (1024.0 * 1024.0 * 1024.0));
    state_set_sd_free_gb(freeGb);
    Serial.printf("[SD] OK, wolne %.2f GB\n", freeGb);
  } else {
    state_set_sd_free_gb(0);
    Serial.println("[SD] brak karty / blad");
  }
#else
  state_set_sd_free_gb(-1);  // karta jest w Grove – ESP32 nie zna jej zajętości
#endif
}

#if RECORD_TARGET == RECORD_TARGET_ESP_SD
static void log_event_csv(const TrapEvent& ev) {
  if (!s_sdReady) return;
  bool fresh = !SD.exists("/events.csv");
  File f = SD.open("/events.csv", FILE_APPEND);
  if (!f) return;
  if (fresh) f.println("id,time,animal,score,class,hits,checked,frames,ms");
  f.printf("%lu,%lu,%d,%u,%s,%u,%u,%u,%lu\n", (unsigned long)ev.id, (unsigned long)ev.time,
           ev.animal, ev.bestScore, ev.bestClass.c_str(), ev.hits, ev.framesChecked,
           ev.framesRecorded, (unsigned long)ev.durationMs);
  f.close();  // zamykamy od razu – mniejsze ryzyko uszkodzenia przy zaniku zasilania
}
#endif

// ---------------------------------------------------------------------------
//  Nagrywanie
// ---------------------------------------------------------------------------
// Nagrywa co najmniej rec s; dopóki PIR jest aktywny, wydłuża do RECORD_MAX_S.
static bool keep_recording(uint32_t t0, uint16_t recS) {
  uint32_t el = millis() - t0;
  if (el < (uint32_t)recS * 1000UL) return true;
  return pir_active() && el < (uint32_t)RECORD_MAX_S * 1000UL;
}

static uint16_t record(uint32_t id, uint16_t recS) {
  uint16_t frames = 0;
  uint32_t t0 = millis();

#if RECORD_TARGET == RECORD_TARGET_GROVE_SD
  if (!camera_grove_sd_save(true)) return 0;
  while (keep_recording(t0, recS)) {
    if (camera_record_frame_on_grove()) frames++;
  }
  camera_grove_sd_save(false);
#else
  if (!s_sdReady) return 0;
  char dir[24];
  snprintf(dir, sizeof(dir), "/EV%05lu", (unsigned long)id);
  SD.mkdir(dir);
  std::vector<uint8_t> jpg;
  while (keep_recording(t0, recS)) {
    if (!camera_grab(jpg)) continue;
    char path[48];
    snprintf(path, sizeof(path), "%s/F%04u.jpg", dir, frames);
    File f = SD.open(path, FILE_WRITE);
    if (!f) { state_set_flag(ERR_SD, true); break; }
    f.write(jpg.data(), jpg.size());
    f.close();
    frames++;
  }
#endif

  Serial.printf("[REC] nagranie #%lu: %u klatek w %.1f s\n", (unsigned long)id, frames,
                (millis() - t0) / 1000.0f);
  return frames;
}

// ---------------------------------------------------------------------------
TrapEvent trap_run_event(bool keepCameraOn) {
  TrapEvent ev = {};
  uint32_t t0 = millis();
  CamConfig cfg = state_get_config();
  ev.time = state_time();

  // 1. Wybudzenie kamery
  if (!camera_power_on()) {
    ev.ok = false;
    ev.durationMs = millis() - t0;
    Serial.println("[EVT] kamera niedostepna – pomijam zdarzenie");
    state_set_last_event(ev);
    return ev;
  }
  ev.ok = true;

  // 2. Klasyfikacja kilku klatek
  for (uint8_t i = 0; i < cfg.frames; i++) {
    Classification c;
    if (!camera_classify(c)) continue;
    ev.framesChecked++;
    Serial.printf("[EVT] klatka %u: %s (score %u %s)\n", i + 1, c.animal ? "ZWIERZE" : "brak",
                  c.score, c.name.c_str());
    if (c.animal) {
      ev.hits++;
      if (c.score > ev.bestScore) { ev.bestScore = c.score; ev.bestClass = c.name; }
    }
    if (ev.hits >= cfg.hits) break;  // decyzja zapadła – nie trać czasu
  }
  ev.animal = ev.hits >= cfg.hits;

  // 3. Nagrywanie albo nic
  if (ev.animal) {
    ev.id = state_next_event_id();
    Serial.printf("[EVT] zwierze (%s, %u) -> nagrywam #%lu\n", ev.bestClass.c_str(), ev.bestScore,
                  (unsigned long)ev.id);
    ev.framesRecorded = record(ev.id, cfg.recS);
  } else {
    Serial.printf("[EVT] brak zwierzecia (%u/%u trafien) – bez nagrania\n", ev.hits, cfg.hits);
  }

  ev.durationMs = millis() - t0;
#if RECORD_TARGET == RECORD_TARGET_ESP_SD
  if (ev.animal) log_event_csv(ev);
#endif
  state_set_last_event(ev);

  if (!keepCameraOn) camera_power_off();
  return ev;
}
