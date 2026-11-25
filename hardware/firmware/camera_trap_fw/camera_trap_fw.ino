// ============================================================================
//  Fotopułapka AI – firmware
//  XIAO ESP32-C3 + Grove Vision AI V2 (OV5647) + PIR HC-SR501 + powerbank
//
//  Cykl pracy:
//    deep sleep ──PIR──► wybudzenie ─► kamera ON ─► klasyfikacja N klatek
//        ▲                                   │
//        │            zwierzę? ──tak──► nagrywanie (rec s, dłużej gdy PIR aktywny)
//        │               │nie                │
//        └── okno BLE (win s) ◄──────────────┘  (+ cooldown, w którym PIR nie budzi)
//
//    Co adv minut ESP wstaje na win s i rozgłasza BLE, żeby dało się
//    połączyć telefonem. Po włączeniu zasilania zostaje aktywny 90 s
//    (rozgrzewanie PIR). Połączenie BLE / Wi-Fi / WAKE_UP blokują sen.
//
//  Polecenia (zapis tekstu do charakterystyki COMMAND lub Serial Monitor):
//    PING                       test łącza
//    WAKE_UP                    tryb serwisowy: nie zasypiaj, kamera ON
//    SLEEP                      zaśnij teraz
//    TRIGGER                    symuluj PIR (pełne zdarzenie)
//    GET_STATUS / GET_CONFIG / GET_EVENT
//    SET_CONFIG {"ai":0.7,"frames":3,"hits":1,"rec":10,"cool":5,"adv":5,"win":8}
//    SET_TIME 1764000000        ustaw zegar (epoch, s) – aplikacja przy połączeniu
//    ENABLE_WIFI / DISABLE_WIFI / WIFI_INFO
//    REBOOT
// ============================================================================
#include "config.h"
#include "device_state.h"
#include "sleep_pir.h"
#include "camera_grove.h"
#include "trap_event.h"
#include "ble_service.h"
#include "wifi_stream.h"

static WakeReason s_wake;
static uint32_t   s_awakeUntil = 0;      // koniec okna BLE (millis)
static bool       s_maintenance = false; // WAKE_UP
static bool       s_forceSleep = false;  // SLEEP
static uint32_t   s_lastActivity = 0;
static uint32_t   s_lastStatusMs = 0;
static uint32_t   s_cooldownUntil = 0;   // do tego czasu PIR jest ignorowany (millis)
static uint32_t   s_disconnectedAt = 0;
static bool       s_wasConnected = false;
static bool       s_lastPir = false;

// ---------------------------------------------------------------------------
//  JSON (bez argumentów domyślnych – generator prototypów Arduino IDE ich nie lubi)
// ---------------------------------------------------------------------------
static String strip_braces(const String& json) { return json.substring(1, json.length() - 1); }

static String ok_json_extra(const String& cmd, const String& extra) {
  String s = "{\"cmd\":\"" + cmd + "\",\"ok\":1";
  if (extra.length()) s += "," + extra;
  return s + "}";
}
static String ok_json(const String& cmd) { return ok_json_extra(cmd, ""); }
static String err_json(const String& cmd, const String& error) {
  return "{\"cmd\":\"" + cmd + "\",\"ok\":0,\"error\":\"" + error + "\"}";
}

static String wifi_json_fields() {
  WifiInfo w = wifi_info();
  if (!w.on) return "\"wifi\":0";
  return "\"wifi\":1,\"mode\":\"" + w.mode + "\",\"ssid\":\"" + w.ssid + "\",\"pass\":\"" +
         w.password + "\",\"ip\":\"" + w.ip + "\",\"url\":\"" + w.streamUrl + "\"";
}

static void send_status() {
  ble_notify_status(state_status_json());
  s_lastStatusMs = millis();
}

static void extend_window(uint16_t seconds) {
  uint32_t until = millis() + seconds * 1000UL;
  if ((int32_t)(until - s_awakeUntil) > 0) s_awakeUntil = until;
}

static bool pir_warmed_up() {
  // Po włączeniu zasilania HC-SR501 przez ok. minutę zgłasza fałszywe ruchy
  return s_wake != WAKE_POWER_ON || millis() > PIR_WARMUP_S * 1000UL;
}

// ---------------------------------------------------------------------------
//  Zdarzenie PIR w trakcie, gdy ESP już nie śpi (okno BLE, tryb serwisowy)
// ---------------------------------------------------------------------------
static void run_event_awake(const char* source) {
  Serial.printf("[EVT] start (%s)\n", source);
  bool keepCam = s_maintenance || wifi_is_on();
  TrapEvent ev = trap_run_event(keepCam);
  CamConfig cfg = state_get_config();
  s_cooldownUntil = millis() + cfg.cooldownS * 1000UL;
  ble_notify_response(ok_json_extra("EVENT", strip_braces(state_last_event_json())));
  send_status();
  extend_window(cfg.windowS);
  (void)ev;
}

// ---------------------------------------------------------------------------
static void handle_command(String line) {
  line.trim();
  if (!line.length()) return;
  s_lastActivity = millis();

  int sp = line.indexOf(' ');
  String cmd = (sp < 0 ? line : line.substring(0, sp));
  String arg = (sp < 0 ? "" : line.substring(sp + 1));
  cmd.toUpperCase();
  Serial.printf("[CMD] %s %s\n", cmd.c_str(), arg.c_str());

  if (cmd == "PING" || cmd == "HELLO") {
    ble_notify_response(ok_json_extra("PING", String("\"fw\":\"" FW_VERSION "\",\"name\":\"") + ble_device_name() + "\""));

  } else if (cmd == "WAKE_UP") {
    s_maintenance = true;
    s_forceSleep = false;
    state_set_awake(true);
    bool cam = camera_power_on();
    ble_notify_response(ok_json_extra(cmd, String("\"cam\":") + (cam ? 1 : 0) +
                                      ",\"timeout\":" + MAINTENANCE_TIMEOUT_S));
    send_status();

  } else if (cmd == "SLEEP") {
    ble_notify_response(ok_json(cmd));
    s_maintenance = false;
    s_forceSleep = true;

  } else if (cmd == "TRIGGER") {
    ble_notify_response(ok_json(cmd));
    run_event_awake("TRIGGER");

  } else if (cmd == "GET_STATUS") {
    send_status();
    ble_notify_response(ok_json(cmd));

  } else if (cmd == "GET_CONFIG") {
    ble_notify_response(ok_json_extra(cmd, strip_braces(state_config_json())));

  } else if (cmd == "GET_EVENT") {
    ble_notify_response(ok_json_extra(cmd, strip_braces(state_last_event_json())));

  } else if (cmd == "SET_CONFIG") {
    CamConfig cfg;
    String error;
    if (!state_parse_config_json(arg, cfg, error) || !state_set_config(cfg, error)) {
      ble_notify_response(err_json(cmd, error));
      return;
    }
    String json = state_config_json();
    ble_update_config_value(json);
    ble_notify_response(ok_json_extra(cmd, strip_braces(json)));

  } else if (cmd == "SET_TIME") {
    long epoch = arg.toInt();
    if (epoch < 1700000000L) {
      ble_notify_response(err_json(cmd, "epoch seconds expected"));
      return;
    }
    state_set_time((uint32_t)epoch);
    ble_notify_response(ok_json_extra(cmd, String("\"time\":") + state_time()));

  } else if (cmd == "ENABLE_WIFI") {
    s_maintenance = true;  // Wi-Fi i tak blokuje sen; po wyłączeniu zostaje tryb serwisowy
    state_set_awake(true);
    camera_power_on();
    String error;
    if (!wifi_enable(error)) ble_notify_response(err_json(cmd, error));
    else                     ble_notify_response(ok_json_extra(cmd, wifi_json_fields()));
    send_status();

  } else if (cmd == "DISABLE_WIFI") {
    wifi_disable();
    ble_notify_response(ok_json(cmd));
    send_status();

  } else if (cmd == "WIFI_INFO") {
    ble_notify_response(ok_json_extra(cmd, wifi_json_fields()));

  } else if (cmd == "REBOOT") {
    ble_notify_response(ok_json(cmd));
    delay(300);
    ESP.restart();

  } else {
    ble_notify_response(err_json(cmd, "unknown command"));
  }
}

// ---------------------------------------------------------------------------
static bool should_sleep() {
  uint32_t now = millis();
  if (s_forceSleep) return true;  // SLEEP – nawet przy połączeniu (go_to_sleep wyłączy Wi-Fi)
  if (wifi_is_on()) return false;
  if (ble_is_connected()) return false;
  if (s_maintenance) {
    if (now - s_lastActivity < MAINTENANCE_TIMEOUT_S * 1000UL) return false;
    Serial.println("[MAIN] tryb serwisowy wygasl");
    s_maintenance = false;
    state_set_awake(false);
  }
  if ((int32_t)(s_awakeUntil - now) > 0) return false;
  if (s_disconnectedAt && now - s_disconnectedAt < DISCONNECT_GRACE_S * 1000UL) return false;
  return true;
}

static void go_to_sleep() {  // nie wraca
  CamConfig cfg = state_get_config();
  uint32_t now = millis();
  uint16_t cooldown = 0;
  if ((int32_t)(s_cooldownUntil - now) > 0) cooldown = (s_cooldownUntil - now) / 1000 + 1;

  ble_notify_response("{\"cmd\":\"SLEEP\",\"ok\":1}");
  delay(100);
  wifi_disable();
  camera_power_off();
  sleep_now(cooldown, cfg.advMin);
}

// ---------------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  pir_begin();
  state_begin();

  s_wake = sleep_wake_reason();
  state_set_wake_reason(wake_reason_name(s_wake));
  CamConfig cfg = state_get_config();

  // Ponowne uzbrojenie PIR po cooldownie – nic więcej nie robimy, od razu sen
  if (s_wake == WAKE_REARM) sleep_now(0, cfg.advMin);

#if GROVE_POWER_PIN >= 0
  pinMode(GROVE_POWER_PIN, OUTPUT);
  digitalWrite(GROVE_POWER_PIN, !GROVE_POWER_ON_LEVEL);
#endif

  trap_storage_begin();

  if (s_wake == WAKE_PIR) {
    // Najpierw reakcja na ruch (liczy się czas), BLE dopiero potem
    Serial.println("\n[MAIN] wybudzenie: PIR");
    trap_run_event(false);
    s_cooldownUntil = millis() + cfg.cooldownS * 1000UL;
  } else {
    delay(300);  // czas na otwarcie Serial Monitora przy USB-CDC
    Serial.printf("\n=== Fotopulapka AI %s, wybudzenie: %s ===\n", FW_VERSION, wake_reason_name(s_wake));
  }

  ble_begin();
  extend_window(s_wake == WAKE_POWER_ON ? FIRST_BOOT_AWAKE_S : cfg.windowS);
  s_lastActivity = millis();
  s_lastPir = pir_active();
}

void loop() {
  BleCommand cmd;
  while (ble_poll_command(cmd)) handle_command(String(cmd.text));
  if (Serial.available()) handle_command(Serial.readStringUntil('\n'));

  // połączenie BLE
  bool connected = ble_is_connected();
  if (connected) s_lastActivity = millis();
  if (connected && !s_wasConnected) send_status();
  if (!connected && s_wasConnected) s_disconnectedAt = millis();
  s_wasConnected = connected;
  if (connected && millis() - s_lastStatusMs > STATUS_NOTIFY_PERIOD_MS) send_status();

  // PIR, gdy nie śpimy (zbocze narastające). Przy Wi-Fi kamera obsługuje stream.
  bool pir = pir_active();
  if (pir && !s_lastPir && pir_warmed_up() && !wifi_is_on() &&
      (int32_t)(millis() - s_cooldownUntil) >= 0) {
    run_event_awake("PIR");
  }
  s_lastPir = pir;

  wifi_loop();
  if (should_sleep()) go_to_sleep();
  delay(10);
}
