// STM32L432KC_LCD.c
// Source code for LCD functions

#include "STM32L432KC.h"
#include "STM32L432KC_LCD.h"
#include "STM32L432KC_GPIO.h"
#include "STM32L432KC_RCC.h"
#include "STM32L432KC_TIM.h"
//#include <stm32l432xx.h>
#include <string.h>

// Initalize timer for delays

void initLCD2() {
  RCC->APB2ENR |= (RCC_APB2ENR_TIM15EN);
  initTIM(TIM15);

  // LCD Control Pins
  pinMode(RS, GPIO_OUTPUT);  // Register Select
  pinMode(RW, GPIO_OUTPUT);  // Read/Write (Should always be set to 0 for write)
  pinMode(E, GPIO_OUTPUT);  // Enable
  pinMode(DB0, GPIO_OUTPUT);  // DB0
  pinMode(DB1, GPIO_OUTPUT);  // DB1
  pinMode(DB2, GPIO_OUTPUT);  // DB2
  pinMode(DB3, GPIO_OUTPUT);  // DB3
  pinMode(DB4, GPIO_OUTPUT);  // DB4
  pinMode(DB5, GPIO_OUTPUT);  // DB5
  pinMode(DB6, GPIO_OUTPUT);  // DB6 
  pinMode(DB7, GPIO_OUTPUT);  // DB7 
  //GPIOA->PUPDR |= _VAL2FLD(GPIO_PUPDR_PUPD2, 0b10); // Set PB0 as pull-down
  //GPIOA->PUPDR |= _VAL2FLD(GPIO_PUPDR_PUPD7, 0b10); // Set PB0 as pull-down
  //GPIOA->PUPDR |= _VAL2FLD(GPIO_PUPDR_PUPD6, 0b10); // Set PB0 as pull-down
  //GPIOA->PUPDR |= _VAL2FLD(GPIO_PUPDR_PUPD5, 0b10); // Set PB0 as pull-down
  //GPIOA->PUPDR |= _VAL2FLD(GPIO_PUPDR_PUPD4, 0b10); // Set PB0 as pull-down
  //GPIOA->PUPDR |= _VAL2FLD(GPIO_PUPDR_PUPD3, 0b10); // Set PB0 as pull-down
  //GPIOA->PUPDR |= _VAL2FLD(GPIO_PUPDR_PUPD2, 0b10); // Set PB0 as pull-down
  //GPIOA->PUPDR |= _VAL2FLD(GPIO_PUPDR_PUPD1, 0b10); // Set PB0 as pull-down
  //GPIOA->PUPDR |= _VAL2FLD(GPIO_PUPDR_PUPD0, 0b10); // Set PB0 as pull-down


  digitalWrite(RS, 0);
  digitalWrite(RW, 0);
  digitalWrite(E, 0);
  digitalWrite(DB0, 0);
  digitalWrite(DB1, 0);
  digitalWrite(DB2, 0);
  digitalWrite(DB3, 0);
  digitalWrite(DB4, 0);
  digitalWrite(DB5, 0);
  digitalWrite(DB6, 0);
  digitalWrite(DB7, 0);

  delay_millis(TIM15,20);
}

void controlPins(int pins[10]){
    digitalWrite(RS, pins[0]); //RS
    digitalWrite(RW, pins[1]); //RW
    digitalWrite(DB7, pins[2]); //DB7
    digitalWrite(DB6, pins[3]); //DB6
    digitalWrite(DB5, pins[4]); //DB5
    digitalWrite(DB4, pins[5]); //DB4
    digitalWrite(DB3, pins[6]); //DB3
    digitalWrite(DB2, pins[7]); //DB2
    digitalWrite(DB1, pins[8]); //DB1 
    digitalWrite(DB0, pins[9]); //DB0
}

// Shifts data into LCD registers
void writeData() {
    delay_millis(TIM15, 1); 
    digitalWrite(E, 1); // Set enable high to write data
    delay_millis(TIM15, 1);
    digitalWrite(E, 0); // Set enable low
    delay_millis(TIM15, 1); 
}


// Implements data for initializing the display
void initConfig() {
    
    int data[10] = {0, 0, 0, 0, 1, 1, 1, 1, 0, 0};

    controlPins(data);
  
    writeData();
}

// This function turns on the display if control = 1, else turns display off
void displayControl(int display, int cursor, int blink){ 

    int data[10] = {0, 0, 0, 0, 0, 0, 1, display, cursor, blink};

    controlPins(data);

    writeData();
}

// This function sets the cursor to the first char of the first line
void returnHome(){ 
    int data[10] = {0, 0, 1, 0, 0, 0, 0, 0, 0, 0};

    controlPins(data);
    
    writeData();
}

// This function sets the cursor to the first char of the second line
void secondLine(){ 
    int data[10] = {0, 0, 1, 1, 0, 0, 0, 0, 0, 0};

    controlPins(data);
    
    writeData();
}

// This function clears all characters from the display
void clearDisplay(){ 
    int data[10] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 1};
  
    controlPins(data);

    writeData();
}

// This function sets the moving direction of the cursor and display
// incdec When high, cursor moves to right, else moves to left
//dispshift When high shift of all characters can be done through DDRAM write, else cant be done
void entryMode(int incdec, int dispshift){ 
    int data[10] = {0, 0, 0, 0, 0, 0, 0, 1, incdec, dispshift};
  
    controlPins(data);
    
    writeData();
}

// This function moves the cursor or display
// cd When high, controls display, else cursor
// rl When high shift right, else shift left
void dispShift(int cd, int rl){ 
    int data[10] = {0, 0, 0, 0, 0, 1, cd, rl, 0, 0};
  
    controlPins(data);
    
    writeData();
}

void initLCD() {
  //delay_millis(TIM15, 20); // wait 20ms after power up
  
  initConfig();
  
  delay_millis(TIM15, 5); // wait 5ms after 8bit config is set
  
  initConfig();
  
  delay_millis(TIM15, 1); // wait 1ms after 8bit config is set
  
  initConfig();
  
  initConfig();
  
  displayControl(0, 0, 0);
  
  clearDisplay();
  
  entryMode(1, 0);

  //displayControl(1, 1, 1);
}

void writeChar(char c) {
    int ascii[8];
    // assuming 8-bit ascii per char
    for (int i = 7; i >= 0; i--) {
        // calculate bitmask to check whether
        // ith bit of ascii is set or not
        int mask = (1 << i);
        
        // ith bit of ascii is set 
        if (c & mask) {
            //printf("1");
            ascii[i] = 1;
        }
        // ith bit of ascii is not set   
        else {
            //printf("0");
            ascii[i] = 0;
        }
    }

    int data[10] = {1, 0, ascii[7], ascii[6], ascii[5], ascii[4], ascii[3], ascii[2], ascii[1], ascii[0]};

    controlPins(data);

    writeData();
}

void writeString(char sentence[]) {
    int len = strlen(sentence);
    for (int i = 0; i < len; i++) {
        delay_millis(TIM15, 10);
        writeChar(sentence[i]);
    }
}