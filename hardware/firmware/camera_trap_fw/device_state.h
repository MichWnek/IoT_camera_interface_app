// Stan urządzenia: konfiguracja (trwała w NVS), liczniki zdarzeń, status.
#pragma once
#include <Arduino.h>

// Bity pola "err" w STATUS_UPDATE
enum ErrorFlags : uint32_t {
  ERR_NONE        = 0,
  ERR_CAMERA      = 1 << 0,  // Grove Vision AI nie odpowiada
  ERR_SD          = 1 << 1,  // brak / błąd karty SD
  ERR_LOW_BATTERY = 1 << 2,  // bateria < LOW_BATTERY_PERCENT
  ERR_WIFI        = 1 << 3,  // nie udało się uruchomić Wi-Fi
  ERR_PIR_STUCK   = 1 << 4,  // PIR nie opada (zła regulacja czasu / tryb H)
};

struct CamConfig {
  float    aiThreshold;  // 0.0–1.0
  uint8_t  frames;       // klatki do klasyfikacji
  uint8_t  hits;         // ile z nich musi pokazać zwierzę
  uint16_t recS;         // długość nagrania [s]
  uint16_t cooldownS;    // po zdarzeniu ignoruj PIR [s]
  uint16_t advMin;       // okresowe wybudzenie na BLE [min], 0 = wyłączone
  uint8_t  windowS;      // czas rozgłaszania BLE po wybudzeniu [s]
};

// Wynik jednego zdarzenia PIR
struct TrapEvent {
  uint32_t id;           // numer nagrania (0 = brak nagrania)
  bool     animal;
  uint8_t  bestScore;    // 0–100
  String   bestClass;
  uint8_t  hits;
  uint8_t  framesChecked;
  uint16_t framesRecorded;
  uint32_t durationMs;
  uint32_t time;         // epoch (0 = zegar nieustawiony)
  bool     ok;           // false = błąd kamery
};

void      state_begin();
CamConfig state_get_config();
bool      state_set_config(const CamConfig& cfg, String& error);
bool      state_parse_config_json(const String& json, CamConfig& out, String& error);
String    state_config_json();

void      state_set_flag(uint32_t flag, bool on);
uint32_t  state_errors();
void      state_set_wifi(bool on);
void      state_set_awake(bool on);
void      state_set_stream_clients(int delta);
void      state_set_wake_reason(const char* reason);
void      state_set_sd_free_gb(float gb);     // -1 = nieznane

uint32_t  state_next_event_id();              // zwiększa licznik w NVS
uint32_t  state_event_count();
void      state_set_last_event(const TrapEvent& ev);
String    state_last_event_json();

uint32_t  state_time();                       // epoch lub 0
void      state_set_time(uint32_t epoch);

String    state_status_json();
