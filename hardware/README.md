# Fotopułapka AI – firmware

**XIAO ESP32-C3 + Grove Vision AI V2 (OV5647) + PIR HC-SR501 + powerbank.**
ESP32 zarządza układem. Większość czasu śpi (deep sleep) i budzi go tylko PIR. Po wybudzeniu
model na Grove sprawdza kilka klatek. Jeśli widzi zwierzę, urządzenie nagrywa, a jeśli nie, wraca do snu.
Do tego dochodzą funkcje z HLD: konfiguracja i status przez BLE oraz podgląd wideo przez Wi-Fi.

```
firmware/camera_trap_fw/   szkic Arduino (otwórz camera_trap_fw.ino)
  camera_trap_fw.ino       cykl pracy (maszyna stanów) + obsługa poleceń
  config.h                 piny, czasy, klasy "zwierzę", tryb nagrywania, BLE/Wi-Fi
  sleep_pir.*              PIR i deep sleep (przyczyna wybudzenia, uzbrajanie PIR)
  trap_event.*             zdarzenie: klasyfikacja -> nagrywanie / nic
  camera_grove.*           Grove Vision AI: zasilanie, klasyfikacja, obraz, zapis na SD
  ble_service.*            serwer GATT (STATUS, CONFIG, COMMAND, RESPONSE)
  wifi_stream.*            Wi-Fi AP / sieć domowa, HTTP, MJPEG
  device_state.*           konfiguracja w NVS, licznik nagrań, status, zegar
tools/ble_test.py          tester BLE z PC (udaje aplikację)
```

## 1. Cykl pracy

```
             ┌──────────────── deep sleep (~µA na ESP) ◄─────────────────┐
             │ PIR HIGH                                                  │
             ▼                                                           │
   wybudzenie ESP ─► Grove ON ─► klasyfikacja `frames` klatek (bez obrazu, szybko)
                                   │                                     │
                 ≥ `hits` klatek ze zwierzęciem?                         │
                     │tak                              │nie              │
                     ▼                                 │                 │
   nagrywanie `rec` s (dłużej, póki PIR aktywny,       │                 │
   maks. RECORD_MAX_S) ─► licznik nagrań +1            │                 │
                     └───────────────┬─────────────────┘                 │
                                     ▼                                   │
           okno BLE `win` s (można się połączyć) ─► Grove OFF ─► cooldown `cool` s ┘
```

- **Okresowe wybudzenie:** co `adv` minut ESP wstaje na `win` sekund i rozgłasza BLE. Bez tego
  nie dałoby się połączyć telefonem ze śpiącym urządzeniem. Drugi sposób to pomachać ręką przed PIR.
- **Po włączeniu zasilania** urządzenie czuwa 90 s. HC-SR501 rozgrzewa się przez ok. minutę i przez ten czas zgłasza
  fałszywe ruchy, więc firmware je w tym czasie ignoruje.
- **Nie zasypia, gdy:** jest połączenie BLE, działa Wi-Fi albo przyszło `WAKE_UP` (tryb serwisowy,
  wygasa po 5 min bez aktywności). `SLEEP` usypia od razu.
- **Przed snem** ESP czeka, aż PIR opadnie. Gdyby zasnął przy stanie HIGH, od razu by się wybudził
  i tak w kółko. Jeśli PIR nie opada przez 4 s, ESP śpi 5 s i sprawdza jeszcze raz (flaga `PIR_STUCK`).

## 2. Podłączenie (XIAO ESP32-C3)

| Element | Pin XIAO | Uwagi |
|---|---|---|
| HC-SR501 VCC | 5V | czujnik wymaga 4,5–20 V |
| HC-SR501 GND | GND | |
| HC-SR501 OUT | **D2 (GPIO4)** | wyjście ma 3,3 V, można podłączyć bezpośrednio. **Wybudzać z deep sleep mogą tylko GPIO0–5**, a D0, D1 i D3 zajmuje gniazdo Grove |
| Grove Vision AI V2 | gniazdo XIAO z tyłu modułu | I2C (D4/D5) + reset (D3) przez gniazdo |

Gdy XIAO jest w gnieździe, PIR podłączasz przewodami przylutowanymi od góry do pól XIAO: D2, 5V i GND.
Możesz też użyć wyższych listew (stacking headers). Przed lutowaniem sprawdź multimetrem na schemacie
lub płytce Grove, czy D2 nie jest z niczym połączony.

**Ustawienia HC-SR501:**
- zworka na **H** (wyzwalanie powtarzalne): wyjście trzyma HIGH, dopóki jest ruch, a firmware tyle czasu wydłuża nagranie,
- potencjometr **czasu na minimum** (ok. 3 s), wtedy szybciej opada przed snem,
- **czułość** zostaw na środku i dostrój w terenie.

Czułości tego czujnika nie da się zmienić programowo.

## 3. Zasilanie z powerbanku – przeczytaj przed testem w terenie

1. **Większość powerbanków wyłącza się sama**, gdy pobór spada poniżej ok. 50–100 mA. ESP w deep sleep
   pobiera mikroampery, więc powerbank zgaśnie i pułapka przestanie działać. Rozwiązania:
   - powerbank z trybem **„always on” / „low current” / „IoT”**,
   - ogniwo Li-ion z przetwornicą zamiast powerbanku (wtedy działa też pomiar baterii: `BATTERY_ADC_PIN`).
2. **Grove bez odcinania zasilania** (`GROVE_POWER_PIN -1`, domyślnie) cały czas pracuje i pobiera prąd
   rzędu dziesiątek mA, a usypia się tylko ESP. Warto zmierzyć to multimetrem. Paradoksalnie to może
   utrzymywać powerbank przy życiu, ale baterii starczy na krócej. Prawdziwe oszczędzanie wymaga przełącznika
   zasilania (load switch / MOSFET) i zasilania XIAO osobno od Grove. Z XIAO włożonym w złącze modułu
   mają wspólne zasilanie.
3. Z powerbanku nie da się odczytać poziomu baterii, więc status wysyła `"bat":-1` (nieznany).

## 4. Kompilacja (Arduino IDE 2.x)

1. Płytka: **XIAO_ESP32C3** (pakiet *esp32 by Espressif*). ESP32 DevKit V1: **ESP32 Dev Module**.
2. **Tools → Partition Scheme → Huge APP (3MB No OTA)** – BLE + Wi-Fi nie mieszczą się w domyślnej.
3. Biblioteki: **ArduinoJson** (v7) i **Seeed_Arduino_SSCMA** (v1.0.3+).
4. `config.h`:
   - `USE_GROVE_VISION_AI 1` – prawdziwy moduł; `0` – symulacja: losowa klasyfikacja i obraz testowy,
     do testów bez Grove (np. kolega z DevKitem),
   - `RECORD_TARGET`: `GROVE_SD` (domyślnie) – zdjęcia zapisuje sam Grove na swoją kartę microSD;
     `ESP_SD` – ESP pobiera JPEG po I2C (wolno, ok. 1–5 kl./s) i zapisuje na własną kartę SD,
   - `ANIMAL_CLASS_NAMES` – które klasy modelu liczą się jako zwierzę.
5. **Model na Grove** wgrywasz przez SenseCraft AI (przeglądarka, USB-C modułu). Przy starcie ESP wypisuje
   w Serial Monitorze listę klas modelu i oznacza te, które uzna za zwierzę. Do testów w domu
   z modelem „person” dopisz `person` do `ANIMAL_CLASS_NAMES`.

## 5. Protokół BLE

Serwis `6e400000-c0de-4a1b-9f5e-ca3e7a000001`, nazwa `CT-XXXX`.

| Charakterystyka | Właściwości | Zawartość |
|---|---|---|
| STATUS `6e400001-…` | READ, NOTIFY (co 5 s) | `{"bat":-1,"sd":-1.00,"wifi":0,"cli":0,"cam":1,"awake":0,"err":0,"up":12,"ev":3,"pir":0,"wake":"pir","time":1764000000}` |
| CONFIG `6e400002-…` | READ, WRITE | `{"ai":0.60,"frames":3,"hits":1,"rec":10,"cool":5,"adv":5,"win":8}` |
| COMMAND `6e400003-…` | WRITE | polecenia tekstowe (niżej) |
| RESPONSE `6e400004-…` | NOTIFY | `{"cmd":"…","ok":1,…}`; po zdarzeniu także `{"cmd":"EVENT",…}` |

Polecenia: `PING`, `WAKE_UP`, `SLEEP`, `TRIGGER` (symuluje PIR), `GET_STATUS`, `GET_CONFIG`,
`GET_EVENT`, `SET_CONFIG {json}`, `SET_TIME <epoch>`, `ENABLE_WIFI`, `DISABLE_WIFI`, `WIFI_INFO`, `REBOOT`.

- `wake`: `boot` / `pir` / `adv` – co obudziło urządzenie.
- `err` (maska bitów): 1 kamera, 2 SD, 4 słaba bateria, 8 Wi-Fi, 16 PIR nie opada.
- `sd: -1` – karta jest w Grove i ESP nie zna jej zajętości (przy `ESP_SD` podaje wolne GB).
- `time` – ESP nie ma zegara z baterią. Aplikacja po połączeniu powinna wysłać `SET_TIME`. Zegar
  działa dalej w deep sleep, ale ginie po odłączeniu zasilania (wtedy `time: 0`).

**Zmiany potrzebne w aplikacji Flutter:**
- `CameraConfig.pirThreshold` (V) nie pasuje do HC-SR501, bo jego czułość ustawia się potencjometrem.
  W modelu przyda się `frames`, `hits`, `rec`, `cool`, `adv`, `win`.
- `DeviceStatus` musi przyjmować `bat` i `sd` równe -1 (dziś `assert` wymaga ≥ 0).

## 6. Test w domu

1. Wgraj firmware i otwórz Serial Monitor (115200). Po starcie zobaczysz listę klas modelu i komunikat o oknie 90 s.
2. Połącz się: `python tools/ble_test.py` (najpierw `pip install bleak`). Skrypt sam ustawi zegar i wyśle `WAKE_UP`.
3. `TRIGGER` uruchamia pełne zdarzenie bez machania ręką. W Serial Monitorze widać wynik każdej klatki i decyzję.
4. Wpisz `SLEEP`, odczekaj, aż PIR opadnie, potem pomachaj przed czujnikiem. ESP wstaje, klasyfikuje, ewentualnie nagrywa
   i po ok. 8 s znów zasypia. Liczba nagrań jest w polu `ev` statusu.
5. Wideo: `ENABLE_WIFI`, połącz się z `CamTrap-XXXX` (hasło `camtrap123`) i otwórz `http://192.168.4.1/`
   albo w VLC `http://192.168.4.1:81/stream`. Kiedy Wi-Fi działa, PIR jest ignorowany, bo kamera obsługuje stream.

**Uwaga:** na XIAO ESP32-C3 port USB znika z komputera, gdy ESP śpi. To normalne. Żeby ponownie wgrać
firmware, wybudź płytkę (PIR / `WAKE_UP`) albo przytrzymaj BOOT i naciśnij RESET.

## 7. Znane ograniczenia

- Czas reakcji: wybudzenie ESP to ułamek sekundy, klasyfikacja ok. 0,1–0,3 s na klatkę. Z odcinaniem zasilania Grove
  dochodzi jeszcze 1–3 s jego startu. Szybkie zwierzę może zdążyć wyjść z kadru.
- Zapis na kartę Grove (`save_jpeg()`) wymaga aktualnego firmware modułu. Jeśli po nagraniu karta
  jest pusta, ustaw `GROVE_SD_FETCH_IMAGE 1`.
- Kod nie był jeszcze kompilowany ani uruchomiony na sprzęcie.
