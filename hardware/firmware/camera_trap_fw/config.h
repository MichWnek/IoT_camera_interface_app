// ============================================================================
//  Fotopułapka AI – konfiguracja firmware
//  XIAO ESP32-C3 + Grove Vision AI V2 (OV5647) + PIR HC-SR501 + powerbank
//  (działa też na ESP32 DevKit V1 – piny wybierane automatycznie niżej)
// ============================================================================
#pragma once
#include <sdkconfig.h>  // CONFIG_IDF_TARGET_* (wybór pinów)

#define FW_VERSION "0.2.0"

// ---------------------------------------------------------------------------
//  Piny
// ---------------------------------------------------------------------------
#if CONFIG_IDF_TARGET_ESP32C3
// XIAO ESP32-C3. Wybudzanie z deep sleep działa TYLKO na GPIO0–GPIO5.
// Gdy XIAO siedzi w gnieździe Grove Vision AI V2, gniazdo łączy z modułem:
// D0 (SPI SYNC), D1 (SPI CS), D3 (RESET), D4/D5 (I2C), D6/D7 (UART), D8–D10 (SPI).
// Jedyny wolny pin, który umie budzić C3, to D2 – tam idzie PIR.
#define PIR_PIN          4    // D2 (GPIO4) <- OUT z HC-SR501
#define GROVE_RESET_PIN  5    // D3 (GPIO5) – reset modułu przez gniazdo; używany tylko, gdy moduł nie odpowiada
#define GROVE_POWER_PIN  -1   // EN przełącznika zasilania Grove; -1 = Grove zasilany stale
                              // (w gnieździe XIAO i Grove mają wspólne zasilanie – odcięcie wymaga
                              //  połączenia kablem Grove zamiast gniazda)
// Karta SD po stronie ESP (RECORD_TARGET_ESP_SD) – w gnieździe Grove nie ma na
// nią wolnych pinów; ma sens tylko przy połączeniu XIAO z Grove kablem I2C.
#define SD_SCK_PIN       8    // D8
#define SD_MISO_PIN      9    // D9
#define SD_MOSI_PIN      10   // D10
#define SD_CS_PIN        2    // D0
#else
// ESP32 DevKit V1 (klasyczny ESP32). Wybudzanie: piny RTC (0,2,4,12–15,25–27,32–39).
#define PIR_PIN          27
#define GROVE_RESET_PIN  -1
#define GROVE_POWER_PIN  -1   // np. 26
#define SD_SCK_PIN       18
#define SD_MISO_PIN      19
#define SD_MOSI_PIN      23
#define SD_CS_PIN        5
#endif
// I2C do Grove: domyślne piny Wire (XIAO C3: SDA=D4/GPIO6, SCL=D5/GPIO7;
// DevKit: SDA=21, SCL=22). Biblioteka SSCMA sama wywołuje Wire.begin().

#define GROVE_POWER_ON_LEVEL HIGH   // stan pinu włączający zasilanie Grove

// ---------------------------------------------------------------------------
//  Grove Vision AI V2
// ---------------------------------------------------------------------------
// 1 = prawdziwy moduł (biblioteka Seeed_Arduino_SSCMA)
// 0 = symulacja (bez modułu): obraz testowy + losowa klasyfikacja
#define USE_GROVE_VISION_AI 1
#define GROVE_BOOT_TIMEOUT_MS 5000  // ile czekać na moduł po włączeniu zasilania

// Klasy uznawane za "zwierzę". Nazwy porównywane są z listą klas modelu
// (z AI.info()). Do testów w domu z modelem "person" dopisz "person".
#define ANIMAL_CLASS_NAMES "animal,animals,bird,cat,dog,horse,sheep,cow,bear,deer,fox,boar,hare,rabbit,squirrel,badger,wolf,lynx,roe"
// Gdy model nie podaje nazw klas: indeksy klas zwierząt, "*" = dowolna klasa.
#define ANIMAL_CLASS_IDS   "*"

// Symulacja (USE_GROVE_VISION_AI 0)
#define MOCK_FRAME_W 160
#define MOCK_FRAME_H 120
#define MOCK_FPS     5
#define MOCK_ANIMAL_CHANCE 50       // % szans, że symulowana klasyfikacja "widzi" zwierzę

// ---------------------------------------------------------------------------
//  Nagrywanie
// ---------------------------------------------------------------------------
// GROVE_SD: zdjęcia zapisuje sam Grove Vision AI na SWOJĄ kartę microSD
//           (AT+ACTION save_jpeg) – szybko, pełna jakość, bez przesyłu po I2C.
// ESP_SD:   ESP32 pobiera JPEG przez I2C i zapisuje na kartę podłączoną po SPI.
#define RECORD_TARGET_GROVE_SD 0
#define RECORD_TARGET_ESP_SD   1
#define RECORD_TARGET RECORD_TARGET_GROVE_SD

// Przy GROVE_SD: 0 = invoke bez obrazu (szybciej), 1 = z obrazem (gdyby moduł
// nie zapisywał plików przy wnioskowaniu "results only").
#define GROVE_SD_FETCH_IMAGE 0

#define RECORD_MAX_S 60   // maks. czas nagrania, nawet gdy PIR cały czas aktywny

// ---------------------------------------------------------------------------
//  Uśpienie i okna BLE
// ---------------------------------------------------------------------------
#define FIRST_BOOT_AWAKE_S      90   // po włączeniu zasilania: BLE + rozgrzewanie PIR
#define PIR_WARMUP_S            60   // HC-SR501 potrzebuje ~30–60 s po włączeniu
#define PIR_LOW_WAIT_MS         4000 // przed snem czekamy aż PIR opadnie
#define PIR_STUCK_RETRY_S       5    // jeśli PIR wciąż HIGH – śpij tyle i sprawdź ponownie
#define MAINTENANCE_TIMEOUT_S   300  // tryb serwisowy (WAKE_UP) bez aktywności -> sen
#define DISCONNECT_GRACE_S      15   // po rozłączeniu BLE poczekaj chwilę przed snem

// ---------------------------------------------------------------------------
//  BLE
// ---------------------------------------------------------------------------
#define BLE_NAME_PREFIX "CT-"
#define SERVICE_UUID        "6e400000-c0de-4a1b-9f5e-ca3e7a000001"
#define CHAR_STATUS_UUID    "6e400001-c0de-4a1b-9f5e-ca3e7a000001"  // READ | NOTIFY
#define CHAR_CONFIG_UUID    "6e400002-c0de-4a1b-9f5e-ca3e7a000001"  // READ | WRITE
#define CHAR_COMMAND_UUID   "6e400003-c0de-4a1b-9f5e-ca3e7a000001"  // WRITE
#define CHAR_RESPONSE_UUID  "6e400004-c0de-4a1b-9f5e-ca3e7a000001"  // NOTIFY
#define BLE_MTU                 247
#define STATUS_NOTIFY_PERIOD_MS 5000

// ---------------------------------------------------------------------------
//  Wi-Fi
// ---------------------------------------------------------------------------
#define WIFI_USE_HOME_NETWORK 0     // 0 = własny AP (teren), 1 = sieć domowa (testy)
#define AP_SSID_PREFIX "CamTrap-"
#define AP_PASSWORD    "camtrap123" // min. 8 znaków – zmień przed wyjściem w teren
#define AP_CHANNEL     6
#define HOME_WIFI_SSID     "TWOJA_SIEC"
#define HOME_WIFI_PASSWORD "TWOJE_HASLO"
#define HOME_WIFI_TIMEOUT_MS 15000
#define WIFI_IDLE_TIMEOUT_MS (10UL * 60UL * 1000UL)
#define HTTP_PORT   80
#define STREAM_PORT 81

// ---------------------------------------------------------------------------
//  Status
// ---------------------------------------------------------------------------
// Powerbank daje stałe 5 V – poziomu baterii nie da się zmierzyć.
// -1 = "nieznany". Przy własnym ogniwie Li-ion podaj pin ADC (dzielnik napięcia).
#define BATTERY_ADC_PIN      -1
#define BATTERY_DIVIDER      2.0f
#define BATTERY_EMPTY_MV     3300
#define BATTERY_FULL_MV      4200
#define MOCK_BATTERY_PERCENT -1
#define LOW_BATTERY_PERCENT  20

// ---------------------------------------------------------------------------
//  Konfiguracja zmieniana przez BLE (CONFIG) – zakresy i wartości domyślne
// ---------------------------------------------------------------------------
#define DEFAULT_AI_THRESHOLD 0.60f  // ai     0.0–1.0  minimalna pewność "zwierzęcia"
#define DEFAULT_FRAMES       3      // frames 1–10     klatki do klasyfikacji po PIR
#define DEFAULT_HITS         1      // hits   1–frames ile klatek musi pokazać zwierzę
#define DEFAULT_REC_S        10     // rec    1–RECORD_MAX_S  długość nagrania [s]
#define DEFAULT_COOLDOWN_S   5      // cool   0–3600   po zdarzeniu ignoruj PIR [s]
#define DEFAULT_ADV_MIN      5      // adv    0–1440   co ile min wstać i rozgłaszać BLE (0 = nigdy)
#define DEFAULT_WINDOW_S     8      // win    2–120    jak długo rozgłaszać BLE po wybudzeniu [s]
