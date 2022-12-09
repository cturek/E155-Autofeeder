---
layout: page
title: Documentation
---

<font face = "Courier New" size = "3">
**your code here**
</font><br />

# Schematics
<!-- Include images of the schematics for your system. They should follow best practices for schematic drawings with all parts and pins clearly labeled. You may draw your schematics either with a software tool or neatly by hand. -->
<div style="text-align: center">
  <img src="assets/schematics/E155_MCU_Schematics.png" alt="mcuschematics" width="750" />
</div>

<div style="text-align: center">
  <img src="assets/schematics/fpga.jpg" alt="fpga" width="500" />
</div>

# Source Code Overview
<!-- This section should include information to describe the organization of the code base and highlight how the code connects. -->

<i>The source code for the project is located in the Github repository [here](https://github.com/cturek/E155-Autofeeder/tree/main/src).</i>

As shown above, the FPGA interfaces with the four digit seven segment display, the four by four keypad, and the motor. Each of these interfaces is carried out using an FSM; the more interesting ones (keypad and display) are shown above, while the motor FSM is trivial and is not shown. The FPGA encodes its display state as a 3 bit signal and sends it over to the MCU.

The MCU interfaces with two different peripherals, a character LCD and a RFID reader. Whenever the correct card is waved in front of the reader, the MCU will send a signal over to the FPGA. As for the LCD, it displays the different configuration states that the autofeeder is in, with the information for what to display being sent over by the FPGA on the 3 bit signal.

## FPGA

The FPGA will control the 4 x 4 keypad, the four digit 7-segment display, and the motor used to rotate the feed tray. The motor operates on 12V while the FPGA sets pins to 3.3V, so it needs a motor driver.

Since we are not interested in typing letters, we configure three of the six non-numerical buttons to alternate functions. This means that when those specific buttons are pressed, the state machine will perform some logic internally rather than displaying a digit. For example, if the MODE button is pushed, the auto feeder will shift from one state to another, which will likely require the displayed digits to change.

Second, the four digit 7-segment display actually has five common anodes: one for each of the digits, and one more for the central colon and degree symbol. Thus, we have to keep track of four different digit values now and must also come up with a way to display the colon properly. Implementing this is not so hard; all we need to do is add two more shifts to go to the third and fourth digits. The colon only has two states: displayed (for clock) or hidden (for feed amount), so it will not be hard to send bits high or low depending on the internal FSM. 

The final piece of hardware that the FPGA controls is the stepper motor. We are using a NEMA 17 bipolar stepper rated at 12V[<sup>5</sup>](https://cturek.github.io/E155-Autofeeder/resources/). It offers 200 steps per revolution, and can operate at 60 RPM. To give enough voltage and current to this motor, we are using the STM L293D[<sup>6</sup>](https://cturek.github.io/E155-Autofeeder/resources/) push/pull channel driver as an H-bridge. 


# Bill of Materials
<!-- The bill of materials should include all the parts used in your project along with the prices and links.  -->

| Item | Part Number | Quantity | Unit Price | Link |
| ---- | ----------- | ----- | ---- | ---- |
| Adafruit Stepper Motor | 324 | 1 | $14.00 |  [link](https://www.adafruit.com/product/324) |
| ID-12 RFID Reader | EN-11827 | 1 | $32.50 | [link](https://www.sparkfun.com/products/11827) |
| 125kHz RFID Card | COM-14325 | 2 | $2.10 | [link](https://www.sparkfun.com/products/14325) |
| Quad 7-Segment Common Anode Display | LTC-4627JS | 1 | $3.57 | [link](https://www.digikey.com/en/products/detail/lite-on-inc./LTC-4627JS/408219) |
| 2x16 LCD Display | MC21605A6W-FPTLW | 1 | $5.00 | [link](https://www.digikey.com/en/products/detail/midas-displays/MC21605A6W-FPTLW/13970956?utm_adgroup=Optoelectronics&utm_source=google&utm_medium=cpc&utm_campaign=Shopping_DK%2BSuppliers_Midas%20Displays&utm_term=&utm_content=Optoelectronics&gclid=EAIaIQobChMIloym-9yE-wIVniytBh2NSQDmEAQYASABEgK5TfD_BwE) |



**Total cost: $57.90**
