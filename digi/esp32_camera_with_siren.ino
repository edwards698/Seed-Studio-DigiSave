/*
  XIAO ESP32S3 Sense — WiFi-first Camera Web Server with Siren/Buzzer
  - Connects to Wi-Fi and prints IP first
  - Then initializes the camera
  - "/" always loads (shows status); "/stream" & "/capture" only work when the camera is OK
  - "/siren" endpoint to trigger a buzzer/siren sound

#include <WiFi.h>
#include "esp_camera.h"
#include "esp_http_server.h"
#include "img_converters.h"

// ========= Wi-Fi credentials =========
const char *ssid = "3,2,1 Kaboom!💥💥💥";
const char *password = "##ONETWOTHREE456789";
// ====================================

// ========= Buzzer/Siren Pin =========
#define BUZZER_PIN 21 // Change this to any available GPIO pin on your XIAO ESP32S3
// ===================================

// ===== XIAO ESP32S3 Sense (OV2640) pin map =====
#define PWDN_GPIO_NUM -1
#define RESET_GPIO_NUM -1
#define XCLK_GPIO_NUM 10
#define SIOD_GPIO_NUM 40 // CAM_SDA
#define SIOC_GPIO_NUM 39 // CAM_SCL
#define Y2_GPIO_NUM 15
#define Y3_GPIO_NUM 17
#define Y4_GPIO_NUM 18
#define Y5_GPIO_NUM 16
#define Y6_GPIO_NUM 14
#define Y7_GPIO_NUM 12
#define Y8_GPIO_NUM 11
#define Y9_GPIO_NUM 48
#define VSYNC_GPIO_NUM 38
#define HREF_GPIO_NUM 47
#define PCLK_GPIO_NUM 13
// ===============================================

static httpd_handle_t http_main = nullptr;
static bool CAMERA_OK = false;

// ---------- Siren/Buzzer Functions ----------
void playAlarmTone()
{
    // Play an alarm pattern: high-low-high-low for 3 seconds
    for (int i = 0; i < 6; i++)
    {
        // High frequency tone
        for (int j = 0; j < 100; j++)
        {
            digitalWrite(BUZZER_PIN, HIGH);
            delayMicroseconds(500); // ~1kHz
            digitalWrite(BUZZER_PIN, LOW);
            delayMicroseconds(500);
        }

        delay(100); // Brief pause

        // Low frequency tone
        for (int j = 0; j < 50; j++)
        {
            digitalWrite(BUZZER_PIN, HIGH);
            delayMicroseconds(1000); // ~500Hz
            digitalWrite(BUZZER_PIN, LOW);
            delayMicroseconds(1000);
        }

        delay(100); // Brief pause between cycles
    }
}

void playSirenTone()
{
    // Play a siren pattern: sweeping frequency for 3 seconds
    for (int cycle = 0; cycle < 3; cycle++)
    {
        // Rising frequency
        for (int freq = 200; freq <= 1000; freq += 20)
        {
            for (int i = 0; i < 5; i++)
            {
                digitalWrite(BUZZER_PIN, HIGH);
                delayMicroseconds(1000000 / freq / 2);
                digitalWrite(BUZZER_PIN, LOW);
                delayMicroseconds(1000000 / freq / 2);
            }
        }

        // Falling frequency
        for (int freq = 1000; freq >= 200; freq -= 20)
        {
            for (int i = 0; i < 5; i++)
            {
                digitalWrite(BUZZER_PIN, HIGH);
                delayMicroseconds(1000000 / freq / 2);
                digitalWrite(BUZZER_PIN, LOW);
                delayMicroseconds(1000000 / freq / 2);
            }
        }
    }
}

// ---------- HTTP handlers ----------
static const char *CT_MJPEG = "multipart/x-mixed-replace;boundary=frame";

static esp_err_t siren_handler(httpd_req_t *req)
{
    Serial.println("[INFO] Siren endpoint triggered!");

    // Set response headers
    httpd_resp_set_type(req, "application/json");
    httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");
    httpd_resp_set_hdr(req, "Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    httpd_resp_set_hdr(req, "Access-Control-Allow-Headers", "Content-Type");

    // Play the siren sound in a non-blocking way
    Serial.println("[INFO] Playing siren sound...");
    playSirenTone(); // You can change this to playAlarmTone() for a different sound
    Serial.println("[INFO] Siren sound completed.");

    // Send response
    const char *response = "{\"status\":\"success\",\"message\":\"Siren activated\"}";
    return httpd_resp_send(req, response, strlen(response));
}

static esp_err_t stream_handler(httpd_req_t *req)
{
    if (!CAMERA_OK)
    {
        httpd_resp_send_500(req);
        return ESP_FAIL;
    }

    esp_err_t res = httpd_resp_set_type(req, CT_MJPEG);
    if (res != ESP_OK)
        return res;

    camera_fb_t *fb = nullptr;
    uint8_t *jpg_buf = nullptr;
    size_t jpg_len = 0;
    char hdr[96];

    while (true)
    {
        fb = esp_camera_fb_get();
        if (!fb)
        {
            Serial.println("[ERR ] Capture failed");
            return ESP_FAIL;
        }

        // Ensure JPEG in jpg_buf/jpg_len
        if (fb->format != PIXFORMAT_JPEG)
        {
            bool ok = frame2jpg(fb, 80, &jpg_buf, &jpg_len);
            if (!ok)
            {
                esp_camera_fb_return(fb);
                Serial.println("[ERR ] JPEG conversion failed");
                return ESP_FAIL;
            }
        }
        else
        {
            jpg_buf = fb->buf;
            jpg_len = fb->len;
        }

        // Boundary
        res = httpd_resp_send_chunk(req, "--frame\r\n", strlen("--frame\r\n"));
        if (res != ESP_OK)
        {
            if (fb->format != PIXFORMAT_JPEG && jpg_buf)
                free(jpg_buf);
            esp_camera_fb_return(fb);
            break;
        }

        // Part header
        size_t h = snprintf(hdr, sizeof(hdr),
                            "Content-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n",
                            (unsigned)jpg_len);
        res = httpd_resp_send_chunk(req, hdr, h);
        if (res != ESP_OK)
        {
            if (fb->format != PIXFORMAT_JPEG && jpg_buf)
                free(jpg_buf);
            esp_camera_fb_return(fb);
            break;
        }

        // Payload
        res = httpd_resp_send_chunk(req, (const char *)jpg_buf, jpg_len);

        // Cleanup this frame
        if (fb->format != PIXFORMAT_JPEG && jpg_buf)
        {
            free(jpg_buf);
            jpg_buf = nullptr;
        }
        esp_camera_fb_return(fb);

        if (res != ESP_OK)
            break;

        // End of part
        res = httpd_resp_send_chunk(req, "\r\n", 2);
        if (res != ESP_OK)
            break;
    }

    return res;
}

static esp_err_t capture_handler(httpd_req_t *req)
{
    if (!CAMERA_OK)
    {
        httpd_resp_send_500(req);
        return ESP_FAIL;
    }

    camera_fb_t *fb = esp_camera_fb_get();
    if (!fb)
    {
        httpd_resp_send_500(req);
        return ESP_FAIL;
    }

    esp_err_t r;

    if (fb->format != PIXFORMAT_JPEG)
    {
        uint8_t *jpg = nullptr;
        size_t jl = 0;
        bool ok = frame2jpg(fb, 80, &jpg, &jl);
        esp_camera_fb_return(fb);

        if (!ok)
        {
            httpd_resp_send_500(req);
            return ESP_FAIL;
        }

        httpd_resp_set_type(req, "image/jpeg");
        r = httpd_resp_send(req, (const char *)jpg, jl);
        free(jpg);
    }
    else
    {
        httpd_resp_set_type(req, "image/jpeg");
        r = httpd_resp_send(req, (const char *)fb->buf, fb->len);
        esp_camera_fb_return(fb);
    }

    return r;
}

static const char INDEX_HTML_OK[] PROGMEM = R"HTML(
<!doctype html><html><head><meta name=viewport content="width=device-width,initial-scale=1"><title>XIAO ESP32S3 Sense</title></head>
<body style="font-family:sans-serif;text-align:center;background:#111;color:#eee">
  <h2>XIAO ESP32S3 Sense</h2>
  <p><a href="/capture">Capture</a> | <a href="/siren">Test Siren</a></p>
  <img src="/stream" style="max-width:100%;height:auto;border:1px solid #333"/>
</body></html>)HTML";

static const char INDEX_HTML_FAIL[] PROGMEM = R"HTML(
<!doctype html><html><head><meta name=viewport content="width=device-width,initial-scale=1"><title>XIAO ESP32S3 Sense</title></head>
<body style="font-family:sans-serif;text-align:center;background:#111;color:#eee">
  <h2>Camera NOT initialized</h2>
  <p>Wi-Fi is connected. Check the ribbon cable on both ends, enable PSRAM in Tools (if Sense), then retry.</p>
  <p><a href="/siren">Test Siren</a> (should still work)</p>
</body></html>)HTML";

static esp_err_t index_handler(httpd_req_t *req)
{
    httpd_resp_set_type(req, "text/html");
    const char *page = CAMERA_OK ? INDEX_HTML_OK : INDEX_HTML_FAIL;
    return httpd_resp_send(req, page, strlen(page));
}

static void start_http_server()
{
    httpd_config_t c = HTTPD_DEFAULT_CONFIG();
    c.server_port = 80;

    if (httpd_start(&http_main, &c) == ESP_OK)
    {
        httpd_uri_t u_index = {.uri = "/", .method = HTTP_GET, .handler = index_handler, .user_ctx = NULL};
        httpd_uri_t u_capture = {.uri = "/capture", .method = HTTP_GET, .handler = capture_handler, .user_ctx = NULL};
        httpd_uri_t u_stream = {.uri = "/stream", .method = HTTP_GET, .handler = stream_handler, .user_ctx = NULL};
        httpd_uri_t u_siren = {.uri = "/siren", .method = HTTP_GET, .handler = siren_handler, .user_ctx = NULL};

        httpd_register_uri_handler(http_main, &u_index);
        httpd_register_uri_handler(http_main, &u_capture);
        httpd_register_uri_handler(http_main, &u_stream); // safe: handler checks CAMERA_OK
        httpd_register_uri_handler(http_main, &u_siren);  // buzzer endpoint
    }
}

// ---------- Wi-Fi then camera ----------
static bool connect_wifi(uint32_t timeout_ms = 20000)
{
    WiFi.mode(WIFI_STA);
    WiFi.setSleep(false);
    Serial.printf("[INFO] Connecting to SSID: %s\n", ssid);
    WiFi.begin(ssid, password);

    uint32_t t0 = millis();
    while (WiFi.status() != WL_CONNECTED)
    {
        delay(400);
        Serial.print(".");
        if (millis() - t0 > timeout_ms)
        {
            Serial.println("\n[ERR ] Wi-Fi connect timeout.");
            return false;
        }
    }

    Serial.println("\n[OK  ] Wi-Fi connected.");
    Serial.printf("[NET ] MAC: %s\n", WiFi.macAddress().c_str());
    Serial.printf("[NET ] IPv4: %s\n", WiFi.localIP().toString().c_str());
    Serial.printf("[NET ] Gateway: %s  DNS: %s\n",
                  WiFi.gatewayIP().toString().c_str(),
                  WiFi.dnsIP().toString().c_str());
    Serial.println("========================================");
    Serial.printf(" Index  : http://%s/\n", WiFi.localIP().toString().c_str());
    Serial.printf(" (Stream appears after camera starts)\n");
    Serial.println("========================================");
    return true;
}

static bool init_camera()
{
    camera_config_t cfg = {};
    cfg.ledc_channel = LEDC_CHANNEL_0;
    cfg.ledc_timer = LEDC_TIMER_0;

    cfg.pin_d0 = Y2_GPIO_NUM;
    cfg.pin_d1 = Y3_GPIO_NUM;
    cfg.pin_d2 = Y4_GPIO_NUM;
    cfg.pin_d3 = Y5_GPIO_NUM;
    cfg.pin_d4 = Y6_GPIO_NUM;
    cfg.pin_d5 = Y7_GPIO_NUM;
    cfg.pin_d6 = Y8_GPIO_NUM;
    cfg.pin_d7 = Y9_GPIO_NUM;
    cfg.pin_xclk = XCLK_GPIO_NUM;
    cfg.pin_pclk = PCLK_GPIO_NUM;
    cfg.pin_vsync = VSYNC_GPIO_NUM;
    cfg.pin_href = HREF_GPIO_NUM;
    cfg.pin_sscb_sda = SIOD_GPIO_NUM;
    cfg.pin_sscb_scl = SIOC_GPIO_NUM;
    cfg.pin_pwdn = PWDN_GPIO_NUM;
    cfg.pin_reset = RESET_GPIO_NUM;

    // Conservative bring-up first; increase later
    cfg.xclk_freq_hz = 16000000; // try 20 MHz after it works
    cfg.pixel_format = PIXFORMAT_JPEG;
    cfg.frame_size = FRAMESIZE_QVGA; // try VGA later
    cfg.jpeg_quality = 28;           // lower number = better quality
    cfg.fb_count = 1;
    cfg.grab_mode = CAMERA_GRAB_LATEST;
    cfg.fb_location = CAMERA_FB_IN_DRAM; // OK without PSRAM

    if (psramFound())
    {
        Serial.println("[INFO] PSRAM detected; using PSRAM for frame buffers.");
        cfg.fb_location = CAMERA_FB_IN_PSRAM;
    }
    else
    {
        Serial.println("[WARN] PSRAM NOT detected. (OK at QVGA; enable in Tools if Sense)");
    }

    Serial.println("[INFO] Initializing camera...");
    esp_err_t err = esp_camera_init(&cfg);
    if (err != ESP_OK)
    {
        Serial.printf("[ERR ] Camera init failed (0x%x).\n", err);
        return false;
    }

    // Optional: flip if image is upside-down
    // sensor_t* s = esp_camera_sensor_get();
    // if (s) { s->set_vflip(s, 1); }

    Serial.println("[OK  ] Camera initialized.");
    return true;
}

void setup()
{
    Serial.begin(115200);
    Serial.setDebugOutput(true);
    Serial.println("\n[XIAO ESP32S3 Sense] Booting...");

    // Initialize buzzer pin
    pinMode(BUZZER_PIN, OUTPUT);
    digitalWrite(BUZZER_PIN, LOW);
    Serial.printf("[INFO] Buzzer pin %d initialized.\n", BUZZER_PIN);

    // 1) Wi-Fi first (always get IP)
    if (!connect_wifi())
    {
        Serial.println("[FATAL] No Wi-Fi. Rebooting in 5s...");
        delay(5000);
        ESP.restart();
    }

    // 2) Start single HTTP server so "/" is available even if camera fails
    start_http_server();

    // 3) Then bring up the camera; endpoints already registered
    CAMERA_OK = init_camera();
    if (CAMERA_OK)
    {
        Serial.println("========================================");
        Serial.printf(" Stream : http://%s/stream\n", WiFi.localIP().toString().c_str());
        Serial.printf(" Capture: http://%s/capture\n", WiFi.localIP().toString().c_str());
        Serial.printf(" Siren  : http://%s/siren\n", WiFi.localIP().toString().c_str());
        Serial.println("========================================");
    }
    else
    {
        Serial.println("[WARN] Camera not ready. Open the index page for status.");
        Serial.printf(" Siren  : http://%s/siren\n", WiFi.localIP().toString().c_str());
    }
}

void loop(){
    // Nothing here; the HTTP server handles requests
} * /