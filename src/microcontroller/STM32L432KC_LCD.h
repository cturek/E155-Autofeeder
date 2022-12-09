// STM32L432KC_LCD.h
// Header for LCD functions

#ifndef  STM32L432KC_LCD
#define  STM32L432KC_LCD

#include <stdint.h>
#include <stm32l432xx.h>
#include <STM32L432KC_GPIO.h>

// Pin definitions for every GPIO pin
#define RS PB4
#define RW PB5
#define E PB3
#define DB7 PA2
#define DB6 PA7
#define DB5 PA6
#define DB4 PA5
#define DB3 PA4
#define DB2 PA3
#define DB1 PA1
#define DB0 PA0


///////////////////////////////////////////////////////////////////////////////
// Function prototypes
///////////////////////////////////////////////////////////////////////////////

void writeData(void);
void initConfig(void);
void controlPins(int pins[10]);
void initLCD(void);
void initLCD2(void);
void displayControl(int display, int cursor, int blink);
void clearDisplay();
void entryMode(int incdec, int dispshift);
void dispShift(int cd, int rl);
void writeChar(char c);
void writeString(char sentence[]);
void returnHome(void);

void secondLine(void);

#endif