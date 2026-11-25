#include "device_state.h"
#include "config.h"

#include <ArduinoJson.h>
#include <Preferences.h>
#include <sys/time.h>

static Preferences  s_prefs;
static CamConfig    s_config = {DEFAULT_AI_THRESHOLD, DEFAULT_FRAMES, DEFAULT_HITS, DEFAULT_REC_S,
                                DEFAULT_COOLDOWN_S, DEFAULT_ADV_MIN, DEFAULT_WINDOW_S};
static uint32_t     s_errors = ERR_NONE;
static bool         s_wifiOn = false;
static bool         s_awake = false;
static int          s_streamClients = 0;
static float        s_sdFreeGb = -1.0f;
static const char*  s_wakeReason = "boot";
static uint32_t     s_eventCount = 0;
static portMUX_TYPE s_mux = portMUX_INITIALIZER_UNLOCKED;  // stan czytany z kilku tasków

// Ostatnie zdarzenie – w pamięci RTC, przetrwa deep sleep (nie przetrwa odłączenia zasilania)
struct RtcEvent {
  uint32_t id, durationMs, time;
  uint16_t framesRecorded;
  uint8_t  bestScore, hits, framesChecked;
  bool     animal, ok, valid;
  char     cls[20];
};
RTC_DATA_ATTR static RtcEvent s_lastEvent = {};

// ---------------------------------------------------------------------------
static int read_battery_percent() {
#if BATTERY_ADC_PIN >= 0
  uint32_t mv = 0;
  for (int i = 0; i < 8; i++) mv += analogReadMilliVolts(BATTERY_ADC_PIN);
  mv = (uint32_t)((mv / 8) * BATTERY_DIVIDER);
  if (mv <= BATTERY_EMPTY_MV) return 0;
  if (mv >= BATTERY_FULL_MV) return 100;
  return (int)((mv - BATTERY_EMPTY_MV) * 100 / (BATTERY_FULL_MV - BATTERY_EMPTY_MV));
#else
  return MOCK_BATTERY_PERCENT;
#endif
}

void state_begin() {
  s_prefs.begin("camtrap", false);
  CamConfig c = s_config;
  c.aiThreshold = s_prefs.getFloat("ai", c.aiThreshold);
  c.frames      = s_prefs.getUChar("frames", c.frames);
  c.hits        = s_prefs.getUChar("hits", c.hits);
  c.recS        = s_prefs.getUShort("rec", c.recS);
  c.cooldownS   = s_prefs.getUShort("cool", c.cooldownS);
  c.advMin      = s_prefs.getUShort("adv", c.advMin);
  c.windowS     = s_prefs.getUChar("win", c.windowS);
  String err;
  if (!state_set_config(c, err)) {  // uszkodzone/stare wartości -> domyślne
    Serial.printf("[CFG] niepoprawna konfiguracja w NVS (%s) – domyslna\n", err.c_str());
  }
  s_eventCount = s_prefs.getUInt("events", 0);
#if BATTERY_ADC_PIN >= 0
  analogSetPinAttenuation(BATTERY_ADC_PIN, ADC_11db);
#endif
}

// ---------------------------------------------------------------------------
//  Konfiguracja
// ---------------------------------------------------------------------------
CamConfig state_get_config() {
  portENTER_CRITICAL(&s_mux);
  CamConfig c = s_config;
  portEXIT_CRITICAL(&s_mux);
  return c;
}

static bool in_range(long v, long lo, long hi) { return v >= lo && v <= hi; }

bool state_set_config(const CamConfig& c, String& error) {
  if (isnan(c.aiThreshold) || c.aiThreshold < 0.0f || c.aiThreshold > 1.0f) { error = "ai must be 0..1"; return false; }
  if (!in_range(c.frames, 1, 10))                 { error = "frames must be 1..10"; return false; }
  if (!in_range(c.hits, 1, c.frames))             { error = "hits must be 1..frames"; return false; }
  if (!in_range(c.recS, 1, RECORD_MAX_S))         { error = "rec must be 1..RECORD_MAX_S"; return false; }
  if (!in_range(c.cooldownS, 0, 3600))            { error = "cool must be 0..3600"; return false; }
  if (!in_range(c.advMin, 0, 1440))               { error = "adv must be 0..1440"; return false; }
  if (!in_range(c.windowS, 2, 120))               { error = "win must be 2..120"; return false; }

  portENTER_CRITICAL(&s_mux);
  s_config = c;
  portEXIT_CRITICAL(&s_mux);

  // Preferences zapisuje tylko zmienione wartości – brak niepotrzebnego zużycia flash
  s_prefs.putFloat("ai", c.aiThreshold);
  s_prefs.putUChar("frames", c.frames);
  s_prefs.putUChar("hits", c.hits);
  s_prefs.putUShort("rec", c.recS);
  s_prefs.putUShort("cool", c.cooldownS);
  s_prefs.putUShort("adv", c.advMin);
  s_prefs.putUChar("win", c.windowS);
  return true;
}

bool state_parse_config_json(const String& json, CamConfig& out, String& error) {
  JsonDocument doc;  // ArduinoJson v7
  DeserializationError e = deserializeJson(doc, json);
  if (e) { error = String("bad json: ") + e.c_str(); return false; }
  out = state_get_config();
  if (doc["ai"].is<float>())    out.aiThreshold = doc["ai"].as<float>();
  if (doc["frames"].is<int>())  out.frames      = doc["frames"].as<int>();
  if (doc["hits"].is<int>())    out.hits        = doc["hits"].as<int>();
  if (doc["rec"].is<int>())     out.recS        = doc["rec"].as<int>();
  if (doc["cool"].is<int>())    out.cooldownS   = doc["cool"].as<int>();
  if (doc["adv"].is<int>())     out.advMin      = doc["adv"].as<int>();
  if (doc["win"].is<int>())     out.windowS     = doc["win"].as<int>();
  return true;
}

String state_config_json() {
  CamConfig c = state_get_config();
  char buf[128];
  snprintf(buf, sizeof(buf),
           "{\"ai\":%.2f,\"frames\":%u,\"hits\":%u,\"rec\":%u,\"cool\":%u,\"adv\":%u,\"win\":%u}",
           c.aiThreshold, c.frames, c.hits, c.recS, c.cooldownS, c.advMin, c.windowS);
  return String(buf);
}

// ---------------------------------------------------------------------------
//  Flagi i drobny stan
// ---------------------------------------------------------------------------
void state_set_flag(uint32_t flag, bool on) {
  portENTER_CRITICAL(&s_mux);
  if (on) s_errors |= flag; else s_errors &= ~flag;
  portEXIT_CRITICAL(&s_mux);
}

uint32_t state_errors() {
  portENTER_CRITICAL(&s_mux);
  uint32_t e = s_errors;
  portEXIT_CRITICAL(&s_mux);
  return e;
}

void state_set_wifi(bool on)            { portENTER_CRITICAL(&s_mux); s_wifiOn = on; portEXIT_CRITICAL(&s_mux); }
void state_set_awake(bool on)           { portENTER_CRITICAL(&s_mux); s_awake = on;  portEXIT_CRITICAL(&s_mux); }
void state_set_wake_reason(const char* r) { s_wakeReason = r; }
void state_set_sd_free_gb(float gb)     { portENTER_CRITICAL(&s_mux); s_sdFreeGb = gb; portEXIT_CRITICAL(&s_mux); }

void state_set_stream_clients(int delta) {
  portENTER_CRITICAL(&s_mux);
  s_streamClients = max(0, s_streamClients + delta);
  portEXIT_CRITICAL(&s_mux);
}

// ---------------------------------------------------------------------------
//  Zdarzenia
// ---------------------------------------------------------------------------
uint32_t state_next_event_id() {
  s_eventCount++;
  s_prefs.putUInt("events", s_eventCount);  // jeden zapis NVS na nagranie
  return s_eventCount;
}

uint32_t state_event_count() { return s_eventCount; }

void state_set_last_event(const TrapEvent& ev) {
  RtcEvent r = {};
  r.id = ev.id; r.durationMs = ev.durationMs; r.time = ev.time;
  r.framesRecorded = ev.framesRecorded; r.bestScore = ev.bestScore;
  r.hits = ev.hits; r.framesChecked = ev.framesChecked;
  r.animal = ev.animal; r.ok = ev.ok; r.valid = true;
  strlcpy(r.cls, ev.bestClass.c_str(), sizeof(r.cls));
  s_lastEvent = r;
}

String state_last_event_json() {
  const RtcEvent& r = s_lastEvent;
  if (!r.valid) return "{\"valid\":0}";
  char buf[200];
  snprintf(buf, sizeof(buf),
           "{\"id\":%lu,\"animal\":%d,\"score\":%u,\"cls\":\"%s\",\"hits\":%u,\"checked\":%u,"
           "\"frames\":%u,\"ms\":%lu,\"t\":%lu,\"ok\":%d}",
           (unsigned long)r.id, r.animal ? 1 : 0, r.bestScore, r.cls, r.hits, r.framesChecked,
           r.framesRecorded, (unsigned long)r.durationMs, (unsigned long)r.time, r.ok ? 1 : 0);
  return String(buf);
}

// ---------------------------------------------------------------------------
//  Czas – zegar RTC ESP32 biegnie w deep sleep; ustawiany z telefonu (SET_TIME)
// ---------------------------------------------------------------------------
uint32_t state_time() {
  time_t now = time(nullptr);
  return now > 1700000000 ? (uint32_t)now : 0;  // przed 2023 = nieustawiony
}

void state_set_time(uint32_t epoch) {
  struct timeval tv = {(time_t)epoch, 0};
  settimeofday(&tv, nullptr);
}

// ---------------------------------------------------------------------------
String state_status_json() {
  int bat = read_battery_percent();
  state_set_flag(ERR_LOW_BATTERY, bat >= 0 && bat < LOW_BATTERY_PERCENT);

  portENTER_CRITICAL(&s_mux);
  bool wifi = s_wifiOn, awake = s_awake;
  int clients = s_streamClients;
  uint32_t err = s_errors;
  float sd = s_sdFreeGb;
  portEXIT_CRITICAL(&s_mux);

  char buf[220];
  snprintf(buf, sizeof(buf),
           "{\"bat\":%d,\"sd\":%.2f,\"wifi\":%d,\"cli\":%d,\"cam\":%d,\"awake\":%d,\"err\":%lu,"
           "\"up\":%lu,\"ev\":%lu,\"pir\":%d,\"wake\":\"%s\",\"time\":%lu}",
           bat, sd, wifi ? 1 : 0, clients, (err & ERR_CAMERA) ? 0 : 1, awake ? 1 : 0,
           (unsigned long)err, (unsigned long)(millis() / 1000), (unsigned long)s_eventCount,
           digitalRead(PIR_PIN), s_wakeReason, (unsigned long)state_time());
  return String(buf);
}
