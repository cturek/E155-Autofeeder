/**
    Main: Containts main function of microcontroller controlled peripherals: LCD screen and RFID sensor
    @file main.c
    @author Manuel Mendoza
    @version 1.0 12/2/2022
*/
#include <stdio.h>
#include <stm32l432xx.h>
#include "STM32L432KC.h"
#include <string.h>
#include <stdlib.h>


////////////////////////////////////////////////
// Constants
////////////////////////////////////////////////
#define ID1A "05004792BA"
#define ID2A "050047F610"
#define ID1B "5004792BA6"
#define ID2B "50047F610A"

////////////////////////////////////////////////
// Function Prototypes
////////////////////////////////////////////////

//Filters the ID out from RFID data transmission
void idFinder(char request[], char corrID[]) {
      	for(int i = 0; i < 10; i++){
            corrID[i] = request[i+2];
        }
}

//function to compare array elements
char compareArray(int a[],int b[],int size)	{
	int i;
	for(i=0;i<size;i++){
		if(a[i]!=b[i])
			return 0;
	}
	return 1;
}


////////////////////////////////////////////////
// Main
////////////////////////////////////////////////

int main(void) {
  configureFlash();
  configureClock();

  RCC->APB2ENR |= (RCC_APB2ENR_TIM16EN);
  initTIM(TIM16);

  // Initialization for UART Peripherals
  USART_TypeDef * USART = initUSART(USART1_ID, 9600); //Enable UART Communication with RFID tag
  

  // Initalization for GPIO Ports
  gpioEnable(GPIO_PORT_A);
  gpioEnable(GPIO_PORT_B);
  gpioEnable(GPIO_PORT_C);


  ////////////Initialize FPGA state pins/////////////////////////
  pinMode(PA9, GPIO_INPUT); //FPGA State into uController
  pinMode(PB0, GPIO_INPUT); //FPGA State into uController
  pinMode(PB1, GPIO_INPUT); //FPGA State into uController
  pinMode(PA8, GPIO_OUTPUT); //RFID Output to FPGA 

  GPIOB->PUPDR |= _VAL2FLD(GPIO_PUPDR_PUPD0, 0b10); // Set PB0 as pull-down
  GPIOA->PUPDR |= _VAL2FLD(GPIO_PUPDR_PUPD9, 0b10); // Set PB7 as pull-down 
  GPIOB->PUPDR |= _VAL2FLD(GPIO_PUPDR_PUPD1, 0b10); // Set PB5 as pull-down
  ///////////////////////////////////////////////////////////////

  ////////////INTERRUPT INITALIZATION FOR RFID and LCD STATES///////////////////
  pinMode(PA11, GPIO_INPUT); //RFID Interrupt Trigger
  pinMode(PA12, GPIO_INPUT); //FPGA State Interrupt Trigger

  GPIOA->PUPDR |= _VAL2FLD(GPIO_PUPDR_PUPD12, 0b10); // Set PA12 as pull-down
  GPIOA->PUPDR |= _VAL2FLD(GPIO_PUPDR_PUPD11, 0b10); // Set PA11 as pull-down

  // Initalization for Interrupts
  RCC->APB2ENR |= _VAL2FLD(RCC_APB2ENR_SYSCFGEN, 0b1);

  // Set EXTI12 to receive input from PA12
  SYSCFG->EXTICR[3] &= ~(_VAL2FLD(SYSCFG_EXTICR4_EXTI12, 0b000));
  // Set EXTI14 to receive input from PA11
  SYSCFG->EXTICR[2] &= ~(_VAL2FLD(SYSCFG_EXTICR3_EXTI11, 0b000));

  // Enable interrupts globally
  __enable_irq();

  // Set interrupts to trigger on rising edge for PA11 and PA12
  EXTI->IMR1 |= _VAL2FLD(EXTI_IMR1_IM12, 0b1);
  EXTI->RTSR1 |= _VAL2FLD(EXTI_RTSR1_RT12, 0b1);
  EXTI->FTSR1  &= ~_VAL2FLD(EXTI_FTSR1_FT12, 0b0);
  EXTI->IMR1 |= _VAL2FLD(EXTI_IMR1_IM11, 0b1);
  EXTI->RTSR1 |= _VAL2FLD(EXTI_RTSR1_RT11, 0b1);
  EXTI->FTSR1  &= ~_VAL2FLD(EXTI_FTSR1_FT11, 0b0);
  
  //Enable PA11 & PA12 interrupt handler
  NVIC_EnableIRQ(EXTI15_10_IRQn);

  ////////////////////////////////////////////////////////////////

  ////////////////////////LCD Initialization//////////////////////
  initLCD2();  
  initLCD();
  
  displayControl(1,0,0);

  clearDisplay();
  ////////////////////////////////////////////////////////////////

  char greeting[] = " Initializing...";
  writeString(greeting);
  secondLine();
  writeString("  Press reset");
  
  while(1){
    //clearDisplay();
    //writeString("main");

    }
}
      

   

 //Interrupt that reads ID coming from RFID reader and writes it to LCD
void EXTI15_10_IRQHandler(void) {
    //Check that the PA11 was what triggered our interrupt (RFID)
    if (EXTI->PR1 & (1 << 11)){
      //If so, clear the interrupt (NB: Write 1 to reset.)
      EXTI->PR1 |= (1 << 11);

      //Initialize two different strings, one holds the raw ID, while the other holds the filtered data
      char corrID[10] = "          "; // initialize to known value
      char request[16] = "                "; // initialize to known value
      
      //Quick macro to allow easy use of USART1
      USART_TypeDef * USART = id2Port(USART1_ID);
       
      // Wait for read data register to be full and read, reads in 16 chars from RFID tag through UART
      for(int i = 0; i < 16; i++){
        while(!(USART-> ISR & USART_ISR_RXNE));
        request[i] = readChar(USART);
        }
      
      //Filters ID from RFID tag
      idFinder(request, corrID);

      //Correct card comparison
      clearDisplay();  

      if((strcmp(corrID, ID2A) == 0) | (strcmp(corrID, ID2B) == 0)){
          writeString("   Correct ID"); 
          secondLine();
          writeString(" ID:");
          writeString(corrID);
          digitalWrite(PA8, 1);
          while(digitalRead(PA11));
          //delay_millis(TIM15, 100);
          digitalWrite(PA8, 0);
      }
      else{
          writeString("  Incorrect ID");
          secondLine();
          writeString(" ID:");
          writeString(corrID);
      }
    }

    //Based on the inputs from the FPGA, write different configuration options to the LCD screen
    if (EXTI->PR1 & (1 << 12)){
      //If so, clear the interrupt (NB: Write 1 to reset.)
      EXTI->PR1 |= (1 << 12);
    
      //clearDisplay();
      //writeString("Interrupt");
      
      //delay_millis(TIM16, 1);

      int state[] = {digitalRead(PA9), digitalRead(PB0), digitalRead(PB1)};
 
      int input_time[3]          = {0,1,0};
      int input_feed[3]          = {1,0,0};
      int input_amount[3]        = {1,1,0};
      int display_auto_config[3] = {0,0,0};
      int display_rfid_config[3] = {0,0,1};
      int display_feed[3]        = {0,1,1};
      int display_amount[3]      = {1,0,1};

      clearDisplay();
      //delay_millis(TIM16, 1000);
      if (compareArray(state, input_time, 3)){
          writeString("    Input");
          secondLine();
          writeString("  current time");
      }
      else if (compareArray(state, input_feed, 3)){
          writeString("Input feed time");
          secondLine();
          writeString(" or feed delay");
      }
      else if (compareArray(state, input_amount, 3)){
          writeString("    Input");
          secondLine();
          writeString("  feed amount");
      }
      else if (compareArray(state, display_auto_config, 3)){
          writeString("  Autofeed Mode");
          secondLine();
          writeString("Current time is:");
      }
      else if (compareArray(state, display_rfid_config, 3)){
          writeString("Tag Detect Mode");
          secondLine();
          writeString("Current time is:");
      }
      else if (compareArray(state, display_feed, 3)){
          writeString(" Feed time or  ");
          secondLine();
          writeString("  feed delay   ");
      }
      else if (compareArray(state, display_amount, 3)){
          writeString("  Feed amount  ");
          secondLine();
          writeString(" # of rotations");
      }
      else {
          writeString(" Invalid input");
      }
    }
}

 