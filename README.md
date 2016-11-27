# Freepascal Raspberry Pi LCD interface library

This library aims to provide access to various LCD modules without needing kernel support, by directly talking to them over the I2C/SPI bus or via direct GPIO pin access. Root not required.

No dependencies on external libraries are required. All required libraries are available on my Github account, and will compile into your program statically.

## Library dependencies

All of these are available on my Github account.

* rpiio

## Supported displays and the driver to use for them

* HD44780 based character LCDs using the I2C PCF8574(A) chip (very common)
** Driver:  __rpii2clcdhd44780__
*** Usually these displays have backlight control. Leave the backlight jumper on the "backpack" module and the library can control it.
*** If you cannot see anything and the backlight is on, you probably need to adjust a trimpot on the "backpack" module.
*** __20x4__ displays have been fully tested.
*** __16x2__ displays should work, and will be tested soon.
*** The other 2 common sizes I know of (__8x1__ and __40x2__) I cannot get hold of so I cannot test or add support. Please contact me if you wish to donate a module, or add support and send me a pull request.

## Upcoming displays

* HD44780 based character LCDs connected directly to GPIO pins, without an I2C or SPI backpack board / interface IC.
** 4-bit and 8-bit mode will be supported.
** Driving the backlight via a transistor and PWM for brightness control will be supported.

## Directory layout example

** Please always use this standardised directory layout when using any of my freepascal or Delphi programs. The compilation scripts assume that the libraries will always be found by looking one directory back, and under libs/<name> **

* /home/youruser/projects/my_awesome_program
* /home/youruser/projects/libs/rpiio

