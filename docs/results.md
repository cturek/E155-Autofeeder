---
layout: page
title: Results
---

## Summary of Results

Our autofeeder worked very well! 

# Autofeed Mode

Upon resetting the autofeeder, the FPGA defaults to autofeed mode, and everything resets to zeroes (Time = 00:00, Feed Time = 00:00, Feed Amount = 00). The feeder then begins counting up, and the user is immediately able to configure the current time, the feed time, and the feed amount. The keypad works without hiccups, does not suffer from switch bounce, and does not misread inputs. Times are correctly stored, and the world time continues to increase in the background when in a different mode. After running dozens of tests, including edge cases, the autofeeder is correctly able to detect when the time is the same as the feed time, and runs the motor for exactly the number of rotations specified.

The MCU accurately detects when the user has switched modes and alters the LCD display accordingly. There have been no issues with the LCD displaying the wrong message for any state. If RFID cards are presented to the feeder, they have zero effect in autofeed mode.

# RFID MODE

Pressing the "C" button on the keypad switches the feeder from autofeed mode to RFID mode, no matter the current state. If the world time is currently on the LED display, the MCU immediately updates the LCD screen to let the user know that they have swapped to RFID mode. If anything else is on the LED display, the feeder will alert the user the next time they switch to the world time display. 

We ran a myriad of tests to ensure the following desired characteristics of RFID mode:

1. The RFID delay timer counts down, even when in the background.

2. The delay timer stops at 00:00 until the feeder is activated, then resets to the most recent input.

3. The feeder does not activate if an incorrect RFID tag is presented to the reader.

4. The feeder does not activate if the correct tag is presented but the delay timer is nonzero.

5. The feeder activates when both the correct tag is presented and the timer is zero, and performs the correct number of cycles.

We consider this project a great success.

# Video Demonstration

<iframe width="560" height="315" src="https://www.youtube.com/watch?v=lRMq9qJNIq8" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>