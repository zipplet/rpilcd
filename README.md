# Freepascal Raspberry Pi LCD interface library

This library aims to provide access to various LCD modules without needing kernel support, by directly talking to them over the I2C/SPI bus or via direct GPIO pin access. Root not required.

No dependencies on external libraries are required. All required libraries are available on my Github account, and will compile into your program statically.

## Library dependencies

All of these are available on my Github account.

* rpiio - https://github.com/zipplet/rpiio

## Supported displays and the driver to use for them

* HD44780 character LCD with 8 user defineable characters
  * Driver:  __rpilcdhd44780__
  * Demo video: https://youtu.be/XQv7JDUyKzE
  * Supported connection methods:
    * I2C bus (with the PCF8574(A) IO expander IC)
    * __Raw (directly connected) displays coming soon, 4 and 8 bit mode__
  * Display sub-types supported / tested:
    * __20x4 5x8 dot__: Full support (tested)
    * __16x2 5x8 dot__: Full support (tested)
    * __40x2 5x8 dot__: Full support __(untested)__
    * The other 3 common sizes I know of (__8x1__, __16x1__ and __40x2__) I cannot get hold of so I cannot test or add support. Please contact me if you wish to donate a module, or add support and send me a pull request.

* SSD1306 OLED display (monochrome)
  * Driver: __rpilcdi2cssd1306__
  * Supported connection modes:
    * I2C bus
  * Display sub-types supported / tested:
    * __128x64__: Under test
  * __Strictly alpha/testing only, please do not use this yet!__

## Upcoming displays

## Directory layout example

**Please always use this standardised directory layout when using any of my freepascal or Delphi programs. The compilation scripts assume that the libraries will always be found by looking one directory back, and under libs/<name>**

* /home/youruser/projects/my_awesome_program
* /home/youruser/projects/libs/rpiio
