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
