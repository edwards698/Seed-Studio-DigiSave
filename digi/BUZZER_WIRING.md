# XIAO ESP32S3 Buzzer Wiring Guide

## Required Components:

- XIAO ESP32S3 Sense
- Active Buzzer (3.3V-5V) or Passive Buzzer
- Jumper wires
- Breadboard (optional)

## Wiring:

```
XIAO ESP32S3    →    Buzzer
GPIO 21         →    Positive (+) pin
GND             →    Negative (-) pin
```

## Alternative GPIO Pins:

If GPIO 21 is not available, you can use any of these pins:

- GPIO 2, 3, 4, 5, 6, 7, 8, 9
- GPIO 43, 44 (if not using other peripherals)

**Note:** Make sure to update the `BUZZER_PIN` definition in your Arduino code if you use a different pin.

## Buzzer Types:

### Active Buzzer:

- Generates its own tone when voltage is applied
- Easier to use, just needs on/off control
- Usually has built-in oscillator

### Passive Buzzer:

- Requires PWM signal to generate tones
- Can create different frequencies and melodies
- More flexible but requires more complex code

## Code Configuration:

In the Arduino sketch, change this line if you use a different GPIO pin:

```cpp
#define BUZZER_PIN 21  // Change to your chosen GPIO pin
```

## Testing:

1. Upload the modified Arduino code to your XIAO ESP32S3
2. Open Serial Monitor to see the IP address
3. Test the buzzer by visiting: `http://YOUR_ESP32_IP/siren`
4. Or use the Flutter app's siren button or motion detection feature

## Volume Control:

For volume control, you can:

1. Add a resistor in series (100Ω - 1kΩ) to reduce volume
2. Use PWM to control the duty cycle for volume variation
3. Use an external amplifier circuit for louder sound

## Troubleshooting:

- If no sound: Check wiring, ensure buzzer is active type, verify GPIO pin
- If too quiet: Remove series resistor, check buzzer voltage rating
- If too loud: Add series resistor or reduce PWM duty cycle
