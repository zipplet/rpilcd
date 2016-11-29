# Freepascal Raspberry Pi LCD interface library

This library aims to provide access to various LCD modules without needing kernel support, by directly talking to them over the I2C/SPI bus or via direct GPIO pin access. Root not required.

No dependencies on external libraries are required. All required libraries are available on my Github account, and will compile into your program statically.

## Library dependencies

All of these are available on my Github account.

* rpiio - https://github.com/zipplet/rpiio

## Supported displays and the driver to use for them

* HD44780 character LCDs behind the I2C PCF8574(A) IO expander IC
  * Driver:  __rpilcdi2chd44780__
    * __Demo video:__ https://youtu.be/XQv7JDUyKzE
    * If there is a jumper for the backlight, leave the jumper on the interface module and the driver can control the backlight via a built in transistor on the module.
    * __20x4__ displays have been fully tested.
    * __16x2__ displays have been fully tested.
    * __40x2__ displays should work but __have not been tested__
    * The other 3 common sizes I know of (__8x1__, __16x1__ and __40x2__) I cannot get hold of so I cannot test or add support. Please contact me if you wish to donate a module, or add support and send me a pull request.

* SSD1306 I2C OLED 128x64 display - __ALPHA / TESTING ONLY__
  * Driver: __rpilcdi2cssd1306__

## Upcoming displays

* HD44780 character LCDs connected directly to GPIO pins
  * 4-bit and 8-bit mode will be supported.
  * Driving the backlight via a transistor and PWM for brightness control will be supported.
  * Supported display sizes will be the same as for the I2C based driver, until I obtain other module sizes.

## Directory layout example

**Please always use this standardised directory layout when using any of my freepascal or Delphi programs. The compilation scripts assume that the libraries will always be found by looking one directory back, and under libs/<name>**

* /home/youruser/projects/my_awesome_program
* /home/youruser/projects/libs/rpiio

